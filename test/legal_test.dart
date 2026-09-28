import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/paths.dart';
import 'package:recorder/core/photo_files.dart';
import 'package:recorder/data/data_privacy.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/legal/consent_screen.dart';
import 'package:recorder/features/legal/recording_notice.dart';
import 'package:recorder/legal/legal_texts.dart';

class _MemoryKeyStore extends ApiKeyStore {
  _MemoryKeyStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async => value = key;

  @override
  Future<void> delete() async => value = null;
}

String _normalized(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('legal texts', () {
    test('the in-app texts match docs/legal', () {
      expect(
        _normalized('docs/legal/podminky-pouziti.md'),
        '# ${kTermsOfUse.title}\n\n${kTermsOfUse.body}\n',
      );
      expect(
        _normalized('docs/legal/zasady-ochrany-osobnich-udaju.md'),
        '# ${kPrivacyPolicy.title}\n\n${kPrivacyPolicy.body}\n',
      );
    });

    test('the shown version matches pubspec', () {
      final version = RegExp(
        r'^version:\s*([0-9.]+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(kAppVersion, version);
    });
  });

  group('consent gate', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Widget app() => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: ConsentGate(child: Scaffold(body: Text('Aplikace'))),
      ),
    );

    testWidgets('blocks the app until all three boxes are ticked', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Vítej v Aftermindu'), findsOneWidget);
      expect(find.text('Aplikace'), findsNothing);

      final accept = find.widgetWithText(
        FilledButton,
        'Souhlasím a pokračovat',
      );
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.widget<FilledButton>(accept).onPressed, isNull);
        await tester.ensureVisible(boxes.at(i));
        await tester.tap(boxes.at(i));
        await tester.pump();
      }
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);

      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(find.text('Aplikace'), findsOneWidget);
      final prefs = await db.preferencesDao.current();
      expect(prefs.termsAcceptedVersion, kTermsVersion);
      expect(prefs.termsAcceptedAt, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('an older version asks again', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ConsentScreen(updated: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Změnily se podmínky'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('the current version goes straight through', (tester) async {
      await db.preferencesDao.acceptTerms(kTermsVersion, DateTime(2026));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Aplikace'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('recording notice', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<Future<bool>> open(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      result = confirmRecordingNotice(context, ref),
                  child: const Text('Nahrát'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Nahrát'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('go on and remember the choice', (tester) async {
      final result = await open(tester);
      expect(find.text('Než začneš nahrávat'), findsOneWidget);

      await tester.tap(find.text('Příště nezobrazovat'));
      await tester.pump();
      await tester.tap(find.text('Mám svolení, nahrávat'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      expect((await db.preferencesDao.current()).recordingNoticeDismissed, isTrue);
    });

    testWidgets('cancel stops the recording and asks next time', (
      tester,
    ) async {
      final result = await open(tester);
      await tester.tap(find.text('Zrušit'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
      expect(
        (await db.preferencesDao.current()).recordingNoticeDismissed,
        isFalse,
      );
    });

    testWidgets('a dismissed notice is skipped', (tester) async {
      await db.preferencesDao.setRecordingNoticeDismissed(true);
      final result = await open(tester);

      expect(find.text('Než začneš nahrávat'), findsNothing);
      expect(await result, isTrue);
    });
  });

  group('data privacy', () {
    late AppDatabase db;
    late Directory docs;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      docs = Directory.systemTemp.createTempSync('wipe_test');
    });
    tearDown(() async {
      await db.close();
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    Future<void> seed() async {
      await db.preferencesDao.acceptTerms(kTermsVersion, DateTime(2026));
      await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)),
      );
      for (final dir in [kRecordingsDirName, kPhotosDirName, kCardPhotosDirName]) {
        final d = Directory(p.join(docs.path, dir, 'x'))
          ..createSync(recursive: true);
        File(p.join(d.path, 'f.bin')).writeAsStringSync('data');
      }
    }

    test('export carries every table and no keys', () async {
      await seed();
      final data = await exportAllData(db, now: DateTime(2026, 9, 28));

      expect(data['app'], 'Aftermind');
      expect(data['schemaVersion'], db.schemaVersion);
      final tables = data['tables']! as Map<String, Object?>;
      expect(tables.keys, containsAll(['meetings', 'preferences']));
      expect((tables['meetings']! as List).single, containsPair('title', 'Hodina'));
      expect(data.toString(), isNot(contains('gsk_')));
    });

    test('wipe removes rows, files and keys, and keeps going on errors', () async {
      await seed();
      final groq = _MemoryKeyStore('gsk_secret');
      final gemini = _MemoryKeyStore('AIza_secret');
      var signedOut = false;
      var cancelled = false;

      await DataWiper(
        db,
        docsPath: () async => docs.path,
        keyStores: [groq, gemini],
        signOutGoogle: () async {
          signedOut = true;
          throw const SocketException('offline');
        },
        cancelReminders: () async => cancelled = true,
      ).wipe();

      expect(signedOut, isTrue);
      expect(cancelled, isTrue);
      expect(await db.select(db.meetings).get(), isEmpty);
      final prefs = await db.preferencesDao.current();
      expect(prefs.termsAcceptedVersion, 0);
      for (final dir in [kRecordingsDirName, kPhotosDirName, kCardPhotosDirName]) {
        expect(Directory(p.join(docs.path, dir)).existsSync(), isFalse);
      }
      expect(groq.value, isNull);
      expect(gemini.value, isNull);
    });
  });
}
