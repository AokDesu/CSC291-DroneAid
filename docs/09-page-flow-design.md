# DroneAid — Full Page & Flow Design

- **Date:** 2026-05-19
- **Owners:** All (this is the team-shared source of truth for screens + flows)
- **Audience:** human reviewers AND Claude Code (must read end-to-end before writing UI code)
- **Companion docs:** `01-concepts.md` (functional list), `07-software-architecture.md` (technical), `08-implementation-diagram.md` (sequences + state machines), and the full spec under `superpowers/specs/`.

> **Read order for implementers:** §1 conventions → §2 components → §3 navigation → §4 seed data → §5 user pages → §6 admin pages → §7 flows → §8 errors → §9 validation. The page sections cite component IDs and flow IDs; do not skip §1–§3.

---

## 1. Conventions

### 1.1 Identifier system

| Prefix | Meaning |
|---|---|
| `P-U-NN` | User-side page |
| `P-A-NN` | Admin-side page |
| `C-NN` | Reusable component |
| `F-NN` | Flow (cross-page interaction) |
| `E-NN` | Error / edge case |
| `V-NN` | Validation rule |

Every screen, component, flow, and validation rule has a stable ID. Cross-reference by ID, not by name.

### 1.2 Visual design tokens

#### Theme

- **Base:** Material 3, generated from seed color `#006A6A` (teal). Both light and dark variants generated automatically by `ColorScheme.fromSeed()`.
- **Brightness modes:** `system` (default), `light`, `dark`. User toggles in Settings (P-U-09).
- **Typography:** Material 3 typography. Heading: `headlineSmall` (24/32). Body: `bodyLarge` (16/24). Label: `labelLarge` (14/20). System font (Roboto / SF).

#### Spacing scale

| Token | px |
|---|---|
| `space-xs` | 4 |
| `space-sm` | 8 |
| `space-md` | 16 |
| `space-lg` | 24 |
| `space-xl` | 32 |
| `space-2xl` | 48 |

Use multiples of 4. Default page padding: `space-md` (16) horizontally, `space-md` vertically.

#### Shapes

- Cards: `RoundedRectangleBorder(radius: 12)`.
- Buttons: M3 default (`FilledButton`, `OutlinedButton`, `TextButton`).
- Map markers: 32×32 circular with 2px white border.

#### Motion

- Page transitions: M3 shared-axis (forward/back).
- Status updates: `AnimatedSwitcher` 200 ms fade.
- Drone marker movement: `AnimationController` with 60 fps tick, linear easing.

### 1.3 Copy style

- All UI strings in **English only** for v1.
- Tone: clear, calm, factual. No exclamation marks except in errors.
- Date format: `MMM d, h:mm a` (e.g. `Jun 4, 7:42 PM`).
- Distance: kilometers with one decimal (e.g. `4.2 km`).
- ETA: relative (`in 12 min`) plus absolute (`7:42 PM`).
- All copy lives in `app/lib/l10n/app_en.arb`; the doc uses inline copy for readability but every string is keyed.

### 1.4 Loading / empty / error pattern

Every screen that fetches data has four states. Each page section below specifies the exact copy for each state.

| State | Treatment |
|---|---|
| `loading` | Centered `CircularProgressIndicator`, no skeleton. |
| `empty` | Centered illustration (placeholder), heading, supportive line, optional action button. |
| `error` | Centered error icon, heading "Something went wrong", body with localized error, "Retry" button. |
| `data` | Real content. |

### 1.5 Navigation rules

- `go_router` declarative routes. See §3 for the full map.
- Auth gate redirects unauthenticated users to `/login`.
- Role gate redirects user role to user shell, admin role to admin shell.
- Back button on every non-root page; root pages (bottom-nav destinations) have no back button.
- Deep links from notifications use the `?from=notification` query param so screens know to show "Back to Notifications" instead of system back.

---

## 2. Component library (C-NN)

Reusable widgets owned by Belle (`app/lib/widgets/`). Page specs reference these by ID.

| ID | Component | Purpose | Key props |
|---|---|---|---|
| **C-01** | `AppScaffold` | Standard page chrome (AppBar, body, optional bottom-nav) | `title`, `actions`, `body`, `showBottomNav` |
| **C-02** | `StatusChip` | Color-coded status pill | `status: RequestStatus \| FlightStatus \| DroneStatus` |
| **C-03** | `BatteryBar` | Horizontal battery gauge | `percent: 0..100`, `lowThreshold: int = 15` |
| **C-04** | `DroneMap` | flutter_map wrapper with drone marker + path | `origin`, `destination`, `flightPlan`, `mode: 'single'\|'fleet'` |
| **C-05** | `ItemPickerSheet` | Bottom-sheet to add a catalog item + qty | `items: List<CatalogItem>`, `onAdd: (id, qty) -> void` |
| **C-06** | `RequestCard` | Compact card showing one request | `request`, `onTap`, `showUser: bool` |
| **C-07** | `DroneCard` | Compact card showing one drone | `drone`, `onTap` |
| **C-08** | `NotificationListTile` | Inbox row | `notification`, `onTap` |
| **C-09** | `EmptyState` | Empty-state illustration + copy + CTA | `icon`, `title`, `body`, `actionLabel?`, `onAction?` |
| **C-10** | `ErrorState` | Error illustration + copy + retry | `error`, `onRetry` |
| **C-11** | `WeightBar` | Live weight vs drone-max progress bar | `currentKg`, `maxKg = 6.0` |
| **C-12** | `ConfirmDialog` | Standard destructive-action dialog | `title`, `body`, `confirmLabel`, `dangerous: bool` |
| **C-13** | `MapPinPicker` | Fullscreen map to drop / drag a pin | `initial?: LatLng`, `onPick: (LatLng) -> void` |
| **C-14** | `EtaTicker` | Self-updating ETA / battery readout | `flight`, refreshes every 1 s |
| **C-15** | `WeatherBadge` | Tiny pill showing global weather state | `state`, tap → admin only opens panel |
| **C-16** | `RolePill` | "USER" / "ADMIN" badge for profile/header | `role` |
| **C-17** | `LoadingButton` | Filled button that shows a spinner while awaiting | `onPressed`, `loading` |
| **C-18** | `NumericKeypadField` | National ID 13-digit input | `controller`, `onComplete` |

---

## 3. Navigation map

```
/                              → AuthGate
  ├── /login                   P-U-01
  ├── /register                P-U-02
  │
  ├── /user                    (role=user shell, bottom-nav)
  │     ├── /home              P-U-03  Request (tab 1)
  │     ├── /queue             P-U-04  Queue (tab 2)
  │     ├── /tracking/:flightId P-U-05  Tracking
  │     ├── /confirm/:reqId    P-U-06  Confirm
  │     ├── /history           P-U-07  History (tab 4)
  │     ├── /notifications     P-U-08  Notifications (top-right icon)
  │     └── /profile           P-U-09  Profile + Settings (tab 5)
  │
  └── /admin                   (role=admin shell, top-tabs + AppBar)
        ├── /requests          P-A-01  Requests list (tab 1)
        ├── /requests/:reqId   P-A-02  Request manage
        ├── /drones            P-A-03  Drone list (tab 2)
        ├── /drones/:droneId   P-A-04  Drone detail
        ├── /control           P-A-05  Control live map (tab 3)
        ├── /weather           P-A-06  Weather panel (tab 4 sub)
        ├── /inventory         P-A-07  Supply inventory (tab 4 sub)
        └── /admin/profile     reuses P-U-09 profile layout
```

### Bottom-nav (user)

```
┌──────────────────────────────────────────────┐
│  🏠 Home    📋 Queue    📍 Tracking*    🗂 History    👤 Profile  │
└──────────────────────────────────────────────┘
```

