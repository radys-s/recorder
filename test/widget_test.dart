import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recorder/app.dart';

void main() {
  testWidgets('RecorderApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RecorderApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
