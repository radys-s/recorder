import '../../ai/web_answer_service.dart';
import '../../core/logging.dart';

/// A small, real grounding check for Settings → Diagnostika.
///
/// It calls the same service as a live answer rather than a retired Groq
/// Compound model, so a passing result proves that the badge and source chips
/// in the app have usable evidence behind them.
class WebAnswerProbe {
  const WebAnswerProbe(this._service);

  static const _tag = 'ai.answers.probe';
  static const question =
      'Jaká je aktuální základní úroková sazba České národní banky?';

  final WebAnswerService _service;

  Future<List<String>> run() async {
    final started = DateTime.now();
    final answer = await _service.lookUp(question);
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (answer == null) {
      const line =
          'Bez ověřeného výsledku — přidej Gemini klíč nebo zkus později.';
      AppLog.d(_tag, '$line ($elapsed ms)');
      return ['$line ($elapsed ms)'];
    }

    final domains = answer.sources.map((s) => s.domain).join(', ');
    final line = 'Ověřeno · ${answer.sources.length} zdroje: $domains';
    AppLog.d(_tag, '$line ($elapsed ms): ${answer.answer}');
    return ['$line ($elapsed ms)', answer.answer];
  }
}