`* Tracking tab` is enabled only when the user has an active in-flight request. Otherwise the icon is dimmed and tapping shows a snackbar: "You don't have a drone in flight right now."

### Top-tabs (admin)

```
┌──────────────────────────────────────────────┐
│ AppBar: DroneAid · Admin           🔔  ⚙     │
│ Tabs:  Requests | Drones | Control | More    │
└──────────────────────────────────────────────┘
```

"More" tab opens a sheet with Weather panel, Supply inventory, Admin profile.

---

## 4. Demo seed dataset

Backed by `functions/src/seed/*.ts`. Run once after `firebase deploy`. Idempotent.

### 4.1 Admins (collection `users` with role=admin)

| ID | nationalId | name | phone | password (demo only) |
|---|---|---|---|---|
| droneaid-admin | 1100000000008 | Drone-Aid Admin | +66 81 000 0001 | `Admin#001` |

### 4.2 Demo users (role=user)

| ID | nationalId | name | deliveryAddress | phone | password |
|---|---|---|---|---|---|
| user-mali | 1100000000101 | Mali Suwan | 13.7563, 100.5018 (Bangkok central) | +66 81 000 0101 | `Demo#101` |
| user-naree | 1100000000102 | Naree Charoen | 13.7460, 100.5300 (slightly east) | +66 81 000 0102 | `Demo#102` |
| user-somchai | 1100000000103 | Somchai T. | 13.7700, 100.5300 (north) | +66 81 000 0103 | `Demo#103` |

### 4.3 Catalog (`catalog`)

| itemId | name | weightKg | stock | icon | active |
|---|---|---|---|---|---|
| food-kit | Food Kit | 2.0 | 30 | `food` | true |
| water-5l | Water 5 L | 5.0 | 20 | `water` | true |
| medical-kit | Medical Kit | 1.0 | 15 | `med` | true |
| baby-formula | Baby Formula | 1.2 | 12 | `baby` | true |
| blanket | Blanket | 0.5 | 25 | `blanket` | true |
| flashlight | Flashlight + batteries | 0.4 | 10 | `light` | true |

### 4.4 Drone fleet (`drones`)

Base location: warehouse at 13.7400, 100.5400 (Bangkok). All start `idle`, battery 100%, payload 6.0 kg.

| droneId | name |
|---|---|
| drn-001 | DRN-001 |
| drn-002 | DRN-002 |
| drn-003 | DRN-003 |
| drn-004 | DRN-004 |
| drn-005 | DRN-005 |
| drn-006 | DRN-006 |
| drn-007 | DRN-007 |
| drn-008 | DRN-008 |

### 4.5 Weather

Single doc `weather/current`:
```
{ state: "clear", updatedBy: "droneaid-admin", updatedAt: <serverTimestamp> }
```

### 4.6 No demo requests at seed time

Empty `requests` collection so demo runs through a fresh submit on stage.

---

## 5. User pages

### P-U-01 — Login

**Route:** `/login`
**Owner:** Belle
**Providers:** `authProvider` (state: anonymous / signing-in / authed / error).

#### Layout

```
┌────────────────────────────────────────┐
│                                        │
│        DroneAid                         │   ← App logo (top-center)
│        Relief delivery, on demand       │   ← bodyMedium, opacity 60%
│                                        │
│   ┌─────────────────────────────────┐  │
│   │ 13-digit national ID            │  │   ← TextField, numeric keypad
│   │ ▌                               │  │
│   └─────────────────────────────────┘  │
│                                        │
│   ┌─────────────────────────────────┐  │
│   │ Password                  👁     │  │   ← TextField, obscure toggle
│   │ ▌                               │  │
│   └─────────────────────────────────┘  │
│                                        │
│   ┌─────────────────────────────────┐  │
│   │            Log in               │  │   ← LoadingButton (C-17)
│   └─────────────────────────────────┘  │
│                                        │
│   New here?  Create an account →       │   ← TextButton → /register
│                                        │
└────────────────────────────────────────┘
```

#### Fields

| Field | Type | Validation |
|---|---|---|
| National ID | `NumericKeypadField` (C-18) | V-01 13-digit Thai checksum; required |
| Password | `TextField`, obscure | V-02 min 8 chars; required |

#### States

- `loading`: button shows spinner, both fields disabled.
- `error`: snackbar with error text from `E-01` … `E-04`.
- `empty` / `data`: same — this page has no data fetch.

#### Actions

| Element | Action | Flow |
|---|---|---|
| `Log in` button | `authProvider.signIn(id, pw)` | **F-02 Login** |
| `Create an account` link | `context.go('/register')` | navigate |

#### Acceptance criteria (Gherkin)

```gherkin
Feature: Login

  Scenario: Successful user login
    Given a registered user with national ID "1100000000101" and password "Demo#101"
    When the user enters those credentials and taps "Log in"
    Then the app shows a loading spinner on the button
    And within 3 seconds the app navigates to "/user/home"
    And the bottom-nav is visible with 5 tabs

  Scenario: Successful admin login
    Given a registered admin with national ID "1100000000001" and password "Admin#001"
    When the admin enters those credentials and taps "Log in"
    Then the app navigates to "/admin/requests"
    And the admin top-tabs are visible

  Scenario: Wrong password
    Given a registered user with national ID "1100000000101"
    When the user enters that ID and password "wrong"
    Then a snackbar appears with text "Wrong national ID or password."
    And the password field is cleared and refocused

  Scenario: Bad national ID checksum
    When the user enters national ID "1234567890123" (invalid checksum)
    Then the ID field shows error "Invalid national ID."
    And the "Log in" button is disabled until the field is fixed

  Scenario: Locked account
    Given a user whose users doc has locked=true
    When the user logs in successfully
    Then the app immediately signs them out
    And a dialog appears: "This account has been locked. Contact your coordinator."
```

---

### P-U-02 — Register

**Route:** `/register`
**Owner:** Belle
**Providers:** `authProvider`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Create an account                   │   ← AppBar with back
├────────────────────────────────────────┤
│                                        │
│   ┌─────────────────────────────────┐  │
│   │ Full name                       │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ 13-digit national ID            │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ Phone (e.g. +66 81 …)           │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ Password                  👁     │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ Confirm password          👁     │  │
│   └─────────────────────────────────┘  │
│                                        │
│   ☐  I agree to the program terms.     │
│                                        │
│   ┌─────────────────────────────────┐  │
│   │         Create account          │  │
│   └─────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

#### Fields

| Field | Type | Validation |
|---|---|---|
| Full name | text | V-03 1–60 chars |
| National ID | numeric 13 | V-01 checksum; uniqueness check on submit |
| Phone | tel | V-04 E.164 format |
| Password | text obscure | V-02 8+ chars, 1 letter + 1 digit |
| Confirm password | text obscure | V-05 must match password |
| Terms checkbox | bool | V-06 required true |

#### Actions

| Element | Action | Flow |
|---|---|---|
| `Create account` | `authProvider.register(...)` | **F-01 Register** |
| Back arrow | pop | navigate |

#### Acceptance criteria

```gherkin
Feature: Register

  Scenario: Successful registration
    Given valid inputs for all fields
    When the user taps "Create account"
    Then a Firebase Auth user is created with email "<id>@drone-aid.local"
    And users/{uid} is provisioned with role=user via onUserCreated trigger
    And the app navigates to "/user/home" and shows a snackbar "Welcome to DroneAid."

  Scenario: National ID already registered
    Given national ID "1100000000101" is already in users collection
    When the user attempts to register with that ID
    Then the form shows error "This national ID is already registered. Log in instead."
    And the "Log in" link is emphasized

  Scenario: Password mismatch
    When the password and confirm fields do not match
    Then the confirm field shows error "Passwords do not match."
    And the submit button is disabled

  Scenario: Terms unchecked
    When all fields are valid but the terms checkbox is off
    Then the submit button remains disabled with a tooltip "Please accept the program terms."
```

