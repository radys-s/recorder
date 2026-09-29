import '../core/redaction.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/tables/meeting_notes_table.dart';
import '../data/db/daos/meeting_notes_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/db/app_database.dart';
import '../stt/refined_transcript.dart';
import 'lesson_notes_input.dart';
import 'llm_provider.dart';

/// Turns a meeting's transcript into notes at a chosen depth.
///
/// Everything it produces is written to the database rather than returned, so
/// the screen only ever watches [MeetingNotesDao] — which is also what makes a
/// generation survive the user navigating away mid-call.
class NotesGenerator {
  NotesGenerator(
    this._llm,
    this._segmentsDao,
    this._notesDao, {
    this.refinedFor,
    this.lessonFor,
    this.gemini,
    this.hasGeminiKey,
    this.onLessonNotes,
  });

  static const _tag = 'ai.notes';

  final LlmProvider _llm;
  final TranscriptSegmentsDao _segmentsDao;
  final MeetingNotesDao _notesDao;

  /// The refined windows of a meeting; where they are ready they replace the
  /// live text.
  final Future<List<RefinedSegment>> Function(int meetingId)? refinedFor;

  /// The lesson material for a meeting with a subject, else null. A lesson gets
  /// výpisky instead of meeting notes.
  final Future<LessonNotesInput?> Function(int meetingId)? lessonFor;

  /// With a key, a lesson's výpisky are one Gemini call over everything;
  /// without one, or when it fails, Groq's windowed path does the work.
  final LlmProvider? gemini;
  final Future<bool> Function()? hasGeminiKey;

  /// Called once a lesson's výpisky are stored, e.g. for card suggestions.
  final Future<void> Function(int meetingId, String notes)? onLessonNotes;

