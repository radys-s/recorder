import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recorder/app.dart';

void main() {
  testWidgets('RecorderApp builds without throwing', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const ProviderScope(child: RecorderApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    final library = tester.getSemantics(find.bySemanticsLabel('Knihovna'));
    expect(library.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
}
