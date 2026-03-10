import type { ChangeEvent, RefObject } from 'react'
import type { AppSettings, Message, PendingAttachment } from '../lib/types'
import { ChatComposer } from './ChatComposer'
import { MessageList } from './MessageList'
import { ChatSidebar } from './ChatSidebar'

type ChatScreenProps = {
  canSend: boolean
  conversationTitle: string
  directStatus: string
  draft: string
  fileInputRef: RefObject<HTMLInputElement | null>
  localDeviceName: string
  messages: Message[]
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
  conversationTitle,
  directStatus,
  draft,
  fileInputRef,
  localDeviceName,
  messages,
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
        conversationTitle={conversationTitle}
        directStatus={directStatus}
        localDeviceName={localDeviceName}
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
