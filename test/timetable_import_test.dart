import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/timetable_import.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/features/subjects/timetable_import_screen.dart';

class _FakeKeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'AIza_test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGemini extends GeminiProvider {
  _FakeGemini(this.reply) : super(_FakeKeyStore());

  final String reply;
  final prompts = <String>[];
  var imageCount = 0;

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    prompts.addAll([for (final m in messages) m.content]);
    imageCount = images.length;
    return GeminiCompletion(content: reply);
  }
}

final _image = LlmImage(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png');

ImportedLesson _l(
  String subject,
  int day,
  int start,
  int end, {
  bool guessed = false,
}) => ImportedLesson(
  subject: subject,
  weekday: day,
  startMinute: start,
  endMinute: end,
  timeGuessed: guessed,
);

void main() {
  group('parseClock', () {
    test('reads colon, dot and padded forms', () {
      expect(parseClock('8:05'), 485);
      expect(parseClock('08.05'), 485);
      expect(parseClock(' 13:40 '), 820);
    });

    test('rejects what is not a time', () {
      expect(parseClock('25:00'), isNull);
      expect(parseClock('8:75'), isNull);
      expect(parseClock('osm'), isNull);
      expect(parseClock(null), isNull);
      expect(parseClock(805), isNull);
    });
  });

  group('parseTimetable', () {
    test('uses the times the timetable shows', () {
      final lessons = parseTimetable(
        '{"lessons":[{"subject":"Matematika","day":1,'
        '"start":"8:00","end":"8:45","period":1}]}',
      );
      expect(lessons, [_l('Matematika', 1, 480, 525)]);
    });

    test('a period without times takes the bell schedule, flagged', () {
      final lessons = parseTimetable(
        '{"lessons":[{"subject":"Dějepis","day":"Úterý","start":null,'
        '"end":null,"period":3}]}',
      );
      expect(lessons, [_l('Dějepis', 2, 600, 645, guessed: true)]);
    });

    test('reads day names and abbreviations', () {
      final lessons = parseTimetable(
        '{"lessons":['
        '{"subject":"A","day":"po","start":"8:00","end":"8:45"},'
        '{"subject":"B","day":"Čtvrtek","start":"8:00","end":"8:45"},'
        '{"subject":"C","day":"Pá","start":"8:00","end":"8:45"}]}',
      );
      expect([for (final l in lessons) l.weekday], [1, 4, 5]);
    });

    test('invalid entries are left out', () {
      final lessons = parseTimetable(
        '{"lessons":['
        '{"subject":"","day":1,"start":"8:00","end":"8:45"},'
        '{"subject":"Fyzika","day":9,"start":"8:00","end":"8:45"},'
        '{"subject":"Chemie","day":2},'
        '{"subject":"Biologie","day":2,"start":"9:00","end":"8:00"},'
        '"nonsense"]}',
      );
      expect(lessons, isEmpty);
    });

    test('a reply without lessons is empty, not an error', () {
      expect(parseTimetable('nic tu není'), isEmpty);
      expect(parseTimetable('{"lessons": "x"}'), isEmpty);
    });
  });

  group('mergeImportedLessons', () {
    test('sorts, drops duplicates and joins a double lesson', () {
      final merged = mergeImportedLessons([
        _l('Čeština', 2, 480, 525),
        _l('Matematika', 1, 535, 580),
        _l('Matematika', 1, 480, 525),
        _l('Matematika', 1, 480, 525),
        _l('Cestina', 2, 600, 645),
      ]);
      expect(merged, [
        _l('Matematika', 1, 480, 580),
        _l('Čeština', 2, 480, 525),
        _l('Cestina', 2, 600, 645),
      ]);
    });

    test('a double lesson across the long break is joined', () {
      final merged = mergeImportedLessons([
        _l('Matematika', 1, 535, 580),
        _l('Matematika', 1, 600, 645),
        _l('Matematika', 1, 700, 745),
      ]);
      expect(merged, [
        _l('Matematika', 1, 535, 645),
        _l('Matematika', 1, 700, 745),
      ]);
    });

    test('a guessed half makes the joined lesson guessed', () {
      final merged = mergeImportedLessons([
        _l('Fyzika', 3, 480, 525),
        _l('Fyzika', 3, 535, 580, guessed: true),
      ]);
      expect(merged.single.timeGuessed, isTrue);
    });
  });

  group('matchSubjectName', () {
    const known = ['Čeština', 'Anglický jazyk', 'Tv'];

    test('ignores case and diacritics', () {
      expect(matchSubjectName('cestina', known), 'Čeština');
    });

    test('a prefix of at least four letters matches', () {
      expect(matchSubjectName('Anglický', known), 'Anglický jazyk');
    });

    test('short names need an exact match', () {
      expect(matchSubjectName('Tělocvik', known), isNull);
      expect(matchSubjectName('TV', known), 'Tv');
      expect(matchSubjectName('Matematika', known), isNull);
    });
  });

  group('TimetableImportService', () {
    test('reads, merges and uses the known subject names', () async {
      final gemini = _FakeGemini(
        '{"lessons":['
        '{"subject":"Cestina","day":1,"start":"8:00","end":"8:45"},'
        '{"subject":"Cestina","day":1,"start":"8:55","end":"9:40"},'
        '{"subject":"Matematika","day":2,"period":1}]}',
      );
      final lessons = await TimetableImportService(gemini)
          .read([_image], knownSubjects: ['Čeština']);
      expect(lessons, [
        _l('Čeština', 1, 480, 580),
        _l('Matematika', 2, 480, 525, guessed: true),
      ]);
      expect(gemini.imageCount, 1);
      expect(gemini.prompts.join('\n'), contains('Čeština'));
    });

    test('no timetable on the picture is a Czech permanent error', () async {
      final service = TimetableImportService(_FakeGemini('{"lessons":[]}'));
      await expectLater(
        service.read([_image]),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.message,
            'message',
            contains('rozvrh'),
          ),
        ),
      );
    });
  });

  group('saveImportedTimetable', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('creates missing subjects, reuses existing ones', () async {
      final cz = await db.savedNotesDao.createFolder('Čeština');
      final outcome = await saveImportedTimetable(db, [
        _l('Čeština', 1, 480, 525),
        _l('Matematika', 1, 535, 580),
        _l('Matematika', 3, 480, 525),
      ]);
      expect(outcome.slotsAdded, 3);
      expect(outcome.subjectsCreated, 1);
      expect(outcome.skipped, 0);
      final names = [for (final f in await db.savedNotesDao.folders()) f.name];
      expect(names, unorderedEquals(['Matematika', 'Čeština']));
      final slots = await db.subjectsDao.allSlots();
      expect(slots.where((s) => s.subjectId == cz), hasLength(1));
    });

    test('an import run twice adds nothing the second time', () async {
      final lessons = [_l('Fyzika', 2, 600, 645)];
      await saveImportedTimetable(db, lessons);
      final again = await saveImportedTimetable(db, lessons);
      expect(again.slotsAdded, 0);
      expect(again.skipped, 1);
      expect(again.subjectsCreated, 0);
      expect(await db.subjectsDao.allSlots(), hasLength(1));
    });
  });

  test('lessonCount and importSummary speak Czech', () {
    expect(lessonCount(1), '1 hodinu');
    expect(lessonCount(3), '3 hodiny');
    expect(lessonCount(5), '5 hodin');
    expect(
      importSummary((slotsAdded: 12, subjectsCreated: 5, skipped: 2)),
      'Přidáno do rozvrhu: 12 hodin · 5 nových předmětů · už v rozvrhu: 2.',
    );
    expect(
      importSummary((slotsAdded: 0, subjectsCreated: 0, skipped: 4)),
      'Nic nového k přidání · už v rozvrhu: 4.',
    );
  });
}
