# Tournament Sharing & Private Tournaments — Design Spec

**Date:** 2026-04-18  
**Status:** Approved

---

## Overview

Hosts can create tournaments as public or private. Private tournaments require an invite link (or join code) to enroll. Any user can share a tournament via the native share sheet. Recipients tap the link and land directly on the tournament detail screen; private tournaments auto-validate the embedded code and open the enroll sheet.

---

## Data Model

### `Tournament` — new fields

| Field | Type | Default | Description |
|---|---|---|---|
| `isPrivate` | `bool` | `false` | Whether the tournament is invite-only |
| `joinCode` | `String?` | `null` | 6-char alphanumeric code, generated at creation for private tournaments |

**Code format:** uppercase alphanumeric, no ambiguous chars (e.g. excludes `0`, `O`, `I`, `1`). Example: `"T4X9KR"`.

**Updates required:**
- `Tournament.toMap()` — include `isPrivate` and `joinCode`
- `Tournament.fromMap()` — parse `isPrivate` (default `false`) and `joinCode` (nullable)
- `Tournament.copyWith()` — add both fields

---

## Tournament Creation (`league_entry_screen.dart`)

- Add a **Public / Private toggle** (segmented button or switch) in the creation form, below the format picker.
- When **Private** is selected, show a subtle note: *"A join code will be generated — only you can see it."*
- No code shown at creation time; it is displayed in the host dashboard after creation.
- Add `isPrivate` parameter to `TournamentService.createTournament()`.
- When `isPrivate = true`, generate a random 6-char join code using Dart's `Random.secure()` and store it as `joinCode` on the Firestore doc alongside `isPrivate: true`.
- Code generation helper: pick from charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (excludes ambiguous chars).
- `updateTournament()` does **not** regenerate the join code — it is permanent once created.

---

## Tournament List (`tournaments_list_screen.dart`)

- Both public and private tournaments appear in the browse list.
- Private tournament cards show a **lock icon + "Private" badge** so users know they need an invite.
- No change to how tournaments are fetched — all tournaments are returned from Firestore.

---

## Tournament Detail & Host Dashboard

### Share button
- A share icon button (e.g. `Icons.share`) is added to the tournament detail screen's app bar / action area — visible to **all users** (not just the host).
- Tapping it calls `Share.share()` from `share_plus` with:
  - **Public:** `"Check out [Name] on MySportsBuddies!\nmsb://tournament/{id}"`
  - **Private:** `"You're invited to join [Name] on MySportsBuddies!\nTap to join: msb://tournament/{id}?code={code}\n\nOr enter code {code} in the app."`

### Host-only join code panel (private tournaments only)
- In the host dashboard, a card shows the raw join code with a **copy to clipboard** button.
- Only visible when `tournament.isPrivate == true` and `currentUserId == tournament.createdBy`.

---

## Deep Link Handling

### URI scheme
```
msb://tournament/{tournamentId}
msb://tournament/{tournamentId}?code={joinCode}
```

### Setup
- Add `app_links` package to `pubspec.yaml`.
- Configure intent filter in `AndroidManifest.xml` for scheme `msb`, host `tournament`.
- Configure URL scheme in `ios/Runner/Info.plist`.

### Runtime handling (`main.dart`)
- Initialize `AppLinks()` and listen to `uriLinkStream` in `main.dart` after Firebase init.
- On receiving a URI:
  1. Extract `tournamentId` from path segments.
  2. Extract `code` from query params (may be null).
  3. Navigate to tournament detail screen, passing both `tournamentId` and optional `code`.
- Also handle the initial link (app opened cold via the link) using `AppLinks().getInitialLink()`.

### Tournament detail — private access logic
- If tournament `isPrivate == true`:
  - If user arrived with correct `code` in URI → show tournament detail normally; open enroll sheet directly.
  - If user arrived with no code or wrong code (browsed from list) → show a **locked state**: lock icon + *"This is a private tournament. Ask the host for an invite link."* Enroll button is hidden.
  - Exception: the host (`createdBy`) always sees the full detail regardless.

---

## Packages to Add

| Package | Version | Purpose |
|---|---|---|
| `share_plus` | `^10.0.0` | Native share sheet |
| `app_links` | `^6.0.0` | Deep link URI handling |

---

## Error Handling

- If deep link `tournamentId` doesn't exist in Firestore → show snackbar "Tournament not found" and navigate to tournament list.
- If `code` is present but doesn't match → show locked state (do not reveal that code was wrong vs. missing, to prevent guessing).
- Share button always works even if `joinCode` is null on a private tournament (fallback: share without code, show "Code unavailable").

---

## Out of Scope

- Revoking / regenerating the join code after creation.
- Per-match join links within a tournament.
- Web fallback when the app is not installed (no Firebase Dynamic Links).
- Firestore security rules changes (join code is stored on the tournament doc; access control is UI-level).
