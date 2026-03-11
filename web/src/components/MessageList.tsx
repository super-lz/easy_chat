import { useEffect, useMemo, useRef } from 'react'
import type { PreviewSlide } from './ImagePreviewLightbox'
import type { Message } from '../lib/types'

type MessageListProps = {
  messages: Message[]
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

export function MessageList({ messages, onOpenImagePreview }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement | null>(null)
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
    bottomRef.current?.scrollIntoView({ block: 'end' })
  }, [messages])

  const downloadBatch = (items: Message[]) => {
    for (const item of items) {
      if (!item.downloadUrl) continue
      const anchor = document.createElement('a')
      anchor.href = item.downloadUrl
      anchor.download = item.content
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
    }
  }

  const openImagePreview = (messageId: string) => {
    const nextIndex = imageSlideIndexByMessageId.get(messageId)
    if (typeof nextIndex === "number") {
      onOpenImagePreview(imageSlides, nextIndex)
    }
  }

  return (
    <>
      <div className="message-area">
        {renderItems.map((item) => {
          if (item.kind === 'group') {
            const downloadable = item.files.filter(
              (entry) => entry.downloadUrl,
            )
            return (
              <article
                key={item.groupId}
                className={`message-row ${item.sender === 'browser' ? 'from-browser' : ''}`}
              >
                {item.sender !== 'system' ? (
                  <div className={`message-avatar avatar-${item.sender}`} />
                ) : null}
                <div
                  className={`message-bubble file-batch-bubble ${item.texts.length > 0 ? 'composed-message-bubble' : ''}`}
                >
                  {item.files.length > 0 ? (
                    <>
                      {item.files.length > 1 ? (
                        <div className="file-batch-header">
                          <strong>{item.files.length} 个文件</strong>
                          {downloadable.length === item.files.length &&
                          downloadable.length > 0 ? (
                            <button
                              type="button"
                              className="batch-download-button"
                              onClick={() => downloadBatch(item.files)}
                            >
                              全部下载
                            </button>
                          ) : null}
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
                              {message.downloadUrl ? (
                                <a
                                  className="file-link"
                                  href={message.downloadUrl}
                                  download={message.content}
                                >
                                  {message.content}
                                </a>
                              ) : (
                                <span>{message.content}</span>
                              )}
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
        return (
          <article
            key={message.id}
            className={`message-row ${message.sender === 'browser' ? 'from-browser' : ''} ${
                message.sender === 'system' ? 'from-system' : ''
              }`}
          >
              {message.sender !== 'system' ? (
                <div className={`message-avatar avatar-${message.sender}`} />
              ) : null}
              <div
                className={`message-bubble ${message.type === 'file' ? 'file-bubble' : ''}`}
              >
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
                {message.sender !== 'system' && !message.downloadUrl ? (
                  <p>{message.content}</p>
                ) : null}
                {message.sender !== 'system' && message.downloadUrl ? (
                  <a
                    className="file-link"
                    href={message.downloadUrl}
                    download={message.content}
                  >
                    {message.content}
                  </a>
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
    </>
  )
}

function fileKindLabel(fileName: string) {
  const extension = fileName.split('.').pop()?.toUpperCase() ?? 'FILE'
  return extension.slice(0, 4)
}

function shouldShowProgress(progress?: number) {
  return typeof progress === 'number' && progress > 0 && progress < 1
}
