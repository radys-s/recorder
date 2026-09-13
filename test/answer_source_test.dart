import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/answer_source.dart';

void main() {
  group('AnswerSource.tryParse', () {
    test('accepts a well-formed source', () {
      final source = AnswerSource.tryParse({
        'title': 'Sazby ČNB',
        'url': 'https://www.cnb.cz/cs/menova-politika/',
      });

      expect(source, isNotNull);
      expect(source!.title, 'Sazby ČNB');
      expect(source.domain, 'cnb.cz');
    });

    test('falls back to the host when the title is missing', () {
      final source = AnswerSource.tryParse({'url': 'https://example.org/a'});
      expect(source!.title, 'example.org');
    });

    // A chip that cannot be opened looks like evidence and is not — the whole
    // point of validating here rather than at tap time.
    test('rejects anything that is not an http(s) link', () {
      expect(AnswerSource.tryParse({'url': 'javascript:alert(1)'}), isNull);
      expect(AnswerSource.tryParse({'url': 'ftp://example.org'}), isNull);
      expect(AnswerSource.tryParse({'url': 'cnb.cz/sazby'}), isNull);
      expect(AnswerSource.tryParse({'url': 'https://'}), isNull);
      expect(AnswerSource.tryParse({'url': ''}), isNull);
      expect(AnswerSource.tryParse('https://example.org'), isNull);
      expect(AnswerSource.tryParse(null), isNull);
    });
  });

  group('encodeAnswerSources / decodeAnswerSources', () {
    test('round-trips', () {
      final encoded = encodeAnswerSources([
        AnswerSource(title: 'Sazby ČNB', url: Uri.parse('https://cnb.cz/a')),
        AnswerSource(title: 'Kurzy', url: Uri.parse('https://kurzy.cz/b')),
      ]);

      final decoded = decodeAnswerSources(encoded);
      expect(decoded, hasLength(2));
      expect(decoded.first.title, 'Sazby ČNB');
      expect(decoded.last.url.toString(), 'https://kurzy.cz/b');
    });

    // Null and not `[]`, so "no sources" and "written before web search
    // existed" read the same in the UI — which is all either one means.
    test('an empty list encodes to null', () {
      expect(encodeAnswerSources(const []), isNull);
    });

    // A row from an older or buggier build must not fail a screen that is
    // open during a live meeting.
    test('anything unusable decodes to no sources', () {
      expect(decodeAnswerSources(null), isEmpty);
      expect(decodeAnswerSources(''), isEmpty);
      expect(decodeAnswerSources('not json'), isEmpty);
      expect(decodeAnswerSources('{"url": "https://a.cz"}'), isEmpty);
      expect(decodeAnswerSources('[{"url": "nope"}]'), isEmpty);
    });

    test('drops only the bad entries from a mixed list', () {
      final decoded = decodeAnswerSources(
        '[{"url":"nope"},{"title":"OK","url":"https://a.cz/x"}]',
      );
      expect(decoded, hasLength(1));
      expect(decoded.single.domain, 'a.cz');
    });
  });

  group('collectAnswerSources', () {
    // Groq reports what its agentic model actually retrieved in
    // `executed_tools`, and nests the results one level deeper as a JSON
    // string. Taking links from there rather than from the model's own prose
    // is what makes a source chip evidence instead of a claim.
    test('digs sources out of a nested executed_tools block', () {
      final tools = [
        {
          'index': 0,
          'type': 'search',
          'arguments': '{"query": "sazba ČNB"}',
          'output': '{"results": [{"title": "Sazby", "url": "https://cnb.cz/a", '
              '"score": 0.9}, {"title": "Kurzy", "url": "https://kurzy.cz/b"}]}',
        },
      ];

      final sources = collectAnswerSources(tools);
      expect(sources.map((s) => s.domain), ['cnb.cz', 'kurzy.cz']);
    });

    test('de-duplicates by domain and honours the cap', () {
      final sources = collectAnswerSources([
        {'url': 'https://a.cz/1'},
        {'url': 'https://a.cz/2'},
        {'url': 'https://b.cz/1'},
        {'url': 'https://c.cz/1'},
        {'url': 'https://d.cz/1'},
      ], max: 3);

      expect(sources.map((s) => s.domain), ['a.cz', 'b.cz', 'c.cz']);
    });

    test('an unrecognised shape yields nothing rather than throwing', () {
      expect(collectAnswerSources(null), isEmpty);
      expect(collectAnswerSources('just prose'), isEmpty);
      expect(collectAnswerSources([1, 2, 3]), isEmpty);
      expect(collectAnswerSources([{'output': 'not json {'}]), isEmpty);
    });
  });
}
