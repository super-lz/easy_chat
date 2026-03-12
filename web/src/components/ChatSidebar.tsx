import { memo } from 'react'
import { Smartphone } from 'lucide-react'
import type { DirectConnectionState } from '../lib/types'

type ChatSidebarProps = {
  browserIp: string
  browserName: string
  browserPort: string
  connectionState: DirectConnectionState
  error: string | null
  phoneIp: string
  phoneName: string
  phonePort: string
  onDisconnect: () => void
}

export const ChatSidebar = memo(function ChatSidebar({
  browserIp,
  browserName,
  browserPort,
  connectionState,
  error,
  phoneIp,
  phoneName,
  phonePort,
  onDisconnect,
}: ChatSidebarProps) {
  const badgeClassName = mapConnectionBadgeClassName(connectionState.kind)
  const networkStatusLabel = connectionState.kind === 'connected' ? '正常' : connectionState.label
  return (
    <aside className="sidebar">
      <div className="sidebar-top">
        <div className="sidebar-brand-block">
          <h1 className="sidebar-brand">EasyChat</h1>
          <p className="sidebar-brand-subtitle">局域网直连</p>
        </div>
      </div>

      <div className="sidebar-status">
        <section className="sidebar-panel">
          <p className="sidebar-panel-label">当前会话</p>
          <div className="session-device-block">
            <div className="session-device-icon" aria-hidden="true">
              <Smartphone />
            </div>
            <div className="session-device-copy">
              <strong>{phoneName}</strong>
              <ConnectionBadge
                className={badgeClassName}
                label={connectionState.label}
              />
            </div>
          </div>
          <button className="disconnect-button dock-disconnect" type="button" onClick={onDisconnect}>
            断开连接
          </button>
        </section>

        <section className="sidebar-panel">
          <p className="sidebar-panel-label">本地网络</p>
          <div className="network-detail-list">
            <div className="network-detail-row">
              <span>手机</span>
              <code>{phoneName}</code>
            </div>
            <div className="network-detail-row">
              <span>浏览器</span>
              <code>{browserName}</code>
            </div>
            <div className="network-detail-row">
              <span>手机地址</span>
              <code>{`${phoneIp}:${phonePort}`}</code>
            </div>
            <div className="network-detail-row">
              <span>浏览器地址</span>
              <code>{`${browserIp}:${browserPort}`}</code>
            </div>
            <div className="network-detail-row network-detail-row-status">
              <span>状态</span>
              <ConnectionBadge
                className={badgeClassName}
                label={networkStatusLabel}
              />
            </div>
          </div>
          {error ? (
            <div className="diagnostic-card diagnostic-card-error">
              <span>错误</span>
              <code>{error}</code>
            </div>
          ) : null}
        </section>
      </div>
    </aside>
  )
})

function mapConnectionBadgeClassName(kind: DirectConnectionState['kind']) {
  if (kind === 'connected') {
    return 'is-connected'
  }
  if (kind === 'failed') {
    return 'is-failed'
  }
  return 'is-connecting'
}

function ConnectionBadge({
  className,
  label,
}: {
  className: string
  label: string
}) {
  return (
    <span className={`status-badge ${className}`}>
      <span className="status-badge-dot" aria-hidden="true" />
      <strong>{label}</strong>
    </span>
  )
}
