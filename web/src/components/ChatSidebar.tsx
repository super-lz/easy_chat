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
  const wifiLabel = wifiName === 'Unknown Wi-Fi' ? '未知 Wi‑Fi' : wifiName

  return (
    <aside className="sidebar">
      <div className="sidebar-top">
        <h1 className="sidebar-brand">EasyChat</h1>
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
              <div className={`device-connection-state ${connectionState.className}`}>
                <span className="device-status-dot" aria-hidden="true" />
                <span>{connectionState.label}</span>
              </div>
            </div>
          </div>
          <button className="disconnect-button dock-disconnect" type="button" onClick={onDisconnect}>
            断开设备
          </button>
        </section>

        <section className="sidebar-panel">
          <p className="sidebar-panel-label">本地网络</p>
          <div className="network-detail-list">
            <div className="network-detail-row">
              <span>Wi‑Fi</span>
              <code>{wifiLabel}</code>
            </div>
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
              <span className={`status-badge ${connectionState.className}`}>
                <span className="status-badge-dot" aria-hidden="true" />
                <strong>{connectionState.className === 'is-connected' ? '正常' : connectionState.label}</strong>
              </span>
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
