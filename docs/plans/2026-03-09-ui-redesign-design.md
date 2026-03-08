# 2026-03-09 UI Redesign Design

## 1. Background and Goal

- This design resets the whole Flutter UI around clearer information architecture, stricter navigation semantics, and a minimal professional visual language.
- The product is a multi-end app, so the design first unifies semantic structure and interaction contracts, then defines mobile and desktop layouts separately.
- Priority order is: flow correctness first, task efficiency second, visual quality third.
- Delivery strategy is one-time switchover rather than phased rollout.

## 2. Decisions Already Locked

- Redesign scope is full: information architecture, interaction, and visual system.
- Settings page stays blank in the current version.
- Pool page removes cross-domain shortcut actions such as `go to cards`; users switch domains through primary navigation.
- Global sync banners are removed.
- Sync-related feedback only appears inside the pool domain.
- Product-facing and code-facing terminology both migrate from `shell` to `home page` / `homepage`.

## 3. Alternatives Considered

### 3.1 Option A (Selected): Semantic-first unified redesign

- Define one shared semantic model first, then implement platform-specific layout blueprints for mobile and desktop within the same redesign iteration.
- Pros:
  - best match for a multi-end product,
  - prevents semantic drift between platforms,
  - reduces future rework caused by inconsistent flows.
- Cons:
  - highest one-time design and implementation coordination cost.

### 3.2 Option B: Desktop-first structural redesign

- Lock desktop three-column layout first, then adapt mobile later.
- Pros:
  - desktop structure becomes clear quickly,
  - implementation complexity is front-loaded onto one platform.
- Cons:
  - mobile semantics can lag behind,
  - increases cross-platform drift risk.

### 3.3 Option C: Visual refresh before semantic cleanup

- Refresh tokens and component appearance first, then repair flows later.
- Pros:
  - fast visible improvement.
- Cons:
  - directly conflicts with the priority on navigation and interaction correctness,
  - risks preserving broken flows under a cleaner surface.

## 4. Unified Information Architecture

### 4.1 Home Page as the single top-level container

- `Home Page` is the only top-level application page.
- The home page hosts three primary content domains:
  - `Card List Page`
  - `Pool List Page`
  - `Settings Page`
- App launch always lands on `Home Page > Card List Page`.

### 4.2 Domain responsibilities

- `Card List Page`
  - card search,
  - card list browsing,
  - open editor,
  - create first card from empty state.
- `Pool List Page`
  - unjoined state,
  - joined state,
  - join/create/approve/exit/dissolve actions,
  - all sync-related recoverable feedback.
- `Settings Page`
  - blank placeholder only in this version,
  - no pool entry,
  - no diversion flow.

### 4.3 Terminology standard

- Product and design language uses readable names instead of `S1-S5`.
- The stable page vocabulary is:
  - `Home Page`
  - `Card List Page`
  - `Pool List Page`
  - `Settings Page`
- Sync is no longer modeled as a standalone page or global layer; it is a local feedback concern inside the pool domain.

## 5. Unified Navigation and Back Semantics

### 5.1 Primary navigation

- Primary navigation always exposes exactly three destinations:
  - cards,
  - pool,
  - settings.
- Mobile uses a bottom tab bar.
- Desktop uses a left navigation column.
- Different trigger methods are allowed, but the result semantics must stay identical.

### 5.2 Back behavior

- From `Pool List Page` or `Settings Page`, system back returns to `Card List Page`.
- From the root state of `Card List Page`, system back opens exit confirmation.
- Exit confirmation supports `confirm exit` and `cancel`.
- Multi-step return chains are forbidden for returning to the main task path.

### 5.3 Pool entry constraints

- `Create Pool` and `Scan to Join` only appear in `Pool List Page` when the user is unjoined.
- Settings page must not expose pool creation or join entry.
- After create/join succeeds, the user remains in the pool domain; no cross-domain redirect is introduced.

## 6. State Machines and Observable Flows

### 6.1 Home page state machine

States:

- `HomePage.CardList`
- `HomePage.PoolList`
- `HomePage.Settings`
- `HomePage.ExitConfirm`

Transitions:

- app launch complete -> `HomePage.CardList`
- switch to pool -> `HomePage.PoolList`
- switch to settings -> `HomePage.Settings`
- back from pool/settings -> `HomePage.CardList`
- back from card root -> `HomePage.ExitConfirm`
- cancel exit -> `HomePage.CardList`
- confirm exit -> app termination

### 6.2 Card editing state machine

States:

- `CardList.Idle`
- `CardEditor.Open`
- `CardEditor.Dirty`
- `CardEditor.Saving`
- `CardEditor.SaveSucceeded`
- `CardEditor.SaveFailed`
- `CardEditor.LeaveGuard`

Transitions:

- open create/edit -> `CardEditor.Open`
- change title/body -> `CardEditor.Dirty`
- save -> `CardEditor.Saving`
- save success -> `CardEditor.SaveSucceeded` -> `CardEditor.Open`
- save failure -> `CardEditor.SaveFailed`
- retry save -> `CardEditor.Saving`
- any leave intent from dirty editor -> `CardEditor.LeaveGuard`
- choose `save and leave` -> `CardEditor.Saving` -> target page
- choose `discard changes` -> target page
- choose `cancel` -> `CardEditor.Dirty`

### 6.3 Pool state machine

States:

- `PoolList.Unjoined`
- `PoolList.JoinRequesting`
- `PoolList.Joined`
- `PoolList.JoinFailed(code)`
- `PoolList.ExitConfirm`
- `PoolList.Exiting`
- `PoolList.ExitPartialFailed`

