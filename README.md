# MySportsBuddies

**Connect. Play. Win. Together.**

Your ultimate companion for finding sports partners, organizing games, and building your athletic community.

---

## 📱 Download Now

- **iOS**: [Available on App Store](#) (Coming Soon)
- **Android**: [Available on Google Play](#) (Coming Soon)

## About the App

MySportsBuddies is a revolutionary mobile application that connects sports enthusiasts and athletes worldwide. Whether you're looking for a tennis partner, need teammates for a basketball game, or want to join a local running club, MySportsBuddies makes it simple to find, connect, and play together.

### Why Choose MySportsBuddies?

- ⚡ **Instant Connections** - Find sports partners in your area within seconds
- 🎯 **Organized Play** - Schedule games, tournaments, and training sessions seamlessly
- 👥 **Community-Driven** - Join sports groups and build lasting friendships
- 🔔 **Stay Updated** - Real-time notifications for game invites and team updates
- 💬 **Direct Messaging** - Chat with teammates and coordinate plans
- 🏆 **Track Progress** - Showcase your sports interests and skill levels

## 🎮 Features

### Core Features
- **Smart Partner Matching** - Discover sports buddies based on sport, skill level, and location
- **Group Management** - Create, join, and manage sports communities
- **Game Scheduling** - Organize matches, practice sessions, and tournaments
- **Comprehensive Profiles** - Highlight your athletic interests, achievements, and availability
- **Live Notifications** - Instant alerts for invitations and team messages
- **In-App Messaging** - Direct communication with teammates
- **Sports Directory** - Browse 10+ popular sports including cricket, football, basketball, tennis, and more
- **Venue Listings** - Discover nearby courts, fields, and training facilities
- **Game Marketplace** - Post and discover open games in your area

## 🛠️ Technology Stack

- **Framework**: Flutter 3.44+ (Beta)
- **Language**: Dart 3.12+
- **Backend**: Firebase (Firestore, Authentication, Cloud Storage)
- **Architecture**: Provider + Singleton ChangeNotifiers
- **Auth**: Phone OTP, Email/Password, Google Sign-In

### Supported Platforms
- iOS 11.0+
- Android 5.0+
- Web (Community support)

## 🚀 Getting Started

### For Users

1. Download MySportsBuddies from the App Store or Google Play
2. Sign up using your phone number, email, or Google account
3. Complete your sports profile
4. Start finding your next sports buddy!

### For Developers

#### Prerequisites
- Flutter 3.44+ (latest beta)
- Dart 3.12+
- Android Studio or Xcode for platform-specific development

#### Installation & Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/mysportsbuddies.git
cd mysportsbuddies

# Install dependencies
flutter pub get

# Configure Firebase
# Follow Firebase setup for Android and iOS (see CLAUDE.md for details)

# Run the app
flutter run
```

#### Development Commands

```bash
# Run with analysis
flutter run

# Format code
dart format lib/ test/

# Static analysis
flutter analyze --fatal-infos

# Run tests
flutter test

# Build for release
flutter build apk --release      # Android
flutter build appbundle --release # Android (Play Store)
flutter build ios --no-codesign   # iOS
```

#### Project Structure
```
lib/
├── services/           # Business logic (singleton ChangeNotifiers)
├── screens/            # UI by feature (auth, community, tournaments, etc.)
├── core/
│   ├── models/        # Data models
│   ├── routes/        # Navigation
│   └── config/        # App configuration
├── widgets/           # Reusable UI components
└── main.dart          # App entry point
```

See [CLAUDE.md](./CLAUDE.md) for detailed architecture documentation.

## 🔐 Security & Privacy

- **Authentication**: Secure phone OTP, email/password, and OAuth integration
- **Data Encryption**: All sensitive data encrypted in transit
- **Privacy First**: User data is never shared with third parties
- **GDPR Compliant**: Full compliance with data protection regulations

[Read our Privacy Policy](#) | [Terms of Service](#)

## 📊 Version

Current Release: **v1.0.0**

## 🆘 Support & Feedback

### Need Help?
- 📧 **Email**: support@mysportsbuddies.com
- 🐛 **Report a Bug**: [GitHub Issues](https://github.com/yourusername/mysportsbuddies/issues)
- 💬 **Community Chat**: [Discord Server](#)
- 📱 **In-App Support**: Settings → Help & Support

### Share Feedback
Your feedback helps us improve! Visit [Feedback Portal](#) to share your ideas and feature requests.

---

**Made with ❤️ by Avinash Maddini for sports enthusiasts worldwide.**

**Follow Us**: [Twitter](#) | [Instagram](#) | [Facebook](#)
