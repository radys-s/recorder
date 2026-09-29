import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/meetings_list/widgets/transcription_key_sheet.dart';

class _Keys extends ApiKeyStore {
  _Keys(this.value);
  final String? value;

  @override
  Future<String?> read() async => value;
}

void main() {
  Future<({Future<bool> result, List<int> opened})> open(
    WidgetTester tester, {
    String? groq,
    String? gemini,
  }) async {
    late Future<bool> result;
    final opened = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(_Keys(groq)),
          geminiKeyStoreProvider.overrideWithValue(_Keys(gemini)),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => result = confirmTranscriptionKey(
                  context,
                  ref,
                  openSettings: () async => opened.add(1),
                ),
                child: const Text('Nahrát'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nahrát'));
    await tester.pumpAndSettle();
    return (result: result, opened: opened);
  }

  testWidgets('a Groq key goes straight through', (tester) async {
    final r = await open(tester, groq: 'gsk_test');
    expect(find.text('Chybí klíč pro přepis'), findsNothing);
    expect(await r.result, isTrue);
  });

  testWidgets('a Gemini key alone is enough', (tester) async {
    final r = await open(tester, gemini: 'AIza_test');
    expect(find.text('Chybí klíč pro přepis'), findsNothing);
    expect(await r.result, isTrue);
  });

  testWidgets('no key: the sheet points to Settings and does not record', (
    tester,
  ) async {
    final r = await open(tester);
    expect(find.text('Chybí klíč pro přepis'), findsOneWidget);

    await tester.tap(find.text('Otevřít Nastavení'));
    await tester.pumpAndSettle();

    expect(await r.result, isFalse);
    expect(r.opened, [1]);
  });

  testWidgets('no key: recording anyway is allowed', (tester) async {
    final r = await open(tester);
    await tester.tap(find.text('Nahrávat i tak'));
    await tester.pumpAndSettle();

    expect(await r.result, isTrue);
    expect(r.opened, isEmpty);
  });

  testWidgets('no key: dismissing the sheet cancels the recording', (
    tester,
  ) async {
    final r = await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await r.result, isFalse);
  });
}
