import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_intent.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';

/// One row: text, intent while recording, intent after the lesson.
typedef _Row = (String, ChatIntent, ChatIntent);

const _q = ChatIntent.question;
const _c = ChatIntent.context;
const _r = ChatIntent.rule;

const List<_Row> _table = [
  // Real questions, with and without `?`, with and without diacritics.
  ('Kdo byl Proško?', _q, _q),
  ('kdo byl prosko', _q, _q),
  ('Jaký je to literární druh', _q, _q),
  ('jaky je to literarni druh', _q, _q),
  ('Co je to realismus?', _q, _q),
  ('co je to realismus', _q, _q),
  ('Proč Viktorka skočila do vody?', _q, _q),
  ('proc viktorka skocila do vody', _q, _q),
  ('Kolik je 15 % z 240?', _q, _q),
  ('kolik je 15 procent ze 240', _q, _q),
  ('Kdy se narodila Němcová', _q, _q),
  ('Kde leží Litomyšl?', _q, _q),
  ('Jak se počítá obvod kruhu', _q, _q),
  ('Který stylový postup je tu použit', _q, _q),
  ('Je to próza nebo poezie?', _q, _q),
  ('Víš, co znamená metafora?', _q, _q),
  ('Můžeš mi říct, kdo to napsal', _q, _q),
  ('Nevím, kdy to bude hotové', _q, _q),
  ('Zajímalo by mě, kolik to stojí', _q, _q),
  ('what is a subnet mask?', _q, _q),
  ('How does OSPF choose a route', _q, _q),
  ('why is the sky blue', _q, _q),
  // Requests that are questions without being phrased as one.
  ('Vysvětli mi rozdíl mezi TCP a UDP', _q, _q),
  ('vysvetli rozdil mezi tcp a udp', _q, _q),
  ('prosím vysvětli metaforu', _q, _q),
  ('Shrň poslední tři minuty', _q, _q),
  ('shrn to', _q, _q),
  ('Popiš hlavní postavy', _q, _q),
  ('Definuj pojem alegorie', _q, _q),
  ('Porovnej realismus a romantismus', _q, _q),
  ('Uveď tři příklady', _q, _q),
  ('Vyjmenuj vyjmenovaná slova po b', _q, _q),
  ('Řekni mi hlavní myšlenku', _q, _q),
  ('Napiš definici rozpočtu', _q, _q),
  ('Spočítej obsah trojúhelníku se stranou 6', _q, _q),
  ('Odpověz mi, kdo byl Proško', _q, _q),
  ('hele odpověz na to', _q, _q),
  ('explain the difference between tcp and udp', _q, _q),
  ('summarize the last part', _q, _q),
  ('Vysvětli to jednou větou', _q, _q),
  // Rules: how to answer, never what.
  ('Odpovídej jednou větou', _r, _r),
  ('odpovidej strucne', _r, _r),
  ('Neodpovídej na vtipy', _r, _r),
  ('Piš stručně', _r, _r),
  ('prosím piš stručně', _r, _r),
  ('Nepiš úvody', _r, _r),
  ('Vysvětluj jednoduše', _r, _r),
  ('Nevysvětluj základy', _r, _r),
  ('Používej odborné termíny', _r, _r),
  ('Mluv česky', _r, _r),
  ('Buď stručný', _r, _r),
  ('Vždy uveď autora', _r, _r),
  ('Nikdy nevymýšlej citáty', _r, _r),
  ('Pravidlo: odpovídej jednou větou', _r, _r),
  ('rule: answer in one sentence', _r, _r),
  ('always answer briefly', _r, _r),
  // Explicit context opener wins over everything, also after the lesson.
  ('Kontext: čteme Babičku', _c, _c),
  ('kontext čteme máj', _c, _c),
  ('Poznámka: učitel říkal, že to bude v testu', _c, _c),
  ('poznamka: test ve čtvrtek', _c, _c),
  ('Info: hodina je o směrování', _c, _c),
  // Plain context while recording; a question after the lesson.
  ('Čteme úryvek, kde Viktorka zpívá u splavu', _c, _q),
  ('Teď probíráme Babičku od Boženy Němcové', _c, _q),
  ('Je to ten úryvek s Viktorkou', _c, _q),
  ('Babička', _c, _q),
  ('Dnes máme OSPF', _c, _q),
  ('učitel zadal domácí úkol na strany 12 až 14', _c, _q),
  ('We are reading chapter three', _c, _q),
  // Thanks and acknowledgements are never worth a request.
  ('díky', _c, _c),
  ('Děkuji', _c, _c),
  ('ok', _c, _c),
  ('super díky', _c, _c),
  ('jo', _c, _c),
  ('thanks', _c, _c),
  // Edge cases: a verb that is only a request as the first word.
  ('Učitel řekl, ať vysvětlíme metaforu', _c, _q),
  ('Napsali jsme test z češtiny', _c, _q),
  ('Teď budeme počítat obsah', _c, _q),
  ('Mluvíme o realismu', _c, _q),
  ('Zeptej se mě na realismus', _c, _q),
  ('A kdo to vlastně napsal', _q, _q),
  ('hele a proč to tak je', _q, _q),
  ('Nešlo by to jednodušeji?', _q, _q),
  ('Řekni to jednou větou', _q, _q),
  ('piš vždy česky', _r, _r),
  ('Neodpovídej na otázky o večeři', _r, _r),
  // Empty.
  ('   ', _c, _c),
  ('', _c, _c),
];

void main() {
  group('detectChatIntent', () {
    for (final (text, whileRecording, afterLesson) in _table) {
      test('"$text" -> $whileRecording / $afterLesson', () {
        expect(
          detectChatIntent(text, recording: true),
          whileRecording,
          reason: 'while recording',
        );
        expect(
          detectChatIntent(text, recording: false),
          afterLesson,
          reason: 'after the lesson',
        );
      });
    }

    test('the default is the recording behaviour', () {
      expect(detectChatIntent('Čteme Babičku'), ChatIntent.context);
    });

    test('the table is wide enough to mean something', () {
      expect(_table.length, greaterThanOrEqualTo(80));
    });
  });
}
