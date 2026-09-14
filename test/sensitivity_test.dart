import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_chunker.dart';
import 'package:recorder/audio/pcm_gain.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/sensitivity.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/stt/whisper_segment_filter.dart';

/// Alternating ±[amplitude] PCM16, so the RMS is exactly amplitude / 32768.
Uint8List _pcm({required int ms, required int amplitude}) {
  final samples = kSampleRateHz * ms ~/ 1000;
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

int _peak(List<Uint8List> frames) {
  var peak = 0;
  for (final frame in frames) {
    final data = ByteData.sublistView(frame);
    for (var i = 0; i + 1 < frame.length; i += 2) {
      final s = data.getInt16(i, Endian.little).abs();
      if (s > peak) peak = s;
    }
  }
  return peak;
}

int _voicedMs(SensitivityProfile profile, Uint8List pcm) {
  final chunks = <PcmChunk>[];
  PcmChunker(
    onChunk: chunks.add,
    voicedRmsThreshold: profile.voicedRmsThreshold,
    silenceRmsThreshold: profile.silenceRmsThreshold,
  )
    ..addBytes(pcm)
    ..flush();
  return chunks.single.voicedMs;
}

void main() {
  group('SensitivityProfile', () {
    test('medium is exactly the behaviour before the setting existed', () {
      const m = SensitivityProfile.medium;
      expect(m.voicedRmsThreshold, kVoicedRmsThreshold);
      expect(m.silenceRmsThreshold, kSilenceRmsThreshold);
      expect(m.minVoicedDuration, kMinVoicedDuration);
      expect(m.noSpeechProbThreshold, kNoSpeechProbThreshold);
      expect(m.lowAvgLogprobThreshold, kLowAvgLogprobThreshold);
      expect(m.maxGain, 1);
    });

    test('maps every setting, and the steps move in one direction', () {
      expect(SensitivityProfile.of(MicSensitivity.low), SensitivityProfile.low);
      expect(SensitivityProfile.of(MicSensitivity.medium),
          SensitivityProfile.medium);
      expect(
          SensitivityProfile.of(MicSensitivity.high), SensitivityProfile.high);

      const l = SensitivityProfile.low;
      const m = SensitivityProfile.medium;
      const h = SensitivityProfile.high;
      expect(l.voicedRmsThreshold, greaterThan(m.voicedRmsThreshold));
      expect(m.voicedRmsThreshold, greaterThan(h.voicedRmsThreshold));
      expect(l.silenceRmsThreshold, greaterThan(m.silenceRmsThreshold));
      expect(m.silenceRmsThreshold, greaterThan(h.silenceRmsThreshold));
      expect(l.minVoicedDuration, greaterThan(m.minVoicedDuration));
      expect(m.minVoicedDuration, greaterThan(h.minVoicedDuration));
      expect(l.noSpeechProbThreshold, lessThan(m.noSpeechProbThreshold));
      expect(m.noSpeechProbThreshold, lessThan(h.noSpeechProbThreshold));
      expect(h.maxGain, greaterThan(1));
      expect(l.maxGain, 1);
    });

    test('labels are the three Czech words from the request', () {
      expect(MicSensitivity.values.map((s) => s.label),
          ['Málo', 'Středně', 'Hodně']);
    });
  });

  group('chunker thresholds', () {
    // ~-50 dBFS: a quiet speaker across the table.
    final quiet = _pcm(ms: 2000, amplitude: 100);
    // ~-44 dBFS: normal speech a little way off.
    final moderate = _pcm(ms: 2000, amplitude: 200);

    test('quiet speech counts as voiced only on high', () {
      expect(_voicedMs(SensitivityProfile.low, quiet), 0);
      expect(_voicedMs(SensitivityProfile.medium, quiet), 0);
      expect(_voicedMs(SensitivityProfile.high, quiet), 2000);
    });

    test('low ignores what medium still hears', () {
      expect(_voicedMs(SensitivityProfile.low, moderate), 0);
      expect(_voicedMs(SensitivityProfile.medium, moderate), 2000);
    });

    test('a threshold changed mid-recording applies from the next frame', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(onChunk: chunks.add)
        ..addBytes(_pcm(ms: 1000, amplitude: 100));
      chunker
        ..voicedRmsThreshold = SensitivityProfile.high.voicedRmsThreshold
        ..addBytes(_pcm(ms: 1000, amplitude: 100))
        ..flush();
      expect(chunks.single.voicedMs, 1000);
    });

    test('quiet speech is not cut up as one long pause on high', () {
      final chunks = <PcmChunk>[];
      PcmChunker(
        onChunk: chunks.add,
        silenceRmsThreshold: SensitivityProfile.high.silenceRmsThreshold,
      )
        ..addBytes(_pcm(ms: 20000, amplitude: 200))
        ..flush();
      // Never silent, so nothing before the 30 s hard cap: one chunk.
      expect(chunks, hasLength(1));
    });
  });

  group('normalizingGain / applyGain', () {
    test('no gain allowed, or silence, leaves the audio alone', () {
      final quiet = [_pcm(ms: 100, amplitude: 500)];
      expect(normalizingGain(quiet, maxGain: 1), 1);
      expect(normalizingGain([Uint8List(3200)], maxGain: 8), 1);
      expect(identical(applyGain(quiet, 1), quiet), isTrue);
    });

    test('quiet audio is raised by at most maxGain', () {
      final frames = [_pcm(ms: 100, amplitude: 1000)];
      final gain = normalizingGain(frames, maxGain: 8);
      expect(gain, 8);
      expect(_peak(applyGain(frames, gain)), 8000);
    });

    test('never lifts the peak past the target, so it cannot clip', () {
      final frames = [_pcm(ms: 100, amplitude: 4000)];
      final gain = normalizingGain(frames, maxGain: 8);
      expect(gain, lessThan(8));
      final peak = _peak(applyGain(frames, gain));
      expect(peak, lessThanOrEqualTo((kNormalizePeakTarget * 32767).round()));
      expect(peak, greaterThan(28000));
    });

    test('audio already near full scale is not worth touching', () {
      expect(normalizingGain([_pcm(ms: 100, amplitude: 30000)], maxGain: 8), 1);
      final extreme = ByteData(4)
        ..setInt16(0, -32768, Endian.little)
        ..setInt16(2, 32767, Endian.little);
      expect(normalizingGain([extreme.buffer.asUint8List()], maxGain: 8), 1);
    });

    test('the one loud sample decides, across frames', () {
      final frames = [
        _pcm(ms: 100, amplitude: 500),
        _pcm(ms: 100, amplitude: 16000),
      ];
      final gain = normalizingGain(frames, maxGain: 8);
      expect(gain, closeTo(kNormalizePeakTarget * 32767 / 16000, 1e-9));
    });

    test('input is not modified and a dangling odd byte is kept', () {
      final frame = Uint8List.fromList([..._pcm(ms: 1, amplitude: 1000), 7]);
      final before = Uint8List.fromList(frame);
      final out = applyGain([frame], 4).single;
      expect(frame, before);
      expect(out.length, frame.length);
      expect(out.last, 7);
      expect(ByteData.sublistView(out).getInt16(0, Endian.little), 4000);
    });
  });

  group('Whisper filter thresholds', () {
    final quietSegment = [
      {
        'text': ' Tak to stihneme do pátku.',
        'no_speech_prob': 0.7,
        'avg_logprob': -1.1,
        'compression_ratio': 1.3,
      },
    ];

    test('a quiet but real segment is dropped on medium, kept on high', () {
      expect(filterWhisperSegments(quietSegment)!.dropped, 1);

      const h = SensitivityProfile.high;
      final kept = filterWhisperSegments(
        quietSegment,
        noSpeechProbThreshold: h.noSpeechProbThreshold,
        lowAvgLogprobThreshold: h.lowAvgLogprobThreshold,
      )!;
      expect(kept.dropped, 0);
      expect(kept.text, 'Tak to stihneme do pátku.');
    });

    test('a decoding loop is dropped whatever the sensitivity', () {
      const h = SensitivityProfile.high;
      final loop = filterWhisperSegments(
        [
          {
            'text': 'a pak a pak a pak a pak',
            'no_speech_prob': 0.1,
            'avg_logprob': -0.2,
            'compression_ratio': 3.1,
          },
        ],
        noSpeechProbThreshold: h.noSpeechProbThreshold,
        lowAvgLogprobThreshold: h.lowAvgLogprobThreshold,
      )!;
      expect(loop.dropped, 1);
    });

    test('low drops a borderline segment medium keeps', () {
      const l = SensitivityProfile.low;
      final borderline = [
        {
          'text': 'Hm.',
          'no_speech_prob': 0.55,
          'avg_logprob': -0.9,
          'compression_ratio': 1.0,
        },
      ];
      expect(filterWhisperSegments(borderline)!.dropped, 0);
      expect(
        filterWhisperSegments(
          borderline,
          noSpeechProbThreshold: l.noSpeechProbThreshold,
          lowAvgLogprobThreshold: l.lowAvgLogprobThreshold,
        )!
            .dropped,
        1,
      );
    });
  });
}
