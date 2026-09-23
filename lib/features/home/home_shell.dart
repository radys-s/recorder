import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../meetings_list/meetings_list_screen.dart';
import '../notes_library/notes_library_screen.dart';
import '../subjects/subjects_screen.dart';

/// The three places the app lives: today's lesson, subjects, and the library.
///
/// An [IndexedStack] rather than swapping screens, so switching tabs keeps each
/// one's scroll position, search text and selected subject. Each tab owns its
/// app bar and button; the detail screens are pushed over the whole shell, so
/// the bar underneath does not follow into a meeting.
///
/// The bar is intentionally a stable foundation rather than a floating glass
/// object. Navigation is a control people touch constantly, not decoration.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MeetingsListScreen(),
          SubjectsScreen(),
          NotesLibraryScreen(),
        ],
      ),
      bottomNavigationBar: _HomeNavigationBar(
        index: _index,
        onSelected: _select,
      ),
    );
  }
}

/// A quiet, full-width navigation foundation. The previous floating glass pill
/// looked impressive in isolation but made the screen's main action compete
/// with another rounded object at the bottom on every tab.
class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: largeText ? 96 : 80,
          backgroundColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: onSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Dnes',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Předměty',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: 'Knihovna',
            ),
          ],
        ),
      ),
    );
  }
}
