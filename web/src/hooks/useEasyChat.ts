import { useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react'
import { formatBytes } from '../lib/format'
import {
  DirectTransportClient,
  type FileBatch,
  type FileProgressEvent,
  type IncomingFileStart,
} from '../lib/directTransport'
import { getBrowserName, getDeviceInfo } from '../lib/browser'
import { createPairingSession, subscribeToPairingSession } from '../lib/pairingClient'
import {
  clearStoredEndpoint,
  initialMessages,
  persistEndpoint,
  persistSettings,
  restoreSettings,
  restoreStoredEndpoint,
} from '../lib/storage'
import type {
  AppSettings,
  DirectConnectionState,
  Message,
  PendingAttachment,
  PairingSession,
  PhoneEndpoint,
} from '../lib/types'

const PAIRING_API = import.meta.env.VITE_PAIRING_API_URL ?? ''
const DIRECT_CONNECT_TIMEOUT_MS = 5000
const MAX_RECONNECT_DELAY_MS = 2000
const IMMEDIATE_RECONNECT_COOLDOWN_MS = 800
const DEBUG_LOG_THROTTLE_MS = 400
const THROTTLED_DEBUG_EVENTS = new Set([
  'socket error',
  'socket close',
  'connect transport',
  'schedule reconnect',
  'immediate reconnect trigger',
])

export type AppPhase = 'pairing' | 'connecting' | 'chat'

const debugEventTimestamps = new Map<string, number>()
const RECONNECT_GUIDANCE = '连接已断开，重连中，请确保 App 保留在前台'
let localMessageSequence = 0

function logConnectionDebug(event: string, detail?: unknown) {
  if (!import.meta.env.DEV) return
  if (THROTTLED_DEBUG_EVENTS.has(event)) {
    const now = Date.now()
    const lastLoggedAt = debugEventTimestamps.get(event) ?? 0
    if (now - lastLoggedAt < DEBUG_LOG_THROTTLE_MS) {
      return
    }
    debugEventTimestamps.set(event, now)
  }
  console.info(`[easy-chat][connection] ${event}`, detail)
}

function getInitialBootstrapState() {
  const settings = restoreSettings()
  const endpoint = restoreStoredEndpoint()
  logConnectionDebug('bootstrap', {
    hasEndpoint: Boolean(endpoint),
    endpoint,
  })

  return {
    settings,
    endpoint,
    phase: endpoint ? ('connecting' as const) : ('pairing' as const),
    isLoading: !endpoint,
    connectionState: endpoint ? createRestoringState() : createIdleState(),
  }
}

export function useEasyChat() {
  const [bootstrapState] = useState(() => getInitialBootstrapState())
  const [phase, setPhase] = useState<AppPhase>(bootstrapState.phase)
  const [countdown, setCountdown] = useState(0)
  const [draft, setDraft] = useState('')
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([])
  const [messages, setMessages] = useState<Message[]>(initialMessages)
  const [session, setSession] = useState<PairingSession | null>(null)
  const [endpoint, setEndpoint] = useState<PhoneEndpoint | null>(bootstrapState.endpoint)
  const [peerPhoneMeta, setPeerPhoneMeta] = useState<{ name: string } | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(bootstrapState.isLoading)
  const [connectionState, setConnectionState] = useState<DirectConnectionState>(bootstrapState.connectionState)
  const [settings, setSettings] = useState<AppSettings>(bootstrapState.settings)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const reconnectTimerRef = useRef<number | null>(null)
  const reconnectAttemptsRef = useRef(0)
  const lastReconnectStartedAtRef = useRef(0)
  const shouldReconnectRef = useRef(true)
  const unsubscribePairingRef = useRef<(() => void) | null>(null)
  const settingsRef = useRef(settings)
  const transportRef = useRef<DirectTransportClient | null>(null)

  const sessionHint = useMemo(() => {
    if (phase === 'pairing') return '等待手机扫码'
    if (phase === 'connecting') return '正在切换到局域网直连'
    return '局域网直连已建立'
  }, [phase])

  const conversationTitle = peerPhoneMeta?.name ?? endpoint?.deviceName ?? '我的手机'
  const canCompose = phase === 'chat'
  const canSend = canCompose && (draft.trim().length > 0 || pendingAttachments.length > 0)
  const visibleMessages = useMemo(
    () => messages.filter((message) => settings.showSystemMessages || message.sender !== 'system'),
    [messages, settings.showSystemMessages],
  )
  const lastUserMessage = useMemo(
    () => [...visibleMessages].reverse().find((message) => message.sender !== 'system') ?? null,
    [visibleMessages],
  )

  useEffect(() => {
    settingsRef.current = settings
  }, [settings])

  useEffect(() => {
    transportRef.current = new DirectTransportClient({
      onOpen: (nextEndpoint) => {
        logConnectionDebug('socket open', nextEndpoint)
        reconnectAttemptsRef.current = 0
        shouldReconnectRef.current = true
        unsubscribePairingRef.current?.()
        unsubscribePairingRef.current = null
        setSession(null)
        setError(null)
        setConnectionState(createConnectedState())
        setPhase('chat')
        setMessages((current) => [
          ...current,
          {
            id: createLocalId('system-open'),
            sender: 'system',
            type: 'text',
            content: '局域网直连已建立',
          },
        ])
        transportRef.current?.sendPeerMeta({
          role: 'browser',
          name: getBrowserName(navigator.userAgent),
          deviceInfo: getDeviceInfo(navigator.userAgent),
        })
      },
      onPeerMeta: ({ role, name }) => {
        if (role !== 'phone') {
          return
        }
        setPeerPhoneMeta({ name })
      },
      onTextMessage: ({ text, compositionId }) => {
        setMessages((current) => [
          ...current,
          {
            id: createLocalId('phone'),
            sender: 'phone',
            type: 'text',
            content: text,
            compositionId,
          },
        ])
      },
      onIncomingFileStart: (event) => {
        setMessages((current) => [...current, createIncomingFileMessage(event)])
      },
      onIncomingFileProgress: (event) => {
        replaceTransferProgress(setMessages, event)
      },
      onIncomingFileComplete: (event) => {
        setMessages((current) =>
          current.map((message) =>
            message.id === event.transferId
              ? {
                  ...message,
                  meta: `${formatBytes(event.size)} • 已接收`,
                  progress: 1,
                  downloadUrl: event.downloadUrl,
                  mimeType: event.mimeType,
                  transferState: 'completed',
                }
              : message,
          ),
        )
      },
      onOutgoingFileProgress: (event) => {
        replaceTransferProgress(setMessages, event)
      },
      onOutgoingFileDelivered: ({ transferId, size }) => {
        setMessages((current) =>
          current.map((message) =>
            message.id === transferId
              ? {
                  ...message,
                  meta: `${formatBytes(size)} • 已发送`,
                  progress: 1,
                  transferState: 'completed',
                }
              : message,
          ),
        )
      },
      onFileCanceled: (event) => {
        markTransferCancelled(setMessages, event.transferId, event.size)
      },
      onSystemMessage: (text) => {
        appendSystemMessage(setMessages, translateSystemText(text))
      },
      onProtocolError: (text) => {
        appendSystemMessage(setMessages, translateSystemText(text))
      },
      onConnectionError: () => {
        logConnectionDebug('socket error', { endpoint })
        if (endpoint && shouldReconnectRef.current && settingsRef.current.autoReconnect) {
          setConnectionState(createReconnectState(reconnectAttemptsRef.current))
          setError(RECONNECT_GUIDANCE)
          return
        }

        setConnectionState(createFailedState())
        setError('无法连接到手机，请确认手机仍在当前 Wi‑Fi 下且 App 保持打开')
      },
      onRemoteDisconnect: () => {
        logConnectionDebug('remote disconnect', { endpoint })
        void createSession('peer_disconnect', true)
      },
      onClose: ({ opened }) => {
        logConnectionDebug('socket close', { opened, endpoint })
        if (endpoint && scheduleReconnect(endpoint, opened)) {
          return
        }

        setPhase('connecting')
        setConnectionState(createFailedState(opened ? '连接已断开' : '连接失败'))
        if (!opened) {
          setError('无法连接到手机，请确认手机仍在当前 Wi‑Fi 下且 App 保持打开')
        }
      },
    })

    return () => {
      transportRef.current?.disconnect()
      transportRef.current = null
    }
  }, [endpoint])

  useEffect(() => {
    logConnectionDebug('mount restore check', {
      restored: bootstrapState.endpoint,
    })
    if (bootstrapState.endpoint) {
      setConnectionState(createRestoringState())
      setPhase('connecting')
      setIsLoading(false)
    } else {
      void createSession('mount_without_endpoint')
    }

    return () => {
      unsubscribePairingRef.current?.()
      transportRef.current?.disconnect()
      if (reconnectTimerRef.current) window.clearTimeout(reconnectTimerRef.current)
    }
  }, [])

  useEffect(() => {
    if (!session) return

    const timer = window.setInterval(() => {
      setCountdown(Math.max(0, Math.ceil((session.expiresAt - Date.now()) / 1000)))
    }, 1000)

    return () => window.clearInterval(timer)
  }, [session])

  useEffect(() => {
    if (!endpoint) return
    logConnectionDebug('connect with endpoint', endpoint)
    setPeerPhoneMeta(null)

    shouldReconnectRef.current = true
    unsubscribePairingRef.current?.()
    unsubscribePairingRef.current = null
    setSession(null)

    persistEndpoint(endpoint)

    setPhase('connecting')
    setConnectionState(createRestoringState('正在连接手机'))
    connectDirectTransport(endpoint)
  }, [endpoint])

  useEffect(() => {
    persistSettings(settings)
  }, [settings])

  useEffect(() => {
    const triggerImmediateReconnect = () => {
      if (!endpoint || !shouldReconnectRef.current || !settingsRef.current.autoReconnect) {
        return
      }
      if (transportRef.current?.isOpen() || transportRef.current?.isConnecting()) {
        return
      }
      if (Date.now() - lastReconnectStartedAtRef.current < IMMEDIATE_RECONNECT_COOLDOWN_MS) {
        return
      }

      logConnectionDebug('immediate reconnect trigger', {
        endpoint,
        visibilityState: document.visibilityState,
        online: navigator.onLine,
      })
      reconnectAttemptsRef.current += 1
      setConnectionState(createReconnectState(reconnectAttemptsRef.current))
      connectDirectTransport(endpoint)
    }

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        triggerImmediateReconnect()
      }
    }

    window.addEventListener('focus', triggerImmediateReconnect)
    window.addEventListener('online', triggerImmediateReconnect)
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      window.removeEventListener('focus', triggerImmediateReconnect)
      window.removeEventListener('online', triggerImmediateReconnect)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [bootstrapState.endpoint])

  function connectDirectTransport(nextEndpoint: PhoneEndpoint) {
    logConnectionDebug('connect transport', nextEndpoint)
    lastReconnectStartedAtRef.current = Date.now()
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current)
      reconnectTimerRef.current = null
    }
    transportRef.current?.connect(nextEndpoint, DIRECT_CONNECT_TIMEOUT_MS)
  }

  function scheduleReconnect(nextEndpoint: PhoneEndpoint, opened: boolean) {
    if (!shouldReconnectRef.current || !settingsRef.current.autoReconnect) {
      logConnectionDebug('skip reconnect', {
        shouldReconnect: shouldReconnectRef.current,
        autoReconnect: settingsRef.current.autoReconnect,
      })
      return false
    }

    reconnectAttemptsRef.current += 1
    const attempt = reconnectAttemptsRef.current
    const reconnectDelay = Math.min(Math.max(0, attempt - 1) * 500, MAX_RECONNECT_DELAY_MS)
    logConnectionDebug('schedule reconnect', { attempt, opened, endpoint: nextEndpoint })
    setConnectionState(createReconnectState(attempt))
    setError(RECONNECT_GUIDANCE)
    reconnectTimerRef.current = window.setTimeout(() => {
      connectDirectTransport(nextEndpoint)
    }, reconnectDelay)
    return true
  }

  function releaseAttachmentPreviews(items: PendingAttachment[]) {
    for (const item of items) {
      if (item.previewUrl) {
        URL.revokeObjectURL(item.previewUrl)
      }
    }
  }

  async function createSession(reason = 'unknown', clearRemembered = false) {
    logConnectionDebug('create pairing session', { reason, clearRemembered })
    unsubscribePairingRef.current?.()
    unsubscribePairingRef.current = null
    shouldReconnectRef.current = false
    transportRef.current?.disconnect()
    transportRef.current?.resetTransfers()
    reconnectAttemptsRef.current = 0
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current)
      reconnectTimerRef.current = null
    }

    setIsLoading(true)
    setError(null)
    setSession(null)
    setEndpoint(null)
    setPeerPhoneMeta(null)
    setConnectionState(createIdleState())
    setMessages(initialMessages)
    setPendingAttachments((current) => {
      releaseAttachmentPreviews(current)
      return []
    })
    setPhase('pairing')
    if (clearRemembered) {
      clearStoredEndpoint()
    }

    try {
      const data = await createPairingSession(
        PAIRING_API,
        getBrowserName(navigator.userAgent),
        getDeviceInfo(navigator.userAgent),
      )
      setSession(data)
      setCountdown(Math.max(0, Math.ceil((data.expiresAt - Date.now()) / 1000)))
      unsubscribePairingRef.current = subscribeToPairingSession(PAIRING_API, data.sessionId, {
        onStatus: (payload) => {
          logConnectionDebug('pairing status', payload)
          if (payload.phoneEndpoint) {
            persistEndpoint(payload.phoneEndpoint)
            setSession(null)
            setEndpoint(payload.phoneEndpoint)
          }
        },
        onExpired: () => {
          void createSession('pairing_expired', false)
        },
        onError: () => {
          logConnectionDebug('pairing stream error')
          setError('配对服务连接已断开')
        },
      })
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '未知配对错误')
    } finally {
      setIsLoading(false)
    }
  }

  function disconnectToPairing() {
    transportRef.current?.disconnectPeer()
    void createSession('manual_disconnect', true)
  }

  const sendMessage = async () => {
    const transport = transportRef.current
    const text = draft.trim()

    if (!transport?.isOpen()) {
      setError('当前连接不可用')
      return
    }

    if (pendingAttachments.length > 0) {
      const compositionId = createLocalId('compose')
      const batch: FileBatch | undefined =
        pendingAttachments.length > 1
          ? { id: createLocalId('batch'), total: pendingAttachments.length }
          : undefined

      for (const attachment of pendingAttachments) {
        const outgoing = await transport.queueFile(attachment.file, batch, compositionId)
        const localDownloadUrl = URL.createObjectURL(attachment.file)
        setMessages((current) => [...current, createOutgoingFileMessage(outgoing, localDownloadUrl, compositionId)])
      }

      if (text) {
        transport.sendText(text, compositionId)
        setMessages((current) => [
          ...current,
          {
            id: createLocalId('caption'),
            sender: 'browser',
            type: 'text',
            content: text,
            compositionId,
          },
        ])
      }

      setPendingAttachments((current) => {
        releaseAttachmentPreviews(current)
        return []
      })
      setDraft('')
      return
    }

    if (!text) return

    transport.sendText(text)
    setMessages((current) => [
      ...current,
      {
        id: createLocalId('message'),
        sender: 'browser',
        type: 'text',
        content: text,
      },
    ])
    setDraft('')
  }

  const handleFileInput = async (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files ?? [])
    if (files.length === 0) return
    appendPendingFiles(files)
    event.target.value = ''
  }

  function appendPendingFiles(files: File[]) {
    const nextFiles = files
      .filter((file) => file.size > 0)
      .map<PendingAttachment>((file, index) => ({
        id: createLocalId(`pending-${index}`),
        file,
        name: file.name,
        size: file.size,
        mimeType: file.type || 'application/octet-stream',
        previewUrl: file.type.startsWith('image/') ? URL.createObjectURL(file) : undefined,
      }))

    if (nextFiles.length === 0) return

    setPendingAttachments((current) => [...current, ...nextFiles])
  }

  function removePendingAttachment(id: string) {
    setPendingAttachments((current) => {
      const removed = current.find((item) => item.id === id)
      if (removed?.previewUrl) {
        URL.revokeObjectURL(removed.previewUrl)
      }
      return current.filter((item) => item.id !== id)
    })
  }

  function clearPendingAttachments() {
    setPendingAttachments((current) => {
      releaseAttachmentPreviews(current)
      return []
    })
  }

  function toggleSetting(key: keyof AppSettings) {
    setSettings((current) => ({ ...current, [key]: !current[key] }))
  }

  function cancelFileTransfer(transferId: string) {
    const transport = transportRef.current
    if (!transport) return
    transport.cancelTransfer(transferId)
  }

  function cancelBatchTransfers(batchId: string) {
    const transport = transportRef.current
    if (!transport) return

    const activeTransferIds = messages
      .filter(
        (message) =>
          message.type === 'file' &&
          message.batchId === batchId &&
          message.transferState === 'transferring',
      )
      .map((message) => message.id)

    if (activeTransferIds.length === 0) return
    transport.cancelTransfers(activeTransferIds)
  }

  return {
    canCompose,
    canSend,
    connectionState,
    conversationTitle,
    countdown,
    draft,
    endpoint,
    error,
    fileInputRef,
    handleFileInput,
    isLoading,
    lastUserMessage,
    phase,
    session,
    sessionHint,
    settings,
    toggleSetting,
    visibleMessages,
    createSession,
    disconnectToPairing,
    sendMessage,
    setDraft,
    appendPendingFiles,
    cancelBatchTransfers,
    cancelFileTransfer,
    clearPendingAttachments,
    pendingAttachments,
    removePendingAttachment,
  }
}

