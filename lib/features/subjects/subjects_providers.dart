import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/daos/subjects_dao.dart';

final subjectsDaoProvider = Provider<SubjectsDao>((ref) {
  return ref.watch(appDatabaseProvider).subjectsDao;
});

/// Every subject with its card, note and lesson counts.
final subjectsProvider = StreamProvider<List<SubjectSummary>>((ref) {
  return ref.watch(subjectsDaoProvider).watchSubjects();
});

final subjectProvider = StreamProvider.family<Subject?, int>((ref, id) {
  return ref.watch(subjectsDaoProvider).watchSubject(id);
});

final subjectCardsProvider =
    StreamProvider.family<List<ContextCard>, int>((ref, subjectId) {
  return ref.watch(subjectsDaoProvider).watchCards(subjectId);
});

final subjectSlotsProvider =
    StreamProvider.family<List<TimetableSlot>, int>((ref, subjectId) {
  return ref.watch(subjectsDaoProvider).watchSlots(subjectId);
});

/// Every timetable slot of every subject.
final allSlotsProvider = StreamProvider<List<TimetableSlot>>((ref) {
  return ref.watch(subjectsDaoProvider).watchAllSlots();
});

final contextCardProvider =
    StreamProvider.family<ContextCard?, int>((ref, id) {
  return ref.watch(subjectsDaoProvider).watchCard(id);
});

final subjectLessonsProvider =
    StreamProvider.family<List<Meeting>, int>((ref, subjectId) {
  return ref.watch(subjectsDaoProvider).watchLessons(subjectId);
});

final pinnedCardsProvider =
    StreamProvider.family<List<ContextCard>, int>((ref, meetingId) {
  return ref.watch(subjectsDaoProvider).watchPinnedCards(meetingId);
});

/// Eight hues picked to stay apart from each other and from the red recording
/// state. Stored as an index, so the palette can be retuned without a
/// migration.
const _subjectHues = <Color>[
  Color(0xFF3F6FB5), // blue
  Color(0xFF3C8D5A), // green
  Color(0xFFC77A22), // amber
  Color(0xFF7E57C2), // violet
  Color(0xFF26878A), // teal
  Color(0xFFB0476E), // rose
  Color(0xFF7A6552), // brown
  Color(0xFF5C6BC0), // indigo
];

/// The subject's colour, lifted on a dark surface so it keeps its contrast.
Color subjectColor(BuildContext context, int index) {
  final base = _subjectHues[index % _subjectHues.length];
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(base, Colors.white, 0.3)!
      : base;
}

/// Czech plural: 1 karta, 2–4 karty, 5+ (and 0) karet.
String czechCount(int n, String one, String few, String many) {
  final word = n == 1 ? one : (n >= 2 && n <= 4 ? few : many);
  return '$n $word';
}
