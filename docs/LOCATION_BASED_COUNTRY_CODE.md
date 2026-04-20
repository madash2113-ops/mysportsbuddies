# Location-Based Country Code & Deployment Agents

## Overview

This implementation provides:
1. **Location-based country code detection** for automatic phone code selection
2. **Senior Developer Agent** - Automated code review and architecture validation
3. **Senior Tester Agent** - Automated testing and quality assurance

## Part 1: Location-Based Country Code Detection

### How It Works

The app detects the user's country and automatically sets the correct phone code during registration/login.

#### Detection Flow (Priority Order)

1. **GPS Location (Most Accurate)**
   - Requests device location permission
   - Reverse geocodes coordinates to country using Nominatim API
   - No API key required

2. **IP Geolocation (Fallback)**
   - Uses free IP geolocation APIs (`ipapi.co`, `ip-api.com`)
   - Works without requesting permissions
   - Faster than GPS

3. **Default (Final Fallback)**
   - Falls back to `+91` (India) if all detection fails
   - User can manually change country code

#### Supported Countries (30+)

| Code | Country | Phone | Code | Country | Phone |
|------|---------|-------|------|---------|-------|
| IN | India | +91 | US | USA | +1 |
| GB | United Kingdom | +44 | CA | Canada | +1 |
| AU | Australia | +61 | NZ | New Zealand | +64 |
| ZA | South Africa | +27 | PK | Pakistan | +92 |
| LK | Sri Lanka | +94 | BD | Bangladesh | +880 |
| AF | Afghanistan | +93 | NP | Nepal | +977 |
| MY | Malaysia | +60 | SG | Singapore | +65 |
| AE | UAE | +971 | OM | Oman | +968 |
| QA | Qatar | +974 | BH | Bahrain | +973 |
| SA | Saudi Arabia | +966 | DE | Germany | +49 |
| FR | France | +33 | IT | Italy | +39 |
| ES | Spain | +34 | NL | Netherlands | +31 |
| JP | Japan | +81 | CN | China | +86 |
| KR | South Korea | +82 | BR | Brazil | +55 |
| MX | Mexico | +52 | NG | Nigeria | +234 |
| KE | Kenya | +254 | IE | Ireland | +353 |
| ZW | Zimbabwe | +263 | | | |

### Implementation Details

#### Service: `LocationCountryService`

**File**: `lib/services/location_country_service.dart`

```dart
// Main method - called from screens
final phoneCode = await LocationCountryService().detectCountryCode();
// Returns: "+91", "+1", "+44", etc.

// Convert phone code to Country object
final country = LocationCountryService.getCountryFromCode(phoneCode);
// Returns: Country object for use with country_picker package
```

#### Updated Screens

**1. Phone Login Screen** (`lib/screens/auth/phone_login_screen.dart`)
- Detects country on screen load
- Shows loading indicator: "Detecting your location..."
- User can manually override detected country

**2. Register Game Screen** (`lib/screens/register/register_game_screen.dart`)
- Auto-detects country when creating/editing games
- Uses detected code for organizer's phone number

**3. Edit Profile Screen** (`lib/screens/profile/edit_profile_screen.dart`)
- Can be integrated similarly if needed

### Permissions Required

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Already present in your project -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### API Endpoints Used

1. **Nominatim (OpenStreetMap)** - Free reverse geocoding
   - `https://nominatim.openstreetmap.org/reverse`
   - No API key required
   - Rate limit: 1 request/second

2. **IP Geolocation APIs** (fallback)
   - `ipapi.co/json/` - Reliable, no key
   - `ip-api.com/json/` - Alternative fallback

### Testing Location Detection

```dart
// In phone_login_screen.dart:
_detectUserLocation() async {
  final phoneCode = await LocationCountryService().detectCountryCode();
  print('Detected: $phoneCode'); // e.g., "+1", "+91"
}
```

### Performance Impact

- **GPS Detection**: 5-15 seconds (one-time on login)
- **IP Detection**: 100-500ms (fast fallback)
- **Cached**: Returns immediately on subsequent app restarts
- **No blocking**: UI stays responsive during detection

---

## Part 2: GitHub Actions Deployment Agents

### Overview

Two automated agents run on every Pull Request to ensure code quality and test coverage.

#### 1. Senior Tester Agent

**File**: `.github/workflows/senior-tester-agent.yml`

**Triggers**: Pull requests to `dev`, `test`, `main` branches

**Responsibilities**:
- Run full test suite (unit + widget tests)
- Check code formatting
- Build APK (debug) and verify no build errors
- Generate coverage reports
- Post quality metrics to PR

**Outputs**:
- ✅ Test results in PR comments
- 📊 Coverage metrics
- 🚀 Debug APK artifact (7-day retention)

**Key Checks**:
```bash
✅ Code Analysis (flutter analyze --fatal-infos)
✅ Code Format (dart format --set-exit-if-changed)
✅ Unit & Widget Tests (flutter test --coverage)
✅ APK Build (flutter build apk --debug)
```

#### 2. Senior Dev Agent

**File**: `.github/workflows/senior-dev-agent.yml`

**Triggers**: Pull requests to `dev`, `test`, `main` branches

