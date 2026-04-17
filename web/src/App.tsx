import { ChatScreen } from './components/ChatScreen'
import { PairingScreen } from './components/PairingScreen'
import { getBrowserName, getDeviceInfo } from './lib/browser'
import { useEasyChat } from './hooks/useEasyChat'
import './App.css'

function App() {
  const browserName = getBrowserName(navigator.userAgent)
  const deviceInfo = getDeviceInfo(navigator.userAgent)
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
          countdown={countdown}
          deviceInfo={deviceInfo}
          isLoading={isLoading}
          session={session}
        />
      ) : (
        <ChatScreen
          canCompose={canCompose}
          canSend={canSend}
          connectionState={connectionState}
          conversationTitle={conversationTitle}
          draft={draft}
          error={error}
          fileInputRef={fileInputRef}
          localDeviceInfo={deviceInfo}
          localDeviceName={browserName}
          messages={visibleMessages}
          pendingAttachments={pendingAttachments}
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