---

### P-U-03 — Home / Request

**Route:** `/user/home`
**Owner:** Bew
**Providers:** `catalogProvider` (stream), `cartProvider` (local state), `userProvider` (profile + delivery address).

#### Layout

```
┌────────────────────────────────────────┐
│ DroneAid                  🌤  🔔  👤   │  ← AppBar, weather badge (C-15), notif, profile
├────────────────────────────────────────┤
│ Request supplies                       │  ← headlineSmall
│ Pick what you need, drop a pin.        │  ← bodyMedium 60%
│                                        │
│ ┌── Catalog ─────────────────────────┐ │
│ │ ┌─────┐   Food Kit          2.0 kg │ │  ← Each row: icon · name · weight · "Add"
│ │ │ 🍱  │   30 in stock              │ │     row tap → opens ItemPickerSheet (C-05)
│ │ └─────┘                       [+]  │ │
│ │ ┌─────┐   Water 5 L          5.0 kg│ │
│ │ │ 💧  │   20 in stock              │ │
│ │ └─────┘                       [+]  │ │
│ │ ┌─────┐   Medical Kit        1.0 kg│ │
│ │ │ 💊  │   15 in stock              │ │
│ │ └─────┘                       [+]  │ │
│ │ … (scrollable)                     │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Cart  (3 items, 4.5 kg)                │  ← Updates live
│   • Food Kit ×1                  ✕     │
│   • Water 5 L ×1                 ✕     │
│   • Medical Kit ×1               ✕     │
│                                        │
│ Weight    ████░░░░░░  4.5 / 6.0 kg     │  ← C-11 WeightBar
│                                        │
│ Delivery pin:  13.7563, 100.5018       │
│                                  Edit →│  ← opens C-13 MapPinPicker
│                                        │
│ ┌────────────────────────────────────┐ │
│ │            Submit request           │ │  ← LoadingButton; disabled if cart empty or weight>6
│ └────────────────────────────────────┘ │
│                                        │
└────────────────────────────────────────┘
│   bottom nav                            │
└────────────────────────────────────────┘
```

#### States

- `loading` — catalog stream first frame: skeleton list of 4 grey rows.
- `empty` — catalog has zero `active` items: `EmptyState` (C-09) with text "No supplies available right now. Check back soon."
- `error` — catalog stream errors: `ErrorState` (C-10).
- `data` — as above.

Cart-specific:
- Empty cart: cart section hidden, submit disabled.
- Weight bar turns red (`error` color) if total > maxPayloadKg (6.0).

#### Actions

| Element | Action |
|---|---|
| Catalog row tap | open `ItemPickerSheet` (C-05) with that item; on Add → push `{catalogId, qty}` to cart |
| Cart row ✕ | remove from cart |
| Edit delivery pin | push `MapPinPicker` (C-13); on save → update local cart context only (saved on submit) |
| Submit request | call **F-07 Submit Request** |

#### Acceptance criteria

```gherkin
Feature: Browse catalog and submit a request

  Scenario: Add items and submit
    Given the catalog has Food Kit, Water 5 L, Medical Kit, all active and in stock
    And the user is on /user/home
    When the user taps "Food Kit" and selects qty 1, then "Medical Kit" qty 1
    And the user confirms the delivery pin
    And taps "Submit request"
    Then submitRequest callable is invoked with items=[{food-kit:1},{medical-kit:1}]
    And a snackbar appears: "Request submitted. Watch the Queue tab."
    And the app navigates to /user/queue

  Scenario: Weight exceeds payload
    When the cart total weight exceeds 6.0 kg
    Then the WeightBar turns red
    And the "Submit request" button is disabled with helper text "Total exceeds drone payload."

  Scenario: Out of stock item filtered out
    Given Water 5 L has stock=0
    Then Water 5 L row shows "Out of stock" and the [+] button is disabled

  Scenario: No active items
    Given no catalog item has active=true
    Then the page shows an EmptyState: "No supplies available right now."

  Scenario: Pin not set
    Given the user has no deliveryAddress in profile and has not chosen a pin
    Then the "Submit request" button is disabled with helper text "Please drop a delivery pin."
```

---

### P-U-04 — Queue

**Route:** `/user/queue`
**Owner:** Bew
**Providers:** `myRequestsProvider` (stream of `requests where userId == uid order by createdAt desc`).

#### Layout

```
┌────────────────────────────────────────┐
│ DroneAid                  🌤  🔔  👤   │
├────────────────────────────────────────┤
│ Your queue                             │
│                                        │
│ ┌── Active ─────────────────────────┐  │
│ │ #req-9f8d        ●  In flight     │  │   StatusChip (C-02)
│ │ Medical Kit ×1 · Food Kit ×1      │  │
│ │ ETA in 12 min   Battery 78%       │  │   from current flight (live)
│ │ Submitted 7:32 PM           ▶ Track│  │
│ └───────────────────────────────────┘  │
│                                        │
│ ┌── Pending ────────────────────────┐  │
│ │ #req-7c3a        ⏳ Pending        │  │
│ │ Blanket ×2                        │  │
│ │ Submitted 8:01 PM           Cancel│  │
│ └───────────────────────────────────┘  │
│                                        │
│ See past deliveries → /user/history    │
│                                        │
└────────────────────────────────────────┘
```

#### Sections

- **Active**: status in `{approved, in_flight, delivered}` (delivered means waiting for user confirm).
- **Pending**: status == `pending`.
- **Hidden**: rejected, cancelled, failed, confirmed — those live in History.

#### Actions

| Element | Action |
|---|---|
| `▶ Track` | navigate to `/user/tracking/:flightId` |
| `Confirm` (when status=delivered) | navigate to `/user/confirm/:reqId` |
| `Cancel` (pending only) | open `ConfirmDialog` (C-12); on confirm → call **F-09 Cancel Request** |

#### Acceptance criteria

```gherkin
Feature: User queue

  Scenario: Queue updates live as status changes
    Given the user has one request in status "pending"
    When an admin approves and assigns a drone
    Then within 2 seconds the queue row updates to "In flight" with ETA and battery
    And a "Track" button appears

  Scenario: Cancel pending
    Given a request in status "pending"
    When the user taps Cancel and confirms
    Then the request is removed from the active list and moves to History as "cancelled"

  Scenario: Empty queue
    Given the user has zero requests
    Then the page shows EmptyState: "No requests yet. Tap Home to submit one."

  Scenario: Delivered awaits confirm
    When a flight transitions to delivered
    Then the row shows status "Delivered — confirm receipt" and a "Confirm" button
```

---

### P-U-05 — Tracking

