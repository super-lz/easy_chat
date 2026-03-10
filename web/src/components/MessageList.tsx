import { useEffect, useMemo, useRef } from 'react'
import type { Message } from '../lib/types'

type MessageListProps = {
  messages: Message[]
}

type RenderItem =
  | { kind: 'message'; message: Message }
  | { kind: 'batch'; batchId: string; sender: Message['sender']; items: Message[] }

export function MessageList({ messages }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement | null>(null)
  const renderItems = useMemo<RenderItem[]>(() => {
    const items: RenderItem[] = []

    for (const message of messages) {
      const lastItem = items[items.length - 1]
      if (
        message.type === 'file' &&
        message.batchId &&
        lastItem?.kind === 'batch' &&
        lastItem.batchId === message.batchId &&
        lastItem.sender === message.sender
      ) {
        lastItem.items.push(message)
        continue
      }

      if (message.type === 'file' && message.batchId) {
        items.push({
          kind: 'batch',
          batchId: message.batchId,
          sender: message.sender,
          items: [message],
        })
        continue
      }

      items.push({ kind: 'message', message })
    }

    return items
  }, [messages])

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

  return (
    <div className="message-area">
      {renderItems.map((item) => {
        if (item.kind === 'batch') {
          const downloadable = item.items.filter((entry) => entry.downloadUrl)
          return (
            <article
              key={item.batchId}
              className={`message-row ${item.sender === 'browser' ? 'from-browser' : ''}`}
            >
              {item.sender !== 'system' ? <div className={`message-avatar avatar-${item.sender}`} /> : null}
              <div className="message-bubble file-batch-bubble">
                <div className="file-batch-header">
                  <strong>{item.items.length} 个文件</strong>
                  {downloadable.length === item.items.length && downloadable.length > 0 ? (
                    <button type="button" className="batch-download-button" onClick={() => downloadBatch(item.items)}>
                      全部下载
                    </button>
                  ) : null}
                </div>
                <div className="file-batch-list">
                  {item.items.map((message) => (
                    <div key={message.id} className="file-batch-item">
                      {message.mimeType?.startsWith('image/') && message.downloadUrl ? (
                        <img className="file-batch-image" src={message.downloadUrl} alt={message.content} />
                      ) : (
                        <div className="file-batch-icon">{fileKindLabel(message.content)}</div>
                      )}
                      <div className="file-batch-copy">
                        {message.downloadUrl ? (
                          <a className="file-link" href={message.downloadUrl} download={message.content}>
                            {message.content}
                          </a>
                        ) : (
                          <span>{message.content}</span>
                        )}
                        {message.meta ? <small>{message.meta}</small> : null}
                      </div>
                      {typeof message.progress === 'number' ? (
                        <div className="progress-track">
                          <div className="progress-fill" style={{ width: `${Math.round(message.progress * 100)}%` }} />
                        </div>
                      ) : null}
                    </div>
                  ))}
                </div>
              </div>
            </article>
          )
        }

        const message = item.message
        return (
          <article
            key={message.id}
            className={`message-row ${message.sender === 'browser' ? 'from-browser' : ''} ${
              message.sender === 'system' ? 'from-system' : ''
            }`}
          >
            {message.sender !== 'system' ? <div className={`message-avatar avatar-${message.sender}`} /> : null}
            <div className={`message-bubble ${message.type === 'file' ? 'file-bubble' : ''}`}>
              {message.sender === 'system' ? <span className="message-status-tag">已连接</span> : null}
              {message.type === 'file' && message.mimeType?.startsWith('image/') && message.downloadUrl ? (
                <img className="image-preview" src={message.downloadUrl} alt={message.content} />
              ) : null}
              {message.sender !== 'system' && !message.downloadUrl ? <p>{message.content}</p> : null}
              {message.sender !== 'system' && message.downloadUrl ? (
                <a className="file-link" href={message.downloadUrl} download={message.content}>
                  {message.content}
                </a>
              ) : null}
              {message.sender === 'system' ? <p>{message.content}</p> : null}
              {message.meta ? <small>{message.meta}</small> : null}
              {message.type === 'file' && typeof message.progress === 'number' ? (
                <div className="progress-track">
                  <div className="progress-fill" style={{ width: `${Math.round(message.progress * 100)}%` }} />
                </div>
              ) : null}
            </div>
          </article>
        )
      })}
      <div ref={bottomRef} />
    </div>
  )
}

function fileKindLabel(fileName: string) {
  const extension = fileName.split('.').pop()?.toUpperCase() ?? 'FILE'
  return extension.slice(0, 4)
}
