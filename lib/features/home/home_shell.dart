import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
import '../../core/spacing.dart';
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
/// Navigation is a floating dock (see [_HomeNavigationBar]).
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
    const pages = [MeetingsListScreen(), SubjectsScreen(), NotesLibraryScreen()];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          // Hidden tabs keep their state but not their tickers, so an
          // animation on one tab never runs while another is on screen.
          for (var i = 0; i < pages.length; i++)
            TickerMode(enabled: i == _index, child: pages[i]),
        ],
      ),
      bottomNavigationBar: _HomeNavigationBar(
        index: _index,
        onSelected: _select,
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Dnes', Icons.today_outlined, Icons.today),
  _Tab('Předměty', Icons.school_outlined, Icons.school),
  _Tab('Knihovna', Icons.auto_stories_outlined, Icons.auto_stories),
];

/// A quiet floating dock. It floats so content can run under it, but it is
/// near-opaque (no blur — that costs frames over long lists) and carries only
/// three destinations and one moving pill.
///
/// The Scaffold uses `extendBody`, so the dock's height reaches every tab as
/// bottom padding; the root lists add that padding after their last row and
/// nothing ends up under the dock.
class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final reduced = reducedMotion(context);
    final height = largeText ? 76.0 : 64.0;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.xl,
        0,
        Gap.xl,
        bottom > 0 ? bottom : Gap.md,
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(Gap.xs + 2),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1E1F23) : scheme.surface).withValues(
            alpha: 0.97,
          ),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: dark ? 0.8 : 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / _tabs.length;
            return Stack(
              children: [
                // The moving pill behind the selected destination.
                AnimatedPositioned(
                  duration: reduced ? Duration.zero : AppDuration.base,
                  curve: AppCurve.standard,
                  left: slot * index,
                  top: 0,
                  bottom: 0,
                  width: slot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _DockItem(
                          tab: _tabs[i],
                          selected: i == index,
                          onTap: () => onSelected(i),
                          radius: height / 2,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.radius,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.selectedIcon : tab.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
