# Auto Country Code Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect the user's country code instantly from device locale (no spinner, no network required) and silently refine via IP geolocation in the background.

**Architecture:** `PlatformDispatcher.instance.locale` (Flutter built-in, synchronous) becomes the primary source. `LocationCountryService` gains a `detectFromLocale()` method. `PhoneLoginScreen` shows the form immediately with the locale country, then updates silently if IP returns a different one.

**Tech Stack:** `dart:ui` (PlatformDispatcher — already available), `country_picker` (already in pubspec), existing `LocationCountryService`, existing `PhoneLoginScreen`.

---

## File Map

| File | Change |
|------|--------|
| `lib/services/location_country_service.dart` | Add `detectFromLocale()` static method; add cache-expiry (24h TTL) |
| `lib/screens/auth/phone_login_screen.dart` | Remove spinner; show form immediately from locale; background-refine via IP |

---

### Task 1: Add `detectFromLocale()` to `LocationCountryService`

**Files:**
- Modify: `lib/services/location_country_service.dart`

- [ ] **Step 1: Add the `detectFromLocale()` static method**

Open `lib/services/location_country_service.dart`. Add `import 'dart:ui' show PlatformDispatcher;` at the top, then add this static method just before `getCountryFromCode()`:

```dart
import 'dart:ui' show PlatformDispatcher;
```

```dart
/// Synchronously detect country from device locale.
/// Returns the detected [Country], or null if locale has no country code.
/// This is instant (no network, no permissions) — the preferred primary source.
static Country? detectFromLocale() {
  try {
    final locale = PlatformDispatcher.instance.locale;
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) return null;
    return CountryParser.parseCountryCode(countryCode);
  } catch (e) {
    debugPrint('🌍 Locale detection failed: $e');
    return null;
  }
}
```

- [ ] **Step 2: Add 24-hour cache TTL to prevent stale `+91` from locking in**

Add a constant and modify `getCachedOrDetectCountryCode()` to expire old cache:

```dart
static const String _cachedPhoneCodeKey = 'cached_phone_code';
static const String _cachedPhoneCodeTimestampKey = 'cached_phone_code_ts';
static const Duration _cacheTTL = Duration(hours: 24);
```

Replace the existing `getCachedOrDetectCountryCode()`:

```dart
Future<String> getCachedOrDetectCountryCode() async {
  final cachedCode = await getCachedPhoneCode();
  if (cachedCode != null && cachedCode.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    final tsMillis = prefs.getInt(_cachedPhoneCodeTimestampKey) ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - tsMillis;
    if (cacheAge < _cacheTTL.inMilliseconds) {
      debugPrint('✅ Location: Using cached phone code $cachedCode');
      return cachedCode;
    }
    debugPrint('⏱ Location: Cache expired, re-detecting');
  }
  return detectCountryCode();
}
```

Update `_cachePhoneCode()` to also save the timestamp:

```dart
Future<void> _cachePhoneCode(String phoneCode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedPhoneCodeKey, phoneCode);
    await prefs.setInt(
      _cachedPhoneCodeTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (e) {
    debugPrint('Cache write error: $e');
  }
}
```

- [ ] **Step 3: Verify `dart analyze` passes on this file**

```bash
cd G:/mysportsbuddies
dart analyze lib/services/location_country_service.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/services/location_country_service.dart
git commit -m "feat: add locale-based country detection + 24h cache TTL to LocationCountryService"
```

---

### Task 2: Update `PhoneLoginScreen` — no spinner, instant locale country, background IP refinement

**Files:**
- Modify: `lib/screens/auth/phone_login_screen.dart`

- [ ] **Step 1: Replace the `_isReady` / spinner approach with instant locale detection**

In `_PhoneLoginScreenState`, change the field declarations:

```dart
// BEFORE
Country _country = CountryParser.parseCountryCode('IN');
bool _loading = false;
bool _isReady = false;
String? _error;

// AFTER
late Country _country;
bool _loading = false;
String? _error;
```

- [ ] **Step 2: Update `initState()` to use locale immediately, then background-refine**

```dart
@override
void initState() {
  super.initState();
  // Use device locale instantly — no spinner, no network needed.
  _country = LocationCountryService.detectFromLocale()
      ?? CountryParser.parseCountryCode('IN');
  // Silently refine via IP in the background.
  _refineCountryInBackground();
}

/// Fires IP geolocation in the background and updates the flag/code
/// silently if a different (more accurate) country is returned.
void _refineCountryInBackground() {
  LocationCountryService()
      .getCachedOrDetectCountryCode()
      .timeout(const Duration(seconds: 5), onTimeout: () => '+${_country.phoneCode}')
      .then((phoneCode) {
    if (!mounted) return;
    final refined = LocationCountryService.getCountryFromCode(phoneCode);
    if (refined.countryCode != _country.countryCode) {
      setState(() => _country = refined);
      debugPrint('🌍 Country refined to: ${refined.name} (${refined.phoneCode})');
    }
  }).catchError((dynamic e) {
    debugPrint('🌍 Background refinement failed: $e');
  });
}
```

- [ ] **Step 3: Remove `_initializeCountryCode()` and the `_isReady` guard in `build()`**

Delete the entire `_initializeCountryCode()` method (it is replaced by `_refineCountryInBackground()`).

In `build()`, replace:

```dart
// BEFORE
body: _isReady
    ? Padding(...)
    : const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),

// AFTER
body: Padding(
  padding: const EdgeInsets.all(AppSpacing.lg),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ... (same content as before, just unwrapped)
    ],
  ),
),
```

- [ ] **Step 4: Verify `dart analyze` passes on this file**

```bash
dart analyze lib/screens/auth/phone_login_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Hot restart and verify**

Run the app:
```bash
flutter run
```

Navigate to Login → Phone login. Expected:
- Form appears **immediately** with the correct country flag and code for your device locale (e.g. 🇺🇸 +1 for en_US, 🇬🇧 +44 for en_GB)
- No spinner / loading state
- Country picker still works (tap flag to change manually)

- [ ] **Step 6: Commit**

```bash
git add lib/screens/auth/phone_login_screen.dart
git commit -m "feat: show phone login form instantly using device locale for country code"
```
