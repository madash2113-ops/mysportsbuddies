# Firebase Phone Auth Redirect Fix Design

## Goal
Eliminate the disruptive browser redirect during phone number sign-in. On real devices with fingerprints registered: no browser at all. On the emulator during development: test phone number bypasses verification entirely.

## Root Cause
Firebase phone auth verifies the calling app via Play Integrity before sending an SMS. When this check fails (no SHA fingerprints registered, or emulator), Firebase falls back to a browser-based reCAPTCHA flow in a Chrome Custom Tab. The app currently lacks the custom URL scheme intent filter required for the Chrome Custom Tab to redirect cleanly back after reCAPTCHA completes.

## Components

### `android/app/src/main/AndroidManifest.xml` (code change)
Add a new `<intent-filter>` inside the existing `<activity>` block for `MainActivity`. This registers the app's package name as a URL scheme so Chrome Custom Tab can return to the app:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.example.flutter_application_1"/>
</intent-filter>
```

No Dart/Flutter code changes required.

### Firebase Console — SHA fingerprints (user configuration, one-time)
Registers the debug signing key so Play Integrity can verify the app on real Android devices, eliminating reCAPTCHA entirely.

Steps:
1. Run to get fingerprints:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android
   ```
2. Firebase Console → Project Settings → Your apps → Android app
3. Add SHA-1 and SHA-256 certificate fingerprints → Save
4. Download updated `google-services.json` → replace `android/app/google-services.json`

### Firebase Console — Test phone number (emulator/dev bypass)
Emulators never support Play Integrity. A test phone number bypasses SMS verification entirely in development.

Steps:
1. Firebase Console → Authentication → Sign-in method → Phone → Test phone numbers
2. Add: `+1 555-555-5555` / OTP: `123456` (or any number/code pair you prefer)
3. Use this number in the app during emulator testing — no reCAPTCHA, no SMS sent

## Effect Per Environment

| Environment | Before | After |
|---|---|---|
| Real device, no fingerprints | Browser reCAPTCHA → redirect back | Same (fingerprints not yet added) |
| Real device, fingerprints registered | Browser reCAPTCHA → redirect back | **No browser, no redirect** |
| Emulator, test number used | Browser reCAPTCHA → redirect back | **No browser, instant OTP** |
| Emulator, real number used | Browser reCAPTCHA → redirect back | Browser reCAPTCHA → cleaner redirect |

## Testing
- Build and run on emulator → enter test phone number → OTP screen appears with no browser redirect
- Verify existing phone auth flow still works end-to-end (OTP entry, navigation to home)
- No regression on email/Google sign-in flows