**Route:** `/user/tracking/:flightId`
**Owner:** Poom
**Providers:** `flightStreamProvider(flightId)`, `weatherProvider`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Tracking #req-9f8d                  │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │                                    │ │
│ │       (OpenStreetMap tiles)        │ │   C-04 DroneMap mode=single
│ │                                    │ │
│ │   📍 origin (warehouse)            │ │
│ │   ━ ━ ━ ━ ━ ━ ━ ━ ━ ━ →             │ │
│ │                       🛸 drone     │ │   marker moves every frame
│ │                              📍 you│ │
│ │                                    │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Status   In flight  ●                  │
│ ETA      in 12 min  (7:42 PM)          │
│ Battery  ████████░░  78%               │   C-03 BatteryBar
│ Weather  🌤 Clear                       │   C-15
│ Speed    15 km/h                       │
│ Distance 4.2 km remaining              │
│                                        │
└────────────────────────────────────────┘
```

#### State map (visual)

| flight.status | Banner | Map |
|---|---|---|
| `enroute` | "In flight" green | drone moves origin→dest |
| `delivering` | "Arriving — get ready" amber | drone hovers at dest |
| `completed` | "Delivered — please confirm" blue with CTA | drone at dest |
| `returning` | "Returning to base" grey | drone moves dest→origin |
| `aborted`/`failed` | "Flight aborted: <reason>" red | drone at last known position, then home |

#### Live values

`EtaTicker` (C-14) recomputes ETA + battery from `flight` doc every 1 s. No Firestore writes per second — pure local math.

#### Actions

| Element | Action |
|---|---|
| Back | pop |
| "Confirm receipt" (when completed) | navigate to `/user/confirm/:reqId` |
| Weather badge | open weather panel only if role=admin; else snackbar with explanation |

#### Acceptance criteria

```gherkin
Feature: Live drone tracking

  Scenario: Drone moves on screen
    Given a flight in status "enroute" with takeoffAt 60 seconds ago
    When the user opens /user/tracking/:flightId
    Then the drone marker is between origin and destination
    And the marker position updates at 60 fps without Firestore reads

  Scenario: ETA decreases
    Given a flight whose duration is 18 minutes total and 6 minutes elapsed
    Then ETA reads approximately "in 12 min"

  Scenario: Battery animates
    Given batteryAtTakeoff=95 and drain 80%/hr
    After 7.5 minutes the battery readout should be approximately 85% (one decimal tolerance)

  Scenario: Flight aborts during view
    Given the user is watching a tracking page
    When tickFlights marks flight.status=aborted with failureType="weather"
    Then within 2 seconds the banner turns red with text "Flight aborted: weather"
    And a button "Back to Queue" appears

  Scenario: Tracking when flight is gone
    Given the flight document does not exist or belongs to another user
    Then the page shows an ErrorState "Flight not found" and a Back button
```

---

### P-U-06 — Confirm

**Route:** `/user/confirm/:reqId`
**Owner:** Poom
**Providers:** `requestStreamProvider(reqId)`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Confirm receipt                     │
├────────────────────────────────────────┤
│                                        │
│              📦                         │   ← Large icon, animation on land
│                                        │
│  Did you receive your supplies?        │   headlineSmall
│                                        │
│  Items: Medical Kit ×1, Food Kit ×1    │
│  Delivered at 7:42 PM                  │
│                                        │
│   ┌─────────────────────────────────┐  │
│   │            Yes, confirm          │  │   FilledButton (primary)
│   └─────────────────────────────────┘  │
│                                        │
│   ┌─────────────────────────────────┐  │
│   │   Something's wrong — report     │  │   OutlinedButton
│   └─────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

#### Actions

| Element | Action |
|---|---|
| `Yes, confirm` | call **F-13 Confirm Delivery** |
| `Something's wrong` | open `ConfirmDialog` → call `reportIssue` (out of scope v1 — opens snackbar "Coordinator notified.") |

#### Acceptance criteria

```gherkin
Feature: Confirm receipt

  Scenario: Confirm sets state and triggers return
    Given a request in status "delivered"
    When the user taps "Yes, confirm"
    Then confirmDelivery callable is invoked
    And request.status becomes "confirmed"
    And the linked flight.status becomes "returning"
    And the user is navigated back to /user/queue with snackbar "Thanks — supplies received."

  Scenario: Confirm without delivered status
    Given a request in status "in_flight" (race condition)
    When the user lands here from a stale notification
    Then the buttons are disabled and a banner reads "Drone hasn't arrived yet."
```

---

### P-U-07 — History

**Route:** `/user/history`
**Owner:** Bew
**Providers:** `myHistoryRequestsProvider` (paged stream of `requests where userId == uid and status in [confirmed, failed, cancelled, rejected]`).

#### Layout

```
┌────────────────────────────────────────┐
│ History                                │
├────────────────────────────────────────┤
│ Jun 4                                  │
│   ✓ Confirmed  Food Kit ×1, Water ×1   │
│     7:42 PM · 2 flights (1 aborted)    │
│   ✗ Cancelled  Blanket ×2              │
│     6:10 PM                            │
│                                        │
│ Jun 3                                  │
│   ✓ Confirmed  Medical Kit ×1          │
│     8:15 PM                            │
│                                        │
│   (Load older …)                       │
└────────────────────────────────────────┘
```

Groups by day; each row is a `RequestCard` (C-06) with terminal status. Tap row → simple detail sheet (read-only).

#### Acceptance criteria

```gherkin
Feature: History

  Scenario: Shows terminal requests grouped by day
    Given the user has 5 confirmed requests across 2 days
    Then they are grouped by date heading "Jun 4" / "Jun 3"
    And ordered newest-first within each day

  Scenario: Multi-flight request shows flight count
    Given a confirmed request whose currentFlightId went through one aborted flight then one successful flight
    Then the row shows "2 flights (1 aborted)"
```

---

### P-U-08 — Notifications

**Route:** `/user/notifications`
**Owner:** Poom
**Providers:** `notificationsProvider` (stream of `users/{uid}/notifications order by createdAt desc`).

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Notifications                       │
├────────────────────────────────────────┤
│ Unread (3)                             │
│ ● Drone arriving in 2 min              │
│   Tracking · 7:40 PM                   │
│ ● Drone dispatched, ETA 18 min         │
│   Tracking · 7:22 PM                   │
│ ● Request approved                     │
│   Queue · 7:21 PM                      │
│                                        │
│ Earlier                                │
│   Delivery confirmed                   │
│     Jun 3 8:15 PM                      │
│   Drone aborted: weather               │
│     Jun 2 5:00 PM                      │
└────────────────────────────────────────┘
```

Each row is `NotificationListTile` (C-08). Tap row → mark read + jump to associated screen (using `requestId` / `flightId`).

#### Acceptance criteria

```gherkin
Feature: Notifications inbox

  Scenario: New push arrives while app is open
    Given the app is in the foreground on /user/queue
    When an FCM push arrives for a state change
    Then a new entry appears in /user/notifications subcollection within 2 seconds
    And the AppBar bell shows a red dot

  Scenario: Tap to deep-link
    When the user taps "Drone dispatched"
    Then the row is marked read
    And the app navigates to /user/tracking/:flightId

  Scenario: Empty
    Given the user has zero notifications
    Then the page shows EmptyState: "No notifications yet."
```

---

### P-U-09 — Profile + Settings

**Route:** `/user/profile` (also `/admin/profile`)
**Owner:** Belle
**Providers:** `userProvider`, `themeProvider`.

#### Layout

```
┌────────────────────────────────────────┐
│ Profile                                │
├────────────────────────────────────────┤
│ 👤  Mali Suwan                  USER   │  ← RolePill (C-16)
│    1100000000101                       │
│    +66 81 000 0101                     │
│                                        │
│ ── Profile ──                          │
│ Full name     Mali Suwan        Edit   │
│ Phone         +66 81 000 0101   Edit   │
│ Delivery pin  13.7563, 100.5018 Edit → │  ← opens C-13
│                                        │
│ ── Settings ──                         │
│ Theme         System ▾                 │  ← System / Light / Dark
│ Language      English (only v1)        │  ← disabled select for now
│ Notifications [ON]   per category…    │  ← expands a sublist
│                                        │
│ ── Account ──                          │
│   ┌──────────────────────────────┐    │
│   │           Log out             │    │  OutlinedButton (danger)
│   └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

#### Actions

| Element | Action |
|---|---|
| Edit name / phone | inline editing → `updateProfile` callable |
| Edit delivery pin | push `MapPinPicker` → save back to user doc |
| Theme select | sets `themeProvider`; persisted to user prefs |
| Notifications toggles | sets per-category prefs (in user doc) |
| Log out | confirm dialog → `authProvider.signOut()` + delete FCM token from user doc |

#### Acceptance criteria

