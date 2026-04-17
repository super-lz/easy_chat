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
  deviceInfo: string
  browserName: string
  verificationCode: string
  pairingUrl: string
}

export type PhoneEndpoint = {
  deviceName: string
  phoneIp: string
  phonePort: number
  token: string
  protocolVersion: number
}

export type IncomingTransfer = {
  name: string
  size: number
  mimeType: string
  compositionId?: string
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
  compositionId?: string
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

export type DirectConnectionState = {
  kind: 'idle' | 'restoring' | 'reconnecting' | 'connected' | 'failed'
  label: string
}

export type DirectPayload =
  | { type: 'system'; text: string }
  | {
      type: 'peer_meta'
      sender?: 'phone' | 'browser'
      role?: 'phone' | 'browser'
      name: string
      address?: string
      deviceInfo?: string
    }
  | {
      type: 'message'
      sender?: 'phone' | 'browser'
      text: string
      compositionId?: string
    }
  | {
      type: 'file_offer'
      transferId: string
      sender?: 'phone' | 'browser'
      compositionId?: string
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
  | { type: 'disconnect'; sender?: 'phone' | 'browser' }
  | { type: 'pong' }
  | { type: 'error'; text: string }
