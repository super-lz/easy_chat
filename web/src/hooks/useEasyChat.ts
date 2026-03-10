import { useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react'
import { formatBytes } from '../lib/format'
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
  DirectPayload,
  IncomingTransfer,
  Message,
  OutgoingTransfer,
  PendingAttachment,
  PairingSession,
  PhoneEndpoint,
} from '../lib/types'

const PAIRING_API =
  import.meta.env.VITE_PAIRING_API_URL ??
  `${window.location.protocol}//${window.location.hostname}:8787`
const MAX_RECONNECT_ATTEMPTS = 5

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
  const eventSourceRef = useRef<EventSource | null>(null)
  const directSocketRef = useRef<WebSocket | null>(null)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const reconnectTimerRef = useRef<number | null>(null)
  const reconnectAttemptsRef = useRef(0)
  const shouldReconnectRef = useRef(true)
  const incomingTransfersRef = useRef<Map<string, IncomingTransfer>>(new Map())
  const outgoingTransfersRef = useRef<Map<string, OutgoingTransfer>>(new Map())

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
    const restored = restoreStoredEndpoint()
    if (restored) {
      setEndpoint(restored)
      setDirectStatus('正在恢复上一次连接')
      setPhase('connecting')
      setIsLoading(false)
    } else {
      void createSession()
    }

    return () => {
      eventSourceRef.current?.close()
      directSocketRef.current?.close()
      if (reconnectTimerRef.current) window.clearTimeout(reconnectTimerRef.current)
    }
  }, [])

  useEffect(() => {
    if (!session) return

    const timer = window.setInterval(() => {
      setCountdown(Math.max(0, Math.ceil((session.expiresAt - Date.now()) / 1000)))
    }, 250)

    return () => window.clearInterval(timer)
  }, [session])

  useEffect(() => {
    if (!endpoint) return

    persistEndpoint(endpoint)
    setPhase('connecting')
    setDirectStatus('正在连接手机')
    connectDirectSocket(endpoint)

    return () => {
      directSocketRef.current?.close()
      directSocketRef.current = null
    }
  }, [endpoint, settings.rememberConnection])

  useEffect(() => {
    persistSettings(settings)
  }, [settings])

  function releaseAttachmentPreviews(items: PendingAttachment[]) {
    for (const item of items) {
      if (item.previewUrl) {
        URL.revokeObjectURL(item.previewUrl)
      }
    }
  }

  function replaceTransferProgress(id: string, progress: number, size: number) {
    setMessages((current) =>
      current.map((message) =>
        message.id === id
          ? {
              ...message,
              meta: `${formatBytes(size)} • ${Math.round(progress * 100)}%`,
              progress,
            }
          : message,
      ),
    )
  }

  async function createSession(clearRemembered = true) {
    eventSourceRef.current?.close()
    shouldReconnectRef.current = false
    directSocketRef.current?.close()
    directSocketRef.current = null
    reconnectAttemptsRef.current = 0
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current)
      reconnectTimerRef.current = null
    }
    incomingTransfersRef.current.clear()
    outgoingTransfersRef.current.clear()
    setIsLoading(true)
    setError(null)
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
      const response = await fetch(`${PAIRING_API}/api/pairings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      if (!response.ok) throw new Error('创建配对会话失败')

      const data = (await response.json()) as PairingSession
      setSession(data)
      setCountdown(Math.max(0, Math.ceil((data.expiresAt - Date.now()) / 1000)))
      subscribeToSession(data.sessionId)
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '未知配对错误')
    } finally {
      setIsLoading(false)
    }
  }

  function disconnectToPairing() {
    void createSession()
  }

  function subscribeToSession(sessionId: string) {
    const source = new EventSource(`${PAIRING_API}/api/pairings/${sessionId}/events`)
    let isExpectedClose = false
    eventSourceRef.current = source

    source.addEventListener('status', (event) => {
      const payload = JSON.parse((event as MessageEvent).data) as {
        status: PairingSession['status']
        phoneEndpoint?: PhoneEndpoint
      }
      if (payload.phoneEndpoint) {
        setEndpoint(payload.phoneEndpoint)
      }
    })

    source.addEventListener('expired', () => {
      isExpectedClose = true
      source.close()
      void createSession(false)
    })

    source.onerror = () => {
      if (isExpectedClose) return
      setError('配对服务连接已断开。')
      source.close()
    }
  }

  function connectDirectSocket(nextEndpoint: PhoneEndpoint) {
    shouldReconnectRef.current = true
    directSocketRef.current?.close()

    const socket = new WebSocket(
      `ws://${nextEndpoint.phoneIp}:${nextEndpoint.phonePort}/ws?token=${encodeURIComponent(nextEndpoint.token)}`,
    )
    directSocketRef.current = socket

    socket.onopen = () => {
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

      for (const [transferId, outgoing] of outgoingTransfersRef.current.entries()) {
        socket.send(
          JSON.stringify({
            type: 'file_offer',
            transferId,
            sender: 'browser',
            batchId: outgoing.batchId,
            batchTotal: outgoing.batchTotal,
            name: outgoing.file.name,
            mimeType: outgoing.file.type || 'application/octet-stream',
            size: outgoing.file.size,
            chunkSize: outgoing.chunkSize,
            totalChunks: outgoing.totalChunks,
          }),
        )
      }
    }

    socket.onmessage = (event) => {
      const payload = JSON.parse(event.data) as DirectPayload

      if (payload.type === 'message') {
        setMessages((current) => [
          ...current,
          {
            id: `phone-${Date.now()}`,
            sender: 'phone',
            type: 'text',
            content: payload.text,
          },
        ])
        return
      }

      if (payload.type === 'file_offer') {
        if (!incomingTransfersRef.current.has(payload.transferId)) {
          incomingTransfersRef.current.set(payload.transferId, {
            name: payload.name,
            size: payload.size,
            mimeType: payload.mimeType,
            batchId: payload.batchId,
            batchTotal: payload.batchTotal,
            chunkSize: payload.chunkSize,
            totalChunks: payload.totalChunks,
            chunks: Array.from({ length: payload.totalChunks }, () => null),
          })
          setMessages((current) => [
            ...current,
            {
              id: payload.transferId,
              sender: 'phone',
              type: 'file',
              content: payload.name,
              batchId: payload.batchId,
              batchTotal: payload.batchTotal,
              meta: `${formatBytes(payload.size)} • 0%`,
              progress: 0,
              mimeType: payload.mimeType,
            },
          ])
        }

        const transfer = incomingTransfersRef.current.get(payload.transferId)
        let nextChunk = 0
        while (transfer && nextChunk < transfer.totalChunks && transfer.chunks[nextChunk]) {
          nextChunk += 1
        }
        socket.send(JSON.stringify({ type: 'file_resume', transferId: payload.transferId, nextChunk }))
        return
      }

      if (payload.type === 'file_resume') {
        const outgoing = outgoingTransfersRef.current.get(payload.transferId)
        if (outgoing) {
          replaceTransferProgress(
            payload.transferId,
            outgoing.totalChunks === 0 ? 0 : payload.nextChunk / outgoing.totalChunks,
            outgoing.file.size,
          )
          sendFileChunks(payload.transferId, outgoing, payload.nextChunk)
        }
        return
      }

      if (payload.type === 'file_chunk') {
        const transfer = incomingTransfersRef.current.get(payload.transferId)
        if (transfer && payload.chunkIndex >= 0 && payload.chunkIndex < transfer.totalChunks) {
          const chunk = Uint8Array.from(atob(payload.chunk), (char) => char.charCodeAt(0))
          transfer.chunks[payload.chunkIndex] ??= chunk
          const loaded = transfer.chunks.reduce((sum, chunkPart) => sum + (chunkPart?.byteLength ?? 0), 0)
          replaceTransferProgress(payload.transferId, loaded / transfer.size, transfer.size)

          let nextChunk = 0
          while (nextChunk < transfer.totalChunks && transfer.chunks[nextChunk]) {
            nextChunk += 1
          }
          socket.send(JSON.stringify({ type: 'file_resume', transferId: payload.transferId, nextChunk }))
        }
        return
      }

      if (payload.type === 'file_complete') {
        const transfer = incomingTransfersRef.current.get(payload.transferId)
        if (transfer) {
          const nextChunk = transfer.chunks.findIndex((chunk) => chunk === null)
          if (nextChunk !== -1) {
            socket.send(JSON.stringify({ type: 'file_resume', transferId: payload.transferId, nextChunk }))
            return
          }

          const blob = new Blob(
            transfer.chunks.map((chunk) => {
              const safeChunk = chunk ?? new Uint8Array()
              const buffer = new ArrayBuffer(safeChunk.byteLength)
              new Uint8Array(buffer).set(safeChunk)
              return buffer
            }),
            { type: transfer.mimeType },
          )
          const downloadUrl = URL.createObjectURL(blob)
          setMessages((current) =>
            current.map((message) =>
              message.id === payload.transferId
                ? {
                    ...message,
                    meta: `${formatBytes(transfer.size)} • 已接收`,
                    progress: 1,
                    downloadUrl,
                    mimeType: transfer.mimeType,
                  }
                : message,
            ),
          )
          incomingTransfersRef.current.delete(payload.transferId)
          socket.send(JSON.stringify({ type: 'file_received', transferId: payload.transferId }))
        }
        return
      }

      if (payload.type === 'file_received') {
        const outgoing = outgoingTransfersRef.current.get(payload.transferId)
        if (outgoing) {
          outgoingTransfersRef.current.delete(payload.transferId)
          setMessages((current) =>
            current.map((message) =>
              message.id === payload.transferId
                ? {
                    ...message,
                    meta: `${formatBytes(outgoing.file.size)} • 已发送`,
                    progress: 1,
                  }
                : message,
            ),
          )
        }
        return
      }

      if (payload.type === 'system' || payload.type === 'error') {
        setMessages((current) => [
          ...current,
          {
            id: `system-${Date.now()}`,
            sender: 'system',
            type: 'text',
            content: payload.text,
          },
        ])
      }
    }

    socket.onclose = () => {
      if (shouldReconnectRef.current && settings.autoReconnect && reconnectAttemptsRef.current < MAX_RECONNECT_ATTEMPTS) {
        reconnectAttemptsRef.current += 1
        const attempt = reconnectAttemptsRef.current
        setDirectStatus(`重连中 (${attempt}/${MAX_RECONNECT_ATTEMPTS})`)
        reconnectTimerRef.current = window.setTimeout(() => {
          connectDirectSocket(nextEndpoint)
        }, Math.min(1500 * attempt, 5000))
        return
      }

      setDirectStatus('连接已断开')
    }

    socket.onerror = () => {
      setDirectStatus('连接失败')
      setError('无法连接到手机，请确认手机仍在当前 Wi‑Fi 下且 App 保持打开。')
    }
  }

  const sendMessage = async () => {
    const socket = directSocketRef.current
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      setError('当前连接不可用。')
      return
    }

    if (pendingAttachments.length > 0) {
      const batch =
        pendingAttachments.length > 1
          ? { id: `batch-${Date.now()}`, total: pendingAttachments.length }
          : undefined

      for (const attachment of pendingAttachments) {
        await sendFile(attachment.file, batch)
      }
      setPendingAttachments((current) => {
        releaseAttachmentPreviews(current)
        return []
      })
      return
    }

    const text = draft.trim()
    if (!text) return

    socket.send(JSON.stringify({ type: 'message', text }))
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

  const sendFile = async (file: File, batch?: { id: string; total: number }) => {
    const socket = directSocketRef.current
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      setError('当前连接不可用。')
      return
    }

    const transferId = `file-${Date.now()}`
    const chunkSize = 32 * 1024
    const bytes = new Uint8Array(await file.arrayBuffer())
    const totalChunks = Math.ceil(bytes.length / chunkSize)

    outgoingTransfersRef.current.set(transferId, {
      file,
      bytes,
      batchId: batch?.id,
      batchTotal: batch?.total,
      chunkSize,
      totalChunks,
    })

    const localDownloadUrl = URL.createObjectURL(file)

    setMessages((current) => [
      ...current,
      {
        id: transferId,
        sender: 'browser',
        type: 'file',
        content: file.name,
        batchId: batch?.id,
        batchTotal: batch?.total,
        meta: `${formatBytes(file.size)} • 0%`,
        progress: 0,
        mimeType: file.type || 'application/octet-stream',
        downloadUrl: localDownloadUrl,
      },
    ])

    socket.send(
      JSON.stringify({
        type: 'file_offer',
        transferId,
        sender: 'browser',
        batchId: batch?.id,
        batchTotal: batch?.total,
        name: file.name,
        mimeType: file.type || 'application/octet-stream',
        size: file.size,
        chunkSize,
        totalChunks,
      }),
    )
  }

  function sendFileChunks(transferId: string, outgoing: OutgoingTransfer, startChunk: number) {
    const socket = directSocketRef.current
    if (!socket || socket.readyState !== WebSocket.OPEN) return

    if (startChunk >= outgoing.totalChunks) {
      socket.send(JSON.stringify({ type: 'file_complete', transferId }))
      return
    }

    for (let chunkIndex = startChunk; chunkIndex < outgoing.totalChunks; chunkIndex += 1) {
      const start = chunkIndex * outgoing.chunkSize
      const end = Math.min(start + outgoing.chunkSize, outgoing.bytes.length)
      const chunk = outgoing.bytes.slice(start, end)
      let binary = ''
      chunk.forEach((value) => {
        binary += String.fromCharCode(value)
      })
      socket.send(JSON.stringify({ type: 'file_chunk', transferId, chunkIndex, chunk: btoa(binary) }))
    }

    socket.send(JSON.stringify({ type: 'file_complete', transferId }))
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
