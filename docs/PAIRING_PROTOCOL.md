# Pairing Protocol

## Purpose

The pairing service is a temporary rendezvous layer only. It never relays message bodies or file bytes.

## Flow

1. Browser creates a pairing session with `POST /api/pairings`.
2. Service returns:
   - `sessionId`
   - `challenge`
   - `expiresAt`
   - `pairingUrl`
3. Browser renders `pairingUrl` as QR content.
4. Phone app scans or receives the pairing URL.
5. Phone app parses:
   - `sessionId`
   - `challenge`
   - `serverUrl`
6. Phone app sends endpoint registration to `POST /api/pairings/:sessionId/register`.
7. Browser listens to `GET /api/pairings/:sessionId/events` with SSE.
8. Service pushes phone endpoint metadata back to the browser.
9. Browser can then open the direct LAN connection to the phone app.

## Session creation

`POST /api/pairings`

Response:

```json
{
  "sessionId": "uuid",
  "challenge": "random-challenge",
  "expiresAt": 1773140000000,
  "status": "waiting",
  "pairingUrl": "easychat://pair?sessionId=...&challenge=...&serverUrl=http%3A%2F%2Flocalhost%3A8787"
}
```

## Session events

`GET /api/pairings/:sessionId/events`

SSE events:

- `status`
- `expired`

`status` payload:

```json
{
  "sessionId": "uuid",
  "status": "phone_registered",
  "phoneEndpoint": {
    "deviceName": "Leazer Phone",
    "phoneIp": "192.168.1.23",
    "phonePort": 9763,
    "token": "token-123",
    "wifiName": "Leazer Home 5G",
    "protocolVersion": 1
  }
}
```

## Phone registration

`POST /api/pairings/:sessionId/register`

Request body:

```json
{
  "challenge": "random-challenge",
  "deviceName": "Leazer Phone",
  "wifiName": "Leazer Home 5G",
  "phoneIp": "192.168.1.23",
  "phonePort": 9763,
  "token": "token-123",
  "protocolVersion": 1
}
```

## Current implementation status

- Browser: implemented
- Pairing service: implemented
- Phone app camera QR scan: implemented
- Phone app manual pairing-link input fallback: implemented
- Direct WebSocket transport for text messages: implemented
- Direct WebSocket transport for files: implemented

## Direct WebSocket transport

After pairing, the browser connects directly to:

`ws://<phoneIp>:<phonePort>/ws?token=<token>`

The phone app validates the token from query params before upgrading.

### Browser to phone message

```json
{
  "type": "message",
  "text": "hello from browser"
}
```

### Phone to browser message

```json
{
  "type": "message",
  "sender": "phone",
  "text": "hello from phone"
}
```

### System message

```json
{
  "type": "system",
  "text": "Direct socket connected"
}
```

### Keepalive

```json
{
  "type": "ping"
}
```

Response:

```json
{
  "type": "pong"
}
```

## File transfer over direct WebSocket

Files are transferred over the same direct socket using JSON control messages plus resumable binary chunk frames:

- `file_offer`
- `file_resume`
- `file_complete`
- `file_received`
- `file_cancel`

### File offer

```json
{
  "type": "file_offer",
  "transferId": "file-1773140",
  "sender": "browser",
  "name": "notes.pdf",
  "mimeType": "application/pdf",
  "size": 18342,
  "chunkSize": 131072,
  "totalChunks": 1
}
```

### Resume request / ack

Receiver tells sender which next chunk index is still needed.

```json
{
  "type": "file_resume",
  "transferId": "file-1773140",
  "nextChunk": 3
}
```

### File chunk

Chunk data is sent as a binary WebSocket frame instead of base64 JSON.

Binary frame layout:

- `1 byte`: frame type, currently `1`
- `2 bytes`: UTF-8 byte length of `transferId`
- `4 bytes`: `chunkIndex`
- `N bytes`: UTF-8 `transferId`
- remaining bytes: raw chunk payload

### File complete

```json
{
  "type": "file_complete",
  "transferId": "file-1773140"
}
```

### File received

Receiver sends this after the full file has been reassembled successfully.

```json
{
  "type": "file_received",
  "transferId": "file-1773140"
}
```

### File cancel

Either side can cancel an in-flight transfer.

```json
{
  "type": "file_cancel",
  "transferId": "file-1773140"
}
```

### Current client behavior

- Browser can choose one local file and send it directly to the phone
- Phone app can choose one local file and send it directly to the browser
- Browser assembles received files into `Blob` URLs for download
- Phone app saves received files into its local app documents directory and shows them as chat items
- Phone app auto-detects a local IPv4 address before endpoint registration
- Both clients show file transfer progress during active transfer
- Image files are previewed inline in chat on both sides
- Browser caches the last direct phone endpoint locally for page refresh recovery
- Browser retries direct socket connection automatically after unexpected disconnects
- If the direct socket drops during a transfer, sender and receiver resume from the next missing chunk after reconnect
- Text messages stay responsive during file transfer because file chunks are sent in throttled batches instead of flooding the socket buffer

### Current resume scope

- Supported: unexpected socket disconnects while browser tab and phone app stay alive
- Supported: automatic direct reconnection followed by chunk resume
- Not yet supported: browser refresh during an active outgoing browser file transfer
- Not yet supported: phone app restart during an active transfer
