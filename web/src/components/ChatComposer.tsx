import { memo, useEffect, useMemo, useRef, useState, type ChangeEvent, type DragEvent, type KeyboardEvent, type RefObject } from 'react'
import EmojiPicker, { Categories, SuggestionMode, Theme, type EmojiClickData } from 'emoji-picker-react'
import zhEmojiData from 'emoji-picker-react/src/data/emojis-zh.json'
import { ChevronDown, ChevronUp, Plus, Smile, Trash2, X } from 'lucide-react'
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
  onClearPendingAttachments: () => void
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
  onClearPendingAttachments,
  onRemovePendingAttachment,
  onSendMessage,
}: ChatComposerProps) {
  const [isDraggingFiles, setIsDraggingFiles] = useState(false)
  const [isEmojiPickerOpen, setIsEmojiPickerOpen] = useState(false)
  const [isPendingAttachmentsCollapsed, setIsPendingAttachmentsCollapsed] = useState(false)
  const composerInputRef = useRef<HTMLTextAreaElement | null>(null)
  const emojiPopoverRef = useRef<HTMLDivElement | null>(null)
  const selectionRangeRef = useRef({ start: draft.length, end: draft.length })
  const hasPendingAttachments = pendingAttachments.length > 0
  const pendingPreviewSlides = useMemo(
    () =>
      pendingAttachments
        .filter((attachment) => attachment.previewUrl)
        .map((attachment) => ({
          id: attachment.id,
          src: attachment.previewUrl!,
          alt: attachment.name,
          title: attachment.name,
          description: formatAttachmentMeta(attachment),
        })) satisfies PreviewSlide[],
    [pendingAttachments],
  )
  const pendingPreviewIndexById = useMemo(
    () => new Map(pendingPreviewSlides.map((slide, index) => [slide.id, index])),
    [pendingPreviewSlides],
  )

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

  useEffect(() => {
    if (draft.length < selectionRangeRef.current.start) {
      selectionRangeRef.current = { start: draft.length, end: draft.length }
    }
  }, [draft])

  useEffect(() => {
    const input = composerInputRef.current
    if (!input) return

    input.style.height = 'auto'
    const computedStyle = window.getComputedStyle(input)
    const lineHeight = Number.parseFloat(computedStyle.lineHeight) || 24
    const paddingTop = Number.parseFloat(computedStyle.paddingTop) || 0
    const paddingBottom = Number.parseFloat(computedStyle.paddingBottom) || 0
    const borderTop = Number.parseFloat(computedStyle.borderTopWidth) || 0
    const borderBottom = Number.parseFloat(computedStyle.borderBottomWidth) || 0
    const maxHeight = lineHeight * 4 + paddingTop + paddingBottom + borderTop + borderBottom
    const nextHeight = Math.min(input.scrollHeight, maxHeight)

    input.style.height = `${nextHeight}px`
    input.style.overflowY = input.scrollHeight > maxHeight ? 'auto' : 'hidden'
    const selectionEnd = input.selectionEnd ?? draft.length
    const isCursorAtEnd = selectionEnd >= draft.length

    if (input.scrollHeight > maxHeight && isCursorAtEnd) {
      input.scrollTop = input.scrollHeight
    }
  }, [draft])

  const handleKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key !== 'Enter') return

    if (event.metaKey || event.ctrlKey) {
      event.preventDefault()
      const selectionStart = event.currentTarget.selectionStart ?? draft.length
      const selectionEnd = event.currentTarget.selectionEnd ?? draft.length
      const nextDraft = `${draft.slice(0, selectionStart)}\n${draft.slice(selectionEnd)}`
      const nextCursor = selectionStart + 1
      selectionRangeRef.current = { start: nextCursor, end: nextCursor }
      onDraftChange(nextDraft)
      window.requestAnimationFrame(() => {
        const input = composerInputRef.current
        if (!input) return
        input.focus()
        input.setSelectionRange(nextCursor, nextCursor)
        input.scrollTop = input.scrollHeight
      })
      return
    }

    if (sendWithEnter && !event.shiftKey) {
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
    const { start, end } = selectionRangeRef.current
    const selectionStart = Math.min(start, draft.length)
    const selectionEnd = Math.min(end, draft.length)
    const nextDraft = `${draft.slice(0, selectionStart)}${emojiData.emoji}${draft.slice(selectionEnd)}`
    const nextCursor = selectionStart + emojiData.emoji.length

    selectionRangeRef.current = { start: nextCursor, end: nextCursor }
    onDraftChange(nextDraft)
  }

  const syncSelectionRange = () => {
    const input = composerInputRef.current
    if (!input) return
    selectionRangeRef.current = {
      start: input.selectionStart ?? draft.length,
      end: input.selectionEnd ?? draft.length,
    }
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
        <div className="pending-attachments-shell">
          <div className="pending-attachments-toolbar">
            <button
              type="button"
              className="pending-toolbar-button"
              onClick={() => setIsPendingAttachmentsCollapsed((current) => !current)}
              aria-expanded={!isPendingAttachmentsCollapsed}
            >
              {isPendingAttachmentsCollapsed ? <ChevronUp aria-hidden="true" /> : <ChevronDown aria-hidden="true" />}
              <span>{isPendingAttachmentsCollapsed ? '展开文件' : '收起文件'}</span>
            </button>
            <button
              type="button"
              className="pending-toolbar-button pending-toolbar-button-danger"
              onClick={() => {
                if (!window.confirm(`确认清空这 ${pendingAttachments.length} 个已选文件吗？`)) return
                onClearPendingAttachments()
              }}
            >
              <Trash2 aria-hidden="true" />
              <span>清空所选文件</span>
            </button>
            <span className="pending-selection-count">共 {pendingAttachments.length} 个文件</span>
          </div>
          {!isPendingAttachmentsCollapsed ? (
            <div className="pending-attachments">
              {pendingAttachments.map((attachment) => (
                <PendingAttachmentCard
                  key={attachment.id}
                  attachment={attachment}
                  onOpenPreviewById={openPendingPreview}
                  onRemoveById={onRemovePendingAttachment}
                />
              ))}
            </div>
          ) : null}
        </div>
      ) : null}
      <div className="composer-controls">
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
            onClick={() => {
              syncSelectionRange()
              setIsEmojiPickerOpen((current) => !current)
            }}
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
        <textarea
          ref={composerInputRef}
          value={draft}
          rows={1}
          onChange={(event) => {
            onDraftChange(event.target.value)
            selectionRangeRef.current = {
              start: event.target.selectionStart ?? event.target.value.length,
              end: event.target.selectionEnd ?? event.target.value.length,
            }
          }}
          onClick={syncSelectionRange}
          onKeyUp={syncSelectionRange}
          onSelect={syncSelectionRange}
          placeholder={
            hasPendingAttachments
              ? '可继续输入文字或表情，发送后会和文件一起发出'
              : '按 Enter 发送，按 Command/Ctrl + Enter 换行...'
          }
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
      </div>
    </footer>
  )
}

