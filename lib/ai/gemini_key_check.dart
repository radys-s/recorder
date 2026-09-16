import '../core/constants.dart';
import 'gemini_model_resolver.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'photo_text_service.dart';

enum CheckState { ok, warn, fail }

class GeminiCheckStep {
  const GeminiCheckStep(this.label, this.state, this.detail);

  final String label;
  final CheckState state;
  final String detail;
}

class GeminiKeyReport {
  const GeminiKeyReport({
    required this.steps,
    this.models,
    this.selectable = const [],
  });

  final List<GeminiCheckStep> steps;

  /// The models the app will use, when the key offers any.
  final GeminiModelPair? models;

  /// Flash models the user may pick instead, newest first.
  final List<String> selectable;

  bool get works => steps.every((s) => s.state != CheckState.fail);
}

/// „Ověřit klíč" as a real test: list the models, pick the ones to use, then
/// one tiny plain call and one tiny search call. Each step says what went
/// wrong in Google's own words, so a missing model or a used-up limit is not
/// mistaken for a bad key. Stops at the first step nothing else can follow.
Future<GeminiKeyReport> checkGeminiKey({
  required Future<List<String>> Function() listModels,
  required GeminiProvider gemini,
  required GeminiModelResolver resolver,
  String? override,
}) async {
  final steps = <GeminiCheckStep>[];

  List<String> ids;
  try {
    ids = await listModels();
  } catch (e) {
    steps.add(GeminiCheckStep('Klíč a seznam modelů', CheckState.fail,
        geminiFailureText(e)));
    return GeminiKeyReport(steps: steps);
  }
  steps.add(GeminiCheckStep('Klíč a seznam modelů', CheckState.ok,
      'Google nabízí ${ids.length} modelů.'));

  final pair = pickGeminiModels(ids, override: override);
  final selectable = selectableGeminiModels(ids);
  if (pair == null) {
    steps.add(const GeminiCheckStep('Model', CheckState.fail,
        'Klíč nenabízí žádný model Gemini Flash.'));
    return GeminiKeyReport(steps: steps, selectable: selectable);
  }
  final overrideIgnored = override != null && pair.main != override;
  steps.add(GeminiCheckStep(
    'Model',
    overrideIgnored ? CheckState.warn : CheckState.ok,
    [
      'Hlavní ${pair.main}, lehký ${pair.lite}.',
      if (overrideIgnored) 'Vybraný $override už klíč nenabízí.',
    ].join(' '),
  ));
  resolver.use(pair);

  try {
    await gemini.generate(
      model: kGeminiModel,
      messages: const [LlmMessage.user('Odpověz jedním slovem: funguješ?')],
      maxTokens: 1024,
      timeout: const Duration(seconds: 40),
    );
    steps.add(const GeminiCheckStep(
        'Odpověď modelu', CheckState.ok, 'Model odpovídá.'));
  } catch (e) {
    steps.add(GeminiCheckStep(
        'Odpověď modelu', CheckState.fail, geminiFailureText(e)));
    return GeminiKeyReport(steps: steps, models: pair, selectable: selectable);
  }

  try {
    final found = await gemini.generate(
      model: kGeminiModel,
      messages: const [
        LlmMessage.user('Kdo je autorem knihy Babička? Odpověz jménem.'),
      ],
      search: true,
      maxTokens: 1024,
      timeout: const Duration(seconds: 40),
    );
    steps.add(found.grounded
        ? const GeminiCheckStep('Vyhledávání Google', CheckState.ok,
            'Dohledávání karet půjde přes Google.')
        : const GeminiCheckStep('Vyhledávání Google', CheckState.warn,
            'Model odpovídá bez vyhledávání — dohledané karty ověř.'));
  } catch (e) {
    steps.add(GeminiCheckStep('Vyhledávání Google', CheckState.warn,
        '${geminiFailureText(e)} Dohledávání pak půjde přes Groq.'));
  }
  return GeminiKeyReport(steps: steps, models: pair, selectable: selectable);
}
