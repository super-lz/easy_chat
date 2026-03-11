import { useEffect, useRef, useState, type ChangeEvent, type DragEvent, type KeyboardEvent, type RefObject } from 'react'
import EmojiPicker, { Categories, SuggestionMode, Theme, type EmojiClickData } from 'emoji-picker-react'
import zhEmojiData from 'emoji-picker-react/src/data/emojis-zh.json'
import { Plus, Smile, X } from 'lucide-react'
import type { PendingAttachment } from '../lib/types'
import type { PreviewSlide } from './ImagePreviewLightbox'

const localizedEmojiData = zhEmojiData as Parameters<typeof EmojiPicker>[0]['emojiData']

type ChatComposerProps = {
  canCompose: boolean
  canSend: boolean
  draft: string
  fileInputRef: RefObject<HTMLInputElement | null>
  pendingAttachments: PendingAttachment[]
  sendWithEnter: boolean
  onAppendFiles: (files: File[]) => void
  onDraftChange: (value: string) => void
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onOpenImagePreview: (slides: PreviewSlide[], index: number) => void
  onOpenFilePicker: () => void
  onRemovePendingAttachment: (id: string) => void
  onSendMessage: () => void
}

export function ChatComposer({
  canCompose,
  canSend,
  draft,
  fileInputRef,
  pendingAttachments,
  sendWithEnter,
  onAppendFiles,
  onDraftChange,
  onFileChange,
  onOpenImagePreview,
  onOpenFilePicker,
  onRemovePendingAttachment,
  onSendMessage,
}: ChatComposerProps) {
  const [isDraggingFiles, setIsDraggingFiles] = useState(false)
  const [isEmojiPickerOpen, setIsEmojiPickerOpen] = useState(false)
  const composerInputRef = useRef<HTMLInputElement | null>(null)
  const emojiPopoverRef = useRef<HTMLDivElement | null>(null)
  const hasPendingAttachments = pendingAttachments.length > 0
  const pendingPreviewSlides = pendingAttachments
    .filter((attachment) => attachment.previewUrl)
    .map((attachment) => ({
      id: attachment.id,
      src: attachment.previewUrl!,
      alt: attachment.name,
      title: attachment.name,
      description: formatAttachmentMeta(attachment),
    })) satisfies PreviewSlide[]
  const pendingPreviewIndexById = new Map(pendingPreviewSlides.map((slide, index) => [slide.id, index]))

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

  useEffect(() => {
    if (!isEmojiPickerOpen) return

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node | null
      if (!target) return
      if (emojiPopoverRef.current?.contains(target)) return
      setIsEmojiPickerOpen(false)
    }

    document.addEventListener('mousedown', handlePointerDown)
    return () => document.removeEventListener('mousedown', handlePointerDown)
  }, [isEmojiPickerOpen])

  useEffect(() => {
    if (canCompose) return
    setIsEmojiPickerOpen(false)
  }, [canCompose])

  useEffect(() => {
    if (!hasPendingAttachments) return
    window.requestAnimationFrame(() => {
      composerInputRef.current?.focus()
    })
  }, [hasPendingAttachments])

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
    window.requestAnimationFrame(() => {
      composerInputRef.current?.focus()
    })
  }

  const handleFileInputChange = (event: ChangeEvent<HTMLInputElement>) => {
    onFileChange(event)
    fileInputRef.current?.blur()
    window.requestAnimationFrame(() => {
      composerInputRef.current?.focus()
    })
  }

  const openPendingPreview = (attachmentId: string) => {
    const nextIndex = pendingPreviewIndexById.get(attachmentId)
    if (typeof nextIndex === 'number') {
      onOpenImagePreview(pendingPreviewSlides, nextIndex)
    }
  }

  const insertEmoji = (emojiData: EmojiClickData) => {
    const input = composerInputRef.current
    const selectionStart = input?.selectionStart ?? draft.length
    const selectionEnd = input?.selectionEnd ?? draft.length
    const nextDraft = `${draft.slice(0, selectionStart)}${emojiData.emoji}${draft.slice(selectionEnd)}`
    const nextCursor = selectionStart + emojiData.emoji.length

    onDraftChange(nextDraft)

    window.requestAnimationFrame(() => {
      composerInputRef.current?.focus()
      composerInputRef.current?.setSelectionRange(nextCursor, nextCursor)
    })
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
      <input ref={fileInputRef} hidden type="file" multiple onChange={handleFileInputChange} />
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
                <X aria-hidden="true" />
              </button>
              {attachment.previewUrl ? (
                <button
                  type="button"
                  className="image-preview-trigger pending-file-image-trigger"
                  onClick={() => openPendingPreview(attachment.id)}
                  aria-label={`预览图片 ${attachment.name}`}
                >
                  <img className="pending-file-image" src={attachment.previewUrl} alt={attachment.name} />
                </button>
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
      <button
        className="ghost-button composer-icon"
        type="button"
        onClick={() => {
          onOpenFilePicker()
          fileInputRef.current?.blur()
        }}
        aria-label="发送文件"
        disabled={!canCompose}
      >
        <Plus aria-hidden="true" />
      </button>
      <div className="composer-emoji" ref={emojiPopoverRef}>
        <button
          className={`ghost-button composer-icon ${isEmojiPickerOpen ? 'is-active' : ''}`}
          type="button"
          aria-label="表情"
          aria-expanded={isEmojiPickerOpen}
          onClick={() => setIsEmojiPickerOpen((current) => !current)}
          disabled={!canCompose}
        >
          <Smile aria-hidden="true" />
        </button>
        {isEmojiPickerOpen ? (
          <div className="emoji-picker-popover">
            <EmojiPicker
              onEmojiClick={insertEmoji}
              theme={Theme.LIGHT}
              emojiData={localizedEmojiData}
              skinTonesDisabled
              lazyLoadEmojis
              searchPlaceholder="搜索表情"
              suggestedEmojisMode={SuggestionMode.RECENT}
              categories={[
                { category: Categories.SUGGESTED, name: '最近使用' },
                { category: Categories.SMILEYS_PEOPLE, name: '笑脸与人物' },
                { category: Categories.ANIMALS_NATURE, name: '动物与自然' },
                { category: Categories.FOOD_DRINK, name: '食物与饮品' },
                { category: Categories.TRAVEL_PLACES, name: '出行与地点' },
                { category: Categories.ACTIVITIES, name: '活动' },
                { category: Categories.OBJECTS, name: '物品' },
                { category: Categories.SYMBOLS, name: '符号' },
                { category: Categories.FLAGS, name: '旗帜' },
              ]}
              previewConfig={{ showPreview: false }}
            />
          </div>
        ) : null}
      </div>
      <input
        ref={composerInputRef}
        value={draft}
        onChange={(event) => onDraftChange(event.target.value)}
        placeholder={hasPendingAttachments ? '可继续输入文字或表情，发送后会和文件一起发出' : '按 Enter 发送消息...'}
        onKeyDown={handleKeyDown}
        disabled={!canCompose}
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
