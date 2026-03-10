# Easy Chat Engineering Guidelines

## Purpose

This file defines the local engineering rules for this repository.

Goal:
- keep the project easy to evolve
- avoid one-file accumulation
- keep UI, protocol, and local transport logic separable
- make later maintenance predictable

This document should be updated during development whenever the project structure or standards change.

## Product Direction

Current product shape:
- mobile app is the installed endpoint
- browser is the desktop endpoint
- pairing can use a lightweight web service
- messages and files should go direct over the local network after pairing

This means the codebase must clearly separate:
- pairing flow
- direct transport
- UI rendering
- persistence and local preferences

## Core Engineering Rules

### 1. No large mixed-responsibility files

Avoid files that simultaneously hold:
- UI layout
- state orchestration
- protocol parsing
- storage helpers
- formatting utilities

Target split:
- page/container: flow orchestration only
- components: rendering only
- hooks/services: state and side effects
- lib: pure helpers, types, storage, formatting

Soft rule:
- if a file exceeds about 250-300 lines, review whether it should be split
- if a file exceeds about 400 lines, splitting is expected unless there is a strong reason not to

### 2. Prefer composition over branching-heavy components

When a screen grows, split by visual and behavioral responsibility.

Examples:
- sidebar
- message list
- composer
- pairing panel
- settings rows

Do not keep adding conditional branches into a single render function when a stable subcomponent can be extracted.

### 3. Extract stable domain helpers early

Move reusable logic out of UI files when it becomes stable:
- browser/device naming
- local storage keys
- message formatting
- protocol type definitions
- transport payload parsing helpers

Do not duplicate:
- storage key names
- default settings
- byte formatting logic
- payload type definitions

## Current Web Structure Standard

Recommended structure under `web/src`:

- `components/`
  - visual units and small composite sections
- `hooks/`
  - reusable stateful logic and side effects
- `lib/`
  - pure helpers, constants, storage, formatting, types
- `assets/`
  - static assets only

Current direction:
- `App.tsx` should remain a composition root and high-level orchestrator
- direct socket flow should eventually move into `hooks/useEasyChat.ts`
- rendering should stay inside `components/`

## Component Rules

### Components should:
- receive explicit props
- avoid hidden dependencies
- stay focused on one UI responsibility
- avoid owning unrelated business logic

### Components should not:
- define storage keys
- parse unrelated transport payloads
- contain large inline helper blocks
- mix visual markup with local persistence logic

### Extraction rule

Extract a component when one of these becomes true:
- the JSX block has a clear name
- the block is reused
- the block has its own styling cluster
- the block makes the parent materially harder to scan

## Hook and Service Rules

Use hooks or services for:
- pairing lifecycle
- websocket lifecycle
- reconnect behavior
- message synchronization
- file transfer orchestration

Do not leave transport-heavy code inside top-level page files long term.

Planned extraction:
- `hooks/useEasyChat.ts`
- optional `lib/directTransport.ts`
- optional `lib/pairingClient.ts`

## State Management Rules

Keep state close to the layer that owns it.

Recommended boundaries:
- app/container state:
  - phase
  - session
  - endpoint
  - direct status
  - messages
  - settings
- presentational state:
  - local open/close UI state
  - temporary selection state

Avoid pushing derived values into state when they can be computed with `useMemo`.

Examples of derived values:
- visible messages
- session hint
- browser label
- connection address
- last visible user message

## Storage Rules

Local persistence must be centralized.

Current rule:
- localStorage access belongs in `web/src/lib/storage.ts`

Do not access localStorage directly from leaf components.

Any new persisted key must be added with:
- a named constant
- default behavior
- restore behavior
- invalid data fallback behavior

## Styling Rules

## Visual direction

The product should feel:
- simple
- reliable
- quiet
- practical

Avoid:
- decorative gradients as the main visual identity
- high-saturation accents
- heavy borders
- excessive explanatory text
- flashy motion

Prefer:
- restrained contrast
- calm blue-gray neutrals
- subtle panel layering
- compact spacing
- clear information hierarchy

## CSS rules

- use shared CSS variables for colors, borders, and shadows
- avoid scattering raw hex values unless there is a clear one-off reason
- if a color is reused more than once, promote it to a variable
- prefer spacing consistency over ad hoc padding values

UI should generally follow:
- full-height app shell
- no page-level scrolling when avoidable
- internal scrolling in message/content areas only

## Copy Rules

Interface copy should be:
- primarily Chinese
- short
- operational

Avoid:
- tutorial-like paragraphs inside normal screens
- mixed Chinese/English labels unless technically necessary

## Networking and Protocol Rules

Keep protocol definitions strongly typed and centralized.

Current rule:
- direct transport payload types live in `web/src/lib/types.ts`

Future rule:
- protocol serialization/parsing helpers should move into dedicated transport files if message types continue to grow

When changing protocol behavior:
- update the code
- update `docs/PAIRING_PROTOCOL.md`
- note any backward compatibility risk

## File Transfer Rules

When editing file transfer behavior:
- preserve resumable transfer assumptions unless intentionally changing them
- keep progress updates accurate
- keep sender and receiver state transitions explicit

Do not introduce:
- hidden magic constants without naming them
- duplicated chunk logic in multiple files

If chunk behavior changes, document:
- chunk size
- resume behavior
- completion signal behavior

## Validation Rules

Every meaningful web change should end with:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/web
npm run build
```

When changing mobile code, also run:

```bash
cd /Users/leazer/Documents/leazer/easy_chat/mobile_app
flutter analyze
flutter test
```

If validation is skipped, state that explicitly.

## Refactor Triggers

Refactor instead of layering more code when:
- a component starts managing multiple unrelated concerns
- UI and networking logic become entangled
- the same string constants or helpers appear in multiple files
- a file becomes hard to scan top-to-bottom
- a feature requires editing too many unrelated places

## Definition of Maintainable Changes

A change is not complete unless it leaves the codebase:
- clearer than before
- at least as testable as before
- with structure that supports the next similar feature

For this project, “working but piled up” is not acceptable as the steady-state development model.

## Next Structural Targets

Recommended next refactors:

1. Extract websocket + pairing orchestration into `hooks/useEasyChat.ts`
2. Move direct transport helpers into dedicated transport utilities
3. Introduce a small UI token map for spacing/radius if the component set continues growing
4. Add lightweight component-level tests for key rendering paths if web complexity increases

## Maintenance Note

Whenever a new pattern becomes stable, add it here.

This file should evolve with the project rather than remain static.
