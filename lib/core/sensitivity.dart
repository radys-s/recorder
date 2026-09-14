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

  static SensitivityProfile of(MicSensitivity sensitivity) =>
      switch (sensitivity) {
        MicSensitivity.low => low,
        MicSensitivity.medium => medium,
        MicSensitivity.high => high,
      };
}