```gherkin
Feature: Profile + Settings

  Scenario: Change theme
    Given the user is on /user/profile
    When the user selects Theme=Dark
    Then the app immediately switches to dark mode
    And the choice persists across app restarts

  Scenario: Edit phone
    When the user edits phone to "+66 81 999 9999" and taps save
    Then updateProfile callable is invoked
    And the field shows "Saved" for 1 second

  Scenario: Log out
    When the user taps "Log out" and confirms
    Then the FCM token for this device is removed from users.fcmTokens
    And the app navigates to /login
```

---

## 6. Admin pages

### P-A-01 — Requests list

**Route:** `/admin/requests`
**Owner:** Bew
**Providers:** `allRequestsProvider` (stream of `requests order by createdAt desc`, filter chips client-side).

#### Layout

```
┌────────────────────────────────────────┐
│ DroneAid · Admin       🌤  🔔  ⚙       │
│ Requests | Drones | Control | More     │
├────────────────────────────────────────┤
│ Filters:  ⏳ Pending  ●In flight  ✗Failed  All  │  ← FilterChips, multi
│ Sort:     Newest ▾   Priority ▾                  │
│                                                  │
│ #req-9f8d  ⏳ Pending     URGENT                  │  ← C-06 RequestCard, showUser=true
│   Mali Suwan · Medical Kit ×1, Food Kit ×1       │
│   3.0 kg · Bangkok shelter · 7:32 PM             │
│   ─────────────────────────────                  │
│ #req-7c3a  ● In flight                            │
│   Somchai T. · Blanket ×2                        │
│   1.0 kg · 4.1 km · 7:21 PM                      │
│   ─────────────────────────────                  │
│ #req-5e22  ✗ Failed (weather)                     │
│   Naree Charoen · Water 5 L                      │
│   5.0 kg · 6:00 PM                               │
└────────────────────────────────────────┘
```

#### Actions

| Element | Action |
|---|---|
| Card tap | navigate to `/admin/requests/:reqId` (P-A-02) |
| Filter chip tap | toggle filter |
| Sort menu | change sort order |

#### Acceptance criteria

```gherkin
Feature: Admin requests list

  Scenario: New request appears live
    Given the admin is on /admin/requests
    When a user submits a new request
    Then a new row appears at the top within 2 seconds with status "Pending"
    And the count badge on the Requests tab increments

  Scenario: Filter pending only
    When the admin taps the "Pending" filter chip
    Then only requests with status=pending are shown
    And the chip is highlighted

  Scenario: Empty after filter
    Given filter is "Failed" and no failed requests exist
    Then EmptyState "No failed requests."
```

---

### P-A-02 — Request manage

**Route:** `/admin/requests/:reqId`
**Owner:** Bew
**Providers:** `requestStreamProvider(reqId)`, `userProfileProvider(userId)`, `eligibleDronesProvider(weightKg, destinationLatLng)`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Request #req-9f8d                   │
├────────────────────────────────────────┤
│ Status        ⏳ Pending  URGENT       │
│ Submitted     Jun 4 · 7:32 PM          │
│                                        │
│ ── Requester ──                        │
│ Mali Suwan · ID 1100000000101          │
│ +66 81 000 0101                        │
│ 5 prior deliveries (4 confirmed, 1 fail)│
│                                        │
│ ── Items ──                            │
│ • Medical Kit  ×1   1.0 kg             │
│ • Food Kit     ×1   2.0 kg             │
│ Total weight  3.0 kg                   │
│                                        │
│ ── Delivery ──                         │
│ 📍 13.7563, 100.5018  (Bangkok central)│
│ Distance from base  3.8 km             │
│                                        │
│ ── Actions ──                          │
│   ┌────────────────────────────────┐   │
│   │           Approve              │   │  FilledButton (primary)
│   └────────────────────────────────┘   │
│   ┌────────────────────────────────┐   │
│   │            Reject              │   │  OutlinedButton (error)
│   └────────────────────────────────┘   │
│                                        │
│  (When approved, drone picker reveals) │
│                                        │
│ ── Pick drone ──                       │
│ ○ DRN-001   Battery 92%   3.8 km   ✓   │  radio list
│ ○ DRN-003   Battery 86%   3.8 km   ✓   │
│ ○ DRN-004   Battery 41%   3.8 km   ⚠   │  ← warns: low battery
│                                        │
│   ┌────────────────────────────────┐   │
│   │       Assign DRN-001           │   │  enabled when one selected
│   └────────────────────────────────┘   │
└────────────────────────────────────────┘
```

#### Drone picker logic (`eligibleDronesProvider`)

- Filters: `status=idle`, `maxPayloadKg >= totalWeightKg`, base within `15 km` of destination, `batteryPct >= 30` (configurable, warn at 30–50).
- Sort: by distance ascending, then battery descending.
- If list empty: shows EmptyState with copy "No eligible drone right now. Try again in a few minutes or send to another shift." and disables Assign.

#### Acceptance criteria

```gherkin
Feature: Manage a request

  Scenario: Approve and assign
    Given a pending request with total weight 3.0 kg
    When the admin taps Approve
    Then approveRequest is invoked
    And stock for each item is decremented atomically
    And status becomes "approved"
    And the drone picker section reveals 3 eligible drones

    When the admin selects DRN-001 and taps "Assign DRN-001"
    Then assignDrone({reqId, droneId:"drn-001"}) is invoked
    And a flight document is created with status=enroute
    And drone DRN-001 status becomes "flying"
    And the request status becomes "in_flight"
    And the user receives a push "Drone dispatched"

  Scenario: Reject with reason
    When the admin taps Reject
    Then a dialog asks for a reason from a preset list:
      | reason                |
      | Out of stock          |
      | Weather too dangerous |
      | Out of service area   |
      | Other                 |
    When the admin selects a reason and confirms
    Then rejectRequest({reqId, reason}) is invoked
    And status becomes "rejected" with the chosen reason

  Scenario: Stock insufficient at approve
    Given between viewing and approving, another admin approved a competing request that drained stock
    When the admin taps Approve
    Then approveRequest returns error "OUT_OF_STOCK: <itemName>"
    And a snackbar shows the message and the page reloads stock

  Scenario: No eligible drone
    Given total weight exceeds all available drones' payload (impossible in v1 since max kg = 6)
    Or all drones are flying/maintenance
    Then the picker shows the empty state and Assign is disabled

  Scenario: Reassign after failure
    Given the request is in status "failed" with a previous flight
    Then a banner reads "Previous attempt failed (weather)."
    And the Reassign button opens the drone picker again
    When the admin assigns a new drone
    Then a new flight is created and request status becomes "in_flight"
```

---

### P-A-03 — Drone list

**Route:** `/admin/drones`
**Owner:** Tawan
**Providers:** `allDronesProvider` (stream).

#### Layout

```
┌────────────────────────────────────────┐
│ DroneAid · Admin                       │
│ Requests | Drones | Control | More     │
├────────────────────────────────────────┤
│ Filters: All  Idle  Flying  Maint.  Off│
│                                        │
│ DRN-001  Idle      Battery 100%        │  ← C-07 DroneCard
│   Base · max 6.0 kg                    │
│ DRN-002  Flying    Battery 68%         │
│   Job: #req-9f8d  ETA 7 min            │
│ DRN-003  Idle      Battery 100%        │
│ DRN-004  Maint.    Battery —           │
│   Last fault: mechanical 2h ago        │
│ DRN-005  Flying    Battery 41%         │
│ …                                      │
└────────────────────────────────────────┘
```

#### Acceptance criteria

```gherkin
Feature: Drone list

  Scenario: Filter to flying only
    When admin taps "Flying" chip
    Then only drones in status=flying are shown

  Scenario: Card tap
    When admin taps DRN-002
    Then app navigates to /admin/drones/drn-002 (P-A-04)
