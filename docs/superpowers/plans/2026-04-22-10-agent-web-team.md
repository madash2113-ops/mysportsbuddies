# 10-Agent Web Team Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a 10-agent senior engineering team to fix bugs, polish UX, and implement missing features across all 8 MySportsBuddies web screens.

**Architecture:** Tech Lead (Claude) coordinates two waves. Wave 1 launches 9 agents in parallel, each owning non-overlapping files. Wave 2 launches Agent 10 (Shell & Navigation) after Agent 1 hands off `web_shell.dart`. Zero file conflicts possible.

**Tech Stack:** Flutter 3.x, Dart, Firebase Firestore, Provider, Google Fonts Inter, cloud_firestore, firebase_storage

---

## Shared Context Block
> Copy this into every agent prompt as Layer 1.

```
Project: MySportsBuddies — Flutter web app
Theme: dark bg=#080808, card=#111111, border=#1C1C1C
Accent red: Color(0xFFDE313B) — STATIC only. Replace any gradient that uses red button colors with this flat color.
Font: Google Fonts Inter throughout (GoogleFonts.inter(...))
Architecture: Provider + Singleton ChangeNotifiers + Firebase backend
Design system: lib/design/ — always use AppColors, AppTheme, AppTypography, AppSpacing, AppTextStyles. Never raw values.
Services: lib/services/ — all singletons via factory constructor pattern:
  class XService extends ChangeNotifier {
    XService._();
    static final XService _instance = XService._();
    factory XService() => _instance;
  }
Storage bucket: gs://mysportsbuddies-4d077.firebasestorage.app (never appspot.com)
Deprecated: withOpacity() → use withValues(alpha: ...) instead
Safe sort: never sort unmodifiable list — use [...list]..sort(...) spread copy
Dropdowns: use OverlayPortal, not Overlay
Modal sheets: use ListenableBuilder(listenable: XService(), ...) not Consumer<XService>
After all changes: run `flutter analyze lib/screens/web/` — must return zero issues
Baseline: flutter analyze currently returns zero issues — do not introduce new ones
```

## Known Issues Block
> Copy this into every agent prompt as Layer 2.

```
Known issues to fix (in addition to anything you discover yourself):
1. Search (owned by Agent 1 — do not touch web_shell.dart search bar)
2. Gradient red buttons: web_landing_page.dart lines 435-439 and 662-666 use
   LinearGradient([_red, _redDeep]) on CTA buttons — replace with flat Color(0xFFDE313B).
   web_home_dashboard.dart line 497 uses `gradColors` on sport mode buttons — check and
   flatten if it's a red gradient. Other gradients (transparent overlays, background glows)
   are intentional — leave them.
3. Home upcoming/schedule toggle (owned by Agent 2 — do not touch web_home_dashboard.dart
   for this fix).
```

---

## Pre-Flight Check

- [x] `flutter analyze lib/screens/web/` → **zero issues** (verified 2026-04-22)
- [x] Baseline recorded — agents must not introduce new issues

---

## WAVE 1 — Launch all 9 agents in parallel

### Task 1: Agent 1 — Search Engineer

**Files:**
- Modify: `lib/screens/web/web_shell.dart`
- Create: `lib/services/search_service.dart`

- [ ] **Step 1: Launch Agent 1 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Search Engineer. You own exactly two files:
  - lib/screens/web/web_shell.dart
  - lib/services/search_service.dart (CREATE THIS FILE)

YOUR TASKS:

1. CREATE lib/services/search_service.dart as a singleton ChangeNotifier:

```dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchResult {
  final String type;      // 'user' | 'tournament' | 'game' | 'venue'
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  const SearchResult({required this.type, required this.id,
    required this.title, required this.subtitle, this.imageUrl});
}

class SearchService extends ChangeNotifier {
  SearchService._();
  static final SearchService _instance = SearchService._();
  factory SearchService() => _instance;

  List<SearchResult> results = [];
  bool loading = false;

  Future<void> search(String query) async {
    if (query.trim().length < 2) { results = []; notifyListeners(); return; }
    loading = true; notifyListeners();
    final q = query.trim();
    final end = q.substring(0, q.length - 1) +
        String.fromCharCode(q.codeUnitAt(q.length - 1) + 1);
    final db = FirebaseFirestore.instance;
    final futures = await Future.wait([
      db.collection('users')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: end).limit(5).get(),
      db.collection('tournaments')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: end).limit(5).get(),
      db.collection('games')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: end).limit(5).get(),
      db.collection('venues')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: end).limit(5).get(),
    ]);
    final types = ['user', 'tournament', 'game', 'venue'];
    results = [];
    for (int i = 0; i < futures.length; i++) {
      for (final doc in futures[i].docs) {
        final d = doc.data() as Map<String, dynamic>;
        results.add(SearchResult(
          type: types[i],
          id: doc.id,
          title: d['name'] ?? '',
          subtitle: _subtitle(types[i], d),
          imageUrl: d['imageUrl'] ?? d['photoUrl'] ?? d['photoUrls']?[0],
        ));
      }
    }
    loading = false; notifyListeners();
  }

  void clear() { results = []; notifyListeners(); }

  String _subtitle(String type, Map<String, dynamic> d) {
    switch (type) {
      case 'user': return d['sport'] ?? d['location'] ?? 'Player';
      case 'tournament': return d['sport'] ?? 'Tournament';
      case 'game': return d['sport'] ?? 'Game';
      case 'venue': return d['location'] ?? 'Venue';
      default: return '';
    }
  }
}
```

2. MODIFY lib/screens/web/web_shell.dart:
   - Add SearchService import
   - Convert _TopHeader to StatefulWidget (it may already be one from previous edits — check)
   - Add a FocusNode + TextEditingController for the search TextField
   - Remove readOnly: true from the TextField
   - Change hintText to 'Search players, tournaments, venues...'
   - On onChanged: debounce 400ms then call SearchService().search(value)
   - Show search results in an OverlayPortal dropdown below the search bar
   - Dropdown: dark card (color: Color(0xFF111111), border, radius 12)
   - Group results by type with small section headers: 'Players', 'Tournaments', 'Games', 'Venues'
   - Each row: leading circle avatar (imageUrl or type icon), title, subtitle
   - On tap: close dropdown, clear search, call SearchService().clear(),
     navigate via WebShellController().navigateTo(index) where:
     users → index 5 (Profile), tournaments → index 1, games → index 0, venues → index 4
   - Show CircularProgressIndicator(color: Color(0xFFDE313B)) while loading
   - Show 'No results for "query"' empty state if results is empty after search
   - Keep the 'Ctrl K' badge on the right side of the search bar

3. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Summary of files created/modified and what changed.
```

- [ ] **Step 2: Wait for Agent 1 to complete, review output**
  - Verify `search_service.dart` created with correct singleton pattern
  - Verify `web_shell.dart` has working OverlayPortal dropdown
  - Verify zero analyze issues

---

### Task 2: Agent 2 — Home Dashboard Specialist

**Files:**
- Modify: `lib/screens/web/web_home_dashboard.dart`

- [ ] **Step 1: Launch Agent 2 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in dashboard UX. You own exactly:
  - lib/screens/web/web_home_dashboard.dart (1139 lines)

YOUR TASKS:

1. UPCOMING/SCHEDULE LAYOUT FIX:
   The tab toggle buttons ('Upcoming', 'Schedule') currently sit horizontally in a row
   alongside the panel title. Move them so they appear stacked vertically on the RIGHT
   side of the page in a fixed right column (~220px wide). The left content area shows
   the currently active list. Use a Row layout: Expanded(left content) + SizedBox(220, right column with vertical buttons).
   Each button: full width, AnimatedContainer 150ms, active state uses Color(0xFFDE313B)
   background, inactive uses transparent with border.

2. IMMERSIVE CARD RESULTS:
   When a toggle button is clicked, the results (upcoming matches or schedule) render
   in an AnimatedSwitcher (200ms FadeTransition) inside a Card-style container:
   - Background: Color(0xFF0E0E0E)
   - Border: Border.all(color: Color(0xFF1C1C1C))
   - BorderRadius: 16
   - Padding: 16
   - The card fills the available left column height
   - Each result row has hover effect: AnimatedContainer border glow on hover

3. GRADIENT FIX:
   Line ~497 uses `gradColors` in a LinearGradient on sport mode buttons.
   Read that code. If gradColors contains red shades, replace the gradient with
   flat Color(0xFFDE313B). If it's non-red (blue, green etc for sport modes),
   leave it — it's intentional.

4. HUMAN WALKTHROUGH AUDIT:
   Mentally walk through the page as a user:
   - Page loads: are there loading states for all data? If not, add CircularProgressIndicator(color: Color(0xFFDE313B)) centered.
   - Sports mode selector: does switching sport work?
   - Upcoming matches list: can user see matches? Is empty state shown when list is empty?
   - Schedule list: same check.
   - Nearby games section: does it load? Any broken interactions?
   - All buttons: do they have onTap? Are any null?
   - Any overflow errors visible (e.g. text too long for container)? Add TextOverflow.ellipsis.
   - Any dead navigation (navigateTo calls with wrong index)?
   Fix everything you find.

5. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Wait for Agent 2, review output**
  - Verify toggle buttons are on right side, stacked vertically
  - Verify results render in AnimatedSwitcher card
  - Verify gradient fix applied correctly

---

### Task 3: Agent 3 — Landing Page Specialist

**Files:**
- Modify: `lib/screens/web/web_landing_page.dart`

- [ ] **Step 1: Launch Agent 3 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Frontend Engineer specializing in marketing landing pages. You own:
  - lib/screens/web/web_landing_page.dart (2240 lines)

YOUR TASKS:

1. GRADIENT RED BUTTON FIX (PRIORITY):
   Lines 435-439: _HeroPrimaryBtn uses LinearGradient([_red, _redDeep]) as button background.
   Replace with flat: color: const Color(0xFFDE313B)
   Lines 662-666: Another CTA button uses LinearGradient([_red, _redDeep] or [_red, Color(0xFFCC1020)]).
   Replace with flat: color: const Color(0xFFDE313B)
   Keep all other gradients (transparent overlays, RadialGradient glows) — they are decorative.

2. HUMAN WALKTHROUGH AUDIT — walk through as a new visitor:
   a) NAVBAR: Logo renders? Nav links visible? "Get Started" / "Sign In" buttons work?
      Do they navigate to the correct auth route?
   b) HERO SECTION: Headline readable? CTA buttons functional? Animated elements working?
   c) FEATURES SECTION: All feature cards render? Icons/images load with fallback?
   d) SOCIAL PROOF / STATS: Numbers display correctly? No overflow?
   e) HOW IT WORKS: Steps render in correct order? Icons correct?
   f) CTA SECTION: Bottom CTA button navigates correctly to auth?
   g) FOOTER: Links render? No overflow at 1280px width?

3. For every button/link: verify it has a working onTap that navigates somewhere meaningful.
   If onTap is null or navigates to a dead route, fix it.

4. Check all text for overflow at 1280px+ width. Add TextOverflow.ellipsis or flexible layouts where needed.

5. Verify AnimatedScale(1.02) on hover is applied to _HeroPrimaryBtn and _RedBtn (may already be done — verify and keep).

6. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made, especially the gradient fixes and any dead navigation found.
```

- [ ] **Step 2: Review Agent 3 output**
  - Confirm gradient lines 435-439 and 662-666 are flat color
  - Confirm all CTAs have working navigation

---

### Task 4: Agent 4 — Feed Specialist

**Files:**
- Modify: `lib/screens/web/web_feed_page.dart`

- [ ] **Step 1: Launch Agent 4 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in social feed UX. You own:
  - lib/screens/web/web_feed_page.dart (676 lines)

YOUR TASKS — human walkthrough as a user:

1. FEED LOAD: When page first loads, is there a loading state?
   If not: add centered CircularProgressIndicator(color: Color(0xFFDE313B)).
   When feed is empty: add empty state with Icon(Icons.dynamic_feed_outlined, size: 48,
   color: Color(0xFF3A3A3A)) + Text('Nothing here yet') + Text('Follow people to see their posts').

2. POST INTERACTION:
   - Like button: does it call the correct service method? Does the icon toggle filled/outlined?
   - Comment button: does it open a comment input or navigate to post detail?
   - Share button: does it do something, or is onTap null? If null, add a snackbar: 'Link copied!'
   - Any buttons with null onTap → fix them.