Transitions:

- create pool from unjoined -> `PoolList.Joined`
- scan to join -> `PoolList.JoinRequesting`
- join success -> `PoolList.Joined`
- join failure -> `PoolList.JoinFailed(code)`
- choose recovery action -> `PoolList.Unjoined` or `PoolList.JoinRequesting`
- exit pool -> `PoolList.ExitConfirm`
- confirm exit -> `PoolList.Exiting`
- exit success -> `PoolList.Unjoined`
- partial cleanup failure -> `PoolList.ExitPartialFailed`
- retry cleanup success -> `PoolList.Unjoined`

### 6.4 Sync feedback model

- Sync is not a standalone page and not a global banner system.
- Sync only appears as local pool feedback.
- Allowed local feedback states are:
  - `NoFeedback`
  - `RecoverableWarning`
  - `RecoverableError`
- Card CRUD remains available regardless of sync outcome.

## 7. Mobile Layout Blueprint

### 7.1 Home page structure

- Layout: top bar (lightweight, optional actions) + content area + bottom tab bar.
- Bottom tabs are fixed to `Cards / Pool / Settings`.
- Cards is the default selected tab.

### 7.2 Card list page

- Top: search field.
- Middle: list content.
- Empty state: explain why empty and how to create the first card.
- Primary action: floating create button.
- Editor opens as a dedicated editing context.

### 7.3 Pool list page

- `Unjoined`: show only `Create Pool` and `Scan to Join`.
- `Joined`: show pool info, members, approval zone when allowed, and exit action.
- `Failure`: show error meaning and next action side by side.
- Sync-related recoverable feedback stays inside this page only.

### 7.4 Settings page

- Fully blank placeholder in this version.
- Still reachable from primary navigation and one-step removable by switching tabs.

## 8. Desktop Layout Blueprint

### 8.1 Three-column home page

- Left column: primary navigation.
- Middle column: list and search workspace.
- Right column: detail and editing workspace.
- Suggested width ranges:
  - left: `220~260`
  - middle: `340~420`
  - right: remaining width, and not less than `480`

### 8.2 Card list page on desktop

- Left: cards selected.
- Middle: search + list + create entry.
- Right: current card detail/editor.
- Desktop optimizes for browse-and-edit side by side.

### 8.3 Pool list page on desktop

- Middle: pool state panel and relevant lists.
- Right: member detail, approval operations, exit/dissolve confirmations.
- Sync/recovery information remains local to this domain.

### 8.4 Settings page on desktop

- Left: settings selected.
- Middle and right: blank placeholder for this version.

### 8.5 Leave protection on desktop

- If card editing is dirty and the user attempts to leave the editing context, a blocking modal must appear.
- Left and middle columns remain visible but non-interactive while the modal is open.
- The user must explicitly choose one of:
  - `Save and Leave`
  - `Discard Changes`
  - `Cancel`
- Only after a choice resolves may other columns become interactive again.
- This matches mobile semantics: no silent loss and no unconfirmed navigation out of dirty editing.

## 9. Visual Language

### 9.1 Overall tone

- Minimal, professional, calm, and trustworthy.
- Information clarity comes before decoration.
- Avoid high-saturation accents, ornamental backgrounds, and heavy shadow stacks.

### 9.2 Color usage

- Neutral surfaces form the baseline.
- Brand/primary color is reserved for the current primary action and active selection.
- Semantic colors stay strict:
  - success for confirmed success,
  - warning for recoverable risk,
  - error for failures and dangerous actions.
- Ordinary info must not reuse error styling.

### 9.3 Typography and spacing

- Stable hierarchy: page title / section title / body / secondary info / button label.
- Secondary text must remain readable.
- Shared spacing tokens:
  - `8 / 12 / 16 / 24 / 32`
- Mobile horizontal padding centers on `16`.
- Desktop horizontal padding centers on `24~32`.

### 9.4 Buttons and containers

- Each page should expose only one visually dominant primary action.
- Dangerous actions must remain visually distinct from standard actions.
- Prefer subtle borders and clear spacing over thick shadows.
- Keep corner radius and container treatment consistent across pages.

### 9.5 Motion and feedback

- Motion exists only to support transitions and state changes.
- Common duration range: `120~220ms`.
- Processing feedback appears immediately; animation is never a substitute for feedback.

## 10. Acceptance and Test Mapping

- Launch enters `HomePage.CardList` by default.
- Primary navigation only exposes `Cards / Pool / Settings`.
- Settings page is blank and has no pool entry.
- Pool create/join entry only appears in `PoolList.Unjoined`.
- Back from non-cards domain returns to cards.
- Back from card root opens exit confirmation.
- Dirty card editing always enters blocking leave protection before leaving.
- Desktop leave protection blocks left/middle interaction until resolved.
- Pool failures always show `what happened + next action`.
- No global sync banner remains.
- Card CRUD is never blocked by sync failure.

## 11. Implementation Impact

- Rename `shell` terminology in Flutter UI code, controllers, layout widgets, and tests to `homepage` terminology.
- Rebuild primary navigation around the `Home Page` container model.
- Remove cross-domain shortcuts that bypass primary navigation semantics.
- Move sync feedback to the pool domain and remove global sync affordances.
- Rework mobile and desktop layouts under one semantic contract with separate layout implementations.

## 12. Out of Scope

- New business capabilities beyond existing cards, pool, and settings domains.
- New sync product features beyond localizing existing feedback.
- Expanding settings into a full configuration center in this version.
