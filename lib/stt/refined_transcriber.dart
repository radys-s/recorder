import 'dart:io';

import '../ai/gemini_provider.dart';
import '../ai/llm_provider.dart';
import '../core/constants.dart';
import '../data/db/tables/preferences_table.dart';
import 'stt_provider.dart';
import 'transcript_sanitizer.dart';

/// What a refined window is told about the lesson it comes from.
class RefinedContext {
  const RefinedContext({
    this.subjectName,
    this.cardTitles = const [],
    this.glossary,
    this.previousText,
    this.languageCode,
    this.sensitivity = MicSensitivity.auto,
  });

  final String? subjectName;
  final List<String> cardTitles;
  final String? glossary;

  /// The end of the window before this one, so a sentence cut at the
  /// boundary is continued rather than guessed.
  final String? previousText;
  final String? languageCode;
  final MicSensitivity sensitivity;
}

/// What Gemini answers for a window with no speech in it.
const String kRefinedSilenceMarker = '[ticho]';

const String _geminiSystemPrompt = '''
You transcribe a recording of a school lesson or a meeting, word for word.

- Write exactly what is said, in the language it is said in (usually Czech), with correct diacritics and punctuation. Do not translate.
- Do not summarise, shorten, reorder or tidy up. Keep repetitions and unfinished sentences as spoken.
- Never add a word that is not in the audio. A part you cannot make out is written as [nesrozumitelné].
- Start a new paragraph when the speaker changes. Do not label speakers.
- Leave out noises, music and silence. If nobody speaks at all, answer only $kRefinedSilenceMarker.
- The context below only helps you spell names and terms; never copy text from it into the transcript.
- Answer with the transcript alone: no heading, no comments, no quotation marks.''';

/// The request for one window: instructions, then whatever context there is.
List<LlmMessage> refinedGeminiMessages(RefinedContext context) {
  final previous = context.previousText?.trim() ?? '';
  final tail = previous.length <= kRefinedContextChars
      ? previous
      : previous.substring(previous.length - kRefinedContextChars);
  final lines = [
    if (context.subjectName?.trim().isNotEmpty ?? false)
      'Subject: ${context.subjectName!.trim()}',
    if (context.cardTitles.isNotEmpty)
      'Topics: ${context.cardTitles.join(', ')}',
    if (context.glossary?.trim().isNotEmpty ?? false)
      'Names and terms: ${context.glossary!.trim()}',
    if (tail.isNotEmpty) 'The previous part of the recording ended with:\n…$tail',
  ];
  return [
    const LlmMessage.system(_geminiSystemPrompt),
    LlmMessage.user(
      '${lines.isEmpty ? '' : 'Context:\n${lines.join('\n')}\n\n'}'
      'Transcribe this recording.',
    ),
  ];
}

/// Gemini's reply as transcript text: the silence marker becomes nothing,
/// stray code fences and quotes are dropped, loops are collapsed.
String cleanGeminiTranscript(String raw) {
  var text = raw.trim();
  text = text.replaceAll(RegExp(r'^```[a-z]*\s*|\s*```$'), '').trim();
  if (text.length >= 2 &&
      (text.startsWith('"') && text.endsWith('"') ||
          text.startsWith('„') && text.endsWith('“'))) {
    text = text.substring(1, text.length - 1).trim();
  }
  if (text.toLowerCase() == kRefinedSilenceMarker) return '';
  text = text.replaceAll(kRefinedSilenceMarker, '').trim();
  return collapseRepeats(text);
}

/// The two ways a window can be heard again.
class RefinedTranscriber {
  RefinedTranscriber({required this.gemini, required this.stt});

  final GeminiProvider gemini;
  final SttProvider stt;

  /// Throws [AiException].
  Future<String> viaGemini(File wav, RefinedContext context) async {
    final result = await gemini.generate(
      model: kGeminiModel,
      messages: refinedGeminiMessages(context),
      images: [LlmMedia(await wav.readAsBytes(), mimeType: 'audio/wav')],
      maxTokens: 16000,
      timeout: kRefinedGeminiTimeout,
    );
    return cleanGeminiTranscript(result.content);
  }

  /// Throws [SttException]. The same guards as the live pass, over the whole
  /// window.
  Future<String> viaWhisper(
    File wav,
    RefinedContext context, {
    required int? voicedMs,
    required int durationMs,
  }) async {
    final result = await stt.transcribe(
      audioFile: wav,
      promptContext: context.previousText,
      languageCode: context.languageCode,
      sensitivity: context.sensitivity,
      glossary: context.glossary,
    );
    final text = limitToSpeakingRate(
      collapseRepeats(sanitizeTranscript(result.text)),
      voicedMs: voicedMs,
      durationMs: durationMs,
    );
    if (isPromptEcho(text, context.previousText) ||
        isPromptEcho(
            text, [?context.glossary, ?context.previousText].join(' '))) {
      return '';
    }
    return text;
  }
}
