# EasyChat PRD

## 1. Product Summary

EasyChat is a LAN-first chat-style transfer tool for one user's phone and computer.

Core constraints:

- The phone app is the only installed client.
- The computer must not install any software.
- The computer uses a browser only.
- Message content and file content must never be forwarded by a third-party server.
- A public web page may be used only for pairing and session bootstrap.
- The phone app only needs to be available while it is open in the foreground.

Core experience:

1. User opens the phone app.
2. User opens the EasyChat pairing page on the computer browser.
3. The browser shows a QR code.
4. The phone app scans the QR code.
5. The phone app reports its current LAN address and a temporary token to the pairing service.
6. The browser receives the LAN connection info and connects directly to the phone app.
7. Chat messages and files are exchanged in a WeChat-like conversation UI.

## 2. Product Goals

### Primary goals

- Let a user quickly send text, images, and files between phone and computer on the same Wi-Fi.
- Keep the interaction model chat-based rather than folder-based.
- Require no desktop install.
- Keep all payload transfer peer-to-peer on the local network.

### Non-goals for MVP

- Cross-network transfer
- Multi-user chat
- Account system
- Cloud sync
- Background message delivery
- Long-lived device discovery
- Audio/video calls
- End-to-end encrypted multi-device identity system

## 3. Users and Main Use Cases

### Target user

- A single user moving files and notes between their own phone and computer

### Main use cases

- Send a screenshot from phone to computer
- Send a file from computer to phone
- Copy a short note, code snippet, or URL across devices
- Transfer several images in one session
- Reconnect to the same computer quickly during an active session

## 4. Core Product Principles

- Pair fast: opening app plus scanning once should be enough.
- Chat first: every transfer appears as a conversation item.
- Local first: after pairing, all payloads stay on the LAN.
- Temporary by default: session state can be lightweight and local.
- Minimal trust in server: the public service only coordinates pairing metadata.

## 5. System Model

### Roles

- Phone app: local transport host
- Browser page: pairing client and chat UI
- Pairing service: temporary rendezvous only

### Responsibility split

#### Pairing service can do

- Serve the pairing page
- Create temporary pairing sessions
- Generate QR code payloads
- Accept phone registration for a session
- Notify browser that phone LAN info is ready

#### Pairing service cannot do

- Proxy chat messages
- Proxy file bytes
- Persist message history
- Store uploaded transfer payloads

#### Phone app does

- Scan QR code
- Start LAN server while foregrounded
- Register LAN endpoint to pairing service
- Accept direct browser connection
- Send and receive messages and files
- Persist local session history

#### Browser page does

- Create pairing session
- Display QR code
- Receive phone LAN endpoint metadata
- Connect directly to phone app over LAN
- Render chat UI
- Send and receive messages and files

## 6. High-Level User Flow

### First connection

1. User opens app and taps `Connect to Computer`.
2. App opens scan screen and prepares local LAN service.
3. User opens `https://easychat.example.com` on computer.
4. Browser creates temporary session and shows QR code.
5. User scans QR code with phone app.
6. App confirms the computer name and Wi-Fi network.
7. App posts `{sessionId, phoneIp, phonePort, token, deviceName}` to pairing service.
8. Browser receives the endpoint metadata.
9. Browser opens a direct connection to phone app.
10. App shows `Connected`.
11. Browser enters chat screen.

### In-session transfer

1. Either side sends text.
2. Either side taps attachment and selects file(s).
3. Receiver sees transfer card with progress.
4. Completed item becomes a normal chat bubble or file card.

### Session end

1. User leaves the app or taps disconnect.
2. Local LAN service stops.
3. Browser shows disconnected state with reconnect hint.

## 7. Functional Requirements

### FR-1 Pairing

- Browser can create a temporary pairing session.
- Browser can render a QR code containing pairing URL and challenge.
- Phone app can scan the QR code.
- Phone app can validate the QR payload version and expiration.
- Phone app can register its LAN endpoint and one-time token.
- Browser can receive pairing completion in near real time.

### FR-2 Direct LAN connection

- Browser can connect to phone app over LAN after pairing.
- Phone app exposes a direct connection endpoint only while pairing/session is active.
- Invalid or expired tokens are rejected.
- Connection state is visible on both ends.

### FR-3 Messaging

- Phone and browser can exchange text messages in real time.
- Messages include sender, timestamp, status, and body.
- Failed send state is visible.

### FR-4 File transfer

