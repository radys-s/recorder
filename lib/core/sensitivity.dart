import 'dart:math' as math;

import '../data/db/tables/preferences_table.dart';
import '../stt/whisper_segment_filter.dart';
import 'constants.dart';

/// The concrete thresholds behind one [MicSensitivity] setting.
///
/// A quiet meeting was lost in three separate places, and turning up only one
/// of them moves the loss to the next:
///
///  1. the upload gate — a chunk with too little audio above
///     [voicedRmsThreshold] is never sent to Whisper at all;
///  2. the cut detector — with speech below [silenceRmsThreshold] every frame
///     is "a pause", so chunks are cut at the minimum length mid-word;
///  3. Whisper's own segment scores — quiet speech comes back with a high
///     no-speech probability and is filtered out as silence.
///
/// [MicSensitivity.medium] is exactly what the app did before the setting
/// existed. The ends trade the same thing in opposite directions: `high` hears
/// a quiet room and occasionally transcribes its noise, `low` keeps a loud
/// room's noise out and may miss a quiet voice.
class SensitivityProfile {
  const SensitivityProfile({
    required this.voicedRmsThreshold,
    required this.minVoicedDuration,
    required this.silenceRmsThreshold,
    required this.noSpeechProbThreshold,
    required this.lowAvgLogprobThreshold,
    required this.maxGain,
  });

  /// Normalised frame RMS above which 100 ms could be somebody talking.
  final double voicedRmsThreshold;

  /// Voiced audio a chunk needs before it is uploaded.
  final Duration minVoicedDuration;

  /// Normalised frame RMS below which a frame counts as a pause for cutting.
  final double silenceRmsThreshold;

  /// Whisper segment filter: dropped only when both are exceeded.
  final double noSpeechProbThreshold;
  final double lowAvgLogprobThreshold;

  /// Upper bound on the gain a chunk is raised by before upload; 1 leaves the
  /// audio untouched. Whisper's features are not level-invariant, so a chunk
  /// peaking at -30 dBFS reads to it as far more likely silence than the same
  /// words at -6.
  final double maxGain;

  /// A noisy room: fewer invented sentences, at the cost of a quiet voice.
  static const low = SensitivityProfile(
    voicedRmsThreshold: 0.008, // ~-42 dBFS
    minVoicedDuration: Duration(milliseconds: 600),
    silenceRmsThreshold: 0.015, // ~-36 dBFS
    noSpeechProbThreshold: 0.5,
    lowAvgLogprobThreshold: -0.8,
    maxGain: 1,
  );

  static const medium = SensitivityProfile(
    voicedRmsThreshold: kVoicedRmsThreshold,
    minVoicedDuration: kMinVoicedDuration,
    silenceRmsThreshold: kSilenceRmsThreshold,
    noSpeechProbThreshold: kNoSpeechProbThreshold,
    lowAvgLogprobThreshold: kLowAvgLogprobThreshold,
    maxGain: 1,
  );

  /// A quiet meeting, or a speaker far from the phone.
  ///
  /// The voiced threshold stays just above a quiet room's noise floor
  /// (~-56 dBFS on a phone microphone); below that, every chunk of room tone
  /// would be uploaded and the hallucination guard would be all that stood
  /// between the user and invented text.
  static const high = SensitivityProfile(
    voicedRmsThreshold: 0.002, // ~-54 dBFS
    minVoicedDuration: Duration(milliseconds: 200),
    silenceRmsThreshold: 0.004, // ~-48 dBFS
    noSpeechProbThreshold: 0.8,
    lowAvgLogprobThreshold: -1.2,
    maxGain: 8, // +18 dB
  );

  /// [MicSensitivity.auto] before the room has been measured, and what the
  /// Whisper filter uses for it: a little more trusting than [medium], since
  /// the thresholds in front of the filter already follow the room.
  static const auto = SensitivityProfile(
    voicedRmsThreshold: 0.003,
    minVoicedDuration: Duration(milliseconds: 250),
    silenceRmsThreshold: 0.007,
    noSpeechProbThreshold: 0.7,
    lowAvgLogprobThreshold: -1.1,
    maxGain: kAutoMaxGain,
  );

  static SensitivityProfile of(MicSensitivity sensitivity) =>
      switch (sensitivity) {
        MicSensitivity.low => low,
        MicSensitivity.medium => medium,
        MicSensitivity.high => high,
        MicSensitivity.auto => auto,
      };

  @override
  String toString() => 'voiced ${voicedRmsThreshold.toStringAsFixed(4)}, '
      'silence ${silenceRmsThreshold.toStringAsFixed(4)}, '
      'min ${minVoicedDuration.inMilliseconds}ms, '
      'gain ×${maxGain.toStringAsFixed(1)}';
}