  /// Generates and stores notes for [meetingId]. Never throws: every failure
  /// ends up on the row as [NotesStatus.failed] with a message, because the
  /// caller is a button press with nowhere to report an exception to.
  Future<void> generate({
    required int meetingId,
    required NotesDepth depth,
  }) async {
    // Outside the main try on purpose, but still caught: if the row cannot even
    // be marked, there is no row to put the failure on either, and the
    // "never throws" promise above is what the button relies on.
    LessonNotesInput? lesson;
    try {
      lesson = await lessonFor?.call(meetingId);
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: lesson material failed', e, st);
    }
    // Gemini's long context is useful for an ordinary meeting too. Restricting
    // it to lessons meant a 38-minute meeting was pushed through the smaller
    // fallback path even when the user had already configured the free key.
    final onGemini = gemini != null && await _geminiAvailable();

    try {
      await _notesDao.markGenerating(
        meetingId,
        depth,
        onGemini ? kGeminiModel : kGroqNotesModel,
      );
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: could not start generation', e, st);
      return;
    }

    try {
      final transcript = await _transcript(meetingId);
      if (transcript.isEmpty) {
        await _notesDao.markFailed(
          meetingId,
          'Přepis je zatím prázdný, není z čeho poznámky udělat.',
        );
        return;
      }

      AppLog.d(
        _tag,
        'meeting $meetingId: ${transcript.length} chars, depth=${depth.name}',
      );

      // Trimmed here rather than trusted to the provider: a reply of nothing but
      // whitespace would otherwise be stored as "ready" notes the user cannot
      // see, replacing the previous ones.
      String? notes;
      if (onGemini) {
        try {
          notes = (await _generateGemini(transcript, depth, lesson)).trim();
        } on AiException catch (e) {
          AppLog.e(_tag, 'meeting $meetingId: Gemini failed, using Groq: ${describeError(e)}');
          await _notesDao.markGenerating(meetingId, depth, kGroqNotesModel);
        }
      }
      notes ??=
          (transcript.length > kNotesWindowThreshold
                  ? await _generateWindowed(transcript, depth, lesson)
                  : await _generateSingle(transcript, depth, lesson))
              .trim();

      if (notes.isEmpty) {
        await _notesDao.markFailed(meetingId, 'Model vrátil prázdnou odpověď.');
        return;
      }

      await _notesDao.markReady(meetingId, notes);
      AppLog.d(_tag, 'meeting $meetingId: notes ready (${notes.length} chars)');

      if (lesson != null && onLessonNotes != null) {
        try {
          await onLessonNotes!(meetingId, notes);
        } catch (e, st) {
          AppLog.e(_tag, 'meeting $meetingId: after-notes step failed', e, st);
        }
      }
    } on AiException catch (e) {
      AppLog.e(_tag, 'meeting $meetingId failed: ${describeError(e)}');
      await _fail(meetingId, e.message);
    } catch (e) {
      AppLog.e(_tag, 'meeting $meetingId failed: ${describeError(e)}');
      await _fail(
        meetingId,
        'Nastala neočekávaná chyba. Zkus to prosím znovu.',
      );
    }
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await hasGeminiKey?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A failure while recording a failure is logged, not thrown.
  Future<void> _fail(int meetingId, String message) async {
    try {
      await _notesDao.markFailed(meetingId, message);
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: could not record failure', e, st);
    }
  }

  /// Segments in order, empty ones dropped — a segment with no text is either a
  /// sub-second tail or a chunk the sanitizer emptied, and neither belongs in
  /// the material the model reasons over.
  Future<String> _transcript(int meetingId) async {
    final segments = await _segmentsDao.segmentsForMeeting(meetingId);
    if (refinedFor != null) {
      return refinedOrLiveTranscript(segments, await refinedFor!(meetingId));
    }
    final parts = <String>[
      for (final s in segments)
        if (s.content != null && s.content!.trim().isNotEmpty)
          s.content!.trim(),
    ];
    return parts.join(' ');
  }

  Future<String> _generateSingle(
    String transcript,
    NotesDepth depth,
    LessonNotesInput? lesson,
  ) {
    return _llm.complete(
      model: kGroqNotesModel,
      messages: lesson == null
          ? [
              LlmMessage.system(_systemPrompt(depth)),
              LlmMessage.user(transcript),
            ]
          : [
              LlmMessage.system(lessonNotesPrompt(depth)),
              LlmMessage.user(
                lessonUserMessage(
                  transcript,
                  lesson,
                  maxExtraChars: kNotesExtrasGroqChars,
                ),
              ),
            ],
      temperature: 0.2,
      maxTokens: _maxTokens(depth),
    );
  }

  /// The whole lesson in one call: Gemini's context holds a lesson with every
  /// photo and answer, so nothing is summarised away before the notes.
  Future<String> _generateGemini(
    String transcript,
    NotesDepth depth,
    LessonNotesInput? lesson,
  ) {
    return gemini!.complete(
      model: kGeminiModel,
      messages: lesson == null
          ? [
              LlmMessage.system(_systemPrompt(depth)),
              LlmMessage.user(transcript),
            ]
          : [
              LlmMessage.system(lessonNotesPrompt(depth)),
              LlmMessage.user(lessonUserMessage(transcript, lesson)),
            ],
      temperature: 0.2,
      // Thinking counts against the cap too.
      maxTokens: _maxTokens(depth) + 4000,
      timeout: kGeminiNotesTimeout,
    );
  }

  /// Two passes for transcripts too long to hand over whole: summarise each
  /// window faithfully, then merge the summaries into one set of notes. Bounded
  /// by construction, and it keeps a two-hour meeting from failing outright.
  Future<String> _generateWindowed(
    String transcript,
    NotesDepth depth,
    LessonNotesInput? lesson,
  ) async {
    final windows = _split(transcript, kNotesWindowSize);
    AppLog.d(_tag, 'windowed pass: ${windows.length} windows');

    final summaries = <String>[];
    for (var i = 0; i < windows.length; i++) {
      final summary = await _llm.complete(
        model: kGroqNotesModel,
        messages: [
          LlmMessage.system(_windowPrompt(i + 1, windows.length)),
          LlmMessage.user(windows[i]),
        ],
        temperature: 0.2,
        maxTokens: 1200,
      );
      summaries.add('--- ${i + 1}/${windows.length} ---\n$summary');
    }

    return _llm.complete(
      model: kGroqNotesModel,
      messages: lesson == null
          ? [
              LlmMessage.system(
                '${_systemPrompt(depth)}\n\n'
                'The user message is not a transcript but a series of summaries '
                'of consecutive parts of one meeting. Merge them into a single '
                'set of notes, removing repetition and keeping the meeting in '
                'order. Do not mention the parts or their numbering.',
              ),
              LlmMessage.user(summaries.join('\n\n')),
            ]
          : [
              LlmMessage.system(
                '${lessonNotesPrompt(depth)}\n\n'
                'The "Přepis" block is not a transcript but a series of '
                'summaries of consecutive parts of the lesson. Merge them, '
                'removing repetition and keeping the lesson in order. Do not '
                'mention the parts or their numbering.',
              ),
              LlmMessage.user(
                lessonUserMessage(
                  summaries.join('\n\n'),
                  lesson,
                  maxExtraChars: kNotesExtrasGroqChars,
                ),
              ),
            ],
      temperature: 0.2,
      maxTokens: _maxTokens(depth),
    );
  }

  /// Splits on whitespace near each boundary, so a window never ends mid-word.
  static List<String> _split(String text, int size) {
    final out = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = start + size;
      if (end >= text.length) {
        out.add(text.substring(start));
        break;
      }
      final space = text.lastIndexOf(' ', end);
      if (space > start) end = space;
      out.add(text.substring(start, end));
      start = end;
    }
    return out;
  }

