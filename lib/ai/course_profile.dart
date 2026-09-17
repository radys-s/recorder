import '../data/db/app_database.dart';

/// One line naming a course for prompts and the UI:
/// „Počítačové sítě, SOŠ, obor IT, 3. ročník".
///
/// The subject's full name wins over its short one, and its own level over the
/// student's year. Parts that are not known are left out, so a student who set
/// nothing still gets just the subject's name.
String courseLine(Subject subject, Preference? prefs) {
  final name = subject.fullName?.trim();
  final level = subject.levelOverride?.trim();
  return [
    if (name != null && name.isNotEmpty) name else subject.name,
    if (prefs?.schoolType != null) prefs!.schoolType!.label,
    if (_filled(prefs?.schoolName)) prefs!.schoolName!.trim(),
    if (_filled(prefs?.studyField)) 'obor ${prefs!.studyField!.trim()}',
    if (level != null && level.isNotEmpty)
      level
    else if (prefs?.studyYear != null)
      '${prefs!.studyYear}. ročník',
  ].join(', ');
}

bool _filled(String? v) => v != null && v.trim().isNotEmpty;
