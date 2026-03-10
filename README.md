# Easy Chat

Design docs for a LAN-first phone-to-browser chat and file transfer product.

Current direction:

- Phone app is the only installed client
- Computer uses browser only
- Public server is allowed for pairing/bootstrap only
- All message and file payloads transfer directly between browser and phone on the same Wi-Fi

Docs:

- [PRD](./docs/PRD.md)
- [UI Spec](./docs/UI_SPEC.md)
- [Pairing Protocol](./docs/PAIRING_PROTOCOL.md)
- [Engineering Guidelines](./docs/ENGINEERING_GUIDELINES.md)
- [Design Language](./docs/DESIGN_LANGUAGE.md)

Prototype apps:

- `web`: browser pairing page and chat UI prototype
- `mobile_app`: Flutter mobile app with local WebSocket server prototype
- `pairing_service`: temporary rendezvous API for session bootstrap

Run locally:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/pairing_service
node server.js
```

```bash
cd /Users/leazer/Documents/leazer/easy_chat/web
npm install
npm run dev
```

LAN note:

- When the web page is opened via a LAN host such as `http://192.168.29.50:5173`, the app now derives the pairing service host from that page by default.
- `VITE_PAIRING_API_URL` is still supported as an override when needed.
- Use `npm run dev -- --host 0.0.0.0` during phone-on-LAN testing so the phone can access the web page from your computer's LAN IP.

Usage flow:

1. Start the pairing service:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/pairing_service
node server.js
```

2. Start the web app with LAN access enabled:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/web
npm run dev -- --host 0.0.0.0
```

3. Find the web app LAN address from the Vite output, for example:

```text
http://192.168.29.50:5173
```

4. Open that LAN address on your computer browser. Do not use the QR flow from a `localhost` page when testing with a real phone.

5. Start the Flutter app on your Android phone:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/mobile_app
flutter run
```

6. Make sure the phone and computer are on the same Wi-Fi.

7. In the phone app, scan the QR code shown in the browser.

8. On the confirm screen, verify:
- `Server` is your computer LAN IP with port `8787`, not `localhost`
- `Local IP` is the phone LAN IP

9. Tap `Start Direct Server`.

10. After direct connection is established, test:
- text message both directions
- image transfer both directions
- normal file transfer both directions
- temporary Wi-Fi interruption / reconnect to observe resume behavior

```bash
cd /Users/leazer/Documents/leazer/easy_chat/mobile_app
flutter run
```

Current implemented flow:

1. Start `pairing_service`
2. Start `web`
3. Open browser page and let it create a QR payload
4. In the phone app, scan the browser QR code
5. Manual pairing-link paste remains available as a fallback
6. The phone app starts a local WebSocket server and registers its LAN endpoint
7. The browser connects directly to the phone app
8. Text messages and files flow over that direct local WebSocket

Current usability status:

- Phone app scans the browser QR code with the real camera
- Manual pairing-link paste remains as fallback
- Phone app auto-fills its local IPv4 address before registration
- Text and file messages both work over the direct socket
- File messages now show transfer progress on both ends
- Received files are saved into the phone app's local documents directory
- Image messages render inline previews in chat
- Browser refresh can restore the most recent direct endpoint
- Browser will attempt automatic reconnect after unexpected socket disconnects
- Active file transfers can resume from the next missing chunk after unexpected socket disconnects

Current resume boundary:

- Works when the browser tab and phone app both stay alive
- Does not yet persist unfinished transfers across a browser refresh or mobile app restart

Verification:

- `cd /Users/leazer/Documents/leazer/easy_chat/pairing_service && node --check server.js`
- `cd /Users/leazer/Documents/leazer/easy_chat/web && npm run build`
- `cd /Users/leazer/Documents/leazer/easy_chat/mobile_app && flutter analyze`
- `cd /Users/leazer/Documents/leazer/easy_chat/mobile_app && flutter test`
