import { useEffect, useState, type ChangeEvent, type DragEvent, type KeyboardEvent, type RefObject } from 'react'
import type { PendingAttachment } from '../lib/types'

type ChatComposerProps = {
  canSend: boolean
  draft: string
  fileInputRef: RefObject<HTMLInputElement | null>
  pendingAttachments: PendingAttachment[]
  sendWithEnter: boolean
  onAppendFiles: (files: File[]) => void
  onDraftChange: (value: string) => void
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onOpenFilePicker: () => void
  onRemovePendingAttachment: (id: string) => void
  onSendMessage: () => void
}

export function ChatComposer({
  canSend,
  draft,
  fileInputRef,
  pendingAttachments,
  sendWithEnter,
  onAppendFiles,
  onDraftChange,
  onFileChange,
  onOpenFilePicker,
  onRemovePendingAttachment,
  onSendMessage,
}: ChatComposerProps) {
  const [isDraggingFiles, setIsDraggingFiles] = useState(false)
  const hasPendingAttachments = pendingAttachments.length > 0

  useEffect(() => {
    const handlePaste = (event: ClipboardEvent) => {
      const files = Array.from(event.clipboardData?.files ?? [])
      if (files.length === 0) return
      event.preventDefault()
      onAppendFiles(files)
    }

    window.addEventListener('paste', handlePaste)
    return () => window.removeEventListener('paste', handlePaste)
  }, [onAppendFiles])

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (sendWithEnter && event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      if (canSend) {
        onSendMessage()
      }
    }
  }

  const handleDrop = (event: DragEvent<HTMLElement>) => {
    event.preventDefault()
    setIsDraggingFiles(false)
    const files = Array.from(event.dataTransfer.files ?? [])
    if (files.length === 0) return
    onAppendFiles(files)
  }

  return (
    <footer
      className={`composer ${isDraggingFiles ? 'is-dragging-files' : ''} ${hasPendingAttachments ? 'has-pending-files' : ''}`}
      onDragEnter={(event) => {
        event.preventDefault()
        setIsDraggingFiles(true)
      }}
      onDragOver={(event) => event.preventDefault()}
      onDragLeave={(event) => {
        event.preventDefault()
        if (event.currentTarget === event.target) {
          setIsDraggingFiles(false)
        }
      }}
      onDrop={handleDrop}
    >
      <input ref={fileInputRef} hidden type="file" multiple onChange={onFileChange} />
      {hasPendingAttachments ? (
        <div className="pending-attachments">
          {pendingAttachments.map((attachment) => (
            <div key={attachment.id} className="pending-file-card">
              <button
                className="pending-file-remove"
                type="button"
                aria-label={`移除 ${attachment.name}`}
                onClick={() => onRemovePendingAttachment(attachment.id)}
              >
                ×
              </button>
              {attachment.previewUrl ? (
                <img className="pending-file-image" src={attachment.previewUrl} alt={attachment.name} />
              ) : (
                <div className="pending-file-icon">{fileKindLabel(attachment.name)}</div>
              )}
              <div className="pending-file-copy">
                <strong>{attachment.name}</strong>
                <small>{formatAttachmentMeta(attachment)}</small>
              </div>
            </div>
          ))}
        </div>
      ) : null}
      <button className="ghost-button composer-icon" type="button" onClick={onOpenFilePicker} aria-label="发送文件">
        ＋
      </button>
      <button className="ghost-button composer-icon" type="button" aria-label="表情" disabled={hasPendingAttachments}>
        ☺
      </button>
      <input
        value={draft}
        onChange={(event) => onDraftChange(event.target.value)}
        placeholder={hasPendingAttachments ? '已选择文件，点击发送后一起发出' : '按 Enter 发送消息...'}
        onKeyDown={handleKeyDown}
        disabled={!canSend || hasPendingAttachments}
      />
      <button className="primary-button composer-send" type="button" onClick={onSendMessage} disabled={!canSend}>
        <svg viewBox="0 0 24 24" aria-hidden="true" className="send-icon">
          <path
            d="M21 3 10 14"
            fill="none"
            stroke="currentColor"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
          <path
            d="m21 3-7 18-4-7-7-4 18-7Z"
            fill="none"
            stroke="currentColor"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
        </svg>
      </button>
    </footer>
  )
}

function formatAttachmentMeta(attachment: PendingAttachment) {
  const size = attachment.size >= 1024 * 1024
    ? `${(attachment.size / (1024 * 1024)).toFixed(1)} MB`
    : `${Math.max(1, Math.round(attachment.size / 1024))} KB`
  return size
}

function fileKindLabel(fileName: string) {
  const extension = fileName.split('.').pop()?.toUpperCase() ?? 'FILE'
  return extension.slice(0, 4)
}