  /// Well above what the notes themselves need, because `max_tokens` also
  /// bounds the model's reasoning tokens and gpt-oss spends most of its budget
  /// there. Being stingy here does not save money — only used tokens are
  /// billed — it just truncates the end of the notes.
  static int _maxTokens(NotesDepth depth) => switch (depth) {
    NotesDepth.keywords => 1200,
    NotesDepth.brief => 1500,
    NotesDepth.standard => 3000,
    NotesDepth.detailed => 4500,
    NotesDepth.full => 6000,
  };

  /// Written in English deliberately: the instruction-following is noticeably
  /// steadier, and the language of the *output* is pinned by its own rule
  /// rather than by the language the instructions happen to be in.
  ///
  /// Kept short on purpose. An earlier version answered each bad habit with
  /// another prohibition — nine of them in the end — and the model started
  /// obeying them one at a time instead of writing: it opened a heading per
  /// task to satisfy "every task in the task list", then repeated the task
  /// below. Showing the shape of the output does what the prohibitions could
  /// not.
  static String _systemPrompt(NotesDepth depth) {
    return '''
You write the notes somebody reads tomorrow morning instead of listening to the
recording again. The material is an automatic transcript: it may contain
recognition errors and has no speaker labels.

Rules:
- Write in the same language as the transcript, headings included.
- Use only what was said. Invent no fact, name, number, date, decision or task,
  and never pad the list with a task nobody accepted.
- Leave out small talk that has nothing to do with what the meeting is about —
  what somebody is having for dinner, the weather, private chatter — unless the
  meeting itself is about it.
- Keep every number, amount, date and name that was said. A date the reader has
  to act on — the next meeting, a deadline, a delivery date — is never dropped.
- Sentences with verbs, active voice, people named: "Petr namítl, že by to
  mohlo ohrozit další zakázku". Not "obavy byly odmítnuty", not "Karel:
  přehled výdajů - pátek".
- Neutral in your own voice: "padlo rozhodnutí informovat zákazníka", not
  "rozhodli jsme se informovat zákazníka". Plain statements too, not only
  decisions: "na skladě zbývají tři kusy", never "na skladě nám zbývají tři
  kusy". The reader was not necessarily in the room, so "my" and "nám" have
  nobody to refer to. An owner is either a name somebody
  said out loud or the word "mluvčí" for whoever took the task on with "já to
  udělám" — never a role you inferred, such as "vedoucí porady". This holds at
  every depth: "Mluvčí pošle zákazníkovi vyjádření", never "Já pošlu
  zákazníkovi vyjádření".
- Every task somebody accepted appears in the task list at the end, as an
  instruction with its owner and its deadline. Never open a section of its own
  to hold a single task.
- Plain text: "- " for a bullet, "Nadpis:" alone on its line. No Markdown, no
  bold, no tables. Do not give a heading to a single fact — write that fact as
  one line with no heading above it. Never stretch a bullet or add a sentence
  to fill a section out: everything in the notes was said in the meeting, and
  a short section is better than a padded one.
- Notes only — no preamble, no closing remark, nothing about the transcript or
  about yourself. If a passage was unintelligible and it mattered, the very last
  line, after a blank line, is "Nejasné v přepisu: <the words as transcribed>".
  An unintelligible passage never appears anywhere else — not as a bullet, and
  above all not to pad a section out to its second bullet. A section with one
  thing to say is folded into a neighbouring one.

${_depthPrompt(depth)}''';
  }

