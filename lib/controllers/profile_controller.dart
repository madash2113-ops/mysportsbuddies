import 'dart:io';
import 'package:flutter/material.dart';

class ProfileController extends ChangeNotifier {
  File? _profileImage;

  File? get profileImage => _profileImage;

  void setProfileImage(File image) {
    _profileImage = image;
    notifyListeners();
  }
}
