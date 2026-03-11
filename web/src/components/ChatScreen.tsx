import type { ChangeEvent, RefObject } from 'react'
import type { AppSettings, Message, PendingAttachment } from '../lib/types'
import { ChatComposer } from './ChatComposer'
import { MessageList } from './MessageList'
import { ChatSidebar } from './ChatSidebar'

type ChatScreenProps = {
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

        <MessageList messages={messages} />

        <ChatComposer
          canSend={canSend}
          draft={draft}
          fileInputRef={fileInputRef}
          pendingAttachments={pendingAttachments}
          sendWithEnter={settings.sendWithEnter}
          onAppendFiles={onAppendFiles}
          onDraftChange={onDraftChange}
          onFileChange={onFileChange}
          onOpenFilePicker={onOpenFilePicker}
          onRemovePendingAttachment={onRemovePendingAttachment}
          onSendMessage={onSendMessage}
        />
      </section>
    </section>
  )
}
