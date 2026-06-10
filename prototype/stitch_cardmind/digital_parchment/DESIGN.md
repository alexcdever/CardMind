---
name: Digital Parchment
colors:
  surface: '#f9f9f8'
  surface-dim: '#dadad9'
  surface-bright: '#f9f9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f3'
  surface-container: '#eeeeed'
  surface-container-high: '#e8e8e7'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#41484a'
  inverse-surface: '#2f3130'
  inverse-on-surface: '#f1f1f0'
  outline: '#71787a'
  outline-variant: '#c1c8ca'
  surface-tint: '#3e646e'
  primary: '#315861'
  on-primary: '#ffffff'
  primary-container: '#4a707a'
  on-primary-container: '#caf2fe'
  inverse-primary: '#a5cdd8'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e4e2e1'
  on-secondary-container: '#656464'
  tertiary: '#6e4a2e'
  on-tertiary: '#ffffff'
  tertiary-container: '#896244'
  on-tertiary-container: '#ffe7d8'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c1e9f5'
  primary-fixed-dim: '#a5cdd8'
  on-primary-fixed: '#001f26'
  on-primary-fixed-variant: '#254c55'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c6'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474747'
  tertiary-fixed: '#ffdcc4'
  tertiary-fixed-dim: '#eebd99'
  on-tertiary-fixed: '#2e1501'
  on-tertiary-fixed-variant: '#613f24'
  background: '#f9f9f8'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
  paper-white: '#F9F9F8'
  ink-charcoal: '#1A1A1A'
  graphite-gray: '#666666'
  muted-border: '#E2E2E0'
  active-teal: '#4A707A'
  danger-red: '#A34F4F'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  editor-text:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  status-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  unit-1: 4px
  unit-2: 8px
  unit-4: 16px
  unit-6: 24px
  sidebar-width: 260px
  list-width: 360px
  editor-max-width: 48rem
---

## Brand & Style
The design system is centered on the concept of "Digital Paper"—a philosophy that prioritizes content longevity, local-first reliability, and cognitive focus. It targets power users who value speed and clarity over decorative flourishes. 

The aesthetic is **Minimalist** and **Functional**, drawing inspiration from precision tools and technical documentation. It avoids the "weight" of traditional software by using subtle borders and intentional whitespace rather than heavy drop shadows or vibrant gradients. The UI should feel like a high-performance, low-latency extension of the user's thought process—robust, quiet, and dependable.

## Colors
The palette is built on a "Paper and Ink" foundation. `paper-white` serves as the primary canvas color, providing a softer, less straining experience than pure #FFFFFF. `ink-charcoal` is used for primary body text to ensure maximum contrast and legibility.

A single accent, `active-teal`, is used sparingly to denote focus, primary actions, and active navigation states. This ensures that the user's attention is only drawn to interactive elements when necessary. Use `muted-border` for all structural divisions to maintain the local-first, robust "sheet" metaphor.

## Typography
This design system utilizes a dual-font approach. **Inter** is the workhorse for all UI elements, providing a neutral, systematic feel that disappears into the background. For the actual note-writing experience, **JetBrains Mono** is employed to emphasize the "plain-text" and "local-first" nature of the app.

- **UI Elements:** Use Inter for navigation, buttons, and headers.
- **Note Content:** Use JetBrains Mono in the editor to provide a structured, technical feel that aids in proofreading and clarity.
- **Hierarchy:** Lean on weight (SemiBold) and color (Charcoal vs. Gray) rather than large scale shifts to keep the interface compact.

## Layout & Spacing
The layout follows a strict **fixed-pane** model for desktop and a **stack-based** model for mobile.

- **Desktop (3-Pane):** Sidebar (260px) | Note List (360px) | Editor (Fluid with 48rem max-width). The editor should be centered within its pane when the window exceeds 48rem.
- **Mobile (2-Tab):** A bottom navigation bar with exactly two items: "Cards" and "Pool."
- **Grid:** A consistent 4px/8px incremental grid. All padding and margins must be multiples of 4px. Use 16px (unit-4) for standard container padding and 8px (unit-2) for tight list-item spacing.

## Elevation & Depth
Depth is conveyed through **Tonal Layers** and **Subtle Outlines** rather than shadows. 

- **Level 0 (Background):** The main application frame uses the base neutral color.
- **Level 1 (Surface):** Secondary panes like the sidebar use a slightly darker or lighter tint (1-2% variance) to differentiate from the primary canvas.
- **Borders:** Instead of shadows, use 1px solid borders in `muted-border` (#E2E2E0) to define the edges of cards, panes, and input fields.
- **Active State:** When a card or item is selected, apply a 2px left-border of `active-teal` to indicate focus without changing the element's elevation.

## Shapes
The shape language is **Soft** but disciplined. 
- **Standard Corners:** Use 0.25rem (4px) for cards, buttons, and input fields. This provides a professional, "tooled" look that feels more modern than sharp corners but more serious than highly rounded ones.
- **Interactive Elements:** Buttons and tags maintain the same 4px radius. 
- **Icons:** Use linear, stroke-based icons (1.5px or 2px stroke weight) to match the border-heavy aesthetic of the UI.

## Components
- **Buttons:** Flat surfaces with `muted-border`. Primary buttons use a `active-teal` background with white text. Secondary buttons use a white background and teal text/border. No shadows.
- **Note Cards:** Rectangular containers with a bottom-border separator. On hover/active, the background shifts slightly to a cooler gray or receives the teal left-accent.
- **Input Fields:** Minimalist design with only a bottom border (2px) that turns `active-teal` on focus. No encompassing box unless used for search bars.
- **Pool Cards:** Large, centered cards for the "Unjoined" state. These should use a 1px border and more generous internal padding (unit-6) to denote their status as primary setup actions.
- **Confirmation Dialogs:** Destructive actions (Delete/Disband) use a high-contrast modal with `danger-red` accents for the "Confirm" action.
- **Sync Indicator:** A small, text-based label in the sidebar or bottom-bar (e.g., "• Synced" or "• 2 Pending") using the `status-sm` typography role. Avoid intrusive icons.