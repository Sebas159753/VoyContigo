import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:voycontigo/core/theme/app_theme.dart'; // No longer needed for colors here

class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (int index) => _onItemTapped(index, context),
        backgroundColor: Colors.white,
        indicatorColor: Colors.black12,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Colors.black54),
            selectedIcon: Icon(Icons.dashboard, color: Colors.black),
            label: 'Tablero',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined, color: Colors.black54),
            selectedIcon: Icon(Icons.event_note, color: Colors.black),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined, color: Colors.black54),
            selectedIcon: Icon(Icons.emoji_events, color: Colors.black),
            label: 'Premios',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.black54),
            selectedIcon: Icon(Icons.person, color: Colors.black),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/tablero')) return 0;
    if (location.startsWith('/my-trips')) return 1;
    if (location.startsWith('/rewards')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/tablero');
        break;
      case 1:
        context.go('/my-trips');
        break;
      case 2:
        context.go('/rewards');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
