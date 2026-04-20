# Firebase Phone Auth Redirect Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the browser redirect during Firebase phone sign-in. On emulator with a test phone number: no browser at all. On a real device with SHA fingerprints registered: no browser at all.

**Architecture:** Two independent fixes: (1) add a custom URL scheme intent filter to `AndroidManifest.xml` so Chrome Custom Tab can redirect back to the app cleanly when reCAPTCHA is needed; (2) register SHA fingerprints in Firebase Console so Play Integrity succeeds and reCAPTCHA is never triggered on real devices. The Dart/Flutter code is unchanged.

**Tech Stack:** Android `AndroidManifest.xml`, Firebase Console (manual configuration).

---

## File Map

| File | Change |
|------|--------|
| `android/app/src/main/AndroidManifest.xml` | Add Firebase auth callback URL scheme intent filter |
| Firebase Console | SHA fingerprints + test phone number (manual, one-time) |

---

### Task 1: Add Firebase auth callback scheme to `AndroidManifest.xml`

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add the intent filter inside `<activity android:name=".MainActivity">`**

The file currently has two `<intent-filter>` blocks inside `MainActivity` (lines 32–41). Add a third one immediately after the existing `msb://tournament` intent filter (after line 41, before `</activity>`):

```xml
        <intent-filter>
            <action android:name="android.intent.action.VIEW"/>
            <category android:name="android.intent.category.DEFAULT"/>
            <category android:name="android.intent.category.BROWSABLE"/>
            <data android:scheme="com.example.flutter_application_1"/>
        </intent-filter>
```

The full `<activity>` block should end up as:

```xml
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="msb" android:host="tournament"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="com.example.flutter_application_1"/>
            </intent-filter>
        </activity>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "fix: add Firebase auth callback URL scheme to AndroidManifest for phone OTP redirect"
```

---

### Task 2: Register SHA fingerprints in Firebase Console (real device fix — manual)

**This task has no code changes.** It is a one-time manual setup step required to eliminate reCAPTCHA on real devices.

- [ ] **Step 1: Get the debug signing fingerprints**

Run this in your terminal (Git Bash / WSL / any shell with Java):

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

Copy the `SHA1` and `SHA-256` values from the output.

- [ ] **Step 2: Add fingerprints to Firebase Console**

1. Open Firebase Console → your project → Project Settings (gear icon) → Your apps
2. Select the Android app (`com.example.flutter_application_1`)
3. Click **Add fingerprint**
4. Paste the SHA-1 value → Save
5. Click **Add fingerprint** again
6. Paste the SHA-256 value → Save

- [ ] **Step 3: Download updated `google-services.json`**

In Firebase Console → Project Settings → Your apps → Android app → click **Download google-services.json**.

Replace `android/app/google-services.json` with the downloaded file.

- [ ] **Step 4: Commit the updated `google-services.json`**

```bash
git add android/app/google-services.json
git commit -m "chore: update google-services.json with SHA fingerprints for Play Integrity"
```

---

### Task 3: Add a test phone number for emulator testing (manual)

**This task has no code changes.** It bypasses SMS verification entirely during emulator development.

- [ ] **Step 1: Add a test phone number in Firebase Console**

1. Firebase Console → Authentication → Sign-in method → Phone
2. Scroll to **Test phone numbers** section → click **Add**
3. Phone number: `+1 555-555-5555`  /  Verification code: `123456`
4. Click **Save**

- [ ] **Step 2: Verify on emulator**

Run the app on an emulator:

```bash
flutter run
```

Navigate to Login → Phone login. Enter `+1 555-555-5555`. Expected:
- OTP screen appears with **no browser redirect**
- Enter `123456` → login succeeds

On a real device with fingerprints registered, entering any registered phone number should also produce no browser redirect.
