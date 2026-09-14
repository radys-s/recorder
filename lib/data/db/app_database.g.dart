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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    endedAt,
    interrupted,
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
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    this.endedAt,
    required this.interrupted,
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
    };
  }

  Meeting copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    Value<DateTime?> endedAt = const Value.absent(),
    bool? interrupted,
  }) => Meeting(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    interrupted: interrupted ?? this.interrupted,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meeting(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('interrupted: $interrupted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAt, endedAt, interrupted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meeting &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.endedAt == this.endedAt &&
          other.interrupted == this.interrupted);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<bool> interrupted;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
  });
  MeetingsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.interrupted = const Value.absent(),
  }) : title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Meeting> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endedAt,
    Expression<bool>? interrupted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (interrupted != null) 'interrupted': interrupted,
    });
  }

  MeetingsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endedAt,
    Value<bool>? interrupted,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      interrupted: interrupted ?? this.interrupted,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('interrupted: $interrupted')
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
          ..write('createdAt: $createdAt')
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
          other.createdAt == this.createdAt);
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
          ..write('createdAt: $createdAt')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transcriptLanguage,
    notesDepth,
    liveAnswersEnabled,
    webAnswersEnabled,
    micSensitivity,
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
  const Preference({
    required this.id,
    required this.transcriptLanguage,
    required this.notesDepth,
    required this.liveAnswersEnabled,
    required this.webAnswersEnabled,
    required this.micSensitivity,
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
    };
  }

  Preference copyWith({
    int? id,
    TranscriptLanguage? transcriptLanguage,
    NotesDepth? notesDepth,
    bool? liveAnswersEnabled,
    bool? webAnswersEnabled,
    MicSensitivity? micSensitivity,
  }) => Preference(
    id: id ?? this.id,
    transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
    notesDepth: notesDepth ?? this.notesDepth,
    liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
    webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
    micSensitivity: micSensitivity ?? this.micSensitivity,
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
          ..write('micSensitivity: $micSensitivity')
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
          other.micSensitivity == this.micSensitivity);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<int> id;
  final Value<TranscriptLanguage> transcriptLanguage;
  final Value<NotesDepth> notesDepth;
  final Value<bool> liveAnswersEnabled;
  final Value<bool> webAnswersEnabled;
  final Value<MicSensitivity> micSensitivity;
  const PreferencesCompanion({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
  });
  PreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.notesDepth = const Value.absent(),
    this.liveAnswersEnabled = const Value.absent(),
    this.webAnswersEnabled = const Value.absent(),
    this.micSensitivity = const Value.absent(),
  });
  static Insertable<Preference> custom({
    Expression<int>? id,
    Expression<int>? transcriptLanguage,
    Expression<int>? notesDepth,
    Expression<bool>? liveAnswersEnabled,
    Expression<bool>? webAnswersEnabled,
    Expression<int>? micSensitivity,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transcriptLanguage != null) 'transcript_language': transcriptLanguage,
      if (notesDepth != null) 'notes_depth': notesDepth,
      if (liveAnswersEnabled != null)
        'live_answers_enabled': liveAnswersEnabled,
      if (webAnswersEnabled != null) 'web_answers_enabled': webAnswersEnabled,
      if (micSensitivity != null) 'mic_sensitivity': micSensitivity,
    });
  }

  PreferencesCompanion copyWith({
    Value<int>? id,
    Value<TranscriptLanguage>? transcriptLanguage,
    Value<NotesDepth>? notesDepth,
    Value<bool>? liveAnswersEnabled,
    Value<bool>? webAnswersEnabled,
    Value<MicSensitivity>? micSensitivity,
  }) {
    return PreferencesCompanion(
      id: id ?? this.id,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      notesDepth: notesDepth ?? this.notesDepth,
      liveAnswersEnabled: liveAnswersEnabled ?? this.liveAnswersEnabled,
      webAnswersEnabled: webAnswersEnabled ?? this.webAnswersEnabled,
      micSensitivity: micSensitivity ?? this.micSensitivity,
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
          ..write('micSensitivity: $micSensitivity')
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
          ..write('dismissed: $dismissed, ')
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
  ];
}

typedef $$MeetingsTableCreateCompanionBuilder = MeetingsCompanion Function({
  Value<int> id,
  required String title,
  required DateTime createdAt,
  Value<DateTime?> endedAt,
  Value<bool> interrupted,
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime?> endedAt,
  Value<bool> interrupted,
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
              }) => MeetingsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime createdAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                endedAt: endedAt,
                interrupted: interrupted,
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
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<int> id,
      Value<TranscriptLanguage> transcriptLanguage,
      Value<NotesDepth> notesDepth,
      Value<bool> liveAnswersEnabled,
      Value<bool> webAnswersEnabled,
      Value<MicSensitivity> micSensitivity,
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
              }) => PreferencesCompanion(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
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
              }) => PreferencesCompanion.insert(
                id: id,
                transcriptLanguage: transcriptLanguage,
                notesDepth: notesDepth,
                liveAnswersEnabled: liveAnswersEnabled,
                webAnswersEnabled: webAnswersEnabled,
                micSensitivity: micSensitivity,
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
}
