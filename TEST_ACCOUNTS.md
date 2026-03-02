# Test Accounts Setup Guide

This document explains how to create and manage test accounts for MySportsBuddies app testing.

## Quick Start

### Option 1: Development Mode (Fastest - Recommended for Testing)

The app is currently in **DEV MODE** (`kDevMode = true` in `lib/core/config/app_config.dart`).

**In dev mode:**
- ALL users get full premium access automatically
- Perfect for testing all features without account creation
- Any account you create will have full access

**To use dev mode:**
1. Simply create any account in the app through the registration flow
2. All features are unlocked automatically
3. No need to add UIDs to `kOwnerUserIds`

### Option 2: Production Mode with Owner Access

When you're ready to deploy or test production behavior:

1. **Enable production mode** in `lib/core/config/app_config.dart`:
```dart
const bool kDevMode = false;  // Changed from true
```

2. **Add your test account UIDs** to the owner list:
```dart
const List<String> kOwnerUserIds = [
  'YOUR_FIREBASE_UID_1',
  'YOUR_FIREBASE_UID_2',
  // Add more test account UIDs here
];
```
 
3. **How to find your Firebase UID:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project
   - Go to **Authentication** → **Users**
   - Each user row shows their UID
   - Copy and paste into `kOwnerUserIds`

## Creating Test Accounts

### Through App Registration UI

1. Launch the app
2. Go to login screen
3. Tap "Create Account" or "Register"
4. Fill in details:
   - **Full Name**: Use descriptive names like "Test User 1", "Admin Test", etc.
   - **Email**: Use unique emails: `test1@example.com`, `test2@example.com`
   - **Phone**: Any valid format: `+1234567890`
   - **Password**: Use strong passwords (if email auth is enabled)

5. After registration, note the user's Firebase UID from Firebase Console

### Through Firebase Console (Direct Creation)

For more control, you can create users directly in Firebase:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Authentication** → **Users** tab
4. Click **"Create User"** button
5. Enter email and password
6. Copy the generated UID

## Recommended Test Accounts

Create these test accounts for different scenarios:

```
1. Personal Account (Your account)
   - Name: "Your Name"
   - Email: your.email@example.com
   - Phone: Your phone number
   - Purpose: Personal testing & feature verification
   - UID: [Add to kOwnerUserIds after creation]

2. Admin/Full Access Account
   - Name: "Test Admin"
   - Email: admin.test@example.com
   - Phone: +1111111111
   - Purpose: Full feature testing in production mode
   - UID: [Add to kOwnerUserIds]

3. Regular User Account
   - Name: "Test User"
   - Email: user.test@example.com
   - Phone: +2222222222
   - Purpose: Testing free features, non-premium flow

4. Community Tester
   - Name: "Community Test"
   - Email: community.test@example.com
   - Phone: +3333333333
   - Purpose: Community features, posts, stories

5. Social Features Tester
   - Name: "Social Test"
   - Email: social.test@example.com
   - Phone: +4444444444
   - Purpose: Follow, messages, collaborations
```

## Access Levels

### DEV MODE (Current Setting - kDevMode = true)
- ✅ All users have full premium access
- ✅ All features unlocked
- ✅ No time restrictions
- ✅ No payment required
- Perfect for: Feature development & QA testing

### PRODUCTION MODE (kDevMode = false)
- ❌ Only users in `kOwnerUserIds` have full access
- ❌ Regular users are limited to free features
- ❌ Premium features require `isPremium = true` or owner status
- Perfect for: Pre-release testing, payment flow testing

## Implementation Details

### Full Access Check

The app uses this logic to determine full access:

```dart
bool get hasFullAccess {
  if (kDevMode) return true;                                    // Dev mode: always true
  if (_userId != null && kOwnerUserIds.contains(_userId)) return true;  // Owner list
  return _profile?.isPremium == true;                           // Premium flag
}
```

### Setting Premium Status Manually

If you need to set `isPremium = true` for a user:

1. Go to Firebase Console
2. Go to **Firestore Database** → **users** collection
3. Find the user document by their UID
4. Edit the document and add/set: `isPremium: true`
5. Restart the app to see changes

## Testing Workflows

### Test All Features
1. Stay in DEV MODE
2. Create any test account
3. All features automatically available

### Test Premium Flow
1. Set `kDevMode = false`
2. Create a regular test account
3. Verify free features work
4. Add account UID to `kOwnerUserIds`
5. Restart app
6. Verify premium features unlock

### Test Payment Integration (Future)
1. Set `kDevMode = false`
2. Create regular test account
3. Implement payment logic
4. Verify premium features unlock after purchase

## Firestore User Document Structure

When a user registers, this data is stored in Firestore:

```json
users/{userId}
{
  "id": "firebase-auth-uid",
  "numericId": 483921,
  "name": "Test User",
  "email": "test@example.com",
  "phone": "+1234567890",
  "location": "City, State",
  "dob": "1990-01-15",
  "bio": "Sports enthusiast",
  "imageUrl": "https://...",
  "updatedAt": Timestamp,
  "isPremium": false
}
```

## Quick Reference

| Setting | Location | Purpose |
|---------|----------|---------|
| `kDevMode` | `lib/core/config/app_config.dart` | Toggle dev/prod mode |
| `kOwnerUserIds` | `lib/core/config/app_config.dart` | Owner account UIDs |
| `isPremium` | Firestore `users/{uid}` | Premium account flag |
| User data | Firebase Auth + Firestore | Account information |

## Troubleshooting

**Issue**: Account created but features not unlocked in production mode
- **Solution**: Add UID to `kOwnerUserIds` and restart app

**Issue**: Can't find Firebase UID
- **Solution**: Check Firebase Console → Authentication → Users, look for the UID column

**Issue**: Changes not reflecting after setting isPremium
- **Solution**: Hot restart or full restart the app (not hot reload)

**Issue**: Multiple test accounts needed
- **Solution**: Create more accounts, add their UIDs to `kOwnerUserIds` (comma-separated list)

## Best Practices

✅ **Do:**
- Keep a list of test account credentials in a secure note
- Document which UID belongs to which test account
- Use descriptive names so you remember what each account tests
- Add new test accounts as you discover new features to test
- Regularly clean up unused test accounts in Firebase

❌ **Don't:**
- Use production email addresses for testing
- Leave `kDevMode = true` when deploying to production
- Share test account UIDs publicly
- Delete test accounts without backing up their UIDs first
- Mix personal and test accounts in production

