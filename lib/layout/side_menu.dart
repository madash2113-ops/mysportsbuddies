import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {
  final List<Widget> items;

  const SideMenu({
    Key? key,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: items,
      ),
    );
  }
}
