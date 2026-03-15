import 'dart:io';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

/// Holds the current user's profile state for the UI layer.
///
/// Auto-syncs [networkImageUrl] from [UserService] whenever the Firestore
/// profile changes (app start, save, upload). This means every widget that
/// watches ProfileController always has the latest photo URL without any
/// manual wiring in each screen.
class ProfileController extends ChangeNotifier {
  File?   _profileImage;
  String? _networkImageUrl;
  String? _name;
  String? _email;
  String? _phone;
  String? _location;
  String? _dob;
  String? _bio;
  int?    _numericId;

  ProfileController() {
    // Listen to UserService so we auto-sync every time the profile loads or
    // is saved (including after a successful image upload).
    UserService().addListener(_syncFromUserService);
    _syncFromUserService();
  }

  @override
  void dispose() {
    UserService().removeListener(_syncFromUserService);
    super.dispose();
  }

  // ── Auto-sync ─────────────────────────────────────────────────────────────

  void _syncFromUserService() {
    final p = UserService().profile;
    if (p == null) return;

    bool changed = false;

    if (p.imageUrl != null && p.imageUrl != _networkImageUrl) {
      _networkImageUrl = p.imageUrl;
      changed = true;
    }
    if (p.name.isNotEmpty && p.name != _name) {
      _name = p.name;
      changed = true;
    }
    if (p.email.isNotEmpty && p.email != _email) {
      _email = p.email;
      changed = true;
    }
    if (p.numericId != null && p.numericId != _numericId) {
      _numericId = p.numericId;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  File?   get profileImage    => _profileImage;
  String? get networkImageUrl => _networkImageUrl;
  String? get name            => _name;
  String? get email           => _email;
  String? get phone           => _phone;
  String? get location        => _location;
  String? get dob             => _dob;
  String? get bio             => _bio;
  int?    get numericId       => _numericId;

  // ── Resolved image provider (use this everywhere) ────────────────────────

  /// Returns the best available ImageProvider for the current user's avatar:
  /// 1. Local file (picked this session, shown immediately)
  /// 2. Network URL (saved to Firestore, persists across restarts)
  /// Returns null when no photo exists (show initials/icon fallback).
  ImageProvider? get avatarImage {
    if (_profileImage != null) return FileImage(_profileImage!);
    if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
      return NetworkImage(_networkImageUrl!);
    }
    return null;
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void setProfileImage(File image) {
    _profileImage = image;
    notifyListeners();
  }

  void clearProfileImage() {
    _profileImage = null;
    notifyListeners();
  }

  void setNetworkImageUrl(String url) {
    _networkImageUrl = url;
    notifyListeners();
  }

  void setProfile({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? dob,
    String? bio,
    String? networkImageUrl,
    int? numericId,
  }) {
    if (name != null)            _name = name;
    if (email != null)           _email = email;
    if (phone != null)           _phone = phone;
    if (location != null)        _location = location;
    if (dob != null)             _dob = dob;
    if (bio != null)             _bio = bio;
    if (networkImageUrl != null) _networkImageUrl = networkImageUrl;
    if (numericId != null)       _numericId = numericId;
    notifyListeners();
  }
}
