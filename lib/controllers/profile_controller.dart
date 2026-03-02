import 'dart:io';
import 'package:flutter/material.dart';

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

  // ── Setters ──────────────────────────────────────────────────────────────
  void setProfileImage(File image) {
    _profileImage = image;
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
