# Flutter SDK — Project Setup (recommended)

This repository should NOT include the full Flutter SDK. The `flutter/` folder in this repo contained a nested Git repository; that nested metadata has been removed and `flutter/` is now ignored.

Recommended workflow (scalable and reproducible): use FVM (Flutter Version Manager) to pin and share Flutter versions across the team and CI.

Quick steps (developer machine, Windows):

1. Install FVM:

```powershell
# Using Dart (recommended if you have Dart SDK installed):
dart pub global activate fvm

# OR using Chocolatey (if you prefer):
# choco install fvm
```

2. Pin a Flutter version for this project (pick the version your team wants):

```powershell
# Example: pick a version or channel (adjust to the version you use)
fvm use 3.44.0-0.2.pre --force --local
# This creates an .fvm config in the repo telling teammates which version to use
```

3. Install and use the pinned SDK:

```powershell
fvm install
fvm flutter pub get
# Run Android/iOS build via fvm flutter
fvm flutter build apk
```

CI integration:
- Install FVM on CI runner and call `fvm install` then use `fvm flutter` to run build/test commands.

Why this is better:
- Keeps repository small (no heavy binary history)
- Ensures everyone uses the same Flutter version
- Easier to upgrade and test alternate versions

Notes about this change:
- A backup of the nested `.git` was created at the repo root with a name like `flutter-git-backup-<timestamp>`.
- The `flutter/` directory is now ignored in `.gitignore`.

If you want me to also add `fvm` config (e.g. `fvm use <version> --local`) and commit it, tell me which Flutter version/channel to pin.
