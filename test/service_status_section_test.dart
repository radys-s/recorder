import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/ai/ai_router.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/settings/service_status_section.dart';

class _Keys extends ApiKeyStore {
  _Keys(this.value);
  final String? value;

  @override
  Future<String?> read() async => value;
}

Future<AiRouteHealth> _pump(
  WidgetTester tester, {
  String? groq,
  String? gemini,
}) async {
  final health = AiRouteHealth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiRouteHealthProvider.overrideWithValue(health),
        apiKeyStoreProvider.overrideWithValue(_Keys(groq)),
        geminiKeyStoreProvider.overrideWithValue(_Keys(gemini)),
        mistralKeyStoreProvider.overrideWithValue(_Keys(null)),
        cerebrasKeyStoreProvider.overrideWithValue(_Keys(null)),
        customAiKeyStoreProvider.overrideWithValue(_Keys(null)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ServiceStatusSection()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return health;
}

void main() {
  setUpAll(() => initializeDateFormatting('cs'));

  testWidgets('without keys every row says so', (tester) async {
    await _pump(tester);
    expect(find.text('Stav služeb'), findsOneWidget);
    expect(find.text('Bez klíče'), findsNWidgets(5));
  });

  testWidgets('a key with no traffic is ready, not yet used', (tester) async {
    await _pump(tester, groq: 'gsk_test');
    expect(find.text('Připraveno, zatím nepoužito'), findsOneWidget);
    expect(find.text('Bez klíče'), findsNWidgets(4));
  });

  testWidgets('follows the router: success, rest, refusal', (tester) async {
    final health = await _pump(tester, groq: 'gsk_test', gemini: 'AIza_test');

    health.succeeded(AiVendor.groq, 'whisper-x');
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('V pořádku'), findsOneWidget);
    expect(find.textContaining('whisper-x'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);

    health.cool(AiVendor.gemini, const Duration(minutes: 5));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Pauza do'), findsOneWidget);
    expect(find.text('1× · 1× limit'), findsOneWidget);

    health.disable(AiVendor.groq, 'gsk_test');
    await tester.pump();
    await tester.pump();
    expect(find.text('Klíč odmítnut — ulož nový'), findsOneWidget);
  });
}
