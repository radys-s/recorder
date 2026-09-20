// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MeetingsTable extends Meetings with TableInfo<$MeetingsTable, Meeting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interruptedMeta = const VerificationMeta(
    'interrupted',
  );
  @override
  late final GeneratedColumn<bool> interrupted = GeneratedColumn<bool>(
    'interrupted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("interrupted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rulesMeta = const VerificationMeta('rules');
  @override
  late final GeneratedColumn<String> rules = GeneratedColumn<String>(
    'rules',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioClearedAtMeta = const VerificationMeta(
    'audioClearedAt',
  );
  @override
  late final GeneratedColumn<DateTime> audioClearedAt =
      GeneratedColumn<DateTime>(
        'audio_cleared_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    endedAt,
    interrupted,
    subjectId,
    rules,
    topicId,
    audioClearedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meeting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('interrupted')) {
      context.handle(
        _interruptedMeta,
        interrupted.isAcceptableOrUnknown(
          data['interrupted']!,
          _interruptedMeta,
        ),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('rules')) {
      context.handle(
        _rulesMeta,
        rules.isAcceptableOrUnknown(data['rules']!, _rulesMeta),
      );
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    }
    if (data.containsKey('audio_cleared_at')) {
      context.handle(
        _audioClearedAtMeta,
        audioClearedAt.isAcceptableOrUnknown(
          data['audio_cleared_at']!,
          _audioClearedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meeting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meeting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      interrupted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}interrupted'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      rules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules'],
      ),
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topic_id'],
      ),
      audioClearedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}audio_cleared_at'],
      ),
    );
  }

  @override
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }
}

class Meeting extends DataClass implements Insertable<Meeting> {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime? endedAt;

  /// Set when startup had to close this meeting because the app died while it
  /// was recording. Persisted rather than derived: once `endedAt` is filled in
  /// the evidence is gone, and the list would quietly start claiming the
  /// recording ended normally.
  final bool interrupted;

  /// The subject this lesson belongs to; null for an ordinary meeting, which
  /// keeps the meeting prompts and notes.
  final int? subjectId;

  /// Rules for this lesson only, set at the start sheet. Rules typed into the
  /// chat later are chat messages and come after these.
  final String? rules;

  /// The plan topic the student picked for this lesson; null lets the app
  /// work it out from the date and what is being said.
  final int? topicId;

