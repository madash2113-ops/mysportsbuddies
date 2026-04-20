# App-Wide Accurate Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `LocationService` the single reactive source of truth for GPS position so venues on the home and browse screens sort by distance and show distance labels.

**Architecture:** Add `extends ChangeNotifier` to `LocationService` and call `notifyListeners()` after each position update. `HomeScreen` warms up the singleton after the user grants permission. `_VenuesGrid` and `VenuesListScreen` listen reactively via `ListenableBuilder` and sort by distance.

**Tech Stack:** `geolocator` (already in pubspec), `flutter/foundation.dart` (`ChangeNotifier`), existing `VenueModel.distanceTo()`, existing `LocationService.formatDistance()`.

---

## File Map

| File | Change |
|------|--------|
| `lib/services/location_service.dart` | Add `extends ChangeNotifier`; call `notifyListeners()` after position updates |
| `lib/screens/home/home_screen.dart` | Warm up GPS after permission grant; add distance sort + labels to `_VenuesGrid` |
| `lib/screens/venues/venues_list_screen.dart` | Add `Position? _userPos`, fast+accurate init, distance sort in `_filtered`, "X km" chip on cards |

---

### Task 1: Make `LocationService` a `ChangeNotifier`

**Files:**
- Modify: `lib/services/location_service.dart`

- [ ] **Step 1: Add `extends ChangeNotifier` to the class declaration**

Open `lib/services/location_service.dart`. Change line 8 from:

```dart
class LocationService {
```

to:

```dart
class LocationService extends ChangeNotifier {
```

`flutter/foundation.dart` is already imported on line 2 — no new import needed.

- [ ] **Step 2: Call `notifyListeners()` in `getLastKnownPosition()` after updating `_lastPosition`**

Change:

```dart
  Future<Position?> getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) _lastPosition = pos;
      return pos;
    } catch (e) {
      debugPrint('LocationService.getLastKnownPosition error: $e');
      return null;
    }
  }
```

To:

```dart
  Future<Position?> getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        _lastPosition = pos;
        notifyListeners();
      }
      return pos;
    } catch (e) {
      debugPrint('LocationService.getLastKnownPosition error: $e');
      return null;
    }
  }
```

- [ ] **Step 3: Call `notifyListeners()` in `getCurrentPosition()` after updating `_lastPosition`**

Change (inside the try block, after the `_lastPosition = await Geolocator.getCurrentPosition(...)` assignment):

```dart
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _lastPosition;
```

To:

```dart
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      notifyListeners();
      return _lastPosition;
```

- [ ] **Step 4: Verify `dart analyze` passes**

```bash
cd G:/mysportsbuddies
dart analyze lib/services/location_service.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/services/location_service.dart
git commit -m "feat: make LocationService a ChangeNotifier with notifyListeners on position update"
```

---

### Task 2: Warm up GPS in `HomeScreen` after permission is granted

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add `unawaited` GPS warm-up call after location permission is granted**

In `_requestInitialPermissions()` (around line 189), change:

```dart
    if (accepted == true) {
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
    }
```

To:

```dart
    if (accepted == true) {
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
      // Fire-and-forget: warms up LocationService for all screens this session.
      unawaited(LocationService().getCurrentPosition());
    }
```

`dart:async` is already imported on line 1. `LocationService` is already imported on line 15. `unawaited` is part of `dart:async`.

- [ ] **Step 2: Verify `dart analyze` passes on the file**

```bash
dart analyze lib/screens/home/home_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: warm up LocationService GPS after permission grant in HomeScreen"
```

---

### Task 3: Add distance sort and labels to `_VenuesGrid` (home screen)

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (the `_VenuesGrid` class, around line 2170)

- [ ] **Step 1: Merge `LocationService` into the existing `ListenableBuilder`**

`_VenuesGrid` already has `ListenableBuilder(listenable: VenueService(), ...)`. Change it to listen to both services:

```dart
// BEFORE
    return ListenableBuilder(
      listenable: VenueService(),
      builder: (context, _) {
        final venues = VenueService().venues;
```

```dart
// AFTER
    return ListenableBuilder(
      listenable: Listenable.merge([VenueService(), LocationService()]),
      builder: (context, _) {
        final locSvc = LocationService();
        final pos    = locSvc.lastPosition;

        // Sort by distance when position is available; venue with lat=0/lng=0
        // is treated as unknown and sorts to the end.
        final venues = [...VenueService().venues];
        if (pos != null) {
          venues.sort((a, b) {
            final da = (a.lat == 0 && a.lng == 0)
                ? double.infinity
                : a.distanceTo(pos.latitude, pos.longitude);
            final db = (b.lat == 0 && b.lng == 0)
                ? double.infinity
                : b.distanceTo(pos.latitude, pos.longitude);
            return da.compareTo(db);
          });
        }
```

- [ ] **Step 2: Add "X km" distance label to each venue pill**

