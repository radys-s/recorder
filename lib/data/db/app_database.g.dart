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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    endedAt,
    interrupted,
    subjectId,
    rules,
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
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    this.endedAt,
    required this.interrupted,
    this.subjectId,
    this.rules,
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
  }) => Meeting(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    interrupted: interrupted ?? this.interrupted,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    rules: rules.present ? rules.value : this.rules,
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
          ..write('rules: $rules')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, createdAt, endedAt, interrupted, subjectId, rules);
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
          other.rules == this.rules);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<bool> interrupted;
  final Value<int?> subjectId;
  final Value<String?> rules;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rules = const Value.absent(),
  });
  MeetingsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rules = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (interrupted != null) 'interrupted': interrupted,
      if (subjectId != null) 'subject_id': subjectId,
      if (rules != null) 'rules': rules,
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
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      interrupted: interrupted ?? this.interrupted,
      subjectId: subjectId ?? this.subjectId,
      rules: rules ?? this.rules,
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
          ..write('rules: $rules')
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
          ..write('voicedMs: $voicedMs')
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
          other.voicedMs == this.voicedMs);
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
          ..write('voicedMs: $voicedMs')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transcriptLanguage,
    notesDepth,
    liveAnswersEnabled,
    webAnswersEnabled,
    micSensitivity,
    globalRules,
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
  const Preference({
    required this.id,
    required this.transcriptLanguage,
    required this.notesDepth,
    required this.liveAnswersEnabled,
    required this.webAnswersEnabled,
    required this.micSensitivity,
    this.globalRules,
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
  }) => Preference(
    id: id ?? this.id,
    transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
    notesDepth: notesDepth ?? this.notesDepth,
    liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
    webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
    micSensitivity: micSensitivity ?? this.micSensitivity,
    globalRules: globalRules.present ? globalRules.value : this.globalRules,
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
          ..write('globalRules: $globalRules')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transcriptLanguage,
    notesDepth,
    liveAnswersEnabled,
    webAnswersEnabled,
    micSensitivity,
    globalRules,
  );
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
          other.globalRules == this.globalRules);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<int> id;
  final Value<TranscriptLanguage> transcriptLanguage;
  final Value<NotesDepth> notesDepth;
  final Value<bool> liveAnswersEnabled;
  final Value<bool> webAnswersEnabled;
  final Value<MicSensitivity> micSensitivity;
  final Value<String?> globalRules;
  const PreferencesCompanion({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
    this.globalRules = const Value.absent(),
  });
  PreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
    this.globalRules = const Value.absent(),
  });
  static Insertable<Preference> custom({
    Expression<int>? id,
    Expression<int>? transcriptLanguage,
    Expression<int>? notesDepth,
    Expression<bool>? liveAnswersEnabled,
    Expression<bool>? webAnswersEnabled,
    Expression<int>? micSensitivity,
    Expression<String>? globalRules,
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
  }) {
    return PreferencesCompanion(
      id: id ?? this.id,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      notesDepth: notesDepth ?? this.notesDepth,
      liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
      webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
      micSensitivity: micSensitivity ?? this.micSensitivity,
      globalRules: globalRules ?? this.globalRules,
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
          ..write('globalRules: $globalRules')
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
  final String? error;
  final DateTime createdAt;
  const MeetingNote({
    required this.id,
    required this.meetingId,
    required this.depth,
    this.content,
    required this.model,
    required this.status,
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
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
  }) => MeetingNote(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    depth: depth ?? this.depth,
    content: content.present ? content.value : this.content,
    model: model ?? this.model,
    status: status ?? this.status,
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
  final Value<String?> error;
  final Value<DateTime> createdAt;
  const MeetingNotesCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.depth = const Value.absent(),
    this.content = const Value.absent(),
    this.model = const Value.absent(),
    this.status = const Value.absent(),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    rules,
    colorIndex,
    sortOrder,
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
  const Subject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.rules,
    required this.colorIndex,
    required this.sortOrder,
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
    };
  }

  Subject copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    Value<String?> rules = const Value.absent(),
    int? colorIndex,
    int? sortOrder,
  }) => Subject(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    rules: rules.present ? rules.value : this.rules,
    colorIndex: colorIndex ?? this.colorIndex,
    sortOrder: sortOrder ?? this.sortOrder,
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
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, rules, colorIndex, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.rules == this.rules &&
          other.colorIndex == this.colorIndex &&
          other.sortOrder == this.sortOrder);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<String?> rules;
  final Value<int> colorIndex;
  final Value<int> sortOrder;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rules = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
    this.rules = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Subject> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<String>? rules,
    Expression<int>? colorIndex,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rules != null) 'rules': rules,
      if (colorIndex != null) 'color_index': colorIndex,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<String?>? rules,
    Value<int>? colorIndex,
    Value<int>? sortOrder,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rules: rules ?? this.rules,
      colorIndex: colorIndex ?? this.colorIndex,
      sortOrder: sortOrder ?? this.sortOrder,
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
          ..write('sortOrder: $sortOrder')
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
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime?> endedAt,
  Value<bool> interrupted,
  Value<int?> subjectId,
  Value<String?> rules,
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
              }) => MeetingsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
                subjectId: subjectId,
                rules: rules,
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
              }) => MeetingsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
                subjectId: subjectId,
                rules: rules,
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
              }) => PreferencesCompanion(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
                globalRules: globalRules,
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
              }) => PreferencesCompanion.insert(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
                globalRules: globalRules,
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
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MeetingNotesCompanion(
                id: id,
                meetingId: meetingId,
                depth: depth,
                content: content,
                model: model,
                status: status,
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
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
              }) => MeetingNotesCompanion.insert(
                id: id,
                meetingId: meetingId,
                depth: depth,
                content: content,
                model: model,
                status: status,
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
});
typedef $$SubjectsTableUpdateCompanionBuilder = SubjectsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<String?> rules,
  Value<int> colorIndex,
  Value<int> sortOrder,
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
              }) => SubjectsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                rules: rules,
                colorIndex: colorIndex,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
                Value<String?> rules = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                rules: rules,
                colorIndex: colorIndex,
                sortOrder: sortOrder,
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
}