  /// Each depth is given as the shape of the finished notes rather than as a
  /// description of them, section names in Czech because that is what this app
  /// is used in — the language rule above still decides the actual output.
  ///
  /// Each depth also carries a word budget. Without one the model decided the
  /// length itself, and „Vyvážené" came out nearly as short as „Jen to hlavní"
  /// while „Podrobné" ran on.
  static String _depthPrompt(NotesDepth depth) => switch (depth) {
    NotesDepth.keywords =>
      '''
At most 5 lines, about 40 words in total, and nothing else: no opening sentence,
no headings. This depth is the one exception to the rule about whole sentences:
each line begins with "- " and is a short keyword phrase. The shape, from an
unrelated meeting — take the form, never the content:

  - Kalkulace: Marek, do středy
  - Objednávka materiálu odložena do příchodu vzorku
  - Další schůzka čt 9:00

Only outcomes: decisions, accepted tasks with owner and deadline, dates. An
accepted task is never dropped; background and discussion always are. If
nothing was concluded, one line naming the topic and "bez závěru".''',
    NotesDepth.brief =>
      '''
Write 3 to 6 bullets, at most 80 words in total, and nothing else: no opening
sentence, no headings. The
shape, from an unrelated meeting — take the form, never the content:

  - Marek dodá revidovanou kalkulaci do středy.
  - Objednávka materiálu se odkládá, dokud nepřijde vzorek.
  - Další schůzka je ve čtvrtek v 9:00.

Every line begins with "- " and is a whole sentence with a verb, never a row of
fields strung together with dashes.

One line for every task somebody accepted, naming the person who took it on and
the deadline if one was said. Dropping an accepted task is the one mistake this
depth must not make: drop background before you drop a task. A task taken on in
the first person belongs to "mluvčí" — "Mluvčí napíše zákazníkovi", never "Já
napíšu zákazníkovi".

One line for every decision that was actually taken: a date that moved, one
option chosen over another, an agreement to tell somebody something. A line
that is nobody's task — a deadline that shifted, the date of the next meeting —
is written without an owner, and inventing one for it is worse than leaving it
plain. If a date was agreed for the next meeting, one of the lines is that.

No background, no discussion. If the meeting concluded nothing at all, write one
line saying what it was about and that nothing was decided.''',
    NotesDepth.standard =>
      '''
120 to 250 words — clearly more than a list of outcomes, for a reader who is
through it in a minute or two. The shape:

  <two or three sentences, no heading above them: what the meeting was about
  and what came out of it>

  Probírané body:
  - <one line per topic: what was said about it and where it ended up>

  Rozhodnutí:
  - <the decision, and the reason given for it if one was said>

  Úkoly:
  - <kdo> <co> <do kdy>

  Otevřené otázky:
  - ...

  Další schůzka: <kdy>

"Probírané body" is what makes this depth more than the short one: every topic
the meeting spent real time on gets its line, including one that ended without
a decision. Skip any other section the meeting produced nothing for. Each fact
belongs to one section only. If the meeting was too short to reach 120 words
without padding, write less — never pad.''',
    NotesDepth.detailed =>
      '''
300 to 550 words. The shape:

  <two or three sentences, no heading above them: what the meeting was about
  and what came out of it>

  <Téma>:
  - 2 to 4 bullets: the main points, the numbers and the arguments that
    decided it, and where the topic ended up
  - ...

  <Téma>:
  - ...

  Úkoly:
  - <kdo> <co> <do kdy>

  Další schůzka: <kdy>

One heading per topic, in the order the meeting took them, small related points
grouped under one heading. Keep what a reader needs to understand each outcome;
leave out asides, repetition and minor examples — that is what separates this
depth from the complete write-up. Leave out the last line if no next meeting was
agreed.''',
    NotesDepth.full =>
      '''
As long as the meeting needs: keep every argument, objection, example and number
that was said. The shape:

  <two or three sentences, no heading above them: what the meeting was about
  and what came out of it>

  <Téma>:
  - what was said about it, with the numbers and the reasoning, including any
    objection raised and how it was settled
  - ...

  <Téma>:
  - ...

  Úkoly:
  - <kdo> <co> <do kdy>

  Další schůzka: <kdy>

One heading per topic, in the order the meeting took them, and small related
points grouped under one heading rather than each getting its own. A topic
section says where that topic stands; the task list at the end collects the
same commitments as instructions, and at this depth that restatement is wanted.
Leave out the last line if no next meeting was agreed.''',
  };

  static String _windowPrompt(int index, int total) =>
      '''
You are given part $index of $total of one long recording's transcript, produced by
automatic speech recognition.

Summarise only this part, faithfully and in the same language as the transcript.
Keep every decision, task, number, date and name that appears in it. Do not
invent anything, and do not try to guess what the other parts contain. Plain
text, "- " for bullets, no preamble.''';
}
