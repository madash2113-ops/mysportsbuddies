import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../data/sports_list.dart';
import '../nearby/nearby_games_screen.dart';

class AllSportsScreen extends StatefulWidget {
  const AllSportsScreen({super.key});

  @override
  State<AllSportsScreen> createState() => _AllSportsScreenState();
}

class _AllSportsScreenState extends State<AllSportsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filteredSports = allSports
        .where((sport) =>
            sport.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: AppC.bg(context),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'All Sports',
          style: TextStyle(
            color: AppC.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              style: TextStyle(color: AppC.text(context)),
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Search sport',
                hintStyle: TextStyle(color: AppC.hint(context)),
                prefixIcon: Icon(Icons.search, color: AppC.muted(context)),
                filled: true,
                fillColor: AppC.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredSports.length,
              itemBuilder: (context, index) {
                final sport = filteredSports[index];
                return ListTile(
                  leading: Text(
                    sport.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    sport.name,
                    style: TextStyle(
                      color: AppC.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppC.hint(context),
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => NearbyGamesScreen(sport: sport.name),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
