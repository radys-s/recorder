import 'dart:math' as math;

import '../ai/json_extract.dart';
import '../ai/llm_provider.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import 'lesson_vocabulary.dart';
import 'transcript_sanitizer.dart';

const _systemPrompt = '''
You proofread the last few chunks of an automatic Czech speech transcript of a school lesson.

Fix only words the speech recognition misheard: names and terms of this subject, wrong diacritics, a word split in two or two words merged at the edge of a chunk. Use the course and the lesson vocabulary to spell them.

Never rephrase, reorder, add, remove, translate or summarise. Never move text from one chunk into another. Keep filler words, repetitions and grammar mistakes the speaker really made. If you are not sure a word is wrong, leave it as it is. Most chunks need no change at all.

Reply with JSON only: {"texts": ["<chunk 1, corrected>", "<chunk 2, corrected>"]} — exactly as many items as there are chunks, in the same order.''';

/// Fixes the words Whisper misheard in a lesson transcript, using the
/// subject's vocabulary.
///
/// Chunks are proofread in small batches rather than one at a time: the model
/// sees about forty seconds of speech instead of ten, which is what lets it
/// tell a misheard term from a word the teacher really said, and it is three
/// times fewer requests against the same rate limit.
///
/// The prompt asks for spelling fixes only; [acceptCorrection] makes sure of
/// it — per chunk, so one rewritten sentence costs that chunk's correction and
/// nothing else.
class TranscriptCorrector {
  TranscriptCorrector(
    this._llm, {
    String model = kGroqCorrectionModel,
    this.fallbackModel = kGroqAnswerModel,
    this.timeout = kCorrectionTimeout,
  }) : _model = model; // ignore: prefer_initializing_formals

  static const _tag = 'stt.corrector';

  final LlmProvider _llm;
  final String fallbackModel;
  final Duration timeout;
  String _model;
  bool _disabled = false;

  /// Off for the rest of the session after a failure retrying cannot fix.
  bool get disabled => _disabled;

  /// The corrected text, or null when nothing changed, the model's version
  /// was rejected, or the call failed.
  Future<String?> correct({
    required String text,
    required LessonListening lesson,
    List<String> previous = const [],
    bool uncertain = false,
  }) async => (await correctBatch(
    texts: [text],
    lesson: lesson,
    previous: previous,
    uncertain: uncertain,
  )).first;

  /// One entry per chunk of [texts], in the same order: the corrected text, or
  /// null where the chunk is unchanged, was rejected, or the call failed.
  Future<List<String?>> correctBatch({
    required List<String> texts,
    required LessonListening lesson,
    List<String> previous = const [],
    bool uncertain = false,
  }) async {
    final none = List<String?>.filled(texts.length, null);
    if (_disabled || texts.isEmpty) return none;
    final terms = [
      for (final t in lesson.terms.take(kCorrectorTermCount)) t.term,
    ];
    final user = [
      if (lesson.courseLine?.trim().isNotEmpty ?? false)
        'Course: ${lesson.courseLine!.trim()}'
      else if (lesson.subjectName != null)
        'Subject: ${lesson.subjectName}',
      if (lesson.topicTitle?.trim().isNotEmpty ?? false)
        'Topic of this lesson: ${lesson.topicTitle!.trim()}',
      if (terms.isNotEmpty) 'Lesson vocabulary: ${terms.join(', ')}',
      if (previous.isNotEmpty) 'Earlier chunks: ${previous.join(' ')}',
      if (uncertain) 'The recognizer was unsure about some of these chunks.',
      'Chunks:',
      for (var i = 0; i < texts.length; i++) '${i + 1}) ${texts[i]}',
    ].join('\n');

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final raw = await _llm.complete(
          model: _model,
          messages: [
            const LlmMessage.system(_systemPrompt),
            LlmMessage.user(user),
          ],
          temperature: 0,
          maxTokens: 2000,
          jsonMode: true,
          timeout: timeout,
        );
        final list = extractJsonObject(raw)?['texts'];
        // A reply with a different number of chunks has lost track of which
        // text is which, and applying it would move words between segments.
        if (list is! List || list.length != texts.length) {
          AppLog.d(
            _tag,
            'rejected: reply does not cover ${texts.length} chunks',
          );
          return none;
        }
        final out = <String?>[];
        for (var i = 0; i < texts.length; i++) {
          final corrected = list[i];
          if (corrected is! String) {
            out.add(null);
            continue;
          }
          final verdict = acceptCorrection(
            texts[i],
            corrected,
            knownTerms: terms,
          );
          if (verdict != null) {
            AppLog.d(_tag, 'rejected chunk ${i + 1}: $verdict');
            out.add(null);
            continue;
          }
          out.add(
            corrected.trim() == texts[i].trim() ? null : corrected.trim(),
          );
        }
        return out;
      } on AiPermanentException catch (e) {
        if (e.statusCode == 404 && _model != fallbackModel) {
          AppLog.d(_tag, '$_model missing, using $fallbackModel');
          _model = fallbackModel;
          continue;
        }
        AppLog.e(_tag, 'disabled for this session: ${e.message}');
        _disabled = true;
        return none;
      } on AiException catch (e) {
        AppLog.d(_tag, 'skipped: ${e.message}');
        return none;
      }
    }
    return none;
  }
}

