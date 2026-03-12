import { useMemo, useState, type ChangeEvent, type RefObject } from 'react'
import type { AppSettings, DirectConnectionState, Message, PendingAttachment } from '../lib/types'
import { ChatComposer } from './ChatComposer'
import { ImagePreviewLightbox, type PreviewSlide } from './ImagePreviewLightbox'
import { MessageList } from './MessageList'
import { ChatSidebar } from './ChatSidebar'

type ChatScreenProps = {
  browserIp: string
  browserPort: string
  canCompose: boolean
  canSend: boolean
  conversationTitle: string
  connectionState: DirectConnectionState
  draft: string
  error: string | null
  fileInputRef: RefObject<HTMLInputElement | null>
  localDeviceName: string
  messages: Message[]
  pendingAttachments: PendingAttachment[]
  phoneIp: string
  phonePort: string
  settings: AppSettings
  onAppendFiles: (files: File[]) => void
  onDisconnect: () => void
  onDraftChange: (value: string) => void
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onOpenFilePicker: () => void
  onCancelBatchTransfers: (batchId: string) => void
  onCancelFileTransfer: (transferId: string) => void
  onClearPendingAttachments: () => void
  onRemovePendingAttachment: (id: string) => void
  onSendMessage: () => void
}

export function ChatScreen({
  browserIp,
  browserPort,
  canCompose,
  canSend,
  conversationTitle,
  connectionState,
  draft,
  error,
  fileInputRef,
  localDeviceName,
  messages,
  pendingAttachments,
  phoneIp,
  phonePort,
  settings,
  onAppendFiles,
  onDisconnect,
  onDraftChange,
  onFileChange,
  onOpenFilePicker,
  onCancelBatchTransfers,
  onCancelFileTransfer,
  onClearPendingAttachments,
  onRemovePendingAttachment,
  onSendMessage,
}: ChatScreenProps) {
  const [previewRequest, setPreviewRequest] = useState<{
    key: string
    slides: PreviewSlide[]
    index: number
  } | null>(null)
  const hasPreviewOpen = previewRequest !== null
  const openImagePreview = useMemo(
    () => (slides: PreviewSlide[], index: number) => {
      setPreviewRequest({
        key: `${Date.now()}-${slides.map((slide) => slide.id).join('|')}`,
        slides,
        index,
      })
    },
    [],
  )

  return (
    <section className="chat-layout">
      <ChatSidebar
        browserIp={browserIp}
        browserName={localDeviceName}
        browserPort={browserPort}
        connectionState={connectionState}
        error={error}
        phoneIp={phoneIp}
        phoneName={conversationTitle}
        phonePort={phonePort}
        onDisconnect={onDisconnect}
      />

      <section className="chat-main">
        <MessageList
          messages={messages}
          onCancelBatchTransfers={onCancelBatchTransfers}
          onCancelFileTransfer={onCancelFileTransfer}
          onOpenImagePreview={openImagePreview}
        />

        <ChatComposer
          canCompose={canCompose}
          canSend={canSend}
          draft={draft}
          fileInputRef={fileInputRef}
          pendingAttachments={pendingAttachments}
          sendWithEnter={settings.sendWithEnter}
          onAppendFiles={onAppendFiles}
          onDraftChange={onDraftChange}
          onFileChange={onFileChange}
          onOpenImagePreview={openImagePreview}
          onOpenFilePicker={onOpenFilePicker}
          onClearPendingAttachments={onClearPendingAttachments}
          onRemovePendingAttachment={onRemovePendingAttachment}
          onSendMessage={onSendMessage}
        />

        {hasPreviewOpen ? (
          <ImagePreviewLightbox
            key={previewRequest.key}
            openIndex={previewRequest.index}
            slides={previewRequest.slides}
            onClose={() => setPreviewRequest(null)}
          />
        ) : null}
      </section>
    </section>
  )
}
