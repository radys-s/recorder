/// Drops the parts of a Whisper response that Whisper itself flags as unlikely
/// to be speech.
///
/// `verbose_json` returns, per segment, three numbers Whisper computes anyway:
///
///   * `no_speech_prob` — how likely the segment's audio holds no speech,
///   * `avg_logprob` — how confident the decoder was in the words it chose,
///   * `compression_ratio` — how repetitive the text is; a decoder stuck in a
///     loop ("a pak a pak a pak…") compresses far better than language does.
///
/// The thresholds are the ones OpenAI's own reference implementation uses to
/// decide a segment is silence or a runaway loop. A segment that is only
/// *probably* silent but was decoded confidently is kept: that is a quiet
/// speaker, not a hallucination.
///
/// This complements [sanitizeTranscript] rather than replacing it. The
/// sanitizer knows the specific sentences Whisper invents over silence; this
/// catches the ones nobody has listed yet, by asking the model how sure it was.
library;

const double kNoSpeechProbThreshold = 0.6;
const double kLowAvgLogprobThreshold = -1.0;
const double kMaxCompressionRatio = 2.4;

/// Below this mean `avg_logprob` a transcript is shown as uncertain.
const double kLowConfidenceLogprob = -0.9;

/// Below this the transcript is too doubtful to trigger an automatic answer.
const double kVeryLowConfidenceLogprob = -1.3;

/// Result of filtering one response's segments.
class WhisperSegmentFilterResult {
  const WhisperSegmentFilterResult({
    required this.text,
    required this.total,
    required this.dropped,
    this.confidence,
  });

  /// Duration-weighted mean `avg_logprob` of the kept segments; null when no
  /// kept segment reported one.
  final double? confidence;

  /// The kept segments' text, joined. Only meaningful when [dropped] > 0 —
  /// otherwise the response's own `text` should be used unchanged.
  final String text;
  final int total;
  final int dropped;
}

/// Filters the `segments` array of a `verbose_json` response.
///
/// Returns null when there is nothing to filter on — no `segments` field, or
/// one in a shape this does not recognise — so the caller keeps the plain
/// `text`. A segment missing one of the metrics is kept: an unknown is never a
/// reason to delete what might be real speech.
///
/// The two no-speech thresholds default to OpenAI's and are raised by the
/// sensitivity setting, since quiet real speech is scored as probable silence.
WhisperSegmentFilterResult? filterWhisperSegments(
  Object? segments, {
  double noSpeechProbThreshold = kNoSpeechProbThreshold,
  double lowAvgLogprobThreshold = kLowAvgLogprobThreshold,
}) {
  if (segments is! List || segments.isEmpty) return null;

  final kept = <String>[];
  var dropped = 0;
  var weightedLogprob = 0.0;
  var weight = 0.0;

  for (final segment in segments) {
    if (segment is! Map) return null;
    final text = segment['text'];
    if (text is! String) return null;

    if (isLikelyHallucinatedSegment(
      noSpeechProb: _num(segment['no_speech_prob']),
      avgLogprob: _num(segment['avg_logprob']),
      compressionRatio: _num(segment['compression_ratio']),
      noSpeechProbThreshold: noSpeechProbThreshold,
      lowAvgLogprobThreshold: lowAvgLogprobThreshold,
    )) {
      dropped++;
      continue;
    }

    final trimmed = text.trim();
    if (trimmed.isNotEmpty) kept.add(trimmed);
    final logprob = _num(segment['avg_logprob']);
    if (trimmed.isNotEmpty && logprob != null) {
      final start = _num(segment['start']);
      final end = _num(segment['end']);
      // Without timings every segment counts the same.
      final span = start != null && end != null && end > start
          ? end - start
          : 1.0;
      weightedLogprob += logprob * span;
      weight += span;
    }
  }

  return WhisperSegmentFilterResult(
    text: kept.join(' '),
    total: segments.length,
    dropped: dropped,
    confidence: weight > 0 ? weightedLogprob / weight : null,
  );
}

/// The transcript should be shown as uncertain.
bool isLowConfidence(double? confidence) =>
    confidence != null && confidence < kLowConfidenceLogprob;

/// The transcript is too doubtful to answer from without being asked.
bool isVeryLowConfidence(double? confidence) =>
    confidence != null && confidence < kVeryLowConfidenceLogprob;

/// The decision for one segment, exposed for the tests.
bool isLikelyHallucinatedSegment({
  double? noSpeechProb,
  double? avgLogprob,
  double? compressionRatio,
  double noSpeechProbThreshold = kNoSpeechProbThreshold,
  double lowAvgLogprobThreshold = kLowAvgLogprobThreshold,
}) {
  if (compressionRatio != null && compressionRatio > kMaxCompressionRatio) {
    return true;
  }
  return noSpeechProb != null &&
      avgLogprob != null &&
      noSpeechProb > noSpeechProbThreshold &&
      avgLogprob < lowAvgLogprobThreshold;
}

double? _num(Object? value) => value is num ? value.toDouble() : null;
