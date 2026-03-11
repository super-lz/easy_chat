import { ChatScreen } from './components/ChatScreen'
import { PairingScreen } from './components/PairingScreen'
import { getBrowserName } from './lib/browser'
import { useEasyChat } from './hooks/useEasyChat'
import './App.css'

function App() {
  const browserName = getBrowserName(navigator.userAgent)
  const currentPageOrigin = window.location.origin
  const pairingServiceOrigin = import.meta.env.VITE_PAIRING_API_URL || currentPageOrigin
  const {
    canSend,
    connectionAddress,
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
    removePendingAttachment,
    session,
    settings,
    visibleMessages,
    appendPendingFiles,
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
          pairingServiceOrigin={pairingServiceOrigin}
          pageOrigin={currentPageOrigin}
          session={session}
        />
      ) : (
        <ChatScreen
          canSend={canSend}
          connectionAddress={connectionAddress}
          conversationTitle={conversationTitle}
          directStatus={directStatus}
          draft={draft}
          error={error}
          fileInputRef={fileInputRef}
          localDeviceName={browserName}
          messages={visibleMessages}
          pageOrigin={currentPageOrigin}
          pairingServiceOrigin={pairingServiceOrigin}
          pendingAttachments={pendingAttachments}
          settings={settings}
          onAppendFiles={appendPendingFiles}
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
