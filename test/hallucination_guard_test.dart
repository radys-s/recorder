import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/grounding.dart';
import 'package:recorder/audio/pcm_chunker.dart';
import 'package:recorder/stt/transcript_sanitizer.dart';
import 'package:recorder/stt/whisper_segment_filter.dart';

Uint8List _pcm({required int ms, required int amplitude}) {
  final bytes = Uint8List(ms * 32);
  for (var i = 0; i < bytes.length ~/ 2; i++) {
    final sample = i.isEven ? amplitude : -amplitude;
    final unsigned = sample < 0 ? sample + 0x10000 : sample;
    bytes[i * 2] = unsigned & 0xFF;
    bytes[i * 2 + 1] = (unsigned >> 8) & 0xFF;
  }
  return bytes;
}

Map<String, Object> _seg(
  String text, {
  double noSpeech = 0.01,
  double logprob = -0.2,
  double compression = 1.3,
}) =>
    {
      'text': text,
      'no_speech_prob': noSpeech,
      'avg_logprob': logprob,
      'compression_ratio': compression,
    };

void main() {
  group('PcmChunk.voicedMs', () {
    test('counts only frames loud enough to be speech', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(onChunk: chunks.add);
      // 2 s of speech-level signal, 1 s at a quiet-room noise floor (~-56
      // dBFS), 13 s of digital silence — then flushed.
      chunker.addBytes(_pcm(ms: 2000, amplitude: 3000));
      chunker.addBytes(_pcm(ms: 1000, amplitude: 50));
      chunker.addBytes(_pcm(ms: 13000, amplitude: 0));
      chunker.flush();

      expect(chunks.first.voicedMs, 2000);
      final total = chunks.fold<int>(0, (sum, c) => sum + c.voicedMs);
      expect(total, 2000);
    });

    test('a quiet far-away speaker still counts as voiced', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(onChunk: chunks.add);
      // ~-44 dBFS: below the chunker's silence threshold, above the voiced one.
      chunker.addBytes(_pcm(ms: 1000, amplitude: 200));
      chunker.flush();
      expect(chunks.single.voicedMs, 1000);
    });

    test('resets between chunks', () {
      final chunks = <PcmChunk>[];
      final chunker = PcmChunker(onChunk: chunks.add);
      chunker.addBytes(_pcm(ms: 30000, amplitude: 3000));
      chunker.addBytes(_pcm(ms: 1000, amplitude: 0));
      chunker.flush();
      expect(chunks.map((c) => c.voicedMs), [30000, 0]);
    });
  });

  group('filterWhisperSegments', () {
    test('returns null when there is nothing to filter on', () {
      expect(filterWhisperSegments(null), isNull);
      expect(filterWhisperSegments('nope'), isNull);
      expect(filterWhisperSegments(<Object>[]), isNull);
    });

    test('keeps confident speech untouched', () {
      final r = filterWhisperSegments([_seg(' Dobrý den.'), _seg(' Začneme.')])!;
      expect(r.dropped, 0);
      expect(r.text, 'Dobrý den. Začneme.');
    });

    test('drops a segment Whisper scored as silence', () {
      final r = filterWhisperSegments([
        _seg(' Rozpočet je osm set tisíc.'),
        _seg(' Titulky vytvořil Jan.', noSpeech: 0.9, logprob: -1.4),
      ])!;
      expect(r.dropped, 1);
      expect(r.text, 'Rozpočet je osm set tisíc.');
    });

    test('keeps a probably-silent segment that was decoded confidently', () {
      // A quiet speaker, not a hallucination.
      expect(
        isLikelyHallucinatedSegment(noSpeechProb: 0.8, avgLogprob: -0.3),
        isFalse,
      );
    });

    test('drops a repetition loop', () {
      expect(isLikelyHallucinatedSegment(compressionRatio: 3.1), isTrue);
    });

    test('missing metrics keep the segment', () {
      final r = filterWhisperSegments([
        {'text': ' Bez metrik.'},
      ])!;
      expect(r.dropped, 0);
    });
  });

  group('isPromptEcho', () {
    const prompt = 'Na marketing jsme vyčlenili čtvrtinu celého rozpočtu.';

    test('the previous chunk repeated back is an echo', () {
      expect(isPromptEcho('vyčlenili čtvrtinu celého rozpočtu', prompt), isTrue);
    });

    test('new speech is not', () {
      expect(isPromptEcho('Grafik dodá návrhy do pátku.', prompt), isFalse);
    });

    test('a short repeated phrase survives', () {
      expect(isPromptEcho('Marketing.', prompt), isFalse);
      expect(isPromptEcho('anything', null), isFalse);
    });
  });

  group('sanitizeTranscript, sound tags', () {
    test('a bracketed tag is removed wherever it sits', () {
      expect(sanitizeTranscript('[hudba]'), '');
      expect(sanitizeTranscript('Dobře. [potlesk] Jdeme dál.'),
          'Dobře. Jdeme dál.');
    });
  });

  group('isGroundedIn', () {
    const spoken = 'Teď k té první věci. Nevím přesně, kolik to na ten '
        'marketing dělá v korunách.';

    test('a verbatim quote is grounded', () {
      expect(
        isGroundedIn('kolik to na ten marketing dělá v korunách', spoken),
        isTrue,
      );
    });

    test('inflected forms still match', () {
      expect(isGroundedIn('Kolik korun dělá marketing?', spoken), isTrue);
    });

    test('a question nobody asked is not', () {
      expect(isGroundedIn('Kdo schválil smlouvu s dodavatelem?', spoken),
          isFalse);
    });

    test('too short to judge passes', () {
      expect(isGroundedIn('A co?', spoken), isTrue);
    });
  });
}
