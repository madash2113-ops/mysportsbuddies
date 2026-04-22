# 10-Agent Web Team — Design Spec
**Date:** 2026-04-22  
**Project:** MySportsBuddies Flutter Web  
**Coordinator:** Claude (Tech Lead — reviews only, never edits)

---

## Problem Statement

The MySportsBuddies web app has a mix of functional bugs, visual inconsistencies, and missing features across all 8 web screen files (~8,300 lines total). Known issues plus a full human-walkthrough audit are required across every page.

### Known Issues (given to every agent)
1. Search bar is non-functional — must search across users, tournaments, games, venues
2. Some buttons use gradient red — must be static `#DE313B` everywhere, no gradients
3. Home page: upcoming/schedule toggle buttons must move to the right side of the page vertically; clicking them shows results in an immersive full-screen card overlay

---

## Architecture

### Coordination Model
- **Tech Lead (Claude):** Coordinates wave launch, reviews each agent output, resolves any conflicts, reports final summary to user. Does NOT edit files.
- **10 specialist agents:** Each owns a non-overlapping set of files. No two agents write to the same file simultaneously.

### Execution Waves

**Wave 1 — 9 agents in parallel:**
| Agent | Role | File(s) Owned |
|---|---|---|
| 1 | Search Engineer | `web_shell.dart` + new `lib/services/search_service.dart` |
| 2 | Home Dashboard Specialist | `web_home_dashboard.dart` |
| 3 | Landing Page Specialist | `web_landing_page.dart` |
| 4 | Feed Specialist | `web_feed_page.dart` |
| 5 | Tournaments Specialist | `web_tournaments_page.dart` |
| 6 | Venues Specialist | `web_venues_page.dart` |
| 7 | Profile & Auth Specialist | `web_profile_page.dart` |
| 8 | Scorecard Specialist | `web_scorecard_page.dart` |
| 9 | UI Consistency Engineer | All 8 files (read + targeted edits for gradient→static red fix only) |

**Wave 2 — after Wave 1 completes:**
| Agent | Role | File(s) Owned |
|---|---|---|
| 10 | Shell & Navigation Engineer | `web_shell.dart` (after Agent 1 hands off) |

---

## Context Strategy

Every agent receives the same **3-layer context block** in their prompt.

### Layer 1 — Shared Project Brief
```
Project: MySportsBuddies — Flutter web app
Theme: dark bg=#080808, card=#111111, border=#1C1C1C
Accent: red=#DE313B — STATIC only, NEVER gradient
Font: Google Fonts Inter throughout
Architecture: Provider + Singleton ChangeNotifiers + Firebase backend
Design system: lib/design/ — always use AppColors, AppTheme, AppTypography, AppSpacing, AppTextStyles
Services: lib/services/ — all singletons via factory constructor
Storage bucket: gs://mysportsbuddies-4d077.firebasestorage.app (not appspot.com)
Lint rule: withOpacity() is deprecated — use withValues(alpha: ...) instead
Sort rule: never sort an unmodifiable list — use [...list]..sort(...)
Dropdowns: use OverlayPortal, not Overlay
Modals: use ListenableBuilder(listenable: XService(), ...) not Consumer inside modal sheets
After all changes: run `flutter analyze lib/screens/web/` — zero issues required
```

### Layer 2 — Known Issues List
```
1. Search bar (web_shell.dart header) is non-functional — Agent 1 implements real search.
   All other agents: do not touch search bar.
2. Gradient red buttons → replace with static Color(0xFFDE313B) everywhere you find them.
3. Home page upcoming/schedule: Agent 2 owns this fix.
   All other agents: do not touch web_home_dashboard.dart for this.
```

### Layer 3 — Role-Specific Brief
Unique per agent — see Agent Briefs section below.

---

## Agent Briefs

### Agent 1 — Search Engineer
**Files:** `lib/screens/web/web_shell.dart`, `lib/services/search_service.dart` (create)  
**Task:**
- Create `SearchService` singleton that queries Firestore: users (by name), tournaments (by name), games (by name), venues (by name)
- Use Firestore `where('name', isGreaterThanOrEqualTo: query)` + `isLessThan: query + '\uf8ff'` prefix search pattern
- Results model: `SearchResult { String type, String id, String title, String subtitle, String? imageUrl }`
- In `web_shell.dart`: remove `readOnly: true` from search TextField, wire up `onChanged` to debounced `SearchService.search(query)`, show results in an `OverlayPortal` dropdown below the search bar
- Dropdown shows grouped results: Users / Tournaments / Games / Venues sections
- Tapping a result navigates to the correct page via `WebShellController`
- Remove "Search coming soon..." hint, replace with "Search players, tournaments, venues..."
- Hand off `web_shell.dart` to Agent 10 after completion

