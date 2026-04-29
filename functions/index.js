const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const functions = require('firebase-functions'); // v1 compat for Auth trigger

admin.initializeApp();

const db = admin.firestore();
const COUNTER_DOC = 'config/numericIdCounter';
const USERS_COL = 'users';

/**
 * Atomically claims the next sequential 6-digit app user ID and writes it to
 * the user's Firestore document.  Idempotent: returns the existing ID if the
 * user already has one.
 */
async function assignNumericId(uid) {
  const userRef = db.collection(USERS_COL).doc(uid);

  // Idempotent check — avoid a transaction if the ID already exists
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    const existing = userSnap.data()?.numericId;
    if (existing) return existing;
  }

  // Atomically claim the next counter value
  const counterRef = db.doc(COUNTER_DOC);
  const newId = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const next = (snap.data()?.next) ?? 100000; // 6-digit floor
    tx.set(counterRef, { next: next + 1 }, { merge: true });
    return next;
  });

  // Write the ID to the user document (merge so we never overwrite other fields)
  await userRef.set(
    { numericId: newId, numericIdStr: String(newId) },
    { merge: true },
  );

  console.log(`Assigned numericId ${newId} to ${uid}`);
  return newId;
}

// ── Auth trigger ─────────────────────────────────────────────────────────────
// Fires the moment a new Firebase Auth account is created — iOS, Android, Web.
// Anonymous accounts (no providerData) are skipped; they receive an ID only if
// the user later upgrades to a real account via reloadForUser().
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  if (!user.providerData || user.providerData.length === 0) return null;
  try {
    await assignNumericId(user.uid);
  } catch (err) {
    console.error('onUserCreated: numericId assignment failed', user.uid, err);
  }
  return null;
});

// ── Callable fallback ────────────────────────────────────────────────────────
// The Flutter app calls this on every sign-in.  For new users the Auth trigger
// will already have written the ID; the idempotent check makes this a no-op.
// For older accounts that were created before the trigger existed (e.g. Murali
// Krishna), this is the only path that will generate the missing ID.
exports.ensureNumericId = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  try {
    const numericId = await assignNumericId(uid);
    return { numericId };
  } catch (err) {
    console.error('ensureNumericId: failed for', uid, err);
    throw new HttpsError('internal', 'Failed to generate numeric ID.');
  }
});