3. POST CREATION:
   - Is there a "Create Post" button or FAB? If yes, does it open the correct flow?
   - If missing entirely, add a prominent "New Post" button in the header area.

4. RIGHT SIDEBAR: Does it render content (suggestions, trending)? Any overflow?

5. Check all text for TextOverflow. Add ellipsis where text can overflow containers.

6. Gradient check: any red LinearGradient on buttons → replace with Color(0xFFDE313B).

7. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Review Agent 4 output**

---

### Task 5: Agent 5 — Tournaments Specialist

**Files:**
- Modify: `lib/screens/web/web_tournaments_page.dart`

- [ ] **Step 1: Launch Agent 5 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in tournament/competition UX. You own:
  - lib/screens/web/web_tournaments_page.dart (1061 lines)

YOUR TASKS — human walkthrough:

1. LOAD STATE: Loading indicator while tournaments fetch? If not, add it.
   Empty state when no tournaments: Icon(Icons.emoji_events_outlined, size: 48,
   color: Color(0xFF3A3A3A)) + 'No tournaments yet' + 'Check back soon'.

2. FILTER CHIPS: Do sport/status filters work? Do they update the list correctly?
   Any filter chip with null onTap → fix.

3. TOURNAMENT CARD TAP: When user taps a card, does the detail panel/view open?
   If onTap is null → fix. Detail view must show: name, sport, dates, teams, status.

4. JOIN/REGISTER BUTTON: Does it call the correct TournamentService method?
   If button is missing or non-functional, add a working "Join" button that calls
   TournamentService().joinTournament(tournamentId, userId).

5. RIGHT PANEL / DETAIL VIEW: Does it render without overflow?
   Check all text fields for TextOverflow.ellipsis.

6. Gradient check lines 233, 459, 785: read each LinearGradient.
   If it uses red colors → replace with flat Color(0xFFDE313B).
   If it's a background/decorative gradient (blues, darks) → leave it.

7. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Review Agent 5 output**

---

### Task 6: Agent 6 — Venues Specialist

**Files:**
- Modify: `lib/screens/web/web_venues_page.dart`

- [ ] **Step 1: Launch Agent 6 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in venue discovery UX. You own:
  - lib/screens/web/web_venues_page.dart (951 lines)

NOTE: This file was recently updated. Lint issue on line 268 already fixed.
Hover effects and BouncingScrollPhysics already added by a previous agent.

YOUR TASKS — human walkthrough:

1. LOAD STATE: Loading indicator while venues fetch? Check Consumer<VenueService> builder —
   if venues list is empty AND no explicit loading flag, show a 3-column shimmer placeholder
   or CircularProgressIndicator(color: Color(0xFFDE313B)).

2. SPORT FILTER: Do filter chips update the venue list? Max 8 chips — already implemented,
   verify it works. Any chip with null onTap → fix.

3. FEATURED BANNER TAP: Does tapping the featured venue open the detail panel?
   Verify _selected is set and _RightPanel renders the venue detail.

4. VENUE CARD TAP: Same check — does onTap set _selected correctly?

5. RIGHT PANEL / VENUE DETAIL: Renders without overflow? 
   - Phone/website links: do they launch? Use url_launcher if available, else show snackbar.
   - Book/contact button: functional or placeholder?
   - Photos: do they load with NetworkImage? Add errorBuilder fallback:
     Container(color: Color(0xFF1A1A1A), child: Icon(Icons.image_outlined, color: Color(0xFF3A3A3A)))

6. Check all text for TextOverflow.ellipsis where text could overflow.

7. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Review Agent 6 output**

---

### Task 7: Agent 7 — Profile & Auth Specialist

**Files:**
- Modify: `lib/screens/web/web_profile_page.dart`

- [ ] **Step 1: Launch Agent 7 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in user profile UX. You own:
  - lib/screens/web/web_profile_page.dart (780 lines)

YOUR TASKS — human walkthrough:

1. PROFILE LOAD: Profile image loads from correct bucket:
   gs://mysportsbuddies-4d077.firebasestorage.app/profile_images/{userId}.jpg
   Add error fallback for broken images: show initials avatar instead.

