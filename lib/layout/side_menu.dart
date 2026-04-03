import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {
  final List<Widget> items;

  const SideMenu({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: items,
      ),
    );
  }
}