```

---

### P-A-04 — Drone detail

**Route:** `/admin/drones/:droneId`
**Owner:** Tawan
**Providers:** `droneStreamProvider(droneId)`, `flightHistoryProvider(droneId, limit=10)`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  DRN-002                             │
├────────────────────────────────────────┤
│ Status   Flying  ●                     │
│ Battery  ████████░░░░  68%             │
│ Payload  3.0 kg / 6.0 kg               │
│ Base     13.7400, 100.5400             │
│ Last seen  2 s ago                     │
│                                        │
│ ── Current flight ──                   │
│ #flt-77ab → /admin/control             │
│ Origin → 13.7400, 100.5400             │
│ Dest   → 13.7563, 100.5018             │
│ ETA    7 min                           │
│                                        │
│ ── Future queue ──                     │
│ (none — assignments are immediate v1)  │
│                                        │
│ ── Recent flights (last 10) ──         │
│ Jun 4 7:30 PM  delivered  req-9f8d     │
│ Jun 4 6:50 PM  aborted (weather)       │
│ Jun 4 5:10 PM  delivered  req-5e22     │
│                                        │
│ ── Actions ──                          │
│   [ Take offline ]    [ Maintenance ]  │
│                                        │
└────────────────────────────────────────┘
```

#### Actions

| Element | Action |
|---|---|
| Take offline | confirm → `toggleDroneOffline(droneId, true)` (uses toggleDroneMaintenance callable internally with status=offline) — disabled if drone is flying |
| Maintenance | confirm → `toggleDroneMaintenance(droneId, true)` — disabled if flying |

#### Acceptance criteria

```gherkin
Feature: Drone detail

  Scenario: Toggle maintenance on idle drone
    Given a drone in status "idle"
    When admin taps "Maintenance" and confirms
    Then drone.status becomes "maintenance"
    And the drone disappears from the eligibleDrones picker

  Scenario: Cannot toggle a flying drone
    Given a drone in status "flying"
    Then the "Take offline" and "Maintenance" buttons are disabled with tooltip "Wait until flight ends."
```

---

### P-A-05 — Control (live map)

**Route:** `/admin/control`
**Owner:** Poom
**Providers:** `activeFlightsProvider` (stream of `flights where status in [enroute, delivering, returning]`).

#### Layout

```
┌────────────────────────────────────────┐
│ DroneAid · Admin                       │
│ Requests | Drones | Control | More     │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │  (Fullscreen OpenStreetMap)        │ │  C-04 DroneMap mode=fleet
│ │                                    │ │
│ │  📍 base                           │ │
│ │       🛸 DRN-001                    │ │
│ │              🛸 DRN-003             │ │
│ │   🛸 DRN-005 (red flash — battery low)│
│ │                       🛸 DRN-002    │ │
│ │                                    │ │
│ └────────────────────────────────────┘ │
│ Active flights: 4   Weather: 🌤 Clear  │
│ Tap a drone for flight details         │
└────────────────────────────────────────┘
```

Tap a drone marker → bottom sheet with quick info + buttons (Open drone detail, Open request, Reassign if failed).

#### Acceptance criteria

```gherkin
Feature: Live control map

  Scenario: Multiple drones move
    Given 4 active flights
    Then 4 drone markers appear on the map
    And each updates position at 60 fps

  Scenario: Failure flashes
    When a flight transitions to aborted
    Then the marker flashes red for 3 seconds
    And tapping it opens a sheet with "Reassign" CTA

  Scenario: No active flights
    Then the map shows only the base pin and a banner "No drones in flight."
```

---

### P-A-06 — Weather panel

**Route:** `/admin/weather` (under "More" tab)
**Owner:** Tawan
**Providers:** `weatherProvider`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Weather                             │
├────────────────────────────────────────┤
│ Current state:   🌤 Clear              │
│ Updated 7:12 PM by Aok                 │
│                                        │
│ Set state:                             │
│   ◉ Clear   (mod 1.0  · drain 80%/hr)  │
│   ○ Wind    (mod 0.7  · drain 100%/hr) │
│   ○ Storm   (mod 0.0  · drain 120%/hr) │
│                                        │
│   ┌────────────────────────────────┐   │
│   │              Save              │   │
│   └────────────────────────────────┘   │
│                                        │
│ ⚠ Changing to "Storm" can abort in-    │
│   flight drones (20% per tick).        │
└────────────────────────────────────────┘
```

#### Acceptance criteria

```gherkin
Feature: Set weather

  Scenario: Change state
    When admin selects "Storm" and taps Save
    Then setWeather({state:"storm"}) is invoked
    And weather/current.state becomes "storm"
    And within 60 s tickFlights starts applying storm rules

  Scenario: Warning shown
    When admin selects "Storm" before Save
    Then a yellow warning banner appears about in-flight aborts
```

---

### P-A-07 — Supply inventory

**Route:** `/admin/inventory` (under "More" tab)
**Owner:** Bew
**Providers:** `catalogProvider`.

#### Layout

```
┌────────────────────────────────────────┐
│ ←  Inventory                  + Add     │
├────────────────────────────────────────┤
│ Food Kit         2.0 kg   30 in stock  │
│   [ Restock + ]   [ Deactivate ]        │
│ Water 5 L        5.0 kg   20 in stock  │
│ Medical Kit      1.0 kg   15 in stock  │
│   [ Restock + ]   [ Deactivate ]        │
│ Blanket          0.5 kg   25 in stock  │
│ Flashlight       0.4 kg   10 in stock  │
│ …                                      │
└────────────────────────────────────────┘
```

Restock opens dialog with quantity stepper (1, 5, 10, custom). Save calls `restockItem`.
Add opens dialog for new item: name, weightKg, initial stock, icon. Calls `createCatalogItem`.

#### Acceptance criteria

```gherkin
Feature: Inventory

  Scenario: Restock
    When admin taps Restock+ for "Food Kit" with quantity 10 and saves
    Then restockItem({itemId:"food-kit", qty:10}) is invoked
    And the visible stock count increases by 10 within 2 seconds

  Scenario: Deactivate
    When admin deactivates "Blanket"
    Then catalog.blanket.active becomes false
    And the item disappears from the user catalog within 2 seconds
```

---

## 7. Flows (F-NN)

### F-01 Register

**Trigger:** user taps "Create account" on P-U-02.
**Preconditions:** all form fields valid (V-01..V-06).
**Steps:**
1. Client calls `FirebaseAuth.createUserWithEmailAndPassword("<id>@drone-aid.local", password)`.
2. `onUserCreated` trigger fires server-side, provisions `users/{uid}`.
3. Client awaits `users/{uid}` doc exists, then reads role.
4. Router redirects to `/user/home` (role=user) or `/admin/requests` (role=admin).
**Postconditions:** authenticated session, `users/{uid}` exists with role + delivered profile fields.
**Errors:** E-05 ID already registered, E-06 weak password, E-07 network failure.

```gherkin
Feature: Register flow
  Scenario: Happy path
    Given a fresh national ID and valid form
    When the user submits
    Then within 5 s they land on /user/home
  Scenario: ID already exists
    When the user submits an ID that is already taken
    Then they see error E-05 inline
