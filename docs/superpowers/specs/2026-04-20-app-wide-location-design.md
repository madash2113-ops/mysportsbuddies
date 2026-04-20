# App-Wide Accurate Location Design

## Goal
Make `LocationService` the single source of truth for the user's GPS position across the entire app. Venues on the home screen and browse screen sort by distance and display distance labels. All other location-dependent screens continue to work without change.

## Architecture

`LocationService` becomes a `ChangeNotifier`, matching every other singleton service in the codebase. It holds `Position? lastPosition` and calls `notifyListeners()` whenever that position updates. A single GPS fetch on the home screen warms the singleton for the whole session. Screens bind to it reactively via `ListenableBuilder`.

Fallback when position is unavailable: venues sort alphabetically by name.

## Components

### `lib/services/location_service.dart`
**Change:** Add `extends ChangeNotifier`. Call `notifyListeners()` at the end of both `getCurrentPosition()` and `getLastKnownPosition()` when a non-null position is obtained.

No new public API. No new dependencies.

### `lib/screens/home/home_screen.dart` — `_requestInitialPermissions()`
**Change:** After `Permission.locationWhenInUse.request()` succeeds, call `LocationService().getCurrentPosition()` (fire-and-forget, no await needed — it populates `lastPosition` and notifies listeners automatically).

This is the warm-up call that makes `lastPosition` available to all subsequent screens without them each needing their own GPS fetch.

### `lib/screens/home/home_screen.dart` — `_VenuesGrid`
**Change:** Convert from `StatelessWidget` to `StatefulWidget`. Wrap the venue list in `ListenableBuilder(listenable: LocationService())`. Sort the `venues` list by distance from `LocationService().lastPosition` before rendering. Show a "1.2 km" distance label on each pill alongside the existing venue name.

Fallback: if `lastPosition` is null, render venues in the order returned by `VenueService` (Firestore insertion order).

### `lib/screens/venues/venues_list_screen.dart`
**Change:** Add location init in `initState()` using the fast + accurate pattern from `NearbyGamesScreen`:
1. `getLastKnownPosition()` → instant first sort with cached GPS
2. `getCurrentPosition()` → refined sort when accurate fix arrives

Both calls trigger `setState()` to re-sort. Update `_filtered` getter to sort by distance when `_userPos` is non-null. Show a distance chip ("2.4 km") on each venue card. Fallback: alphabetical sort when position is null.

Add a `Position? _userPos` field to the state class. No changes to `VenueService` or `VenueModel`.

## Data Flow

```
HomeScreen.initState()
  └─ _requestInitialPermissions()
       └─ LocationService().getCurrentPosition()
            └─ notifyListeners()  ← all ListenableBuilders rebuild

_VenuesGrid (home)
  └─ ListenableBuilder(listenable: LocationService())
       └─ sorts VenueService().venues by distanceInKm()
       └─ shows "X km" on each pill

VenuesListScreen
  └─ initState: getLastKnownPosition() → setState
  └─ initState: getCurrentPosition()  → setState
  └─ _filtered getter: sorts by distanceInKm() when _userPos != null
  └─ venue card: shows "X km" chip
```

## Error Handling
- Permission denied: `getCurrentPosition()` returns null → `lastPosition` stays null → venues shown in default order, no distance labels
- GPS timeout (10s existing limit): same fallback
- Venue has `lat: 0, lng: 0`: treat as unknown, sort to end (distance = `double.infinity`)

## Testing
- Grant location permission, open app → venues on home tab show distance labels and sort nearest-first
- Deny location permission → venues show in default order, no distance labels, no crash
- Open VenuesListScreen → distance chips appear on cards, list sorted nearest-first
- NearbyGamesScreen → behaviour unchanged
