import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/settings/key_check.dart';
import 'package:recorder/features/settings/settings_screen.dart';

class _MemoryKeys extends ApiKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async => value = key.trim();

  @override
  Future<void> delete() async => value = null;
}

Future<_MemoryKeys> _pumpGroq(
  WidgetTester tester,
  Future<List<String>> Function() lister, {
  bool autofocus = false,
}) async {
  final keys = _MemoryKeys();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(keys),
        groqModelListerProvider.overrideWithValue(lister),
        keysChangedProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(children: [GroqKeySection(autofocus: autofocus)]),
        ),
      ),
    ),
  );
  await tester.pump();
  return keys;
}

Future<void> _save(WidgetTester tester, String key) async {
  await tester.enterText(find.byType(TextField), key);
  await tester.tap(find.text('Uložit'));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  group('checkKey', () {
    test('a refused key says so in Czech and what to do', () async {
      final check = await checkKey(
        'Groq',
        () async => throw const AiPermanentException(
          'Groq rejected the API key.',
          statusCode: 401,
        ),
      );
      expect(check.works, isFalse);
      expect(check.message, contains('Groq ho odmítl'));
      expect(check.message, isNot(contains('rejected')));
    });

    test('offline is not reported as a bad key', () async {
      final check = await checkKey(
        'Groq',
        () async => throw const AiTransientException('Network problem'),
      );
      expect(check.works, isNull);
      expect(check.message, contains('Zkontroluj připojení'));
    });

    test('a transcription key without Whisper is flagged', () async {
      final ok = await checkKey(
        'Groq',
        () async => [kGroqWhisperModel],
        needsTranscription: true,
      );
      final missing = await checkKey(
        'Groq',
        () async => ['llama'],
        needsTranscription: true,
      );
      expect(ok.message, 'Klíč funguje · přepis je dostupný.');
      expect(missing.message, contains('chybí'));
    });
  });

  group('Groq key card', () {
    testWidgets('saving a refused key tells the student at once', (
      tester,
    ) async {
      await _pumpGroq(
        tester,
        () async => throw const AiPermanentException('no', statusCode: 401),
      );
      await _save(tester, 'gsk_wrong_key_123456');

      expect(
        find.text('Klíč uložen, ale nefunguje. Podrobnosti jsou u klíče.'),
        findsOneWidget,
      );
      expect(find.textContaining('Groq ho odmítl'), findsOneWidget);
    });

    testWidgets('saving a working key needs no second tap', (tester) async {
      final keys = await _pumpGroq(tester, () async => [kGroqWhisperModel]);
      await _save(tester, 'gsk_good_key_123456');

      expect(keys.value, 'gsk_good_key_123456');
      expect(find.text('Klíč uložen a funguje.'), findsOneWidget);
      expect(find.text('Klíč funguje · přepis je dostupný.'), findsOneWidget);
    });

    testWidgets('opened from onboarding, the key field has focus', (
      tester,
    ) async {
      await _pumpGroq(tester, () async => const [], autofocus: true);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    });

    testWidgets('links to the page where a free key is made', (tester) async {
      await _pumpGroq(tester, () async => const []);
      expect(find.text('Získat klíč zdarma'), findsOneWidget);
    });
  });
}
