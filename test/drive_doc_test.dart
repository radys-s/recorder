import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/sync/drive_doc.dart';

void main() {
  group('notesToHtml', () {
    test('bullets become one list, a short line with a colon a heading', () {
      final html = notesToHtml(
        'Klíčové pojmy:\n- VLAN – virtuální síť\n- OSPF – směrování\n\n'
        'Učitel řekl, že to bude v testu.',
      );
      expect(
        html,
        '<h3>Klíčové pojmy:</h3>'
        '<ul><li>VLAN – virtuální síť</li><li>OSPF – směrování</li></ul>'
        '<p>Učitel řekl, že to bude v testu.</p>',
      );
    });

    test('a long line ending in a colon stays a paragraph', () {
      final line = '${'slovo ' * 12}takto:';
      expect(notesToHtml(line), '<p>${line.trim()}</p>');
    });

    test('escapes markup the student could have typed', () {
      expect(
        notesToHtml('- a < b & "c" > d'),
        '<ul><li>a &lt; b &amp; &quot;c&quot; &gt; d</li></ul>',
      );
    });
  });

  group('notesDocHtml', () {
    final older = DocLesson(
      date: DateTime(2026, 9, 2),
      topic: 'Směrování',
      notes: '- statické a dynamické',
      important: const [(note: 'bude v testu', excerpt: 'OSPF je link-state')],
      questions: const [(question: 'Co je RIP?', answer: 'Distance-vector.')],
    );
    final newer = DocLesson(date: DateTime(2026, 9, 9), notes: 'VLAN');

    test('lessons oldest first, with starred items, Q&A and subject notes', () {
      final html = notesDocHtml(
        subject: 'Počítačové sítě',
        courseLine: 'SOŠ, 3. ročník',
        lessons: [newer, older],
        notes: const [DocNote(title: 'Shrnutí předmětu', content: 'Vše.')],
      );
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<title>Schůzky – Počítačové sítě</title>'));
      expect(html, contains('<h1>Počítačové sítě</h1><p><i>SOŠ, 3. ročník'));
      expect(
        html.indexOf('Hodina 2. 9. 2026 · Směrování'),
        lessThan(html.indexOf('Hodina 9. 9. 2026</h2>')),
      );
      expect(html, contains('<h3>Označeno jako důležité</h3>'));
      expect(html, contains('<b>bude v testu</b> — OSPF je link-state'));
      expect(html, contains('<b>Co je RIP?</b><br>Distance-vector.'));
      expect(html, contains('<h2>Poznámky předmětu</h2><h3>Shrnutí předmětu'));
    });

    test('the same content gives the same hash, other content another', () {
      String doc() => notesDocHtml(subject: 'Sítě', lessons: [older]);
      final name = notesDocName('Sítě');
      expect(contentHash(name, doc()), contentHash(name, doc()));
      expect(
        contentHash(name, doc()),
        isNot(contentHash(name, notesDocHtml(subject: 'Sítě', lessons: [newer]))),
      );
      expect(contentHash(name, doc()), isNot(contentHash('jiné', doc())));
    });

    test('empty starred items and a missing course line leave no markup', () {
      final html = notesDocHtml(
        subject: 'Sítě',
        lessons: [
          DocLesson(
            date: DateTime(2026, 9, 2),
            notes: 'x',
            important: const [(note: ' ', excerpt: '')],
          ),
        ],
      );
      expect(html, isNot(contains('Označeno')));
      expect(html, isNot(contains('<i>')));
    });
  });

  group('transcripts', () {
    test('paragraphs break only after a sentence', () {
      final text = List.filled(30, 'Tohle je jedna věta o sítích.').join(' ');
      final paragraphs = transcriptParagraphs(text, target: 100);
      expect(paragraphs.length, greaterThan(1));
      for (final p in paragraphs) {
        expect(p, endsWith('.'));
      }
      expect(paragraphs.join(' '), text);
    });

    test('when it does not fit, the newest lessons win and the doc says so', () {
      final lessons = [
        for (var day = 1; day <= 5; day++)
          DocTranscript(date: DateTime(2026, 9, day), text: 'Věta. ' * 40),
      ];
      final one = transcriptsDocHtml(subject: 'Sítě', lessons: lessons.take(1).toList());
      final section = one.length - transcriptsDocHtml(subject: 'Sítě', lessons: const []).length;

      final html = transcriptsDocHtml(
        subject: 'Sítě',
        lessons: lessons,
        maxChars: section * 2 + 10,
      );
      expect(html, contains('Starší hodiny (3) se do dokumentu nevešly'));
      expect(html, isNot(contains('Hodina 3. 9. 2026')));
      expect(
        html.indexOf('Hodina 4. 9. 2026'),
        lessThan(html.indexOf('Hodina 5. 9. 2026')),
      );
    });

    test('everything fits: no note about dropped lessons', () {
      final html = transcriptsDocHtml(
        subject: 'Sítě',
        lessons: [DocTranscript(date: DateTime(2026, 9, 1), text: 'Ahoj.')],
      );
      expect(html, isNot(contains('nevešly')));
      expect(html, contains('<title>Schůzky – Sítě – přepisy</title>'));
    });
  });
}