function createIdleState(): DirectConnectionState {
  return {
    kind: 'idle',
    label: '等待手机共享地址',
  }
}

function createRestoringState(label = '正在恢复连接'): DirectConnectionState {
  return {
    kind: 'restoring',
    label,
  }
}

function createReconnectState(attempt: number): DirectConnectionState {
  return {
    kind: 'reconnecting',
    label: attempt > 0 ? '重连中' : '正在恢复连接',
  }
}

function createConnectedState(): DirectConnectionState {
  return {
    kind: 'connected',
    label: '已连接',
  }
}

function createFailedState(label = '连接失败'): DirectConnectionState {
  return {
    kind: 'failed',
    label,
  }
}

function appendSystemMessage(setMessages: React.Dispatch<React.SetStateAction<Message[]>>, text: string) {
  setMessages((current) => [
    ...current,
    {
      id: createLocalId('system'),
      sender: 'system',
      type: 'text',
      content: text,
    },
  ])
}

function createLocalId(prefix: string) {
  localMessageSequence += 1
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return `${prefix}-${crypto.randomUUID()}`
  }
  return `${prefix}-${Date.now()}-${localMessageSequence}`
}

function translateSystemText(text: string) {
  if (text === 'Direct socket connected') {
    return '直连通道已建立'
  }
  if (text === 'Invalid JSON message') {
    return '收到无效协议消息'
  }
  return text
}

