import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', appLightTheme),
    ('dark', appDarkTheme),
  ]) {
    testWidgets('a large app bar shows its title as a headline ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [SliverAppBar.large(title: Text('Nahrávky'))],
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<DefaultTextStyle>(
            find.ancestor(
              of: find.text('Nahrávky'),
              matching: find.byType(DefaultTextStyle),
            ),
          )
          .map((d) => d.style.fontSize)
          .toSet();
      // The expanded copy must be a headline. The theme's text styles carry
      // no size until geometry is merged in, so a title style from the app
      // bar theme used to leave it at the 14 px default.
      final headline = Typography.englishLike2021.headlineMedium!.fontSize;
      expect(sizes, contains(headline));
    });
  }
}
