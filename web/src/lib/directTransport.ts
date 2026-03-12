import type { DirectPayload, IncomingTransfer, OutgoingTransfer, PhoneEndpoint } from './types'

const DEFAULT_CHUNK_SIZE = 128 * 1024

export type FileBatch = {
  id: string
  total: number
}

export type OutgoingFileDescriptor = {
  transferId: string
  file: File
  batchId?: string
  batchTotal?: number
  mimeType: string
  size: number
}

export type IncomingFileStart = {
  transferId: string
  name: string
  size: number
  mimeType: string
  batchId?: string
  batchTotal?: number
}

export type FileProgressEvent = {
  transferId: string
  size: number
  progress: number
}

export type FileCanceledEvent = {
  transferId: string
  size: number
  batchId?: string
  batchTotal?: number
}

export type IncomingFileComplete = {
  transferId: string
  name: string
  size: number
  mimeType: string
  batchId?: string
  batchTotal?: number
  downloadUrl: string
}

type DirectTransportCallbacks = {
  onOpen: (endpoint: PhoneEndpoint) => void
  onTextMessage: (text: string) => void
  onIncomingFileStart: (event: IncomingFileStart) => void
  onIncomingFileProgress: (event: FileProgressEvent) => void
  onIncomingFileComplete: (event: IncomingFileComplete) => void
  onOutgoingFileProgress: (event: FileProgressEvent) => void
  onOutgoingFileDelivered: (event: { transferId: string; size: number }) => void
  onFileCanceled: (event: FileCanceledEvent & { sender: 'browser' | 'phone' }) => void
  onSystemMessage: (text: string) => void
  onProtocolError: (text: string) => void
  onConnectionError: () => void
  onClose: (context: { opened: boolean }) => void
}

export class DirectTransportClient {
  private socket: WebSocket | null = null
  private connectTimer: number | null = null
  private incomingTransfers = new Map<string, IncomingTransfer>()
  private outgoingTransfers = new Map<string, OutgoingTransfer>()
  private opened = false
  private readonly callbacks: DirectTransportCallbacks

  constructor(callbacks: DirectTransportCallbacks) {
    this.callbacks = callbacks
  }

  connect(endpoint: PhoneEndpoint, timeoutMs: number) {
    this.disconnect()
    this.opened = false

    const socket = new WebSocket(
      `ws://${endpoint.phoneIp}:${endpoint.phonePort}/ws?token=${encodeURIComponent(endpoint.token)}`,
    )
    this.socket = socket
    this.connectTimer = window.setTimeout(() => {
      if (this.socket !== socket || socket.readyState !== WebSocket.CONNECTING) return
      socket.close()
    }, timeoutMs)

    socket.onopen = () => {
      this.opened = true
      this.clearConnectTimer()
      this.callbacks.onOpen(endpoint)

      for (const [transferId, outgoing] of this.outgoingTransfers.entries()) {
        this.sendFileOffer(socket, transferId, outgoing)
      }
    }

    socket.onmessage = (event) => {
      this.handleMessage(event.data)
    }

    socket.onclose = () => {
      this.clearConnectTimer()
      if (this.socket === socket) {
        this.socket = null
      }
      this.callbacks.onClose({ opened: this.opened })
    }

    socket.onerror = () => {
      this.callbacks.onConnectionError()
    }
  }

  disconnect() {
    this.clearConnectTimer()
    this.socket?.close()
    this.socket = null
    this.opened = false
  }

  isOpen() {
    return this.socket?.readyState === WebSocket.OPEN
  }

  sendText(text: string) {
    const socket = this.requireOpenSocket()
    socket.send(JSON.stringify({ type: 'message', text }))
  }

  async queueFile(file: File, batch?: FileBatch) {
    const bytes = new Uint8Array(await file.arrayBuffer())
    const transferId = `file-${Date.now()}`
    const mimeType = file.type || 'application/octet-stream'
    const totalChunks = Math.ceil(bytes.length / DEFAULT_CHUNK_SIZE)

    this.outgoingTransfers.set(transferId, {
      transferId,
      file,
      bytes,
      batchId: batch?.id,
      batchTotal: batch?.total,
      chunkSize: DEFAULT_CHUNK_SIZE,
      totalChunks,
      nextChunk: 0,
      isSending: false,
    })

    const descriptor: OutgoingFileDescriptor = {
      transferId,
      file,
      batchId: batch?.id,
      batchTotal: batch?.total,
      mimeType,
      size: file.size,
    }

    const socket = this.requireOpenSocket()
    this.sendFileOffer(socket, transferId, this.outgoingTransfers.get(transferId)!)
    return descriptor
  }