**Responsibilities**:
- Automated code review and linting
- Architecture pattern validation
- Security scanning
- Dependency analysis
- Pre-merge checklist verification

**Outputs**:
- 📋 Code review comments on PR
- 🏗️ Architecture compliance report
- 🔐 Security findings
- 🚀 Build verification

**Key Checks**:
```bash
✅ Lint & Code Analysis
✅ Format Validation  
✅ Security Scan
✅ Dependency Review
✅ Architecture Patterns
✅ Service ChangeNotifier compliance
✅ Screen layer Provider usage
✅ Firestore naming conventions
✅ Web build verification
✅ Package dependency analysis
```

### Workflow Configuration

Both agents are configured to:
1. Run automatically on PR creation/update
2. Post results as PR comments
3. Mark critical failures (no merge if failed)
4. Provide actionable feedback

### Pre-Merge Checklist (Generated by Senior Dev Agent)

```
- [ ] All automated checks passed
- [ ] Manual code review completed
- [ ] Test coverage maintained (>80%)
- [ ] No breaking changes to public APIs
- [ ] Documentation updated
- [ ] Changelog entry added
```

### Local Verification (Before Pushing)

```bash
# Run locally what the agents will check:

# 1. Code formatting
dart format --set-exit-if-changed lib/ test/

# 2. Linting (fatal mode)
flutter analyze --fatal-infos

# 3. Tests with coverage
flutter test --coverage

# 4. Build validation
flutter build apk --debug
```

### Architecture Checks (Senior Dev Agent)

Validates:
- ✅ Services extend `ChangeNotifier`
- ✅ Singleton pattern used correctly
- ✅ Screens use `Consumer<T>` or `ListenableBuilder`
- ✅ Firestore collections follow naming convention
- ✅ No direct state mutation outside services

### PR Comment Examples

**Tester Agent Comment:**
```
## 🧪 Tester Agent Report

### ✅ Quality Checks
- [x] Code Analysis
- [x] Format Validation
- [x] Unit Tests
- [x] Widget Tests
- [x] Build (APK)

### 📊 Test Coverage
- Current: 82%
- Target: >80%
- ✅ PASSED

### 🚀 Build Artifacts
- [Debug APK] available for download
```

**Dev Agent Comment:**
```
## 👨‍💻 Senior Dev Agent Review

### ✅ Automated Checks
- [x] Lint Analysis (Fatal)
- [x] Code Formatting
- [x] Security Scan
- [x] Dependency Review
- [x] Architecture Patterns

### 📋 Recommendations
1. **Design Patterns**: ✅ Verified consistency with Provider pattern
2. **State Management**: ✅ No Firebase listener leaks detected
3. **Error Handling**: ⚠️ Add try-catch in line 42
4. **Performance**: ✅ Image caching properly implemented

### 🚀 Pre-Merge Checklist
- [ ] All automated checks passed ✅
- [ ] Manual code review completed
- [ ] Test coverage maintained >80% ✅
- [ ] No breaking changes ✅
- [ ] Documentation updated
- [ ] Changelog entry added
```

### Debugging Workflow Issues

If agents fail:

1. **Check local lint**: `flutter analyze --fatal-infos`
2. **Check formatting**: `dart format lib/ test/`
3. **Run tests**: `flutter test`
4. **Build locally**: `flutter build apk --debug`
5. **View workflow logs**: GitHub → Actions → Failed run

### Extending the Agents

To add new checks:

1. **Senior Tester**: Add new test category in `.github/workflows/senior-tester-agent.yml`
   - Example: Add E2E tests, performance tests

2. **Senior Dev**: Add new validation step in `.github/workflows/senior-dev-agent.yml`
   - Example: API contract validation, documentation checks

---

## Integration Summary

### Files Modified/Created

✅ **New Service**: `lib/services/location_country_service.dart`
✅ **Updated Screens**:
  - `lib/screens/auth/phone_login_screen.dart`
  - `lib/screens/register/register_game_screen.dart`
  
✅ **New Workflows**:
  - `.github/workflows/senior-tester-agent.yml`
  - `.github/workflows/senior-dev-agent.yml`

### Build Status

✅ App builds successfully
✅ All imports resolved  
✅ GitHub Actions workflows configured
✅ Location detection implemented

---

## Usage Guide

### For Users

**Phone Login**:
1. App detects user's location (shows spinner if GPS requested)
2. Country code automatically populated
3. User can change via country picker if needed
4. Enter phone number and OTP

**Register Game**:
1. App auto-detects location
2. Organizer phone field uses correct country code
3. User can manually change if different country

### For Developers

**Adding New Country**:

1. Open `lib/services/location_country_service.dart`
2. Add to `_countryCodeToPhone` map:
   ```dart
   'XX': '+XXX', // Country code: phone code
   ```

**Testing Location Service**:
```dart
// In any screen:
final service = LocationCountryService();
final phoneCode = await service.detectCountryCode();
debugPrint('Detected: $phoneCode');
```

---

## Next Steps

1. **Test location detection** on various devices/locations
2. **Monitor API calls** to Nominatim for rate limits
3. **Extend workflows** with additional checks as needed
4. **Document** in user guide if location access requested
5. **Track analytics** for country distribution of users
