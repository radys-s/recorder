import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> meetingWithNotes(String title, String? content) async {
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(title: title, createdAt: DateTime(2026, 9, 28)),
    );
    await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
    if (content != null) await db.meetingNotesDao.markReady(id, content);
    return id;
  }

  test('recent ready notes come newest first and skip unfinished ones',
      () async {
    final older = await meetingWithNotes('A', 'první');
    await meetingWithNotes('B', null);
    final newer = await meetingWithNotes('C', 'druhé');

    final recent = await db.meetingNotesDao.watchRecentReady().first;

    // The home screen falls back to [older] when [newer] waits out its undo
    // window, so both must be there, in this order.
    expect(recent.map((n) => n.meetingId), [newer, older]);
  });
}
