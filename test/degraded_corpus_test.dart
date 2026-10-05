import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_intent.dart';
import 'package:recorder/ai/photo_questions.dart';
import 'package:recorder/ai/question_detector.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';

import 'fixtures/degrade.dart';
import 'fixtures/lesson_corpus.dart';

/// What a worse speech recogniser does to the question detector.
///
/// The real recogniser cannot run here (the keys are on the phone), so the
/// transcript is degraded the way a bad one writes it — no question mark, no
/// capitals, no diacritics, fillers, swallowed words — and the detector is
/// measured on every variant. The matrix is printed so a regression shows as a
/// number, not just a red test; the asserted floors are what the app needs to
/// stay usable, and a failing case is a detector bug to fix, not a floor to
/// lower.
void main() {
  const seeds = [1, 2, 3, 4, 5];

  Iterable<String> texts(Kind kind) =>
      kLessonCorpus.where((s) => s.$2 == kind).map((s) => s.$1);

  /// Share of [kind] sentences, degraded by [variant] over every seed, for
  /// which [hit] is true.
  double rate(Kind kind, String variant, bool Function(String text) hit) {
    var hits = 0;
    var total = 0;
    for (final seed in seeds) {
      final degrade = Degrader(seed).variants[variant]!;
      for (final t in texts(kind)) {
        total++;
        if (hit(degrade(t))) hits++;
      }
    }
    return hits / total;
  }

  final variants = Degrader(0).variants.keys.toList();

  test('corpus is big enough and every kind is represented', () {
    expect(kLessonCorpus.length, greaterThanOrEqualTo(200));
    for (final kind in Kind.values) {
      expect(texts(kind), isNotEmpty, reason: '$kind');
    }
    final unique = kLessonCorpus.map((s) => s.$1).toSet();
    expect(unique.length, kLessonCorpus.length, reason: 'duplicate sentence');
  });

  test('detector matrix over every degraded variant', () {
    final rows = StringBuffer()
      ..writeln(
        '${'variant'.padRight(18)}'
        'přímé  nepřímé  řečnické*  věty(FP)  past(FP)  past*(FP)',
      );
    final result = <String, List<double>>{};
    for (final v in variants) {
      final r = [
        rate(Kind.direct, v, looksLikeQuestion),
        rate(Kind.indirect, v, looksLikeQuestion),
        rate(
          Kind.rhetorical,
          v,
          (t) => looksLikeQuestion(t, endedOnPause: true),
        ),
        rate(Kind.statement, v, looksLikeQuestion),
        rate(Kind.hardNegative, v, looksLikeQuestion),
        rate(
          Kind.hardNegative,
          v,
          (t) => looksLikeQuestion(t, endedOnPause: true),
        ),
      ];
      result[v] = r;
      rows.writeln(
        v.padRight(18) +
            r.map((x) => '${(x * 100).round()}%'.padRight(10)).join(),
      );
    }
    // ignore: avoid_print
    print(rows);

    // Floors on the clean and the mildly degraded text.
    expect(result['čistý']![0], greaterThanOrEqualTo(0.97));
    expect(result['čistý']![1], greaterThanOrEqualTo(0.9));
    expect(result['čistý']![2], greaterThanOrEqualTo(0.8));
    expect(result['? → .']![0], greaterThanOrEqualTo(0.9));
    expect(result['bez interpunkce']![0], greaterThanOrEqualTo(0.85));
    expect(result['vše dohromady']![0], greaterThanOrEqualTo(0.85));
    expect(result['vše dohromady']![1], greaterThanOrEqualTo(0.75));
    expect(result['nejhorší']![0], greaterThanOrEqualTo(0.7));
    // Ceilings on false positives: statements and hard negatives, no pause.
    for (final v in variants) {
      expect(result[v]![3], lessThanOrEqualTo(0.08), reason: 'věty $v');
      expect(result[v]![4], lessThanOrEqualTo(0.12), reason: 'past $v');
    }
  });

  test('chat intent over the corpus, while recording', () {
    for (final kind in [Kind.direct, Kind.indirect, Kind.request]) {
      for (final t in texts(kind)) {
        final intent = detectChatIntent(t, recording: true);
        expect(intent, ChatIntent.question, reason: '$kind "$t" -> $intent');
      }
    }
    final misses = <String>[];
    for (final kind in [Kind.statement]) {
      for (final t in texts(kind)) {
        final intent = detectChatIntent(t, recording: true);
        if (intent == ChatIntent.question) misses.add(t);
      }
    }
    expect(
      misses.length / texts(Kind.statement).length,
      lessThan(0.08),
      reason: '$misses',
    );
  });

  test('chat intent after the lesson treats everything as a question', () {
    for (final t in texts(Kind.statement)) {
      expect(detectChatIntent(t, recording: false), ChatIntent.question);
    }
  });

  test('photo questions found in a worksheet however it was written', () {
    final worksheet = [for (final t in texts(Kind.direct).take(6)) t];
    for (final v in ['čistý', '? → .', 'vše dohromady']) {
      final degrade = Degrader(7).variants[v]!;
      final lines = [
        for (var i = 0; i < worksheet.length; i++)
          '${i + 1}) ${degrade(worksheet[i])}',
      ];
      final found = extractQuestions(lines.join('\n'));
      expect(found.length, greaterThanOrEqualTo(4), reason: '$v -> $found');
    }
  });
}
