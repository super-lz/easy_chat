# Easy Chat Design Language

## Source Direction

This project borrows visual language inspiration from:
- Smartisan OS page: [https://www.smartisan.com/os/#/6-x](https://www.smartisan.com/os/#/6-x)

This is style inspiration only.
We do not copy layouts mechanically.

## Design Goal

Easy Chat web should feel:
- concise
- precise
- reliable
- calm
- polished without showing off

It should look like a carefully designed tool, not a marketing page and not a generic admin panel.

## Smartisan-Inspired Traits We Intentionally Keep

### 1. Calm surfaces

- large clean surfaces
- subtle contrast between layers
- bright, almost paper-like panels
- restrained shadows

### 2. High polish without visual noise

- no loud gradients
- no loud borders
- no saturated accent blocks everywhere
- no decorative clutter

### 3. Precise typography

- strong headline hierarchy
- compact interface copy
- slightly denser body layout
- clear separation between primary and secondary information

### 4. Refined geometry

- soft rounded corners
- consistent panel radii
- gentle separation between sections
- spacious but controlled padding

### 5. Product-like reliability

- cool neutral palette
- deep blue-gray as the main accent family
- information first, decoration second

### 6. Light interaction motion

- very short transitions
- subtle surface lift on hover
- gentle fade/slide on section entry
- motion should feel almost invisible rather than playful

## Color Direction

Use:
- cool gray backgrounds
- near-white cards
- smartisan-like light gray text system
- restrained blue primary accent similar in spirit to `#5079d9`
- very soft status tints

Avoid:
- playful gradients
- overly warm beige palettes
- highly saturated “tech product” blues
- neon success/error colors

Reference feeling from the Smartisan page:
- body and nav text often live around soft gray values such as `#666` and `#9093a7`
- transitions are short, roughly `0.15s`
- surfaces stay bright and almost monochrome, with blue used sparingly

## Layout Direction

### Pairing page

Should feel like:
- a product setup surface
- centered, calm, and premium

Should not feel like:
- a verbose landing page
- a feature brochure

### Chat page

Should feel like:
- a desktop chat tool
- dense enough for real use
- quiet enough for long sessions

Hierarchy:
- left: navigation, session, settings
- right: active conversation
- bottom-left: persistent status and disconnect action

## Component Styling Rules

### Sidebar

- slightly darker than the main panel
- low-noise sections
- cards should feel embedded, not floating heavily

### Message area

- softer canvas than the sidebar
- message bubbles must remain readable and light
- sent and received messages should be differentiated without shouting

### Composer

- compact
- obvious input focus
- action buttons should feel deliberate, not bulky

## Copy Style

UI copy should be:
- Chinese first
- short
- functional
- non-promotional

Avoid “marketing voice” inside the product UI.

## Implementation Rules

When adjusting UI in the future:

1. Update shared variables first
2. Prefer component-level refinement over page-wide hacks
3. Keep spacing and radii on a small reusable scale
4. If a new visual pattern appears more than once, standardize it

## Current Design System Intention

The current Easy Chat web should move toward:
- cool gray page background
- white main content surfaces
- subtle blue-gray accents
- compact, desktop-first chat density
- restrained visual hierarchy similar in spirit to Smartisan product pages

This document should evolve as the UI system becomes more concrete.
