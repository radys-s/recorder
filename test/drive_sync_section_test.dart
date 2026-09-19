import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/settings/drive_sync_section.dart';
import 'package:recorder/sync/drive_sync_service.dart';
import 'package:recorder/sync/web_authenticator.dart';

const _clientId = '1234-abcdef.apps.googleusercontent.com';

class _Web implements WebAuthenticator {
  @override
  Future<Uri> authenticate(Uri url, {required String callbackScheme}) =>
      throw const WebAuthCancelled();

  @override
  Future<String?> bundleId() async => 'com.example.app';
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  group('messages', () {
    test('czechDocs declines', () {
      expect(czechDocs(1), '1 dokument');
      expect(czechDocs(3), '3 dokumenty');
      expect(czechDocs(5), '5 dokumentů');
    });

    test('each outcome says what happened', () {
      expect(
        driveSyncMessage(const DriveSyncReport(DriveSyncOutcome.notSignedIn)),
        contains('přihlas'),
      );
      expect(
        driveSyncMessage(const DriveSyncReport(DriveSyncOutcome.needsSignIn)),
        contains('vypršelo'),
      );
      expect(
        driveSyncMessage(
          const DriveSyncReport(DriveSyncOutcome.failed, error: 'Disk je plný.'),
        ),
        'Disk je plný.',
      );
      expect(
        driveSyncMessage(
          const DriveSyncReport(DriveSyncOutcome.synced, uploaded: 2),
        ),
        'Odesláno na Disk: 2 dokumenty.',
      );
      expect(
        driveSyncMessage(
          const DriveSyncReport(DriveSyncOutcome.synced, skipped: 1),
        ),
        'Na Disku je všechno aktuální.',
      );
      expect(
        driveSyncMessage(const DriveSyncReport(DriveSyncOutcome.synced)),
        startsWith('Zatím není co posílat'),
      );
    });
  });

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Unmounts inside the body; see `notes_library_screen_test.dart`.
  void uiTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          webAuthenticatorProvider.overrideWithValue(_Web()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DriveSyncSection()),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  uiTest('without a client id it asks for one', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(TextField, 'Client ID'), findsOneWidget);
    expect(find.text('Přihlásit se Googlem'), findsNothing);
  });

  uiTest('a wrong client id is refused and not stored', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Uložit'));
    await _settle(tester);
    expect(find.textContaining('Tohle nevypadá jako Client ID'), findsOneWidget);
    expect(find.text('Přihlásit se Googlem'), findsNothing);
  });

  uiTest('a valid client id is stored and offers sign-in', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), ' $_clientId ');
    await tester.tap(find.text('Uložit'));
    await _settle(tester);
    expect(find.text('Přihlásit se Googlem'), findsOneWidget);
    expect(find.text('Nepřihlášeno'), findsOneWidget);
  });

  uiTest('signed in shows the account and the sync controls', (tester) async {
    await db.preferencesDao.setGoogleClientId(_clientId);
    await db.preferencesDao.setGoogleAccountEmail('s@example.com');
    await pump(tester);
    expect(find.text('Přihlášeno jako s@example.com'), findsOneWidget);
    expect(find.text('Synchronizovat teď'), findsOneWidget);
    expect(find.text('Posílat výpisky automaticky'), findsOneWidget);
    expect(find.text('Odhlásit'), findsOneWidget);
  });
}
