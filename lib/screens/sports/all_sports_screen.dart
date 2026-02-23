import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../data/sports_list.dart';
import '../common/sport_action_sheet.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'All Sports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Search sport',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 🏏 SPORTS LIST
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.white38,
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SportActionSheet(
                        sport: sport.name,
                      ),
                    );
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
