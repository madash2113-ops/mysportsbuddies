# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dependencies
flutter pub get

# Run
flutter run

# Analyze & format (CI enforces these)
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib/ test/

# Test
flutter test
flutter test --coverage

# Build
flutter build apk --debug
flutter build appbundle --release
flutter build ios --no-codesign
```

## Architecture

**Pattern**: Provider + Singleton ChangeNotifiers + Firebase backend.

### Layers
- `lib/services/` — All business logic. Each service is a singleton `ChangeNotifier` with this pattern:
  ```dart
  class XService extends ChangeNotifier {
    XService._();
    static final XService _instance = XService._();
    factory XService() => _instance;
  }
  ```
- `lib/screens/` — UI only. Organized by feature (auth, community, tournaments, scoreboard, etc.)
- `lib/core/models/` — Data models (user_profile, tournament, feed_post, match_score, etc.)
- `lib/core/routes/app_routes.dart` — All named routes
- `lib/core/config/app_config.dart` — `kDevMode = true` bypasses ALL premium restrictions; `kOwnerUserIds`/`kOwnerNumericIds` for production premium; `kGeminiApiKey` enables AI banner generation (Gemini 2.0 Flash)
- `lib/core/engines/rally/` — Standalone `RallyEngine` for rally-based sports (badminton, volleyball, etc.); configured via `RallyRuleConfig`/`RallyPresets`, used by `ScoreboardService`
- `lib/design/` — Design system: `AppColors` (dark "Void" palette, "Flame" red accent), `AppTheme`, `AppTypography`, `AppSpacing`, `AppTextStyles` — always use these instead of raw values

### State management
- 15 services registered in `MultiProvider` at `main.dart`
- Use `Consumer<XService>` in most screens
- Use `ListenableBuilder(listenable: XService(), ...)` when a screen can be pushed from a modal bottom sheet or drawer (Provider tree may not be available there)

### Firebase
- Auth: Phone OTP, email/password, Google Sign-In
- Firestore: Real-time listeners started in `main.dart` (feed, stories, messages, games, scoreboards, notifications, tournaments, venues, game listings)
- Storage bucket: `gs://mysportsbuddies-4d077.firebasestorage.app` — always reference this explicitly, not the default appspot.com bucket
- Profile images: `profile_images/{userId}.jpg`

### Firestore collections
```
users/                              user profiles
feed/ → {postId}/comments/          social posts + comments
stories/                            24h stories (filter isActive client-side)
follows/                            doc ID = {followerId}_{followedId}
conversations/ → {id}/messages/     DMs
notifications/{userId}/items/       per-user notification feed
games/                              registered games
matches/                            scoreboards
tournaments/ → teams/matches/venues/admins/groups/squads/
venues/                             venue listings
game_listings/                      open games marketplace
```

### Analytics
Use `AnalyticsService` (wraps Firebase Analytics + Crashlytics). Always use `AnalyticsEvents` string constants — never raw strings — when logging events.

### Stats storage
`StatsService` stores per-player sport stats **inside user documents** (`users/{userId}.sportStats.{Sport}`), not in a separate collection. ICC-standard batting/bowling stats are tracked.

### Notification triggers
Call `NotificationService.send(toUserId, NotifType.X, ...)` from:
- `FollowService` on follow
- `FeedService.likePost` on like
- `FeedService.addComment` on comment

## Known Dart/Lint Gotchas

- `List.unmodifiable(list)..sort()` — **crashes at runtime**. Sort on a spread copy: `[...list]..sort(...)`
- Multiple `_` callback params in Dart 3: use `(_, _)` not `(_, __)`
- `DropdownButtonFormField(value: ...)` is deprecated — use a plain `DropdownButton` in a styled `Container`
- Use `OverlayPortal` for dropdowns, not `Overlay` — shows correctly inside modal sheets
- Always add actual usage in the same edit as a new import, or the analyzer will warn

## CI/CD

Four GitHub Actions workflows:
- **ci.yml** — Runs on PRs to dev/test/main: format check → analyze → test → build
- **dev-deploy.yml** — Push to `dev`: debug APK build + tests
- **prod-deploy.yml** — Push to `main`: manual approval gate → release APK/AAB/iOS + GitHub Release
- **hotfix.yml** — Hotfix flow
