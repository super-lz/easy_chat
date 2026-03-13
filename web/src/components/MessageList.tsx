import { memo, useEffect, useMemo, useRef, useState } from 'react'
import { ArrowDown, Check, CircleX, Copy, Download } from 'lucide-react'
import type { PreviewSlide } from './ImagePreviewLightbox'
import type { Message } from '../lib/types'

type MessageListProps = {
  messages: Message[]
  onCancelBatchTransfers: (batchId: string) => void
  onCancelFileTransfer: (transferId: string) => void
  onOpenImagePreview: (slides: PreviewSlide[], index: number) => void
}

type RenderItem =
  | { kind: 'message'; message: Message }
  | {
      kind: 'group'
      groupId: string
      sender: Message['sender']
      files: Message[]
      texts: Message[]
    }

export const MessageList = memo(function MessageList({
  messages,
  onCancelBatchTransfers,
  onCancelFileTransfer,
  onOpenImagePreview,
}: MessageListProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const bottomRef = useRef<HTMLDivElement | null>(null)
  const menuRef = useRef<HTMLDivElement | null>(null)
  const shouldStickToBottomRef = useRef(true)
  const isProgrammaticScrollRef = useRef(false)
  const lastMessageIdRef = useRef<string | null>(null)
  const copyResetTimerRef = useRef<number | null>(null)
  const [openDownloadMenuId, setOpenDownloadMenuId] = useState<string | null>(null)
  const [copiedBubbleId, setCopiedBubbleId] = useState<string | null>(null)
  const [showScrollToBottom, setShowScrollToBottom] = useState(false)
  const [hasUnreadIncoming, setHasUnreadIncoming] = useState(false)
  const renderItems = useMemo<RenderItem[]>(() => {
    const items: RenderItem[] = []

    for (const message of messages) {
      const groupingKey =
        message.compositionId ??
        (message.type === "file" && message.batchId
          ? `batch:${message.batchId}`
          : null)
      const lastItem = items[items.length - 1]

      if (
        groupingKey &&
        lastItem?.kind === "group" &&
        lastItem.groupId === groupingKey &&
        lastItem.sender === message.sender
      ) {
        if (message.type === "file") {
          lastItem.files.push(message)
        } else {
          lastItem.texts.push(message)
        }
        continue
      }

      if (groupingKey) {
        items.push({
          kind: "group",
          groupId: groupingKey,
          sender: message.sender,
          files: message.type === "file" ? [message] : [],
          texts: message.type === 'text' ? [message] : [],
        })
        continue
      }

      items.push({ kind: 'message', message })
    }

    return items
  }, [messages])
  const imageSlides = useMemo(
    () =>
      messages
        .filter(
          (message) =>
            message.type === "file" &&
            message.mimeType?.startsWith('image/') &&
            message.downloadUrl,
        )
        .map((message) => ({
          id: message.id,
          src: message.downloadUrl!,
          alt: message.content,
          title: message.content,
          description: message.meta,
        })) satisfies PreviewSlide[],
    [messages],
  )
  const imageSlideIndexByMessageId = useMemo(
    () => new Map(imageSlides.map((slide, index) => [slide.id, index])),
    [imageSlides],
  )

  useEffect(() => {
    const latestMessage = messages[messages.length - 1]
    if (!latestMessage) {
      return
    }

    const isNewMessage = latestMessage.id !== lastMessageIdRef.current
    lastMessageIdRef.current = latestMessage.id

    if (!isNewMessage) {
      return
    }

    const shouldAutoScroll =
      latestMessage.sender === 'browser' || shouldStickToBottomRef.current

    if (!shouldAutoScroll) {
      if (latestMessage.sender !== 'browser' && latestMessage.sender !== 'system') {
        setHasUnreadIncoming(true)
        setShowScrollToBottom(true)
      }
      return
    }

    setHasUnreadIncoming(false)
    setShowScrollToBottom(false)
    isProgrammaticScrollRef.current = latestMessage.sender === 'browser'
    bottomRef.current?.scrollIntoView({
      block: 'end',
      behavior: latestMessage.sender === 'browser' ? 'smooth' : 'auto',
    })
  }, [messages])

  useEffect(() => {
    if (!openDownloadMenuId) {
      return
    }

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node | null
      if (!target) return
      if (menuRef.current?.contains(target)) return
      setOpenDownloadMenuId(null)
    }

    document.addEventListener('mousedown', handlePointerDown)
    return () => document.removeEventListener('mousedown', handlePointerDown)
  }, [openDownloadMenuId])

  useEffect(() => {
    return () => {
      if (copyResetTimerRef.current !== null) {
        window.clearTimeout(copyResetTimerRef.current)
      }
    }
  }, [])

  const handleScroll = () => {
    const container = containerRef.current
    if (!container) {
      return
    }

    const distanceFromBottom =
      container.scrollHeight - container.scrollTop - container.clientHeight
    shouldStickToBottomRef.current = distanceFromBottom < 72
    if (shouldStickToBottomRef.current) {
      isProgrammaticScrollRef.current = false
      setHasUnreadIncoming(false)
      setShowScrollToBottom(false)
      return
    }

    if (isProgrammaticScrollRef.current) {
      return
    }

    setShowScrollToBottom(true)
  }

  const downloadBatch = (items: Message[]) => {
    for (const item of items) {
      if (!item.downloadUrl) continue
      triggerDownload(item.downloadUrl, item.content)
    }
  }

  const downloadFile = (message: Message) => {
    if (!message.downloadUrl) return
    triggerDownload(message.downloadUrl, message.content)
  }

  const downloadBatchArchive = async (items: Message[]) => {
    const downloadableItems = items.filter((item) => item.downloadUrl)
    if (downloadableItems.length === 0) {
      return
    }

    const archiveEntries = await Promise.all(
      downloadableItems.map(async (item, index) => {
        const response = await fetch(item.downloadUrl!)
        const bytes = new Uint8Array(await response.arrayBuffer())
        return {
          name: buildArchiveEntryName(item.content, index),
          bytes,
        }
      }),
    )

    const archive = createZipArchive(archiveEntries)
    const archiveUrl = URL.createObjectURL(new Blob([archive], { type: 'application/zip' }))
    const anchor = document.createElement('a')
    anchor.href = archiveUrl
    anchor.download = buildArchiveFileName(downloadableItems)
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()
    window.setTimeout(() => URL.revokeObjectURL(archiveUrl), 1000)
  }

  const openImagePreview = (messageId: string) => {
    const nextIndex = imageSlideIndexByMessageId.get(messageId)
    if (typeof nextIndex === "number") {
      onOpenImagePreview(imageSlides, nextIndex)
    }
  }

  const handleBubbleMouseEnter = (bubbleId: string) => {
    setCopiedBubbleId((current) => (current === bubbleId ? null : current))
  }

  const writeTextFallback = (text: string) => {
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.setAttribute('readonly', '')
    textarea.style.position = 'fixed'
    textarea.style.top = '0'
    textarea.style.left = '-9999px'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    textarea.setSelectionRange(0, text.length)
    const copied = document.execCommand('copy')
    textarea.remove()
    return copied
  }

  const copyBubbleText = async (bubbleId: string, text: string) => {
    const normalizedText = text.trim()
    if (!normalizedText) return

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(normalizedText)
      } else if (!writeTextFallback(normalizedText)) {
        throw new Error('Clipboard unavailable')
      }

      if (copyResetTimerRef.current !== null) {
        window.clearTimeout(copyResetTimerRef.current)
      }
      setCopiedBubbleId(bubbleId)
      copyResetTimerRef.current = window.setTimeout(() => {
        setCopiedBubbleId((current) => (current === bubbleId ? null : current))
        copyResetTimerRef.current = null
      }, 1200)
    } catch (error) {
      console.error('Failed to copy message text', error)
    }
  }

  return (
    <div className="message-area-shell">
      <div
        ref={containerRef}
        className="message-area"
        onScroll={handleScroll}
      >
        {renderItems.map((item) => {
          if (item.kind === 'group') {
            const downloadable = item.files.filter(
              (entry) => entry.downloadUrl,
            )
            const cancelableFiles = item.files.filter(isTransferCancelable)
            return (
              <article
                key={item.groupId}
                className={`message-row ${item.sender === 'browser' ? 'from-browser' : ''}`}
              >
                <div
                  className={`message-bubble file-batch-bubble ${item.texts.length > 0 ? 'composed-message-bubble' : ''}`}
                  onMouseEnter={() => handleBubbleMouseEnter(item.groupId)}
                >
                  {item.texts.length > 0 ? (
                    <button
                      type="button"
                      className="message-copy-button"
                      onClick={() => void copyBubbleText(item.groupId, item.texts.map((message) => message.content).join('\n'))}
                      aria-label={copiedBubbleId === item.groupId ? '已复制消息文本' : '复制消息文本'}
                      title={copiedBubbleId === item.groupId ? '已复制' : '复制文本'}
                    >
                      {copiedBubbleId === item.groupId ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
                    </button>
                  ) : null}
                  {item.files.length > 0 ? (
                    <>
                      {item.files.length > 1 ? (
                        <div className="file-batch-header">
                          <strong>{item.files.length} 个文件</strong>
                          <div className="file-batch-actions">
                            {cancelableFiles.length > 1 && item.files[0]?.batchId ? (
                              <button
                                type="button"
                                className="file-action-button file-action-button-danger"
                                onClick={() => {
                                  if (!window.confirm(`确认取消这 ${cancelableFiles.length} 个文件的传输吗？`)) return
                                  onCancelBatchTransfers(item.files[0].batchId!)
                                }}
                                aria-label="取消全部传输"
                              >
                                <CircleX aria-hidden="true" />
                                <span>全部取消</span>
                              </button>
                            ) : null}
                            {downloadable.length === item.files.length &&
                            downloadable.length > 0 ? (
                              <div
                                className="batch-download-menu"
                                ref={openDownloadMenuId === item.groupId ? menuRef : null}
                              >
                                <button
                                  type="button"
                                  className="batch-download-button"
                                  onClick={() =>
                                    setOpenDownloadMenuId((current) =>
                                      current === item.groupId ? null : item.groupId,
                                    )
                                  }
                                  aria-expanded={openDownloadMenuId === item.groupId}
                                >
                                  <Download aria-hidden="true" />
                                  <span>导出文件</span>
                                </button>
                                {openDownloadMenuId === item.groupId ? (
                                  <div className="batch-download-popmenu">
                                    <button
                                      type="button"
                                      className="batch-download-option"
                                      onClick={() => {
                                        void downloadBatchArchive(item.files)
                                        setOpenDownloadMenuId(null)
                                      }}
                                    >
                                      <strong>归档下载</strong>
                                      <span>打成一个包下载</span>
                                    </button>
                                    <button
                                      type="button"
                                      className="batch-download-option"
                                      onClick={() => {
                                        downloadBatch(item.files)
                                        setOpenDownloadMenuId(null)
                                      }}
                                    >
                                      <strong>逐个保存</strong>
                                      <span>依次下载全部文件</span>
                                    </button>
                                  </div>
                                ) : null}
                              </div>
                            ) : null}
                          </div>
                        </div>
                      ) : null}
                      <div className="file-batch-list">
                        {item.files.map((message) => (
                          <div key={message.id} className="file-batch-item">
                            {message.mimeType?.startsWith('image/') &&
                            message.downloadUrl ? (
                              <button
                                type="button"
                                className="image-preview-trigger file-batch-image-trigger"
                                onClick={() => openImagePreview(message.id)}
                                aria-label={`预览图片 ${message.content}`}
                              >
                                <img
                                  className="file-batch-image"
                                  src={message.downloadUrl}
                                  alt={message.content}
                                />
                              </button>
                            ) : (
                              <div className="file-batch-icon">
                                {fileKindLabel(message.content)}
                              </div>
                            )}
                            <div className="file-batch-copy">
                              <div className="file-batch-copy-main">
                                <span className="file-link">{message.content}</span>
                                {message.downloadUrl ? (
                                  <button
                                    type="button"
                                    className="icon-action-button file-download-button"
                                    onClick={() => downloadFile(message)}
                                    aria-label={`下载 ${message.content}`}
                                  >
                                    <Download aria-hidden="true" />
                                  </button>
                                ) : null}
                                {isTransferCancelable(message) ? (
                                  <button
                                    type="button"
                                    className="icon-action-button icon-action-button-danger"
                                    onClick={() => {
                                      if (!window.confirm(`确认取消 ${message.content} 的传输吗？`)) return
                                      onCancelFileTransfer(message.id)
                                    }}
                                    aria-label={`取消 ${message.content} 的传输`}
                                  >
                                    <CircleX aria-hidden="true" />
                                  </button>
                                ) : null}
                              </div>
                              {message.meta ? (
                                <small>{message.meta}</small>
                              ) : null}
                              {shouldShowProgress(message.progress) ? (
                                <div className="progress-track progress-track-compact">
                                  <div
                                    className="progress-fill"
                                    style={{
                                      width: `${Math.round((message.progress ?? 0) * 100)}%`,
                                    }}
                                  />
                                </div>
                              ) : null}
                            </div>
                          </div>
                        ))}
                      </div>
                    </>
                  ) : null}
                  {item.texts.length > 0 ? (
                    <div
                      className={item.files.length > 0 ? 'composed-message-text' : ''}
                    >
                      {item.texts.map((message) => (
                        <p key={message.id}>{message.content}</p>
                      ))}
                    </div>
                  ) : null}
                </div>
              </article>
            );
          }

        const message = item.message
        const emojiOnlyMessage =
          message.type === 'text' &&
          message.sender !== 'system' &&
          isEmojiOnlyMessage(message.content)
        return (
          <article
            key={message.id}
            className={`message-row ${message.sender === 'browser' ? 'from-browser' : ''} ${
                message.sender === 'system' ? 'from-system' : ''
              }`}
          >
              <div
                className={`message-bubble ${message.type === 'file' ? 'file-bubble' : ''} ${
                  emojiOnlyMessage ? 'emoji-only-bubble' : ''
                }`}
                onMouseEnter={() => handleBubbleMouseEnter(message.id)}
              >
                {message.type !== 'file' || message.sender === 'system' ? (
                  <button
                    type="button"
                    className="message-copy-button"
                    onClick={() => void copyBubbleText(message.id, message.content)}
                    aria-label={copiedBubbleId === message.id ? '已复制消息文本' : '复制消息文本'}
                    title={copiedBubbleId === message.id ? '已复制' : '复制文本'}
                  >
                    {copiedBubbleId === message.id ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
                  </button>
                ) : null}
                {message.type === 'file' &&
                message.mimeType?.startsWith('image/') &&
                message.downloadUrl ? (
                  <button
                    type="button"
                    className="image-preview-trigger image-preview-button"
                    onClick={() => openImagePreview(message.id)}
                    aria-label={`预览图片 ${message.content}`}
                  >
                    <img
                      className="image-preview"
                      src={message.downloadUrl}
                      alt={message.content}
                    />
                  </button>
                ) : null}
                {message.type === 'file' && message.sender !== 'system' ? (
                  <div className="file-message-header">
                    <p className="file-link">{message.content}</p>
                    {message.downloadUrl ? (
                      <button
                        type="button"
                        className="icon-action-button file-download-button"
                        onClick={() => downloadFile(message)}
                        aria-label={`下载 ${message.content}`}
                      >
                        <Download aria-hidden="true" />
                      </button>
                    ) : null}
                    {isTransferCancelable(message) ? (
                      <button
                        type="button"
                        className="icon-action-button icon-action-button-danger"
                        onClick={() => {
                          if (!window.confirm(`确认取消 ${message.content} 的传输吗？`)) return
                          onCancelFileTransfer(message.id)
                        }}
                        aria-label={`取消 ${message.content} 的传输`}
                      >
                        <CircleX aria-hidden="true" />
                      </button>
                    ) : null}
                  </div>
                ) : null}
                {message.type !== 'file' && message.sender !== 'system' ? (
                  <p>{message.content}</p>
                ) : null}
                {message.sender === 'system' ? <p>{message.content}</p> : null}
                {message.meta ? <small>{message.meta}</small> : null}
                {message.type === 'file' &&
                shouldShowProgress(message.progress) ? (
                  <div className="progress-track progress-track-compact">
                    <div
                      className="progress-fill"
                      style={{
                        width: `${Math.round((message.progress ?? 0) * 100)}%`,
                      }}
                    />
                  </div>
                ) : null}
              </div>
            </article>
          );
        })}
        <div ref={bottomRef} />
      </div>
      {showScrollToBottom ? (
        <button
          type="button"
          className="scroll-to-bottom-button"
          onClick={() => {
            shouldStickToBottomRef.current = true
            isProgrammaticScrollRef.current = true
            setHasUnreadIncoming(false)
            setShowScrollToBottom(false)
            bottomRef.current?.scrollIntoView({ block: 'end', behavior: 'auto' })
          }}
          aria-label="滚动到底部"
        >
          <ArrowDown aria-hidden="true" />
          <span>{hasUnreadIncoming ? '新的消息' : '回到底部'}</span>
        </button>
      ) : null}
    </div>
  )
})

