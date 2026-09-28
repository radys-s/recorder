import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
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
/// The shell also tells the global recording banner when the dashboard stage
/// is on screen: the stage *is* the recording then, and a second red strip
/// above it would say the same thing twice.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with RouteAware {
  int _index = 0;

  /// Whether a route is pushed over the shell.
  bool _covered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStage());
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    _covered = true;
    _syncStage();
  }

  @override
  void didPopNext() {
    _covered = false;
    _syncStage();
  }

  void _syncStage() {
    if (!mounted) return;
    ref.read(dashboardStageVisibleProvider.notifier).state =
        _index == 0 && !_covered;
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _syncStage();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      MeetingsListScreen(),
      SubjectsScreen(),
      NotesLibraryScreen(),
    ];
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

/// A floating glass dock: content scrolls under it and shows through the blur.
/// Only the selected destination carries colour — the accent, as a soft
/// gradient pill with a lit outline and a gradient-painted icon.
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
    final radius = BorderRadius.circular(height / 2);
    final accent = context.accent;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.xl,
        0,
        Gap.xl,
        bottom > 0 ? bottom : Gap.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.40 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: GradientOutline(
              gradient: accent.hairline(
                scheme.outlineVariant.withValues(alpha: 0.8),
              ),
              borderRadius: radius,
              width: 0.8,
              child: Container(
                height: height,
                padding: const EdgeInsets.all(Gap.xs + 2),
                decoration: BoxDecoration(
                  color: (dark ? const Color(0xFF1E1F23) : Colors.white)
                      .withValues(alpha: 0.72),
                  borderRadius: radius,
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final slot = box.maxWidth / _tabs.length;
                    return Stack(
                      children: [
                        // A faint pill behind the selected destination.
                        AnimatedPositioned(
                          duration: reduced ? Duration.zero : AppDuration.base,
                          curve: AppCurve.standard,
                          left: slot * index,
                          top: 0,
                          bottom: 0,
                          width: slot,
                          child: GradientOutline(
                            gradient: accent.outlineGradient(
                              opacity: dark ? 0.55 : 0.6,
                            ),
                            borderRadius: radius,
                            width: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: accent.softGradient(),
                                borderRadius: radius,
                              ),
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
            ),
          ),
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
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      size: 22,
      color: selected ? Colors.white : color,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            selected
                ? GradientMask(
                    gradient: context.accent.textGradient,
                    child: icon,
                  )
                : icon,
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
