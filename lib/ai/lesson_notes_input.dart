import '../data/db/tables/preferences_table.dart';

/// Everything besides the transcript that výpisky are made from.
class LessonNotesInput {
  const LessonNotesInput({
    required this.subjectName,
    this.cardTitles = const [],
    this.context = const [],
    this.photos = const [],
    this.questions = const [],
  });

  final String subjectName;

  /// Titles of the cards pinned for the lesson.
  final List<String> cardTitles;

  /// What the student typed as context, oldest first.
  final List<String> context;

  /// Text read from board and slide photos, oldest first.
  final List<String> photos;

  /// Questions from the lesson with the app's answers, oldest first.
  final List<({String question, String answer})> questions;
}

/// The labelled material after the transcript, each block cut to fit [maxChars]
/// in total. Items are kept whole and in order; the first that does not fit
/// ends its block, so a later block still gets its share.
String lessonNotesBlocks(LessonNotesInput input, {int? maxChars}) {
  final blocks = <(String, List<String>)>[
    ('Kontext od studenta', [for (final c in input.context) '- ${c.trim()}']),
    (
      'Fotky tabule a prezentace',
      [
        for (var i = 0; i < input.photos.length; i++)
          '--- fotka ${i + 1} ---\n${input.photos[i].trim()}',
      ],
    ),
    (
      'Otázky a odpovědi',
      [
        for (final q in input.questions)
          '- Otázka: ${q.question.trim()}\n  Odpověď: ${q.answer.trim()}',
      ],
    ),
  ];
  final present = [for (final b in blocks) if (b.$2.isNotEmpty) b];
  if (present.isEmpty) return '';

  final share = maxChars == null ? null : maxChars ~/ present.length;
  final out = StringBuffer();
  for (final (label, items) in present) {
    final kept = <String>[];
    var used = 0;
    for (final item in items) {
      if (share != null && used + item.length > share) break;
      kept.add(item);
      used += item.length + 1;
    }
    if (kept.isEmpty) continue;
    out.write('\n\n$label:\n${kept.join('\n')}');
  }
  return out.toString();
}

/// The user message for výpisky: the subject, the pinned cards, the transcript
/// and the labelled blocks. [maxExtraChars] caps the blocks, not the transcript.
String lessonUserMessage(
  String transcript,
  LessonNotesInput lesson, {
  int? maxExtraChars,
}) {
  final cards = lesson.cardTitles.isEmpty
      ? ''
      : '\nKarty k hodině: ${lesson.cardTitles.join(', ')}';
  return 'Předmět: ${lesson.subjectName}$cards\n\n'
      'Přepis:\n${transcript.trim()}'
      '${lessonNotesBlocks(lesson, maxChars: maxExtraChars)}';
}

/// Výpisky: study notes for the notebook rather than meeting minutes.
///
/// English for the same reason as the meeting prompts; section names in Czech
/// because they are the output.
String lessonNotesPrompt(NotesDepth depth) => '''
You write the study notes (výpisky) a student copies into their notebook after
a lesson and learns from before a test. The material comes in labelled blocks:

- "Přepis": an automatic transcript of the lesson. It has recognition errors and
  no speaker labels; the teacher does most of the talking.
- "Kontext od studenta": what the student typed during the lesson — what the
  class was reading or working on.
- "Fotky tabule a prezentace": text read from photos of the board and of slides.
- "Otázky a odpovědi": questions from the lesson with answers an AI gave then.

Rules:
- Write in the same language as the transcript, headings included.
- Use only the material. Invent no fact, name, date, term or definition.
- The board and slide text is what the teacher wrote: prefer its spelling of
  names and terms over the transcript's, and never leave out a term that is on
  it. An answer from "Otázky a odpovědi" may be used only where the lesson
  agrees with it.
- Leave out classroom logistics, discipline, jokes and chatter.
- Plain text: "- " for a bullet, "Nadpis:" alone on its line. No Markdown, no
  bold, no tables. A term and its definition as "- pojem – definice".
- Notes only — no preamble, no closing remark, nothing about the material or
  about yourself. Skip any section the lesson gave nothing for; never pad one.
- "Domácí úkol" only if homework was actually given, with its deadline if said.

${_lessonDepthPrompt(depth)}''';

String _lessonDepthPrompt(NotesDepth depth) => switch (depth) {
      NotesDepth.keywords => '''
At most 6 lines, about 50 words, no headings: each line "- " and a key term with
a few words of definition, the most testable ones first. A last line
"- Domácí úkol: ..." only if homework was given.''',
      NotesDepth.brief => '''
At most 100 words. The shape:

  Téma: <one line>
  - <the 3 to 6 things from the lesson most worth knowing, one sentence each>
  Domácí úkol: <only if given>''',
      NotesDepth.standard => '''
150 to 300 words. The shape:

  Téma: <one line>

  Klíčové pojmy:
  - <pojem> – <definice>

  Příklady:
  - <an example or excerpt used in the lesson and what it showed>

  Co si zapamatovat (může být v testu):
  - ...

  Domácí úkol: <only if given>''',
      NotesDepth.detailed => '''
300 to 600 words. The shape:

  Téma: <one line>

  Klíčové pojmy:
  - <pojem> – <definice>

  <Podtéma>:
  - what was explained about it, with dates, names and reasons

  Příklady / ukázky:
  - ...

  Souvislosti:
  - <how this ties to the cards listed as "Karty k hodině" or to earlier topics,
    only where the lesson itself made the link>

  Co si zapamatovat (může být v testu):
  - ...

  Domácí úkol: <only if given>

One heading per subtopic, in the order the lesson took them.''',
      NotesDepth.full => '''
As long as the lesson needs: keep every explanation, example, date, name and
term. Same shape as a detailed version — Téma, Klíčové pojmy, one heading per
subtopic, Příklady / ukázky, Souvislosti, Co si zapamatovat (může být v testu),
Domácí úkol — with nothing from the lesson left out.''',
    };
