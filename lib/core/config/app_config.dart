// ── App-wide configuration ─────────────────────────────────────────────────
//
// DEV MODE
// Set kDevMode = true while developing/testing.
// This bypasses ALL premium restrictions so you can test every feature.
// Flip to false before publishing to the app store.
//
// OWNER ACCESS
// Add Firebase UIDs (Firebase console → Authentication → Users → User UID)
// to kOwnerUserIds. Those users always get full premium access in production.

/// Set to true during development — removes ALL premium gates.
const bool kDevMode = true;

/// Firebase UIDs that always get full premium access in production.
/// Add your own UID here once you have email/Google auth set up.
const List<String> kOwnerUserIds = [
  // 'paste-your-firebase-uid-here',
];
