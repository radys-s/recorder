import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/widgets/result_transition.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/search/search_screen.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });
  testWidgets(
    'rapid queries never animate a stale completion; deletion stays gone',
    (t) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final first = await db.savedNotesDao.saveNote(
          title: 'Alfa',
          content: 'První téma',
        );
        await db.savedNotesDao.saveNote(title: 'Beta', content: 'Druhé téma');
        await t.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: SearchScreen()),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 15; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await t.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        await t.enterText(find.byType(TextField), 'alfa');
        await t.pump(const Duration(milliseconds: 251));
        // Change the intent while the first asynchronous corpus scan is pending.
        await t.enterText(find.byType(TextField), 'beta');
        await settle();
        expect(find.text('Beta'), findsOneWidget);
        expect(find.text('Alfa'), findsNothing);
        final state = t.state(find.byType(ResultTransition));
        await t.pump();
        expect(t.state(find.byType(ResultTransition)), same(state));
        await t.enterText(find.byType(TextField), 'alfa');
        await settle();
        await db.savedNotesDao.deleteNote(first);
        // Reaccept the query as well: the assertion must hold with or without
        // the separately developed live corpus-refresh subscription.
        await t.enterText(find.byType(TextField), 'alfa ');
        await settle();
        expect(find.text('Alfa'), findsNothing);
        expect(find.text('Nic nenalezeno'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'beta');
        await t.pump(const Duration(milliseconds: 251));
        await t.enterText(find.byType(TextField), '');
        await settle();
        expect(find.text('Beta'), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        await db.close();
      }
    },
  );
}