/// Why [corrected] is not an acceptable proofreading of [raw], or null when
/// it is.
///
/// Words are aligned without case and diacritics. The correction is rejected
/// when it adds or drops more than max(2, 10 %) of the words, when its length
/// moves outside 85–115 %, or when it swaps a word for one that looks nothing
/// like it (more than 40 % of the letters different) and is not a word of the
/// lesson's vocabulary.
String? acceptCorrection(
  String raw,
  String corrected, {
  Iterable<String> knownTerms = const [],
}) {
  final a = raw.trim(), b = corrected.trim();
  if (b.isEmpty) return 'empty';
  if (a.isEmpty) return 'nothing to correct';
  final ratio = b.length / a.length;
  if (ratio < 0.85 || ratio > 1.15) {
    return 'length ratio ${ratio.toStringAsFixed(2)}';
  }

  final x = _words(a), y = _words(b);
  final known = {for (final t in knownTerms) ..._words(t)};
  final ops = _align(x, y);
  final gaps = ops.where((o) => o.$1 == null || o.$2 == null).length;
  final allowed = math.max(2, (x.length * 0.1).floor());
  if (gaps > allowed) return '$gaps words added or dropped';

  for (final (from, to) in ops) {
    if (from == null || to == null || from == to) continue;
    final distance = _levenshtein(from, to);
    if (distance > 0.4 * math.max(from.length, to.length) &&
        !known.contains(to)) {
      return '"$from" -> "$to" is not a spelling fix';
    }
  }
  return null;
}

List<String> _words(String text) =>
    normalizeForArtifactMatch(text)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

/// Word alignment as (from, to) pairs; null on one side is an insertion or a
/// deletion. A substitution costs as much as the words differ, so a spelling
/// fix aligns to its original instead of being split into a drop and an add.
List<(String?, String?)> _align(List<String> x, List<String> y) {
  final n = x.length, m = y.length;
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i.toDouble();
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j.toDouble();
  }
  double swap(int i, int j) {
    final p = x[i], q = y[j];
    if (p == q) return 0;
    return 0.5 + _levenshtein(p, q) / math.max(p.length, q.length);
  }

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      cost[i][j] = math.min(
        cost[i - 1][j - 1] + swap(i - 1, j - 1),
        math.min(cost[i - 1][j] + 1, cost[i][j - 1] + 1),
      );
    }
  }

  final ops = <(String?, String?)>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 &&
        j > 0 &&
        cost[i][j] == cost[i - 1][j - 1] + swap(i - 1, j - 1)) {
      ops.add((x[i - 1], y[j - 1]));
      i--;
      j--;
    } else if (i > 0 && cost[i][j] == cost[i - 1][j] + 1) {
      ops.add((x[i - 1], null));
      i--;
    } else {
      ops.add((null, y[j - 1]));
      j--;
    }
  }
  return ops.reversed.toList();
}

int _levenshtein(String s, String t) {
  if (s == t) return 0;
  var prev = List<int>.generate(t.length + 1, (j) => j);
  for (var i = 1; i <= s.length; i++) {
    final curr = List<int>.filled(t.length + 1, 0)..[0] = i;
    for (var j = 1; j <= t.length; j++) {
      curr[j] = math.min(
        prev[j - 1] + (s[i - 1] == t[j - 1] ? 0 : 1),
        math.min(prev[j] + 1, curr[j - 1] + 1),
      );
    }
    prev = curr;
  }
  return prev[t.length];
}
