import 'dart:math' as math;

import '../ai/json_extract.dart';
import '../ai/llm_provider.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import 'lesson_vocabulary.dart';
import 'transcript_sanitizer.dart';

const _systemPrompt = '''
You proofread one chunk of an automatic Czech speech transcript of a school lesson.

Fix only words the speech recognition misheard: names and terms of this subject, wrong diacritics, a word split in two or two words merged at the edge of the chunk. Use the lesson vocabulary to spell them.

Never rephrase, reorder, add, remove, translate or summarise. Keep filler words, repetitions and grammar mistakes the speaker really made. If you are not sure a word is wrong, leave it as it is. Most chunks need no change at all.

Reply with JSON only: {"text": "<the chunk, corrected>"}''';

/// Fixes the words Whisper misheard in a lesson transcript, using the
/// subject's vocabulary.
///
/// The prompt asks for spelling fixes only; [acceptCorrection] makes sure of
/// it, so a model that rewrites a sentence costs the correction, never the
/// transcript.
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
  }) async {
    if (_disabled) return null;
    final terms = [
      for (final t in lesson.terms.take(kCorrectorTermCount)) t.term,
    ];
    final user = [
      if (lesson.subjectName != null) 'Subject: ${lesson.subjectName}',
      if (terms.isNotEmpty) 'Lesson vocabulary: ${terms.join(', ')}',
      if (previous.isNotEmpty) 'Previous chunks: ${previous.join(' ')}',
      if (uncertain) 'The recognizer was unsure about this chunk.',
      'Chunk: $text',
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
        final corrected = extractJsonObject(raw)?['text'];
        if (corrected is! String) return null;
        final verdict = acceptCorrection(text, corrected, knownTerms: terms);
        if (verdict != null) {
          AppLog.d(_tag, 'rejected: $verdict');
          return null;
        }
        return corrected.trim() == text.trim() ? null : corrected.trim();
      } on AiPermanentException catch (e) {
        if (e.statusCode == 404 && _model != fallbackModel) {
          AppLog.d(_tag, '$_model missing, using $fallbackModel');
          _model = fallbackModel;
          continue;
        }
        AppLog.e(_tag, 'disabled for this session: ${e.message}');
        _disabled = true;
        return null;
      } on AiException catch (e) {
        AppLog.d(_tag, 'skipped: ${e.message}');
        return null;
      }
    }
    return null;
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
