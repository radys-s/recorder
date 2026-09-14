import 'package:flutter/material.dart';

import '../meetings_list/meetings_list_screen.dart';
import '../notes_library/notes_library_screen.dart';

/// The two places the app lives: meetings, and the notes kept from them.
///
/// An [IndexedStack] rather than swapping screens, so switching tabs keeps each
/// one's scroll position, search text and selected folder. Each tab owns its
/// app bar and button; the detail screens are pushed over the whole shell, so
/// the bar underneath does not follow into a meeting.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MeetingsListScreen(),
          NotesLibraryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Schůzky',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Poznámky',
          ),
        ],
      ),
    );
  }
}
