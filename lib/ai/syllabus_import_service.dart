import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import 'answer_source.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'syllabus.dart';

/// Longest pasted plan sent to Gemini, and to the router behind it.
const int kSyllabusTextGeminiChars = 60000;
const int kSyllabusTextRouterChars = 20000;

/// A thematic plan read or estimated, before the student reviews it.
class SyllabusImport {
  const SyllabusImport({
    required this.topics,
    this.sources = const [],
    this.estimated = false,
  });

  final List<SyllabusTopicDraft> topics;

  /// Pages the estimate was based on; empty for a plan the student supplied.
  final List<AnswerSource> sources;

  /// True for an AI estimate, which the UI labels as such.
  final bool estimated;
}

/// Turns a pasted plan, photos of it, or nothing but the course profile into
/// a list of topics.
///
/// Gemini first; on any failure but a wrong key the text paths go to the
/// router, so a busy Gemini never blocks the import. Photos already fall back
/// to Mistral inside the Gemini provider.
class SyllabusImportService {
  SyllabusImportService({
    required this._gemini,
    required this._llm,
    required this._hasGeminiKey,
  });

  static const _tag = 'ai.syllabus';

  final GeminiProvider _gemini;
  final LlmProvider _llm;
  final Future<bool> Function() _hasGeminiKey;

  /// Topics from a plan the student pasted.
  Future<SyllabusImport> fromText(String text, {required String course}) async {
    final plan = text.trim();
    if (plan.isEmpty) throw ArgumentError.value(text, 'text', 'blank');
    String user(int max) => 'Course: $course\n\nThe plan:\n${_cut(plan, max)}';

    if (await _geminiAvailable()) {
      try {
        final result = await _gemini.generate(
          model: kGeminiModel,
          messages: [
            const LlmMessage.system(_readPrompt),
            LlmMessage.user(user(kSyllabusTextGeminiChars)),
          ],
          jsonMode: true,
          maxTokens: 12000,
          timeout: kGeminiNotesTimeout,
        );
        final topics = parseSyllabus(result.content);
        if (topics.isNotEmpty) return SyllabusImport(topics: topics);
      } on AiException catch (e) {
        if (e.kind == GeminiErrorKind.badKey) rethrow;
        AppLog.e(_tag, 'Gemini failed, asking the router', e);
      }
    }
    final raw = await _llm.complete(
      model: kGroqAnswerModel,
      messages: [
        const LlmMessage.system(_readPrompt),
        LlmMessage.user(user(kSyllabusTextRouterChars)),
      ],
      jsonMode: true,
      maxTokens: 6000,
    );
    return SyllabusImport(topics: _nonEmpty(raw));
  }

  /// Topics from photos or screenshots of a printed plan.
  Future<SyllabusImport> fromImages(
    List<LlmImage> images, {
    required String course,
  }) async {
    if (images.isEmpty) throw ArgumentError.value(images, 'images', 'empty');
    final result = await _gemini.generate(
      model: kGeminiModel,
      messages: [
        const LlmMessage.system(_readPrompt),
        LlmMessage.user(
          'Course: $course\n'
          '${images.length == 1 ? 'A photo' : '${images.length} photos'} '
          'of the thematic plan.',
        ),
      ],
      images: images,
      jsonMode: true,
      maxTokens: 12000,
      timeout: kGeminiPhotoTimeout,
    );
    return SyllabusImport(topics: _nonEmpty(result.content));
  }

  /// A plan guessed from the course alone, with web search when Gemini can.
  Future<SyllabusImport> estimate({required String course}) async {
    final user =
        'Course: $course\nThe school year runs from September to June.';
    if (await _geminiAvailable()) {
      try {
        final result = await _gemini.generate(
          model: kGeminiModel,
          messages: [
            const LlmMessage.system(_estimatePrompt),
            LlmMessage.user(user),
          ],
          search: true,
          maxTokens: 12000,
          timeout: kCardLookupTimeout,
        );
        final topics = parseSyllabus(result.content);
        if (topics.isNotEmpty) {
          return SyllabusImport(
            topics: topics,
            sources: result.sources,
            estimated: true,
          );
        }
        AppLog.d(_tag, 'grounded estimate had no topics, asking the router');
      } on AiException catch (e) {
        if (e.kind == GeminiErrorKind.badKey) rethrow;
        AppLog.e(_tag, 'Gemini estimate failed, asking the router', e);
      }
    }
    final raw = await _llm.complete(
      model: kGroqAnswerModel,
      messages: [
        const LlmMessage.system(_estimatePrompt),
        LlmMessage.user(user),
      ],
      jsonMode: true,
      maxTokens: 6000,
    );
    return SyllabusImport(topics: _nonEmpty(raw), estimated: true);
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey();
    } catch (_) {
      return false;
    }
  }

  List<SyllabusTopicDraft> _nonEmpty(String raw) {
    final topics = parseSyllabus(raw);
    AppLog.d(_tag, '${topics.length} topic(s)');
    if (topics.isEmpty) {
      throw const AiPermanentException('V plánu jsem nenašel žádná témata.');
    }
    return topics;
  }

  static String _cut(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static const String _shape = '''
Reply with one JSON object and nothing else:
{"topics": [{"title": "...", "description": "...", "terms": ["...", "..."], "month_from": 9, "month_to": 10}]}

- "title": the topic as the plan names it, in Czech, at most 12 words.
- "description": one short sentence on what the topic covers, or null.
- "terms": 5-15 technical terms, names and abbreviations a teacher will say
  out loud in this topic, spelled as written in the field (English terms and
  abbreviations stay English, e.g. "VLAN", "subnet mask").
- "month_from" / "month_to": numbers 1-12 for when the topic is taught, or
  null when unknown.
- Topics in teaching order. No introduction, revision or exam entries unless
  they are real topics.''';

  static const String _readPrompt =
      '''
A student gives you the thematic plan (tematický plán) of one school course,
as text or photos. List its topics.

$_shape
- Take the topics from the plan only; never add a topic it does not contain.
  Terms may be completed from your knowledge of the topic.''';

  static const String _estimatePrompt =
      '''
A Czech student has no thematic plan for one course. Estimate it for the
course and year given, as Czech schools teach it (RVP/ŠVP for that school type
and field). Search the web for published thematic plans or ŠVP of similar
schools when you can.

$_shape
- Cover the whole school year, September to June, with months filled in.''';
}
