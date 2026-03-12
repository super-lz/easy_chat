export type Message = {
  id: string
  sender: 'browser' | 'phone' | 'system'
  type: 'text' | 'file'
  content: string
  compositionId?: string
  batchId?: string
  batchTotal?: number
  meta?: string
  downloadUrl?: string
  progress?: number
  mimeType?: string
  transferState?: 'transferring' | 'completed' | 'cancelled'
}

export type PendingAttachment = {
  id: string
  file: File
  name: string
  size: number
  mimeType: string
  previewUrl?: string
}

export type PairingSession = {
  sessionId: string
  challenge: string
  expiresAt: number
  status: 'waiting' | 'phone_registered'
  pairingUrl: string
}

export type PhoneEndpoint = {
  deviceName: string
  phoneIp: string
  phonePort: number
  token: string
  wifiName: string
  protocolVersion: number
}

export type IncomingTransfer = {
  name: string
  size: number
  mimeType: string
  batchId?: string
  batchTotal?: number
  chunkSize: number
  totalChunks: number
  receivedBytes: number
  chunks: Array<Uint8Array | null>
}

export type OutgoingTransfer = {
  transferId: string
  file: File
  batchId?: string
  batchTotal?: number
  chunkSize: number
  totalChunks: number
  nextChunk: number
  isSending: boolean
}

export type AppSettings = {
  rememberConnection: boolean
  autoReconnect: boolean
  sendWithEnter: boolean
  showSystemMessages: boolean
}

export type DirectPayload =
  | { type: 'system'; text: string }
  | { type: 'message'; sender?: 'phone' | 'browser'; text: string }
  | {
      type: 'file_offer'
      transferId: string
      sender?: 'phone' | 'browser'
      batchId?: string
      batchTotal?: number
      name: string
      mimeType: string
      size: number
      chunkSize: number
      totalChunks: number
    }
  | { type: 'file_resume'; transferId: string; nextChunk: number }
  | { type: 'file_chunk'; transferId: string; chunkIndex: number; chunk: string }
  | { type: 'file_complete'; transferId: string }
  | { type: 'file_received'; transferId: string }
  | { type: 'file_cancel'; transferId: string }
  | { type: 'pong' }
  | { type: 'error'; text: string }