  resetTransfers() {
    this.incomingTransfers.clear()
    this.outgoingTransfers.clear()
  }

  cancelTransfer(transferId: string) {
    const outgoing = this.outgoingTransfers.get(transferId)
    if (outgoing) {
      this.outgoingTransfers.delete(transferId)
      this.sendTransferCancel(transferId)
      this.callbacks.onFileCanceled({
        transferId,
        size: outgoing.file.size,
        batchId: outgoing.batchId,
        batchTotal: outgoing.batchTotal,
        sender: 'browser',
      })
      return true
    }

    const incoming = this.incomingTransfers.get(transferId)
    if (incoming) {
      this.incomingTransfers.delete(transferId)
      this.sendTransferCancel(transferId)
      this.callbacks.onFileCanceled({
        transferId,
        size: incoming.size,
        batchId: incoming.batchId,
        batchTotal: incoming.batchTotal,
        sender: 'phone',
      })
      return true
    }

    return false
  }

  cancelTransfers(transferIds: string[]) {
    let cancelled = false
    for (const transferId of transferIds) {
      cancelled = this.cancelTransfer(transferId) || cancelled
    }
    return cancelled
  }

  private handleMessage(raw: string) {
    const payload = JSON.parse(raw) as DirectPayload

    if (payload.type === 'message') {
      this.callbacks.onTextMessage(payload.text)
      return
    }

    if (payload.type === 'file_offer') {
      this.handleFileOffer(payload)
      return
    }

    if (payload.type === 'file_resume') {
      this.handleFileResume(payload.transferId, payload.nextChunk)
      return
    }

    if (payload.type === 'file_chunk') {
      this.handleFileChunk(payload.transferId, payload.chunkIndex, payload.chunk)
      return
    }

    if (payload.type === 'file_complete') {
      this.handleFileComplete(payload.transferId)
      return
    }

    if (payload.type === 'file_received') {
      this.handleFileReceived(payload.transferId)
      return
    }

    if (payload.type === 'file_cancel') {
      this.handleFileCancel(payload.transferId)
      return
    }

    if (payload.type === 'system') {
      this.callbacks.onSystemMessage(payload.text)
      return
    }

    if (payload.type === 'error') {
      this.callbacks.onProtocolError(payload.text)
    }
  }

  private handleFileOffer(payload: Extract<DirectPayload, { type: 'file_offer' }>) {
    if (!this.incomingTransfers.has(payload.transferId)) {
      this.incomingTransfers.set(payload.transferId, {
        name: payload.name,
        size: payload.size,
        mimeType: payload.mimeType,
        batchId: payload.batchId,
        batchTotal: payload.batchTotal,
        chunkSize: payload.chunkSize,
        totalChunks: payload.totalChunks,
        chunks: Array.from({ length: payload.totalChunks }, () => null),
      })
      this.callbacks.onIncomingFileStart({
        transferId: payload.transferId,
        name: payload.name,
        size: payload.size,
        mimeType: payload.mimeType,
        batchId: payload.batchId,
        batchTotal: payload.batchTotal,
      })
    }

    const transfer = this.incomingTransfers.get(payload.transferId)
    let nextChunk = 0
    while (transfer && nextChunk < transfer.totalChunks && transfer.chunks[nextChunk]) {
      nextChunk += 1
    }
    this.requireOpenSocket().send(JSON.stringify({ type: 'file_resume', transferId: payload.transferId, nextChunk }))
  }

  private handleFileResume(transferId: string, nextChunk: number) {
    const outgoing = this.outgoingTransfers.get(transferId)
    if (!outgoing) return

    outgoing.nextChunk = nextChunk

    this.callbacks.onOutgoingFileProgress({
      transferId,
      size: outgoing.file.size,
      progress: outgoing.totalChunks === 0 ? 0 : nextChunk / outgoing.totalChunks,
    })

    this.scheduleChunkPump(outgoing)
  }

  private handleFileChunk(transferId: string, chunkIndex: number, encodedChunk: string) {
    const transfer = this.incomingTransfers.get(transferId)
    if (!transfer || chunkIndex < 0 || chunkIndex >= transfer.totalChunks) {
      return
    }

    transfer.chunks[chunkIndex] ??= Uint8Array.from(atob(encodedChunk), (char) => char.charCodeAt(0))
    const loaded = transfer.chunks.reduce((sum, chunk) => sum + (chunk?.byteLength ?? 0), 0)
    this.callbacks.onIncomingFileProgress({
      transferId,
      size: transfer.size,
      progress: transfer.size === 0 ? 0 : loaded / transfer.size,
    })
  }

