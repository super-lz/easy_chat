import { ChatScreen } from './components/ChatScreen'
import { PairingScreen } from './components/PairingScreen'
import { getBrowserName } from './lib/browser'
import { useEasyChat } from './hooks/useEasyChat'
import './App.css'

function App() {
  const browserName = getBrowserName(navigator.userAgent)
  const currentLocation = window.location
  const browserIp = currentLocation.hostname || '未知'
  const browserPort =
    currentLocation.port || (currentLocation.protocol === 'https:' ? '443' : '80')
  const {
    canCompose,
    canSend,
    conversationTitle,
    countdown,
    directStatus,
    draft,
    error,
    fileInputRef,
    handleFileInput,
    isLoading,
    pendingAttachments,
    phase,
    endpoint,
    removePendingAttachment,
    session,
    settings,
    visibleMessages,
    appendPendingFiles,
    cancelBatchTransfers,
    cancelFileTransfer,
    disconnectToPairing,
    sendMessage,
    setDraft,
  } = useEasyChat()

  return (
    <main className={`app-frame ${phase === 'pairing' ? 'app-frame-pairing' : ''}`}>
      {phase === 'pairing' ? (
        <PairingScreen
          browserName={browserName}
          countdown={countdown}
          isLoading={isLoading}
          pairingServiceOrigin={import.meta.env.VITE_PAIRING_API_URL || window.location.origin}
          pageOrigin={window.location.origin}
          session={session}
        />
      ) : (
        <ChatScreen
          browserIp={browserIp}
          browserPort={browserPort}
          canCompose={canCompose}
          canSend={canSend}
          conversationTitle={conversationTitle}
          directStatus={directStatus}
          draft={draft}
          error={error}
          fileInputRef={fileInputRef}
          localDeviceName={browserName}
          messages={visibleMessages}
          pendingAttachments={pendingAttachments}
          phoneIp={endpoint?.phoneIp ?? '等待连接'}
          phonePort={endpoint ? String(endpoint.phonePort) : '等待连接'}
          settings={settings}
          wifiName={endpoint?.wifiName || '等待连接'}
          onAppendFiles={appendPendingFiles}
          onCancelBatchTransfers={cancelBatchTransfers}
          onCancelFileTransfer={cancelFileTransfer}
          onDisconnect={disconnectToPairing}
          onDraftChange={setDraft}
          onFileChange={(event) => void handleFileInput(event)}
          onOpenFilePicker={() => fileInputRef.current?.click()}
          onRemovePendingAttachment={removePendingAttachment}
          onSendMessage={sendMessage}
        />
      )}
    </main>
  )
}

export default App
