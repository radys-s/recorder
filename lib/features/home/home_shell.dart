import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/spacing.dart';
import '../meetings_list/meetings_list_screen.dart';
import '../notes_library/notes_library_screen.dart';
import '../subjects/subjects_screen.dart';

/// The three places the app lives: recordings, subjects with their cards, and
/// the notes kept from lessons.
///
/// An [IndexedStack] rather than swapping screens, so switching tabs keeps each
/// one's scroll position, search text and selected subject. Each tab owns its
/// app bar and button; the detail screens are pushed over the whole shell, so
/// the bar underneath does not follow into a meeting.
///
/// The bar floats over the content (`extendBody`), so every tab gets the bar's
/// height as bottom padding through [MediaQuery] and adds it to its list.
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
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          MeetingsListScreen(),
          SubjectsScreen(),
          NotesLibraryScreen(),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _index,
        onSelected: _select,
      ),
    );
  }
}

/// A frosted pill hovering above the content instead of a band glued to the
/// bottom edge.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Gap.xxl);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(alpha: 0.82),
                  borderRadius: radius,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                // The bar adds the home-indicator inset itself; the SafeArea
                // above already lifted the whole pill clear of it.
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: NavigationBar(
                    height: 64,
                    backgroundColor: Colors.transparent,
                    selectedIndex: index,
                    onDestinationSelected: onSelected,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.mic_none_outlined),
                        selectedIcon: Icon(Icons.mic),
                        label: 'Nahrávky',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.school_outlined),
                        selectedIcon: Icon(Icons.school),
                        label: 'Předměty',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bookmarks_outlined),
                        selectedIcon: Icon(Icons.bookmarks),
                        label: 'Poznámky',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
