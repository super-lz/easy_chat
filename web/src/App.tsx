import { ChatScreen } from './components/ChatScreen'
import { PairingScreen } from './components/PairingScreen'
import { getBrowserName } from './lib/browser'
import { useEasyChat } from './hooks/useEasyChat'
import './App.css'

function App() {
  const browserName = getBrowserName(navigator.userAgent)
  const {
    canSend,
    conversationTitle,
    countdown,
    directStatus,
    draft,
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
          session={session}
        />
      ) : (
        <ChatScreen
          canSend={canSend}
          conversationTitle={conversationTitle}
          directStatus={directStatus}
          draft={draft}
          fileInputRef={fileInputRef}
          localDeviceName={browserName}
          messages={visibleMessages}
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