  private handleFileComplete(transferId: string) {
    const transfer = this.incomingTransfers.get(transferId)
    if (!transfer) return

    const nextChunk = transfer.chunks.findIndex((chunk) => chunk === null)
    if (nextChunk !== -1) {
      this.requireOpenSocket().send(JSON.stringify({ type: 'file_resume', transferId, nextChunk }))
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

    this.incomingTransfers.delete(transferId)
    this.requireOpenSocket().send(JSON.stringify({ type: 'file_received', transferId }))
    this.callbacks.onIncomingFileComplete({
      transferId,
      name: transfer.name,
      size: transfer.size,
      mimeType: transfer.mimeType,
      batchId: transfer.batchId,
      batchTotal: transfer.batchTotal,
      downloadUrl: URL.createObjectURL(blob),
    })
  }

  private handleFileReceived(transferId: string) {
    const outgoing = this.outgoingTransfers.get(transferId)
    if (!outgoing) return

    this.outgoingTransfers.delete(transferId)
    this.callbacks.onOutgoingFileDelivered({ transferId, size: outgoing.file.size })
  }

  private handleFileCancel(transferId: string) {
    const outgoing = this.outgoingTransfers.get(transferId)
    if (outgoing) {
      this.outgoingTransfers.delete(transferId)
      this.callbacks.onFileCanceled({
        transferId,
        size: outgoing.file.size,
        batchId: outgoing.batchId,
        batchTotal: outgoing.batchTotal,
        sender: 'browser',
      })
      return
    }

    const incoming = this.incomingTransfers.get(transferId)
    if (!incoming) return

    this.incomingTransfers.delete(transferId)
    this.callbacks.onFileCanceled({
      transferId,
      size: incoming.size,
      batchId: incoming.batchId,
      batchTotal: incoming.batchTotal,
      sender: 'phone',
    })
  }

  private sendFileOffer(socket: WebSocket, transferId: string, outgoing: OutgoingTransfer) {
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

  private scheduleChunkPump(outgoing: OutgoingTransfer) {
    if (outgoing.isSending) return
    outgoing.isSending = true
    window.setTimeout(() => {
      this.pumpFileChunks(outgoing.transferId)
    }, 0)
  }

  private pumpFileChunks(transferId: string) {
    const outgoing = this.outgoingTransfers.get(transferId)
    if (!outgoing) return

    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      outgoing.isSending = false
      return
    }

    const socket = this.socket
    const chunksPerTick = 4

    if (outgoing.nextChunk >= outgoing.totalChunks) {
      outgoing.isSending = false
      socket.send(JSON.stringify({ type: 'file_complete', transferId }))
      return
    }

    const endChunk = Math.min(outgoing.nextChunk + chunksPerTick, outgoing.totalChunks)

    for (let chunkIndex = outgoing.nextChunk; chunkIndex < endChunk; chunkIndex += 1) {
      if (!this.outgoingTransfers.has(transferId)) {
        return
      }
      const start = chunkIndex * outgoing.chunkSize
      const end = Math.min(start + outgoing.chunkSize, outgoing.bytes.length)
      const chunk = outgoing.bytes.slice(start, end)
      let binary = ''
      chunk.forEach((value) => {
        binary += String.fromCharCode(value)
      })
      socket.send(JSON.stringify({ type: 'file_chunk', transferId, chunkIndex, chunk: btoa(binary) }))
      outgoing.nextChunk = chunkIndex + 1
    }

    if (!this.outgoingTransfers.has(transferId)) {
      return
    }

    outgoing.isSending = false

    if (outgoing.nextChunk >= outgoing.totalChunks) {
      socket.send(JSON.stringify({ type: 'file_complete', transferId }))
      return
    }

    this.scheduleChunkPump(outgoing)
  }

  private sendTransferCancel(transferId: string) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return
    this.socket.send(JSON.stringify({ type: 'file_cancel', transferId }))
  }

  private requireOpenSocket() {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error('当前连接不可用。')
    }
    return this.socket
  }

  private clearConnectTimer() {
    if (this.connectTimer !== null) {
      window.clearTimeout(this.connectTimer)
      this.connectTimer = null
    }
  }
}
