import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/ai/term_alias_service.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/subject_terms_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/stt/term_corrections.dart';

class _FakeLlm extends LlmProvider {
  _FakeLlm(this.reply);

  final Object reply;
  final prompts = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    prompts.add(messages.last.content);
    final r = reply;
    if (r is Exception) throw r;
    return LlmCompletion(content: r as String);
  }
}

void main() {
  group('acceptAlias', () {
    test('an ordinary Czech word is never rewritten', () {
      expect(acceptAlias('tak', term: 'TCP'), isFalse);
      expect(acceptAlias('nebo ne', term: 'NAT'), isFalse);
      expect(acceptAlias('jak to', term: 'JIT'), isFalse);
    });

    test('a short form on its own is too likely by accident', () {
      expect(acceptAlias('lan', term: 'LAN'), isFalse);
      expect(acceptAlias('vílan', term: 'VLAN'), isTrue);
    });

    test('two words pass even when each is short', () {
      expect(acceptAlias('v lan', term: 'VLAN'), isTrue);
    });

    test('a form that folds to the term itself changes nothing', () {
      expect(acceptAlias('vlan', term: 'VLAN'), isFalse);
      expect(acceptAlias('Ospf', term: 'OSPF'), isFalse);
    });

    test('empty and overlong forms are refused', () {
      expect(acceptAlias('   ', term: 'VLAN'), isFalse);
      expect(acceptAlias('a' * 90, term: 'VLAN'), isFalse);
    });
  });

  group('parseTermAliases', () {
    test('keeps the allowed pairs and drops what the guard refuses', () {
      final out = parseTermAliases(
        '{"aliases": [{"term": "VLAN", "heard": ["vílan", "v lan", "lan", '
        '"tak"]}, {"term": "OSPF", "heard": "ó es pé ef"}]}',
        terms: ['VLAN', 'OSPF'],
      );
      expect(out, [
        (term: 'VLAN', heard: 'vílan'),
        (term: 'VLAN', heard: 'v lan'),
        (term: 'OSPF', heard: 'ó es pé ef'),
      ]);
    });

    test('a term nobody asked about cannot rewrite anything', () {
      final out = parseTermAliases(
        '{"aliases": [{"term": "Babička", "heard": ["babicka na horach"]}]}',
        terms: ['VLAN'],
      );
      expect(out, isEmpty);
    });

    test('the term is written the way the subject spells it', () {
      final out = parseTermAliases(
        '{"aliases": [{"term": "vlan", "heard": ["vílan"]}]}',
        terms: ['VLAN'],
      );
      expect(out, [(term: 'VLAN', heard: 'vílan')]);
    });

    test('at most three forms per term, deduplicated', () {
      final out = parseTermAliases(
        '{"aliases": [{"term": "VLAN", "heard": '
        '["vílan", "Vílan", "v lan", "ví lan", "vejlan"]}]}',
        terms: ['VLAN'],
      );
      expect(out.length, 3);
      expect(out.map((a) => a.heard), ['vílan', 'v lan', 'ví lan']);
    });

    test('junk is no aliases rather than a crash', () {
      expect(parseTermAliases('nope'), isEmpty);
      expect(parseTermAliases('{"aliases": "vílan"}'), isEmpty);
      expect(parseTermAliases('{"aliases": [{"term": 1}]}'), isEmpty);
    });
  });

  group('TermAliasService', () {
    late AppDatabase db;
    late int subject;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      subject = await db.savedNotesDao.createFolder('Počítačové sítě');
    });
    tearDown(() => db.close());

    test('the plan\'s terms are asked about and stored as corrections',
        () async {
      await db.subjectsDao.replaceTopics(
        subject,
        const [
          SyllabusTopicDraft(title: 'Směrování', terms: ['OSPF', 'VLAN']),
        ],
        SyllabusSource.pasted,
      );
      final llm = _FakeLlm(
        '{"aliases": [{"term": "VLAN", "heard": ["vílan", "v lan"]}, '
        '{"term": "OSPF", "heard": ["ó es pé ef"]}]}',
      );

      expect(await TermAliasService(db.subjectsDao, llm).generate(subject), 3);
      expect(llm.prompts.single, 'OSPF\nVLAN');

      final rows = await db.subjectsDao.terms(subject);
      final aliases = [
        for (final r in rows)
          if (r.source == TermSource.alias) (heard: r.heard, term: r.term),
      ];
      expect(aliases, hasLength(3));

      // The point of the whole feature: the deterministic pass now fixes the
      // mishearing on every chunk, with no AI in the lesson.
      expect(
        applyTermCorrections(
          'Nastavíme vílan a pak ó es pé ef.',
          [for (final a in aliases) (heard: a.heard!, term: a.term)],
        ).text,
        'Nastavíme VLAN a pak OSPF.',
      );
    });

    test('a failed call costs nothing and writes nothing', () async {
      await db.subjectsDao.addTerm(subject, 'VLAN');
      final llm = _FakeLlm(const AiTransientException('busy'));

      expect(await TermAliasService(db.subjectsDao, llm).generate(subject), 0);
      final rows = await db.subjectsDao.terms(subject);
      expect(rows.where((r) => r.source == TermSource.alias), isEmpty);
    });

    test('a subject with no vocabulary makes no request', () async {
      final llm = _FakeLlm('{"aliases": []}');
      expect(await TermAliasService(db.subjectsDao, llm).generate(subject), 0);
      expect(llm.prompts, isEmpty);
    });
  });
}
