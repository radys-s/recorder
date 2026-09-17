import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../stt/transcript_sanitizer.dart' show normalizeForArtifactMatch;
import 'gemini_provider.dart';
import 'json_extract.dart';
import 'llm_provider.dart';

/// One lesson read off a timetable screenshot.
class ImportedLesson {
  const ImportedLesson({
    required this.subject,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.timeGuessed = false,
  });

  /// The subject's name as the timetable (or the model) writes it in full.
  final String subject;

  /// 1 = Monday … 7 = Sunday.
  final int weekday;
  final int startMinute;
  final int endMinute;

  /// The screenshot showed only the period number; the time comes from the
  /// usual Czech bell schedule and may be off.
  final bool timeGuessed;

  ImportedLesson copyWith({
    String? subject,
    int? weekday,
    int? startMinute,
    int? endMinute,
    bool? timeGuessed,
  }) => ImportedLesson(
    subject: subject ?? this.subject,
    weekday: weekday ?? this.weekday,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    timeGuessed: timeGuessed ?? this.timeGuessed,
  );

  @override
  bool operator ==(Object other) =>
      other is ImportedLesson &&
      other.subject == subject &&
      other.weekday == weekday &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.timeGuessed == timeGuessed;

  @override
  int get hashCode =>
      Object.hash(subject, weekday, startMinute, endMinute, timeGuessed);

  @override
  String toString() =>
      'ImportedLesson($subject, $weekday, $startMinute-$endMinute)';
}

/// The usual Czech bell schedule, period 0 to 10, used when a screenshot shows
/// period numbers but no times.
const List<(int, int)> kCzechBellSchedule = [
  (7 * 60 + 5, 7 * 60 + 50),
  (8 * 60, 8 * 60 + 45),
  (8 * 60 + 55, 9 * 60 + 40),
  (10 * 60, 10 * 60 + 45),
  (10 * 60 + 55, 11 * 60 + 40),
  (11 * 60 + 50, 12 * 60 + 35),
  (12 * 60 + 45, 13 * 60 + 30),
  (13 * 60 + 40, 14 * 60 + 25),
  (14 * 60 + 35, 15 * 60 + 20),
  (15 * 60 + 30, 16 * 60 + 15),
  (16 * 60 + 25, 17 * 60 + 10),
];

/// Back-to-back lessons of one subject at most this far apart become one slot
/// (a double lesson), so the start sheet picks the subject for the whole block.
/// Czech schools' long break is 20 minutes, and a double lesson often spans it.
const int kDoubleLessonGapMinutes = 20;

/// Reads a timetable screenshot with Gemini.
///
/// Groq has no vision model on this account, so callers explain the action
/// when no Gemini key is set.
class TimetableImportService {
  TimetableImportService(this._gemini);

  static const _tag = 'ai.timetable';

  final GeminiProvider _gemini;

  /// The lessons on [images], merged and sorted. [knownSubjects] are the
  /// student's subjects, so the model can use their exact names. Throws
  /// [AiException]; a picture with no timetable on it is a permanent one
  /// with a Czech message.
  Future<List<ImportedLesson>> read(
    List<LlmImage> images, {
    List<String> knownSubjects = const [],
  }) async {
    if (images.isEmpty) throw ArgumentError.value(images, 'images', 'empty');
    final known = knownSubjects.where((s) => s.trim().isNotEmpty).toList();
    final result = await _gemini.generate(
      model: kGeminiModel,
      messages: [
        const LlmMessage.system(_prompt),
        LlmMessage.user(
          [
            images.length == 1
                ? 'A screenshot of a school timetable.'
                : '${images.length} screenshots of one school timetable.',
            if (known.isNotEmpty)
              "The student's subjects: ${known.join(', ')}.",
          ].join('\n'),
        ),
      ],
      images: images,
      jsonMode: true,
      maxTokens: 12000,
      timeout: kGeminiPhotoTimeout,
    );
    final lessons = mergeImportedLessons(parseTimetable(result.content));
    AppLog.d(_tag, '${images.length} image(s): ${lessons.length} lesson(s)');
    if (lessons.isEmpty) {
      throw const AiPermanentException('Na obrázku jsem nenašel rozvrh hodin.');
    }
    return [
      for (final l in lessons)
        l.copyWith(subject: matchSubjectName(l.subject, known) ?? l.subject),
    ];
  }

  static const String _prompt = '''
A student sends a screenshot or photo of their school timetable (for example
from Bakaláři, Edookit or a printed schedule). List every lesson in it.

Reply with one JSON object and nothing else:
{"lessons": [{"subject": "...", "day": 1, "start": "8:00", "end": "8:45", "period": 1}]}

- "subject": the subject's full Czech name, not an abbreviation ("Čj" is
  "Český jazyk", "M" is "Matematika", "Aj" is "Anglický jazyk"). If one of the
  student's subjects listed below is the same subject, use exactly that name.
- "day": 1 = Monday … 7 = Sunday.
- "start" / "end": 24-hour H:MM as shown in the timetable, usually in the
  header above each period. Use null when the timetable shows no times.
- "period": the lesson's period number when the timetable numbers them, else
  null.
- One entry per lesson. A lesson spanning two periods is two entries.
- Leave out breaks, empty cells, cancelled lessons, room numbers and teachers.
- When a cell holds alternatives for odd/even weeks or groups, list each once.
If there is no timetable in the image, reply {"lessons": []}.''';
}

