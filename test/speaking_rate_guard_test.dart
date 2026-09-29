import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_chunker.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/stt/groq_whisper_stt_provider.dart';
import 'package:recorder/stt/transcript_sanitizer.dart';

Uint8List _pcm({required int ms, required int amplitude}) {
  final data = ByteData(ms * 32);
  for (var i = 0; i < ms * 16; i++) {
    data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('limitToSpeakingRate', () {
    test('normal speech passes untouched', () {
      // 10 s chunk, 8 s voiced: allowance 30 + 160 + 20 = 210 chars.
      const text = 'Dneska si probereme realismus. Hlavní autorkou je Božena '
          'Němcová a její Babička vyšla v roce 1855.';
      expect(limitToSpeakingRate(text, voicedMs: 8000, durationMs: 10000),
          text);
    });

    test('an invented tail over a mostly silent chunk is cut by sentence', () {
      // 13 s chunk, 1 s voiced: allowance 30 + 20 + 120 = 170 chars.
      final text = 'Tak jo. ${'Děkujeme, že jste sledovali tento díl. ' * 6}';
      final out = limitToSpeakingRate(text, voicedMs: 1000, durationMs: 13000);
      expect(out.length, lessThanOrEqualTo(170));
      expect(out, startsWith('Tak jo.'));
      expect(out, endsWith('.'));
    });

    test('a single overlong sentence is cut at a word boundary', () {
      final text = List.filled(60, 'slovo').join(' ');
      final out = limitToSpeakingRate(text, voicedMs: 0, durationMs: 1000);
      expect(out.length, lessThanOrEqualTo(40));
      expect(out.split(' ').every((w) => w == 'slovo'), isTrue);
    });

    test('a chunk with speech in a tenth of it or more is never cut', () {
      // 10 s chunk, 1 s voiced (exactly 10 %): far over the allowance, yet a
      // quiet teacher under-counted by the gate must keep every word.
      final text = List.filled(60, 'slovo').join(' ');
      expect(limitToSpeakingRate(text, voicedMs: 1000, durationMs: 10000),
          text);
      // Just under 10 %: the guard is back on.
      expect(
        limitToSpeakingRate(text, voicedMs: 999, durationMs: 10000).length,
        lessThan(text.length),
      );
    });

    test('unknown voiced time disables the check', () {
      final text = 'a' * 5000;
      expect(limitToSpeakingRate(text, voicedMs: null, durationMs: 1000), text);
    });
  });

  group('collapseRepeats', () {
    test('a decoding loop keeps one occurrence', () {
      expect(
        collapseRepeats('A pak jsme a pak jsme a pak jsme a pak jsme odešli.'),
        'A pak jsme odešli.',
      );
    });

    test('the shortest period wins', () {
      expect(collapseRepeats('ano ne ano ne ano ne ano ne konec tady'),
          'ano ne konec tady');
    });

    test('two repeats and single-word doubling are real speech', () {
      const twice = 'to je dobré to je dobré a hotovo';
      expect(collapseRepeats(twice), twice);
      const words = 'velmi velmi velmi dobře řečeno, opravdu';
      expect(collapseRepeats(words), words);
    });

    test('text without repeats is returned identical', () {
      const text = 'Babička je próza z venkovského prostředí.';
      expect(identical(collapseRepeats(text), text), isTrue);
    });
  });

  group('PcmChunk.voicedFrames', () {
    test('flags line up with frames and survive a cut, gapless', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(
        onChunk: chunks.add,
        minDuration: kFastChunkMinDuration,
        targetDuration: kFastChunkTargetDuration,
        hardCapDuration: kFastChunkHardCapDuration,
      );
      chunker.addBytes(_pcm(ms: 9000, amplitude: 3000));
      chunker.addBytes(_pcm(ms: 1000, amplitude: 0));
      chunker.addBytes(_pcm(ms: 25000, amplitude: 3000));
      chunker.flush();

      expect(chunks.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < chunks.length; i++) {
        final c = chunks[i];
        expect(c.voicedFrames.length, c.frames.length);
        expect(c.voicedFrames.where((v) => v).length * 100, c.voicedMs);
        if (i > 0) expect(c.startMs, chunks[i - 1].endMs);
      }
      final bytes = chunks.fold<int>(0, (s, c) => s + c.byteLength);
      expect(bytes, 35000 * 32);
      // The first chunk closes on the pause, not before the fast minimum.
      expect(chunks.first.endMs, greaterThanOrEqualTo(8000));
    });
  });

  group('whisperPrompt length', () {
    test('keeps a 320-char tail and trims the glossary first', () {
      final tail = 'x' * 1000;
      final glossary = List.generate(80, (i) => 'Pojem$i').join(', ');
      final prompt = GroqWhisperSttProvider.whisperPrompt(
          glossary: glossary, context: tail)!;
      expect(prompt, endsWith('x' * 320));
      expect(prompt.length, lessThanOrEqualTo(620));
      expect(prompt, startsWith('Pojem0, Pojem1'));
      expect(prompt, isNot(contains(', .')));
    });
  });
}
