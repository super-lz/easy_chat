import { useMemo, useState, type ChangeEvent, type RefObject } from 'react'
import type { AppSettings, Message, PendingAttachment } from '../lib/types'
import { ChatComposer } from './ChatComposer'
import { ImagePreviewLightbox, type PreviewSlide } from './ImagePreviewLightbox'
import { MessageList } from './MessageList'
import { ChatSidebar } from './ChatSidebar'

type ChatScreenProps = {
  canCompose: boolean
  canSend: boolean
  connectionAddress: string
  conversationTitle: string
  directStatus: string
  draft: string
  error: string | null
  fileInputRef: RefObject<HTMLInputElement | null>
  localDeviceName: string
  messages: Message[]
  pageOrigin: string
  pairingServiceOrigin: string
  pendingAttachments: PendingAttachment[]
  settings: AppSettings
  onAppendFiles: (files: File[]) => void
  onDisconnect: () => void
  onDraftChange: (value: string) => void
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onOpenFilePicker: () => void
  onRemovePendingAttachment: (id: string) => void
  onSendMessage: () => void
}

export function ChatScreen({
  canCompose,
  canSend,
  connectionAddress,
  conversationTitle,
  directStatus,
  draft,
  error,
  fileInputRef,
  localDeviceName,
  messages,
  pageOrigin,
  pairingServiceOrigin,
  pendingAttachments,
  settings,
  onAppendFiles,
  onDisconnect,
  onDraftChange,
  onFileChange,
  onOpenFilePicker,
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
        connectionAddress={connectionAddress}
        conversationTitle={conversationTitle}
        directStatus={directStatus}
        error={error}
        localDeviceName={localDeviceName}
        pageOrigin={pageOrigin}
        pairingServiceOrigin={pairingServiceOrigin}
        onDisconnect={onDisconnect}
      />

      <section className="chat-main">
        <header className="chat-toolbar">
          <h2>{conversationTitle}</h2>
          <button className="toolbar-more" type="button" aria-label="更多">
            •••
          </button>
        </header>

        <MessageList messages={messages} onOpenImagePreview={openImagePreview} />

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
