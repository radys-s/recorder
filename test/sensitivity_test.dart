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

    test('labels, with automatic appended in storage and shown first', () {
      expect(MicSensitivity.values.map((s) => s.label),
          ['Málo', 'Středně', 'Hodně', 'Automaticky']);
      expect(MicSensitivity.ordered.first, MicSensitivity.auto);
      expect(MicSensitivity.ordered.toSet(), MicSensitivity.values.toSet());
      expect(SensitivityProfile.of(MicSensitivity.auto),
          SensitivityProfile.auto);
    });
  });

  group('AutoCalibrator', () {
    const warmupFrames = 30; // 3 s of 100 ms frames
    const windowFrames = 200;

    AutoCalibrator feed(Iterable<double> levels, List<SensitivityProfile> out) {
      final c = AutoCalibrator();
      for (final l in levels) {
        final p = c.add(l);
        if (p != null) out.add(p);
      }
      return c;
    }

    test('nothing before the warm-up, then one estimate per window', () {
      final out = <SensitivityProfile>[];
      final c = feed(List.filled(warmupFrames - 1, 0.001), out);
      expect(out, isEmpty);
      expect(c.latest, isNull);
      c.add(0.001);
      expect(c.latest, isNotNull);
      for (var i = 0; i < windowFrames - 1; i++) {
        expect(c.add(0.001), isNull);
      }
      expect(c.add(0.001), isNotNull);
    });

    test('a quiet room with a distant speaker gets high-like thresholds', () {
      // 80 % room tone at -60 dBFS, 20 % speech at -40 dBFS.
      final levels = [
        for (var i = 0; i < 30; i++) i % 5 == 0 ? 0.01 : 0.001,
      ];
      final p = AutoCalibrator.profileFor(levels);
      expect(p.voicedRmsThreshold, SensitivityProfile.high.voicedRmsThreshold);
      expect(p.silenceRmsThreshold, 0.004);
      expect(p.maxGain, kAutoMaxGain);
      expect(p.noSpeechProbThreshold, closeTo(0.8, 1e-9));
    });

    test('a noisy classroom gets low-like thresholds', () {
      final levels = [
        for (var i = 0; i < 30; i++) i % 3 == 0 ? 0.2 : 0.012,
      ];
      final p = AutoCalibrator.profileFor(levels);
      expect(p.voicedRmsThreshold, SensitivityProfile.low.voicedRmsThreshold);
      expect(p.silenceRmsThreshold, SensitivityProfile.low.silenceRmsThreshold);
      // The ceiling is fixed; loud speech simply measures as needing no gain.
      expect(p.maxGain, kAutoMaxGain);
      expect(p.minVoicedDuration, const Duration(milliseconds: 600));
    });

    test('silence always sits above voiced, whatever the room', () {
      for (final floor in [0.0, 0.0005, 0.002, 0.004, 0.02, 0.5]) {
        final p = AutoCalibrator.profileFor(List.filled(30, floor));
        expect(p.silenceRmsThreshold, greaterThan(p.voicedRmsThreshold),
            reason: 'floor $floor');
      }
    });

    test('follows the room when it gets louder', () {
      final out = <SensitivityProfile>[];
      feed([
        ...List.filled(warmupFrames, 0.001),
        ...List.filled(windowFrames, 0.012),
      ], out);
      expect(out, hasLength(2));
      expect(out.last.voicedRmsThreshold,
          greaterThan(out.first.voicedRmsThreshold));
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

  group('speechGain / applyGain', () {
    List<bool> all(int n, [bool v = true]) => List.filled(n, v);

    test('no gain allowed, silence or no voiced frame leaves the audio alone',
        () {
      final quiet = [_pcm(ms: 100, amplitude: 500)];
      expect(speechGain(quiet, all(1), maxGain: 1), 1);
      expect(speechGain([Uint8List(3200)], all(1), maxGain: 16), 1);
      expect(speechGain(quiet, all(1, false), maxGain: 16), 1);
      expect(speechGain(quiet, const [], maxGain: 16), 1);
      expect(identical(applyGain(quiet, 1), quiet), isTrue);
    });

    test('quiet voiced speech is raised to the loudness target', () {
      // RMS 1000/32768 ≈ 0.0305 → gain ≈ 3.28 to reach 0.1.
      final frames = [_pcm(ms: 100, amplitude: 1000)];
      final gain = speechGain(frames, all(1), maxGain: 16);
      expect(gain, closeTo(kSpeechRmsTarget * 32768 / 1000, 1e-6));
      expect(_peak(applyGain(frames, gain)), closeTo(3277, 2));
    });

    test('a very distant voice is capped at maxGain', () {
      final frames = [_pcm(ms: 100, amplitude: 50)];
      expect(speechGain(frames, all(1), maxGain: 16), 16);
    });

    test('one loud spike no longer vetoes the gain', () {
      final frames = [
        for (var i = 0; i < 20; i++) _pcm(ms: 100, amplitude: 800),
        _pcm(ms: 100, amplitude: 30000),
      ];
      final gain = speechGain(frames, all(frames.length), maxGain: 16);
      // Peak-based gain would have been ~1; the median level ignores the spike.
      expect(gain, closeTo(kSpeechRmsTarget * 32768 / 800, 1e-6));
      final out = applyGain(frames, gain);
      expect(_peak(out), lessThanOrEqualTo(32767));
    });

    test('pauses do not drag the level down and over-amplify', () {
      final frames = [
        _pcm(ms: 100, amplitude: 2000),
        _pcm(ms: 100, amplitude: 30),
        _pcm(ms: 100, amplitude: 30),
      ];
      final voicedOnly = speechGain(frames, [true, false, false], maxGain: 16);
      expect(voicedOnly, closeTo(kSpeechRmsTarget * 32768 / 2000, 1e-6));
    });

    test('loud speech needs no gain', () {
      expect(speechGain([_pcm(ms: 100, amplitude: 8000)], all(1), maxGain: 16),
          1);
    });

    test('the soft limiter never exceeds Int16 and leaves quiet samples alone',
        () {
      final extreme = ByteData(4)
        ..setInt16(0, -32768, Endian.little)
        ..setInt16(2, 32767, Endian.little);
      final out = ByteData.sublistView(
          applyGain([extreme.buffer.asUint8List()], 16).single);
      expect(out.getInt16(0, Endian.little), greaterThanOrEqualTo(-32768));
      expect(out.getInt16(2, Endian.little), lessThanOrEqualTo(32767));
      expect(out.getInt16(2, Endian.little), greaterThan(30000));

      expect(softLimit(0.5), 0.5);
      expect(softLimit(-0.5), -0.5);
      expect(softLimit(3), lessThan(1));
      expect(softLimit(0.71), greaterThan(0.7));
      expect(softLimit(-3), greaterThan(-1));
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
