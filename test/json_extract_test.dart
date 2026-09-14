import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/json_extract.dart';

void main() {
  test('a clean object', () {
    expect(extractJsonObject('{"is_question": true}'), {'is_question': true});
  });

  test('an object in a Markdown fence', () {
    expect(
      extractJsonObject('```json\n{"answer": "Ano."}\n```'),
      {'answer': 'Ano.'},
    );
  });

  test('a brace in the prose after the object', () {
    expect(
      extractJsonObject('Výsledek: {"is_question": true} (viz {poznámka})'),
      {'is_question': true},
    );
  });

  test('a brace in the prose before the object', () {
    expect(
      extractJsonObject('Zvážil jsem {rozpočet}. {"is_question": false}'),
      {'is_question': false},
    );
  });

  test('a bare {} in the narration does not win over the real object', () {
    expect(
      extractJsonObject('Začnu s {} a pak: {"basis": "meeting"}'),
      {'basis': 'meeting'},
    );
    expect(extractJsonObject('Jen {} nic víc.'), <Object?, Object?>{});
  });

  test('braces and escaped quotes inside strings', () {
    expect(
      extractJsonObject(r'Tady: {"answer": "řekl \"ne}\" a {x"} konec'),
      {'answer': 'řekl "ne}" a {x'},
    );
  });

  test('nested objects are kept whole', () {
    expect(
      extractJsonObject('x {"a": {"b": [1, {"c": 2}]}} y'),
      {
        'a': {
          'b': [
            1,
            {'c': 2},
          ],
        },
      },
    );
  });

  test('no object means null, never a throw', () {
    for (final raw in [
      '',
      'Ano, to je otázka.',
      '["a", "b"]',
      '{"a": 1',
      '}{',
      '{nejde to}',
    ]) {
      expect(extractJsonObject(raw), isNull, reason: raw);
    }
  });
}