function replaceTransferProgress(
  setMessages: React.Dispatch<React.SetStateAction<Message[]>>,
  event: FileProgressEvent,
) {
  setMessages((current) =>
    current.map((message) =>
      message.id === event.transferId
        ? {
            ...message,
            meta: `${formatBytes(event.size)} • ${Math.round(event.progress * 100)}%`,
            progress: event.progress,
            transferState: 'transferring',
          }
        : message,
    ),
  )
}

function createIncomingFileMessage(event: IncomingFileStart): Message {
  return {
    id: event.transferId,
    sender: 'phone',
    type: 'file',
    content: event.name,
    compositionId: event.compositionId,
    batchId: event.batchId,
    batchTotal: event.batchTotal,
    meta: `${formatBytes(event.size)} • 0%`,
    progress: 0,
    mimeType: event.mimeType,
    transferState: 'transferring',
  }
}

function createOutgoingFileMessage(
  event: {
    transferId: string
    file: File
    compositionId?: string
    batchId?: string
    batchTotal?: number
    mimeType: string
    size: number
  },
  downloadUrl: string,
  compositionId?: string,
): Message {
  return {
    id: event.transferId,
    sender: 'browser',
    type: 'file',
    content: event.file.name,
    compositionId,
    batchId: event.batchId,
    batchTotal: event.batchTotal,
    meta: `${formatBytes(event.size)} • 0%`,
    progress: 0,
    mimeType: event.mimeType,
    downloadUrl,
    transferState: 'transferring',
  }
}

function markTransferCancelled(
  setMessages: React.Dispatch<React.SetStateAction<Message[]>>,
  transferId: string,
  size: number,
) {
  setMessages((current) =>
    current.map((message) => {
      if (message.id !== transferId) return message
      if (message.downloadUrl?.startsWith('blob:')) {
        URL.revokeObjectURL(message.downloadUrl)
      }
      return {
        ...message,
        downloadUrl: undefined,
        meta: `${formatBytes(size)} • 已取消`,
        progress: undefined,
        transferState: 'cancelled',
      }
    }),
  )
}
