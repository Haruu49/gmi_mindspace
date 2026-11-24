import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom navigation on phones, navigation rail on wide screens.
/// Each tab keeps its own navigation stack (StatefulShellRoute).
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.shell, required this.destinations});

  final StatefulNavigationShell shell;
  final List<ShellDestination> destinations;

  void _onTap(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _onTap,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

const studentDestinations = [
  ShellDestination('Home', Icons.home_outlined, Icons.home_rounded),
  ShellDestination('Mood', Icons.mood_outlined, Icons.mood_rounded),
  ShellDestination('Self-care', Icons.spa_outlined, Icons.spa_rounded),
  ShellDestination('Booking', Icons.event_available_outlined, Icons.event_available_rounded),
  ShellDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

const counsellorDestinations = [
  ShellDestination('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
  ShellDestination('Appointments', Icons.event_note_outlined, Icons.event_note_rounded),
  ShellDestination('Programmes', Icons.celebration_outlined, Icons.celebration_rounded),
  ShellDestination('Content', Icons.auto_stories_outlined, Icons.auto_stories_rounded),
];