### Agent 2 — Home Dashboard Specialist
**Files:** `lib/screens/web/web_home_dashboard.dart`  
**Task:**
- Move upcoming/schedule toggle buttons to the right side of the page, stacked vertically
- When a toggle is clicked, results render in an immersive card: full-height right panel card with smooth AnimatedSwitcher transition (200ms fade), showing the relevant list
- Fix any gradient red → static `#DE313B`
- Full human-walkthrough audit: load the page mentally from blank state → data loaded → interactions. Fix everything broken, missing, or visually wrong.
- Add loading states (red CircularProgressIndicator) where missing
- Add empty states (icon + headline + subtext) where lists can be empty

### Agent 3 — Landing Page Specialist
**Files:** `lib/screens/web/web_landing_page.dart`  
**Task:**
- Walk through the page exactly as a new visitor would: navbar → hero → features → social proof → CTA → footer
- Fix any broken navigation links, non-functional buttons, or dead CTAs
- Fix gradient red → static `#DE313B`
- Ensure "Get Started" / "Download" / auth CTAs navigate correctly
- Check all sections render correctly at 1280px+ width
- Fix any visual hierarchy issues, spacing inconsistencies, or overflow errors
- Ensure AnimatedScale hover on primary CTA buttons (already added by UX agent — verify and keep)

### Agent 4 — Feed Specialist
**Files:** `lib/screens/web/web_feed_page.dart`  
**Task:**
- Walk through as a user: load feed → read a post → like → comment → create post
- Fix any broken interactions on like/comment/share buttons
- Fix gradient red → static `#DE313B`
- Ensure post creation flow works end-to-end
- Fix loading states and empty states
- Check right sidebar renders correctly
- Fix any overflow or layout issues

### Agent 5 — Tournaments Specialist
**Files:** `lib/screens/web/web_tournaments_page.dart`  
**Task:**
- Walk through: browse tournaments → filter → tap tournament → view details → join/register
- Fix any broken filter chips, broken detail views, broken join flows
- Fix gradient red → static `#DE313B`
- Improve empty state messaging
- Fix any overflow or layout issues at standard web widths

### Agent 6 — Venues Specialist
**Files:** `lib/screens/web/web_venues_page.dart`  
**Task:**
- Walk through: browse venues → filter by sport → tap venue → view details → book
- Fix any broken filter chips, broken detail panel, broken booking flows
- Fix gradient red → static `#DE313B`
- Fix any overflow or layout issues

### Agent 7 — Profile & Auth Specialist
**Files:** `lib/screens/web/web_profile_page.dart`  
**Task:**
- Walk through: view own profile → edit profile → view stats → view activity
- Fix any broken edit flows, broken stat displays, broken image upload
- Fix gradient red → static `#DE313B`
- Fix any overflow or layout issues
- Ensure profile image uses correct storage bucket: `gs://mysportsbuddies-4d077.firebasestorage.app`

### Agent 8 — Scorecard Specialist
**Files:** `lib/screens/web/web_scorecard_page.dart`  
**Task:**
- Walk through: view scorecards → filter → tap scorecard → view detail
- Fix any broken filter, broken detail view, broken score display
- Fix gradient red → static `#DE313B`
- Fix any overflow or layout issues

### Agent 9 — UI Consistency Engineer
**Files:** All 8 web screen files (read all, targeted edits only)  
**Task:**
- Scan every file for `LinearGradient` or `gradient:` that uses red colors → replace with static `Color(0xFFDE313B)`
- Scan for any `withOpacity(` → replace with `withValues(alpha: `
- Scan for font size/weight inconsistencies in headings across pages — normalize
- Scan for border radius inconsistencies on cards — normalize to 12-16px
- Do NOT restructure or refactor — targeted find-and-replace style edits only

### Agent 10 — Shell & Navigation Engineer (Wave 2)
**Files:** `lib/screens/web/web_shell.dart` (after Agent 1 completes)  
**Task:**
- Read the file as updated by Agent 1
- Improve sidebar: add keyboard shortcut hints (⌘1–⌘6) next to nav items as subtle muted badges
- Improve header: ensure notification bell badge is pixel-perfect
- Add responsive handling: if viewport < 900px, collapse sidebar to icon-only mode (48px wide, icons only, no labels)
- Fix any remaining visual inconsistencies in shell chrome
- Ensure sign-out flow in user avatar menu works correctly

---

## Success Criteria

- [ ] `flutter analyze lib/screens/web/` returns zero issues after all agents complete
- [ ] Search returns real results from Firestore across all 4 entity types
- [ ] No gradient red buttons anywhere in the web app
- [ ] Home page upcoming/schedule in correct position with immersive card results
- [ ] Every page has loading states and empty states
- [ ] Every page passes a human walkthrough: no dead buttons, no blank screens, no overflow errors
- [ ] Sidebar collapses at < 900px viewport width

---

## Constraints

- No new package dependencies — Flutter built-ins + existing packages only
- All changes within the existing dark theme aesthetic
- Business logic in services layer only — UI files touch UI only
- Each agent must run `flutter analyze` on their files before reporting done
