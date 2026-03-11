type ChatSidebarProps = {
  connectionAddress: string
  conversationTitle: string
  directStatus: string
  error: string | null
  localDeviceName: string
  pageOrigin: string
  pairingServiceOrigin: string
  onDisconnect: () => void
}

export function ChatSidebar({
  connectionAddress,
  conversationTitle,
  directStatus,
  error,
  localDeviceName,
  pageOrigin,
  pairingServiceOrigin,
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

      <div className="sidebar-spacer" />

      <div className="sidebar-status">
        <div className="device-card">
          <strong>{localDeviceName}</strong>
        </div>
        <div className={`device-connection-state ${connectionState.className}`}>
          <span className="device-link-vertical" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <path d="M12 4v16" />
              <path d="m8 8 4-4 4 4" />
              <path d="m8 16 4 4 4-4" />
            </svg>
          </span>
          <span>{connectionState.label}</span>
        </div>
        <div className="device-card">
          <strong>{conversationTitle}</strong>
        </div>
        <div className="diagnostic-card">
          <span>页面</span>
          <code>{pageOrigin}</code>
        </div>
        <div className="diagnostic-card">
          <span>配对入口</span>
          <code>{pairingServiceOrigin}</code>
        </div>
        <div className="diagnostic-card">
          <span>目标直连</span>
          <code>{connectionAddress}</code>
        </div>
        <div className="diagnostic-card">
          <span>状态</span>
          <code>{directStatus}</code>
        </div>
        {error ? (
          <div className="diagnostic-card diagnostic-card-error">
            <span>错误</span>
            <code>{error}</code>
          </div>
        ) : null}
        <button className="disconnect-button dock-disconnect" type="button" onClick={onDisconnect}>
          断开连接
        </button>
      </div>
    </aside>
  )
}
