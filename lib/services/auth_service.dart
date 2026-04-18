import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';

/// Handles all Firebase authentication flows:
///   • Phone OTP
///   • Email / Password (sign-in + sign-up)
///   • Google Sign-In
///
/// After every successful sign-in, calls UserService.reloadForUser() so the
/// profile singleton is updated with the authenticated user's UID.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool    _loading = false;
  String? _error;
  String? _verificationId;
  int?    _resendToken;
  String? _pendingPhone; // stored so OTP screen can show "sent to <number>"
  bool    _googleSignInInitialized = false;

  bool    get loading      => _loading;
  String? get error        => _error;
  String? get pendingPhone => _pendingPhone;
  User?   get currentUser  => _auth.currentUser;
  bool    get isSignedIn   =>
      _auth.currentUser != null && !(_auth.currentUser!.isAnonymous);

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  /// Sends an OTP to [phoneNumber] (E.164 format, e.g. "+917012345678").
  ///
  /// [onCodeSent]      — called when the SMS has been dispatched.
  /// [onError]         — called with a friendly error message on failure.
  /// [onAutoVerified]  — called on Android when the code is read automatically.
  Future<void> sendOtp(
    String phoneNumber, {
    required void Function() onCodeSent,
    required void Function(String error) onError,
    void Function()? onAutoVerified,
  }) async {
    _pendingPhone = phoneNumber;
    _setLoading(true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,

      // Android auto-verification (instant sign-in without user typing code)
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _signInWithCredential(credential);
          _setLoading(false);
          onAutoVerified?.call();
        } catch (e) {
          _setLoading(false);
          onError(e.toString());
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        _loading = false;
        _error = _friendlyError(e);
        notifyListeners();
        onError(_error!);
      },

      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken    = resendToken;
        _setLoading(false);
        onCodeSent();
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Verifies the 6-digit [smsCode] entered by the user.
  /// Returns true on success, false on failure (check [error]).
  Future<bool> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      _error = 'Session expired. Please request a new OTP.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / Password ───────────────────────────────────────────────────────

  /// Signs in an existing user with [email] and [password].
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password.trim(),
      );
      await _postAuth(
        result.user!,
        email: email.trim(),
        name:  result.user!.displayName,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Creates a new account with [email] and [password], then updates the
  /// display name and writes the initial profile to Firestore.
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    _setLoading(true);
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password.trim(),
      );
      await result.user?.updateDisplayName(name.trim());
      await _postAuth(
        result.user!,
        name:  name.trim(),
        email: email.trim(),
        phone: phone.trim(),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  //
  // Android: add the debug + release SHA-1 fingerprints to Firebase Console
  //          (Project settings → Your apps → Android → SHA certificate fingerprints)
  // iOS:     ensure GoogleService-Info.plist is present and the REVERSED_CLIENT_ID
  //          URL scheme is added to Info.plist → CFBundleURLSchemes

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleSignInInitialized = true;
      }
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await _postAuth(
        result.user!,
        name:  googleUser.displayName,
        email: googleUser.email,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
    // Re-initialise UserService which will fall back to anonymous auth
    await UserService().init();
    notifyListeners();
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  Future<void> _signInWithCredential(AuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    await _postAuth(result.user!, phone: _pendingPhone);
  }

  /// Called after every successful sign-in to sync the UserService singleton.
  Future<void> _postAuth(
    User user, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      await UserService().reloadForUser(
        user.uid,
        name:  name  ?? user.displayName,
        email: email ?? user.email,
        phone: phone ?? user.phoneNumber,
      );
    } catch (e) {
      debugPrint('AuthService._postAuth error: $e');
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    if (v) _error = null;
    notifyListeners();
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Wrong OTP code. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Include country code (e.g. +91).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