const PendingAttachmentCard = memo(function PendingAttachmentCard({
  attachment,
  onOpenPreviewById,
  onRemoveById,
}: {
  attachment: PendingAttachment
  onOpenPreviewById: (attachmentId: string) => void
  onRemoveById: (id: string) => void
}) {
  return (
    <div className="pending-file-card">
      <button
        className="pending-file-remove"
        type="button"
        aria-label={`移除 ${attachment.name}`}
        onClick={() => onRemoveById(attachment.id)}
      >
        <X aria-hidden="true" />
      </button>
      {attachment.previewUrl ? (
        <button
          type="button"
          className="image-preview-trigger pending-file-image-trigger"
          onClick={() => onOpenPreviewById(attachment.id)}
          aria-label={`预览图片 ${attachment.name}`}
        >
          <img
            className="pending-file-image"
            src={attachment.previewUrl}
            alt={attachment.name}
            loading="lazy"
            decoding="async"
            draggable={false}
          />
        </button>
      ) : (
        <div className="pending-file-icon">{fileKindLabel(attachment.name)}</div>
      )}
      <div className="pending-file-copy">
        <strong>{attachment.name}</strong>
        <small>{formatAttachmentMeta(attachment)}</small>
      </div>
    </div>
  )
}, (prevProps, nextProps) => prevProps.attachment === nextProps.attachment)

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