2. EDIT PROFILE: Is there an edit button? Does it open an editable form?
   If edit flow is broken (null onTap, no save action), fix it to call
   UserService().updateProfile(...) with the edited fields.

3. STATS DISPLAY: Sport stats render correctly? No overflow on stat numbers?
   Add TextOverflow.ellipsis to any stat label that could be long.

4. ACTIVITY / FEED: Does the activity section load posts/matches?
   Loading state if missing. Empty state if missing.

5. FOLLOW BUTTON: If viewing another user's profile, does follow/unfollow work?
   Calls FollowService().toggleFollow(userId)?

6. Gradient check line 481: read the LinearGradient.
   If it uses red colors → replace with Color(0xFFDE313B).
   If decorative (dark overlay) → leave it.

7. Check all text for TextOverflow.ellipsis.

8. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Review Agent 7 output**

---

### Task 8: Agent 8 — Scorecard Specialist

**Files:**
- Modify: `lib/screens/web/web_scorecard_page.dart`

- [ ] **Step 1: Launch Agent 8 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in sports scoring/stats UX. You own:
  - lib/screens/web/web_scorecard_page.dart (936 lines)

YOUR TASKS — human walkthrough:

1. LOAD STATE: Scorecards loading indicator present? If not, add centered
   CircularProgressIndicator(color: Color(0xFFDE313B)).
   Empty state when no scorecards: Icon(Icons.scoreboard_outlined, size: 48,
   color: Color(0xFF3A3A3A)) + 'No matches yet' + 'Play a game to see scorecards here'.

2. FILTER: Sport/date filters work? Any filter with null onTap → fix.

3. SCORECARD CARD TAP: Opens detail panel with full score breakdown?
   If onTap is null → fix. Detail must show: teams, scores per period, winner.