function fileKindLabel(fileName: string) {
  const extension = fileName.split('.').pop()?.toUpperCase() ?? 'FILE'
  return extension.slice(0, 4)
}

function shouldShowProgress(progress?: number) {
  return typeof progress === 'number' && progress > 0 && progress < 1
}

function isTransferCancelable(message: Message) {
  return message.type === 'file' && message.transferState === 'transferring'
}

function isEmojiOnlyMessage(content: string) {
  const value = content.trim()
  if (!value) {
    return false
  }

  const stripped = value.replace(/[\p{Emoji_Presentation}\p{Extended_Pictographic}\uFE0F\u200D\s]/gu, '')
  return stripped.length === 0
}

function triggerDownload(url: string, fileName: string) {
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = fileName
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
}

function buildArchiveFileName(items: Message[]) {
  const stem = sanitizeArchiveName(items[0]?.content?.replace(/\.[^.]+$/, '') || 'easychat-files')
  return `${stem}-${items.length}个文件.zip`
}

function buildArchiveEntryName(fileName: string, index: number) {
  const sanitized = sanitizeArchiveName(fileName)
  return sanitized || `file-${index + 1}`
}

function sanitizeArchiveName(fileName: string) {
  return fileName.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 180)
}

function createZipArchive(entries: Array<{ name: string; bytes: Uint8Array }>) {
  const encoder = new TextEncoder()
  const localParts: Uint8Array[] = []
  const centralParts: Uint8Array[] = []
  let offset = 0

  for (const entry of entries) {
    const fileNameBytes = encoder.encode(entry.name)
    const crc = crc32(entry.bytes)
    const timestamp = toDosDateTime(new Date())

    const localHeader = new Uint8Array(30 + fileNameBytes.length)
    const localView = new DataView(localHeader.buffer)
    localView.setUint32(0, 0x04034b50, true)
    localView.setUint16(4, 20, true)
    localView.setUint16(6, 0, true)
    localView.setUint16(8, 0, true)
    localView.setUint16(10, timestamp.time, true)
    localView.setUint16(12, timestamp.date, true)
    localView.setUint32(14, crc, true)
    localView.setUint32(18, entry.bytes.byteLength, true)
    localView.setUint32(22, entry.bytes.byteLength, true)
    localView.setUint16(26, fileNameBytes.length, true)
    localView.setUint16(28, 0, true)
    localHeader.set(fileNameBytes, 30)

    localParts.push(localHeader, entry.bytes)

    const centralHeader = new Uint8Array(46 + fileNameBytes.length)
    const centralView = new DataView(centralHeader.buffer)
    centralView.setUint32(0, 0x02014b50, true)
    centralView.setUint16(4, 20, true)
    centralView.setUint16(6, 20, true)
    centralView.setUint16(8, 0, true)
    centralView.setUint16(10, 0, true)
    centralView.setUint16(12, timestamp.time, true)
    centralView.setUint16(14, timestamp.date, true)
    centralView.setUint32(16, crc, true)
    centralView.setUint32(20, entry.bytes.byteLength, true)
    centralView.setUint32(24, entry.bytes.byteLength, true)
    centralView.setUint16(28, fileNameBytes.length, true)
    centralView.setUint16(30, 0, true)
    centralView.setUint16(32, 0, true)
    centralView.setUint16(34, 0, true)
    centralView.setUint16(36, 0, true)
    centralView.setUint32(38, 0, true)
    centralView.setUint32(42, offset, true)
    centralHeader.set(fileNameBytes, 46)
    centralParts.push(centralHeader)

    offset += localHeader.byteLength + entry.bytes.byteLength
  }

  const centralDirectorySize = centralParts.reduce((sum, part) => sum + part.byteLength, 0)
  const endRecord = new Uint8Array(22)
  const endView = new DataView(endRecord.buffer)
  endView.setUint32(0, 0x06054b50, true)
  endView.setUint16(4, 0, true)
  endView.setUint16(6, 0, true)
  endView.setUint16(8, entries.length, true)
  endView.setUint16(10, entries.length, true)
  endView.setUint32(12, centralDirectorySize, true)
  endView.setUint32(16, offset, true)
  endView.setUint16(20, 0, true)

  const totalLength =
    localParts.reduce((sum, part) => sum + part.byteLength, 0) +
    centralDirectorySize +
    endRecord.byteLength
  const archive = new Uint8Array(totalLength)
  let writeOffset = 0

  for (const part of localParts) {
    archive.set(part, writeOffset)
    writeOffset += part.byteLength
  }
  for (const part of centralParts) {
    archive.set(part, writeOffset)
    writeOffset += part.byteLength
  }
  archive.set(endRecord, writeOffset)

  return archive
}

function toDosDateTime(date: Date) {
  const year = Math.max(1980, date.getFullYear())
  const month = date.getMonth() + 1
  const day = date.getDate()
  const hours = date.getHours()
  const minutes = date.getMinutes()
  const seconds = Math.floor(date.getSeconds() / 2)

  return {
    time: (hours << 11) | (minutes << 5) | seconds,
    date: ((year - 1980) << 9) | (month << 5) | day,
  }
}

function crc32(bytes: Uint8Array) {
  let crc = 0xffffffff
  for (const byte of bytes) {
    crc = (crc >>> 8) ^ CRC32_TABLE[(crc ^ byte) & 0xff]
  }
  return (crc ^ 0xffffffff) >>> 0
}

const CRC32_TABLE = new Uint32Array(
  Array.from({ length: 256 }, (_, index) => {
    let value = index
    for (let bit = 0; bit < 8; bit += 1) {
      value = (value & 1) === 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    }
    return value >>> 0
  }),
)