Inside `itemBuilder`, replace:

```dart
                      child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stadium_outlined,
                                  color: primary, size: 22),
                              const SizedBox(width: 8),
                              Text(v.name,
                                  style: TextStyle(
                                      color: AppC.text(context),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
```

With:

```dart
                      child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stadium_outlined,
                                  color: primary, size: 22),
                              const SizedBox(width: 8),
                              Text(v.name,
                                  style: TextStyle(
                                      color: AppC.text(context),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (pos != null &&
                                  !(v.lat == 0 && v.lng == 0)) ...[
                                const SizedBox(width: 6),
                                Text(
                                  locSvc.formatDistance(
                                      v.distanceTo(pos.latitude, pos.longitude)),
                                  style: TextStyle(
                                      color: AppC.muted(context),
                                      fontSize: 12),
                                ),
                              ],
                            ],
                          ),
```

- [ ] **Step 3: Verify `dart analyze` passes**

```bash
dart analyze lib/screens/home/home_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: sort venues by distance and show distance labels in home VenuesGrid"
```

---

### Task 4: Add location + distance to `VenuesListScreen`

**Files:**
- Modify: `lib/screens/venues/venues_list_screen.dart`

- [ ] **Step 1: Add imports for `geolocator` and `LocationService`**

Add these two imports after the existing imports at the top:

```dart
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';
```

- [ ] **Step 2: Add `_userPos` field and location init in `initState()`**

In `_VenuesListScreenState`, add a field:

```dart
  Position? _userPos;
```

In `initState()`, after `VenueService().listenToVenues();` add the fast+accurate location fetch pattern:

```dart
    // Fast first render from cached position, then refine with accurate fix.
    LocationService().getLastKnownPosition().then((pos) {
      if (pos != null && mounted) setState(() => _userPos = pos);
    });
    LocationService().getCurrentPosition().then((pos) {
      if (pos != null && mounted) setState(() => _userPos = pos);
    });
```

- [ ] **Step 3: Sort venues by distance in `_filtered`**

Replace the current `_filtered` getter:

```dart
  List<VenueModel> get _filtered {
    var list = VenueService().venues;
    if (_selectedSport != 'All') {
      list = list.where((v) => v.sports.contains(_selectedSport)).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((v) =>
              v.name.toLowerCase().contains(_query) ||
              v.address.toLowerCase().contains(_query))
          .toList();
    }
    return list;
  }
```

With:

```dart
  List<VenueModel> get _filtered {
    var list = VenueService().venues;
    if (_selectedSport != 'All') {
      list = list.where((v) => v.sports.contains(_selectedSport)).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((v) =>
              v.name.toLowerCase().contains(_query) ||
              v.address.toLowerCase().contains(_query))
          .toList();
    }
    final pos = _userPos;
    if (pos != null) {
      list = [...list]..sort((a, b) {
          final da = (a.lat == 0 && a.lng == 0)
              ? double.infinity
              : a.distanceTo(pos.latitude, pos.longitude);
          final db = (b.lat == 0 && b.lng == 0)
              ? double.infinity
              : b.distanceTo(pos.latitude, pos.longitude);
          return da.compareTo(db);
        });
    }
    return list;
  }
```

- [ ] **Step 4: Add "X km" distance chip to each venue card**

In `_VenueCard.build()`, inside `Padding(padding: const EdgeInsets.all(14), ...)`, after the `Row` that contains address (after the `const SizedBox(height: 5)` + address Row), add the distance chip. But `_VenueCard` is a `StatelessWidget` and doesn't have access to `_userPos`.

Pass `_userPos` into `_VenueCard` as a constructor parameter. Change `_VenueCard`:

```dart
// BEFORE
class _VenueCard extends StatelessWidget {
  final VenueModel venue;
  const _VenueCard({required this.venue});
```

```dart
// AFTER
class _VenueCard extends StatelessWidget {
  final VenueModel venue;
  final Position?  userPos;
  const _VenueCard({required this.venue, this.userPos});
```

Update the `itemBuilder` call in `VenuesListScreen.build()` from:

```dart
                      _VenueCard(venue: venues[i]),
```

To:

```dart
                      _VenueCard(venue: venues[i], userPos: _userPos),
```

In `_VenueCard.build()`, after the address Row and its `SizedBox(height: 5)`:

```dart
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(venue.address,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
```

Change to:

```dart
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(venue.address,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (userPos != null &&
                          !(venue.lat == 0 && venue.lng == 0)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            LocationService().formatDistance(
                                venue.distanceTo(
                                    userPos!.latitude, userPos!.longitude)),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
```

- [ ] **Step 5: Verify `dart analyze` passes**

```bash
dart analyze lib/screens/venues/venues_list_screen.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/venues/venues_list_screen.dart
git commit -m "feat: sort venues by distance and show distance chip in VenuesListScreen"
```
