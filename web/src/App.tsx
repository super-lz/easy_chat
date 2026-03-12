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
    connectionState,
    conversationTitle,
    countdown,
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
    clearPendingAttachments,
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
          session={session}
        />
      ) : (
        <ChatScreen
          browserIp={browserIp}
          browserPort={browserPort}
          canCompose={canCompose}
          canSend={canSend}
          connectionState={connectionState}
          conversationTitle={conversationTitle}
          draft={draft}
          error={error}
          fileInputRef={fileInputRef}
          localDeviceName={browserName}
          messages={visibleMessages}
          pendingAttachments={pendingAttachments}
          phoneIp={endpoint?.phoneIp ?? '等待连接'}
          phonePort={endpoint ? String(endpoint.phonePort) : '等待连接'}
          settings={settings}
          onAppendFiles={appendPendingFiles}
          onCancelBatchTransfers={cancelBatchTransfers}
          onCancelFileTransfer={cancelFileTransfer}
          onClearPendingAttachments={clearPendingAttachments}
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