```

### F-02 Login

**Trigger:** user taps "Log in" on P-U-01.
**Steps:**
1. `signInWithEmailAndPassword`.
2. Read `users/{uid}.role` to pick shell.
3. Router pushes shell.
**Errors:** E-01 wrong creds, E-02 invalid checksum, E-03 locked, E-04 network.

### F-03 Logout

**Trigger:** user taps "Log out" on P-U-09.
**Steps:**
1. Confirm dialog.
2. Delete this device's FCM token from `users/{uid}.fcmTokens`.
3. `FirebaseAuth.signOut()`.
4. Router redirects to `/login`.

### F-04 Edit profile field

**Trigger:** user edits a field on P-U-09.
**Steps:**
1. Inline edit input replaces label.
2. On Enter or blur → `updateProfile({field, value})`.
3. Success shows "Saved" for 1 s.
**Errors:** E-08 validation, E-04 network.

### F-05 Set delivery pin

**Trigger:** user taps Edit on the delivery pin row.
**Steps:**
1. Push `MapPinPicker` (C-13) with current pin as initial.
2. User drags marker; tap "Use this location".
3. Reverse-geocode (optional) → label.
4. `updateProfile({deliveryAddress})`.

### F-06 Add to cart

**Trigger:** user taps a catalog row on P-U-03.
**Steps:**
1. `ItemPickerSheet` (C-05) opens with item details.
2. User selects quantity (default 1).
3. Tap Add → cart provider gains the row.
4. WeightBar recomputes.
**Errors:** E-09 item out of stock (button disabled).

### F-07 Submit request

**Trigger:** user taps Submit on P-U-03.
**Preconditions:** cart non-empty, weight ≤ 6.0 kg, delivery pin set.
**Steps:**
1. Client builds payload `{items, deliveryAddress, priority, notes}`.
2. Calls `submitRequest` callable.
3. Server validates: each item exists + is active + stock >= qty; total weight ≤ maxPayloadKg; user role=user.
4. Server creates `requests/{reqId}` with status=pending, decremented nothing yet.
5. Server FCMs all admins with new-request push.
6. Client clears cart, navigates to /user/queue with snackbar.
**Errors:** E-10 weight exceeded, E-11 stock changed, E-04 network.

### F-08 Watch queue

**Trigger:** user navigates to /user/queue.
**Steps:** stream from Firestore, render sections per status group. Live updates on any field change.

### F-09 Cancel pending request

**Trigger:** user taps Cancel on a pending row.
**Steps:**
1. ConfirmDialog.
2. `cancelRequest({reqId})`.
3. Server checks status == pending, sets status=cancelled.
**Errors:** E-12 already approved (server rejects with code, snackbar shown).

### F-10 View tracking

**Trigger:** user taps Track on queue or notification deep-link.
**Steps:** subscribe to `flights/{flightId}`, compute live position + battery via C-04 + C-14.
**Sub-flows:** F-10a state transition shown live; F-10b abort banner.

### F-11 Tap notification

**Trigger:** user taps a row in /user/notifications, OR taps an FCM push.
**Steps:**
1. Notification doc updated with `readAt`.
2. Router navigates per `type`:
  - `request_approved` → /user/queue
  - `flight_dispatched` → /user/tracking/:flightId
  - `flight_arriving` → /user/tracking/:flightId
  - `flight_completed` → /user/confirm/:reqId
  - `flight_aborted` → /user/queue
  - `delivery_confirmed` → /user/history

### F-12 Receive FCM push

**Trigger:** server-side FCM send (from `onFlightWritten` trigger).
**Steps:** OS shows notification → user taps → app opens to mapped route (F-11). If app foreground, also creates an in-app banner using local notifications.

### F-13 Confirm delivery

**Trigger:** user taps "Yes, confirm" on P-U-06.
**Steps:**
1. `confirmDelivery({reqId})`.
2. Server sets request.status=confirmed.
3. Server sets flight.status=returning.
4. Server sets drone.status=flying (returning leg).
5. Server FCMs user with "Thanks — received".
6. Client snackbar + navigate back to /user/queue.
**Errors:** E-13 not in delivered state.

### F-14 Admin sees new request push

**Trigger:** push arrives at admin device.
**Steps:** notification rendered → tap → app routes to /admin/requests/:reqId (P-A-02).

### F-15 Admin opens request

**Trigger:** admin taps a row on P-A-01.
**Steps:** subscribe to request doc + user profile + (when approved) eligibleDronesProvider.

### F-16 Admin approves

**Trigger:** admin taps Approve on P-A-02 (status=pending).
**Steps:**
1. `approveRequest({reqId})`.
2. Server transaction: for each item, `stock -= qty`; set request.status=approved.
3. Return list of eligible drones based on weight + range.
4. Client reveals drone picker.
**Errors:** E-11 stock changed.

### F-17 Admin rejects

**Trigger:** admin taps Reject on P-A-02.
**Steps:**
1. Reason dialog.
2. `rejectRequest({reqId, reason})`.
3. Server sets request.status=rejected; FCMs user.
4. Client returns to list.

### F-18 Admin assigns drone

**Trigger:** admin selects drone + taps Assign on P-A-02 (status=approved).
**Steps:**
1. `assignDrone({reqId, droneId})`.
2. Server transaction: create flight document with status=enroute, takeoffAt=now, etaAt=now+duration; update drone.status=flying, drone.currentFlightId=flightId; update request.status=in_flight, request.currentFlightId=flightId.
3. FCM to user: "Drone dispatched".
4. Client returns to /admin/requests with snackbar.
**Errors:** E-14 drone no longer eligible (status changed before assign).

### F-19 Scheduled tick (system flow)

**Trigger:** Cloud Scheduler every 60 s → `tickFlights`.
**Steps:** see design spec §8 — read weather, query active flights, for each: compute progress + battery, roll dice, write transitions, FCM as appropriate.

### F-20 Flight aborts (system flow)

**Trigger:** dice roll inside F-19.
**Steps:**
1. Flight failureType set, status → aborted (mechanical) or returning (weather/battery).
2. Request status → failed.
3. Drone status → idle (if battery>0) or maintenance.
4. FCM to user + admins.

### F-21 Admin reassigns after failure

**Trigger:** admin opens a request with status=failed (P-A-02).
**Steps:** banner shows previous failure; tap Reassign → drone picker reopens; admin picks → assignDrone again creates a 2nd flight on same request.

### F-22 Admin sets weather

**Trigger:** admin saves on P-A-06.
**Steps:** `setWeather({state})`. Server writes `weather/current`. Next tick uses new state.

### F-23 Admin restocks item

**Trigger:** admin taps Restock+ on P-A-07.
**Steps:** Quantity dialog → `restockItem({itemId, qty})` → catalog stock += qty.

### F-24 Admin creates catalog item

**Trigger:** admin taps "+ Add" on P-A-07.
**Steps:** Dialog (name, weight, initial stock, icon) → `createCatalogItem(payload)` → new doc in catalog.

### F-25 Admin toggles drone maintenance / offline

**Trigger:** admin taps Maintenance or Take offline on P-A-04.
**Steps:** `toggleDroneMaintenance({droneId, mode})`. Disallowed if drone.status=flying.

### F-26 Admin browses control map

**Trigger:** admin opens /admin/control.
**Steps:** subscribe to activeFlightsProvider; render markers; tap → bottom sheet → drill down.

### F-27 FCM device registration

**Trigger:** app start, post-login.
**Steps:** request notification permission → on grant, get FCM token → arrayUnion into `users/{uid}.fcmTokens`. On logout, arrayRemove.

### F-28 Theme switch

**Trigger:** user picks Theme in P-U-09.
**Steps:** themeProvider updates → MaterialApp rebuild → preference persisted (in `users/{uid}.prefs.theme`).

### F-29 Deep-link from notification (cold start)

**Trigger:** user taps FCM push while app is killed.
**Steps:** OS launches app with `data.deepLink`. AuthGate checks login → if authed, navigate to deepLink; else stash deepLink, route to /login, replay after login.

### F-30 Account locked mid-session

**Trigger:** admin locks user while user is using app.
**Steps:** users/{uid} listener sees locked=true → sign out + show dialog (E-03).

---

## 8. Errors (E-NN)

| ID | Trigger | UI treatment | Copy |
|---|---|---|---|
| **E-01** | Login wrong creds | Snackbar | "Wrong national ID or password." |
| **E-02** | ID checksum invalid | Inline field error | "Invalid national ID." |
| **E-03** | Account locked | Modal dialog | "This account has been locked. Contact your coordinator." |
| **E-04** | Network failure | Snackbar with Retry | "Can't reach DroneAid. Check your connection." |
| **E-05** | ID already registered | Inline field error | "This national ID is already registered. Log in instead." |
| **E-06** | Weak password | Inline field error | "Password must be at least 8 characters and include a letter and a number." |
| **E-07** | Auth provider returns unknown error | Snackbar | "Something went wrong. Please try again." |
| **E-08** | Invalid profile field | Inline field error | "Please enter a valid value." |
| **E-09** | Catalog item out of stock at add | Disabled [+] + helper | "Out of stock." |
| **E-10** | Cart weight exceeds payload | Helper text + disabled Submit | "Total exceeds drone payload (6.0 kg)." |
| **E-11** | Stock changed between submit and approve | Snackbar + reload | "Stock changed: <item> is now <count> in stock." |
| **E-12** | Cancel after approval | Snackbar | "Too late — your request has been approved." |
| **E-13** | Confirm when not yet delivered | Banner on Confirm page | "Drone hasn't arrived yet." |
| **E-14** | Drone no longer eligible at assign | Snackbar + refresh picker | "DRN-XXX is no longer available. Pick another." |
| **E-15** | FCM permission denied | Banner on first run | "Push notifications are off. Turn on in Settings to get drone updates." |
| **E-16** | Map tiles fail | Map area shows fallback grid + retry | "Map failed to load. Tap to retry." |
| **E-17** | Cloud Function timeout | Snackbar | "DroneAid is slow right now. Please try again." |
| **E-18** | tickFlights detects stuck flight (>2× ETA) | Auto-marks as failed mechanical | (server-side; user notified per F-20) |
| **E-19** | User tries Confirm twice | Server idempotent | (no-op, snackbar "Already confirmed.") |
| **E-20** | Admin assign on non-idle drone | Server rejects | "DRN-XXX changed state. Refresh and pick another." |

---

## 9. Validation rules (V-NN)

| ID | Field | Rule |
|---|---|---|
| **V-01** | National ID | 13 digits, all numeric; Thai ID checksum: `sum(d[i] * (13-i) for i in 0..11) % 11 -> (11 - r) % 10 == d[12]` |
| **V-02** | Password | length ≥ 8, contains at least one letter and one digit |
| **V-03** | Full name | length 1–60, non-blank |
| **V-04** | Phone | E.164 format, length 10–15 incl. `+` |
| **V-05** | Confirm password | equals password |
| **V-06** | Terms checkbox | true |
| **V-07** | Cart total weight | > 0 and ≤ maxPayloadKg (6.0) |
| **V-08** | Delivery pin | lat between -90..90, lng between -180..180, not (0,0) |
| **V-09** | Request items | length ≥ 1, every catalogId exists & active, every qty ≥ 1 |
| **V-10** | Reject reason | non-empty, length ≤ 200 |
| **V-11** | Restock qty | integer ≥ 1, ≤ 999 |
| **V-12** | Catalog item name | unique among active, length 1–40 |
| **V-13** | Drone payload at assign | request.totalWeightKg ≤ drone.maxPayloadKg |
| **V-14** | Drone range at assign | haversine(drone.baseLocation, destination) ≤ 15 km |
| **V-15** | Drone battery at assign | drone.batteryPct ≥ 30 (warn 30–50, hard floor 30) |
| **V-16** | Notification deep link | safe internal route only (no external URLs) |

---

## 10. Internationalization keys (English defaults)

All UI strings live in `app/lib/l10n/app_en.arb`. Format: `screen.section.key`. Examples:

```
"login.title": "DroneAid",
"login.subtitle": "Relief delivery, on demand",
"login.field.id": "13-digit national ID",
"login.field.password": "Password",
"login.action.submit": "Log in",
"login.action.register": "Create an account",
"login.error.wrongCreds": "Wrong national ID or password.",
"login.error.locked": "This account has been locked. Contact your coordinator.",

