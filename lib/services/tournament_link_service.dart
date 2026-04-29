import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../screens/tournaments/tournament_detail_screen.dart';

class PendingTournamentLink {
  final String tournamentId;
  final String? joinCode;

  const PendingTournamentLink({required this.tournamentId, this.joinCode});
}

class TournamentLinkService {
  TournamentLinkService._();

  static const String publicOrigin = 'https://mysportsbuddies-4d077.web.app';
  static PendingTournamentLink? _pending;

  static bool get _isSignedIn {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  static String shareUrl(String tournamentId, {String? joinCode}) {
    final origin = kIsWeb && Uri.base.hasScheme
        ? Uri.base.replace(path: '', queryParameters: {}).origin
        : publicOrigin;
    final uri = Uri.parse('$origin/tournament/$tournamentId');
    if ((joinCode ?? '').isEmpty) return uri.toString();
    return uri.replace(queryParameters: {'code': joinCode}).toString();
  }

  static String appUri(String tournamentId, {String? joinCode}) {
    final uri = Uri(scheme: 'msb', host: 'tournament', path: tournamentId);
    if ((joinCode ?? '').isEmpty) return uri.toString();
    return uri.replace(queryParameters: {'code': joinCode}).toString();
  }

  static PendingTournamentLink? parse(Uri uri) {
    String? tournamentId;
    if (uri.scheme == 'msb' && uri.host == 'tournament') {
      tournamentId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;
    } else if (uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'tournament') {
      tournamentId = uri.pathSegments[1];
    } else {
      tournamentId = uri.queryParameters['t'];
    }
    if ((tournamentId ?? '').isEmpty) return null;
    return PendingTournamentLink(
      tournamentId: tournamentId!,
      joinCode: uri.queryParameters['code'],
    );
  }

  static void setPending(String tournamentId, {String? joinCode}) {
    _pending = PendingTournamentLink(
      tournamentId: tournamentId,
      joinCode: joinCode,
    );
  }

  static PendingTournamentLink? consumePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  static Future<void> openFromLink(
    BuildContext context,
    PendingTournamentLink link,
  ) async {
    if (!_isSignedIn) {
      _pending = link;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(
          tournamentId: link.tournamentId,
          joinCode: link.joinCode,
        ),
      ),
      (route) => route.settings.name == '/home',
    );
  }

  static bool openPendingIfAny(BuildContext context) {
    final pending = consumePending();
    if (pending == null) return false;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(
          tournamentId: pending.tournamentId,
          joinCode: pending.joinCode,
        ),
      ),
      (_) => false,
    );
    return true;
  }

  static Future<void> shareTournament({
    required String tournamentId,
    required String tournamentName,
    String? joinCode,
  }) async {
    final url = shareUrl(tournamentId, joinCode: joinCode);
    final nativeUrl = appUri(tournamentId, joinCode: joinCode);
    final text = kIsWeb
        ? 'Register for "$tournamentName" on MySportsBuddies:\n$url'
        : 'Register for "$tournamentName" on MySportsBuddies:\n$url\n\nOpen in app: $nativeUrl';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: tournamentName),
    );
  }
}