- Phone and browser can send files in either direction.
- MVP supports images, videos, documents, and arbitrary files.
- Transfer progress is shown per file.
- Receiver can open or save received files.
- Sender and receiver can detect transfer failure.

### FR-5 Local history

- Phone stores session history locally.
- Browser stores recent session state locally for the active tab/device.
- Payload history is not stored by the pairing service.

### FR-6 Session security

- Pairing session expires quickly.
- Direct connection requires one-time token.
- Browser origin is validated by the phone app.
- Optional manual confirm step exists on phone before first direct connect.

## 8. Non-Functional Requirements

### Performance

- Pairing should usually complete within 3 seconds on a healthy LAN.
- Text messages should appear near real time.
- Transfers should start within 1 second after accept/connect state is ready.

### Reliability

- App foreground only is acceptable for MVP.
- Active session should recover from short Wi-Fi jitter where possible.
- Browser refresh should allow a fast reconnect flow during the same app-open window.

### Security

- Pairing metadata must expire quickly.
- File and message payloads must not pass through public service.
- Token replay should be prevented.

### Privacy

- No account required for MVP.
- No server-side message retention.
- Pairing service stores only short-lived metadata needed for active session bootstrap.

## 9. Proposed Technical Direction

### Recommended transport for MVP

- Pairing: HTTPS + WebSocket/SSE on public service
- Direct channel: secure WebSocket or WebSocket over LAN
- File transport: binary frames over direct socket in chunks

### Why this direction

- Simpler than WebRTC for LAN-only transfer
- Keeps browser as a pure client
- Avoids needing TURN or signaling for payload transport
- Works with the product constraint that the phone app is the active local service

### Suggested connection model

- Public page creates `pairingSession`
- Phone app scans `pairingUrl`
- Phone app opens LAN service if not already running
- Phone app registers direct endpoint
- Browser switches from `pairing mode` to `direct mode`
- All subsequent operations use direct channel only

## 10. Data Model

### Pairing session

- `sessionId`
- `challenge`
- `expiresAt`
- `browserName`
- `browserIpHint` optional
- `status`

### Phone endpoint registration

- `sessionId`
- `phoneDeviceName`
- `wifiName`
- `phoneIp`
- `phonePort`
- `token`
- `protocolVersion`

### Chat message

- `id`
- `type` = `text | file | image | system`
- `sender` = `phone | browser`
- `timestamp`
- `status`
- `text`
- `fileMeta` optional

### File metadata

- `transferId`
- `name`
- `size`
- `mimeType`
- `sha256` optional in MVP, recommended
- `thumbnail` optional for images

## 11. Direct Protocol Outline

### Control events

- `hello`
- `auth`
- `auth_ok`
- `auth_failed`
- `message_send`
- `message_ack`
- `file_offer`
- `file_accept`
- `file_chunk`
- `file_complete`
- `file_error`
- `disconnect`

### Authentication flow

1. Browser connects to phone direct endpoint.
2. Browser sends `hello`.
3. Phone responds with session challenge.
4. Browser sends `auth` with one-time token.
5. Phone validates token and session.
6. Phone returns `auth_ok`.

## 12. MVP Scope

### Included

- Android app
- Mobile foreground-only availability
- Browser pairing page
- Browser chat page
- Text messages
- Image/file transfer
- Progress states
- Session disconnect/reconnect while app remains open

### Deferred

- iOS
- Multi-computer support
- Drag-and-drop polish
- Large-file resume
- LAN auto-discovery
- Device trust list
- Encrypted payload storage

## 13. Risks and Decisions

### Key risks

- Browser security policy when connecting from public page to LAN endpoint
- Local network permission UX on mobile platforms
- LAN IP changes during active session
- HTTPS page to local insecure socket compatibility constraints

### Explicit decisions

- Server involvement stops after pairing metadata exchange.
- Direct payload transport is LAN only.
- The phone app is the connection host during the session.
- Background availability is not required for MVP.
- Product is optimized for self-transfer, not chat between different people.

## 14. Success Criteria

- A user can connect phone and browser in under 10 seconds.
- A short text message can be exchanged both directions.
- A photo can be transferred both directions successfully on same Wi-Fi.
- A file transfer is visible as a chat item with progress and completion state.
- No message body or file bytes traverse the public pairing service.

## 15. Open Questions Before Build

- Whether the direct LAN endpoint should use `ws://` only for MVP or support a local secure transport strategy
- Whether browser camera-based QR scan is the only computer entry flow or whether manual code entry is also needed
- Whether browser history should persist per session only or across multiple sessions on the same machine