  /// When the chunk WAVs were deleted to free space. Null means the audio is
  /// still there. Persisted rather than derived from the file system, because
  /// "the directory is gone" and "the directory was never written" have to
  /// read differently to „Přepsat znovu".
  final DateTime? audioClearedAt;
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    this.endedAt,
    required this.interrupted,
    this.subjectId,
    this.rules,
    this.topicId,
    this.audioClearedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['interrupted'] = Variable<bool>(interrupted);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    if (!nullToAbsent || rules != null) {
      map['rules'] = Variable<String>(rules);
    }
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<int>(topicId);
    }
    if (!nullToAbsent || audioClearedAt != null) {
      map['audio_cleared_at'] = Variable<DateTime>(audioClearedAt);
    }
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      interrupted: Value(interrupted),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      rules: rules == null && nullToAbsent
          ? const Value.absent()
          : Value(rules),
      topicId: topicId == null && nullToAbsent
          ? const Value.absent()
          : Value(topicId),
      audioClearedAt: audioClearedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(audioClearedAt),
    );
  }

  factory Meeting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meeting(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      interrupted: serializer.fromJson<bool>(json['interrupted']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      rules: serializer.fromJson<String?>(json['rules']),
      topicId: serializer.fromJson<int?>(json['topicId']),
      audioClearedAt: serializer.fromJson<DateTime?>(json['audioClearedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'interrupted': serializer.toJson<bool>(interrupted),
      'subjectId': serializer.toJson<int?>(subjectId),
      'rules': serializer.toJson<String?>(rules),
      'topicId': serializer.toJson<int?>(topicId),
      'audioClearedAt': serializer.toJson<DateTime?>(audioClearedAt),
    };
  }

  Meeting copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    Value<DateTime?> endedAt = const Value.absent(),
    bool? interrupted,
    Value<int?> subjectId = const Value.absent(),
    Value<String?> rules = const Value.absent(),
    Value<int?> topicId = const Value.absent(),
    Value<DateTime?> audioClearedAt = const Value.absent(),
  }) => Meeting(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    interrupted: interrupted ?? this.interrupted,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    rules: rules.present ? rules.value : this.rules,
    topicId: topicId.present ? topicId.value : this.topicId,
    audioClearedAt: audioClearedAt.present
        ? audioClearedAt.value
        : this.audioClearedAt,
  );
  Meeting copyWithCompanion(MeetingsCompanion data) {
    return Meeting(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      interrupted: data.interrupted.present
          ? data.interrupted.value
          : this.interrupted,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      rules: data.rules.present ? data.rules.value : this.rules,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      audioClearedAt: data.audioClearedAt.present
          ? data.audioClearedAt.value
          : this.audioClearedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meeting(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('interrupted: $interrupted, ')
          ..write('subjectId: $subjectId, ')
          ..write('rules: $rules, ')
          ..write('topicId: $topicId, ')
          ..write('audioClearedAt: $audioClearedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    endedAt,
    interrupted,
    subjectId,
    rules,
    topicId,
    audioClearedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meeting &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.endedAt == this.endedAt &&
          other.interrupted == this.interrupted &&
          other.subjectId == this.subjectId &&
          other.rules == this.rules &&
          other.topicId == this.topicId &&
          other.audioClearedAt == this.audioClearedAt);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<bool> interrupted;
  final Value<int?> subjectId;
  final Value<String?> rules;
  final Value<int?> topicId;
  final Value<DateTime?> audioClearedAt;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rules = const Value.absent(),
    this.topicId = const Value.absent(),
    this.audioClearedAt = const Value.absent(),
  });
  MeetingsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rules = const Value.absent(),
    this.topicId = const Value.absent(),
    this.audioClearedAt = const Value.absent(),
  }) : title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Meeting> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? interrupted,
    Expression<int>? subjectId,
    Expression<String>? rules,
    Expression<int>? topicId,
    Expression<DateTime>? audioClearedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (interrupted != null) 'interrupted': interrupted,
      if (subjectId != null) 'subject_id': subjectId,
      if (rules != null) 'rules': rules,
      if (topicId != null) 'topic_id': topicId,
      if (audioClearedAt != null) 'audio_cleared_at': audioClearedAt,
    });
  }

  MeetingsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endedAt,
    Value<bool>? interrupted,
    Value<int?>? subjectId,
    Value<String?>? rules,
    Value<int?>? topicId,
    Value<DateTime?>? audioClearedAt,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      interrupted: interrupted ?? this.interrupted,
      subjectId: subjectId ?? this.subjectId,
      rules: rules ?? this.rules,
      topicId: topicId ?? this.topicId,
      audioClearedAt: audioClearedAt ?? this.audioClearedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (interrupted.present) {
      map['interrupted'] = Variable<bool>(interrupted.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (rules.present) {
      map['rules'] = Variable<String>(rules.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (audioClearedAt.present) {
      map['audio_cleared_at'] = Variable<DateTime>(audioClearedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('interrupted: $interrupted, ')
          ..write('subjectId: $subjectId, ')
          ..write('rules: $rules, ')
          ..write('topicId: $topicId, ')
          ..write('audioClearedAt: $audioClearedAt')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SegmentStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SegmentStatus>($TranscriptSegmentsTable.$converterstatus);
  static const VerificationMeta _localAudioPathMeta = const VerificationMeta(
    'localAudioPath',
  );
  @override
  late final GeneratedColumn<String> localAudioPath = GeneratedColumn<String>(
    'local_audio_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voicedMsMeta = const VerificationMeta(
    'voicedMs',
  );
  @override
  late final GeneratedColumn<int> voicedMs = GeneratedColumn<int>(
    'voiced_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawContentMeta = const VerificationMeta(
    'rawContent',
  );
  @override
  late final GeneratedColumn<String> rawContent = GeneratedColumn<String>(
    'raw_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cutReasonMeta = const VerificationMeta(
    'cutReason',
  );
  @override
  late final GeneratedColumn<String> cutReason = GeneratedColumn<String>(
    'cut_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    sequence,
    startMs,
    endMs,
    content,
    status,
    localAudioPath,
    createdAt,
    voicedMs,
    rawContent,
    confidence,
    cutReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('local_audio_path')) {
      context.handle(
        _localAudioPathMeta,
        localAudioPath.isAcceptableOrUnknown(
          data['local_audio_path']!,
          _localAudioPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localAudioPathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('voiced_ms')) {
      context.handle(
        _voicedMsMeta,
        voicedMs.isAcceptableOrUnknown(data['voiced_ms']!, _voicedMsMeta),
      );
    }
    if (data.containsKey('raw_content')) {
      context.handle(
        _rawContentMeta,
        rawContent.isAcceptableOrUnknown(data['raw_content']!, _rawContentMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('cut_reason')) {
      context.handle(
        _cutReasonMeta,
        cutReason.isAcceptableOrUnknown(data['cut_reason']!, _cutReasonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      status: $TranscriptSegmentsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      localAudioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_audio_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      voicedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voiced_ms'],
      ),
      rawContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_content'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      cutReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cut_reason'],
      ),
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SegmentStatus, int, int> $converterstatus =
      const EnumIndexConverter<SegmentStatus>(SegmentStatus.values);
}

class TranscriptSegment extends DataClass
    implements Insertable<TranscriptSegment> {
  final int id;
  final int meetingId;
  final int sequence;
  final int startMs;
  final int endMs;
  final String? content;
  final SegmentStatus status;
  final String localAudioPath;
  final DateTime createdAt;

  /// How much of the chunk sounded like speech when it was recorded. Lets the
  /// worker reject a transcript far longer than the speech it came from;
  /// null for rows written before v12, which skip that check.
  final int? voicedMs;

  /// What was heard before the user or the AI changed [content]; null while
  /// the text is untouched.
  final String? rawContent;

  /// How sure Whisper was: the duration-weighted mean `avg_logprob` of the
  /// segments it kept. Null when it reported none, or for rows before v17.
  final double? confidence;

  /// How the PCM chunk ended. Null only for rows written before v22.
  final String? cutReason;
  const TranscriptSegment({
    required this.id,
    required this.meetingId,
    required this.sequence,
    required this.startMs,
    required this.endMs,
    this.content,
    required this.status,
    required this.localAudioPath,
    required this.createdAt,
    this.voicedMs,
    this.rawContent,
    this.confidence,
    this.cutReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<int>(meetingId);
    map['sequence'] = Variable<int>(sequence);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    {
      map['status'] = Variable<int>(
        $TranscriptSegmentsTable.$converterstatus.toSql(status),
      );
    }
    map['local_audio_path'] = Variable<String>(localAudioPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || voicedMs != null) {
      map['voiced_ms'] = Variable<int>(voicedMs);
    }
    if (!nullToAbsent || rawContent != null) {
      map['raw_content'] = Variable<String>(rawContent);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    if (!nullToAbsent || cutReason != null) {
      map['cut_reason'] = Variable<String>(cutReason);
    }
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      sequence: Value(sequence),
      startMs: Value(startMs),
      endMs: Value(endMs),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      status: Value(status),
      localAudioPath: Value(localAudioPath),
      createdAt: Value(createdAt),
      voicedMs: voicedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(voicedMs),
      rawContent: rawContent == null && nullToAbsent
          ? const Value.absent()
          : Value(rawContent),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      cutReason: cutReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cutReason),
    );
  }

  factory TranscriptSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegment(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      content: serializer.fromJson<String?>(json['content']),
      status: $TranscriptSegmentsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      localAudioPath: serializer.fromJson<String>(json['localAudioPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      voicedMs: serializer.fromJson<int?>(json['voicedMs']),
      rawContent: serializer.fromJson<String?>(json['rawContent']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      cutReason: serializer.fromJson<String?>(json['cutReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<int>(meetingId),
      'sequence': serializer.toJson<int>(sequence),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'content': serializer.toJson<String?>(content),
      'status': serializer.toJson<int>(
        $TranscriptSegmentsTable.$converterstatus.toJson(status),
      ),
      'localAudioPath': serializer.toJson<String>(localAudioPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'voicedMs': serializer.toJson<int?>(voicedMs),
      'rawContent': serializer.toJson<String?>(rawContent),
      'confidence': serializer.toJson<double?>(confidence),
      'cutReason': serializer.toJson<String?>(cutReason),
    };
  }

  TranscriptSegment copyWith({
    int? id,
    int? meetingId,
    int? sequence,
    int? startMs,
    int? endMs,
    Value<String?> content = const Value.absent(),
    SegmentStatus? status,
    String? localAudioPath,
    DateTime? createdAt,
    Value<int?> voicedMs = const Value.absent(),
    Value<String?> rawContent = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    Value<String?> cutReason = const Value.absent(),
  }) => TranscriptSegment(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    sequence: sequence ?? this.sequence,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    content: content.present ? content.value : this.content,
    status: status ?? this.status,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    createdAt: createdAt ?? this.createdAt,
    voicedMs: voicedMs.present ? voicedMs.value : this.voicedMs,
    rawContent: rawContent.present ? rawContent.value : this.rawContent,
    confidence: confidence.present ? confidence.value : this.confidence,
    cutReason: cutReason.present ? cutReason.value : this.cutReason,
  );
  TranscriptSegment copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegment(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      content: data.content.present ? data.content.value : this.content,
      status: data.status.present ? data.status.value : this.status,
      localAudioPath: data.localAudioPath.present
          ? data.localAudioPath.value
          : this.localAudioPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      voicedMs: data.voicedMs.present ? data.voicedMs.value : this.voicedMs,
      rawContent: data.rawContent.present
          ? data.rawContent.value
          : this.rawContent,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      cutReason: data.cutReason.present ? data.cutReason.value : this.cutReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegment(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('localAudioPath: $localAudioPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('voicedMs: $voicedMs, ')
          ..write('rawContent: $rawContent, ')
          ..write('confidence: $confidence, ')
          ..write('cutReason: $cutReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    sequence,
    startMs,
    endMs,
    content,
    status,
    localAudioPath,
    createdAt,
    voicedMs,
    rawContent,
    confidence,
    cutReason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegment &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.sequence == this.sequence &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.content == this.content &&
          other.status == this.status &&
          other.localAudioPath == this.localAudioPath &&
          other.createdAt == this.createdAt &&
          other.voicedMs == this.voicedMs &&
          other.rawContent == this.rawContent &&
          other.confidence == this.confidence &&
          other.cutReason == this.cutReason);
}

class TranscriptSegmentsCompanion extends UpdateCompanion<TranscriptSegment> {
  final Value<int> id;
  final Value<int> meetingId;
  final Value<int> sequence;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String?> content;
  final Value<SegmentStatus> status;
  final Value<String> localAudioPath;
  final Value<DateTime> createdAt;
  final Value<int?> voicedMs;
  final Value<String?> rawContent;
  final Value<double?> confidence;
  final Value<String?> cutReason;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.localAudioPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.voicedMs = const Value.absent(),
    this.rawContent = const Value.absent(),
    this.confidence = const Value.absent(),
    this.cutReason = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required int meetingId,
    required int sequence,
    required int startMs,
    required int endMs,
    this.content = const Value.absent(),
    required SegmentStatus status,
    required String localAudioPath,
    required DateTime createdAt,
    this.voicedMs = const Value.absent(),
    this.rawContent = const Value.absent(),
    this.confidence = const Value.absent(),
    this.cutReason = const Value.absent(),
  }) : meetingId = Value(meetingId),
       sequence = Value(sequence),
       startMs = Value(startMs),
       endMs = Value(endMs),
       status = Value(status),
       localAudioPath = Value(localAudioPath),
       createdAt = Value(createdAt);
  static Insertable<TranscriptSegment> custom({
    Expression<int>? id,
    Expression<int>? meetingId,
    Expression<int>? sequence,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? content,
    Expression<int>? status,
    Expression<String>? localAudioPath,
    Expression<DateTime>? createdAt,
    Expression<int>? voicedMs,
    Expression<String>? rawContent,
    Expression<double>? confidence,
    Expression<String>? cutReason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (sequence != null) 'sequence': sequence,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (content != null) 'content': content,
      if (status != null) 'status': status,
      if (localAudioPath != null) 'local_audio_path': localAudioPath,
      if (createdAt != null) 'created_at': createdAt,
      if (voicedMs != null) 'voiced_ms': voicedMs,
      if (rawContent != null) 'raw_content': rawContent,
      if (confidence != null) 'confidence': confidence,
      if (cutReason != null) 'cut_reason': cutReason,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? meetingId,
    Value<int>? sequence,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String?>? content,
    Value<SegmentStatus>? status,
    Value<String>? localAudioPath,
    Value<DateTime>? createdAt,
    Value<int?>? voicedMs,
    Value<String?>? rawContent,
    Value<double?>? confidence,
    Value<String?>? cutReason,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      sequence: sequence ?? this.sequence,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      content: content ?? this.content,
      status: status ?? this.status,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      createdAt: createdAt ?? this.createdAt,
      voicedMs: voicedMs ?? this.voicedMs,
      rawContent: rawContent ?? this.rawContent,
      confidence: confidence ?? this.confidence,
      cutReason: cutReason ?? this.cutReason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $TranscriptSegmentsTable.$converterstatus.toSql(status.value),
      );
    }
    if (localAudioPath.present) {
      map['local_audio_path'] = Variable<String>(localAudioPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (voicedMs.present) {
      map['voiced_ms'] = Variable<int>(voicedMs.value);
    }
    if (rawContent.present) {
      map['raw_content'] = Variable<String>(rawContent.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (cutReason.present) {
      map['cut_reason'] = Variable<String>(cutReason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('localAudioPath: $localAudioPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('voicedMs: $voicedMs, ')
          ..write('rawContent: $rawContent, ')
          ..write('confidence: $confidence, ')
          ..write('cutReason: $cutReason')
          ..write(')'))
        .toString();
  }
}

class $UploadQueueTable extends UploadQueue
    with TableInfo<$UploadQueueTable, UploadQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UploadQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<int> segmentId = GeneratedColumn<int>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<QueueStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<QueueStatus>($UploadQueueTable.$converterstatus);
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    segmentId,
    meetingId,
    localFilePath,
    status,
    attemptCount,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upload_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<UploadQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UploadQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UploadQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      )!,
      status: $UploadQueueTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UploadQueueTable createAlias(String alias) {
    return $UploadQueueTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<QueueStatus, int, int> $converterstatus =
      const EnumIndexConverter<QueueStatus>(QueueStatus.values);
}

class UploadQueueData extends DataClass implements Insertable<UploadQueueData> {
  final int id;
  final int segmentId;
  final int meetingId;
  final String localFilePath;
  final QueueStatus status;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UploadQueueData({
    required this.id,
    required this.segmentId,
    required this.meetingId,
    required this.localFilePath,
    required this.status,
    required this.attemptCount,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['segment_id'] = Variable<int>(segmentId);
    map['meeting_id'] = Variable<int>(meetingId);
    map['local_file_path'] = Variable<String>(localFilePath);
    {
      map['status'] = Variable<int>(
        $UploadQueueTable.$converterstatus.toSql(status),
      );
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UploadQueueCompanion toCompanion(bool nullToAbsent) {
    return UploadQueueCompanion(
      id: Value(id),
      segmentId: Value(segmentId),
      meetingId: Value(meetingId),
      localFilePath: Value(localFilePath),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UploadQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UploadQueueData(
      id: serializer.fromJson<int>(json['id']),
      segmentId: serializer.fromJson<int>(json['segmentId']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      status: $UploadQueueTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'segmentId': serializer.toJson<int>(segmentId),
      'meetingId': serializer.toJson<int>(meetingId),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'status': serializer.toJson<int>(
        $UploadQueueTable.$converterstatus.toJson(status),
      ),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UploadQueueData copyWith({
    int? id,
    int? segmentId,
    int? meetingId,
    String? localFilePath,
    QueueStatus? status,
    int? attemptCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UploadQueueData(
    id: id ?? this.id,
    segmentId: segmentId ?? this.segmentId,
    meetingId: meetingId ?? this.meetingId,
    localFilePath: localFilePath ?? this.localFilePath,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UploadQueueData copyWithCompanion(UploadQueueCompanion data) {
    return UploadQueueData(
      id: data.id.present ? data.id.value : this.id,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueData(')
          ..write('id: $id, ')
          ..write('segmentId: $segmentId, ')
          ..write('meetingId: $meetingId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    segmentId,
    meetingId,
    localFilePath,
    status,
    attemptCount,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadQueueData &&
          other.id == this.id &&
          other.segmentId == this.segmentId &&
          other.meetingId == this.meetingId &&
          other.localFilePath == this.localFilePath &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UploadQueueCompanion extends UpdateCompanion<UploadQueueData> {
  final Value<int> id;
  final Value<int> segmentId;
  final Value<int> meetingId;
  final Value<String> localFilePath;
  final Value<QueueStatus> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UploadQueueCompanion({
    this.id = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UploadQueueCompanion.insert({
    this.id = const Value.absent(),
    required int segmentId,
    required int meetingId,
    required String localFilePath,
    required QueueStatus status,
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : segmentId = Value(segmentId),
       meetingId = Value(meetingId),
       localFilePath = Value(localFilePath),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UploadQueueData> custom({
    Expression<int>? id,
    Expression<int>? segmentId,
    Expression<int>? meetingId,
    Expression<String>? localFilePath,
    Expression<int>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (segmentId != null) 'segment_id': segmentId,
      if (meetingId != null) 'meeting_id': meetingId,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UploadQueueCompanion copyWith({
    Value<int>? id,
    Value<int>? segmentId,
    Value<int>? meetingId,
    Value<String>? localFilePath,
    Value<QueueStatus>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UploadQueueCompanion(
      id: id ?? this.id,
      segmentId: segmentId ?? this.segmentId,
      meetingId: meetingId ?? this.meetingId,
      localFilePath: localFilePath ?? this.localFilePath,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<int>(segmentId.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $UploadQueueTable.$converterstatus.toSql(status.value),
      );
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueCompanion(')
          ..write('id: $id, ')
          ..write('segmentId: $segmentId, ')
          ..write('meetingId: $meetingId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TranscriptLanguage, int>
  transcriptLanguage =
      GeneratedColumn<int>(
        'transcript_language',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TranscriptLanguage>(
        $PreferencesTable.$convertertranscriptLanguage,
      );
  @override
  late final GeneratedColumnWithTypeConverter<NotesDepth, int> notesDepth =
      GeneratedColumn<int>(
        'notes_depth',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
      ).withConverter<NotesDepth>($PreferencesTable.$converternotesDepth);
  static const VerificationMeta _liveAnswersEnabledMeta =
      const VerificationMeta('liveAnswersEnabled');
  @override
  late final GeneratedColumn<bool> liveAnswersEnabled = GeneratedColumn<bool>(
    'live_answers_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("live_answers_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _webAnswersEnabledMeta = const VerificationMeta(
    'webAnswersEnabled',
  );
  @override
  late final GeneratedColumn<bool> webAnswersEnabled = GeneratedColumn<bool>(
    'web_answers_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("web_answers_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MicSensitivity, int>
  micSensitivity = GeneratedColumn<int>(
    'mic_sensitivity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  ).withConverter<MicSensitivity>($PreferencesTable.$convertermicSensitivity);
  static const VerificationMeta _globalRulesMeta = const VerificationMeta(
    'globalRules',
  );
  @override
  late final GeneratedColumn<String> globalRules = GeneratedColumn<String>(
    'global_rules',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geminiModelOverrideMeta =
      const VerificationMeta('geminiModelOverride');
  @override
  late final GeneratedColumn<String> geminiModelOverride =
      GeneratedColumn<String>(
        'gemini_model_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _onboardingDismissedMeta =
      const VerificationMeta('onboardingDismissed');
  @override
  late final GeneratedColumn<bool> onboardingDismissed = GeneratedColumn<bool>(
    'onboarding_dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contextCorrectionMeta = const VerificationMeta(
    'contextCorrection',
  );
  @override
  late final GeneratedColumn<bool> contextCorrection = GeneratedColumn<bool>(
    'context_correction',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("context_correction" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _schoolNameMeta = const VerificationMeta(
    'schoolName',
  );
  @override
  late final GeneratedColumn<String> schoolName = GeneratedColumn<String>(
    'school_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SchoolType?, int> schoolType =
      GeneratedColumn<int>(
        'school_type',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<SchoolType?>($PreferencesTable.$converterschoolTypen);
  static const VerificationMeta _studyFieldMeta = const VerificationMeta(
    'studyField',
  );
  @override
  late final GeneratedColumn<String> studyField = GeneratedColumn<String>(
    'study_field',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _studyYearMeta = const VerificationMeta(
    'studyYear',
  );
  @override
  late final GeneratedColumn<int> studyYear = GeneratedColumn<int>(
    'study_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AudioRetention, int>
  audioRetention = GeneratedColumn<int>(
    'audio_retention',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  ).withConverter<AudioRetention>($PreferencesTable.$converteraudioRetention);
  @override
  late final GeneratedColumnWithTypeConverter<LessonReminder, int>
  lessonReminder = GeneratedColumn<int>(
    'lesson_reminder',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<LessonReminder>($PreferencesTable.$converterlessonReminder);
  static const VerificationMeta _googleClientIdMeta = const VerificationMeta(
    'googleClientId',
  );
  @override
  late final GeneratedColumn<String> googleClientId = GeneratedColumn<String>(
    'google_client_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _googleAccountEmailMeta =
      const VerificationMeta('googleAccountEmail');
  @override
  late final GeneratedColumn<String> googleAccountEmail =
      GeneratedColumn<String>(
        'google_account_email',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _driveSyncEnabledMeta = const VerificationMeta(
    'driveSyncEnabled',
  );
  @override
  late final GeneratedColumn<bool> driveSyncEnabled = GeneratedColumn<bool>(
    'drive_sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("drive_sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _driveIncludeTranscriptsMeta =
      const VerificationMeta('driveIncludeTranscripts');
  @override
  late final GeneratedColumn<bool> driveIncludeTranscripts =
      GeneratedColumn<bool>(
        'drive_include_transcripts',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("drive_include_transcripts" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _driveFolderIdMeta = const VerificationMeta(
    'driveFolderId',
  );
  @override
  late final GeneratedColumn<String> driveFolderId = GeneratedColumn<String>(
    'drive_folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transcriptLanguage,
    notesDepth,
    liveAnswersEnabled,
    webAnswersEnabled,
    micSensitivity,
    globalRules,
    geminiModelOverride,
    onboardingDismissed,
    contextCorrection,
    schoolName,
    schoolType,
    studyField,
    studyYear,
    audioRetention,
    lessonReminder,
    googleClientId,
    googleAccountEmail,
    driveSyncEnabled,
    driveIncludeTranscripts,
    driveFolderId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('live_answers_enabled')) {
      context.handle(
        _liveAnswersEnabledMeta,
        liveAnswersEnabled.isAcceptableOrUnknown(
          data['live_answers_enabled']!,
          _liveAnswersEnabledMeta,
        ),
      );
    }
    if (data.containsKey('web_answers_enabled')) {
      context.handle(
        _webAnswersEnabledMeta,
        webAnswersEnabled.isAcceptableOrUnknown(
          data['web_answers_enabled']!,
          _webAnswersEnabledMeta,
        ),
      );
    }
    if (data.containsKey('global_rules')) {
      context.handle(
        _globalRulesMeta,
        globalRules.isAcceptableOrUnknown(
          data['global_rules']!,
          _globalRulesMeta,
        ),
      );
    }
    if (data.containsKey('gemini_model_override')) {
      context.handle(
        _geminiModelOverrideMeta,
        geminiModelOverride.isAcceptableOrUnknown(
          data['gemini_model_override']!,
          _geminiModelOverrideMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_dismissed')) {
      context.handle(
        _onboardingDismissedMeta,
        onboardingDismissed.isAcceptableOrUnknown(
          data['onboarding_dismissed']!,
          _onboardingDismissedMeta,
        ),
      );
    }
    if (data.containsKey('context_correction')) {
      context.handle(
        _contextCorrectionMeta,
        contextCorrection.isAcceptableOrUnknown(
          data['context_correction']!,
          _contextCorrectionMeta,
        ),
      );
    }
    if (data.containsKey('school_name')) {
      context.handle(
        _schoolNameMeta,
        schoolName.isAcceptableOrUnknown(data['school_name']!, _schoolNameMeta),
      );
    }
    if (data.containsKey('study_field')) {
      context.handle(
        _studyFieldMeta,
        studyField.isAcceptableOrUnknown(data['study_field']!, _studyFieldMeta),
      );
    }
    if (data.containsKey('study_year')) {
      context.handle(
        _studyYearMeta,
        studyYear.isAcceptableOrUnknown(data['study_year']!, _studyYearMeta),
      );
    }
    if (data.containsKey('google_client_id')) {
      context.handle(
        _googleClientIdMeta,
        googleClientId.isAcceptableOrUnknown(
          data['google_client_id']!,
          _googleClientIdMeta,
        ),
      );
    }
    if (data.containsKey('google_account_email')) {
      context.handle(
        _googleAccountEmailMeta,
        googleAccountEmail.isAcceptableOrUnknown(
          data['google_account_email']!,
          _googleAccountEmailMeta,
        ),
      );
    }
    if (data.containsKey('drive_sync_enabled')) {
      context.handle(
        _driveSyncEnabledMeta,
        driveSyncEnabled.isAcceptableOrUnknown(
          data['drive_sync_enabled']!,
          _driveSyncEnabledMeta,
        ),
      );
    }
    if (data.containsKey('drive_include_transcripts')) {
      context.handle(
        _driveIncludeTranscriptsMeta,
        driveIncludeTranscripts.isAcceptableOrUnknown(
          data['drive_include_transcripts']!,
          _driveIncludeTranscriptsMeta,
        ),
      );
    }
    if (data.containsKey('drive_folder_id')) {
      context.handle(
        _driveFolderIdMeta,
        driveFolderId.isAcceptableOrUnknown(
          data['drive_folder_id']!,
          _driveFolderIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transcriptLanguage: $PreferencesTable.$convertertranscriptLanguage
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}transcript_language'],
            )!,
          ),
      notesDepth: $PreferencesTable.$converternotesDepth.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}notes_depth'],
        )!,
      ),
      liveAnswersEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}live_answers_enabled'],
      )!,
      webAnswersEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}web_answers_enabled'],
      )!,
      micSensitivity: $PreferencesTable.$convertermicSensitivity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}mic_sensitivity'],
        )!,
      ),
      globalRules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}global_rules'],
      ),
      geminiModelOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gemini_model_override'],
      ),
      onboardingDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_dismissed'],
      )!,
      contextCorrection: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}context_correction'],
      )!,
      schoolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_name'],
      ),
      schoolType: $PreferencesTable.$converterschoolTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}school_type'],
        ),
      ),
      studyField: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_field'],
      ),
      studyYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_year'],
      ),
      audioRetention: $PreferencesTable.$converteraudioRetention.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}audio_retention'],
        )!,
      ),
      lessonReminder: $PreferencesTable.$converterlessonReminder.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}lesson_reminder'],
        )!,
      ),
      googleClientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_client_id'],
      ),
      googleAccountEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_account_email'],
      ),
      driveSyncEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}drive_sync_enabled'],
      )!,
      driveIncludeTranscripts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}drive_include_transcripts'],
      )!,
      driveFolderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drive_folder_id'],
      ),
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TranscriptLanguage, int, int>
  $convertertranscriptLanguage = const EnumIndexConverter<TranscriptLanguage>(
    TranscriptLanguage.values,
  );
  static JsonTypeConverter2<NotesDepth, int, int> $converternotesDepth =
      const EnumIndexConverter<NotesDepth>(NotesDepth.values);
  static JsonTypeConverter2<MicSensitivity, int, int> $convertermicSensitivity =
      const EnumIndexConverter<MicSensitivity>(MicSensitivity.values);
  static JsonTypeConverter2<SchoolType, int, int> $converterschoolType =
      const EnumIndexConverter<SchoolType>(SchoolType.values);
  static JsonTypeConverter2<SchoolType?, int?, int?> $converterschoolTypen =
      JsonTypeConverter2.asNullable($converterschoolType);
  static JsonTypeConverter2<AudioRetention, int, int> $converteraudioRetention =
      const EnumIndexConverter<AudioRetention>(AudioRetention.values);
  static JsonTypeConverter2<LessonReminder, int, int> $converterlessonReminder =
      const EnumIndexConverter<LessonReminder>(LessonReminder.values);
}

class Preference extends DataClass implements Insertable<Preference> {
  final int id;

  /// Defaults are written as integer literals because `withDefault` needs a
  /// const expression and an enum's `.index` is not one. The names beside them
  /// are the contract: reorder either enum and these have to change too.
  final TranscriptLanguage transcriptLanguage;
  final NotesDepth notesDepth;
  final bool liveAnswersEnabled;

  /// Whether a question the meeting itself cannot answer is looked up on the
  /// web.
  ///
  /// Off by default, and deliberately not folded into [liveAnswersEnabled]:
  /// turning it on sends a question derived from a private meeting to a search
  /// index. Only the question sentence ever leaves the device — never the
  /// transcript — but that is still a decision the user makes knowingly rather
  /// than discovers later.
  final bool webAnswersEnabled;
  final MicSensitivity micSensitivity;

  /// How the AI should answer everywhere, unless a subject or lesson says
  /// otherwise.
  final String? globalRules;

  /// A Gemini model id picked in Settings; null follows the app's default.
  final String? geminiModelOverride;

  /// The first-run guide was closed by the user.
  final bool onboardingDismissed;

  /// Lesson transcripts get a second look that fixes misheard subject terms.
  final bool contextCorrection;

  /// The student's course: school, kind of school, field and year. All
  /// optional; filled in, they tell every prompt the level of the lessons.
  final String? schoolName;
  final SchoolType? schoolType;
  final String? studyField;
  final int? studyYear;

  /// How long a finished lesson's audio is kept. The transcript is never
  /// touched by this.
  final AudioRetention audioRetention;

  /// Whether the phone says a timetabled lesson is about to start, and when.
  final LessonReminder lessonReminder;

  /// Google Docs sync for NotebookLM. The OAuth client id is the student's
  /// own, from their own Google Cloud project; it is not a secret. The
  /// refresh token lives in the Keychain, never here.
  final String? googleClientId;
  final String? googleAccountEmail;
  final bool driveSyncEnabled;
  final bool driveIncludeTranscripts;

  /// The „Schůzky" folder the docs live in, once created.
  final String? driveFolderId;
  const Preference({
    required this.id,
    required this.transcriptLanguage,
    required this.notesDepth,
    required this.liveAnswersEnabled,
    required this.webAnswersEnabled,
    required this.micSensitivity,
    this.globalRules,
    this.geminiModelOverride,
    required this.onboardingDismissed,
    required this.contextCorrection,
    this.schoolName,
    this.schoolType,
    this.studyField,
    this.studyYear,
    required this.audioRetention,
    required this.lessonReminder,
    this.googleClientId,
    this.googleAccountEmail,
    required this.driveSyncEnabled,
    required this.driveIncludeTranscripts,
    this.driveFolderId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['transcript_language'] = Variable<int>(
        $PreferencesTable.$convertertranscriptLanguage.toSql(
          transcriptLanguage,
        ),
      );
    }
    {
      map['notes_depth'] = Variable<int>(
        $PreferencesTable.$converternotesDepth.toSql(notesDepth),
      );
    }
    map['live_answers_enabled'] = Variable<bool>(liveAnswersEnabled);
    map['web_answers_enabled'] = Variable<bool>(webAnswersEnabled);
    {
      map['mic_sensitivity'] = Variable<int>(
        $PreferencesTable.$convertermicSensitivity.toSql(micSensitivity),
      );
    }
    if (!nullToAbsent || globalRules != null) {
      map['global_rules'] = Variable<String>(globalRules);
    }
    if (!nullToAbsent || geminiModelOverride != null) {
      map['gemini_model_override'] = Variable<String>(geminiModelOverride);
    }
    map['onboarding_dismissed'] = Variable<bool>(onboardingDismissed);
    map['context_correction'] = Variable<bool>(contextCorrection);
    if (!nullToAbsent || schoolName != null) {
      map['school_name'] = Variable<String>(schoolName);
    }
    if (!nullToAbsent || schoolType != null) {
      map['school_type'] = Variable<int>(
        $PreferencesTable.$converterschoolTypen.toSql(schoolType),
      );
    }
    if (!nullToAbsent || studyField != null) {
      map['study_field'] = Variable<String>(studyField);
    }
    if (!nullToAbsent || studyYear != null) {
      map['study_year'] = Variable<int>(studyYear);
    }
    {
      map['audio_retention'] = Variable<int>(
        $PreferencesTable.$converteraudioRetention.toSql(audioRetention),
      );
    }
    {
      map['lesson_reminder'] = Variable<int>(
        $PreferencesTable.$converterlessonReminder.toSql(lessonReminder),
      );
    }
    if (!nullToAbsent || googleClientId != null) {
      map['google_client_id'] = Variable<String>(googleClientId);
    }
    if (!nullToAbsent || googleAccountEmail != null) {
      map['google_account_email'] = Variable<String>(googleAccountEmail);
    }
    map['drive_sync_enabled'] = Variable<bool>(driveSyncEnabled);
    map['drive_include_transcripts'] = Variable<bool>(driveIncludeTranscripts);
    if (!nullToAbsent || driveFolderId != null) {
      map['drive_folder_id'] = Variable<String>(driveFolderId);
    }
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(
      id: Value(id),
      transcriptLanguage: Value(transcriptLanguage),
      notesDepth: Value(notesDepth),
      liveAnswersEnabled: Value(liveAnswersEnabled),
      webAnswersEnabled: Value(webAnswersEnabled),
      micSensitivity: Value(micSensitivity),
      globalRules: globalRules == null && nullToAbsent
          ? const Value.absent()
          : Value(globalRules),
      geminiModelOverride: geminiModelOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(geminiModelOverride),
      onboardingDismissed: Value(onboardingDismissed),
      contextCorrection: Value(contextCorrection),
      schoolName: schoolName == null && nullToAbsent
          ? const Value.absent()
          : Value(schoolName),
      schoolType: schoolType == null && nullToAbsent
          ? const Value.absent()
          : Value(schoolType),
      studyField: studyField == null && nullToAbsent
          ? const Value.absent()
          : Value(studyField),
      studyYear: studyYear == null && nullToAbsent
          ? const Value.absent()
          : Value(studyYear),
      audioRetention: Value(audioRetention),
      lessonReminder: Value(lessonReminder),
      googleClientId: googleClientId == null && nullToAbsent
          ? const Value.absent()
          : Value(googleClientId),
      googleAccountEmail: googleAccountEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(googleAccountEmail),
      driveSyncEnabled: Value(driveSyncEnabled),
      driveIncludeTranscripts: Value(driveIncludeTranscripts),
      driveFolderId: driveFolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFolderId),
    );
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      id: serializer.fromJson<int>(json['id']),
      transcriptLanguage: $PreferencesTable.$convertertranscriptLanguage
          .fromJson(serializer.fromJson<int>(json['transcriptLanguage'])),
      notesDepth: $PreferencesTable.$converternotesDepth.fromJson(
        serializer.fromJson<int>(json['notesDepth']),
      ),
      liveAnswersEnabled: serializer.fromJson<bool>(json['liveAnswersEnabled']),
      webAnswersEnabled: serializer.fromJson<bool>(json['webAnswersEnabled']),
      micSensitivity: $PreferencesTable.$convertermicSensitivity.fromJson(
        serializer.fromJson<int>(json['micSensitivity']),
      ),
      globalRules: serializer.fromJson<String?>(json['globalRules']),
      geminiModelOverride: serializer.fromJson<String?>(
        json['geminiModelOverride'],
      ),
      onboardingDismissed: serializer.fromJson<bool>(
        json['onboardingDismissed'],
      ),
      contextCorrection: serializer.fromJson<bool>(json['contextCorrection']),
      schoolName: serializer.fromJson<String?>(json['schoolName']),
      schoolType: $PreferencesTable.$converterschoolTypen.fromJson(
        serializer.fromJson<int?>(json['schoolType']),
      ),
      studyField: serializer.fromJson<String?>(json['studyField']),
      studyYear: serializer.fromJson<int?>(json['studyYear']),
      audioRetention: $PreferencesTable.$converteraudioRetention.fromJson(
        serializer.fromJson<int>(json['audioRetention']),
      ),
      lessonReminder: $PreferencesTable.$converterlessonReminder.fromJson(
        serializer.fromJson<int>(json['lessonReminder']),
      ),
      googleClientId: serializer.fromJson<String?>(json['googleClientId']),
      googleAccountEmail: serializer.fromJson<String?>(
        json['googleAccountEmail'],
      ),
      driveSyncEnabled: serializer.fromJson<bool>(json['driveSyncEnabled']),
      driveIncludeTranscripts: serializer.fromJson<bool>(
        json['driveIncludeTranscripts'],
      ),
      driveFolderId: serializer.fromJson<String?>(json['driveFolderId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transcriptLanguage': serializer.toJson<int>(
        $PreferencesTable.$convertertranscriptLanguage.toJson(
          transcriptLanguage,
        ),
      ),
      'notesDepth': serializer.toJson<int>(
        $PreferencesTable.$converternotesDepth.toJson(notesDepth),
      ),
      'liveAnswersEnabled': serializer.toJson<bool>(liveAnswersEnabled),
      'webAnswersEnabled': serializer.toJson<bool>(webAnswersEnabled),
      'micSensitivity': serializer.toJson<int>(
        $PreferencesTable.$convertermicSensitivity.toJson(micSensitivity),
      ),
      'globalRules': serializer.toJson<String?>(globalRules),
      'geminiModelOverride': serializer.toJson<String?>(geminiModelOverride),
      'onboardingDismissed': serializer.toJson<bool>(onboardingDismissed),
      'contextCorrection': serializer.toJson<bool>(contextCorrection),
      'schoolName': serializer.toJson<String?>(schoolName),
      'schoolType': serializer.toJson<int?>(
        $PreferencesTable.$converterschoolTypen.toJson(schoolType),
      ),
      'studyField': serializer.toJson<String?>(studyField),
      'studyYear': serializer.toJson<int?>(studyYear),
      'audioRetention': serializer.toJson<int>(
        $PreferencesTable.$converteraudioRetention.toJson(audioRetention),
      ),
      'lessonReminder': serializer.toJson<int>(
        $PreferencesTable.$converterlessonReminder.toJson(lessonReminder),
      ),
      'googleClientId': serializer.toJson<String?>(googleClientId),
      'googleAccountEmail': serializer.toJson<String?>(googleAccountEmail),
      'driveSyncEnabled': serializer.toJson<bool>(driveSyncEnabled),
      'driveIncludeTranscripts': serializer.toJson<bool>(
        driveIncludeTranscripts,
      ),
      'driveFolderId': serializer.toJson<String?>(driveFolderId),
    };
  }

  Preference copyWith({
    int? id,
    TranscriptLanguage? transcriptLanguage,
    NotesDepth? notesDepth,
    bool? liveAnswersEnabled,
    bool? webAnswersEnabled,
    MicSensitivity? micSensitivity,
    Value<String?> globalRules = const Value.absent(),
    Value<String?> geminiModelOverride = const Value.absent(),
    bool? onboardingDismissed,
    bool? contextCorrection,
    Value<String?> schoolName = const Value.absent(),
    Value<SchoolType?> schoolType = const Value.absent(),
    Value<String?> studyField = const Value.absent(),
    Value<int?> studyYear = const Value.absent(),
    AudioRetention? audioRetention,
    LessonReminder? lessonReminder,
    Value<String?> googleClientId = const Value.absent(),
    Value<String?> googleAccountEmail = const Value.absent(),
    bool? driveSyncEnabled,
    bool? driveIncludeTranscripts,
    Value<String?> driveFolderId = const Value.absent(),
  }) => Preference(
    id: id ?? this.id,
    transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
    notesDepth: notesDepth ?? this.notesDepth,
    liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
    webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
    micSensitivity: micSensitivity ?? this.micSensitivity,
    globalRules: globalRules.present ? globalRules.value : this.globalRules,
    geminiModelOverride: geminiModelOverride.present
        ? geminiModelOverride.value
        : this.geminiModelOverride,
    onboardingDismissed: onboardingDismissed ?? this.onboardingDismissed,
    contextCorrection: contextCorrection ?? this.contextCorrection,
    schoolName: schoolName.present ? schoolName.value : this.schoolName,
    schoolType: schoolType.present ? schoolType.value : this.schoolType,
    studyField: studyField.present ? studyField.value : this.studyField,
    studyYear: studyYear.present ? studyYear.value : this.studyYear,
    audioRetention: audioRetention ?? this.audioRetention,
    lessonReminder: lessonReminder ?? this.lessonReminder,
    googleClientId: googleClientId.present
        ? googleClientId.value
        : this.googleClientId,
    googleAccountEmail: googleAccountEmail.present
        ? googleAccountEmail.value
        : this.googleAccountEmail,
    driveSyncEnabled: driveSyncEnabled ?? this.driveSyncEnabled,
    driveIncludeTranscripts:
        driveIncludeTranscripts ?? this.driveIncludeTranscripts,
    driveFolderId: driveFolderId.present
        ? driveFolderId.value
        : this.driveFolderId,
  );
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      id: data.id.present ? data.id.value : this.id,
      transcriptLanguage: data.transcriptLanguage.present
          ? data.transcriptLanguage.value
          : this.transcriptLanguage,
      notesDepth: data.notesDepth.present
          ? data.notesDepth.value
          : this.notesDepth,
      liveAnswersEnabled: data.liveAnswersEnabled.present
          ? data.liveAnswersEnabled.value
          : this.liveAnswersEnabled,
      webAnswersEnabled: data.webAnswersEnabled.present
          ? data.webAnswersEnabled.value
          : this.webAnswersEnabled,
      micSensitivity: data.micSensitivity.present
          ? data.micSensitivity.value
          : this.micSensitivity,
      globalRules: data.globalRules.present
          ? data.globalRules.value
          : this.globalRules,
      geminiModelOverride: data.geminiModelOverride.present
          ? data.geminiModelOverride.value
          : this.geminiModelOverride,
      onboardingDismissed: data.onboardingDismissed.present
          ? data.onboardingDismissed.value
          : this.onboardingDismissed,
      contextCorrection: data.contextCorrection.present
          ? data.contextCorrection.value
          : this.contextCorrection,
      schoolName: data.schoolName.present
          ? data.schoolName.value
          : this.schoolName,
      schoolType: data.schoolType.present
          ? data.schoolType.value
          : this.schoolType,
      studyField: data.studyField.present
          ? data.studyField.value
          : this.studyField,
      studyYear: data.studyYear.present ? data.studyYear.value : this.studyYear,
      audioRetention: data.audioRetention.present
          ? data.audioRetention.value
          : this.audioRetention,
      lessonReminder: data.lessonReminder.present
          ? data.lessonReminder.value
          : this.lessonReminder,
      googleClientId: data.googleClientId.present
          ? data.googleClientId.value
          : this.googleClientId,
      googleAccountEmail: data.googleAccountEmail.present
          ? data.googleAccountEmail.value
          : this.googleAccountEmail,
      driveSyncEnabled: data.driveSyncEnabled.present
          ? data.driveSyncEnabled.value
          : this.driveSyncEnabled,
      driveIncludeTranscripts: data.driveIncludeTranscripts.present
          ? data.driveIncludeTranscripts.value
          : this.driveIncludeTranscripts,
      driveFolderId: data.driveFolderId.present
          ? data.driveFolderId.value
          : this.driveFolderId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('id: $id, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('notesDepth: $notesDepth, ')
          ..write('liveAnswersEnabled: $liveAnswersEnabled, ')
          ..write('webAnswersEnabled: $webAnswersEnabled, ')
          ..write('micSensitivity: $micSensitivity, ')
          ..write('globalRules: $globalRules, ')
          ..write('geminiModelOverride: $geminiModelOverride, ')
          ..write('onboardingDismissed: $onboardingDismissed, ')
          ..write('contextCorrection: $contextCorrection, ')
          ..write('schoolName: $schoolName, ')
          ..write('schoolType: $schoolType, ')
          ..write('studyField: $studyField, ')
          ..write('studyYear: $studyYear, ')
          ..write('audioRetention: $audioRetention, ')
          ..write('lessonReminder: $lessonReminder, ')
          ..write('googleClientId: $googleClientId, ')
          ..write('googleAccountEmail: $googleAccountEmail, ')
          ..write('driveSyncEnabled: $driveSyncEnabled, ')
          ..write('driveIncludeTranscripts: $driveIncludeTranscripts, ')
          ..write('driveFolderId: $driveFolderId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    transcriptLanguage,
    notesDepth,
    liveAnswersEnabled,
    webAnswersEnabled,
    micSensitivity,
    globalRules,
    geminiModelOverride,
    onboardingDismissed,
    contextCorrection,
    schoolName,
    schoolType,
    studyField,
    studyYear,
    audioRetention,
    lessonReminder,
    googleClientId,
    googleAccountEmail,
    driveSyncEnabled,
    driveIncludeTranscripts,
    driveFolderId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.id == this.id &&
          other.transcriptLanguage == this.transcriptLanguage &&
          other.notesDepth == this.notesDepth &&
          other.liveAnswersEnabled == this.liveAnswersEnabled &&
          other.webAnswersEnabled == this.webAnswersEnabled &&
          other.micSensitivity == this.micSensitivity &&
          other.globalRules == this.globalRules &&
          other.geminiModelOverride == this.geminiModelOverride &&
          other.onboardingDismissed == this.onboardingDismissed &&
          other.contextCorrection == this.contextCorrection &&
          other.schoolName == this.schoolName &&
          other.schoolType == this.schoolType &&
          other.studyField == this.studyField &&
          other.studyYear == this.studyYear &&
          other.audioRetention == this.audioRetention &&
          other.lessonReminder == this.lessonReminder &&
          other.googleClientId == this.googleClientId &&
          other.googleAccountEmail == this.googleAccountEmail &&
          other.driveSyncEnabled == this.driveSyncEnabled &&
          other.driveIncludeTranscripts == this.driveIncludeTranscripts &&
          other.driveFolderId == this.driveFolderId);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<int> id;
  final Value<TranscriptLanguage> transcriptLanguage;
  final Value<NotesDepth> notesDepth;
  final Value<bool> liveAnswersEnabled;
  final Value<bool> webAnswersEnabled;
  final Value<MicSensitivity> micSensitivity;
  final Value<String?> globalRules;
  final Value<String?> geminiModelOverride;
  final Value<bool> onboardingDismissed;
  final Value<bool> contextCorrection;
  final Value<String?> schoolName;
  final Value<SchoolType?> schoolType;
  final Value<String?> studyField;
  final Value<int?> studyYear;
  final Value<AudioRetention> audioRetention;
  final Value<LessonReminder> lessonReminder;
  final Value<String?> googleClientId;
  final Value<String?> googleAccountEmail;
  final Value<bool> driveSyncEnabled;
  final Value<bool> driveIncludeTranscripts;
  final Value<String?> driveFolderId;
  const PreferencesCompanion({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
    this.globalRules = const Value.absent(),
    this.geminiModelOverride = const Value.absent(),
    this.onboardingDismissed = const Value.absent(),
    this.contextCorrection = const Value.absent(),
    this.schoolName = const Value.absent(),
    this.schoolType = const Value.absent(),
    this.studyField = const Value.absent(),
    this.studyYear = const Value.absent(),
    this.audioRetention = const Value.absent(),
    this.lessonReminder = const Value.absent(),
    this.googleClientId = const Value.absent(),
    this.googleAccountEmail = const Value.absent(),
    this.driveSyncEnabled = const Value.absent(),
    this.driveIncludeTranscripts = const Value.absent(),
    this.driveFolderId = const Value.absent(),
  });
  PreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
    this.globalRules = const Value.absent(),
    this.geminiModelOverride = const Value.absent(),
    this.onboardingDismissed = const Value.absent(),
    this.contextCorrection = const Value.absent(),
    this.schoolName = const Value.absent(),
    this.schoolType = const Value.absent(),
    this.studyField = const Value.absent(),
    this.studyYear = const Value.absent(),
    this.audioRetention = const Value.absent(),
    this.lessonReminder = const Value.absent(),
    this.googleClientId = const Value.absent(),
    this.googleAccountEmail = const Value.absent(),
    this.driveSyncEnabled = const Value.absent(),
    this.driveIncludeTranscripts = const Value.absent(),
    this.driveFolderId = const Value.absent(),
  });
  static Insertable<Preference> custom({
    Expression<int>? id,
    Expression<int>? transcriptLanguage,
    Expression<int>? notesDepth,
    Expression<bool>? liveAnswersEnabled,
    Expression<bool>? webAnswersEnabled,
    Expression<int>? micSensitivity,
    Expression<String>? globalRules,
    Expression<String>? geminiModelOverride,
    Expression<bool>? onboardingDismissed,
    Expression<bool>? contextCorrection,
    Expression<String>? schoolName,
    Expression<int>? schoolType,
    Expression<String>? studyField,
    Expression<int>? studyYear,
    Expression<int>? audioRetention,
    Expression<int>? lessonReminder,
    Expression<String>? googleClientId,
    Expression<String>? googleAccountEmail,
    Expression<bool>? driveSyncEnabled,
    Expression<bool>? driveIncludeTranscripts,
    Expression<String>? driveFolderId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transcriptLanguage != null) 'transcript_language': transcriptLanguage,
      if (notesDepth != null) 'notes_depth': notesDepth,
      if (liveAnswersEnabled != null)
        'live_answers_enabled': liveAnswersEnabled,
      if (webAnswersEnabled != null) 'web_answers_enabled': webAnswersEnabled,
      if (micSensitivity != null) 'mic_sensitivity': micSensitivity,
      if (globalRules != null) 'global_rules': globalRules,
      if (geminiModelOverride != null)
        'gemini_model_override': geminiModelOverride,
      if (onboardingDismissed != null)
        'onboarding_dismissed': onboardingDismissed,
      if (contextCorrection != null) 'context_correction': contextCorrection,
      if (schoolName != null) 'school_name': schoolName,
      if (schoolType != null) 'school_type': schoolType,
      if (studyField != null) 'study_field': studyField,
      if (studyYear != null) 'study_year': studyYear,
      if (audioRetention != null) 'audio_retention': audioRetention,
      if (lessonReminder != null) 'lesson_reminder': lessonReminder,
      if (googleClientId != null) 'google_client_id': googleClientId,
      if (googleAccountEmail != null)
        'google_account_email': googleAccountEmail,
      if (driveSyncEnabled != null) 'drive_sync_enabled': driveSyncEnabled,
      if (driveIncludeTranscripts != null)
        'drive_include_transcripts': driveIncludeTranscripts,
      if (driveFolderId != null) 'drive_folder_id': driveFolderId,
    });
  }

  PreferencesCompanion copyWith({
    Value<int>? id,
    Value<TranscriptLanguage>? transcriptLanguage,
    Value<NotesDepth>? notesDepth,
    Value<bool>? liveAnswersEnabled,
    Value<bool>? webAnswersEnabled,
    Value<MicSensitivity>? micSensitivity,
    Value<String?>? globalRules,
    Value<String?>? geminiModelOverride,
    Value<bool>? onboardingDismissed,
    Value<bool>? contextCorrection,
    Value<String?>? schoolName,
    Value<SchoolType?>? schoolType,
    Value<String?>? studyField,
    Value<int?>? studyYear,
    Value<AudioRetention>? audioRetention,
    Value<LessonReminder>? lessonReminder,
    Value<String?>? googleClientId,
    Value<String?>? googleAccountEmail,
    Value<bool>? driveSyncEnabled,
    Value<bool>? driveIncludeTranscripts,
    Value<String?>? driveFolderId,
  }) {
    return PreferencesCompanion(
      id: id ?? this.id,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      notesDepth: notesDepth ?? this.notesDepth,
      liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
      webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
      micSensitivity: micSensitivity ?? this.micSensitivity,
      globalRules: globalRules ?? this.globalRules,
      geminiModelOverride: geminiModelOverride ?? this.geminiModelOverride,
      onboardingDismissed: onboardingDismissed ?? this.onboardingDismissed,
      contextCorrection: contextCorrection ?? this.contextCorrection,
      schoolName: schoolName ?? this.schoolName,
      schoolType: schoolType ?? this.schoolType,
      studyField: studyField ?? this.studyField,
      studyYear: studyYear ?? this.studyYear,
      audioRetention: audioRetention ?? this.audioRetention,
      lessonReminder: lessonReminder ?? this.lessonReminder,
      googleClientId: googleClientId ?? this.googleClientId,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      driveSyncEnabled: driveSyncEnabled ?? this.driveSyncEnabled,
      driveIncludeTranscripts:
          driveIncludeTranscripts ?? this.driveIncludeTranscripts,
      driveFolderId: driveFolderId ?? this.driveFolderId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transcriptLanguage.present) {
      map['transcript_language'] = Variable<int>(
        $PreferencesTable.$convertertranscriptLanguage.toSql(
          transcriptLanguage.value,
        ),
      );
    }
    if (notesDepth.present) {
      map['notes_depth'] = Variable<int>(
        $PreferencesTable.$converternotesDepth.toSql(notesDepth.value),
      );
    }
    if (liveAnswersEnabled.present) {
      map['live_answers_enabled'] = Variable<bool>(liveAnswersEnabled.value);
    }
    if (webAnswersEnabled.present) {
      map['web_answers_enabled'] = Variable<bool>(webAnswersEnabled.value);
    }
    if (micSensitivity.present) {
      map['mic_sensitivity'] = Variable<int>(
        $PreferencesTable.$convertermicSensitivity.toSql(micSensitivity.value),
      );
    }
    if (globalRules.present) {
      map['global_rules'] = Variable<String>(globalRules.value);
    }
    if (geminiModelOverride.present) {
      map['gemini_model_override'] = Variable<String>(
        geminiModelOverride.value,
      );
    }
    if (onboardingDismissed.present) {
      map['onboarding_dismissed'] = Variable<bool>(onboardingDismissed.value);
    }
    if (contextCorrection.present) {
      map['context_correction'] = Variable<bool>(contextCorrection.value);
    }
    if (schoolName.present) {
      map['school_name'] = Variable<String>(schoolName.value);
    }
    if (schoolType.present) {
      map['school_type'] = Variable<int>(
        $PreferencesTable.$converterschoolTypen.toSql(schoolType.value),
      );
    }
    if (studyField.present) {
      map['study_field'] = Variable<String>(studyField.value);
    }
    if (studyYear.present) {
      map['study_year'] = Variable<int>(studyYear.value);
    }
    if (audioRetention.present) {
      map['audio_retention'] = Variable<int>(
        $PreferencesTable.$converteraudioRetention.toSql(audioRetention.value),
      );
    }
    if (lessonReminder.present) {
      map['lesson_reminder'] = Variable<int>(
        $PreferencesTable.$converterlessonReminder.toSql(lessonReminder.value),
      );
    }
    if (googleClientId.present) {
      map['google_client_id'] = Variable<String>(googleClientId.value);
    }
    if (googleAccountEmail.present) {
      map['google_account_email'] = Variable<String>(googleAccountEmail.value);
    }
    if (driveSyncEnabled.present) {
      map['drive_sync_enabled'] = Variable<bool>(driveSyncEnabled.value);
    }
    if (driveIncludeTranscripts.present) {
      map['drive_include_transcripts'] = Variable<bool>(
        driveIncludeTranscripts.value,
      );
    }
    if (driveFolderId.present) {
      map['drive_folder_id'] = Variable<String>(driveFolderId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('id: $id, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('notesDepth: $notesDepth, ')
          ..write('liveAnswersEnabled: $liveAnswersEnabled, ')
          ..write('webAnswersEnabled: $webAnswersEnabled, ')
          ..write('micSensitivity: $micSensitivity, ')
          ..write('globalRules: $globalRules, ')
          ..write('geminiModelOverride: $geminiModelOverride, ')
          ..write('onboardingDismissed: $onboardingDismissed, ')
          ..write('contextCorrection: $contextCorrection, ')
          ..write('schoolName: $schoolName, ')
          ..write('schoolType: $schoolType, ')
          ..write('studyField: $studyField, ')
          ..write('studyYear: $studyYear, ')
          ..write('audioRetention: $audioRetention, ')
          ..write('lessonReminder: $lessonReminder, ')
          ..write('googleClientId: $googleClientId, ')
          ..write('googleAccountEmail: $googleAccountEmail, ')
          ..write('driveSyncEnabled: $driveSyncEnabled, ')
          ..write('driveIncludeTranscripts: $driveIncludeTranscripts, ')
          ..write('driveFolderId: $driveFolderId')
          ..write(')'))
        .toString();
  }
}

class $MeetingNotesTable extends MeetingNotes
    with TableInfo<$MeetingNotesTable, MeetingNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NotesDepth, int> depth =
      GeneratedColumn<int>(
        'depth',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<NotesDepth>($MeetingNotesTable.$converterdepth);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NotesStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<NotesStatus>($MeetingNotesTable.$converterstatus);
  static const VerificationMeta _cardSuggestionsMeta = const VerificationMeta(
    'cardSuggestions',
  );
  @override
  late final GeneratedColumn<String> cardSuggestions = GeneratedColumn<String>(
    'card_suggestions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    depth,
    content,
    model,
    status,
    cardSuggestions,
    error,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meeting_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('card_suggestions')) {
      context.handle(
        _cardSuggestionsMeta,
        cardSuggestions.isAcceptableOrUnknown(
          data['card_suggestions']!,
          _cardSuggestionsMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {meetingId},
  ];
  @override
  MeetingNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      depth: $MeetingNotesTable.$converterdepth.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}depth'],
        )!,
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      status: $MeetingNotesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      cardSuggestions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_suggestions'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MeetingNotesTable createAlias(String alias) {
    return $MeetingNotesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NotesDepth, int, int> $converterdepth =
      const EnumIndexConverter<NotesDepth>(NotesDepth.values);
  static JsonTypeConverter2<NotesStatus, int, int> $converterstatus =
      const EnumIndexConverter<NotesStatus>(NotesStatus.values);
}

class MeetingNote extends DataClass implements Insertable<MeetingNote> {
  final int id;
  final int meetingId;
  final NotesDepth depth;

  /// Null until the first generation succeeds. Kept across a regenerate, so a
  /// failed one leaves the previous notes readable rather than wiping them.
  final String? content;

  /// Which model produced [content] — worth recording, because the notes will
  /// outlive the model id that made them.
  final String model;
  final NotesStatus status;

  /// Up to three topics from a lesson's notes worth keeping as cards, as JSON
  /// (`encodeCardSuggestions`). Cleared whenever new notes land; entries are
  /// removed as the student adds or dismisses them.
  final String? cardSuggestions;
  final String? error;
  final DateTime createdAt;
  const MeetingNote({
    required this.id,
    required this.meetingId,
    required this.depth,
    this.content,
    required this.model,
    required this.status,
    this.cardSuggestions,
    this.error,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<int>(meetingId);
    {
      map['depth'] = Variable<int>(
        $MeetingNotesTable.$converterdepth.toSql(depth),
      );
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['model'] = Variable<String>(model);
    {
      map['status'] = Variable<int>(
        $MeetingNotesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || cardSuggestions != null) {
      map['card_suggestions'] = Variable<String>(cardSuggestions);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MeetingNotesCompanion toCompanion(bool nullToAbsent) {
    return MeetingNotesCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      depth: Value(depth),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      model: Value(model),
      status: Value(status),
      cardSuggestions: cardSuggestions == null && nullToAbsent
          ? const Value.absent()
          : Value(cardSuggestions),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
    );
  }

  factory MeetingNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingNote(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      depth: $MeetingNotesTable.$converterdepth.fromJson(
        serializer.fromJson<int>(json['depth']),
      ),
      content: serializer.fromJson<String?>(json['content']),
      model: serializer.fromJson<String>(json['model']),
      status: $MeetingNotesTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      cardSuggestions: serializer.fromJson<String?>(json['cardSuggestions']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<int>(meetingId),
      'depth': serializer.toJson<int>(
        $MeetingNotesTable.$converterdepth.toJson(depth),
      ),
      'content': serializer.toJson<String?>(content),
      'model': serializer.toJson<String>(model),
      'status': serializer.toJson<int>(
        $MeetingNotesTable.$converterstatus.toJson(status),
      ),
      'cardSuggestions': serializer.toJson<String?>(cardSuggestions),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MeetingNote copyWith({
    int? id,
    int? meetingId,
    NotesDepth? depth,
    Value<String?> content = const Value.absent(),
    String? model,
    NotesStatus? status,
    Value<String?> cardSuggestions = const Value.absent(),
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
  }) => MeetingNote(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    depth: depth ?? this.depth,
    content: content.present ? content.value : this.content,
    model: model ?? this.model,
    status: status ?? this.status,
    cardSuggestions: cardSuggestions.present
        ? cardSuggestions.value
        : this.cardSuggestions,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
  );
  MeetingNote copyWithCompanion(MeetingNotesCompanion data) {
    return MeetingNote(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      depth: data.depth.present ? data.depth.value : this.depth,
      content: data.content.present ? data.content.value : this.content,
      model: data.model.present ? data.model.value : this.model,
      status: data.status.present ? data.status.value : this.status,
      cardSuggestions: data.cardSuggestions.present
          ? data.cardSuggestions.value
          : this.cardSuggestions,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingNote(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('depth: $depth, ')
          ..write('content: $content, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('cardSuggestions: $cardSuggestions, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    depth,
    content,
    model,
    status,
    cardSuggestions,
    error,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingNote &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.depth == this.depth &&
          other.content == this.content &&
          other.model == this.model &&
          other.status == this.status &&
          other.cardSuggestions == this.cardSuggestions &&
          other.error == this.error &&
          other.createdAt == this.createdAt);
}

class MeetingNotesCompanion extends UpdateCompanion<MeetingNote> {
  final Value<int> id;
  final Value<int> meetingId;
  final Value<NotesDepth> depth;
  final Value<String?> content;
  final Value<String> model;
  final Value<NotesStatus> status;
  final Value<String?> cardSuggestions;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  const MeetingNotesCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.depth = const Value.absent(),
    this.content = const Value.absent(),
    this.model = const Value.absent(),
    this.status = const Value.absent(),
    this.cardSuggestions = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MeetingNotesCompanion.insert({
    this.id = const Value.absent(),
    required int meetingId,
    required NotesDepth depth,
    this.content = const Value.absent(),
    required String model,
    required NotesStatus status,
    this.cardSuggestions = const Value.absent(),
    this.error = const Value.absent(),
    required DateTime createdAt,
  }) : meetingId = Value(meetingId),
       depth = Value(depth),
       model = Value(model),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<MeetingNote> custom({
    Expression<int>? id,
    Expression<int>? meetingId,
    Expression<int>? depth,
    Expression<String>? content,
    Expression<String>? model,
    Expression<int>? status,
    Expression<String>? cardSuggestions,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (depth != null) 'depth': depth,
      if (content != null) 'content': content,
      if (model != null) 'model': model,
      if (status != null) 'status': status,
      if (cardSuggestions != null) 'card_suggestions': cardSuggestions,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MeetingNotesCompanion copyWith({
    Value<int>? id,
    Value<int>? meetingId,
    Value<NotesDepth>? depth,
    Value<String?>? content,
    Value<String>? model,
    Value<NotesStatus>? status,
    Value<String?>? cardSuggestions,
    Value<String?>? error,
    Value<DateTime>? createdAt,
  }) {
    return MeetingNotesCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      depth: depth ?? this.depth,
      content: content ?? this.content,
      model: model ?? this.model,
      status: status ?? this.status,
      cardSuggestions: cardSuggestions ?? this.cardSuggestions,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(
        $MeetingNotesTable.$converterdepth.toSql(depth.value),
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $MeetingNotesTable.$converterstatus.toSql(status.value),
      );
    }
    if (cardSuggestions.present) {
      map['card_suggestions'] = Variable<String>(cardSuggestions.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingNotesCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('depth: $depth, ')
          ..write('content: $content, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('cardSuggestions: $cardSuggestions, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AnswerCardsTable extends AnswerCards
    with TableInfo<$AnswerCardsTable, AnswerCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnswerCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<int> segmentId = GeneratedColumn<int>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('meeting'),
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    segmentId,
    question,
    answer,
    basis,
    sources,
    detail,
    cardId,
    dismissed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'answer_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnswerCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnswerCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnswerCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      ),
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AnswerCardsTable createAlias(String alias) {
    return $AnswerCardsTable(attachedDatabase, alias);
  }
}

class AnswerCard extends DataClass implements Insertable<AnswerCard> {
  final int id;
  final int meetingId;

  /// The transcript segment the question was heard in. The card is rendered
  /// directly after that segment, so the answer sits where the question was
  /// asked rather than at the end of the timeline.
  final int segmentId;
  final String question;
  final String answer;

  /// Where the answer came from: `meeting` when it is in what was said,
  /// `knowledge` when the model answered from its own general knowledge,
  /// `unknown` when neither could settle it, and `web` when it was looked up
  /// on the internet.
  ///
  /// `web` is the only one the app writes rather than the model: it is set
  /// after a successful web hop, so it cannot be produced by a model that
  /// merely claims to have searched.
  ///
  /// Stored as text rather than an enum because it is a label from the model,
  /// not a value the app branches on — an unrecognised one renders as no badge
  /// instead of crashing a screen mid-meeting. The badge exists because the
  /// user's standing rule is that the app must not put words in their mouth:
  /// an answer that comes from outside the room has to say so.
  final String basis;

  /// The pages a `web` answer was drawn from: a JSON array of
  /// `{title, url}`, capped at three, or null when there are none.
  ///
  /// JSON in a column rather than a table of its own — nothing ever queries
  /// across sources, and a nullable column is the whole migration for every
  /// card written before web answers existed.
  final String? sources;

  /// The explanation behind [answer], which in class mode is one short line.
  /// Null on cards written before that split.
  final String? detail;

  /// The context card the answer was drawn from, when basis is `card`.
  final int? cardId;

  /// Set by the close button on the pinned panel. Dismissing hides the panel,
  /// never the timeline card — the answer stays part of the meeting's record.
  final bool dismissed;
  final DateTime createdAt;
  const AnswerCard({
    required this.id,
    required this.meetingId,
    required this.segmentId,
    required this.question,
    required this.answer,
    required this.basis,
    this.sources,
    this.detail,
    this.cardId,
    required this.dismissed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<int>(meetingId);
    map['segment_id'] = Variable<int>(segmentId);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['basis'] = Variable<String>(basis);
    if (!nullToAbsent || sources != null) {
      map['sources'] = Variable<String>(sources);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || cardId != null) {
      map['card_id'] = Variable<int>(cardId);
    }
    map['dismissed'] = Variable<bool>(dismissed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnswerCardsCompanion toCompanion(bool nullToAbsent) {
    return AnswerCardsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      segmentId: Value(segmentId),
      question: Value(question),
      answer: Value(answer),
      basis: Value(basis),
      sources: sources == null && nullToAbsent
          ? const Value.absent()
          : Value(sources),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      cardId: cardId == null && nullToAbsent
          ? const Value.absent()
          : Value(cardId),
      dismissed: Value(dismissed),
      createdAt: Value(createdAt),
    );
  }

  factory AnswerCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnswerCard(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      segmentId: serializer.fromJson<int>(json['segmentId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      basis: serializer.fromJson<String>(json['basis']),
      sources: serializer.fromJson<String?>(json['sources']),
      detail: serializer.fromJson<String?>(json['detail']),
      cardId: serializer.fromJson<int?>(json['cardId']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<int>(meetingId),
      'segmentId': serializer.toJson<int>(segmentId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'basis': serializer.toJson<String>(basis),
      'sources': serializer.toJson<String?>(sources),
      'detail': serializer.toJson<String?>(detail),
      'cardId': serializer.toJson<int?>(cardId),
      'dismissed': serializer.toJson<bool>(dismissed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnswerCard copyWith({
    int? id,
    int? meetingId,
    int? segmentId,
    String? question,
    String? answer,
    String? basis,
    Value<String?> sources = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    Value<int?> cardId = const Value.absent(),
    bool? dismissed,
    DateTime? createdAt,
  }) => AnswerCard(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    segmentId: segmentId ?? this.segmentId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    basis: basis ?? this.basis,
    sources: sources.present ? sources.value : this.sources,
    detail: detail.present ? detail.value : this.detail,
    cardId: cardId.present ? cardId.value : this.cardId,
    dismissed: dismissed ?? this.dismissed,
    createdAt: createdAt ?? this.createdAt,
  );
  AnswerCard copyWithCompanion(AnswerCardsCompanion data) {
    return AnswerCard(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      basis: data.basis.present ? data.basis.value : this.basis,
      sources: data.sources.present ? data.sources.value : this.sources,
      detail: data.detail.present ? data.detail.value : this.detail,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnswerCard(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('segmentId: $segmentId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('detail: $detail, ')
          ..write('cardId: $cardId, ')
          ..write('dismissed: $dismissed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    segmentId,
    question,
    answer,
    basis,
    sources,
    detail,
    cardId,
    dismissed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnswerCard &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.segmentId == this.segmentId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.basis == this.basis &&
          other.sources == this.sources &&
          other.detail == this.detail &&
          other.cardId == this.cardId &&
          other.dismissed == this.dismissed &&
          other.createdAt == this.createdAt);
}

class AnswerCardsCompanion extends UpdateCompanion<AnswerCard> {
  final Value<int> id;
  final Value<int> meetingId;
  final Value<int> segmentId;
  final Value<String> question;
  final Value<String> answer;
  final Value<String> basis;
  final Value<String?> sources;
  final Value<String?> detail;
  final Value<int?> cardId;
  final Value<bool> dismissed;
  final Value<DateTime> createdAt;
  const AnswerCardsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.basis = const Value.absent(),
    this.sources = const Value.absent(),
    this.detail = const Value.absent(),
    this.cardId = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AnswerCardsCompanion.insert({
    this.id = const Value.absent(),
    required int meetingId,
    required int segmentId,
    required String question,
    required String answer,
    this.basis = const Value.absent(),
    this.sources = const Value.absent(),
    this.detail = const Value.absent(),
    this.cardId = const Value.absent(),
    this.dismissed = const Value.absent(),
    required DateTime createdAt,
  }) : meetingId = Value(meetingId),
       segmentId = Value(segmentId),
       question = Value(question),
       answer = Value(answer),
       createdAt = Value(createdAt);
  static Insertable<AnswerCard> custom({
    Expression<int>? id,
    Expression<int>? meetingId,
    Expression<int>? segmentId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? basis,
    Expression<String>? sources,
    Expression<String>? detail,
    Expression<int>? cardId,
    Expression<bool>? dismissed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (segmentId != null) 'segment_id': segmentId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (basis != null) 'basis': basis,
      if (sources != null) 'sources': sources,
      if (detail != null) 'detail': detail,
      if (cardId != null) 'card_id': cardId,
      if (dismissed != null) 'dismissed': dismissed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AnswerCardsCompanion copyWith({
    Value<int>? id,
    Value<int>? meetingId,
    Value<int>? segmentId,
    Value<String>? question,
    Value<String>? answer,
    Value<String>? basis,
    Value<String?>? sources,
    Value<String?>? detail,
    Value<int?>? cardId,
    Value<bool>? dismissed,
    Value<DateTime>? createdAt,
  }) {
    return AnswerCardsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      segmentId: segmentId ?? this.segmentId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      basis: basis ?? this.basis,
      sources: sources ?? this.sources,
      detail: detail ?? this.detail,
      cardId: cardId ?? this.cardId,
      dismissed: dismissed ?? this.dismissed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<int>(segmentId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnswerCardsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('segmentId: $segmentId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('detail: $detail, ')
          ..write('cardId: $cardId, ')
          ..write('dismissed: $dismissed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rulesMeta = const VerificationMeta('rules');
  @override
  late final GeneratedColumn<String> rules = GeneratedColumn<String>(
    'rules',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelOverrideMeta = const VerificationMeta(
    'levelOverride',
  );
  @override
  late final GeneratedColumn<String> levelOverride = GeneratedColumn<String>(
    'level_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    rules,
    colorIndex,
    sortOrder,
    fullName,
    levelOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('rules')) {
      context.handle(
        _rulesMeta,
        rules.isAcceptableOrUnknown(data['rules']!, _rulesMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    }
    if (data.containsKey('level_override')) {
      context.handle(
        _levelOverrideMeta,
        levelOverride.isAcceptableOrUnknown(
          data['level_override']!,
          _levelOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      rules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      ),
      levelOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level_override'],
      ),
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class Subject extends DataClass implements Insertable<Subject> {
  final int id;
  final String name;
  final DateTime createdAt;

  /// How the AI should answer in this subject. Sits between the global rules
  /// and a single lesson's rules; the more specific level wins.
  final String? rules;

  /// Index into the fixed subject palette, so the colour follows the theme
  /// instead of being a stored RGB value that is wrong in dark mode.
  final int colorIndex;
  final int sortOrder;

  /// The subject's full name when [name] is a short label — „PSI" is
  /// „Počítačové sítě".
  final String? fullName;

  /// A level that differs from the course's year, e.g. „2. ročník" for a
  /// seminar shared with a younger class.
  final String? levelOverride;
  const Subject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.rules,
    required this.colorIndex,
    required this.sortOrder,
    this.fullName,
    this.levelOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || rules != null) {
      map['rules'] = Variable<String>(rules);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || fullName != null) {
      map['full_name'] = Variable<String>(fullName);
    }
    if (!nullToAbsent || levelOverride != null) {
      map['level_override'] = Variable<String>(levelOverride);
    }
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      rules: rules == null && nullToAbsent
          ? const Value.absent()
          : Value(rules),
      colorIndex: Value(colorIndex),
      sortOrder: Value(sortOrder),
      fullName: fullName == null && nullToAbsent
          ? const Value.absent()
          : Value(fullName),
      levelOverride: levelOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(levelOverride),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      rules: serializer.fromJson<String?>(json['rules']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      fullName: serializer.fromJson<String?>(json['fullName']),
      levelOverride: serializer.fromJson<String?>(json['levelOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'rules': serializer.toJson<String?>(rules),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'fullName': serializer.toJson<String?>(fullName),
      'levelOverride': serializer.toJson<String?>(levelOverride),
    };
  }

  Subject copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    Value<String?> rules = const Value.absent(),
    int? colorIndex,
    int? sortOrder,
    Value<String?> fullName = const Value.absent(),
    Value<String?> levelOverride = const Value.absent(),
  }) => Subject(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    rules: rules.present ? rules.value : this.rules,
    colorIndex: colorIndex ?? this.colorIndex,
    sortOrder: sortOrder ?? this.sortOrder,
    fullName: fullName.present ? fullName.value : this.fullName,
    levelOverride: levelOverride.present
        ? levelOverride.value
        : this.levelOverride,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rules: data.rules.present ? data.rules.value : this.rules,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      levelOverride: data.levelOverride.present
          ? data.levelOverride.value
          : this.levelOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rules: $rules, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fullName: $fullName, ')
          ..write('levelOverride: $levelOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    rules,
    colorIndex,
    sortOrder,
    fullName,
    levelOverride,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.rules == this.rules &&
          other.colorIndex == this.colorIndex &&
          other.sortOrder == this.sortOrder &&
          other.fullName == this.fullName &&
          other.levelOverride == this.levelOverride);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<String?> rules;
  final Value<int> colorIndex;
  final Value<int> sortOrder;
  final Value<String?> fullName;
  final Value<String?> levelOverride;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rules = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.fullName = const Value.absent(),
    this.levelOverride = const Value.absent(),
  });
  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
    this.rules = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.fullName = const Value.absent(),
    this.levelOverride = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Subject> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<String>? rules,
    Expression<int>? colorIndex,
    Expression<int>? sortOrder,
    Expression<String>? fullName,
    Expression<String>? levelOverride,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rules != null) 'rules': rules,
      if (colorIndex != null) 'color_index': colorIndex,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (fullName != null) 'full_name': fullName,
      if (levelOverride != null) 'level_override': levelOverride,
    });
  }

  SubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<String?>? rules,
    Value<int>? colorIndex,
    Value<int>? sortOrder,
    Value<String?>? fullName,
    Value<String?>? levelOverride,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rules: rules ?? this.rules,
      colorIndex: colorIndex ?? this.colorIndex,
      sortOrder: sortOrder ?? this.sortOrder,
      fullName: fullName ?? this.fullName,
      levelOverride: levelOverride ?? this.levelOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rules.present) {
      map['rules'] = Variable<String>(rules.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (levelOverride.present) {
      map['level_override'] = Variable<String>(levelOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rules: $rules, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fullName: $fullName, ')
          ..write('levelOverride: $levelOverride')
          ..write(')'))
        .toString();
  }
}

class $SavedNotesTable extends SavedNotes
    with TableInfo<$SavedNotesTable, SavedNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NotesDepth?, int> depth =
      GeneratedColumn<int>(
        'depth',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<NotesDepth?>($SavedNotesTable.$converterdepthn);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    folderId,
    meetingId,
    depth,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      ),
      depth: $SavedNotesTable.$converterdepthn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}depth'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedNotesTable createAlias(String alias) {
    return $SavedNotesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NotesDepth, int, int> $converterdepth =
      const EnumIndexConverter<NotesDepth>(NotesDepth.values);
  static JsonTypeConverter2<NotesDepth?, int?, int?> $converterdepthn =
      JsonTypeConverter2.asNullable($converterdepth);
}

class SavedNote extends DataClass implements Insertable<SavedNote> {
  final int id;
  final String title;
  final String content;

  /// Null means "Bez složky". Deleting a folder moves its notes here rather
  /// than deleting them.
  final int? folderId;
  final int? meetingId;

  /// The depth the notes were generated at, for the label on the note. Null
  /// once the user has edited the text by hand — it is no longer that output.
  final NotesDepth? depth;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SavedNote({
    required this.id,
    required this.title,
    required this.content,
    this.folderId,
    this.meetingId,
    this.depth,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    if (!nullToAbsent || meetingId != null) {
      map['meeting_id'] = Variable<int>(meetingId);
    }
    if (!nullToAbsent || depth != null) {
      map['depth'] = Variable<int>(
        $SavedNotesTable.$converterdepthn.toSql(depth),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SavedNotesCompanion toCompanion(bool nullToAbsent) {
    return SavedNotesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      meetingId: meetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(meetingId),
      depth: depth == null && nullToAbsent
          ? const Value.absent()
          : Value(depth),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedNote(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      meetingId: serializer.fromJson<int?>(json['meetingId']),
      depth: $SavedNotesTable.$converterdepthn.fromJson(
        serializer.fromJson<int?>(json['depth']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'folderId': serializer.toJson<int?>(folderId),
      'meetingId': serializer.toJson<int?>(meetingId),
      'depth': serializer.toJson<int?>(
        $SavedNotesTable.$converterdepthn.toJson(depth),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SavedNote copyWith({
    int? id,
    String? title,
    String? content,
    Value<int?> folderId = const Value.absent(),
    Value<int?> meetingId = const Value.absent(),
    Value<NotesDepth?> depth = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedNote(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    folderId: folderId.present ? folderId.value : this.folderId,
    meetingId: meetingId.present ? meetingId.value : this.meetingId,
    depth: depth.present ? depth.value : this.depth,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedNote copyWithCompanion(SavedNotesCompanion data) {
    return SavedNote(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      depth: data.depth.present ? data.depth.value : this.depth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedNote(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('folderId: $folderId, ')
          ..write('meetingId: $meetingId, ')
          ..write('depth: $depth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    folderId,
    meetingId,
    depth,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedNote &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.folderId == this.folderId &&
          other.meetingId == this.meetingId &&
          other.depth == this.depth &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SavedNotesCompanion extends UpdateCompanion<SavedNote> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<int?> folderId;
  final Value<int?> meetingId;
  final Value<NotesDepth?> depth;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SavedNotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.folderId = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.depth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SavedNotesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String content,
    this.folderId = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.depth = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : title = Value(title),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedNote> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? folderId,
    Expression<int>? meetingId,
    Expression<int>? depth,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (folderId != null) 'folder_id': folderId,
      if (meetingId != null) 'meeting_id': meetingId,
      if (depth != null) 'depth': depth,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SavedNotesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? content,
    Value<int?>? folderId,
    Value<int?>? meetingId,
    Value<NotesDepth?>? depth,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SavedNotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      meetingId: meetingId ?? this.meetingId,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(
        $SavedNotesTable.$converterdepthn.toSql(depth.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedNotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('folderId: $folderId, ')
          ..write('meetingId: $meetingId, ')
          ..write('depth: $depth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ContextCardsTable extends ContextCards
    with TableInfo<$ContextCardsTable, ContextCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContextCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardKind>($ContextCardsTable.$converterkind);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keywordsMeta = const VerificationMeta(
    'keywords',
  );
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
    'keywords',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    title,
    kind,
    content,
    summary,
    keywords,
    sources,
    createdAt,
    updatedAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'context_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContextCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('keywords')) {
      context.handle(
        _keywordsMeta,
        keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta),
      );
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContextCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContextCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: $ContextCardsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      keywords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords'],
      ),
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
    );
  }

  @override
  $ContextCardsTable createAlias(String alias) {
    return $ContextCardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardKind, String, String> $converterkind =
      const EnumNameConverter<CardKind>(CardKind.values);
}

class ContextCard extends DataClass implements Insertable<ContextCard> {
  final int id;
  final int subjectId;
  final String title;
  final CardKind kind;

  /// The full text, always editable by the user.
  final String content;

  /// A short digest (≤ 600 chars) sent when the token budget is tight. Null
  /// until one is generated; the context builder falls back to the content.
  final String? summary;

  /// Names and terms, comma-separated — also used as a Whisper glossary.
  final String? keywords;

  /// JSON `[{title, url}]`, the same shape as `answer_cards.sources`.
  final String? sources;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  const ContextCard({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    required this.content,
    this.summary,
    this.keywords,
    this.sources,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['title'] = Variable<String>(title);
    {
      map['kind'] = Variable<String>(
        $ContextCardsTable.$converterkind.toSql(kind),
      );
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || keywords != null) {
      map['keywords'] = Variable<String>(keywords);
    }
    if (!nullToAbsent || sources != null) {
      map['sources'] = Variable<String>(sources);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  ContextCardsCompanion toCompanion(bool nullToAbsent) {
    return ContextCardsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      title: Value(title),
      kind: Value(kind),
      content: Value(content),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      keywords: keywords == null && nullToAbsent
          ? const Value.absent()
          : Value(keywords),
      sources: sources == null && nullToAbsent
          ? const Value.absent()
          : Value(sources),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory ContextCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContextCard(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      title: serializer.fromJson<String>(json['title']),
      kind: $ContextCardsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      content: serializer.fromJson<String>(json['content']),
      summary: serializer.fromJson<String?>(json['summary']),
      keywords: serializer.fromJson<String?>(json['keywords']),
      sources: serializer.fromJson<String?>(json['sources']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(
        $ContextCardsTable.$converterkind.toJson(kind),
      ),
      'content': serializer.toJson<String>(content),
      'summary': serializer.toJson<String?>(summary),
      'keywords': serializer.toJson<String?>(keywords),
      'sources': serializer.toJson<String?>(sources),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  ContextCard copyWith({
    int? id,
    int? subjectId,
    String? title,
    CardKind? kind,
    String? content,
    Value<String?> summary = const Value.absent(),
    Value<String?> keywords = const Value.absent(),
    Value<String?> sources = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
  }) => ContextCard(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    summary: summary.present ? summary.value : this.summary,
    keywords: keywords.present ? keywords.value : this.keywords,
    sources: sources.present ? sources.value : this.sources,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  ContextCard copyWithCompanion(ContextCardsCompanion data) {
    return ContextCard(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      summary: data.summary.present ? data.summary.value : this.summary,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      sources: data.sources.present ? data.sources.value : this.sources,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContextCard(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('summary: $summary, ')
          ..write('keywords: $keywords, ')
          ..write('sources: $sources, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    title,
    kind,
    content,
    summary,
    keywords,
    sources,
    createdAt,
    updatedAt,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextCard &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.summary == this.summary &&
          other.keywords == this.keywords &&
          other.sources == this.sources &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class ContextCardsCompanion extends UpdateCompanion<ContextCard> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> title;
  final Value<CardKind> kind;
  final Value<String> content;
  final Value<String?> summary;
  final Value<String?> keywords;
  final Value<String?> sources;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastUsedAt;
  const ContextCardsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.summary = const Value.absent(),
    this.keywords = const Value.absent(),
    this.sources = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  ContextCardsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String title,
    required CardKind kind,
    this.content = const Value.absent(),
    this.summary = const Value.absent(),
    this.keywords = const Value.absent(),
    this.sources = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastUsedAt = const Value.absent(),
  }) : subjectId = Value(subjectId),
       title = Value(title),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ContextCard> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? summary,
    Expression<String>? keywords,
    Expression<String>? sources,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (summary != null) 'summary': summary,
      if (keywords != null) 'keywords': keywords,
      if (sources != null) 'sources': sources,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  ContextCardsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? title,
    Value<CardKind>? kind,
    Value<String>? content,
    Value<String?>? summary,
    Value<String?>? keywords,
    Value<String?>? sources,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastUsedAt,
  }) {
    return ContextCardsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      keywords: keywords ?? this.keywords,
      sources: sources ?? this.sources,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ContextCardsTable.$converterkind.toSql(kind.value),
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContextCardsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('summary: $summary, ')
          ..write('keywords: $keywords, ')
          ..write('sources: $sources, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $CardImagesTable extends CardImages
    with TableInfo<$CardImagesTable, CardImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, cardId, path, ord];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
    );
  }

  @override
  $CardImagesTable createAlias(String alias) {
    return $CardImagesTable(attachedDatabase, alias);
  }
}

class CardImage extends DataClass implements Insertable<CardImage> {
  final int id;
  final int cardId;
  final String path;
  final int ord;
  const CardImage({
    required this.id,
    required this.cardId,
    required this.path,
    required this.ord,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['path'] = Variable<String>(path);
    map['ord'] = Variable<int>(ord);
    return map;
  }

  CardImagesCompanion toCompanion(bool nullToAbsent) {
    return CardImagesCompanion(
      id: Value(id),
      cardId: Value(cardId),
      path: Value(path),
      ord: Value(ord),
    );
  }

  factory CardImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardImage(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      path: serializer.fromJson<String>(json['path']),
      ord: serializer.fromJson<int>(json['ord']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'path': serializer.toJson<String>(path),
      'ord': serializer.toJson<int>(ord),
    };
  }

  CardImage copyWith({int? id, int? cardId, String? path, int? ord}) =>
      CardImage(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        path: path ?? this.path,
        ord: ord ?? this.ord,
      );
  CardImage copyWithCompanion(CardImagesCompanion data) {
    return CardImage(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      path: data.path.present ? data.path.value : this.path,
      ord: data.ord.present ? data.ord.value : this.ord,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardImage(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('path: $path, ')
          ..write('ord: $ord')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cardId, path, ord);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardImage &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.path == this.path &&
          other.ord == this.ord);
}

class CardImagesCompanion extends UpdateCompanion<CardImage> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> path;
  final Value<int> ord;
  const CardImagesCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.path = const Value.absent(),
    this.ord = const Value.absent(),
  });
  CardImagesCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String path,
    this.ord = const Value.absent(),
  }) : cardId = Value(cardId),
       path = Value(path);
  static Insertable<CardImage> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? path,
    Expression<int>? ord,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (path != null) 'path': path,
      if (ord != null) 'ord': ord,
    });
  }

  CardImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? path,
    Value<int>? ord,
  }) {
    return CardImagesCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      path: path ?? this.path,
      ord: ord ?? this.ord,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardImagesCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('path: $path, ')
          ..write('ord: $ord')
          ..write(')'))
        .toString();
  }
}

class $MeetingCardsTable extends MeetingCards
    with TableInfo<$MeetingCardsTable, MeetingCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [meetingId, cardId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meeting_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {meetingId, cardId};
  @override
  MeetingCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingCard(
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
    );
  }

  @override
  $MeetingCardsTable createAlias(String alias) {
    return $MeetingCardsTable(attachedDatabase, alias);
  }
}

class MeetingCard extends DataClass implements Insertable<MeetingCard> {
  final int meetingId;
  final int cardId;
  const MeetingCard({required this.meetingId, required this.cardId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meeting_id'] = Variable<int>(meetingId);
    map['card_id'] = Variable<int>(cardId);
    return map;
  }

  MeetingCardsCompanion toCompanion(bool nullToAbsent) {
    return MeetingCardsCompanion(
      meetingId: Value(meetingId),
      cardId: Value(cardId),
    );
  }

  factory MeetingCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingCard(
      meetingId: serializer.fromJson<int>(json['meetingId']),
      cardId: serializer.fromJson<int>(json['cardId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'meetingId': serializer.toJson<int>(meetingId),
      'cardId': serializer.toJson<int>(cardId),
    };
  }

  MeetingCard copyWith({int? meetingId, int? cardId}) => MeetingCard(
    meetingId: meetingId ?? this.meetingId,
    cardId: cardId ?? this.cardId,
  );
  MeetingCard copyWithCompanion(MeetingCardsCompanion data) {
    return MeetingCard(
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingCard(')
          ..write('meetingId: $meetingId, ')
          ..write('cardId: $cardId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(meetingId, cardId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingCard &&
          other.meetingId == this.meetingId &&
          other.cardId == this.cardId);
}

class MeetingCardsCompanion extends UpdateCompanion<MeetingCard> {
  final Value<int> meetingId;
  final Value<int> cardId;
  final Value<int> rowid;
  const MeetingCardsCompanion({
    this.meetingId = const Value.absent(),
    this.cardId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingCardsCompanion.insert({
    required int meetingId,
    required int cardId,
    this.rowid = const Value.absent(),
  }) : meetingId = Value(meetingId),
       cardId = Value(cardId);
  static Insertable<MeetingCard> custom({
    Expression<int>? meetingId,
    Expression<int>? cardId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (meetingId != null) 'meeting_id': meetingId,
      if (cardId != null) 'card_id': cardId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingCardsCompanion copyWith({
    Value<int>? meetingId,
    Value<int>? cardId,
    Value<int>? rowid,
  }) {
    return MeetingCardsCompanion(
      meetingId: meetingId ?? this.meetingId,
      cardId: cardId ?? this.cardId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingCardsCompanion(')
          ..write('meetingId: $meetingId, ')
          ..write('cardId: $cardId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimetableSlotsTable extends TimetableSlots
    with TableInfo<$TimetableSlotsTable, TimetableSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimetableSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    weekday,
    startMinute,
    endMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timetable_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimetableSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    } else if (isInserting) {
      context.missing(_weekdayMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimetableSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimetableSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
    );
  }

  @override
  $TimetableSlotsTable createAlias(String alias) {
    return $TimetableSlotsTable(attachedDatabase, alias);
  }
}

class TimetableSlot extends DataClass implements Insertable<TimetableSlot> {
  final int id;
  final int subjectId;

  /// 1 = Monday … 7 = Sunday, as `DateTime.weekday`.
  final int weekday;
  final int startMinute;
  final int endMinute;
  const TimetableSlot({
    required this.id,
    required this.subjectId,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['weekday'] = Variable<int>(weekday);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    return map;
  }

  TimetableSlotsCompanion toCompanion(bool nullToAbsent) {
    return TimetableSlotsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      weekday: Value(weekday),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
    );
  }

  factory TimetableSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimetableSlot(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      weekday: serializer.fromJson<int>(json['weekday']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'weekday': serializer.toJson<int>(weekday),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
    };
  }

  TimetableSlot copyWith({
    int? id,
    int? subjectId,
    int? weekday,
    int? startMinute,
    int? endMinute,
  }) => TimetableSlot(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    weekday: weekday ?? this.weekday,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
  );
  TimetableSlot copyWithCompanion(TimetableSlotsCompanion data) {
    return TimetableSlot(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimetableSlot(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('weekday: $weekday, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, weekday, startMinute, endMinute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimetableSlot &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.weekday == this.weekday &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute);
}

class TimetableSlotsCompanion extends UpdateCompanion<TimetableSlot> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<int> weekday;
  final Value<int> startMinute;
  final Value<int> endMinute;
  const TimetableSlotsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.weekday = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
  });
  TimetableSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required int weekday,
    required int startMinute,
    required int endMinute,
  }) : subjectId = Value(subjectId),
       weekday = Value(weekday),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<TimetableSlot> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<int>? weekday,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (weekday != null) 'weekday': weekday,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
    });
  }

  TimetableSlotsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<int>? weekday,
    Value<int>? startMinute,
    Value<int>? endMinute,
  }) {
    return TimetableSlotsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      weekday: weekday ?? this.weekday,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimetableSlotsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('weekday: $weekday, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ChatRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ChatRole>($ChatMessagesTable.$converterrole);
  @override
  late final GeneratedColumnWithTypeConverter<ChatIntent, String> intent =
      GeneratedColumn<String>(
        'intent',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ChatIntent>($ChatMessagesTable.$converterintent);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ChatStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ChatStatus>($ChatMessagesTable.$converterstatus);
  static const VerificationMeta _shortMeta = const VerificationMeta('short');
  @override
  late final GeneratedColumn<String> short = GeneratedColumn<String>(
    'short',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToMeta = const VerificationMeta(
    'replyTo',
  );
  @override
  late final GeneratedColumn<int> replyTo = GeneratedColumn<int>(
    'reply_to',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    role,
    intent,
    body,
    imagePath,
    atMs,
    status,
    short,
    detail,
    basis,
    sources,
    replyTo,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    if (data.containsKey('short')) {
      context.handle(
        _shortMeta,
        short.isAcceptableOrUnknown(data['short']!, _shortMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('reply_to')) {
      context.handle(
        _replyToMeta,
        replyTo.isAcceptableOrUnknown(data['reply_to']!, _replyToMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      role: $ChatMessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      intent: $ChatMessagesTable.$converterintent.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}intent'],
        )!,
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
      status: $ChatMessagesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      short: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      ),
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      ),
      replyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reply_to'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChatRole, String, String> $converterrole =
      const EnumNameConverter<ChatRole>(ChatRole.values);
  static JsonTypeConverter2<ChatIntent, String, String> $converterintent =
      const EnumNameConverter<ChatIntent>(ChatIntent.values);
  static JsonTypeConverter2<ChatStatus, int, int> $converterstatus =
      const EnumIndexConverter<ChatStatus>(ChatStatus.values);
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final int id;
  final int meetingId;
  final ChatRole role;
  final ChatIntent intent;

  /// `text` would shadow the column builder inside a table class.
  final String body;
  final String? imagePath;

  /// Offset into the recording, so the message sorts into the transcript.
  final int atMs;
  final ChatStatus status;

  /// An assistant reply: one bold line, then the explanation.
  final String? short;
  final String? detail;
  final String? basis;
  final String? sources;
  final int? replyTo;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.meetingId,
    required this.role,
    required this.intent,
    required this.body,
    this.imagePath,
    required this.atMs,
    required this.status,
    this.short,
    this.detail,
    this.basis,
    this.sources,
    this.replyTo,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<int>(meetingId);
    {
      map['role'] = Variable<String>(
        $ChatMessagesTable.$converterrole.toSql(role),
      );
    }
    {
      map['intent'] = Variable<String>(
        $ChatMessagesTable.$converterintent.toSql(intent),
      );
    }
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['at_ms'] = Variable<int>(atMs);
    {
      map['status'] = Variable<int>(
        $ChatMessagesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || short != null) {
      map['short'] = Variable<String>(short);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || basis != null) {
      map['basis'] = Variable<String>(basis);
    }
    if (!nullToAbsent || sources != null) {
      map['sources'] = Variable<String>(sources);
    }
    if (!nullToAbsent || replyTo != null) {
      map['reply_to'] = Variable<int>(replyTo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      role: Value(role),
      intent: Value(intent),
      body: Value(body),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      atMs: Value(atMs),
      status: Value(status),
      short: short == null && nullToAbsent
          ? const Value.absent()
          : Value(short),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      basis: basis == null && nullToAbsent
          ? const Value.absent()
          : Value(basis),
      sources: sources == null && nullToAbsent
          ? const Value.absent()
          : Value(sources),
      replyTo: replyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(replyTo),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      role: $ChatMessagesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      intent: $ChatMessagesTable.$converterintent.fromJson(
        serializer.fromJson<String>(json['intent']),
      ),
      body: serializer.fromJson<String>(json['body']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      atMs: serializer.fromJson<int>(json['atMs']),
      status: $ChatMessagesTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      short: serializer.fromJson<String?>(json['short']),
      detail: serializer.fromJson<String?>(json['detail']),
      basis: serializer.fromJson<String?>(json['basis']),
      sources: serializer.fromJson<String?>(json['sources']),
      replyTo: serializer.fromJson<int?>(json['replyTo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<int>(meetingId),
      'role': serializer.toJson<String>(
        $ChatMessagesTable.$converterrole.toJson(role),
      ),
      'intent': serializer.toJson<String>(
        $ChatMessagesTable.$converterintent.toJson(intent),
      ),
      'body': serializer.toJson<String>(body),
      'imagePath': serializer.toJson<String?>(imagePath),
      'atMs': serializer.toJson<int>(atMs),
      'status': serializer.toJson<int>(
        $ChatMessagesTable.$converterstatus.toJson(status),
      ),
      'short': serializer.toJson<String?>(short),
      'detail': serializer.toJson<String?>(detail),
      'basis': serializer.toJson<String?>(basis),
      'sources': serializer.toJson<String?>(sources),
      'replyTo': serializer.toJson<int?>(replyTo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    int? id,
    int? meetingId,
    ChatRole? role,
    ChatIntent? intent,
    String? body,
    Value<String?> imagePath = const Value.absent(),
    int? atMs,
    ChatStatus? status,
    Value<String?> short = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    Value<String?> basis = const Value.absent(),
    Value<String?> sources = const Value.absent(),
    Value<int?> replyTo = const Value.absent(),
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    role: role ?? this.role,
    intent: intent ?? this.intent,
    body: body ?? this.body,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    atMs: atMs ?? this.atMs,
    status: status ?? this.status,
    short: short.present ? short.value : this.short,
    detail: detail.present ? detail.value : this.detail,
    basis: basis.present ? basis.value : this.basis,
    sources: sources.present ? sources.value : this.sources,
    replyTo: replyTo.present ? replyTo.value : this.replyTo,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      role: data.role.present ? data.role.value : this.role,
      intent: data.intent.present ? data.intent.value : this.intent,
      body: data.body.present ? data.body.value : this.body,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
      status: data.status.present ? data.status.value : this.status,
      short: data.short.present ? data.short.value : this.short,
      detail: data.detail.present ? data.detail.value : this.detail,
      basis: data.basis.present ? data.basis.value : this.basis,
      sources: data.sources.present ? data.sources.value : this.sources,
      replyTo: data.replyTo.present ? data.replyTo.value : this.replyTo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('role: $role, ')
          ..write('intent: $intent, ')
          ..write('body: $body, ')
          ..write('imagePath: $imagePath, ')
          ..write('atMs: $atMs, ')
          ..write('status: $status, ')
          ..write('short: $short, ')
          ..write('detail: $detail, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('replyTo: $replyTo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    role,
    intent,
    body,
    imagePath,
    atMs,
    status,
    short,
    detail,
    basis,
    sources,
    replyTo,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.role == this.role &&
          other.intent == this.intent &&
          other.body == this.body &&
          other.imagePath == this.imagePath &&
          other.atMs == this.atMs &&
          other.status == this.status &&
          other.short == this.short &&
          other.detail == this.detail &&
          other.basis == this.basis &&
          other.sources == this.sources &&
          other.replyTo == this.replyTo &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<int> id;
  final Value<int> meetingId;
  final Value<ChatRole> role;
  final Value<ChatIntent> intent;
  final Value<String> body;
  final Value<String?> imagePath;
  final Value<int> atMs;
  final Value<ChatStatus> status;
  final Value<String?> short;
  final Value<String?> detail;
  final Value<String?> basis;
  final Value<String?> sources;
  final Value<int?> replyTo;
  final Value<DateTime> createdAt;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.role = const Value.absent(),
    this.intent = const Value.absent(),
    this.body = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.atMs = const Value.absent(),
    this.status = const Value.absent(),
    this.short = const Value.absent(),
    this.detail = const Value.absent(),
    this.basis = const Value.absent(),
    this.sources = const Value.absent(),
    this.replyTo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int meetingId,
    required ChatRole role,
    required ChatIntent intent,
    this.body = const Value.absent(),
    this.imagePath = const Value.absent(),
    required int atMs,
    required ChatStatus status,
    this.short = const Value.absent(),
    this.detail = const Value.absent(),
    this.basis = const Value.absent(),
    this.sources = const Value.absent(),
    this.replyTo = const Value.absent(),
    required DateTime createdAt,
  }) : meetingId = Value(meetingId),
       role = Value(role),
       intent = Value(intent),
       atMs = Value(atMs),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<int>? id,
    Expression<int>? meetingId,
    Expression<String>? role,
    Expression<String>? intent,
    Expression<String>? body,
    Expression<String>? imagePath,
    Expression<int>? atMs,
    Expression<int>? status,
    Expression<String>? short,
    Expression<String>? detail,
    Expression<String>? basis,
    Expression<String>? sources,
    Expression<int>? replyTo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (role != null) 'role': role,
      if (intent != null) 'intent': intent,
      if (body != null) 'text': body,
      if (imagePath != null) 'image_path': imagePath,
      if (atMs != null) 'at_ms': atMs,
      if (status != null) 'status': status,
      if (short != null) 'short': short,
      if (detail != null) 'detail': detail,
      if (basis != null) 'basis': basis,
      if (sources != null) 'sources': sources,
      if (replyTo != null) 'reply_to': replyTo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? meetingId,
    Value<ChatRole>? role,
    Value<ChatIntent>? intent,
    Value<String>? body,
    Value<String?>? imagePath,
    Value<int>? atMs,
    Value<ChatStatus>? status,
    Value<String?>? short,
    Value<String?>? detail,
    Value<String?>? basis,
    Value<String?>? sources,
    Value<int?>? replyTo,
    Value<DateTime>? createdAt,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      role: role ?? this.role,
      intent: intent ?? this.intent,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
      atMs: atMs ?? this.atMs,
      status: status ?? this.status,
      short: short ?? this.short,
      detail: detail ?? this.detail,
      basis: basis ?? this.basis,
      sources: sources ?? this.sources,
      replyTo: replyTo ?? this.replyTo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $ChatMessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (intent.present) {
      map['intent'] = Variable<String>(
        $ChatMessagesTable.$converterintent.toSql(intent.value),
      );
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $ChatMessagesTable.$converterstatus.toSql(status.value),
      );
    }
    if (short.present) {
      map['short'] = Variable<String>(short.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (replyTo.present) {
      map['reply_to'] = Variable<int>(replyTo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('role: $role, ')
          ..write('intent: $intent, ')
          ..write('body: $body, ')
          ..write('imagePath: $imagePath, ')
          ..write('atMs: $atMs, ')
          ..write('status: $status, ')
          ..write('short: $short, ')
          ..write('detail: $detail, ')
          ..write('basis: $basis, ')
          ..write('sources: $sources, ')
          ..write('replyTo: $replyTo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RefinedSegmentsTable extends RefinedSegments
    with TableInfo<$RefinedSegmentsTable, RefinedSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RefinedSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<int> meetingId = GeneratedColumn<int>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowIndexMeta = const VerificationMeta(
    'windowIndex',
  );
  @override
  late final GeneratedColumn<int> windowIndex = GeneratedColumn<int>(
    'window_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RefinedEngine, String> engine =
      GeneratedColumn<String>(
        'engine',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RefinedEngine>($RefinedSegmentsTable.$converterengine);
  @override
  late final GeneratedColumnWithTypeConverter<RefinedStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<RefinedStatus>($RefinedSegmentsTable.$converterstatus);
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawContentMeta = const VerificationMeta(
    'rawContent',
  );
  @override
  late final GeneratedColumn<String> rawContent = GeneratedColumn<String>(
    'raw_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    windowIndex,
    startMs,
    endMs,
    content,
    engine,
    status,
    error,
    createdAt,
    rawContent,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'refined_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RefinedSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('window_index')) {
      context.handle(
        _windowIndexMeta,
        windowIndex.isAcceptableOrUnknown(
          data['window_index']!,
          _windowIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowIndexMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('raw_content')) {
      context.handle(
        _rawContentMeta,
        rawContent.isAcceptableOrUnknown(data['raw_content']!, _rawContentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RefinedSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RefinedSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meeting_id'],
      )!,
      windowIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_index'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      ),
      engine: $RefinedSegmentsTable.$converterengine.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}engine'],
        )!,
      ),
      status: $RefinedSegmentsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      rawContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_content'],
      ),
    );
  }

  @override
  $RefinedSegmentsTable createAlias(String alias) {
    return $RefinedSegmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RefinedEngine, String, String> $converterengine =
      const EnumNameConverter<RefinedEngine>(RefinedEngine.values);
  static JsonTypeConverter2<RefinedStatus, int, int> $converterstatus =
      const EnumIndexConverter<RefinedStatus>(RefinedStatus.values);
}

class RefinedSegment extends DataClass implements Insertable<RefinedSegment> {
  final int id;
  final int meetingId;
  final int windowIndex;
  final int startMs;
  final int endMs;

  /// Null until the window is ready; empty when the window held no speech.
  final String? content;
  final RefinedEngine engine;
  final RefinedStatus status;
  final String? error;
  final DateTime createdAt;

  /// The window's text before a correction; null while untouched.
  final String? rawContent;
  const RefinedSegment({
    required this.id,
    required this.meetingId,
    required this.windowIndex,
    required this.startMs,
    required this.endMs,
    this.content,
    required this.engine,
    required this.status,
    this.error,
    required this.createdAt,
    this.rawContent,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meeting_id'] = Variable<int>(meetingId);
    map['window_index'] = Variable<int>(windowIndex);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || content != null) {
      map['text'] = Variable<String>(content);
    }
    {
      map['engine'] = Variable<String>(
        $RefinedSegmentsTable.$converterengine.toSql(engine),
      );
    }
    {
      map['status'] = Variable<int>(
        $RefinedSegmentsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || rawContent != null) {
      map['raw_content'] = Variable<String>(rawContent);
    }
    return map;
  }

  RefinedSegmentsCompanion toCompanion(bool nullToAbsent) {
    return RefinedSegmentsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      windowIndex: Value(windowIndex),
      startMs: Value(startMs),
      endMs: Value(endMs),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      engine: Value(engine),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      rawContent: rawContent == null && nullToAbsent
          ? const Value.absent()
          : Value(rawContent),
    );
  }

  factory RefinedSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RefinedSegment(
      id: serializer.fromJson<int>(json['id']),
      meetingId: serializer.fromJson<int>(json['meetingId']),
      windowIndex: serializer.fromJson<int>(json['windowIndex']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      content: serializer.fromJson<String?>(json['content']),
      engine: $RefinedSegmentsTable.$converterengine.fromJson(
        serializer.fromJson<String>(json['engine']),
      ),
      status: $RefinedSegmentsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      rawContent: serializer.fromJson<String?>(json['rawContent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meetingId': serializer.toJson<int>(meetingId),
      'windowIndex': serializer.toJson<int>(windowIndex),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'content': serializer.toJson<String?>(content),
      'engine': serializer.toJson<String>(
        $RefinedSegmentsTable.$converterengine.toJson(engine),
      ),
      'status': serializer.toJson<int>(
        $RefinedSegmentsTable.$converterstatus.toJson(status),
      ),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'rawContent': serializer.toJson<String?>(rawContent),
    };
  }

  RefinedSegment copyWith({
    int? id,
    int? meetingId,
    int? windowIndex,
    int? startMs,
    int? endMs,
    Value<String?> content = const Value.absent(),
    RefinedEngine? engine,
    RefinedStatus? status,
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
    Value<String?> rawContent = const Value.absent(),
  }) => RefinedSegment(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    windowIndex: windowIndex ?? this.windowIndex,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    content: content.present ? content.value : this.content,
    engine: engine ?? this.engine,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    rawContent: rawContent.present ? rawContent.value : this.rawContent,
  );
  RefinedSegment copyWithCompanion(RefinedSegmentsCompanion data) {
    return RefinedSegment(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      windowIndex: data.windowIndex.present
          ? data.windowIndex.value
          : this.windowIndex,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      content: data.content.present ? data.content.value : this.content,
      engine: data.engine.present ? data.engine.value : this.engine,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rawContent: data.rawContent.present
          ? data.rawContent.value
          : this.rawContent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RefinedSegment(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('windowIndex: $windowIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('engine: $engine, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawContent: $rawContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    windowIndex,
    startMs,
    endMs,
    content,
    engine,
    status,
    error,
    createdAt,
    rawContent,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RefinedSegment &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.windowIndex == this.windowIndex &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.content == this.content &&
          other.engine == this.engine &&
          other.status == this.status &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.rawContent == this.rawContent);
}

class RefinedSegmentsCompanion extends UpdateCompanion<RefinedSegment> {
  final Value<int> id;
  final Value<int> meetingId;
  final Value<int> windowIndex;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String?> content;
  final Value<RefinedEngine> engine;
  final Value<RefinedStatus> status;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  final Value<String?> rawContent;
  const RefinedSegmentsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.windowIndex = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.content = const Value.absent(),
    this.engine = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rawContent = const Value.absent(),
  });
  RefinedSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required int meetingId,
    required int windowIndex,
    required int startMs,
    required int endMs,
    this.content = const Value.absent(),
    required RefinedEngine engine,
    required RefinedStatus status,
    this.error = const Value.absent(),
    required DateTime createdAt,
    this.rawContent = const Value.absent(),
  }) : meetingId = Value(meetingId),
       windowIndex = Value(windowIndex),
       startMs = Value(startMs),
       endMs = Value(endMs),
       engine = Value(engine),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<RefinedSegment> custom({
    Expression<int>? id,
    Expression<int>? meetingId,
    Expression<int>? windowIndex,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? content,
    Expression<String>? engine,
    Expression<int>? status,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
    Expression<String>? rawContent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (windowIndex != null) 'window_index': windowIndex,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (content != null) 'text': content,
      if (engine != null) 'engine': engine,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (rawContent != null) 'raw_content': rawContent,
    });
  }

  RefinedSegmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? meetingId,
    Value<int>? windowIndex,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String?>? content,
    Value<RefinedEngine>? engine,
    Value<RefinedStatus>? status,
    Value<String?>? error,
    Value<DateTime>? createdAt,
    Value<String?>? rawContent,
  }) {
    return RefinedSegmentsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      windowIndex: windowIndex ?? this.windowIndex,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      content: content ?? this.content,
      engine: engine ?? this.engine,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      rawContent: rawContent ?? this.rawContent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<int>(meetingId.value);
    }
    if (windowIndex.present) {
      map['window_index'] = Variable<int>(windowIndex.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(
        $RefinedSegmentsTable.$converterengine.toSql(engine.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $RefinedSegmentsTable.$converterstatus.toSql(status.value),
      );
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rawContent.present) {
      map['raw_content'] = Variable<String>(rawContent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RefinedSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('windowIndex: $windowIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('engine: $engine, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawContent: $rawContent')
          ..write(')'))
        .toString();
  }
}

class $SubjectTermsTable extends SubjectTerms
    with TableInfo<$SubjectTermsTable, SubjectTerm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectTermsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heardMeta = const VerificationMeta('heard');
  @override
  late final GeneratedColumn<String> heard = GeneratedColumn<String>(
    'heard',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TermSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<TermSource>($SubjectTermsTable.$convertersource);
  static const VerificationMeta _usesMeta = const VerificationMeta('uses');
  @override
  late final GeneratedColumn<int> uses = GeneratedColumn<int>(
    'uses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    term,
    heard,
    source,
    uses,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_terms';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectTerm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('heard')) {
      context.handle(
        _heardMeta,
        heard.isAcceptableOrUnknown(data['heard']!, _heardMeta),
      );
    }
    if (data.containsKey('uses')) {
      context.handle(
        _usesMeta,
        uses.isAcceptableOrUnknown(data['uses']!, _usesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubjectTerm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectTerm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      term: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}term'],
      )!,
      heard: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}heard'],
      ),
      source: $SubjectTermsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      uses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uses'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubjectTermsTable createAlias(String alias) {
    return $SubjectTermsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TermSource, int, int> $convertersource =
      const EnumIndexConverter<TermSource>(TermSource.values);
}

class SubjectTerm extends DataClass implements Insertable<SubjectTerm> {
  final int id;
  final int subjectId;
  final String term;
  final String? heard;
  final TermSource source;

  /// How often the term turned up in a transcript; ranks the vocabulary.
  final int uses;
  final DateTime createdAt;
  const SubjectTerm({
    required this.id,
    required this.subjectId,
    required this.term,
    this.heard,
    required this.source,
    required this.uses,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['term'] = Variable<String>(term);
    if (!nullToAbsent || heard != null) {
      map['heard'] = Variable<String>(heard);
    }
    {
      map['source'] = Variable<int>(
        $SubjectTermsTable.$convertersource.toSql(source),
      );
    }
    map['uses'] = Variable<int>(uses);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SubjectTermsCompanion toCompanion(bool nullToAbsent) {
    return SubjectTermsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      term: Value(term),
      heard: heard == null && nullToAbsent
          ? const Value.absent()
          : Value(heard),
      source: Value(source),
      uses: Value(uses),
      createdAt: Value(createdAt),
    );
  }

  factory SubjectTerm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectTerm(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      term: serializer.fromJson<String>(json['term']),
      heard: serializer.fromJson<String?>(json['heard']),
      source: $SubjectTermsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      uses: serializer.fromJson<int>(json['uses']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'term': serializer.toJson<String>(term),
      'heard': serializer.toJson<String?>(heard),
      'source': serializer.toJson<int>(
        $SubjectTermsTable.$convertersource.toJson(source),
      ),
      'uses': serializer.toJson<int>(uses),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SubjectTerm copyWith({
    int? id,
    int? subjectId,
    String? term,
    Value<String?> heard = const Value.absent(),
    TermSource? source,
    int? uses,
    DateTime? createdAt,
  }) => SubjectTerm(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    term: term ?? this.term,
    heard: heard.present ? heard.value : this.heard,
    source: source ?? this.source,
    uses: uses ?? this.uses,
    createdAt: createdAt ?? this.createdAt,
  );
  SubjectTerm copyWithCompanion(SubjectTermsCompanion data) {
    return SubjectTerm(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      term: data.term.present ? data.term.value : this.term,
      heard: data.heard.present ? data.heard.value : this.heard,
      source: data.source.present ? data.source.value : this.source,
      uses: data.uses.present ? data.uses.value : this.uses,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectTerm(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('term: $term, ')
          ..write('heard: $heard, ')
          ..write('source: $source, ')
          ..write('uses: $uses, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, term, heard, source, uses, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectTerm &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.term == this.term &&
          other.heard == this.heard &&
          other.source == this.source &&
          other.uses == this.uses &&
          other.createdAt == this.createdAt);
}

class SubjectTermsCompanion extends UpdateCompanion<SubjectTerm> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> term;
  final Value<String?> heard;
  final Value<TermSource> source;
  final Value<int> uses;
  final Value<DateTime> createdAt;
  const SubjectTermsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.term = const Value.absent(),
    this.heard = const Value.absent(),
    this.source = const Value.absent(),
    this.uses = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SubjectTermsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String term,
    this.heard = const Value.absent(),
    required TermSource source,
    this.uses = const Value.absent(),
    required DateTime createdAt,
  }) : subjectId = Value(subjectId),
       term = Value(term),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<SubjectTerm> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? term,
    Expression<String>? heard,
    Expression<int>? source,
    Expression<int>? uses,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (term != null) 'term': term,
      if (heard != null) 'heard': heard,
      if (source != null) 'source': source,
      if (uses != null) 'uses': uses,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SubjectTermsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? term,
    Value<String?>? heard,
    Value<TermSource>? source,
    Value<int>? uses,
    Value<DateTime>? createdAt,
  }) {
    return SubjectTermsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      term: term ?? this.term,
      heard: heard ?? this.heard,
      source: source ?? this.source,
      uses: uses ?? this.uses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (heard.present) {
      map['heard'] = Variable<String>(heard.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $SubjectTermsTable.$convertersource.toSql(source.value),
      );
    }
    if (uses.present) {
      map['uses'] = Variable<int>(uses.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectTermsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('term: $term, ')
          ..write('heard: $heard, ')
          ..write('source: $source, ')
          ..write('uses: $uses, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyllabusTopicsTable extends SyllabusTopics
    with TableInfo<$SyllabusTopicsTable, SyllabusTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyllabusTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _termsMeta = const VerificationMeta('terms');
  @override
  late final GeneratedColumn<String> terms = GeneratedColumn<String>(
    'terms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthFromMeta = const VerificationMeta(
    'monthFrom',
  );
  @override
  late final GeneratedColumn<int> monthFrom = GeneratedColumn<int>(
    'month_from',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthToMeta = const VerificationMeta(
    'monthTo',
  );
  @override
  late final GeneratedColumn<int> monthTo = GeneratedColumn<int>(
    'month_to',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyllabusSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SyllabusSource>($SyllabusTopicsTable.$convertersource);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    ord,
    title,
    description,
    terms,
    monthFrom,
    monthTo,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'syllabus_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyllabusTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('terms')) {
      context.handle(
        _termsMeta,
        terms.isAcceptableOrUnknown(data['terms']!, _termsMeta),
      );
    }
    if (data.containsKey('month_from')) {
      context.handle(
        _monthFromMeta,
        monthFrom.isAcceptableOrUnknown(data['month_from']!, _monthFromMeta),
      );
    }
    if (data.containsKey('month_to')) {
      context.handle(
        _monthToMeta,
        monthTo.isAcceptableOrUnknown(data['month_to']!, _monthToMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyllabusTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyllabusTopic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      terms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terms'],
      ),
      monthFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_from'],
      ),
      monthTo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_to'],
      ),
      source: $SyllabusTopicsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyllabusTopicsTable createAlias(String alias) {
    return $SyllabusTopicsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyllabusSource, int, int> $convertersource =
      const EnumIndexConverter<SyllabusSource>(SyllabusSource.values);
}

class SyllabusTopic extends DataClass implements Insertable<SyllabusTopic> {
  final int id;
  final int subjectId;
  final int ord;
  final String title;
  final String? description;

  /// Terms the topic uses, as a comma list.
  final String? terms;
  final int? monthFrom;
  final int? monthTo;
  final SyllabusSource source;
  final DateTime createdAt;
  const SyllabusTopic({
    required this.id,
    required this.subjectId,
    required this.ord,
    required this.title,
    this.description,
    this.terms,
    this.monthFrom,
    this.monthTo,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['ord'] = Variable<int>(ord);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || terms != null) {
      map['terms'] = Variable<String>(terms);
    }
    if (!nullToAbsent || monthFrom != null) {
      map['month_from'] = Variable<int>(monthFrom);
    }
    if (!nullToAbsent || monthTo != null) {
      map['month_to'] = Variable<int>(monthTo);
    }
    {
      map['source'] = Variable<int>(
        $SyllabusTopicsTable.$convertersource.toSql(source),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyllabusTopicsCompanion toCompanion(bool nullToAbsent) {
    return SyllabusTopicsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      ord: Value(ord),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      terms: terms == null && nullToAbsent
          ? const Value.absent()
          : Value(terms),
      monthFrom: monthFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(monthFrom),
      monthTo: monthTo == null && nullToAbsent
          ? const Value.absent()
          : Value(monthTo),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory SyllabusTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyllabusTopic(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      ord: serializer.fromJson<int>(json['ord']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      terms: serializer.fromJson<String?>(json['terms']),
      monthFrom: serializer.fromJson<int?>(json['monthFrom']),
      monthTo: serializer.fromJson<int?>(json['monthTo']),
      source: $SyllabusTopicsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'ord': serializer.toJson<int>(ord),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'terms': serializer.toJson<String?>(terms),
      'monthFrom': serializer.toJson<int?>(monthFrom),
      'monthTo': serializer.toJson<int?>(monthTo),
      'source': serializer.toJson<int>(
        $SyllabusTopicsTable.$convertersource.toJson(source),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyllabusTopic copyWith({
    int? id,
    int? subjectId,
    int? ord,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> terms = const Value.absent(),
    Value<int?> monthFrom = const Value.absent(),
    Value<int?> monthTo = const Value.absent(),
    SyllabusSource? source,
    DateTime? createdAt,
  }) => SyllabusTopic(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    ord: ord ?? this.ord,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    terms: terms.present ? terms.value : this.terms,
    monthFrom: monthFrom.present ? monthFrom.value : this.monthFrom,
    monthTo: monthTo.present ? monthTo.value : this.monthTo,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  SyllabusTopic copyWithCompanion(SyllabusTopicsCompanion data) {
    return SyllabusTopic(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      ord: data.ord.present ? data.ord.value : this.ord,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      terms: data.terms.present ? data.terms.value : this.terms,
      monthFrom: data.monthFrom.present ? data.monthFrom.value : this.monthFrom,
      monthTo: data.monthTo.present ? data.monthTo.value : this.monthTo,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusTopic(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('ord: $ord, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('terms: $terms, ')
          ..write('monthFrom: $monthFrom, ')
          ..write('monthTo: $monthTo, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    ord,
    title,
    description,
    terms,
    monthFrom,
    monthTo,
    source,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyllabusTopic &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.ord == this.ord &&
          other.title == this.title &&
          other.description == this.description &&
          other.terms == this.terms &&
          other.monthFrom == this.monthFrom &&
          other.monthTo == this.monthTo &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class SyllabusTopicsCompanion extends UpdateCompanion<SyllabusTopic> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<int> ord;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> terms;
  final Value<int?> monthFrom;
  final Value<int?> monthTo;
  final Value<SyllabusSource> source;
  final Value<DateTime> createdAt;
  const SyllabusTopicsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.ord = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.terms = const Value.absent(),
    this.monthFrom = const Value.absent(),
    this.monthTo = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyllabusTopicsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required int ord,
    required String title,
    this.description = const Value.absent(),
    this.terms = const Value.absent(),
    this.monthFrom = const Value.absent(),
    this.monthTo = const Value.absent(),
    required SyllabusSource source,
    required DateTime createdAt,
  }) : subjectId = Value(subjectId),
       ord = Value(ord),
       title = Value(title),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<SyllabusTopic> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<int>? ord,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? terms,
    Expression<int>? monthFrom,
    Expression<int>? monthTo,
    Expression<int>? source,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (ord != null) 'ord': ord,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (terms != null) 'terms': terms,
      if (monthFrom != null) 'month_from': monthFrom,
      if (monthTo != null) 'month_to': monthTo,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyllabusTopicsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<int>? ord,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? terms,
    Value<int?>? monthFrom,
    Value<int?>? monthTo,
    Value<SyllabusSource>? source,
    Value<DateTime>? createdAt,
  }) {
    return SyllabusTopicsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      ord: ord ?? this.ord,
      title: title ?? this.title,
      description: description ?? this.description,
      terms: terms ?? this.terms,
      monthFrom: monthFrom ?? this.monthFrom,
      monthTo: monthTo ?? this.monthTo,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (terms.present) {
      map['terms'] = Variable<String>(terms.value);
    }
    if (monthFrom.present) {
      map['month_from'] = Variable<int>(monthFrom.value);
    }
    if (monthTo.present) {
      map['month_to'] = Variable<int>(monthTo.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $SyllabusTopicsTable.$convertersource.toSql(source.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusTopicsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('ord: $ord, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('terms: $terms, ')
          ..write('monthFrom: $monthFrom, ')
          ..write('monthTo: $monthTo, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DriveDocsTable extends DriveDocs
    with TableInfo<$DriveDocsTable, DriveDoc> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriveDocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DriveDocKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DriveDocKind>($DriveDocsTable.$converterkind);
  static const VerificationMeta _docIdMeta = const VerificationMeta('docId');
  @override
  late final GeneratedColumn<String> docId = GeneratedColumn<String>(
    'doc_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectId,
    kind,
    docId,
    syncedAt,
    contentHash,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drive_docs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriveDoc> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('doc_id')) {
      context.handle(
        _docIdMeta,
        docId.isAcceptableOrUnknown(data['doc_id']!, _docIdMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId, kind};
  @override
  DriveDoc map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriveDoc(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      kind: $DriveDocsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      docId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_id'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $DriveDocsTable createAlias(String alias) {
    return $DriveDocsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DriveDocKind, int, int> $converterkind =
      const EnumIndexConverter<DriveDocKind>(DriveDocKind.values);
}

class DriveDoc extends DataClass implements Insertable<DriveDoc> {
  final int subjectId;
  final DriveDocKind kind;
  final String? docId;
  final DateTime? syncedAt;
  final String? contentHash;
  final String? error;
  const DriveDoc({
    required this.subjectId,
    required this.kind,
    this.docId,
    this.syncedAt,
    this.contentHash,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<int>(subjectId);
    {
      map['kind'] = Variable<int>($DriveDocsTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || docId != null) {
      map['doc_id'] = Variable<String>(docId);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  DriveDocsCompanion toCompanion(bool nullToAbsent) {
    return DriveDocsCompanion(
      subjectId: Value(subjectId),
      kind: Value(kind),
      docId: docId == null && nullToAbsent
          ? const Value.absent()
          : Value(docId),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory DriveDoc.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriveDoc(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      kind: $DriveDocsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      docId: serializer.fromJson<String?>(json['docId']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'kind': serializer.toJson<int>(
        $DriveDocsTable.$converterkind.toJson(kind),
      ),
      'docId': serializer.toJson<String?>(docId),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'error': serializer.toJson<String?>(error),
    };
  }

  DriveDoc copyWith({
    int? subjectId,
    DriveDocKind? kind,
    Value<String?> docId = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => DriveDoc(
    subjectId: subjectId ?? this.subjectId,
    kind: kind ?? this.kind,
    docId: docId.present ? docId.value : this.docId,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    error: error.present ? error.value : this.error,
  );
  DriveDoc copyWithCompanion(DriveDocsCompanion data) {
    return DriveDoc(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      docId: data.docId.present ? data.docId.value : this.docId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriveDoc(')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('docId: $docId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(subjectId, kind, docId, syncedAt, contentHash, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriveDoc &&
          other.subjectId == this.subjectId &&
          other.kind == this.kind &&
          other.docId == this.docId &&
          other.syncedAt == this.syncedAt &&
          other.contentHash == this.contentHash &&
          other.error == this.error);
}

class DriveDocsCompanion extends UpdateCompanion<DriveDoc> {
  final Value<int> subjectId;
  final Value<DriveDocKind> kind;
  final Value<String?> docId;
  final Value<DateTime?> syncedAt;
  final Value<String?> contentHash;
  final Value<String?> error;
  final Value<int> rowid;
  const DriveDocsCompanion({
    this.subjectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.docId = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriveDocsCompanion.insert({
    required int subjectId,
    required DriveDocKind kind,
    this.docId = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : subjectId = Value(subjectId),
       kind = Value(kind);
  static Insertable<DriveDoc> custom({
    Expression<int>? subjectId,
    Expression<int>? kind,
    Expression<String>? docId,
    Expression<DateTime>? syncedAt,
    Expression<String>? contentHash,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (kind != null) 'kind': kind,
      if (docId != null) 'doc_id': docId,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriveDocsCompanion copyWith({
    Value<int>? subjectId,
    Value<DriveDocKind>? kind,
    Value<String?>? docId,
    Value<DateTime?>? syncedAt,
    Value<String?>? contentHash,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return DriveDocsCompanion(
      subjectId: subjectId ?? this.subjectId,
      kind: kind ?? this.kind,
      docId: docId ?? this.docId,
      syncedAt: syncedAt ?? this.syncedAt,
      contentHash: contentHash ?? this.contentHash,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $DriveDocsTable.$converterkind.toSql(kind.value),
      );
    }
    if (docId.present) {
      map['doc_id'] = Variable<String>(docId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriveDocsCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('docId: $docId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $UploadQueueTable uploadQueue = $UploadQueueTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $MeetingNotesTable meetingNotes = $MeetingNotesTable(this);
  late final $AnswerCardsTable answerCards = $AnswerCardsTable(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $SavedNotesTable savedNotes = $SavedNotesTable(this);
  late final $ContextCardsTable contextCards = $ContextCardsTable(this);
  late final $CardImagesTable cardImages = $CardImagesTable(this);
  late final $MeetingCardsTable meetingCards = $MeetingCardsTable(this);
  late final $TimetableSlotsTable timetableSlots = $TimetableSlotsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $RefinedSegmentsTable refinedSegments = $RefinedSegmentsTable(
    this,
  );
  late final $SubjectTermsTable subjectTerms = $SubjectTermsTable(this);
  late final $SyllabusTopicsTable syllabusTopics = $SyllabusTopicsTable(this);
  late final $DriveDocsTable driveDocs = $DriveDocsTable(this);
  late final MeetingsDao meetingsDao = MeetingsDao(this as AppDatabase);
  late final TranscriptSegmentsDao transcriptSegmentsDao =
      TranscriptSegmentsDao(this as AppDatabase);
  late final UploadQueueDao uploadQueueDao = UploadQueueDao(
    this as AppDatabase,
  );
  late final PreferencesDao preferencesDao = PreferencesDao(
    this as AppDatabase,
  );
  late final MeetingNotesDao meetingNotesDao = MeetingNotesDao(
    this as AppDatabase,
  );
  late final AnswerCardsDao answerCardsDao = AnswerCardsDao(
    this as AppDatabase,
  );
  late final SavedNotesDao savedNotesDao = SavedNotesDao(this as AppDatabase);
  late final SubjectsDao subjectsDao = SubjectsDao(this as AppDatabase);
  late final ChatMessagesDao chatMessagesDao = ChatMessagesDao(
    this as AppDatabase,
  );
  late final RefinedSegmentsDao refinedSegmentsDao = RefinedSegmentsDao(
    this as AppDatabase,
  );
  late final DriveDocsDao driveDocsDao = DriveDocsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meetings,
    transcriptSegments,
    uploadQueue,
    preferences,
    meetingNotes,
    answerCards,
    subjects,
    savedNotes,
    contextCards,
    cardImages,
    meetingCards,
    timetableSlots,
    chatMessages,
    refinedSegments,
    subjectTerms,
    syllabusTopics,
    driveDocs,
  ];
}

typedef $$MeetingsTableCreateCompanionBuilder = MeetingsCompanion Function({
  Value<int> id,
  required String title,
  required DateTime createdAt,
  Value<DateTime?> endedAt,
  Value<bool> interrupted,
  Value<int?> subjectId,
  Value<String?> rules,
  Value<int?> topicId,
  Value<DateTime?> audioClearedAt,
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime?> endedAt,
  Value<bool> interrupted,
  Value<int?> subjectId,
  Value<String?> rules,
  Value<int?> topicId,
  Value<DateTime?> audioClearedAt,
});

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get audioClearedAt => $composableBuilder(
    column: $table.audioClearedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get audioClearedAt => $composableBuilder(
    column: $table.audioClearedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get rules =>
      $composableBuilder(column: $table.rules, builder: (column) => column);

  GeneratedColumn<int> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<DateTime> get audioClearedAt => $composableBuilder(
    column: $table.audioClearedAt,
    builder: (column) => column,
  );
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          Meeting,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (Meeting, BaseReferences<_$AppDatabase, $MeetingsTable, Meeting>),
          Meeting,
          PrefetchHooks Function()
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<String?> rules = const Value.absent(),
                Value<int?> topicId = const Value.absent(),
                Value<DateTime?> audioClearedAt = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
                subjectId: subjectId,
                rules: rules,
                topicId: topicId,
                audioClearedAt: audioClearedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime createdAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<String?> rules = const Value.absent(),
                Value<int?> topicId = const Value.absent(),
                Value<DateTime?> audioClearedAt = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
                subjectId: subjectId,
                rules: rules,
                topicId: topicId,
                audioClearedAt: audioClearedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingsTable, Meeting>(table),
                  BaseReferences<_$AppDatabase, $MeetingsTable, Meeting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      Meeting,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (Meeting, BaseReferences<_$AppDatabase, $MeetingsTable, Meeting>),
      Meeting,
      PrefetchHooks Function()
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<int> id,
      required int meetingId,
      required int sequence,
      required int startMs,
      required int endMs,
      Value<String?> content,
      required SegmentStatus status,
      required String localAudioPath,
      required DateTime createdAt,
      Value<int?> voicedMs,
      Value<String?> rawContent,
      Value<double?> confidence,
      Value<String?> cutReason,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<int> id,
      Value<int> meetingId,
      Value<int> sequence,
      Value<int> startMs,
      Value<int> endMs,
      Value<String?> content,
      Value<SegmentStatus> status,
      Value<String> localAudioPath,
      Value<DateTime> createdAt,
      Value<int?> voicedMs,
      Value<String?> rawContent,
      Value<double?> confidence,
      Value<String?> cutReason,
    });

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SegmentStatus, SegmentStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voicedMs => $composableBuilder(
    column: $table.voicedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cutReason => $composableBuilder(
    column: $table.cutReason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voicedMs => $composableBuilder(
    column: $table.voicedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cutReason => $composableBuilder(
    column: $table.cutReason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SegmentStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get voicedMs =>
      $composableBuilder(column: $table.voicedMs, builder: (column) => column);

  GeneratedColumn<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cutReason =>
      $composableBuilder(column: $table.cutReason, builder: (column) => column);
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (
            TranscriptSegment,
            BaseReferences<
              _$AppDatabase,
              $TranscriptSegmentsTable,
              TranscriptSegment
            >,
          ),
          TranscriptSegment,
          PrefetchHooks Function()
        > {
  $$TranscriptSegmentsTableTableManager(
    _$AppDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<SegmentStatus> status = const Value.absent(),
                Value<String> localAudioPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> voicedMs = const Value.absent(),
                Value<String?> rawContent = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> cutReason = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                meetingId: meetingId,
                sequence: sequence,
                startMs: startMs,
                endMs: endMs,
                content: content,
                status: status,
                localAudioPath: localAudioPath,
                createdAt: createdAt,
                voicedMs: voicedMs,
                rawContent: rawContent,
                confidence: confidence,
                cutReason: cutReason,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meetingId,
                required int sequence,
                required int startMs,
                required int endMs,
                Value<String?> content = const Value.absent(),
                required SegmentStatus status,
                required String localAudioPath,
                required DateTime createdAt,
                Value<int?> voicedMs = const Value.absent(),
                Value<String?> rawContent = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> cutReason = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                meetingId: meetingId,
                sequence: sequence,
                startMs: startMs,
                endMs: endMs,
                content: content,
                status: status,
                localAudioPath: localAudioPath,
                createdAt: createdAt,
                voicedMs: voicedMs,
                rawContent: rawContent,
                confidence: confidence,
                cutReason: cutReason,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptSegmentsTable, TranscriptSegment>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $TranscriptSegmentsTable,
                    TranscriptSegment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegment,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (
        TranscriptSegment,
        BaseReferences<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment
        >,
      ),
      TranscriptSegment,
      PrefetchHooks Function()
    >;
typedef $$UploadQueueTableCreateCompanionBuilder =
    UploadQueueCompanion Function({
      Value<int> id,
      required int segmentId,
      required int meetingId,
      required String localFilePath,
      required QueueStatus status,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$UploadQueueTableUpdateCompanionBuilder =
    UploadQueueCompanion Function({
      Value<int> id,
      Value<int> segmentId,
      Value<int> meetingId,
      Value<String> localFilePath,
      Value<QueueStatus> status,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UploadQueueTableFilterComposer
    extends Composer<_$AppDatabase, $UploadQueueTable> {
  $$UploadQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<QueueStatus, QueueStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UploadQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $UploadQueueTable> {
  $$UploadQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UploadQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $UploadQueueTable> {
  $$UploadQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<QueueStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UploadQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UploadQueueTable,
          UploadQueueData,
          $$UploadQueueTableFilterComposer,
          $$UploadQueueTableOrderingComposer,
          $$UploadQueueTableAnnotationComposer,
          $$UploadQueueTableCreateCompanionBuilder,
          $$UploadQueueTableUpdateCompanionBuilder,
          (
            UploadQueueData,
            BaseReferences<_$AppDatabase, $UploadQueueTable, UploadQueueData>,
          ),
          UploadQueueData,
          PrefetchHooks Function()
        > {
  $$UploadQueueTableTableManager(_$AppDatabase db, $UploadQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UploadQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UploadQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UploadQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> segmentId = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<String> localFilePath = const Value.absent(),
                Value<QueueStatus> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UploadQueueCompanion(
                id: id,
                segmentId: segmentId,
                meetingId: meetingId,
                localFilePath: localFilePath,
                status: status,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int segmentId,
                required int meetingId,
                required String localFilePath,
                required QueueStatus status,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => UploadQueueCompanion.insert(
                id: id,
                segmentId: segmentId,
                meetingId: meetingId,
                localFilePath: localFilePath,
                status: status,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UploadQueueTable, UploadQueueData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UploadQueueTable,
                    UploadQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UploadQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UploadQueueTable,
      UploadQueueData,
      $$UploadQueueTableFilterComposer,
      $$UploadQueueTableOrderingComposer,
      $$UploadQueueTableAnnotationComposer,
      $$UploadQueueTableCreateCompanionBuilder,
      $$UploadQueueTableUpdateCompanionBuilder,
      (
        UploadQueueData,
        BaseReferences<_$AppDatabase, $UploadQueueTable, UploadQueueData>,
      ),
      UploadQueueData,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      Value<int> id,
      Value<TranscriptLanguage> transcriptLanguage,
      Value<NotesDepth> notesDepth,
      Value<bool> liveAnswersEnabled,
      Value<bool> webAnswersEnabled,
      Value<MicSensitivity> micSensitivity,
      Value<String?> globalRules,
      Value<String?> geminiModelOverride,
      Value<bool> onboardingDismissed,
      Value<bool> contextCorrection,
      Value<String?> schoolName,
      Value<SchoolType?> schoolType,
      Value<String?> studyField,
      Value<int?> studyYear,
      Value<AudioRetention> audioRetention,
      Value<LessonReminder> lessonReminder,
      Value<String?> googleClientId,
      Value<String?> googleAccountEmail,
      Value<bool> driveSyncEnabled,
      Value<bool> driveIncludeTranscripts,
      Value<String?> driveFolderId,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<int> id,
      Value<TranscriptLanguage> transcriptLanguage,
      Value<NotesDepth> notesDepth,
      Value<bool> liveAnswersEnabled,
      Value<bool> webAnswersEnabled,
      Value<MicSensitivity> micSensitivity,
      Value<String?> globalRules,
      Value<String?> geminiModelOverride,
      Value<bool> onboardingDismissed,
      Value<bool> contextCorrection,
      Value<String?> schoolName,
      Value<SchoolType?> schoolType,
      Value<String?> studyField,
      Value<int?> studyYear,
      Value<AudioRetention> audioRetention,
      Value<LessonReminder> lessonReminder,
      Value<String?> googleClientId,
      Value<String?> googleAccountEmail,
      Value<bool> driveSyncEnabled,
      Value<bool> driveIncludeTranscripts,
      Value<String?> driveFolderId,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TranscriptLanguage, TranscriptLanguage, int>
  get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<NotesDepth, NotesDepth, int> get notesDepth =>
      $composableBuilder(
        column: $table.notesDepth,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get liveAnswersEnabled => $composableBuilder(
    column: $table.liveAnswersEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get webAnswersEnabled => $composableBuilder(
    column: $table.webAnswersEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MicSensitivity, MicSensitivity, int>
  get micSensitivity => $composableBuilder(
    column: $table.micSensitivity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get globalRules => $composableBuilder(
    column: $table.globalRules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geminiModelOverride => $composableBuilder(
    column: $table.geminiModelOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingDismissed => $composableBuilder(
    column: $table.onboardingDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get contextCorrection => $composableBuilder(
    column: $table.contextCorrection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolName => $composableBuilder(
    column: $table.schoolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SchoolType?, SchoolType, int> get schoolType =>
      $composableBuilder(
        column: $table.schoolType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get studyField => $composableBuilder(
    column: $table.studyField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studyYear => $composableBuilder(
    column: $table.studyYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AudioRetention, AudioRetention, int>
  get audioRetention => $composableBuilder(
    column: $table.audioRetention,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LessonReminder, LessonReminder, int>
  get lessonReminder => $composableBuilder(
    column: $table.lessonReminder,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get googleClientId => $composableBuilder(
    column: $table.googleClientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googleAccountEmail => $composableBuilder(
    column: $table.googleAccountEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get driveSyncEnabled => $composableBuilder(
    column: $table.driveSyncEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get driveIncludeTranscripts => $composableBuilder(
    column: $table.driveIncludeTranscripts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driveFolderId => $composableBuilder(
    column: $table.driveFolderId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notesDepth => $composableBuilder(
    column: $table.notesDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get liveAnswersEnabled => $composableBuilder(
    column: $table.liveAnswersEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get webAnswersEnabled => $composableBuilder(
    column: $table.webAnswersEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get micSensitivity => $composableBuilder(
    column: $table.micSensitivity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get globalRules => $composableBuilder(
    column: $table.globalRules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geminiModelOverride => $composableBuilder(
    column: $table.geminiModelOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingDismissed => $composableBuilder(
    column: $table.onboardingDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get contextCorrection => $composableBuilder(
    column: $table.contextCorrection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolName => $composableBuilder(
    column: $table.schoolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schoolType => $composableBuilder(
    column: $table.schoolType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studyField => $composableBuilder(
    column: $table.studyField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studyYear => $composableBuilder(
    column: $table.studyYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioRetention => $composableBuilder(
    column: $table.audioRetention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonReminder => $composableBuilder(
    column: $table.lessonReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleClientId => $composableBuilder(
    column: $table.googleClientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleAccountEmail => $composableBuilder(
    column: $table.googleAccountEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get driveSyncEnabled => $composableBuilder(
    column: $table.driveSyncEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get driveIncludeTranscripts => $composableBuilder(
    column: $table.driveIncludeTranscripts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driveFolderId => $composableBuilder(
    column: $table.driveFolderId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TranscriptLanguage, int>
  get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<NotesDepth, int> get notesDepth =>
      $composableBuilder(
        column: $table.notesDepth,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get liveAnswersEnabled => $composableBuilder(
    column: $table.liveAnswersEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get webAnswersEnabled => $composableBuilder(
    column: $table.webAnswersEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MicSensitivity, int> get micSensitivity =>
      $composableBuilder(
        column: $table.micSensitivity,
        builder: (column) => column,
      );

  GeneratedColumn<String> get globalRules => $composableBuilder(
    column: $table.globalRules,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geminiModelOverride => $composableBuilder(
    column: $table.geminiModelOverride,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingDismissed => $composableBuilder(
    column: $table.onboardingDismissed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get contextCorrection => $composableBuilder(
    column: $table.contextCorrection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schoolName => $composableBuilder(
    column: $table.schoolName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SchoolType?, int> get schoolType =>
      $composableBuilder(
        column: $table.schoolType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get studyField => $composableBuilder(
    column: $table.studyField,
    builder: (column) => column,
  );

  GeneratedColumn<int> get studyYear =>
      $composableBuilder(column: $table.studyYear, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AudioRetention, int> get audioRetention =>
      $composableBuilder(
        column: $table.audioRetention,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<LessonReminder, int> get lessonReminder =>
      $composableBuilder(
        column: $table.lessonReminder,
        builder: (column) => column,
      );

  GeneratedColumn<String> get googleClientId => $composableBuilder(
    column: $table.googleClientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get googleAccountEmail => $composableBuilder(
    column: $table.googleAccountEmail,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get driveSyncEnabled => $composableBuilder(
    column: $table.driveSyncEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get driveIncludeTranscripts => $composableBuilder(
    column: $table.driveIncludeTranscripts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get driveFolderId => $composableBuilder(
    column: $table.driveFolderId,
    builder: (column) => column,
  );
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TranscriptLanguage> transcriptLanguage =
                    const Value.absent(),
                Value<NotesDepth> notesDepth = const Value.absent(),
                Value<bool> liveAnswersEnabled = const Value.absent(),
                Value<bool> webAnswersEnabled = const Value.absent(),
                Value<MicSensitivity> micSensitivity = const Value.absent(),
                Value<String?> globalRules = const Value.absent(),
                Value<String?> geminiModelOverride = const Value.absent(),
                Value<bool> onboardingDismissed = const Value.absent(),
                Value<bool> contextCorrection = const Value.absent(),
                Value<String?> schoolName = const Value.absent(),
                Value<SchoolType?> schoolType = const Value.absent(),
                Value<String?> studyField = const Value.absent(),
                Value<int?> studyYear = const Value.absent(),
                Value<AudioRetention> audioRetention = const Value.absent(),
                Value<LessonReminder> lessonReminder = const Value.absent(),
                Value<String?> googleClientId = const Value.absent(),
                Value<String?> googleAccountEmail = const Value.absent(),
                Value<bool> driveSyncEnabled = const Value.absent(),
                Value<bool> driveIncludeTranscripts = const Value.absent(),
                Value<String?> driveFolderId = const Value.absent(),
              }) => PreferencesCompanion(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
                globalRules: globalRules,
                geminiModelOverride: geminiModelOverride,
                onboardingDismissed: onboardingDismissed,
                contextCorrection: contextCorrection,
                schoolName: schoolName,
                schoolType: schoolType,
                studyField: studyField,
                studyYear: studyYear,
                audioRetention: audioRetention,
                lessonReminder: lessonReminder,
                googleClientId: googleClientId,
                googleAccountEmail: googleAccountEmail,
                driveSyncEnabled: driveSyncEnabled,
                driveIncludeTranscripts: driveIncludeTranscripts,
                driveFolderId: driveFolderId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TranscriptLanguage> transcriptLanguage =
                    const Value.absent(),
                Value<NotesDepth> notesDepth = const Value.absent(),
                Value<bool> liveAnswersEnabled = const Value.absent(),
                Value<bool> webAnswersEnabled = const Value.absent(),
                Value<MicSensitivity> micSensitivity = const Value.absent(),
                Value<String?> globalRules = const Value.absent(),
                Value<String?> geminiModelOverride = const Value.absent(),
                Value<bool> onboardingDismissed = const Value.absent(),
                Value<bool> contextCorrection = const Value.absent(),
                Value<String?> schoolName = const Value.absent(),
                Value<SchoolType?> schoolType = const Value.absent(),
                Value<String?> studyField = const Value.absent(),
                Value<int?> studyYear = const Value.absent(),
                Value<AudioRetention> audioRetention = const Value.absent(),
                Value<LessonReminder> lessonReminder = const Value.absent(),
                Value<String?> googleClientId = const Value.absent(),
                Value<String?> googleAccountEmail = const Value.absent(),
                Value<bool> driveSyncEnabled = const Value.absent(),
                Value<bool> driveIncludeTranscripts = const Value.absent(),
                Value<String?> driveFolderId = const Value.absent(),
              }) => PreferencesCompanion.insert(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
                globalRules: globalRules,
                geminiModelOverride: geminiModelOverride,
                onboardingDismissed: onboardingDismissed,
                contextCorrection: contextCorrection,
                schoolName: schoolName,
                schoolType: schoolType,
                studyField: studyField,
                studyYear: studyYear,
                audioRetention: audioRetention,
                lessonReminder: lessonReminder,
                googleClientId: googleClientId,
                googleAccountEmail: googleAccountEmail,
                driveSyncEnabled: driveSyncEnabled,
                driveIncludeTranscripts: driveIncludeTranscripts,
                driveFolderId: driveFolderId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, Preference>(table),
                  BaseReferences<_$AppDatabase, $PreferencesTable, Preference>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;
typedef $$MeetingNotesTableCreateCompanionBuilder =
    MeetingNotesCompanion Function({
      Value<int> id,
      required int meetingId,
      required NotesDepth depth,
      Value<String?> content,
      required String model,
      required NotesStatus status,
      Value<String?> cardSuggestions,
      Value<String?> error,
      required DateTime createdAt,
    });
typedef $$MeetingNotesTableUpdateCompanionBuilder =
    MeetingNotesCompanion Function({
      Value<int> id,
      Value<int> meetingId,
      Value<NotesDepth> depth,
      Value<String?> content,
      Value<String> model,
      Value<NotesStatus> status,
      Value<String?> cardSuggestions,
      Value<String?> error,
      Value<DateTime> createdAt,
    });

class $$MeetingNotesTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingNotesTable> {
  $$MeetingNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NotesDepth, NotesDepth, int> get depth =>
      $composableBuilder(
        column: $table.depth,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NotesStatus, NotesStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get cardSuggestions => $composableBuilder(
    column: $table.cardSuggestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeetingNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingNotesTable> {
  $$MeetingNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardSuggestions => $composableBuilder(
    column: $table.cardSuggestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingNotesTable> {
  $$MeetingNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NotesDepth, int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NotesStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get cardSuggestions => $composableBuilder(
    column: $table.cardSuggestions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MeetingNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingNotesTable,
          MeetingNote,
          $$MeetingNotesTableFilterComposer,
          $$MeetingNotesTableOrderingComposer,
          $$MeetingNotesTableAnnotationComposer,
          $$MeetingNotesTableCreateCompanionBuilder,
          $$MeetingNotesTableUpdateCompanionBuilder,
          (
            MeetingNote,
            BaseReferences<_$AppDatabase, $MeetingNotesTable, MeetingNote>,
          ),
          MeetingNote,
          PrefetchHooks Function()
        > {
  $$MeetingNotesTableTableManager(_$AppDatabase db, $MeetingNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<NotesDepth> depth = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<NotesStatus> status = const Value.absent(),
                Value<String?> cardSuggestions = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MeetingNotesCompanion(
                id: id,
                meetingId: meetingId,
                depth: depth,
                content: content,
                model: model,
                status: status,
                cardSuggestions: cardSuggestions,
                error: error,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meetingId,
                required NotesDepth depth,
                Value<String?> content = const Value.absent(),
                required String model,
                required NotesStatus status,
                Value<String?> cardSuggestions = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
              }) => MeetingNotesCompanion.insert(
                id: id,
                meetingId: meetingId,
                depth: depth,
                content: content,
                model: model,
                status: status,
                cardSuggestions: cardSuggestions,
                error: error,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingNotesTable, MeetingNote>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MeetingNotesTable,
                    MeetingNote
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeetingNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingNotesTable,
      MeetingNote,
      $$MeetingNotesTableFilterComposer,
      $$MeetingNotesTableOrderingComposer,
      $$MeetingNotesTableAnnotationComposer,
      $$MeetingNotesTableCreateCompanionBuilder,
      $$MeetingNotesTableUpdateCompanionBuilder,
      (
        MeetingNote,
        BaseReferences<_$AppDatabase, $MeetingNotesTable, MeetingNote>,
      ),
      MeetingNote,
      PrefetchHooks Function()
    >;
typedef $$AnswerCardsTableCreateCompanionBuilder =
    AnswerCardsCompanion Function({
      Value<int> id,
      required int meetingId,
      required int segmentId,
      required String question,
      required String answer,
      Value<String> basis,
      Value<String?> sources,
      Value<String?> detail,
      Value<int?> cardId,
      Value<bool> dismissed,
      required DateTime createdAt,
    });
typedef $$AnswerCardsTableUpdateCompanionBuilder =
    AnswerCardsCompanion Function({
      Value<int> id,
      Value<int> meetingId,
      Value<int> segmentId,
      Value<String> question,
      Value<String> answer,
      Value<String> basis,
      Value<String?> sources,
      Value<String?> detail,
      Value<int?> cardId,
      Value<bool> dismissed,
      Value<DateTime> createdAt,
    });

class $$AnswerCardsTableFilterComposer
    extends Composer<_$AppDatabase, $AnswerCardsTable> {
  $$AnswerCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnswerCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnswerCardsTable> {
  $$AnswerCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnswerCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnswerCardsTable> {
  $$AnswerCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<int> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AnswerCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnswerCardsTable,
          AnswerCard,
          $$AnswerCardsTableFilterComposer,
          $$AnswerCardsTableOrderingComposer,
          $$AnswerCardsTableAnnotationComposer,
          $$AnswerCardsTableCreateCompanionBuilder,
          $$AnswerCardsTableUpdateCompanionBuilder,
          (
            AnswerCard,
            BaseReferences<_$AppDatabase, $AnswerCardsTable, AnswerCard>,
          ),
          AnswerCard,
          PrefetchHooks Function()
        > {
  $$AnswerCardsTableTableManager(_$AppDatabase db, $AnswerCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnswerCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnswerCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnswerCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<int> segmentId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<int?> cardId = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AnswerCardsCompanion(
                id: id,
                meetingId: meetingId,
                segmentId: segmentId,
                question: question,
                answer: answer,
                basis: basis,
                sources: sources,
                detail: detail,
                cardId: cardId,
                dismissed: dismissed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meetingId,
                required int segmentId,
                required String question,
                required String answer,
                Value<String> basis = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<int?> cardId = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                required DateTime createdAt,
              }) => AnswerCardsCompanion.insert(
                id: id,
                meetingId: meetingId,
                segmentId: segmentId,
                question: question,
                answer: answer,
                basis: basis,
                sources: sources,
                detail: detail,
                cardId: cardId,
                dismissed: dismissed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnswerCardsTable, AnswerCard>(table),
                  BaseReferences<_$AppDatabase, $AnswerCardsTable, AnswerCard>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnswerCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnswerCardsTable,
      AnswerCard,
      $$AnswerCardsTableFilterComposer,
      $$AnswerCardsTableOrderingComposer,
      $$AnswerCardsTableAnnotationComposer,
      $$AnswerCardsTableCreateCompanionBuilder,
      $$AnswerCardsTableUpdateCompanionBuilder,
      (
        AnswerCard,
        BaseReferences<_$AppDatabase, $AnswerCardsTable, AnswerCard>,
      ),
      AnswerCard,
      PrefetchHooks Function()
    >;
typedef $$SubjectsTableCreateCompanionBuilder = SubjectsCompanion Function({
  Value<int> id,
  required String name,
  required DateTime createdAt,
  Value<String?> rules,
  Value<int> colorIndex,
  Value<int> sortOrder,
  Value<String?> fullName,
  Value<String?> levelOverride,
});
typedef $$SubjectsTableUpdateCompanionBuilder = SubjectsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<String?> rules,
  Value<int> colorIndex,
  Value<int> sortOrder,
  Value<String?> fullName,
  Value<String?> levelOverride,
});

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get levelOverride => $composableBuilder(
    column: $table.levelOverride,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get levelOverride => $composableBuilder(
    column: $table.levelOverride,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get rules =>
      $composableBuilder(column: $table.rules, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get levelOverride => $composableBuilder(
    column: $table.levelOverride,
    builder: (column) => column,
  );
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          Subject,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
          Subject,
          PrefetchHooks Function()
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> rules = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> fullName = const Value.absent(),
                Value<String?> levelOverride = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                rules: rules,
                colorIndex: colorIndex,
                sortOrder: sortOrder,
                fullName: fullName,
                levelOverride: levelOverride,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
                Value<String?> rules = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> fullName = const Value.absent(),
                Value<String?> levelOverride = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                rules: rules,
                colorIndex: colorIndex,
                sortOrder: sortOrder,
                fullName: fullName,
                levelOverride: levelOverride,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubjectsTable, Subject>(table),
                  BaseReferences<_$AppDatabase, $SubjectsTable, Subject>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      Subject,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
      Subject,
      PrefetchHooks Function()
    >;
typedef $$SavedNotesTableCreateCompanionBuilder = SavedNotesCompanion Function({
  Value<int> id,
  required String title,
  required String content,
  Value<int?> folderId,
  Value<int?> meetingId,
  Value<NotesDepth?> depth,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$SavedNotesTableUpdateCompanionBuilder = SavedNotesCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> content,
  Value<int?> folderId,
  Value<int?> meetingId,
  Value<NotesDepth?> depth,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$SavedNotesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedNotesTable> {
  $$SavedNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NotesDepth?, NotesDepth, int> get depth =>
      $composableBuilder(
        column: $table.depth,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedNotesTable> {
  $$SavedNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedNotesTable> {
  $$SavedNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NotesDepth?, int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SavedNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedNotesTable,
          SavedNote,
          $$SavedNotesTableFilterComposer,
          $$SavedNotesTableOrderingComposer,
          $$SavedNotesTableAnnotationComposer,
          $$SavedNotesTableCreateCompanionBuilder,
          $$SavedNotesTableUpdateCompanionBuilder,
          (
            SavedNote,
            BaseReferences<_$AppDatabase, $SavedNotesTable, SavedNote>,
          ),
          SavedNote,
          PrefetchHooks Function()
        > {
  $$SavedNotesTableTableManager(_$AppDatabase db, $SavedNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<int?> meetingId = const Value.absent(),
                Value<NotesDepth?> depth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SavedNotesCompanion(
                id: id,
                title: title,
                content: content,
                folderId: folderId,
                meetingId: meetingId,
                depth: depth,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String content,
                Value<int?> folderId = const Value.absent(),
                Value<int?> meetingId = const Value.absent(),
                Value<NotesDepth?> depth = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => SavedNotesCompanion.insert(
                id: id,
                title: title,
                content: content,
                folderId: folderId,
                meetingId: meetingId,
                depth: depth,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedNotesTable, SavedNote>(table),
                  BaseReferences<_$AppDatabase, $SavedNotesTable, SavedNote>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedNotesTable,
      SavedNote,
      $$SavedNotesTableFilterComposer,
      $$SavedNotesTableOrderingComposer,
      $$SavedNotesTableAnnotationComposer,
      $$SavedNotesTableCreateCompanionBuilder,
      $$SavedNotesTableUpdateCompanionBuilder,
      (SavedNote, BaseReferences<_$AppDatabase, $SavedNotesTable, SavedNote>),
      SavedNote,
      PrefetchHooks Function()
    >;
typedef $$ContextCardsTableCreateCompanionBuilder =
    ContextCardsCompanion Function({
      Value<int> id,
      required int subjectId,
      required String title,
      required CardKind kind,
      Value<String> content,
      Value<String?> summary,
      Value<String?> keywords,
      Value<String?> sources,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastUsedAt,
    });
typedef $$ContextCardsTableUpdateCompanionBuilder =
    ContextCardsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> title,
      Value<CardKind> kind,
      Value<String> content,
      Value<String?> summary,
      Value<String?> keywords,
      Value<String?> sources,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastUsedAt,
    });

class $$ContextCardsTableFilterComposer
    extends Composer<_$AppDatabase, $ContextCardsTable> {
  $$ContextCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CardKind, CardKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContextCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContextCardsTable> {
  $$ContextCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContextCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContextCardsTable> {
  $$ContextCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$ContextCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContextCardsTable,
          ContextCard,
          $$ContextCardsTableFilterComposer,
          $$ContextCardsTableOrderingComposer,
          $$ContextCardsTableAnnotationComposer,
          $$ContextCardsTableCreateCompanionBuilder,
          $$ContextCardsTableUpdateCompanionBuilder,
          (
            ContextCard,
            BaseReferences<_$AppDatabase, $ContextCardsTable, ContextCard>,
          ),
          ContextCard,
          PrefetchHooks Function()
        > {
  $$ContextCardsTableTableManager(_$AppDatabase db, $ContextCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContextCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContextCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContextCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<CardKind> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> keywords = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
              }) => ContextCardsCompanion(
                id: id,
                subjectId: subjectId,
                title: title,
                kind: kind,
                content: content,
                summary: summary,
                keywords: keywords,
                sources: sources,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String title,
                required CardKind kind,
                Value<String> content = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> keywords = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastUsedAt = const Value.absent(),
              }) => ContextCardsCompanion.insert(
                id: id,
                subjectId: subjectId,
                title: title,
                kind: kind,
                content: content,
                summary: summary,
                keywords: keywords,
                sources: sources,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContextCardsTable, ContextCard>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ContextCardsTable,
                    ContextCard
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContextCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContextCardsTable,
      ContextCard,
      $$ContextCardsTableFilterComposer,
      $$ContextCardsTableOrderingComposer,
      $$ContextCardsTableAnnotationComposer,
      $$ContextCardsTableCreateCompanionBuilder,
      $$ContextCardsTableUpdateCompanionBuilder,
      (
        ContextCard,
        BaseReferences<_$AppDatabase, $ContextCardsTable, ContextCard>,
      ),
      ContextCard,
      PrefetchHooks Function()
    >;
typedef $$CardImagesTableCreateCompanionBuilder = CardImagesCompanion Function({
  Value<int> id,
  required int cardId,
  required String path,
  Value<int> ord,
});
typedef $$CardImagesTableUpdateCompanionBuilder = CardImagesCompanion Function({
  Value<int> id,
  Value<int> cardId,
  Value<String> path,
  Value<int> ord,
});

class $$CardImagesTableFilterComposer
    extends Composer<_$AppDatabase, $CardImagesTable> {
  $$CardImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CardImagesTable> {
  $$CardImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardImagesTable> {
  $$CardImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);
}

class $$CardImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardImagesTable,
          CardImage,
          $$CardImagesTableFilterComposer,
          $$CardImagesTableOrderingComposer,
          $$CardImagesTableAnnotationComposer,
          $$CardImagesTableCreateCompanionBuilder,
          $$CardImagesTableUpdateCompanionBuilder,
          (
            CardImage,
            BaseReferences<_$AppDatabase, $CardImagesTable, CardImage>,
          ),
          CardImage,
          PrefetchHooks Function()
        > {
  $$CardImagesTableTableManager(_$AppDatabase db, $CardImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> ord = const Value.absent(),
              }) => CardImagesCompanion(
                id: id,
                cardId: cardId,
                path: path,
                ord: ord,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String path,
                Value<int> ord = const Value.absent(),
              }) => CardImagesCompanion.insert(
                id: id,
                cardId: cardId,
                path: path,
                ord: ord,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardImagesTable, CardImage>(table),
                  BaseReferences<_$AppDatabase, $CardImagesTable, CardImage>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardImagesTable,
      CardImage,
      $$CardImagesTableFilterComposer,
      $$CardImagesTableOrderingComposer,
      $$CardImagesTableAnnotationComposer,
      $$CardImagesTableCreateCompanionBuilder,
      $$CardImagesTableUpdateCompanionBuilder,
      (CardImage, BaseReferences<_$AppDatabase, $CardImagesTable, CardImage>),
      CardImage,
      PrefetchHooks Function()
    >;
typedef $$MeetingCardsTableCreateCompanionBuilder =
    MeetingCardsCompanion Function({
      required int meetingId,
      required int cardId,
      Value<int> rowid,
    });
typedef $$MeetingCardsTableUpdateCompanionBuilder =
    MeetingCardsCompanion Function({
      Value<int> meetingId,
      Value<int> cardId,
      Value<int> rowid,
    });

class $$MeetingCardsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingCardsTable> {
  $$MeetingCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeetingCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingCardsTable> {
  $$MeetingCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingCardsTable> {
  $$MeetingCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);
}

class $$MeetingCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingCardsTable,
          MeetingCard,
          $$MeetingCardsTableFilterComposer,
          $$MeetingCardsTableOrderingComposer,
          $$MeetingCardsTableAnnotationComposer,
          $$MeetingCardsTableCreateCompanionBuilder,
          $$MeetingCardsTableUpdateCompanionBuilder,
          (
            MeetingCard,
            BaseReferences<_$AppDatabase, $MeetingCardsTable, MeetingCard>,
          ),
          MeetingCard,
          PrefetchHooks Function()
        > {
  $$MeetingCardsTableTableManager(_$AppDatabase db, $MeetingCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> meetingId = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingCardsCompanion(
                meetingId: meetingId,
                cardId: cardId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int meetingId,
                required int cardId,
                Value<int> rowid = const Value.absent(),
              }) => MeetingCardsCompanion.insert(
                meetingId: meetingId,
                cardId: cardId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingCardsTable, MeetingCard>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MeetingCardsTable,
                    MeetingCard
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeetingCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingCardsTable,
      MeetingCard,
      $$MeetingCardsTableFilterComposer,
      $$MeetingCardsTableOrderingComposer,
      $$MeetingCardsTableAnnotationComposer,
      $$MeetingCardsTableCreateCompanionBuilder,
      $$MeetingCardsTableUpdateCompanionBuilder,
      (
        MeetingCard,
        BaseReferences<_$AppDatabase, $MeetingCardsTable, MeetingCard>,
      ),
      MeetingCard,
      PrefetchHooks Function()
    >;
typedef $$TimetableSlotsTableCreateCompanionBuilder =
    TimetableSlotsCompanion Function({
      Value<int> id,
      required int subjectId,
      required int weekday,
      required int startMinute,
      required int endMinute,
    });
typedef $$TimetableSlotsTableUpdateCompanionBuilder =
    TimetableSlotsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<int> weekday,
      Value<int> startMinute,
      Value<int> endMinute,
    });

class $$TimetableSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $TimetableSlotsTable> {
  $$TimetableSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimetableSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimetableSlotsTable> {
  $$TimetableSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimetableSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimetableSlotsTable> {
  $$TimetableSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);
}

class $$TimetableSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimetableSlotsTable,
          TimetableSlot,
          $$TimetableSlotsTableFilterComposer,
          $$TimetableSlotsTableOrderingComposer,
          $$TimetableSlotsTableAnnotationComposer,
          $$TimetableSlotsTableCreateCompanionBuilder,
          $$TimetableSlotsTableUpdateCompanionBuilder,
          (
            TimetableSlot,
            BaseReferences<_$AppDatabase, $TimetableSlotsTable, TimetableSlot>,
          ),
          TimetableSlot,
          PrefetchHooks Function()
        > {
  $$TimetableSlotsTableTableManager(
    _$AppDatabase db,
    $TimetableSlotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimetableSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimetableSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimetableSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> weekday = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
              }) => TimetableSlotsCompanion(
                id: id,
                subjectId: subjectId,
                weekday: weekday,
                startMinute: startMinute,
                endMinute: endMinute,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required int weekday,
                required int startMinute,
                required int endMinute,
              }) => TimetableSlotsCompanion.insert(
                id: id,
                subjectId: subjectId,
                weekday: weekday,
                startMinute: startMinute,
                endMinute: endMinute,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimetableSlotsTable, TimetableSlot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TimetableSlotsTable,
                    TimetableSlot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimetableSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimetableSlotsTable,
      TimetableSlot,
      $$TimetableSlotsTableFilterComposer,
      $$TimetableSlotsTableOrderingComposer,
      $$TimetableSlotsTableAnnotationComposer,
      $$TimetableSlotsTableCreateCompanionBuilder,
      $$TimetableSlotsTableUpdateCompanionBuilder,
      (
        TimetableSlot,
        BaseReferences<_$AppDatabase, $TimetableSlotsTable, TimetableSlot>,
      ),
      TimetableSlot,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> id,
      required int meetingId,
      required ChatRole role,
      required ChatIntent intent,
      Value<String> body,
      Value<String?> imagePath,
      required int atMs,
      required ChatStatus status,
      Value<String?> short,
      Value<String?> detail,
      Value<String?> basis,
      Value<String?> sources,
      Value<int?> replyTo,
      required DateTime createdAt,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> id,
      Value<int> meetingId,
      Value<ChatRole> role,
      Value<ChatIntent> intent,
      Value<String> body,
      Value<String?> imagePath,
      Value<int> atMs,
      Value<ChatStatus> status,
      Value<String?> short,
      Value<String?> detail,
      Value<String?> basis,
      Value<String?> sources,
      Value<int?> replyTo,
      Value<DateTime> createdAt,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ChatRole, ChatRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ChatIntent, ChatIntent, String> get intent =>
      $composableBuilder(
        column: $table.intent,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ChatStatus, ChatStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get short => $composableBuilder(
    column: $table.short,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intent => $composableBuilder(
    column: $table.intent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get short => $composableBuilder(
    column: $table.short,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChatRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChatIntent, String> get intent =>
      $composableBuilder(column: $table.intent, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChatStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get short =>
      $composableBuilder(column: $table.short, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<int> get replyTo =>
      $composableBuilder(column: $table.replyTo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<ChatRole> role = const Value.absent(),
                Value<ChatIntent> intent = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<ChatStatus> status = const Value.absent(),
                Value<String?> short = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> basis = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<int?> replyTo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                meetingId: meetingId,
                role: role,
                intent: intent,
                body: body,
                imagePath: imagePath,
                atMs: atMs,
                status: status,
                short: short,
                detail: detail,
                basis: basis,
                sources: sources,
                replyTo: replyTo,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meetingId,
                required ChatRole role,
                required ChatIntent intent,
                Value<String> body = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                required int atMs,
                required ChatStatus status,
                Value<String?> short = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> basis = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<int?> replyTo = const Value.absent(),
                required DateTime createdAt,
              }) => ChatMessagesCompanion.insert(
                id: id,
                meetingId: meetingId,
                role: role,
                intent: intent,
                body: body,
                imagePath: imagePath,
                atMs: atMs,
                status: status,
                short: short,
                detail: detail,
                basis: basis,
                sources: sources,
                replyTo: replyTo,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatMessagesTable,
                    ChatMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;
typedef $$RefinedSegmentsTableCreateCompanionBuilder =
    RefinedSegmentsCompanion Function({
      Value<int> id,
      required int meetingId,
      required int windowIndex,
      required int startMs,
      required int endMs,
      Value<String?> content,
      required RefinedEngine engine,
      required RefinedStatus status,
      Value<String?> error,
      required DateTime createdAt,
      Value<String?> rawContent,
    });
typedef $$RefinedSegmentsTableUpdateCompanionBuilder =
    RefinedSegmentsCompanion Function({
      Value<int> id,
      Value<int> meetingId,
      Value<int> windowIndex,
      Value<int> startMs,
      Value<int> endMs,
      Value<String?> content,
      Value<RefinedEngine> engine,
      Value<RefinedStatus> status,
      Value<String?> error,
      Value<DateTime> createdAt,
      Value<String?> rawContent,
    });

class $$RefinedSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $RefinedSegmentsTable> {
  $$RefinedSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowIndex => $composableBuilder(
    column: $table.windowIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RefinedEngine, RefinedEngine, String>
  get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<RefinedStatus, RefinedStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RefinedSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RefinedSegmentsTable> {
  $$RefinedSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meetingId => $composableBuilder(
    column: $table.meetingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowIndex => $composableBuilder(
    column: $table.windowIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RefinedSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RefinedSegmentsTable> {
  $$RefinedSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meetingId =>
      $composableBuilder(column: $table.meetingId, builder: (column) => column);

  GeneratedColumn<int> get windowIndex => $composableBuilder(
    column: $table.windowIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RefinedEngine, String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RefinedStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get rawContent => $composableBuilder(
    column: $table.rawContent,
    builder: (column) => column,
  );
}

class $$RefinedSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RefinedSegmentsTable,
          RefinedSegment,
          $$RefinedSegmentsTableFilterComposer,
          $$RefinedSegmentsTableOrderingComposer,
          $$RefinedSegmentsTableAnnotationComposer,
          $$RefinedSegmentsTableCreateCompanionBuilder,
          $$RefinedSegmentsTableUpdateCompanionBuilder,
          (
            RefinedSegment,
            BaseReferences<
              _$AppDatabase,
              $RefinedSegmentsTable,
              RefinedSegment
            >,
          ),
          RefinedSegment,
          PrefetchHooks Function()
        > {
  $$RefinedSegmentsTableTableManager(
    _$AppDatabase db,
    $RefinedSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RefinedSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RefinedSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RefinedSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meetingId = const Value.absent(),
                Value<int> windowIndex = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<RefinedEngine> engine = const Value.absent(),
                Value<RefinedStatus> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> rawContent = const Value.absent(),
              }) => RefinedSegmentsCompanion(
                id: id,
                meetingId: meetingId,
                windowIndex: windowIndex,
                startMs: startMs,
                endMs: endMs,
                content: content,
                engine: engine,
                status: status,
                error: error,
                createdAt: createdAt,
                rawContent: rawContent,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meetingId,
                required int windowIndex,
                required int startMs,
                required int endMs,
                Value<String?> content = const Value.absent(),
                required RefinedEngine engine,
                required RefinedStatus status,
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
                Value<String?> rawContent = const Value.absent(),
              }) => RefinedSegmentsCompanion.insert(
                id: id,
                meetingId: meetingId,
                windowIndex: windowIndex,
                startMs: startMs,
                endMs: endMs,
                content: content,
                engine: engine,
                status: status,
                error: error,
                createdAt: createdAt,
                rawContent: rawContent,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RefinedSegmentsTable, RefinedSegment>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RefinedSegmentsTable,
                    RefinedSegment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RefinedSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RefinedSegmentsTable,
      RefinedSegment,
      $$RefinedSegmentsTableFilterComposer,
      $$RefinedSegmentsTableOrderingComposer,
      $$RefinedSegmentsTableAnnotationComposer,
      $$RefinedSegmentsTableCreateCompanionBuilder,
      $$RefinedSegmentsTableUpdateCompanionBuilder,
      (
        RefinedSegment,
        BaseReferences<_$AppDatabase, $RefinedSegmentsTable, RefinedSegment>,
      ),
      RefinedSegment,
      PrefetchHooks Function()
    >;
typedef $$SubjectTermsTableCreateCompanionBuilder =
    SubjectTermsCompanion Function({
      Value<int> id,
      required int subjectId,
      required String term,
      Value<String?> heard,
      required TermSource source,
      Value<int> uses,
      required DateTime createdAt,
    });
typedef $$SubjectTermsTableUpdateCompanionBuilder =
    SubjectTermsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> term,
      Value<String?> heard,
      Value<TermSource> source,
      Value<int> uses,
      Value<DateTime> createdAt,
    });

class $$SubjectTermsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectTermsTable> {
  $$SubjectTermsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heard => $composableBuilder(
    column: $table.heard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TermSource, TermSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get uses => $composableBuilder(
    column: $table.uses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectTermsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectTermsTable> {
  $$SubjectTermsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heard => $composableBuilder(
    column: $table.heard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uses => $composableBuilder(
    column: $table.uses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectTermsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectTermsTable> {
  $$SubjectTermsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get heard =>
      $composableBuilder(column: $table.heard, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TermSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get uses =>
      $composableBuilder(column: $table.uses, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SubjectTermsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectTermsTable,
          SubjectTerm,
          $$SubjectTermsTableFilterComposer,
          $$SubjectTermsTableOrderingComposer,
          $$SubjectTermsTableAnnotationComposer,
          $$SubjectTermsTableCreateCompanionBuilder,
          $$SubjectTermsTableUpdateCompanionBuilder,
          (
            SubjectTerm,
            BaseReferences<_$AppDatabase, $SubjectTermsTable, SubjectTerm>,
          ),
          SubjectTerm,
          PrefetchHooks Function()
        > {
  $$SubjectTermsTableTableManager(_$AppDatabase db, $SubjectTermsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectTermsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectTermsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectTermsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String?> heard = const Value.absent(),
                Value<TermSource> source = const Value.absent(),
                Value<int> uses = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SubjectTermsCompanion(
                id: id,
                subjectId: subjectId,
                term: term,
                heard: heard,
                source: source,
                uses: uses,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String term,
                Value<String?> heard = const Value.absent(),
                required TermSource source,
                Value<int> uses = const Value.absent(),
                required DateTime createdAt,
              }) => SubjectTermsCompanion.insert(
                id: id,
                subjectId: subjectId,
                term: term,
                heard: heard,
                source: source,
                uses: uses,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubjectTermsTable, SubjectTerm>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SubjectTermsTable,
                    SubjectTerm
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectTermsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectTermsTable,
      SubjectTerm,
      $$SubjectTermsTableFilterComposer,
      $$SubjectTermsTableOrderingComposer,
      $$SubjectTermsTableAnnotationComposer,
      $$SubjectTermsTableCreateCompanionBuilder,
      $$SubjectTermsTableUpdateCompanionBuilder,
      (
        SubjectTerm,
        BaseReferences<_$AppDatabase, $SubjectTermsTable, SubjectTerm>,
      ),
      SubjectTerm,
      PrefetchHooks Function()
    >;
typedef $$SyllabusTopicsTableCreateCompanionBuilder =
    SyllabusTopicsCompanion Function({
      Value<int> id,
      required int subjectId,
      required int ord,
      required String title,
      Value<String?> description,
      Value<String?> terms,
      Value<int?> monthFrom,
      Value<int?> monthTo,
      required SyllabusSource source,
      required DateTime createdAt,
    });
typedef $$SyllabusTopicsTableUpdateCompanionBuilder =
    SyllabusTopicsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<int> ord,
      Value<String> title,
      Value<String?> description,
      Value<String?> terms,
      Value<int?> monthFrom,
      Value<int?> monthTo,
      Value<SyllabusSource> source,
      Value<DateTime> createdAt,
    });

class $$SyllabusTopicsTableFilterComposer
    extends Composer<_$AppDatabase, $SyllabusTopicsTable> {
  $$SyllabusTopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get terms => $composableBuilder(
    column: $table.terms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthFrom => $composableBuilder(
    column: $table.monthFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthTo => $composableBuilder(
    column: $table.monthTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyllabusSource, SyllabusSource, int>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyllabusTopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyllabusTopicsTable> {
  $$SyllabusTopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get terms => $composableBuilder(
    column: $table.terms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthFrom => $composableBuilder(
    column: $table.monthFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthTo => $composableBuilder(
    column: $table.monthTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyllabusTopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyllabusTopicsTable> {
  $$SyllabusTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get terms =>
      $composableBuilder(column: $table.terms, builder: (column) => column);

  GeneratedColumn<int> get monthFrom =>
      $composableBuilder(column: $table.monthFrom, builder: (column) => column);

  GeneratedColumn<int> get monthTo =>
      $composableBuilder(column: $table.monthTo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyllabusSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyllabusTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyllabusTopicsTable,
          SyllabusTopic,
          $$SyllabusTopicsTableFilterComposer,
          $$SyllabusTopicsTableOrderingComposer,
          $$SyllabusTopicsTableAnnotationComposer,
          $$SyllabusTopicsTableCreateCompanionBuilder,
          $$SyllabusTopicsTableUpdateCompanionBuilder,
          (
            SyllabusTopic,
            BaseReferences<_$AppDatabase, $SyllabusTopicsTable, SyllabusTopic>,
          ),
          SyllabusTopic,
          PrefetchHooks Function()
        > {
  $$SyllabusTopicsTableTableManager(
    _$AppDatabase db,
    $SyllabusTopicsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyllabusTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyllabusTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyllabusTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> terms = const Value.absent(),
                Value<int?> monthFrom = const Value.absent(),
                Value<int?> monthTo = const Value.absent(),
                Value<SyllabusSource> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyllabusTopicsCompanion(
                id: id,
                subjectId: subjectId,
                ord: ord,
                title: title,
                description: description,
                terms: terms,
                monthFrom: monthFrom,
                monthTo: monthTo,
                source: source,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required int ord,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> terms = const Value.absent(),
                Value<int?> monthFrom = const Value.absent(),
                Value<int?> monthTo = const Value.absent(),
                required SyllabusSource source,
                required DateTime createdAt,
              }) => SyllabusTopicsCompanion.insert(
                id: id,
                subjectId: subjectId,
                ord: ord,
                title: title,
                description: description,
                terms: terms,
                monthFrom: monthFrom,
                monthTo: monthTo,
                source: source,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyllabusTopicsTable, SyllabusTopic>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyllabusTopicsTable,
                    SyllabusTopic
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyllabusTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyllabusTopicsTable,
      SyllabusTopic,
      $$SyllabusTopicsTableFilterComposer,
      $$SyllabusTopicsTableOrderingComposer,
      $$SyllabusTopicsTableAnnotationComposer,
      $$SyllabusTopicsTableCreateCompanionBuilder,
      $$SyllabusTopicsTableUpdateCompanionBuilder,
      (
        SyllabusTopic,
        BaseReferences<_$AppDatabase, $SyllabusTopicsTable, SyllabusTopic>,
      ),
      SyllabusTopic,
      PrefetchHooks Function()
    >;
typedef $$DriveDocsTableCreateCompanionBuilder = DriveDocsCompanion Function({
  required int subjectId,
  required DriveDocKind kind,
  Value<String?> docId,
  Value<DateTime?> syncedAt,
  Value<String?> contentHash,
  Value<String?> error,
  Value<int> rowid,
});
typedef $$DriveDocsTableUpdateCompanionBuilder = DriveDocsCompanion Function({
  Value<int> subjectId,
  Value<DriveDocKind> kind,
  Value<String?> docId,
  Value<DateTime?> syncedAt,
  Value<String?> contentHash,
  Value<String?> error,
  Value<int> rowid,
});

class $$DriveDocsTableFilterComposer
    extends Composer<_$AppDatabase, $DriveDocsTable> {
  $$DriveDocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DriveDocKind, DriveDocKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get docId => $composableBuilder(
    column: $table.docId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriveDocsTableOrderingComposer
    extends Composer<_$AppDatabase, $DriveDocsTable> {
  $$DriveDocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docId => $composableBuilder(
    column: $table.docId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriveDocsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriveDocsTable> {
  $$DriveDocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DriveDocKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get docId =>
      $composableBuilder(column: $table.docId, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$DriveDocsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriveDocsTable,
          DriveDoc,
          $$DriveDocsTableFilterComposer,
          $$DriveDocsTableOrderingComposer,
          $$DriveDocsTableAnnotationComposer,
          $$DriveDocsTableCreateCompanionBuilder,
          $$DriveDocsTableUpdateCompanionBuilder,
          (DriveDoc, BaseReferences<_$AppDatabase, $DriveDocsTable, DriveDoc>),
          DriveDoc,
          PrefetchHooks Function()
        > {
  $$DriveDocsTableTableManager(_$AppDatabase db, $DriveDocsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriveDocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DriveDocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DriveDocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<DriveDocKind> kind = const Value.absent(),
                Value<String?> docId = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriveDocsCompanion(
                subjectId: subjectId,
                kind: kind,
                docId: docId,
                syncedAt: syncedAt,
                contentHash: contentHash,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int subjectId,
                required DriveDocKind kind,
                Value<String?> docId = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriveDocsCompanion.insert(
                subjectId: subjectId,
                kind: kind,
                docId: docId,
                syncedAt: syncedAt,
                contentHash: contentHash,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DriveDocsTable, DriveDoc>(table),
                  BaseReferences<_$AppDatabase, $DriveDocsTable, DriveDoc>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriveDocsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriveDocsTable,
      DriveDoc,
      $$DriveDocsTableFilterComposer,
      $$DriveDocsTableOrderingComposer,
      $$DriveDocsTableAnnotationComposer,
      $$DriveDocsTableCreateCompanionBuilder,
      $$DriveDocsTableUpdateCompanionBuilder,
      (DriveDoc, BaseReferences<_$AppDatabase, $DriveDocsTable, DriveDoc>),
      DriveDoc,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$UploadQueueTableTableManager get uploadQueue =>
      $$UploadQueueTableTableManager(_db, _db.uploadQueue);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$MeetingNotesTableTableManager get meetingNotes =>
      $$MeetingNotesTableTableManager(_db, _db.meetingNotes);
  $$AnswerCardsTableTableManager get answerCards =>
      $$AnswerCardsTableTableManager(_db, _db.answerCards);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$SavedNotesTableTableManager get savedNotes =>
      $$SavedNotesTableTableManager(_db, _db.savedNotes);
  $$ContextCardsTableTableManager get contextCards =>
      $$ContextCardsTableTableManager(_db, _db.contextCards);
  $$CardImagesTableTableManager get cardImages =>
      $$CardImagesTableTableManager(_db, _db.cardImages);
  $$MeetingCardsTableTableManager get meetingCards =>
      $$MeetingCardsTableTableManager(_db, _db.meetingCards);
  $$TimetableSlotsTableTableManager get timetableSlots =>
      $$TimetableSlotsTableTableManager(_db, _db.timetableSlots);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$RefinedSegmentsTableTableManager get refinedSegments =>
      $$RefinedSegmentsTableTableManager(_db, _db.refinedSegments);
  $$SubjectTermsTableTableManager get subjectTerms =>
      $$SubjectTermsTableTableManager(_db, _db.subjectTerms);
  $$SyllabusTopicsTableTableManager get syllabusTopics =>
      $$SyllabusTopicsTableTableManager(_db, _db.syllabusTopics);
  $$DriveDocsTableTableManager get driveDocs =>
      $$DriveDocsTableTableManager(_db, _db.driveDocs);
}
