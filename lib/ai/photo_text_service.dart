import 'package:dio/dio.dart' show CancelToken;

import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import 'gemini_provider.dart';
import 'json_extract.dart';
import 'llm_provider.dart';

/// What a board photo says: the text on it, and one line about any drawing.
class BoardReading {
  const BoardReading({required this.text, required this.description});

  final String text;
  final String description;
}

/// Reads photos with Gemini: book pages for a card, a board during a lesson.
///
/// Groq has no vision model on this account, so there is no fallback — every
/// caller hides or explains the action when no Gemini key is set.
class PhotoTextService {
  PhotoTextService(this._gemini);

  static const _tag = 'ai.photos';

  final GeminiProvider _gemini;

  /// The text of [pages], in order, paragraphs kept. Throws [AiException];
  /// an image with no text in it is a permanent one with a Czech message.
  Future<String> transcribePages(
    List<LlmImage> pages, {
    CancelToken? cancelToken,
  }) async {
    if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'empty');
    final result = await _gemini.generate(
      model: kGeminiModel,
      messages: [
        const LlmMessage.system(_pagesPrompt),
        LlmMessage.user(pages.length == 1
            ? 'Transcribe this page.'
            : 'Transcribe these ${pages.length} pages, in the order given.'),
      ],
      images: pages,
      maxTokens: 16000,
      timeout: kGeminiPhotoTimeout,
      cancelToken: cancelToken,
    );
    final text = cleanModelText(result.content);
    if (text.isEmpty || text == _noText) {
      throw const AiPermanentException('Na fotkách jsem nenašel žádný text.');
    }
    if (result.truncated) {
      AppLog.d(_tag, '${pages.length} page(s): transcription hit the cap');
      return '$text\n\n[Zbytek se nevešel — zkus méně stránek najednou.]';
    }
    return text;
  }

  /// What is on a board photo. Throws [AiException].
  Future<BoardReading> readBoard(LlmImage photo, {String? subjectName}) async {
    final raw = await _gemini.generate(
      model: kGeminiModel,
      messages: [
        const LlmMessage.system(_boardPrompt),
        LlmMessage.user(subjectName == null
            ? 'A photo taken during a lesson.'
            : 'A photo taken during a lesson of $subjectName.'),
      ],
      images: [photo],
      jsonMode: true,
      maxTokens: 6000,
      timeout: kGeminiPhotoTimeout,
    );
    final reading = parseBoardReading(raw.content);
    if (reading == null) {
      throw const AiPermanentException('Z fotky se nepodařilo nic přečíst.');
    }
    return reading;
  }

  static const _noText = 'NO_TEXT';

  static const String _pagesPrompt = '''
You are given photos of printed or handwritten pages a student wants to keep as
study material. Transcribe the text faithfully, exactly as written, in its own
language: keep paragraphs, line breaks of verse, headings and lists. Join words
hyphenated across a line break. Skip page numbers, running headers and footers.
No commentary, no summary, no Markdown, no code fences. If a word is illegible
write […]. If there is no text at all, reply with exactly NO_TEXT.''';

  static const String _boardPrompt = '''
A student photographed the board (or a projected slide, or a handout) during a
lesson. Read it.

Reply with one JSON object and nothing else:
{"text": "...", "description": "..."}

"text": everything written on it, faithfully, in its own language, one line per
line on the board; formulas in plain text. Empty if nothing is written.
For a presentation slide keep its structure: the slide title on the first line,
then each bullet on its own line starting with "- ", indented sub-bullets with
"  - ". A table goes one row per line, cells separated by " | ", header row
first. Leave out slide numbers, logos, footers and the presenter's name
repeated on every slide.
"description": one short sentence in Czech saying what it shows, including any
diagram, chart, table or picture that text alone would lose — for a chart, what
it compares and its trend. No commentary about the photo itself.''';
}

/// The reading in a reply, or null when it holds neither text nor description.
BoardReading? parseBoardReading(String raw) {
  final decoded = extractJsonObject(raw);
  if (decoded == null) return null;
  String str(Object? v) => v is String ? v.trim() : '';
  final text = cleanModelText(str(decoded['text']));
  final description = str(decoded['description']);
  if (text.isEmpty && description.isEmpty) return null;
  return BoardReading(text: text, description: description);
}

/// Strips code fences a model wraps text in, trailing spaces and runs of
/// blank lines, so the result drops straight into a text field.
String cleanModelText(String raw) {
  var text = raw.trim();
  final fenced = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n?```$').firstMatch(text);
  if (fenced != null) text = fenced.group(1)!.trim();
  return text
      .split('\n')
      .map((l) => l.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// A Czech sentence for a failed Gemini call, for a snackbar or a bubble.
///
/// Says what actually went wrong — a missing model or a used-up limit is not
/// a bad key — and adds Google's own reason when there is one.
String geminiFailureText(Object error) {
  if (error is AiException && error.kind is GeminiErrorKind) {
    final google = error.reason == null
        ? ''
        : ' (Google: ${clipReason(error.reason!, max: 120)})';
    final sentence = switch (error.kind as GeminiErrorKind) {
      GeminiErrorKind.badKey =>
        'Gemini klíč neprošel. Zkontroluj ho v Nastavení.',
      GeminiErrorKind.modelMissing =>
        'Model Gemini není pro tvůj klíč dostupný. V Nastavení › Ověřit klíč '
            'vyber jiný.',
      GeminiErrorKind.apiDisabled =>
        'U klíče není zapnuté Gemini API. Zapni ho v Google AI Studiu.',
      GeminiErrorKind.region => 'Google odsud Gemini API nepouští.',
      GeminiErrorKind.quota =>
        'Došel bezplatný limit Gemini. Zkus to za chvíli znovu.',
      GeminiErrorKind.badRequest => 'Gemini tenhle požadavek nepřijal.',
      GeminiErrorKind.overloaded =>
        'Gemini je teď přetížené (moc lidí najednou). Zkus to za chvíli znovu.',
      GeminiErrorKind.network =>
        'Gemini teď neodpovídá (síť nebo výpadek). Zkus to za chvíli znovu.',
    };
    return '$sentence$google';
  }
  if (error is AiPermanentException) {
    if (error.message.startsWith('Chybí Gemini klíč') ||
        error.message.startsWith('Gemini klíč neprošel') ||
        error.message.startsWith('Na fotkách') ||
        error.message.startsWith('Z fotky') ||
        error.message.startsWith('Dohledání')) {
      return error.message;
    }
    return error.statusCode == null
        ? 'Gemini nevrátil použitelnou odpověď. Zkus to znovu.'
        : 'Gemini požadavek odmítl (HTTP ${error.statusCode}).';
  }
  if (error is AiTransientException) {
    return error.message.startsWith('Dohledání')
        ? error.message
        : 'Gemini teď neodpovídá (limit nebo síť). Zkus to za chvíli znovu.';
  }
  return 'Nepodařilo se to. Zkus to znovu.';
}
