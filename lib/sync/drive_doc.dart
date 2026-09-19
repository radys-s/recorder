import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/constants.dart';

/// One lesson's výpisky as they go into the subject's Google Doc.
class DocLesson {
  const DocLesson({
    required this.date,
    required this.notes,
    this.topic,
    this.important = const [],
    this.questions = const [],
  });

  final DateTime date;
  final String? topic;
  final String notes;
  final List<({String note, String excerpt})> important;
  final List<({String question, String answer})> questions;
}

/// A note saved in the subject itself, such as the subject summary.
class DocNote {
  const DocNote({required this.title, required this.content});
  final String title;
  final String content;
}

/// One finished lesson's transcript.
class DocTranscript {
  const DocTranscript({required this.date, required this.text, this.topic});
  final DateTime date;
  final String? topic;
  final String text;
}

String notesDocName(String subject) => '$kDriveFolderName – $subject';

String transcriptsDocName(String subject) =>
    '$kDriveFolderName – $subject – přepisy';

String htmlEscape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _bullet = RegExp(r'^\s*[-•*]\s+');

/// The prompts' plain text as HTML: `- ` lines become a list, a short line
/// ending in a colon a heading, anything else a paragraph — the same reading
/// the notes screen gives it.
String notesToHtml(String text) {
  final out = StringBuffer();
  var inList = false;
  void closeList() {
    if (inList) out.write('</ul>');
    inList = false;
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      closeList();
      continue;
    }
    if (_bullet.hasMatch(line)) {
      if (!inList) out.write('<ul>');
      inList = true;
      out.write('<li>${htmlEscape(line.replaceFirst(_bullet, ''))}</li>');
      continue;
    }
    closeList();
    if (line.length <= 60 && line.endsWith(':')) {
      out.write('<h3>${htmlEscape(line)}</h3>');
    } else {
      out.write('<p>${htmlEscape(line)}</p>');
    }
  }
  closeList();
  return out.toString();
}

String _date(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

String _lessonHeading(DateTime date, String? topic) {
  final t = topic?.trim();
  return '<h2>Hodina ${_date(date)}'
      '${t == null || t.isEmpty ? '' : ' · ${htmlEscape(t)}'}</h2>';
}

String _page(String title, String body) =>
    '<!DOCTYPE html><html><head><meta charset="utf-8">'
    '<title>${htmlEscape(title)}</title></head><body>$body</body></html>';

String _header(String subject, String? courseLine) {
  final course = courseLine?.trim();
  return '<h1>${htmlEscape(subject)}</h1>'
      '${course == null || course.isEmpty ? '' : '<p><i>${htmlEscape(course)}</i></p>'}';
}

/// The subject's výpisky doc, oldest lesson first. There is no timestamp in
/// it on purpose: the same content must give the same hash, or every sync
/// would upload again.
String notesDocHtml({
  required String subject,
  String? courseLine,
  required List<DocLesson> lessons,
  List<DocNote> notes = const [],
}) {
  final body = StringBuffer(_header(subject, courseLine));
  final sorted = [...lessons]..sort((a, b) => a.date.compareTo(b.date));
  for (final l in sorted) {
    body
      ..write(_lessonHeading(l.date, l.topic))
      ..write(notesToHtml(l.notes));
    final starred = [
      for (final i in l.important)
        if (i.note.trim().isNotEmpty || i.excerpt.trim().isNotEmpty) i,
    ];
    if (starred.isNotEmpty) {
      body.write('<h3>Označeno jako důležité</h3><ul>');
      for (final i in starred) {
        final note = i.note.trim();
        final excerpt = i.excerpt.trim();
        body.write(
          '<li>⭐ ${note.isEmpty ? '' : '<b>${htmlEscape(note)}</b>'}'
          '${note.isNotEmpty && excerpt.isNotEmpty ? ' — ' : ''}'
          '${htmlEscape(excerpt)}</li>',
        );
      }
      body.write('</ul>');
    }
    if (l.questions.isNotEmpty) {
      body.write('<h3>Otázky a odpovědi</h3><ul>');
      for (final q in l.questions) {
        body.write(
          '<li><b>${htmlEscape(q.question.trim())}</b><br>'
          '${htmlEscape(q.answer.trim())}</li>',
        );
      }
      body.write('</ul>');
    }
  }
  if (notes.isNotEmpty) {
    body.write('<h2>Poznámky předmětu</h2>');
    for (final n in notes) {
      body
        ..write('<h3>${htmlEscape(n.title.trim())}</h3>')
        ..write(notesToHtml(n.content));
    }
  }
  return _page(notesDocName(subject), body.toString());
}

final _sentenceEnd = RegExp(r'(?<=[.!?…])\s+');

/// Splits a transcript into paragraphs of about [target] characters, breaking
/// only after a sentence, so the doc reads as text and not as one wall.
List<String> transcriptParagraphs(String text, {int target = 900}) {
  final sentences = text
      .split(_sentenceEnd)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  final paragraphs = <String>[];
  final current = StringBuffer();
  for (final s in sentences) {
    if (current.isNotEmpty) current.write(' ');
    current.write(s);
    if (current.length >= target) {
      paragraphs.add(current.toString());
      current.clear();
    }
  }
  if (current.isNotEmpty) paragraphs.add(current.toString());
  return paragraphs;
}

/// The subject's transcripts doc, oldest lesson first. When everything does
/// not fit a Google Doc, the newest lessons win and the doc says what is
/// missing.
String transcriptsDocHtml({
  required String subject,
  String? courseLine,
  required List<DocTranscript> lessons,
  int maxChars = kDriveDocMaxChars,
}) {
  final newestFirst = [...lessons]..sort((a, b) => b.date.compareTo(a.date));
  final kept = <String>[];
  var used = 0;
  var dropped = 0;
  for (final l in newestFirst) {
    final text = l.text.trim();
    if (text.isEmpty) continue;
    final section = StringBuffer(_lessonHeading(l.date, l.topic));
    for (final p in transcriptParagraphs(text)) {
      section.write('<p>${htmlEscape(p)}</p>');
    }
    final html = section.toString();
    if (dropped > 0 || used + html.length > maxChars) {
      dropped++;
      continue;
    }
    kept.add(html);
    used += html.length;
  }
  final body = StringBuffer(_header('$subject – přepisy', courseLine));
  if (dropped > 0) {
    body.write(
      '<p><i>Starší hodiny ($dropped) se do dokumentu nevešly; '
      'jsou v aplikaci.</i></p>',
    );
  }
  for (final html in kept.reversed) {
    body.write(html);
  }
  return _page(transcriptsDocName(subject), body.toString());
}

/// What decides whether a doc needs uploading again.
String contentHash(String name, String html) =>
    sha256.convert(utf8.encode('$name\n$html')).toString();