/// The lessons in a model reply. Entries missing a subject, a day or any usable
/// time are left out; a period without times takes [kCzechBellSchedule].
List<ImportedLesson> parseTimetable(String raw) {
  final decoded = extractJsonObject(raw);
  final list = decoded?['lessons'];
  if (list is! List) return const [];
  final out = <ImportedLesson>[];
  for (final item in list) {
    if (item is! Map) continue;
    final subject = item['subject'] is String
        ? (item['subject'] as String).trim()
        : '';
    if (subject.isEmpty || subject.length > 60) continue;
    final day = _weekday(item['day']);
    if (day == null) continue;
    var start = parseClock(item['start']);
    var end = parseClock(item['end']);
    var guessed = false;
    if (start == null || end == null || end <= start) {
      final period = _int(item['period']);
      if (period == null || period < 0 || period >= kCzechBellSchedule.length) {
        continue;
      }
      final bell = kCzechBellSchedule[period];
      start = bell.$1;
      end = bell.$2;
      guessed = true;
    }
    out.add(
      ImportedLesson(
        subject: subject,
        weekday: day,
        startMinute: start,
        endMinute: end,
        timeGuessed: guessed,
      ),
    );
  }
  return out;
}

/// Sorted by day and time, exact duplicates dropped, and back-to-back lessons
/// of the same subject joined into one slot.
List<ImportedLesson> mergeImportedLessons(List<ImportedLesson> lessons) {
  final sorted = [...lessons]
    ..sort((a, b) {
      final d = a.weekday.compareTo(b.weekday);
      return d != 0 ? d : a.startMinute.compareTo(b.startMinute);
    });
  final out = <ImportedLesson>[];
  for (final l in sorted) {
    if (out.isNotEmpty) {
      final last = out.last;
      final same =
          last.weekday == l.weekday &&
          normalizeForArtifactMatch(last.subject) ==
              normalizeForArtifactMatch(l.subject);
      if (same && l.startMinute <= last.endMinute + kDoubleLessonGapMinutes) {
        if (l.endMinute > last.endMinute) {
          out[out.length - 1] = last.copyWith(
            endMinute: l.endMinute,
            timeGuessed: last.timeGuessed || l.timeGuessed,
          );
        }
        continue;
      }
    }
    out.add(l);
  }
  return out;
}

/// The existing subject [name] refers to, or null: the same name without case
/// and diacritics, or one name starting the other ("Čeština" and "Český
/// jazyk" do not match — the prompt asks the model to use the known name).
String? matchSubjectName(String name, List<String> known) {
  final key = normalizeForArtifactMatch(name);
  if (key.isEmpty) return null;
  for (final k in known) {
    if (normalizeForArtifactMatch(k) == key) return k;
  }
  for (final k in known) {
    final other = normalizeForArtifactMatch(k);
    if (other.length < 4 || key.length < 4) continue;
    if (other.startsWith(key) || key.startsWith(other)) return k;
  }
  return null;
}

/// `8:05`, `08.05` or `805` → minute of day; null when it is not a time.
int? parseClock(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^\s*(\d{1,2})\s*[:.]\s*(\d{2})\s*$').firstMatch(value);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

int? _int(Object? v) => switch (v) {
  int i => i,
  double d when d == d.roundToDouble() => d.toInt(),
  String s => int.tryParse(s.trim().replaceAll('.', '')),
  _ => null,
};

int? _weekday(Object? v) {
  final n = _int(v);
  if (n != null) return n >= 1 && n <= 7 ? n : null;
  if (v is! String) return null;
  final key = normalizeForArtifactMatch(v);
  const names = ['po', 'ut', 'st', 'ct', 'pa', 'so', 'ne'];
  for (var i = 0; i < names.length; i++) {
    if (key.startsWith(names[i])) return i + 1;
  }
  return null;
}

/// What an import added.
typedef TimetableImportOutcome = ({
  int slotsAdded,
  int subjectsCreated,
  int skipped,
});

/// Writes [lessons] in one transaction: subjects that do not exist yet are
/// created, and a slot identical to one already there is skipped.
Future<TimetableImportOutcome> saveImportedTimetable(
  AppDatabase db,
  List<ImportedLesson> lessons,
) {
  return db.transaction(() async {
    final existing = await db.savedNotesDao.folders();
    final before = existing.length;
    final ids = <String, int>{};
    var added = 0;
    var skipped = 0;
    final slots = await db.subjectsDao.allSlots();
    final taken = {
      for (final s in slots)
        '${s.subjectId}/${s.weekday}/${s.startMinute}/${s.endMinute}',
    };
    for (final l in lessons) {
      final key = normalizeForArtifactMatch(l.subject);
      final id = ids[key] ??= await db.savedNotesDao.createFolder(l.subject);
      final slotKey = '$id/${l.weekday}/${l.startMinute}/${l.endMinute}';
      if (!taken.add(slotKey)) {
        skipped++;
        continue;
      }
      await db.subjectsDao.addSlot(
        subjectId: id,
        weekday: l.weekday,
        startMinute: l.startMinute,
        endMinute: l.endMinute,
      );
      added++;
    }
    final after = (await db.savedNotesDao.folders()).length;
    return (
      slotsAdded: added,
      subjectsCreated: after - before,
      skipped: skipped,
    );
  });
}
