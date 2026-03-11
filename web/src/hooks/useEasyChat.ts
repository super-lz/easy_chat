import { useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react'
import { formatBytes } from '../lib/format'
import {
  DirectTransportClient,
  type FileBatch,
  type FileProgressEvent,
  type IncomingFileStart,
} from '../lib/directTransport'
import { createPairingSession, subscribeToPairingSession } from '../lib/pairingClient'
import {
  clearStoredEndpoint,
  initialMessages,
  persistEndpoint,
  persistSettings,
  restoreSettings,
  restoreStoredEndpoint,
} from '../lib/storage'
import type { AppSettings, Message, PendingAttachment, PairingSession, PhoneEndpoint } from '../lib/types'

const PAIRING_API = import.meta.env.VITE_PAIRING_API_URL ?? ''
const MAX_RECONNECT_ATTEMPTS = 5
const DIRECT_CONNECT_TIMEOUT_MS = 5000

export type AppPhase = 'pairing' | 'connecting' | 'chat'

export function useEasyChat() {
  const [phase, setPhase] = useState<AppPhase>('pairing')
  const [countdown, setCountdown] = useState(0)
  const [draft, setDraft] = useState('')
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([])
  const [messages, setMessages] = useState<Message[]>(initialMessages)
  const [session, setSession] = useState<PairingSession | null>(null)
  const [endpoint, setEndpoint] = useState<PhoneEndpoint | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [directStatus, setDirectStatus] = useState('等待手机共享地址')
  const [settings, setSettings] = useState<AppSettings>(() => restoreSettings())
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const reconnectTimerRef = useRef<number | null>(null)
  const reconnectAttemptsRef = useRef(0)
  const shouldReconnectRef = useRef(true)
  const unsubscribePairingRef = useRef<(() => void) | null>(null)
  const sessionRef = useRef<PairingSession | null>(null)
  const settingsRef = useRef(settings)
  const transportRef = useRef<DirectTransportClient | null>(null)

  const sessionHint = useMemo(() => {
    if (phase === 'pairing') return '等待手机扫码'
    if (phase === 'connecting') return '正在切换到局域网直连'
    return '局域网直连已建立'
  }, [phase])

  const conversationTitle = endpoint?.deviceName ?? '我的手机'
  const connectionAddress = endpoint ? `${endpoint.phoneIp}:${endpoint.phonePort}` : '等待手机共享地址'
  const canSend = phase === 'chat'
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
    sessionRef.current = session
  }, [session])

  useEffect(() => {
    transportRef.current = new DirectTransportClient({
      onOpen: (nextEndpoint) => {
        reconnectAttemptsRef.current = 0
        setError(null)
        setDirectStatus('已直连')
        setPhase('chat')
        setMessages((current) => [
          ...current,
          {
            id: `system-open-${Date.now()}`,
            sender: 'system',
            type: 'text',
            content: `已连接到 ${nextEndpoint.phoneIp}:${nextEndpoint.phonePort}`,
          },
        ])
      },
      onTextMessage: (text) => {
        setMessages((current) => [
          ...current,
          {
            id: `phone-${Date.now()}`,
            sender: 'phone',
            type: 'text',
            content: text,
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
                }
              : message,
          ),
        )
      },
      onSystemMessage: (text) => {
        appendSystemMessage(setMessages, text)
      },
      onProtocolError: (text) => {
        appendSystemMessage(setMessages, text)
      },
      onConnectionError: () => {
        setDirectStatus('连接失败')
        setError('无法连接到手机，请确认手机仍在当前 Wi‑Fi 下且 App 保持打开。')
      },
      onClose: ({ opened }) => {
        if (
          shouldReconnectRef.current &&
          settingsRef.current.autoReconnect &&
          endpoint &&
          reconnectAttemptsRef.current < MAX_RECONNECT_ATTEMPTS
        ) {
          reconnectAttemptsRef.current += 1
          const attempt = reconnectAttemptsRef.current
          setDirectStatus(`重连中 (${attempt}/${MAX_RECONNECT_ATTEMPTS})`)
          reconnectTimerRef.current = window.setTimeout(() => {
            connectDirectTransport(endpoint)
          }, Math.min(1500 * attempt, 5000))
          return
        }

        setDirectStatus(opened ? '连接已断开' : '连接失败')
        if (!opened) {
          setError('无法连接到手机，请确认手机仍在当前 Wi‑Fi 下且 App 保持打开。')
        }

        if (!opened && sessionRef.current === null) {
          clearStoredEndpoint()
          void createSession(false)
        }
      },
    })

    return () => {
      transportRef.current?.disconnect()
      transportRef.current = null
    }
  }, [endpoint])

  useEffect(() => {
    const restored = settings.rememberConnection ? restoreStoredEndpoint() : null
    if (restored) {
      setEndpoint(restored)
      setDirectStatus('正在恢复上一次连接')
      setPhase('connecting')
      setIsLoading(false)
    } else {
      void createSession()
    }

    return () => {
      unsubscribePairingRef.current?.()
      transportRef.current?.disconnect()
      if (reconnectTimerRef.current) window.clearTimeout(reconnectTimerRef.current)
    }
  }, [settings.rememberConnection])

  useEffect(() => {
    if (!session) return

    const timer = window.setInterval(() => {
      setCountdown(Math.max(0, Math.ceil((session.expiresAt - Date.now()) / 1000)))
    }, 250)

    return () => window.clearInterval(timer)
  }, [session])

  useEffect(() => {
    if (!endpoint) return

    if (settings.rememberConnection) {
      persistEndpoint(endpoint)
    } else {
      clearStoredEndpoint()
    }

    setPhase('connecting')
    setDirectStatus('正在连接手机')
    connectDirectTransport(endpoint)
  }, [endpoint, settings.rememberConnection])

  useEffect(() => {
    persistSettings(settings)
  }, [settings])

  function connectDirectTransport(nextEndpoint: PhoneEndpoint) {
    transportRef.current?.connect(nextEndpoint, DIRECT_CONNECT_TIMEOUT_MS)
  }

  function releaseAttachmentPreviews(items: PendingAttachment[]) {
    for (const item of items) {
      if (item.previewUrl) {
        URL.revokeObjectURL(item.previewUrl)
      }
    }
  }

  async function createSession(clearRemembered = true) {
    unsubscribePairingRef.current?.()
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
    setDirectStatus('等待手机共享地址')
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
      const data = await createPairingSession(PAIRING_API)
      setSession(data)
      setCountdown(Math.max(0, Math.ceil((data.expiresAt - Date.now()) / 1000)))
      unsubscribePairingRef.current = subscribeToPairingSession(PAIRING_API, data.sessionId, {
        onStatus: (payload) => {
          if (payload.phoneEndpoint) {
            setEndpoint(payload.phoneEndpoint)
          }
        },
        onExpired: () => {
          void createSession(false)
        },
        onError: () => {
          setError('配对服务连接已断开。')
        },
      })
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '未知配对错误')
    } finally {
      setIsLoading(false)
    }
  }

  function disconnectToPairing() {
    void createSession()
  }

  const sendMessage = async () => {
    const transport = transportRef.current
    if (!transport?.isOpen()) {
      setError('当前连接不可用。')
      return
    }

    if (pendingAttachments.length > 0) {
      const batch: FileBatch | undefined =
        pendingAttachments.length > 1
          ? { id: `batch-${Date.now()}`, total: pendingAttachments.length }
          : undefined

      for (const attachment of pendingAttachments) {
        const outgoing = await transport.queueFile(attachment.file, batch)
        const localDownloadUrl = URL.createObjectURL(attachment.file)
        setMessages((current) => [...current, createOutgoingFileMessage(outgoing, localDownloadUrl)])
      }

      setPendingAttachments((current) => {
        releaseAttachmentPreviews(current)
        return []
      })
      return
    }

    const text = draft.trim()
    if (!text) return

    transport.sendText(text)
    setMessages((current) => [
      ...current,
      {
        id: `m-${Date.now()}`,
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
        id: `pending-${Date.now()}-${index}-${file.name}`,
        file,
        name: file.name,
        size: file.size,
        mimeType: file.type || 'application/octet-stream',
        previewUrl: file.type.startsWith('image/') ? URL.createObjectURL(file) : undefined,
      }))

    if (nextFiles.length === 0) return

    setDraft('')
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

  function toggleSetting(key: keyof AppSettings) {
    setSettings((current) => ({ ...current, [key]: !current[key] }))
  }

  return {
    canSend,
    connectionAddress,
    conversationTitle,
    countdown,
    directStatus,
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
    pendingAttachments,
    removePendingAttachment,
  }
}

function appendSystemMessage(setMessages: React.Dispatch<React.SetStateAction<Message[]>>, text: string) {
  setMessages((current) => [
    ...current,
    {
      id: `system-${Date.now()}`,
      sender: 'system',
      type: 'text',
      content: text,
    },
  ])
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
    batchId: event.batchId,
    batchTotal: event.batchTotal,
    meta: `${formatBytes(event.size)} • 0%`,
    progress: 0,
    mimeType: event.mimeType,
  }
}

function createOutgoingFileMessage(
  event: {
    transferId: string
    file: File
    batchId?: string
    batchTotal?: number
    mimeType: string
    size: number
  },
  downloadUrl: string,
): Message {
  return {
    id: event.transferId,
    sender: 'browser',
    type: 'file',
    content: event.file.name,
    batchId: event.batchId,
    batchTotal: event.batchTotal,
    meta: `${formatBytes(event.size)} • 0%`,
    progress: 0,
    mimeType: event.mimeType,
    downloadUrl,
  }
}