/// Sets the thresholds for [MicSensitivity.auto] from what the microphone
/// actually hears.
///
/// Fed every frame's level. The first estimate comes after [warmup], then a
/// fresh one after each further [window], always over the last [window] of
/// audio — so a room that fills up or empties mid-lesson is followed.
///
/// The quiet end of the levels (20th percentile) is the room; the loud end
/// (90th) is the speaker. Thresholds sit a fixed ratio above the room and
/// inside the range between [SensitivityProfile.high] and
/// [SensitivityProfile.low], so a bad estimate can never be worse than one of
/// the manual settings.
class AutoCalibrator {
  AutoCalibrator({
    Duration frameDuration = kSilenceFrameDuration,
    Duration warmup = kCalibrationWarmup,
    Duration window = kCalibrationWindow,
  })  : _warmupFrames = warmup.inMilliseconds ~/ frameDuration.inMilliseconds,
        _windowFrames = window.inMilliseconds ~/ frameDuration.inMilliseconds;

  final int _warmupFrames;
  final int _windowFrames;
  final List<double> _levels = [];
  int _frames = 0;

  /// The newest estimate, or null before the warm-up is over.
  SensitivityProfile? latest;

  /// Returns a new profile when one is due, else null.
  SensitivityProfile? add(double rms) {
    _levels.add(rms);
    if (_levels.length > _windowFrames) _levels.removeAt(0);
    _frames++;
    final due = _frames == _warmupFrames ||
        (_frames > _warmupFrames &&
            (_frames - _warmupFrames) % _windowFrames == 0);
    if (!due) return null;
    return latest = profileFor(_levels);
  }

  static SensitivityProfile profileFor(List<double> levels) {
    if (levels.isEmpty) return SensitivityProfile.auto;
    final sorted = [...levels]..sort();
    double percentile(double q) =>
        sorted[((sorted.length - 1) * q).round()];
    final floor = percentile(0.2);

    final voiced = (floor * 2).clamp(0.002, 0.008);
    final silence =
        (floor * 3.5 > voiced * 1.5 ? floor * 3.5 : voiced * 1.5)
            .clamp(0.004, 0.015);
    // 0 in a silent room, 1 in a noisy one.
    final noise = ((floor - 0.001) / 0.005).clamp(0.0, 1.0);

    return SensitivityProfile(
      voicedRmsThreshold: voiced,
      minVoicedDuration: Duration(milliseconds: (200 + 400 * noise).round()),
      silenceRmsThreshold: silence,
      noSpeechProbThreshold: 0.8 - 0.3 * noise,
      lowAvgLogprobThreshold: -1.2 + 0.4 * noise,
      // The gain itself is measured per chunk on its voiced frames (see
      // `speechGain`), so the room only has to set the ceiling.
      maxGain: kAutoMaxGain,
    );
  }
}


/// How far the speaking voice stands out from the room, measured while
/// recording.
///
/// Both numbers come from the same rolling window of frame levels the
/// calibrator uses: the 20th percentile is the room with nobody talking, the
/// 90th is the loudest speech in it, and their ratio in decibels is what
/// decides whether Whisper has anything to work with. It is deliberately
/// independent of the sensitivity setting — a manual setting does not make a
/// distant teacher any louder.
class SignalQualityTracker {
  SignalQualityTracker({
    Duration frameDuration = kSilenceFrameDuration,
    Duration window = kCalibrationWindow,
    Duration interval = kSignalQualityInterval,
    this.patience = kWeakSignalPatience,
  })  : _frameMs = frameDuration.inMilliseconds,
        _windowFrames = window.inMilliseconds ~/ frameDuration.inMilliseconds,
        _intervalFrames =
            interval.inMilliseconds ~/ frameDuration.inMilliseconds;

  final int _frameMs;
  final int _windowFrames;
  final int _intervalFrames;

  /// How long the signal has to stay weak before it is worth saying so.
  final Duration patience;

  final List<double> _levels = [];
  int _frames = 0;
  int _weakMs = 0;

  /// Speech above the room noise in dB, or null before the first full window.
  double? snrDb;

  /// True once the signal has been weak for [patience] without recovering.
  bool weak = false;

  /// Feeds one frame; returns true when [weak] changed and the UI should say
  /// something.
  bool add(double rms) {
    _levels.add(rms);
    if (_levels.length > _windowFrames) _levels.removeAt(0);
    _frames++;
    if (_levels.length < _windowFrames || _frames % _intervalFrames != 0) {
      return false;
    }

    final snr = snrFor(_levels);
    snrDb = snr;
    if (snr == null) return false;

    final was = weak;
    if (snr >= kGoodSignalSnrDb) {
      _weakMs = 0;
      weak = false;
    } else if (snr < kWeakSignalSnrDb) {
      _weakMs += _intervalFrames * _frameMs;
      if (_weakMs >= patience.inMilliseconds) weak = true;
    }
    // Between the two thresholds nothing moves: that is the hysteresis.
    return weak != was;
  }

  /// Speech level over noise floor in dB, or null when the room is silent
  /// enough that the ratio would be meaningless.
  static double? snrFor(List<double> levels) {
    if (levels.isEmpty) return null;
    final sorted = [...levels]..sort();
    double percentile(double q) => sorted[((sorted.length - 1) * q).round()];
    final floor = percentile(0.2);
    final speech = percentile(0.9);
    // Digital silence: nothing was recorded at all, which is a different
    // problem and not one a nearer phone would fix.
    if (speech <= 0) return null;
    // A perfectly quiet floor would divide by zero; -80 dBFS stands in for it.
    final base = floor <= 0.0001 ? 0.0001 : floor;
    return 20 * (math.log(speech / base) / math.ln10);
  }
}