4. RIGHT PANEL: Renders without overflow?
   Score numbers: large enough to read, correct color (winning team in green #30D158,
   losing in muted #888888)?

5. LIVE SCORE indicator: if a match is live, is there a pulsing dot or 'LIVE' badge?
   If missing, add: Container with Color(0xFF30D158) dot + Text('LIVE') for live matches.

6. Gradient check line 378: read the LinearGradient.
   If it uses red colors → replace with Color(0xFFDE313B).
   If decorative → leave it.

7. Check all text for TextOverflow.ellipsis.

8. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 2: Review Agent 8 output**

---

### Task 9: Agent 9 — UI Consistency Engineer

**Files:**
- Read + targeted edits: all 8 web screen files

- [ ] **Step 1: Launch Agent 9 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior UI Engineer focused on visual consistency. You will READ all 8 files
and make ONLY targeted find-and-replace style edits. Do NOT restructure or refactor.

Files to scan:
  lib/screens/web/web_shell.dart
  lib/screens/web/web_landing_page.dart  (Agent 3 already fixed lines 435-439, 662-666)
  lib/screens/web/web_home_dashboard.dart
  lib/screens/web/web_feed_page.dart
  lib/screens/web/web_profile_page.dart
  lib/screens/web/web_scorecard_page.dart
  lib/screens/web/web_tournaments_page.dart
  lib/screens/web/web_venues_page.dart

YOUR TASKS:

1. GRADIENT AUDIT: Scan ALL files for LinearGradient that uses red-family colors
   ([_red, ...], [Color(0xFFDE313B), ...], [Color(0xFFFF2B2B), ...], [Color(0xFFB3001B), ...],
   [Color(0xFFCC1020), ...]).
   For each found on a BUTTON or INTERACTIVE element → replace with flat Color(0xFFDE313B).
   Background/decorative gradients (transparent, dark colors, non-interactive) → LEAVE.

2. withOpacity() AUDIT: Scan all files for .withOpacity( — replace each with .withValues(alpha: .
   Example: Colors.white.withOpacity(0.5) → Colors.white.withValues(alpha: 0.5)

3. CARD BORDER RADIUS: Scan for BorderRadius.circular() on cards. Normalize to 12 or 16.
   If you see 8 or 10 on a card container → change to 12. If you see 20+ → change to 16.
   Do not change button radii (keep 8 for buttons, 99 for pills).

4. ICON SIZE CONSISTENCY: Scan for Icon( widgets with size values.
   Navigation icons: normalize to 18-20. Content icons: normalize to 20-24. Don't change decorative/large icons.

5. After all edits: run flutter analyze lib/screens/web/
   Expected: No issues found.

Return: File-by-file list of every targeted change made.
```

- [ ] **Step 2: Review Agent 9 output**
  - Verify no structural changes — only targeted replacements
  - Verify zero new analyze issues

---

## WAVE 2 — After Wave 1 complete

### Task 10: Agent 10 — Shell & Navigation Engineer

**Files:**
- Modify: `lib/screens/web/web_shell.dart` (after Agent 1 hands off)

- [ ] **Step 1: Confirm Agent 1 is complete and web_shell.dart is stable**

- [ ] **Step 2: Launch Agent 10 with this exact prompt**

```
[PASTE SHARED CONTEXT BLOCK]
[PASTE KNOWN ISSUES BLOCK]

You are a Senior Flutter Developer specializing in app shell and navigation. You own:
  - lib/screens/web/web_shell.dart

IMPORTANT: Agent 1 (Search Engineer) already modified this file to add working search.
Read the current state of the file carefully before making any changes.
Do NOT modify the search bar or SearchService integration.

YOUR TASKS:

1. KEYBOARD SHORTCUT HINTS IN SIDEBAR:
   Each nav item (_SideNavItem) should show a subtle keyboard shortcut badge on the right
   when hovered. Shortcuts: Home=⌘1, Tournaments=⌘2, Scorecard=⌘3, Feed=⌘4, Venues=⌘5, Profile=⌘6
   Style: Text('⌘N', style: inter(fontSize: 10, color: Color(0xFF3A3A3A)))
   Show only on hover (use existing _hover state). Wrap in Opacity(opacity: _hover ? 1.0 : 0.0).
   Use AnimatedOpacity(duration: 150ms) for smooth appearance.

2. RESPONSIVE SIDEBAR — COLLAPSE AT < 900px:
   Add LayoutBuilder wrapping the WebShell body Row.
   If constraints.maxWidth < 900:
     - Sidebar width: 52px (icons only, no labels, no logo text)
     - Show only the icon, centered, with active/hover states preserved
     - Logo: show only the red square icon, no text
   If constraints.maxWidth >= 900: normal full sidebar (current behavior)
   Use AnimatedContainer(duration: 200ms) for smooth collapse/expand.

3. NOTIFICATION BELL: Verify the unread badge dot (8x8 red dot) is positioned correctly
   at Positioned(right: 6, top: 6). If it looks off, adjust to right: 4, top: 4.

4. USER AVATAR POPUP MENU: Verify 'Sign Out' calls AuthService().signOut() and then
   navigates to '/login' with pushNamedAndRemoveUntil. Already implemented — just verify.

5. HEADER HEIGHT: Currently 64px (_headerH). Ensure it looks balanced with the 210px sidebar.
   If sidebar is collapsed (52px), header should still span full width correctly.

6. Run: flutter analyze lib/screens/web/
   Expected: No issues found.

Return: Bullet list of every change made.
```

- [ ] **Step 3: Review Agent 10 output**
  - Verify sidebar collapses at < 900px
  - Verify keyboard hints appear on hover

---

## Final Verification

- [ ] **Step 1: Run full analyze**
```bash
flutter analyze lib/screens/web/
```
Expected output: `No issues found.`

- [ ] **Step 2: Verify success criteria**
  - [ ] Search returns real Firestore results across users, tournaments, games, venues
  - [ ] No gradient red buttons anywhere (all CTAs use flat Color(0xFFDE313B))
  - [ ] Home page upcoming/schedule on right side with immersive card results
  - [ ] Every page has loading states and empty states
  - [ ] Sidebar collapses to icons-only at < 900px width
  - [ ] Zero analyze issues

- [ ] **Step 3: Commit all changes**
```bash
git add lib/screens/web/ lib/services/search_service.dart
git commit -m "feat: 10-agent web team — search, gradient fixes, dashboard layout, UX polish"
```