"home.title": "Request supplies",
"home.subtitle": "Pick what you need, drop a pin.",
"home.cart.weightBar": "{current} / {max} kg",
"home.action.submit": "Submit request",

"queue.section.active": "Active",
"queue.section.pending": "Pending",
"queue.action.track": "Track",
"queue.action.cancel": "Cancel",

"tracking.status.enroute": "In flight",
"tracking.status.delivering": "Arriving — get ready",
"tracking.status.completed": "Delivered — please confirm",
"tracking.status.returning": "Returning to base",
"tracking.status.aborted": "Flight aborted: {reason}",
"tracking.battery": "Battery",
"tracking.eta": "ETA",
"tracking.distanceRemaining": "{km} km remaining",

"confirm.title": "Confirm receipt",
"confirm.body": "Did you receive your supplies?",
"confirm.action.yes": "Yes, confirm",
"confirm.action.report": "Something's wrong — report",

"admin.requests.title": "Requests",
"admin.requests.empty": "No requests yet.",
"admin.requests.filter.pending": "Pending",
"admin.requests.filter.inFlight": "In flight",
"admin.requests.filter.failed": "Failed",

"admin.manage.action.approve": "Approve",
"admin.manage.action.reject": "Reject",
"admin.manage.action.assign": "Assign {drone}",
"admin.manage.dronePicker.lowBattery": "Low battery",

"admin.weather.title": "Weather",
"admin.weather.state.clear": "Clear",
"admin.weather.state.wind": "Wind",
"admin.weather.state.storm": "Storm",
"admin.weather.warning.storm": "Changing to Storm can abort in-flight drones.",

"admin.inventory.action.restock": "Restock",
"admin.inventory.action.deactivate": "Deactivate",
"admin.inventory.action.add": "Add"
```

(Full set lives in code; the above shows naming convention + a representative sample.)

---

## 11. Accessibility checklist

- Every interactive element has a `Semantics(label: ...)`.
- Minimum tap target 48×48 px.
- Color contrast ≥ 4.5:1 for body, 3:1 for large text (validated by M3 ColorScheme).
- All status indicators use icon + color + text — never color alone.
- `TextField` labels visible (not just placeholder).
- Map markers have semantic labels: "Drone DRN-002, battery 68%, arriving in 7 minutes".
- Reduced-motion preference disables the marker tween animation and falls back to teleport-on-tick.

---

## 12. Performance budgets

| Metric | Target |
|---|---|
| Cold start to /login | ≤ 2.5 s on a mid-range Android |
| Login → /user/home | ≤ 1.5 s |
| /user/home first paint (with catalog cached) | ≤ 300 ms |
| Tracking marker animation | 60 fps |
| Submit request → server ack | ≤ 1.5 s on Wi-Fi |
| tickFlights per-tick execution | ≤ 2 s for ≤ 30 active flights |

If any budget is breached on the demo device, file an issue tagged `perf` before merge.

---

## 13. Open questions

- Should we add a 24-hour auto-confirm rule if user never taps Confirm? (Default: no, leave to admin.)
- Should reassign require admin to add a note explaining choice? (Default: no, keep frictionless.)
- Should we record an audit log of approve/reject/assign? (Out of v1, deferred per spec §1 non-goals.)
- Should the Confirm page require photo proof? (Out of v1, possible future.)

---

## 14. Implementation tips for Claude Code

When implementing a page, in this order:
1. Read this doc's §1, §2, §3 sections first (conventions, components, navigation).
2. Read the target page section (P-U-NN or P-A-NN) end-to-end.
3. Read every flow (F-NN) referenced by the page.
4. Implement components from §2 first if the page consumes any not yet built.
5. Implement the page from layout outward: scaffold → states → actions.
6. Write widget tests for each Gherkin scenario before declaring done.

Refuse to skip §1–§3 even if a page section looks self-contained. The conventions section defines the loading/empty/error pattern that every page must follow; pages omit redundant restatement of it.

---

*End of document.*
