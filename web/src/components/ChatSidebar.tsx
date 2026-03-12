import { Smartphone } from 'lucide-react'

type ChatSidebarProps = {
  browserIp: string
  browserName: string
  browserPort: string
  directStatus: string
  error: string | null
  phoneIp: string
  phoneName: string
  phonePort: string
  wifiName: string
  onDisconnect: () => void
}

export function ChatSidebar({
  browserIp,
  browserName,
  browserPort,
  directStatus,
  error,
  phoneIp,
  phoneName,
  phonePort,
  wifiName,
  onDisconnect,
}: ChatSidebarProps) {
  const connectionState =
    directStatus === '已直连'
      ? { label: '已连接', className: 'is-connected' }
      : directStatus === '连接失败' || directStatus === '连接已断开'
        ? { label: '连接失败', className: 'is-failed' }
        : { label: '连接中', className: 'is-connecting' }

  return (
    <aside className="sidebar">
      <div className="sidebar-top">
        <h1 className="sidebar-brand">EasyChat</h1>
      </div>

      <div className="sidebar-status">
        <section className="sidebar-panel">
          <p className="sidebar-panel-label">Current Session</p>
          <div className="session-device-block">
            <div className="session-device-icon" aria-hidden="true">
              <Smartphone />
            </div>
            <div className="session-device-copy">
              <strong>{phoneName}</strong>
              <div className={`device-connection-state ${connectionState.className}`}>
                <span className="device-status-dot" aria-hidden="true" />
                <span>
                  {connectionState.className === 'is-connected'
                    ? 'Connected'
                    : connectionState.className === 'is-failed'
                      ? 'Offline'
                      : 'Connecting'}
                </span>
              </div>
            </div>
          </div>
          <button className="disconnect-button dock-disconnect" type="button" onClick={onDisconnect}>
            Disconnect Device
          </button>
        </section>

        <section className="sidebar-panel">
          <p className="sidebar-panel-label">Local Network</p>
          <div className="network-detail-list">
            <div className="network-detail-row">
              <span>Wi‑Fi</span>
              <code>{wifiName}</code>
            </div>
            <div className="network-detail-row">
              <span>Phone</span>
              <code>{phoneName}</code>
            </div>
            <div className="network-detail-row">
              <span>Browser</span>
              <code>{browserName}</code>
            </div>
            <div className="network-detail-row">
              <span>Host</span>
              <code>{`${phoneIp}:${phonePort}`}</code>
            </div>
            <div className="network-detail-row">
              <span>Client</span>
              <code>{`${browserIp}:${browserPort}`}</code>
            </div>
            <div className="network-detail-row network-detail-row-status">
              <span>Status</span>
              <code>{connectionState.className === 'is-connected' ? 'Active' : connectionState.label}</code>
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
}
