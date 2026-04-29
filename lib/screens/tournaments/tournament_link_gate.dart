import 'package:flutter/material.dart';

import '../../services/tournament_link_service.dart';

class TournamentLinkGate extends StatefulWidget {
  final String tournamentId;
  final String? joinCode;

  const TournamentLinkGate({
    super.key,
    required this.tournamentId,
    this.joinCode,
  });

  @override
  State<TournamentLinkGate> createState() => _TournamentLinkGateState();
}

class _TournamentLinkGateState extends State<TournamentLinkGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TournamentLinkService.openFromLink(
        context,
        PendingTournamentLink(
          tournamentId: widget.tournamentId,
          joinCode: widget.joinCode,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
