import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/learning/study_flow.dart';

StudyCard _card(StudySource source) => StudyCard(
  id: 1,
  subjectId: 1,
  meetingId: 7,
  noteId: null,
  front: 'Co je VLAN?',
  back: 'Virtuální síť.',
  frontKey: 'co je vlan',
  source: source,
  ease: 2.5,
  intervalDays: 0,
  reps: 0,
  lapses: 0,
  dueAt: DateTime(2026, 9, 28),
  suspended: false,
  createdAt: DateTime(2026, 9, 28),
);

StudyRecommendation _pick({
  int lessons = 3,
  int withNotes = 3,
  int toCard = 0,
  int cards = 10,
  int due = 0,
}) => recommendStudyStep(
  lessons: lessons,
  lessonsWithNotes: withNotes,
  lessonsToCard: toCard,
  cards: cards,
  due: due,
);

void main() {
  setUpAll(() => initializeDateFormatting('cs'));

  group('recommendStudyStep', () {
    test('cards due today beat everything else', () {
      final r = _pick(lessons: 0, withNotes: 0, due: 3);
      expect(r.step, StudyStep.reviewDue);
      expect(r.title, 'Zopakuj 3 kartičky');
    });

    test('no lesson yet asks for the first recording', () {
      expect(
        _pick(lessons: 0, withNotes: 0, cards: 0).step,
        StudyStep.recordLesson,
      );
    });

    test('lessons without any výpisky ask for výpisky', () {
      final one = _pick(lessons: 1, withNotes: 0, cards: 0);
      expect(one.step, StudyStep.makeNotes);
      expect(one.subtitle, contains('Hodina zatím nemá výpisky'));
      final many = _pick(lessons: 5, withNotes: 0, cards: 0);
      expect(many.subtitle, startsWith('5 hodin zatím'));
    });

    test('výpisky without cards ask for cards', () {
      final one = _pick(toCard: 1, cards: 0);
      expect(one.step, StudyStep.makeCards);
      expect(one.subtitle, 'Jedna hodina má výpisky, ale žádné kartičky.');
      expect(_pick(toCard: 2, cards: 0).subtitle, startsWith('2 hodiny má'));
    });

    test('everything in place and nothing due leads to exam prep', () {
      final r = _pick();
      expect(r.step, StudyStep.examPrep);
      expect(r.subtitle, contains('Dnes nic nečeká'));
    });

    test('exam prep without cards explains what it builds', () {
      expect(_pick(cards: 0).subtitle, contains('shrnutí a kvíz'));
    });

    test('missing výpisky beat missing cards', () {
      expect(
        _pick(withNotes: 0, toCard: 0, cards: 0).step,
        StudyStep.makeNotes,
      );
    });

    test('card counts use Czech plural forms', () {
      expect(_pick(due: 1).title, 'Zopakuj 1 kartička');
      expect(_pick(due: 4).title, 'Zopakuj 4 kartičky');
      expect(_pick(due: 5).title, 'Zopakuj 5 kartiček');
    });
  });

  group('lessonStudyLine', () {
    test('lesson with notes and no cards', () {
      expect(
        lessonStudyLine(hasNotes: true, cards: 0, due: 0),
        'Výpisky · bez kartiček',
      );
    });

    test('lesson without notes and cards', () {
      expect(lessonStudyLine(hasNotes: false, cards: 0, due: 0), 'Bez výpisků');
    });

    test('notes with cards, with and without due', () {
      expect(
        lessonStudyLine(hasNotes: true, cards: 3, due: 0),
        'Výpisky · 3 kartičky',
      );
      expect(
        lessonStudyLine(hasNotes: true, cards: 6, due: 2),
        'Výpisky · 6 kartiček · dnes 2',
      );
    });

    test('cards without notes drop the výpisky part', () {
      expect(
        lessonStudyLine(hasNotes: false, cards: 1, due: 1),
        '1 kartička · dnes 1',
      );
    });
  });

  group('describeDueDay', () {
    final now = DateTime(2026, 9, 28, 22, 30); // Monday late evening

    test('same day and overdue are today', () {
      expect(describeDueDay(DateTime(2026, 9, 28, 8), now), 'dnes');
      expect(describeDueDay(DateTime(2026, 9, 20), now), 'dnes');
    });

    test('next calendar day is tomorrow even a minute after midnight', () {
      expect(describeDueDay(DateTime(2026, 9, 29, 0, 1), now), 'zítra');
    });

    test('within a week names the weekday', () {
      expect(describeDueDay(DateTime(2026, 9, 30), now), 've středu');
      expect(describeDueDay(DateTime(2026, 10, 2), now), 'v pátek');
      expect(describeDueDay(DateTime(2026, 10, 4), now), 'v neděli');
    });

    test('a week or more away is a date', () {
      expect(describeDueDay(DateTime(2026, 10, 5), now), '5. 10.');
    });
  });

  group('studyCardProvenance', () {
    final lesson = DateTime(2026, 9, 14, 9);

    test('manual cards are the student\'s own', () {
      final c = _card(StudySource.manual);
      expect(studyCardFromAi(c), isFalse);
      expect(studyCardProvenance(c), 'Přidáno ručně');
    });

    test('AI cards say so and are not presented as verified', () {
      for (final s in [
        StudySource.terms,
        StudySource.remember,
        StudySource.quiz,
      ]) {
        final c = _card(s);
        expect(studyCardFromAi(c), isTrue);
        expect(studyCardProvenance(c, lessonDate: lesson), contains('AI'));
      }
    });

    test('terms and remember cite the lesson date when it is known', () {
      expect(
        studyCardProvenance(_card(StudySource.terms), lessonDate: lesson),
        'Pojem z výpisků hodiny 14. 9. — výpisky vytvořila AI, ověř je.',
      );
      expect(
        studyCardProvenance(_card(StudySource.remember), lessonDate: lesson),
        contains('z výpisků hodiny 14. 9.'),
      );
    });

    test('without a lesson date the line stays honest', () {
      expect(
        studyCardProvenance(_card(StudySource.terms)),
        'Pojem z výpisků — výpisky vytvořila AI, ověř je.',
      );
      expect(
        studyCardProvenance(_card(StudySource.remember)),
        'Kartičku vytvořila AI z výpisků — ověř ji ve výpiscích.',
      );
    });

    test('quiz cards point to the quiz', () {
      expect(
        studyCardProvenance(_card(StudySource.quiz)),
        contains('Před testem'),
      );
    });
  });
}
