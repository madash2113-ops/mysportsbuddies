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

/// Google AI Studio API key — used for AI banner generation (Gemini 2.0 Flash).
/// Get yours free at https://aistudio.google.com/app/apikey
/// Leave empty to disable the "Generate with AI" banner feature.
const String kGeminiApiKey = 'AIzaSyBiY1S-S5TO_mXoTL5f1H0vVfUcjaHeyH0';

/// Firebase UIDs that always get full premium access in production.
/// Add your own UID here once you have email/Google auth set up.
const List<String> kOwnerUserIds = [
  // 'paste-your-firebase-uid-here',
];

/// Numeric player IDs that always get full premium access.
/// Use this when you know the player ID but not the Firebase UID.
const Set<int> kOwnerNumericIds = {
  517913,
};

/// Numeric player IDs reserved for specific Firebase UIDs.
/// These override the auto-generated 6-digit ID at startup.
/// Format: { 'firebase-uid': reservedNumericId }
const Map<String, int> kReservedNumericIds = {
  // 'paste-your-firebase-uid-here': 1,
};
