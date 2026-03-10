type ChatSidebarProps = {
  conversationTitle: string
  directStatus: string
  localDeviceName: string
  onDisconnect: () => void
}

export function ChatSidebar({ conversationTitle, directStatus, localDeviceName, onDisconnect }: ChatSidebarProps) {
  const connectionState =
    directStatus === '已直连'
      ? { label: '已连接', className: 'is-connected' }
      : directStatus === '连接失败' || directStatus === '连接已断开'
        ? { label: '连接失败', className: 'is-failed' }
        : { label: '连接中', className: 'is-connecting' }

  return (
    <aside className="sidebar">
      <div className="sidebar-top">
        <h1 className="sidebar-brand">Easy Chat</h1>
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
        <button className="disconnect-button dock-disconnect" type="button" onClick={onDisconnect}>
          断开连接
        </button>
      </div>
    </aside>
  )
}
