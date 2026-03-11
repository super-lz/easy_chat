# EasyChat UI Spec

## 1. Product Feel

The UI should feel close to a modern messenger, but more focused and less social.

Keywords:

- Clear
- Lightweight
- Personal
- Utility-first
- Fast to pair

Reference feeling:

- WeChat Web style layout
- AirDrop-like clarity for transfer states
- Minimal setup friction

## 2. Visual Direction

### Brand shape

- Friendly utility tool, not enterprise software
- Trustworthy, network-local, clean
- Slightly playful, but not toy-like

### Suggested palette

- Background: warm off-white `#F6F4EE`
- Surface: `#FFFDF8`
- Primary text: `#1E1E1A`
- Secondary text: `#676457`
- Accent green: `#2F8F5B`
- Accent green dark: `#256F47`
- Border: `#DDD6C8`
- Success: `#238A52`
- Warning: `#C17A1C`
- Error: `#B84C3A`

### Typography

- Chinese/UI font: `PingFang SC`, fallback `Noto Sans SC`
- English/UI font: `Inter` or `Manrope`
- Numeric/status text can use `JetBrains Mono` sparingly

### Style notes

- Rounded cards, not overly soft
- Calm color blocks
- Large readable QR display
- Clear distinction between sent and received bubbles
- Transfer cards should feel operational, not decorative

## 3. Information Architecture

### Phone app

- Launch / home
- Connect to computer
- Scanner
- Pairing confirmation
- Chat session
- Transfer detail sheet
- History

### Browser

- Pairing landing page
- Camera scan permission state if needed in future
- Pairing waiting state
- Chat session
- File picker / drag state
- Disconnected state

## 4. Phone App Screens

### 4.1 Home

Purpose:

- Give the user one obvious next step

Layout:

- Top: app title `EasyChat`
- Subtitle: `Same Wi-Fi, direct transfer`
- Primary card: `Connect to Computer`
- Secondary entry: `Recent History`
- Footer hint: `No desktop install required`

Primary actions:

- Tap `Connect to Computer`
- Tap `Recent History`

### 4.2 Scanner

Purpose:

- Scan browser QR code

Layout:

- Full-screen camera preview
- Framing box centered
- Top bar with close button
- Bottom helper text:
  - `Open EasyChat in your computer browser`
  - `Scan the QR code shown on screen`

States:

- Camera loading
- Permission denied
- QR detected
- Invalid/expired QR

### 4.3 Pair Confirmation

Purpose:

- Confirm this browser session before exposing direct connection

Layout:

- Icon + `Connect to this computer?`
- Computer label from pairing metadata
- Wi-Fi name
- Optional browser hint, such as `Chrome on Mac`
- Actions:
  - `Connect`
  - `Cancel`

### 4.4 Phone Chat Screen

Purpose:

- Main session experience

Layout:

- Header:
  - Computer name
  - Connection status pill
  - More menu
- Message list:
  - system items
  - text bubbles
  - image cards
  - file cards
- Composer:
  - attachment button
  - text field
  - send button

Interaction notes:

- Outgoing messages align right
- Incoming messages align left
- File cards show icon, name, size, progress
- System messages use centered muted style

### 4.5 Transfer Detail Sheet

Purpose:

- Show operational detail without polluting chat

Fields:

- File name
- File type
- Size
- Progress
- Transfer speed optional later
- Save/open action

## 5. Browser Screens

### 5.1 Pairing Landing Page

Purpose:

- Start a session with no setup

Layout:

- Left column:
  - Product title
  - Short value statement
  - 3-step instructions
- Right column:
  - Large QR card
  - Session state text
  - Refresh QR action

Suggested copy:

- Title: `Chat with your phone on this Wi-Fi`
- Body: `No desktop app. Scan once, then transfer messages and files directly on your local network.`

QR card content:

- QR code
- Session expiration countdown
- Status:
  - `Waiting for phone`
  - `Phone detected`
  - `Connecting directly`

### 5.2 Pairing Success / Connecting

Purpose:

- Bridge the mental model from cloud page to local direct chat

Layout:

- Centered status card
- Steps list:
  - `QR scanned`
  - `Phone shared local address`
  - `Connecting directly`

### 5.3 Browser Chat Screen

Purpose:

- Main browser workspace

Layout:

- Left sidebar:
  - Brand
  - Single active conversation card
  - Device status
- Main panel:
  - Header
  - Message timeline
  - Composer

Header fields:

- Phone device name
- Current Wi-Fi note
- Connection status
- Reconnect button if disconnected

Composer actions:

- Attach file
- Text input
- Send

Optional drag state:

- Full-panel dashed overlay
- Copy: `Drop files to send`

### 5.4 Disconnected State

Purpose:

- Recover cleanly when phone app closes

Layout:

- Inline banner or centered empty state
- Copy:
  - `Connection lost`
  - `Keep EasyChat open on your phone and reconnect`
- Action:
  - `Return to Pairing`

## 6. Core Components

### QR Card

- Large square QR area
- Border and light surface
- Countdown badge
- Session refresh action

### Message Bubble

- Rounded 18px corners
- Outgoing bubble in accent green with white text
- Incoming bubble in warm neutral surface with dark text
- Timestamps subtle and small

### File Card

- File icon/thumb at left
- Name + size stacked
- Progress bar for active transfer
- Status badge on right

### Status Pill

- Connected: green filled or green tint
- Connecting: amber tint
- Disconnected: gray
- Error: red tint

## 7. UX Rules

- First action on every entry screen must be obvious.
- Any step involving network state must show current progress.
- The user should never wonder whether data is direct or cloud-routed.
- File transfer state must remain visible in chat.
- Disconnects should preserve visible history inside the current session.

## 8. Copy Guidelines

- Keep wording simple and operational.
- Say `directly` and `same Wi-Fi` often where it matters.
- Avoid protocol language such as `socket`, `endpoint`, or `LAN` in user-facing copy.

Examples:

- `Keep the app open on your phone`
- `Connected directly`
- `Ready to send`
- `Waiting for your phone`
- `This QR code expires in 60s`

## 9. Responsive Behavior

### Browser desktop

- Two-column layout
- QR page centered within max width
- Chat page uses sidebar + content layout

### Browser small laptop

- Sidebar narrows
- Composer remains sticky
- File cards compress but keep progress visible

### Phone app

- One-column only
- Scanner is edge-to-edge
- Chat composer remains pinned above keyboard

## 10. MVP Design Tokens

### Radius

- Card radius: `20px`
- Bubble radius: `18px`
- Button radius: `14px`

### Spacing

- Page padding: `24px`
- Card padding: `20px`
- Bubble padding: `12px 14px`
- Vertical message gap: `10px`

### Shadows

- Use soft low-contrast shadows only
- Prefer borders plus subtle elevation over heavy blur

## 11. MVP Deliverables After This Spec

- Phone app low-fidelity wireframes
- Browser page low-fidelity wireframes
- Component inventory
- Interaction states for pairing, connected, transfer, disconnected
