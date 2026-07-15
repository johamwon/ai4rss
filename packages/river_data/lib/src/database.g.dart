// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
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
    name,
    position,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
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
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
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
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Folder({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    this.position = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? position,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedSubscriptionsTable extends FeedSubscriptions
    with TableInfo<$FeedSubscriptionsTable, FeedSubscription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedSubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalUrlMeta = const VerificationMeta(
    'canonicalUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalUrl = GeneratedColumn<String>(
    'canonical_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
      maxTextLength: 1024,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id)',
    ),
  );
  static const VerificationMeta _feedKindMeta = const VerificationMeta(
    'feedKind',
  );
  @override
  late final GeneratedColumn<String> feedKind = GeneratedColumn<String>(
    'feed_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRefreshedAtMeta = const VerificationMeta(
    'lastRefreshedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastRefreshedAt =
      GeneratedColumn<DateTime>(
        'last_refreshed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
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
    canonicalUrl,
    title,
    folderId,
    feedKind,
    enabled,
    etag,
    lastModified,
    lastRefreshedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedSubscription> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('canonical_url')) {
      context.handle(
        _canonicalUrlMeta,
        canonicalUrl.isAcceptableOrUnknown(
          data['canonical_url']!,
          _canonicalUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('feed_kind')) {
      context.handle(
        _feedKindMeta,
        feedKind.isAcceptableOrUnknown(data['feed_kind']!, _feedKindMeta),
      );
    } else if (isInserting) {
      context.missing(_feedKindMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('last_refreshed_at')) {
      context.handle(
        _lastRefreshedAtMeta,
        lastRefreshedAt.isAcceptableOrUnknown(
          data['last_refreshed_at']!,
          _lastRefreshedAtMeta,
        ),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {canonicalUrl},
  ];
  @override
  FeedSubscription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedSubscription(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      canonicalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      feedKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_kind'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      lastRefreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_refreshed_at'],
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
  $FeedSubscriptionsTable createAlias(String alias) {
    return $FeedSubscriptionsTable(attachedDatabase, alias);
  }
}

class FeedSubscription extends DataClass
    implements Insertable<FeedSubscription> {
  final String id;
  final String canonicalUrl;
  final String title;
  final String? folderId;
  final String feedKind;
  final bool enabled;
  final String? etag;
  final String? lastModified;
  final DateTime? lastRefreshedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FeedSubscription({
    required this.id,
    required this.canonicalUrl,
    required this.title,
    this.folderId,
    required this.feedKind,
    required this.enabled,
    this.etag,
    this.lastModified,
    this.lastRefreshedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['canonical_url'] = Variable<String>(canonicalUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['feed_kind'] = Variable<String>(feedKind);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    if (!nullToAbsent || lastRefreshedAt != null) {
      map['last_refreshed_at'] = Variable<DateTime>(lastRefreshedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FeedSubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return FeedSubscriptionsCompanion(
      id: Value(id),
      canonicalUrl: Value(canonicalUrl),
      title: Value(title),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      feedKind: Value(feedKind),
      enabled: Value(enabled),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      lastRefreshedAt: lastRefreshedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRefreshedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FeedSubscription.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedSubscription(
      id: serializer.fromJson<String>(json['id']),
      canonicalUrl: serializer.fromJson<String>(json['canonicalUrl']),
      title: serializer.fromJson<String>(json['title']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      feedKind: serializer.fromJson<String>(json['feedKind']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      lastRefreshedAt: serializer.fromJson<DateTime?>(json['lastRefreshedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'canonicalUrl': serializer.toJson<String>(canonicalUrl),
      'title': serializer.toJson<String>(title),
      'folderId': serializer.toJson<String?>(folderId),
      'feedKind': serializer.toJson<String>(feedKind),
      'enabled': serializer.toJson<bool>(enabled),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'lastRefreshedAt': serializer.toJson<DateTime?>(lastRefreshedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FeedSubscription copyWith({
    String? id,
    String? canonicalUrl,
    String? title,
    Value<String?> folderId = const Value.absent(),
    String? feedKind,
    bool? enabled,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    Value<DateTime?> lastRefreshedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FeedSubscription(
    id: id ?? this.id,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    title: title ?? this.title,
    folderId: folderId.present ? folderId.value : this.folderId,
    feedKind: feedKind ?? this.feedKind,
    enabled: enabled ?? this.enabled,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    lastRefreshedAt: lastRefreshedAt.present
        ? lastRefreshedAt.value
        : this.lastRefreshedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FeedSubscription copyWithCompanion(FeedSubscriptionsCompanion data) {
    return FeedSubscription(
      id: data.id.present ? data.id.value : this.id,
      canonicalUrl: data.canonicalUrl.present
          ? data.canonicalUrl.value
          : this.canonicalUrl,
      title: data.title.present ? data.title.value : this.title,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      feedKind: data.feedKind.present ? data.feedKind.value : this.feedKind,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      lastRefreshedAt: data.lastRefreshedAt.present
          ? data.lastRefreshedAt.value
          : this.lastRefreshedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedSubscription(')
          ..write('id: $id, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('folderId: $folderId, ')
          ..write('feedKind: $feedKind, ')
          ..write('enabled: $enabled, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('lastRefreshedAt: $lastRefreshedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    canonicalUrl,
    title,
    folderId,
    feedKind,
    enabled,
    etag,
    lastModified,
    lastRefreshedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedSubscription &&
          other.id == this.id &&
          other.canonicalUrl == this.canonicalUrl &&
          other.title == this.title &&
          other.folderId == this.folderId &&
          other.feedKind == this.feedKind &&
          other.enabled == this.enabled &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.lastRefreshedAt == this.lastRefreshedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FeedSubscriptionsCompanion extends UpdateCompanion<FeedSubscription> {
  final Value<String> id;
  final Value<String> canonicalUrl;
  final Value<String> title;
  final Value<String?> folderId;
  final Value<String> feedKind;
  final Value<bool> enabled;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DateTime?> lastRefreshedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FeedSubscriptionsCompanion({
    this.id = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.folderId = const Value.absent(),
    this.feedKind = const Value.absent(),
    this.enabled = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.lastRefreshedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedSubscriptionsCompanion.insert({
    required String id,
    required String canonicalUrl,
    required String title,
    this.folderId = const Value.absent(),
    required String feedKind,
    this.enabled = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.lastRefreshedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       canonicalUrl = Value(canonicalUrl),
       title = Value(title),
       feedKind = Value(feedKind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FeedSubscription> custom({
    Expression<String>? id,
    Expression<String>? canonicalUrl,
    Expression<String>? title,
    Expression<String>? folderId,
    Expression<String>? feedKind,
    Expression<bool>? enabled,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<DateTime>? lastRefreshedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (title != null) 'title': title,
      if (folderId != null) 'folder_id': folderId,
      if (feedKind != null) 'feed_kind': feedKind,
      if (enabled != null) 'enabled': enabled,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (lastRefreshedAt != null) 'last_refreshed_at': lastRefreshedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedSubscriptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? canonicalUrl,
    Value<String>? title,
    Value<String?>? folderId,
    Value<String>? feedKind,
    Value<bool>? enabled,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DateTime?>? lastRefreshedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FeedSubscriptionsCompanion(
      id: id ?? this.id,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      feedKind: feedKind ?? this.feedKind,
      enabled: enabled ?? this.enabled,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (canonicalUrl.present) {
      map['canonical_url'] = Variable<String>(canonicalUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (feedKind.present) {
      map['feed_kind'] = Variable<String>(feedKind.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (lastRefreshedAt.present) {
      map['last_refreshed_at'] = Variable<DateTime>(lastRefreshedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedSubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('folderId: $folderId, ')
          ..write('feedKind: $feedKind, ')
          ..write('enabled: $enabled, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('lastRefreshedAt: $lastRefreshedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticlesTable extends Articles with TableInfo<$ArticlesTable, Article> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedIdMeta = const VerificationMeta('feedId');
  @override
  late final GeneratedColumn<String> feedId = GeneratedColumn<String>(
    'feed_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES feed_subscriptions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _canonicalUrlMeta = const VerificationMeta(
    'canonicalUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalUrl = GeneratedColumn<String>(
    'canonical_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
      maxTextLength: 2048,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feedSummaryMeta = const VerificationMeta(
    'feedSummary',
  );
  @override
  late final GeneratedColumn<String> feedSummary = GeneratedColumn<String>(
    'feed_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readStateMeta = const VerificationMeta(
    'readState',
  );
  @override
  late final GeneratedColumn<String> readState = GeneratedColumn<String>(
    'read_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unread'),
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readLaterMeta = const VerificationMeta(
    'readLater',
  );
  @override
  late final GeneratedColumn<bool> readLater = GeneratedColumn<bool>(
    'read_later',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_later" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _activeReadSecondsMeta = const VerificationMeta(
    'activeReadSeconds',
  );
  @override
  late final GeneratedColumn<int> activeReadSeconds = GeneratedColumn<int>(
    'active_read_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scrollDepthMeta = const VerificationMeta(
    'scrollDepth',
  );
  @override
  late final GeneratedColumn<double> scrollDepth = GeneratedColumn<double>(
    'scroll_depth',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
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
    feedId,
    canonicalUrl,
    title,
    author,
    publishedAt,
    feedSummary,
    readState,
    starred,
    readLater,
    activeReadSeconds,
    scrollDepth,
    completedAt,
    contentHash,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Article> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('feed_id')) {
      context.handle(
        _feedIdMeta,
        feedId.isAcceptableOrUnknown(data['feed_id']!, _feedIdMeta),
      );
    } else if (isInserting) {
      context.missing(_feedIdMeta);
    }
    if (data.containsKey('canonical_url')) {
      context.handle(
        _canonicalUrlMeta,
        canonicalUrl.isAcceptableOrUnknown(
          data['canonical_url']!,
          _canonicalUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('feed_summary')) {
      context.handle(
        _feedSummaryMeta,
        feedSummary.isAcceptableOrUnknown(
          data['feed_summary']!,
          _feedSummaryMeta,
        ),
      );
    }
    if (data.containsKey('read_state')) {
      context.handle(
        _readStateMeta,
        readState.isAcceptableOrUnknown(data['read_state']!, _readStateMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('read_later')) {
      context.handle(
        _readLaterMeta,
        readLater.isAcceptableOrUnknown(data['read_later']!, _readLaterMeta),
      );
    }
    if (data.containsKey('active_read_seconds')) {
      context.handle(
        _activeReadSecondsMeta,
        activeReadSeconds.isAcceptableOrUnknown(
          data['active_read_seconds']!,
          _activeReadSecondsMeta,
        ),
      );
    }
    if (data.containsKey('scroll_depth')) {
      context.handle(
        _scrollDepthMeta,
        scrollDepth.isAcceptableOrUnknown(
          data['scroll_depth']!,
          _scrollDepthMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {feedId, canonicalUrl},
  ];
  @override
  Article map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Article(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      feedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_id'],
      )!,
      canonicalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      feedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_summary'],
      ),
      readState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_state'],
      )!,
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      readLater: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_later'],
      )!,
      activeReadSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_read_seconds'],
      )!,
      scrollDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scroll_depth'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
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
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class Article extends DataClass implements Insertable<Article> {
  final String id;
  final String feedId;
  final String canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? feedSummary;
  final String readState;
  final bool starred;
  final bool readLater;
  final int activeReadSeconds;
  final double scrollDepth;
  final DateTime? completedAt;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Article({
    required this.id,
    required this.feedId,
    required this.canonicalUrl,
    required this.title,
    this.author,
    this.publishedAt,
    this.feedSummary,
    required this.readState,
    required this.starred,
    required this.readLater,
    required this.activeReadSeconds,
    required this.scrollDepth,
    this.completedAt,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['feed_id'] = Variable<String>(feedId);
    map['canonical_url'] = Variable<String>(canonicalUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || feedSummary != null) {
      map['feed_summary'] = Variable<String>(feedSummary);
    }
    map['read_state'] = Variable<String>(readState);
    map['starred'] = Variable<bool>(starred);
    map['read_later'] = Variable<bool>(readLater);
    map['active_read_seconds'] = Variable<int>(activeReadSeconds);
    map['scroll_depth'] = Variable<double>(scrollDepth);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      feedId: Value(feedId),
      canonicalUrl: Value(canonicalUrl),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      feedSummary: feedSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(feedSummary),
      readState: Value(readState),
      starred: Value(starred),
      readLater: Value(readLater),
      activeReadSeconds: Value(activeReadSeconds),
      scrollDepth: Value(scrollDepth),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Article.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Article(
      id: serializer.fromJson<String>(json['id']),
      feedId: serializer.fromJson<String>(json['feedId']),
      canonicalUrl: serializer.fromJson<String>(json['canonicalUrl']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      feedSummary: serializer.fromJson<String?>(json['feedSummary']),
      readState: serializer.fromJson<String>(json['readState']),
      starred: serializer.fromJson<bool>(json['starred']),
      readLater: serializer.fromJson<bool>(json['readLater']),
      activeReadSeconds: serializer.fromJson<int>(json['activeReadSeconds']),
      scrollDepth: serializer.fromJson<double>(json['scrollDepth']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'feedId': serializer.toJson<String>(feedId),
      'canonicalUrl': serializer.toJson<String>(canonicalUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'feedSummary': serializer.toJson<String?>(feedSummary),
      'readState': serializer.toJson<String>(readState),
      'starred': serializer.toJson<bool>(starred),
      'readLater': serializer.toJson<bool>(readLater),
      'activeReadSeconds': serializer.toJson<int>(activeReadSeconds),
      'scrollDepth': serializer.toJson<double>(scrollDepth),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Article copyWith({
    String? id,
    String? feedId,
    String? canonicalUrl,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<String?> feedSummary = const Value.absent(),
    String? readState,
    bool? starred,
    bool? readLater,
    int? activeReadSeconds,
    double? scrollDepth,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Article(
    id: id ?? this.id,
    feedId: feedId ?? this.feedId,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    feedSummary: feedSummary.present ? feedSummary.value : this.feedSummary,
    readState: readState ?? this.readState,
    starred: starred ?? this.starred,
    readLater: readLater ?? this.readLater,
    activeReadSeconds: activeReadSeconds ?? this.activeReadSeconds,
    scrollDepth: scrollDepth ?? this.scrollDepth,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Article copyWithCompanion(ArticlesCompanion data) {
    return Article(
      id: data.id.present ? data.id.value : this.id,
      feedId: data.feedId.present ? data.feedId.value : this.feedId,
      canonicalUrl: data.canonicalUrl.present
          ? data.canonicalUrl.value
          : this.canonicalUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      feedSummary: data.feedSummary.present
          ? data.feedSummary.value
          : this.feedSummary,
      readState: data.readState.present ? data.readState.value : this.readState,
      starred: data.starred.present ? data.starred.value : this.starred,
      readLater: data.readLater.present ? data.readLater.value : this.readLater,
      activeReadSeconds: data.activeReadSeconds.present
          ? data.activeReadSeconds.value
          : this.activeReadSeconds,
      scrollDepth: data.scrollDepth.present
          ? data.scrollDepth.value
          : this.scrollDepth,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Article(')
          ..write('id: $id, ')
          ..write('feedId: $feedId, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('feedSummary: $feedSummary, ')
          ..write('readState: $readState, ')
          ..write('starred: $starred, ')
          ..write('readLater: $readLater, ')
          ..write('activeReadSeconds: $activeReadSeconds, ')
          ..write('scrollDepth: $scrollDepth, ')
          ..write('completedAt: $completedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    feedId,
    canonicalUrl,
    title,
    author,
    publishedAt,
    feedSummary,
    readState,
    starred,
    readLater,
    activeReadSeconds,
    scrollDepth,
    completedAt,
    contentHash,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Article &&
          other.id == this.id &&
          other.feedId == this.feedId &&
          other.canonicalUrl == this.canonicalUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.publishedAt == this.publishedAt &&
          other.feedSummary == this.feedSummary &&
          other.readState == this.readState &&
          other.starred == this.starred &&
          other.readLater == this.readLater &&
          other.activeReadSeconds == this.activeReadSeconds &&
          other.scrollDepth == this.scrollDepth &&
          other.completedAt == this.completedAt &&
          other.contentHash == this.contentHash &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ArticlesCompanion extends UpdateCompanion<Article> {
  final Value<String> id;
  final Value<String> feedId;
  final Value<String> canonicalUrl;
  final Value<String> title;
  final Value<String?> author;
  final Value<DateTime?> publishedAt;
  final Value<String?> feedSummary;
  final Value<String> readState;
  final Value<bool> starred;
  final Value<bool> readLater;
  final Value<int> activeReadSeconds;
  final Value<double> scrollDepth;
  final Value<DateTime?> completedAt;
  final Value<String?> contentHash;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.feedId = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.feedSummary = const Value.absent(),
    this.readState = const Value.absent(),
    this.starred = const Value.absent(),
    this.readLater = const Value.absent(),
    this.activeReadSeconds = const Value.absent(),
    this.scrollDepth = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesCompanion.insert({
    required String id,
    required String feedId,
    required String canonicalUrl,
    required String title,
    this.author = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.feedSummary = const Value.absent(),
    this.readState = const Value.absent(),
    this.starred = const Value.absent(),
    this.readLater = const Value.absent(),
    this.activeReadSeconds = const Value.absent(),
    this.scrollDepth = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       feedId = Value(feedId),
       canonicalUrl = Value(canonicalUrl),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Article> custom({
    Expression<String>? id,
    Expression<String>? feedId,
    Expression<String>? canonicalUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<DateTime>? publishedAt,
    Expression<String>? feedSummary,
    Expression<String>? readState,
    Expression<bool>? starred,
    Expression<bool>? readLater,
    Expression<int>? activeReadSeconds,
    Expression<double>? scrollDepth,
    Expression<DateTime>? completedAt,
    Expression<String>? contentHash,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedId != null) 'feed_id': feedId,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (publishedAt != null) 'published_at': publishedAt,
      if (feedSummary != null) 'feed_summary': feedSummary,
      if (readState != null) 'read_state': readState,
      if (starred != null) 'starred': starred,
      if (readLater != null) 'read_later': readLater,
      if (activeReadSeconds != null) 'active_read_seconds': activeReadSeconds,
      if (scrollDepth != null) 'scroll_depth': scrollDepth,
      if (completedAt != null) 'completed_at': completedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesCompanion copyWith({
    Value<String>? id,
    Value<String>? feedId,
    Value<String>? canonicalUrl,
    Value<String>? title,
    Value<String?>? author,
    Value<DateTime?>? publishedAt,
    Value<String?>? feedSummary,
    Value<String>? readState,
    Value<bool>? starred,
    Value<bool>? readLater,
    Value<int>? activeReadSeconds,
    Value<double>? scrollDepth,
    Value<DateTime?>? completedAt,
    Value<String?>? contentHash,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ArticlesCompanion(
      id: id ?? this.id,
      feedId: feedId ?? this.feedId,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      feedSummary: feedSummary ?? this.feedSummary,
      readState: readState ?? this.readState,
      starred: starred ?? this.starred,
      readLater: readLater ?? this.readLater,
      activeReadSeconds: activeReadSeconds ?? this.activeReadSeconds,
      scrollDepth: scrollDepth ?? this.scrollDepth,
      completedAt: completedAt ?? this.completedAt,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (feedId.present) {
      map['feed_id'] = Variable<String>(feedId.value);
    }
    if (canonicalUrl.present) {
      map['canonical_url'] = Variable<String>(canonicalUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (feedSummary.present) {
      map['feed_summary'] = Variable<String>(feedSummary.value);
    }
    if (readState.present) {
      map['read_state'] = Variable<String>(readState.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (readLater.present) {
      map['read_later'] = Variable<bool>(readLater.value);
    }
    if (activeReadSeconds.present) {
      map['active_read_seconds'] = Variable<int>(activeReadSeconds.value);
    }
    if (scrollDepth.present) {
      map['scroll_depth'] = Variable<double>(scrollDepth.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('feedId: $feedId, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('feedSummary: $feedSummary, ')
          ..write('readState: $readState, ')
          ..write('starred: $starred, ')
          ..write('readLater: $readLater, ')
          ..write('activeReadSeconds: $activeReadSeconds, ')
          ..write('scrollDepth: $scrollDepth, ')
          ..write('completedAt: $completedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticleContentsTable extends ArticleContents
    with TableInfo<$ArticleContentsTable, ArticleContent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticleContentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sanitizedHtmlMeta = const VerificationMeta(
    'sanitizedHtml',
  );
  @override
  late final GeneratedColumn<String> sanitizedHtml = GeneratedColumn<String>(
    'sanitized_html',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractorNameMeta = const VerificationMeta(
    'extractorName',
  );
  @override
  late final GeneratedColumn<String> extractorName = GeneratedColumn<String>(
    'extractor_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractorVersionMeta = const VerificationMeta(
    'extractorVersion',
  );
  @override
  late final GeneratedColumn<String> extractorVersion = GeneratedColumn<String>(
    'extractor_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedAtMeta = const VerificationMeta(
    'extractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> extractedAt = GeneratedColumn<DateTime>(
    'extracted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    articleId,
    sanitizedHtml,
    markdown,
    plainText,
    extractorName,
    extractorVersion,
    etag,
    lastModified,
    extractedAt,
    failureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article_contents';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleContent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('sanitized_html')) {
      context.handle(
        _sanitizedHtmlMeta,
        sanitizedHtml.isAcceptableOrUnknown(
          data['sanitized_html']!,
          _sanitizedHtmlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sanitizedHtmlMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    } else if (isInserting) {
      context.missing(_plainTextMeta);
    }
    if (data.containsKey('extractor_name')) {
      context.handle(
        _extractorNameMeta,
        extractorName.isAcceptableOrUnknown(
          data['extractor_name']!,
          _extractorNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractorNameMeta);
    }
    if (data.containsKey('extractor_version')) {
      context.handle(
        _extractorVersionMeta,
        extractorVersion.isAcceptableOrUnknown(
          data['extractor_version']!,
          _extractorVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractorVersionMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('extracted_at')) {
      context.handle(
        _extractedAtMeta,
        extractedAt.isAcceptableOrUnknown(
          data['extracted_at']!,
          _extractedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractedAtMeta);
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleId};
  @override
  ArticleContent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleContent(
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      sanitizedHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sanitized_html'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      )!,
      extractorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extractor_name'],
      )!,
      extractorVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extractor_version'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      extractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}extracted_at'],
      )!,
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
    );
  }

  @override
  $ArticleContentsTable createAlias(String alias) {
    return $ArticleContentsTable(attachedDatabase, alias);
  }
}

class ArticleContent extends DataClass implements Insertable<ArticleContent> {
  final String articleId;
  final String sanitizedHtml;
  final String markdown;
  final String plainText;
  final String extractorName;
  final String extractorVersion;
  final String? etag;
  final String? lastModified;
  final DateTime extractedAt;
  final String? failureCode;
  const ArticleContent({
    required this.articleId,
    required this.sanitizedHtml,
    required this.markdown,
    required this.plainText,
    required this.extractorName,
    required this.extractorVersion,
    this.etag,
    this.lastModified,
    required this.extractedAt,
    this.failureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_id'] = Variable<String>(articleId);
    map['sanitized_html'] = Variable<String>(sanitizedHtml);
    map['markdown'] = Variable<String>(markdown);
    map['plain_text'] = Variable<String>(plainText);
    map['extractor_name'] = Variable<String>(extractorName);
    map['extractor_version'] = Variable<String>(extractorVersion);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    map['extracted_at'] = Variable<DateTime>(extractedAt);
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    return map;
  }

  ArticleContentsCompanion toCompanion(bool nullToAbsent) {
    return ArticleContentsCompanion(
      articleId: Value(articleId),
      sanitizedHtml: Value(sanitizedHtml),
      markdown: Value(markdown),
      plainText: Value(plainText),
      extractorName: Value(extractorName),
      extractorVersion: Value(extractorVersion),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      extractedAt: Value(extractedAt),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
    );
  }

  factory ArticleContent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleContent(
      articleId: serializer.fromJson<String>(json['articleId']),
      sanitizedHtml: serializer.fromJson<String>(json['sanitizedHtml']),
      markdown: serializer.fromJson<String>(json['markdown']),
      plainText: serializer.fromJson<String>(json['plainText']),
      extractorName: serializer.fromJson<String>(json['extractorName']),
      extractorVersion: serializer.fromJson<String>(json['extractorVersion']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      extractedAt: serializer.fromJson<DateTime>(json['extractedAt']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'articleId': serializer.toJson<String>(articleId),
      'sanitizedHtml': serializer.toJson<String>(sanitizedHtml),
      'markdown': serializer.toJson<String>(markdown),
      'plainText': serializer.toJson<String>(plainText),
      'extractorName': serializer.toJson<String>(extractorName),
      'extractorVersion': serializer.toJson<String>(extractorVersion),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'extractedAt': serializer.toJson<DateTime>(extractedAt),
      'failureCode': serializer.toJson<String?>(failureCode),
    };
  }

  ArticleContent copyWith({
    String? articleId,
    String? sanitizedHtml,
    String? markdown,
    String? plainText,
    String? extractorName,
    String? extractorVersion,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    DateTime? extractedAt,
    Value<String?> failureCode = const Value.absent(),
  }) => ArticleContent(
    articleId: articleId ?? this.articleId,
    sanitizedHtml: sanitizedHtml ?? this.sanitizedHtml,
    markdown: markdown ?? this.markdown,
    plainText: plainText ?? this.plainText,
    extractorName: extractorName ?? this.extractorName,
    extractorVersion: extractorVersion ?? this.extractorVersion,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    extractedAt: extractedAt ?? this.extractedAt,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
  );
  ArticleContent copyWithCompanion(ArticleContentsCompanion data) {
    return ArticleContent(
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      sanitizedHtml: data.sanitizedHtml.present
          ? data.sanitizedHtml.value
          : this.sanitizedHtml,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      extractorName: data.extractorName.present
          ? data.extractorName.value
          : this.extractorName,
      extractorVersion: data.extractorVersion.present
          ? data.extractorVersion.value
          : this.extractorVersion,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      extractedAt: data.extractedAt.present
          ? data.extractedAt.value
          : this.extractedAt,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleContent(')
          ..write('articleId: $articleId, ')
          ..write('sanitizedHtml: $sanitizedHtml, ')
          ..write('markdown: $markdown, ')
          ..write('plainText: $plainText, ')
          ..write('extractorName: $extractorName, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('extractedAt: $extractedAt, ')
          ..write('failureCode: $failureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    articleId,
    sanitizedHtml,
    markdown,
    plainText,
    extractorName,
    extractorVersion,
    etag,
    lastModified,
    extractedAt,
    failureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleContent &&
          other.articleId == this.articleId &&
          other.sanitizedHtml == this.sanitizedHtml &&
          other.markdown == this.markdown &&
          other.plainText == this.plainText &&
          other.extractorName == this.extractorName &&
          other.extractorVersion == this.extractorVersion &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.extractedAt == this.extractedAt &&
          other.failureCode == this.failureCode);
}

class ArticleContentsCompanion extends UpdateCompanion<ArticleContent> {
  final Value<String> articleId;
  final Value<String> sanitizedHtml;
  final Value<String> markdown;
  final Value<String> plainText;
  final Value<String> extractorName;
  final Value<String> extractorVersion;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DateTime> extractedAt;
  final Value<String?> failureCode;
  final Value<int> rowid;
  const ArticleContentsCompanion({
    this.articleId = const Value.absent(),
    this.sanitizedHtml = const Value.absent(),
    this.markdown = const Value.absent(),
    this.plainText = const Value.absent(),
    this.extractorName = const Value.absent(),
    this.extractorVersion = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.extractedAt = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticleContentsCompanion.insert({
    required String articleId,
    required String sanitizedHtml,
    required String markdown,
    required String plainText,
    required String extractorName,
    required String extractorVersion,
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    required DateTime extractedAt,
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : articleId = Value(articleId),
       sanitizedHtml = Value(sanitizedHtml),
       markdown = Value(markdown),
       plainText = Value(plainText),
       extractorName = Value(extractorName),
       extractorVersion = Value(extractorVersion),
       extractedAt = Value(extractedAt);
  static Insertable<ArticleContent> custom({
    Expression<String>? articleId,
    Expression<String>? sanitizedHtml,
    Expression<String>? markdown,
    Expression<String>? plainText,
    Expression<String>? extractorName,
    Expression<String>? extractorVersion,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<DateTime>? extractedAt,
    Expression<String>? failureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleId != null) 'article_id': articleId,
      if (sanitizedHtml != null) 'sanitized_html': sanitizedHtml,
      if (markdown != null) 'markdown': markdown,
      if (plainText != null) 'plain_text': plainText,
      if (extractorName != null) 'extractor_name': extractorName,
      if (extractorVersion != null) 'extractor_version': extractorVersion,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (extractedAt != null) 'extracted_at': extractedAt,
      if (failureCode != null) 'failure_code': failureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticleContentsCompanion copyWith({
    Value<String>? articleId,
    Value<String>? sanitizedHtml,
    Value<String>? markdown,
    Value<String>? plainText,
    Value<String>? extractorName,
    Value<String>? extractorVersion,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DateTime>? extractedAt,
    Value<String?>? failureCode,
    Value<int>? rowid,
  }) {
    return ArticleContentsCompanion(
      articleId: articleId ?? this.articleId,
      sanitizedHtml: sanitizedHtml ?? this.sanitizedHtml,
      markdown: markdown ?? this.markdown,
      plainText: plainText ?? this.plainText,
      extractorName: extractorName ?? this.extractorName,
      extractorVersion: extractorVersion ?? this.extractorVersion,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      extractedAt: extractedAt ?? this.extractedAt,
      failureCode: failureCode ?? this.failureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (sanitizedHtml.present) {
      map['sanitized_html'] = Variable<String>(sanitizedHtml.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (extractorName.present) {
      map['extractor_name'] = Variable<String>(extractorName.value);
    }
    if (extractorVersion.present) {
      map['extractor_version'] = Variable<String>(extractorVersion.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (extractedAt.present) {
      map['extracted_at'] = Variable<DateTime>(extractedAt.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleContentsCompanion(')
          ..write('articleId: $articleId, ')
          ..write('sanitizedHtml: $sanitizedHtml, ')
          ..write('markdown: $markdown, ')
          ..write('plainText: $plainText, ')
          ..write('extractorName: $extractorName, ')
          ..write('extractorVersion: $extractorVersion, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('extractedAt: $extractedAt, ')
          ..write('failureCode: $failureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingEventsTable extends ReadingEvents
    with TableInfo<$ReadingEventsTable, ReadingEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventKeyMeta = const VerificationMeta(
    'eventKey',
  );
  @override
  late final GeneratedColumn<String> eventKey = GeneratedColumn<String>(
    'event_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeSecondsMeta = const VerificationMeta(
    'activeSeconds',
  );
  @override
  late final GeneratedColumn<int> activeSeconds = GeneratedColumn<int>(
    'active_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completionRatioMeta = const VerificationMeta(
    'completionRatio',
  );
  @override
  late final GeneratedColumn<double> completionRatio = GeneratedColumn<double>(
    'completion_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    articleId,
    eventKey,
    eventType,
    occurredAt,
    activeSeconds,
    completionRatio,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('event_key')) {
      context.handle(
        _eventKeyMeta,
        eventKey.isAcceptableOrUnknown(data['event_key']!, _eventKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_eventKeyMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('active_seconds')) {
      context.handle(
        _activeSecondsMeta,
        activeSeconds.isAcceptableOrUnknown(
          data['active_seconds']!,
          _activeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('completion_ratio')) {
      context.handle(
        _completionRatioMeta,
        completionRatio.isAcceptableOrUnknown(
          data['completion_ratio']!,
          _completionRatioMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {eventKey},
  ];
  @override
  ReadingEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      eventKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_key'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      activeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_seconds'],
      )!,
      completionRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}completion_ratio'],
      )!,
    );
  }

  @override
  $ReadingEventsTable createAlias(String alias) {
    return $ReadingEventsTable(attachedDatabase, alias);
  }
}

class ReadingEvent extends DataClass implements Insertable<ReadingEvent> {
  final String id;
  final String articleId;
  final String eventKey;
  final String eventType;
  final DateTime occurredAt;
  final int activeSeconds;
  final double completionRatio;
  const ReadingEvent({
    required this.id,
    required this.articleId,
    required this.eventKey,
    required this.eventType,
    required this.occurredAt,
    required this.activeSeconds,
    required this.completionRatio,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['article_id'] = Variable<String>(articleId);
    map['event_key'] = Variable<String>(eventKey);
    map['event_type'] = Variable<String>(eventType);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['active_seconds'] = Variable<int>(activeSeconds);
    map['completion_ratio'] = Variable<double>(completionRatio);
    return map;
  }

  ReadingEventsCompanion toCompanion(bool nullToAbsent) {
    return ReadingEventsCompanion(
      id: Value(id),
      articleId: Value(articleId),
      eventKey: Value(eventKey),
      eventType: Value(eventType),
      occurredAt: Value(occurredAt),
      activeSeconds: Value(activeSeconds),
      completionRatio: Value(completionRatio),
    );
  }

  factory ReadingEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingEvent(
      id: serializer.fromJson<String>(json['id']),
      articleId: serializer.fromJson<String>(json['articleId']),
      eventKey: serializer.fromJson<String>(json['eventKey']),
      eventType: serializer.fromJson<String>(json['eventType']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      activeSeconds: serializer.fromJson<int>(json['activeSeconds']),
      completionRatio: serializer.fromJson<double>(json['completionRatio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'articleId': serializer.toJson<String>(articleId),
      'eventKey': serializer.toJson<String>(eventKey),
      'eventType': serializer.toJson<String>(eventType),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'activeSeconds': serializer.toJson<int>(activeSeconds),
      'completionRatio': serializer.toJson<double>(completionRatio),
    };
  }

  ReadingEvent copyWith({
    String? id,
    String? articleId,
    String? eventKey,
    String? eventType,
    DateTime? occurredAt,
    int? activeSeconds,
    double? completionRatio,
  }) => ReadingEvent(
    id: id ?? this.id,
    articleId: articleId ?? this.articleId,
    eventKey: eventKey ?? this.eventKey,
    eventType: eventType ?? this.eventType,
    occurredAt: occurredAt ?? this.occurredAt,
    activeSeconds: activeSeconds ?? this.activeSeconds,
    completionRatio: completionRatio ?? this.completionRatio,
  );
  ReadingEvent copyWithCompanion(ReadingEventsCompanion data) {
    return ReadingEvent(
      id: data.id.present ? data.id.value : this.id,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      eventKey: data.eventKey.present ? data.eventKey.value : this.eventKey,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      activeSeconds: data.activeSeconds.present
          ? data.activeSeconds.value
          : this.activeSeconds,
      completionRatio: data.completionRatio.present
          ? data.completionRatio.value
          : this.completionRatio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingEvent(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('eventKey: $eventKey, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('activeSeconds: $activeSeconds, ')
          ..write('completionRatio: $completionRatio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    articleId,
    eventKey,
    eventType,
    occurredAt,
    activeSeconds,
    completionRatio,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingEvent &&
          other.id == this.id &&
          other.articleId == this.articleId &&
          other.eventKey == this.eventKey &&
          other.eventType == this.eventType &&
          other.occurredAt == this.occurredAt &&
          other.activeSeconds == this.activeSeconds &&
          other.completionRatio == this.completionRatio);
}

class ReadingEventsCompanion extends UpdateCompanion<ReadingEvent> {
  final Value<String> id;
  final Value<String> articleId;
  final Value<String> eventKey;
  final Value<String> eventType;
  final Value<DateTime> occurredAt;
  final Value<int> activeSeconds;
  final Value<double> completionRatio;
  final Value<int> rowid;
  const ReadingEventsCompanion({
    this.id = const Value.absent(),
    this.articleId = const Value.absent(),
    this.eventKey = const Value.absent(),
    this.eventType = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.activeSeconds = const Value.absent(),
    this.completionRatio = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingEventsCompanion.insert({
    required String id,
    required String articleId,
    required String eventKey,
    required String eventType,
    required DateTime occurredAt,
    this.activeSeconds = const Value.absent(),
    this.completionRatio = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       articleId = Value(articleId),
       eventKey = Value(eventKey),
       eventType = Value(eventType),
       occurredAt = Value(occurredAt);
  static Insertable<ReadingEvent> custom({
    Expression<String>? id,
    Expression<String>? articleId,
    Expression<String>? eventKey,
    Expression<String>? eventType,
    Expression<DateTime>? occurredAt,
    Expression<int>? activeSeconds,
    Expression<double>? completionRatio,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (articleId != null) 'article_id': articleId,
      if (eventKey != null) 'event_key': eventKey,
      if (eventType != null) 'event_type': eventType,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (activeSeconds != null) 'active_seconds': activeSeconds,
      if (completionRatio != null) 'completion_ratio': completionRatio,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? articleId,
    Value<String>? eventKey,
    Value<String>? eventType,
    Value<DateTime>? occurredAt,
    Value<int>? activeSeconds,
    Value<double>? completionRatio,
    Value<int>? rowid,
  }) {
    return ReadingEventsCompanion(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      eventKey: eventKey ?? this.eventKey,
      eventType: eventType ?? this.eventType,
      occurredAt: occurredAt ?? this.occurredAt,
      activeSeconds: activeSeconds ?? this.activeSeconds,
      completionRatio: completionRatio ?? this.completionRatio,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (eventKey.present) {
      map['event_key'] = Variable<String>(eventKey.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (activeSeconds.present) {
      map['active_seconds'] = Variable<int>(activeSeconds.value);
    }
    if (completionRatio.present) {
      map['completion_ratio'] = Variable<double>(completionRatio.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingEventsCompanion(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('eventKey: $eventKey, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('activeSeconds: $activeSeconds, ')
          ..write('completionRatio: $completionRatio, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeItemsTable extends KnowledgeItems
    with TableInfo<$KnowledgeItemsTable, KnowledgeItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE SET NULL',
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
      maxTextLength: 2048,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalUrlMeta = const VerificationMeta(
    'originalUrl',
  );
  @override
  late final GeneratedColumn<String> originalUrl = GeneratedColumn<String>(
    'original_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
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
    articleId,
    title,
    originalUrl,
    markdown,
    summaryJson,
    tagsJson,
    contentHash,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('original_url')) {
      context.handle(
        _originalUrlMeta,
        originalUrl.isAcceptableOrUnknown(
          data['original_url']!,
          _originalUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalUrlMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
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
    } else if (isInserting) {
      context.missing(_contentHashMeta);
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
  KnowledgeItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      originalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_url'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
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
  $KnowledgeItemsTable createAlias(String alias) {
    return $KnowledgeItemsTable(attachedDatabase, alias);
  }
}

class KnowledgeItem extends DataClass implements Insertable<KnowledgeItem> {
  final String id;
  final String? articleId;
  final String title;
  final String originalUrl;
  final String markdown;
  final String? summaryJson;
  final String tagsJson;
  final String contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  const KnowledgeItem({
    required this.id,
    this.articleId,
    required this.title,
    required this.originalUrl,
    required this.markdown,
    this.summaryJson,
    required this.tagsJson,
    required this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || articleId != null) {
      map['article_id'] = Variable<String>(articleId);
    }
    map['title'] = Variable<String>(title);
    map['original_url'] = Variable<String>(originalUrl);
    map['markdown'] = Variable<String>(markdown);
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    map['tags_json'] = Variable<String>(tagsJson);
    map['content_hash'] = Variable<String>(contentHash);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KnowledgeItemsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeItemsCompanion(
      id: Value(id),
      articleId: articleId == null && nullToAbsent
          ? const Value.absent()
          : Value(articleId),
      title: Value(title),
      originalUrl: Value(originalUrl),
      markdown: Value(markdown),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
      tagsJson: Value(tagsJson),
      contentHash: Value(contentHash),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory KnowledgeItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeItem(
      id: serializer.fromJson<String>(json['id']),
      articleId: serializer.fromJson<String?>(json['articleId']),
      title: serializer.fromJson<String>(json['title']),
      originalUrl: serializer.fromJson<String>(json['originalUrl']),
      markdown: serializer.fromJson<String>(json['markdown']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'articleId': serializer.toJson<String?>(articleId),
      'title': serializer.toJson<String>(title),
      'originalUrl': serializer.toJson<String>(originalUrl),
      'markdown': serializer.toJson<String>(markdown),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'contentHash': serializer.toJson<String>(contentHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KnowledgeItem copyWith({
    String? id,
    Value<String?> articleId = const Value.absent(),
    String? title,
    String? originalUrl,
    String? markdown,
    Value<String?> summaryJson = const Value.absent(),
    String? tagsJson,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => KnowledgeItem(
    id: id ?? this.id,
    articleId: articleId.present ? articleId.value : this.articleId,
    title: title ?? this.title,
    originalUrl: originalUrl ?? this.originalUrl,
    markdown: markdown ?? this.markdown,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    tagsJson: tagsJson ?? this.tagsJson,
    contentHash: contentHash ?? this.contentHash,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  KnowledgeItem copyWithCompanion(KnowledgeItemsCompanion data) {
    return KnowledgeItem(
      id: data.id.present ? data.id.value : this.id,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      title: data.title.present ? data.title.value : this.title,
      originalUrl: data.originalUrl.present
          ? data.originalUrl.value
          : this.originalUrl,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeItem(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('markdown: $markdown, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    articleId,
    title,
    originalUrl,
    markdown,
    summaryJson,
    tagsJson,
    contentHash,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeItem &&
          other.id == this.id &&
          other.articleId == this.articleId &&
          other.title == this.title &&
          other.originalUrl == this.originalUrl &&
          other.markdown == this.markdown &&
          other.summaryJson == this.summaryJson &&
          other.tagsJson == this.tagsJson &&
          other.contentHash == this.contentHash &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class KnowledgeItemsCompanion extends UpdateCompanion<KnowledgeItem> {
  final Value<String> id;
  final Value<String?> articleId;
  final Value<String> title;
  final Value<String> originalUrl;
  final Value<String> markdown;
  final Value<String?> summaryJson;
  final Value<String> tagsJson;
  final Value<String> contentHash;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KnowledgeItemsCompanion({
    this.id = const Value.absent(),
    this.articleId = const Value.absent(),
    this.title = const Value.absent(),
    this.originalUrl = const Value.absent(),
    this.markdown = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeItemsCompanion.insert({
    required String id,
    this.articleId = const Value.absent(),
    required String title,
    required String originalUrl,
    required String markdown,
    this.summaryJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    required String contentHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       originalUrl = Value(originalUrl),
       markdown = Value(markdown),
       contentHash = Value(contentHash),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<KnowledgeItem> custom({
    Expression<String>? id,
    Expression<String>? articleId,
    Expression<String>? title,
    Expression<String>? originalUrl,
    Expression<String>? markdown,
    Expression<String>? summaryJson,
    Expression<String>? tagsJson,
    Expression<String>? contentHash,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (articleId != null) 'article_id': articleId,
      if (title != null) 'title': title,
      if (originalUrl != null) 'original_url': originalUrl,
      if (markdown != null) 'markdown': markdown,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (contentHash != null) 'content_hash': contentHash,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeItemsCompanion copyWith({
    Value<String>? id,
    Value<String?>? articleId,
    Value<String>? title,
    Value<String>? originalUrl,
    Value<String>? markdown,
    Value<String?>? summaryJson,
    Value<String>? tagsJson,
    Value<String>? contentHash,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return KnowledgeItemsCompanion(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      originalUrl: originalUrl ?? this.originalUrl,
      markdown: markdown ?? this.markdown,
      summaryJson: summaryJson ?? this.summaryJson,
      tagsJson: tagsJson ?? this.tagsJson,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (originalUrl.present) {
      map['original_url'] = Variable<String>(originalUrl.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeItemsCompanion(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('title: $title, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('markdown: $markdown, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioItemsTable extends AudioItems
    with TableInfo<$AudioItemsTable, AudioItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
      maxTextLength: 2048,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playbackRateMeta = const VerificationMeta(
    'playbackRate',
  );
  @override
  late final GeneratedColumn<double> playbackRate = GeneratedColumn<double>(
    'playback_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _downloadedPathMeta = const VerificationMeta(
    'downloadedPath',
  );
  @override
  late final GeneratedColumn<String> downloadedPath = GeneratedColumn<String>(
    'downloaded_path',
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
    kind,
    title,
    sourceUri,
    positionMs,
    durationMs,
    playbackRate,
    downloadedPath,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUriMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('playback_rate')) {
      context.handle(
        _playbackRateMeta,
        playbackRate.isAcceptableOrUnknown(
          data['playback_rate']!,
          _playbackRateMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_path')) {
      context.handle(
        _downloadedPathMeta,
        downloadedPath.isAcceptableOrUnknown(
          data['downloaded_path']!,
          _downloadedPathMeta,
        ),
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
  AudioItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      playbackRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}playback_rate'],
      )!,
      downloadedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}downloaded_path'],
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
  $AudioItemsTable createAlias(String alias) {
    return $AudioItemsTable(attachedDatabase, alias);
  }
}

class AudioItem extends DataClass implements Insertable<AudioItem> {
  final String id;
  final String kind;
  final String title;
  final String sourceUri;
  final int positionMs;
  final int? durationMs;
  final double playbackRate;
  final String? downloadedPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AudioItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUri,
    required this.positionMs,
    this.durationMs,
    required this.playbackRate,
    this.downloadedPath,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['source_uri'] = Variable<String>(sourceUri);
    map['position_ms'] = Variable<int>(positionMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['playback_rate'] = Variable<double>(playbackRate);
    if (!nullToAbsent || downloadedPath != null) {
      map['downloaded_path'] = Variable<String>(downloadedPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AudioItemsCompanion toCompanion(bool nullToAbsent) {
    return AudioItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      sourceUri: Value(sourceUri),
      positionMs: Value(positionMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      playbackRate: Value(playbackRate),
      downloadedPath: downloadedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AudioItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioItem(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      sourceUri: serializer.fromJson<String>(json['sourceUri']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      playbackRate: serializer.fromJson<double>(json['playbackRate']),
      downloadedPath: serializer.fromJson<String?>(json['downloadedPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'sourceUri': serializer.toJson<String>(sourceUri),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'playbackRate': serializer.toJson<double>(playbackRate),
      'downloadedPath': serializer.toJson<String?>(downloadedPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AudioItem copyWith({
    String? id,
    String? kind,
    String? title,
    String? sourceUri,
    int? positionMs,
    Value<int?> durationMs = const Value.absent(),
    double? playbackRate,
    Value<String?> downloadedPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AudioItem(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    sourceUri: sourceUri ?? this.sourceUri,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    playbackRate: playbackRate ?? this.playbackRate,
    downloadedPath: downloadedPath.present
        ? downloadedPath.value
        : this.downloadedPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AudioItem copyWithCompanion(AudioItemsCompanion data) {
    return AudioItem(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      playbackRate: data.playbackRate.present
          ? data.playbackRate.value
          : this.playbackRate,
      downloadedPath: data.downloadedPath.present
          ? data.downloadedPath.value
          : this.downloadedPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioItem(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('downloadedPath: $downloadedPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    sourceUri,
    positionMs,
    durationMs,
    playbackRate,
    downloadedPath,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioItem &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.sourceUri == this.sourceUri &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.playbackRate == this.playbackRate &&
          other.downloadedPath == this.downloadedPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AudioItemsCompanion extends UpdateCompanion<AudioItem> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> sourceUri;
  final Value<int> positionMs;
  final Value<int?> durationMs;
  final Value<double> playbackRate;
  final Value<String?> downloadedPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AudioItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.downloadedPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioItemsCompanion.insert({
    required String id,
    required String kind,
    required String title,
    required String sourceUri,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.downloadedPath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       sourceUri = Value(sourceUri),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AudioItem> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? sourceUri,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<double>? playbackRate,
    Expression<String>? downloadedPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (sourceUri != null) 'source_uri': sourceUri,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (playbackRate != null) 'playback_rate': playbackRate,
      if (downloadedPath != null) 'downloaded_path': downloadedPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? sourceUri,
    Value<int>? positionMs,
    Value<int?>? durationMs,
    Value<double>? playbackRate,
    Value<String?>? downloadedPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AudioItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      sourceUri: sourceUri ?? this.sourceUri,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      playbackRate: playbackRate ?? this.playbackRate,
      downloadedPath: downloadedPath ?? this.downloadedPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (playbackRate.present) {
      map['playback_rate'] = Variable<double>(playbackRate.value);
    }
    if (downloadedPath.present) {
      map['downloaded_path'] = Variable<String>(downloadedPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('downloadedPath: $downloadedPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackgroundJobsTable extends BackgroundJobs
    with TableInfo<$BackgroundJobsTable, BackgroundJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackgroundJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxAttemptsMeta = const VerificationMeta(
    'maxAttempts',
  );
  @override
  late final GeneratedColumn<int> maxAttempts = GeneratedColumn<int>(
    'max_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<DateTime> availableAt = GeneratedColumn<DateTime>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<DateTime> leaseUntil = GeneratedColumn<DateTime>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
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
    type,
    idempotencyKey,
    payloadJson,
    status,
    attempt,
    maxAttempts,
    availableAt,
    leaseUntil,
    lastErrorCode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'background_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackgroundJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('max_attempts')) {
      context.handle(
        _maxAttemptsMeta,
        maxAttempts.isAcceptableOrUnknown(
          data['max_attempts']!,
          _maxAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availableAtMeta);
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {idempotencyKey},
  ];
  @override
  BackgroundJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackgroundJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      maxAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_attempts'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}available_at'],
      )!,
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_until'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
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
  $BackgroundJobsTable createAlias(String alias) {
    return $BackgroundJobsTable(attachedDatabase, alias);
  }
}

class BackgroundJob extends DataClass implements Insertable<BackgroundJob> {
  final String id;
  final String type;
  final String idempotencyKey;
  final String payloadJson;
  final String status;
  final int attempt;
  final int maxAttempts;
  final DateTime availableAt;
  final DateTime? leaseUntil;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BackgroundJob({
    required this.id,
    required this.type,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.status,
    required this.attempt,
    required this.maxAttempts,
    required this.availableAt,
    this.leaseUntil,
    this.lastErrorCode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt'] = Variable<int>(attempt);
    map['max_attempts'] = Variable<int>(maxAttempts);
    map['available_at'] = Variable<DateTime>(availableAt);
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<DateTime>(leaseUntil);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BackgroundJobsCompanion toCompanion(bool nullToAbsent) {
    return BackgroundJobsCompanion(
      id: Value(id),
      type: Value(type),
      idempotencyKey: Value(idempotencyKey),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attempt: Value(attempt),
      maxAttempts: Value(maxAttempts),
      availableAt: Value(availableAt),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BackgroundJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackgroundJob(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attempt: serializer.fromJson<int>(json['attempt']),
      maxAttempts: serializer.fromJson<int>(json['maxAttempts']),
      availableAt: serializer.fromJson<DateTime>(json['availableAt']),
      leaseUntil: serializer.fromJson<DateTime?>(json['leaseUntil']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attempt': serializer.toJson<int>(attempt),
      'maxAttempts': serializer.toJson<int>(maxAttempts),
      'availableAt': serializer.toJson<DateTime>(availableAt),
      'leaseUntil': serializer.toJson<DateTime?>(leaseUntil),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BackgroundJob copyWith({
    String? id,
    String? type,
    String? idempotencyKey,
    String? payloadJson,
    String? status,
    int? attempt,
    int? maxAttempts,
    DateTime? availableAt,
    Value<DateTime?> leaseUntil = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BackgroundJob(
    id: id ?? this.id,
    type: type ?? this.type,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attempt: attempt ?? this.attempt,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    availableAt: availableAt ?? this.availableAt,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BackgroundJob copyWithCompanion(BackgroundJobsCompanion data) {
    return BackgroundJob(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      maxAttempts: data.maxAttempts.present
          ? data.maxAttempts.value
          : this.maxAttempts,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackgroundJob(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempt: $attempt, ')
          ..write('maxAttempts: $maxAttempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    idempotencyKey,
    payloadJson,
    status,
    attempt,
    maxAttempts,
    availableAt,
    leaseUntil,
    lastErrorCode,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackgroundJob &&
          other.id == this.id &&
          other.type == this.type &&
          other.idempotencyKey == this.idempotencyKey &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attempt == this.attempt &&
          other.maxAttempts == this.maxAttempts &&
          other.availableAt == this.availableAt &&
          other.leaseUntil == this.leaseUntil &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BackgroundJobsCompanion extends UpdateCompanion<BackgroundJob> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> idempotencyKey;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attempt;
  final Value<int> maxAttempts;
  final Value<DateTime> availableAt;
  final Value<DateTime?> leaseUntil;
  final Value<String?> lastErrorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BackgroundJobsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attempt = const Value.absent(),
    this.maxAttempts = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackgroundJobsCompanion.insert({
    required String id,
    required String type,
    required String idempotencyKey,
    required String payloadJson,
    this.status = const Value.absent(),
    this.attempt = const Value.absent(),
    this.maxAttempts = const Value.absent(),
    required DateTime availableAt,
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       idempotencyKey = Value(idempotencyKey),
       payloadJson = Value(payloadJson),
       availableAt = Value(availableAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BackgroundJob> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? idempotencyKey,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attempt,
    Expression<int>? maxAttempts,
    Expression<DateTime>? availableAt,
    Expression<DateTime>? leaseUntil,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attempt != null) 'attempt': attempt,
      if (maxAttempts != null) 'max_attempts': maxAttempts,
      if (availableAt != null) 'available_at': availableAt,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackgroundJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? idempotencyKey,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attempt,
    Value<int>? maxAttempts,
    Value<DateTime>? availableAt,
    Value<DateTime?>? leaseUntil,
    Value<String?>? lastErrorCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BackgroundJobsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      availableAt: availableAt ?? this.availableAt,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (maxAttempts.present) {
      map['max_attempts'] = Variable<int>(maxAttempts.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<DateTime>(availableAt.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<DateTime>(leaseUntil.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackgroundJobsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempt: $attempt, ')
          ..write('maxAttempts: $maxAttempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncTombstonesTable extends SyncTombstones
    with TableInfo<$SyncTombstonesTable, SyncTombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entityType, entityId},
  ];
  @override
  SyncTombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncTombstone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $SyncTombstonesTable createAlias(String alias) {
    return $SyncTombstonesTable(attachedDatabase, alias);
  }
}

class SyncTombstone extends DataClass implements Insertable<SyncTombstone> {
  final String id;
  final String entityType;
  final String entityId;
  final DateTime deletedAt;
  final String deviceId;
  const SyncTombstone({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  SyncTombstonesCompanion toCompanion(bool nullToAbsent) {
    return SyncTombstonesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      deletedAt: Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory SyncTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncTombstone(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  SyncTombstone copyWith({
    String? id,
    String? entityType,
    String? entityId,
    DateTime? deletedAt,
    String? deviceId,
  }) => SyncTombstone(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    deletedAt: deletedAt ?? this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  SyncTombstone copyWithCompanion(SyncTombstonesCompanion data) {
    return SyncTombstone(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncTombstone(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityType, entityId, deletedAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncTombstone &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class SyncTombstonesCompanion extends UpdateCompanion<SyncTombstone> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<DateTime> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const SyncTombstonesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncTombstonesCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required DateTime deletedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       deletedAt = Value(deletedAt),
       deviceId = Value(deviceId);
  static Insertable<SyncTombstone> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncTombstonesCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<DateTime>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return SyncTombstonesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncTombstonesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RiverDatabase extends GeneratedDatabase {
  _$RiverDatabase(QueryExecutor e) : super(e);
  $RiverDatabaseManager get managers => $RiverDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $FeedSubscriptionsTable feedSubscriptions =
      $FeedSubscriptionsTable(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $ArticleContentsTable articleContents = $ArticleContentsTable(
    this,
  );
  late final $ReadingEventsTable readingEvents = $ReadingEventsTable(this);
  late final $KnowledgeItemsTable knowledgeItems = $KnowledgeItemsTable(this);
  late final $AudioItemsTable audioItems = $AudioItemsTable(this);
  late final $BackgroundJobsTable backgroundJobs = $BackgroundJobsTable(this);
  late final $SyncTombstonesTable syncTombstones = $SyncTombstonesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    feedSubscriptions,
    articles,
    articleContents,
    readingEvents,
    knowledgeItems,
    audioItems,
    backgroundJobs,
    syncTombstones,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'feed_subscriptions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('articles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('article_contents', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_items', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String name,
      Value<int> position,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> position,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$RiverDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FeedSubscriptionsTable, List<FeedSubscription>>
  _feedSubscriptionsRefsTable(_$RiverDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.feedSubscriptions,
        aliasName: $_aliasNameGenerator(
          db.folders.id,
          db.feedSubscriptions.folderId,
        ),
      );

  $$FeedSubscriptionsTableProcessedTableManager get feedSubscriptionsRefs {
    final manager = $$FeedSubscriptionsTableTableManager(
      $_db,
      $_db.feedSubscriptions,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _feedSubscriptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$RiverDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
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

  Expression<bool> feedSubscriptionsRefs(
    Expression<bool> Function($$FeedSubscriptionsTableFilterComposer f) f,
  ) {
    final $$FeedSubscriptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.feedSubscriptions,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeedSubscriptionsTableFilterComposer(
            $db: $db,
            $table: $db.feedSubscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$RiverDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
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

class $$FoldersTableAnnotationComposer
    extends Composer<_$RiverDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> feedSubscriptionsRefs<T extends Object>(
    Expression<T> Function($$FeedSubscriptionsTableAnnotationComposer a) f,
  ) {
    final $$FeedSubscriptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.feedSubscriptions,
          getReferencedColumn: (t) => t.folderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FeedSubscriptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.feedSubscriptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool feedSubscriptionsRefs})
        > {
  $$FoldersTableTableManager(_$RiverDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> position = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({feedSubscriptionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (feedSubscriptionsRefs) db.feedSubscriptions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (feedSubscriptionsRefs)
                    await $_getPrefetchedData<
                      Folder,
                      $FoldersTable,
                      FeedSubscription
                    >(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences
                          ._feedSubscriptionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$FoldersTableReferences(
                        db,
                        table,
                        p0,
                      ).feedSubscriptionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool feedSubscriptionsRefs})
    >;
typedef $$FeedSubscriptionsTableCreateCompanionBuilder =
    FeedSubscriptionsCompanion Function({
      required String id,
      required String canonicalUrl,
      required String title,
      Value<String?> folderId,
      required String feedKind,
      Value<bool> enabled,
      Value<String?> etag,
      Value<String?> lastModified,
      Value<DateTime?> lastRefreshedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FeedSubscriptionsTableUpdateCompanionBuilder =
    FeedSubscriptionsCompanion Function({
      Value<String> id,
      Value<String> canonicalUrl,
      Value<String> title,
      Value<String?> folderId,
      Value<String> feedKind,
      Value<bool> enabled,
      Value<String?> etag,
      Value<String?> lastModified,
      Value<DateTime?> lastRefreshedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FeedSubscriptionsTableReferences
    extends
        BaseReferences<
          _$RiverDatabase,
          $FeedSubscriptionsTable,
          FeedSubscription
        > {
  $$FeedSubscriptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoldersTable _folderIdTable(_$RiverDatabase db) =>
      db.folders.createAlias(
        $_aliasNameGenerator(db.feedSubscriptions.folderId, db.folders.id),
      );

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ArticlesTable, List<Article>> _articlesRefsTable(
    _$RiverDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.articles,
    aliasName: $_aliasNameGenerator(
      db.feedSubscriptions.id,
      db.articles.feedId,
    ),
  );

  $$ArticlesTableProcessedTableManager get articlesRefs {
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.feedId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_articlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FeedSubscriptionsTableFilterComposer
    extends Composer<_$RiverDatabase, $FeedSubscriptionsTable> {
  $$FeedSubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedKind => $composableBuilder(
    column: $table.feedKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
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

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> articlesRefs(
    Expression<bool> Function($$ArticlesTableFilterComposer f) f,
  ) {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.feedId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FeedSubscriptionsTableOrderingComposer
    extends Composer<_$RiverDatabase, $FeedSubscriptionsTable> {
  $$FeedSubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedKind => $composableBuilder(
    column: $table.feedKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
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

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeedSubscriptionsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $FeedSubscriptionsTable> {
  $$FeedSubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get feedKind =>
      $composableBuilder(column: $table.feedKind, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> articlesRefs<T extends Object>(
    Expression<T> Function($$ArticlesTableAnnotationComposer a) f,
  ) {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.feedId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FeedSubscriptionsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $FeedSubscriptionsTable,
          FeedSubscription,
          $$FeedSubscriptionsTableFilterComposer,
          $$FeedSubscriptionsTableOrderingComposer,
          $$FeedSubscriptionsTableAnnotationComposer,
          $$FeedSubscriptionsTableCreateCompanionBuilder,
          $$FeedSubscriptionsTableUpdateCompanionBuilder,
          (FeedSubscription, $$FeedSubscriptionsTableReferences),
          FeedSubscription,
          PrefetchHooks Function({bool folderId, bool articlesRefs})
        > {
  $$FeedSubscriptionsTableTableManager(
    _$RiverDatabase db,
    $FeedSubscriptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedSubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedSubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedSubscriptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> canonicalUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> feedKind = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime?> lastRefreshedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedSubscriptionsCompanion(
                id: id,
                canonicalUrl: canonicalUrl,
                title: title,
                folderId: folderId,
                feedKind: feedKind,
                enabled: enabled,
                etag: etag,
                lastModified: lastModified,
                lastRefreshedAt: lastRefreshedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String canonicalUrl,
                required String title,
                Value<String?> folderId = const Value.absent(),
                required String feedKind,
                Value<bool> enabled = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime?> lastRefreshedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FeedSubscriptionsCompanion.insert(
                id: id,
                canonicalUrl: canonicalUrl,
                title: title,
                folderId: folderId,
                feedKind: feedKind,
                enabled: enabled,
                etag: etag,
                lastModified: lastModified,
                lastRefreshedAt: lastRefreshedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FeedSubscriptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, articlesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (articlesRefs) db.articles],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable:
                                    $$FeedSubscriptionsTableReferences
                                        ._folderIdTable(db),
                                referencedColumn:
                                    $$FeedSubscriptionsTableReferences
                                        ._folderIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (articlesRefs)
                    await $_getPrefetchedData<
                      FeedSubscription,
                      $FeedSubscriptionsTable,
                      Article
                    >(
                      currentTable: table,
                      referencedTable: $$FeedSubscriptionsTableReferences
                          ._articlesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FeedSubscriptionsTableReferences(
                            db,
                            table,
                            p0,
                          ).articlesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.feedId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FeedSubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $FeedSubscriptionsTable,
      FeedSubscription,
      $$FeedSubscriptionsTableFilterComposer,
      $$FeedSubscriptionsTableOrderingComposer,
      $$FeedSubscriptionsTableAnnotationComposer,
      $$FeedSubscriptionsTableCreateCompanionBuilder,
      $$FeedSubscriptionsTableUpdateCompanionBuilder,
      (FeedSubscription, $$FeedSubscriptionsTableReferences),
      FeedSubscription,
      PrefetchHooks Function({bool folderId, bool articlesRefs})
    >;
typedef $$ArticlesTableCreateCompanionBuilder =
    ArticlesCompanion Function({
      required String id,
      required String feedId,
      required String canonicalUrl,
      required String title,
      Value<String?> author,
      Value<DateTime?> publishedAt,
      Value<String?> feedSummary,
      Value<String> readState,
      Value<bool> starred,
      Value<bool> readLater,
      Value<int> activeReadSeconds,
      Value<double> scrollDepth,
      Value<DateTime?> completedAt,
      Value<String?> contentHash,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ArticlesTableUpdateCompanionBuilder =
    ArticlesCompanion Function({
      Value<String> id,
      Value<String> feedId,
      Value<String> canonicalUrl,
      Value<String> title,
      Value<String?> author,
      Value<DateTime?> publishedAt,
      Value<String?> feedSummary,
      Value<String> readState,
      Value<bool> starred,
      Value<bool> readLater,
      Value<int> activeReadSeconds,
      Value<double> scrollDepth,
      Value<DateTime?> completedAt,
      Value<String?> contentHash,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ArticlesTableReferences
    extends BaseReferences<_$RiverDatabase, $ArticlesTable, Article> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FeedSubscriptionsTable _feedIdTable(_$RiverDatabase db) =>
      db.feedSubscriptions.createAlias(
        $_aliasNameGenerator(db.articles.feedId, db.feedSubscriptions.id),
      );

  $$FeedSubscriptionsTableProcessedTableManager get feedId {
    final $_column = $_itemColumn<String>('feed_id')!;

    final manager = $$FeedSubscriptionsTableTableManager(
      $_db,
      $_db.feedSubscriptions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_feedIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ArticleContentsTable, List<ArticleContent>>
  _articleContentsRefsTable(_$RiverDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.articleContents,
        aliasName: $_aliasNameGenerator(
          db.articles.id,
          db.articleContents.articleId,
        ),
      );

  $$ArticleContentsTableProcessedTableManager get articleContentsRefs {
    final manager = $$ArticleContentsTableTableManager(
      $_db,
      $_db.articleContents,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _articleContentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingEventsTable, List<ReadingEvent>>
  _readingEventsRefsTable(_$RiverDatabase db) => MultiTypedResultKey.fromTable(
    db.readingEvents,
    aliasName: $_aliasNameGenerator(db.articles.id, db.readingEvents.articleId),
  );

  $$ReadingEventsTableProcessedTableManager get readingEventsRefs {
    final manager = $$ReadingEventsTableTableManager(
      $_db,
      $_db.readingEvents,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_readingEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KnowledgeItemsTable, List<KnowledgeItem>>
  _knowledgeItemsRefsTable(_$RiverDatabase db) => MultiTypedResultKey.fromTable(
    db.knowledgeItems,
    aliasName: $_aliasNameGenerator(
      db.articles.id,
      db.knowledgeItems.articleId,
    ),
  );

  $$KnowledgeItemsTableProcessedTableManager get knowledgeItemsRefs {
    final manager = $$KnowledgeItemsTableTableManager(
      $_db,
      $_db.knowledgeItems,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_knowledgeItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$RiverDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedSummary => $composableBuilder(
    column: $table.feedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readState => $composableBuilder(
    column: $table.readState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readLater => $composableBuilder(
    column: $table.readLater,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeReadSeconds => $composableBuilder(
    column: $table.activeReadSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scrollDepth => $composableBuilder(
    column: $table.scrollDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
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

  $$FeedSubscriptionsTableFilterComposer get feedId {
    final $$FeedSubscriptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.feedId,
      referencedTable: $db.feedSubscriptions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeedSubscriptionsTableFilterComposer(
            $db: $db,
            $table: $db.feedSubscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> articleContentsRefs(
    Expression<bool> Function($$ArticleContentsTableFilterComposer f) f,
  ) {
    final $$ArticleContentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articleContents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleContentsTableFilterComposer(
            $db: $db,
            $table: $db.articleContents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingEventsRefs(
    Expression<bool> Function($$ReadingEventsTableFilterComposer f) f,
  ) {
    final $$ReadingEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingEvents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingEventsTableFilterComposer(
            $db: $db,
            $table: $db.readingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> knowledgeItemsRefs(
    Expression<bool> Function($$KnowledgeItemsTableFilterComposer f) f,
  ) {
    final $$KnowledgeItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knowledgeItems,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnowledgeItemsTableFilterComposer(
            $db: $db,
            $table: $db.knowledgeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$RiverDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedSummary => $composableBuilder(
    column: $table.feedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readState => $composableBuilder(
    column: $table.readState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readLater => $composableBuilder(
    column: $table.readLater,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeReadSeconds => $composableBuilder(
    column: $table.activeReadSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scrollDepth => $composableBuilder(
    column: $table.scrollDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
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

  $$FeedSubscriptionsTableOrderingComposer get feedId {
    final $$FeedSubscriptionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.feedId,
      referencedTable: $db.feedSubscriptions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeedSubscriptionsTableOrderingComposer(
            $db: $db,
            $table: $db.feedSubscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$RiverDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedSummary => $composableBuilder(
    column: $table.feedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readState =>
      $composableBuilder(column: $table.readState, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get readLater =>
      $composableBuilder(column: $table.readLater, builder: (column) => column);

  GeneratedColumn<int> get activeReadSeconds => $composableBuilder(
    column: $table.activeReadSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scrollDepth => $composableBuilder(
    column: $table.scrollDepth,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FeedSubscriptionsTableAnnotationComposer get feedId {
    final $$FeedSubscriptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.feedId,
          referencedTable: $db.feedSubscriptions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FeedSubscriptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.feedSubscriptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> articleContentsRefs<T extends Object>(
    Expression<T> Function($$ArticleContentsTableAnnotationComposer a) f,
  ) {
    final $$ArticleContentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articleContents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleContentsTableAnnotationComposer(
            $db: $db,
            $table: $db.articleContents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingEventsRefs<T extends Object>(
    Expression<T> Function($$ReadingEventsTableAnnotationComposer a) f,
  ) {
    final $$ReadingEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingEvents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.readingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> knowledgeItemsRefs<T extends Object>(
    Expression<T> Function($$KnowledgeItemsTableAnnotationComposer a) f,
  ) {
    final $$KnowledgeItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knowledgeItems,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnowledgeItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.knowledgeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $ArticlesTable,
          Article,
          $$ArticlesTableFilterComposer,
          $$ArticlesTableOrderingComposer,
          $$ArticlesTableAnnotationComposer,
          $$ArticlesTableCreateCompanionBuilder,
          $$ArticlesTableUpdateCompanionBuilder,
          (Article, $$ArticlesTableReferences),
          Article,
          PrefetchHooks Function({
            bool feedId,
            bool articleContentsRefs,
            bool readingEventsRefs,
            bool knowledgeItemsRefs,
          })
        > {
  $$ArticlesTableTableManager(_$RiverDatabase db, $ArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> feedId = const Value.absent(),
                Value<String> canonicalUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> feedSummary = const Value.absent(),
                Value<String> readState = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> readLater = const Value.absent(),
                Value<int> activeReadSeconds = const Value.absent(),
                Value<double> scrollDepth = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion(
                id: id,
                feedId: feedId,
                canonicalUrl: canonicalUrl,
                title: title,
                author: author,
                publishedAt: publishedAt,
                feedSummary: feedSummary,
                readState: readState,
                starred: starred,
                readLater: readLater,
                activeReadSeconds: activeReadSeconds,
                scrollDepth: scrollDepth,
                completedAt: completedAt,
                contentHash: contentHash,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String feedId,
                required String canonicalUrl,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> feedSummary = const Value.absent(),
                Value<String> readState = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> readLater = const Value.absent(),
                Value<int> activeReadSeconds = const Value.absent(),
                Value<double> scrollDepth = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion.insert(
                id: id,
                feedId: feedId,
                canonicalUrl: canonicalUrl,
                title: title,
                author: author,
                publishedAt: publishedAt,
                feedSummary: feedSummary,
                readState: readState,
                starred: starred,
                readLater: readLater,
                activeReadSeconds: activeReadSeconds,
                scrollDepth: scrollDepth,
                completedAt: completedAt,
                contentHash: contentHash,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                feedId = false,
                articleContentsRefs = false,
                readingEventsRefs = false,
                knowledgeItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (articleContentsRefs) db.articleContents,
                    if (readingEventsRefs) db.readingEvents,
                    if (knowledgeItemsRefs) db.knowledgeItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (feedId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.feedId,
                                    referencedTable: $$ArticlesTableReferences
                                        ._feedIdTable(db),
                                    referencedColumn: $$ArticlesTableReferences
                                        ._feedIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (articleContentsRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          ArticleContent
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._articleContentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).articleContentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingEventsRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          ReadingEvent
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._readingEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).readingEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (knowledgeItemsRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          KnowledgeItem
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._knowledgeItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).knowledgeItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $ArticlesTable,
      Article,
      $$ArticlesTableFilterComposer,
      $$ArticlesTableOrderingComposer,
      $$ArticlesTableAnnotationComposer,
      $$ArticlesTableCreateCompanionBuilder,
      $$ArticlesTableUpdateCompanionBuilder,
      (Article, $$ArticlesTableReferences),
      Article,
      PrefetchHooks Function({
        bool feedId,
        bool articleContentsRefs,
        bool readingEventsRefs,
        bool knowledgeItemsRefs,
      })
    >;
typedef $$ArticleContentsTableCreateCompanionBuilder =
    ArticleContentsCompanion Function({
      required String articleId,
      required String sanitizedHtml,
      required String markdown,
      required String plainText,
      required String extractorName,
      required String extractorVersion,
      Value<String?> etag,
      Value<String?> lastModified,
      required DateTime extractedAt,
      Value<String?> failureCode,
      Value<int> rowid,
    });
typedef $$ArticleContentsTableUpdateCompanionBuilder =
    ArticleContentsCompanion Function({
      Value<String> articleId,
      Value<String> sanitizedHtml,
      Value<String> markdown,
      Value<String> plainText,
      Value<String> extractorName,
      Value<String> extractorVersion,
      Value<String?> etag,
      Value<String?> lastModified,
      Value<DateTime> extractedAt,
      Value<String?> failureCode,
      Value<int> rowid,
    });

final class $$ArticleContentsTableReferences
    extends
        BaseReferences<_$RiverDatabase, $ArticleContentsTable, ArticleContent> {
  $$ArticleContentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArticlesTable _articleIdTable(_$RiverDatabase db) =>
      db.articles.createAlias(
        $_aliasNameGenerator(db.articleContents.articleId, db.articles.id),
      );

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ArticleContentsTableFilterComposer
    extends Composer<_$RiverDatabase, $ArticleContentsTable> {
  $$ArticleContentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sanitizedHtml => $composableBuilder(
    column: $table.sanitizedHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractorName => $composableBuilder(
    column: $table.extractorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleContentsTableOrderingComposer
    extends Composer<_$RiverDatabase, $ArticleContentsTable> {
  $$ArticleContentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sanitizedHtml => $composableBuilder(
    column: $table.sanitizedHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractorName => $composableBuilder(
    column: $table.extractorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleContentsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $ArticleContentsTable> {
  $$ArticleContentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sanitizedHtml => $composableBuilder(
    column: $table.sanitizedHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<String> get extractorName => $composableBuilder(
    column: $table.extractorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractorVersion => $composableBuilder(
    column: $table.extractorVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleContentsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $ArticleContentsTable,
          ArticleContent,
          $$ArticleContentsTableFilterComposer,
          $$ArticleContentsTableOrderingComposer,
          $$ArticleContentsTableAnnotationComposer,
          $$ArticleContentsTableCreateCompanionBuilder,
          $$ArticleContentsTableUpdateCompanionBuilder,
          (ArticleContent, $$ArticleContentsTableReferences),
          ArticleContent,
          PrefetchHooks Function({bool articleId})
        > {
  $$ArticleContentsTableTableManager(
    _$RiverDatabase db,
    $ArticleContentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticleContentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticleContentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticleContentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> articleId = const Value.absent(),
                Value<String> sanitizedHtml = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<String> plainText = const Value.absent(),
                Value<String> extractorName = const Value.absent(),
                Value<String> extractorVersion = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime> extractedAt = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleContentsCompanion(
                articleId: articleId,
                sanitizedHtml: sanitizedHtml,
                markdown: markdown,
                plainText: plainText,
                extractorName: extractorName,
                extractorVersion: extractorVersion,
                etag: etag,
                lastModified: lastModified,
                extractedAt: extractedAt,
                failureCode: failureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String articleId,
                required String sanitizedHtml,
                required String markdown,
                required String plainText,
                required String extractorName,
                required String extractorVersion,
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                required DateTime extractedAt,
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleContentsCompanion.insert(
                articleId: articleId,
                sanitizedHtml: sanitizedHtml,
                markdown: markdown,
                plainText: plainText,
                extractorName: extractorName,
                extractorVersion: extractorVersion,
                etag: etag,
                lastModified: lastModified,
                extractedAt: extractedAt,
                failureCode: failureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ArticleContentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable:
                                    $$ArticleContentsTableReferences
                                        ._articleIdTable(db),
                                referencedColumn:
                                    $$ArticleContentsTableReferences
                                        ._articleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ArticleContentsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $ArticleContentsTable,
      ArticleContent,
      $$ArticleContentsTableFilterComposer,
      $$ArticleContentsTableOrderingComposer,
      $$ArticleContentsTableAnnotationComposer,
      $$ArticleContentsTableCreateCompanionBuilder,
      $$ArticleContentsTableUpdateCompanionBuilder,
      (ArticleContent, $$ArticleContentsTableReferences),
      ArticleContent,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$ReadingEventsTableCreateCompanionBuilder =
    ReadingEventsCompanion Function({
      required String id,
      required String articleId,
      required String eventKey,
      required String eventType,
      required DateTime occurredAt,
      Value<int> activeSeconds,
      Value<double> completionRatio,
      Value<int> rowid,
    });
typedef $$ReadingEventsTableUpdateCompanionBuilder =
    ReadingEventsCompanion Function({
      Value<String> id,
      Value<String> articleId,
      Value<String> eventKey,
      Value<String> eventType,
      Value<DateTime> occurredAt,
      Value<int> activeSeconds,
      Value<double> completionRatio,
      Value<int> rowid,
    });

final class $$ReadingEventsTableReferences
    extends BaseReferences<_$RiverDatabase, $ReadingEventsTable, ReadingEvent> {
  $$ReadingEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArticlesTable _articleIdTable(_$RiverDatabase db) =>
      db.articles.createAlias(
        $_aliasNameGenerator(db.readingEvents.articleId, db.articles.id),
      );

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingEventsTableFilterComposer
    extends Composer<_$RiverDatabase, $ReadingEventsTable> {
  $$ReadingEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get completionRatio => $composableBuilder(
    column: $table.completionRatio,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEventsTableOrderingComposer
    extends Composer<_$RiverDatabase, $ReadingEventsTable> {
  $$ReadingEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get completionRatio => $composableBuilder(
    column: $table.completionRatio,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEventsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $ReadingEventsTable> {
  $$ReadingEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventKey =>
      $composableBuilder(column: $table.eventKey, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeSeconds => $composableBuilder(
    column: $table.activeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get completionRatio => $composableBuilder(
    column: $table.completionRatio,
    builder: (column) => column,
  );

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingEventsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $ReadingEventsTable,
          ReadingEvent,
          $$ReadingEventsTableFilterComposer,
          $$ReadingEventsTableOrderingComposer,
          $$ReadingEventsTableAnnotationComposer,
          $$ReadingEventsTableCreateCompanionBuilder,
          $$ReadingEventsTableUpdateCompanionBuilder,
          (ReadingEvent, $$ReadingEventsTableReferences),
          ReadingEvent,
          PrefetchHooks Function({bool articleId})
        > {
  $$ReadingEventsTableTableManager(
    _$RiverDatabase db,
    $ReadingEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<String> eventKey = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> activeSeconds = const Value.absent(),
                Value<double> completionRatio = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingEventsCompanion(
                id: id,
                articleId: articleId,
                eventKey: eventKey,
                eventType: eventType,
                occurredAt: occurredAt,
                activeSeconds: activeSeconds,
                completionRatio: completionRatio,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String articleId,
                required String eventKey,
                required String eventType,
                required DateTime occurredAt,
                Value<int> activeSeconds = const Value.absent(),
                Value<double> completionRatio = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingEventsCompanion.insert(
                id: id,
                articleId: articleId,
                eventKey: eventKey,
                eventType: eventType,
                occurredAt: occurredAt,
                activeSeconds: activeSeconds,
                completionRatio: completionRatio,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable: $$ReadingEventsTableReferences
                                    ._articleIdTable(db),
                                referencedColumn: $$ReadingEventsTableReferences
                                    ._articleIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $ReadingEventsTable,
      ReadingEvent,
      $$ReadingEventsTableFilterComposer,
      $$ReadingEventsTableOrderingComposer,
      $$ReadingEventsTableAnnotationComposer,
      $$ReadingEventsTableCreateCompanionBuilder,
      $$ReadingEventsTableUpdateCompanionBuilder,
      (ReadingEvent, $$ReadingEventsTableReferences),
      ReadingEvent,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$KnowledgeItemsTableCreateCompanionBuilder =
    KnowledgeItemsCompanion Function({
      required String id,
      Value<String?> articleId,
      required String title,
      required String originalUrl,
      required String markdown,
      Value<String?> summaryJson,
      Value<String> tagsJson,
      required String contentHash,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$KnowledgeItemsTableUpdateCompanionBuilder =
    KnowledgeItemsCompanion Function({
      Value<String> id,
      Value<String?> articleId,
      Value<String> title,
      Value<String> originalUrl,
      Value<String> markdown,
      Value<String?> summaryJson,
      Value<String> tagsJson,
      Value<String> contentHash,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$KnowledgeItemsTableReferences
    extends
        BaseReferences<_$RiverDatabase, $KnowledgeItemsTable, KnowledgeItem> {
  $$KnowledgeItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArticlesTable _articleIdTable(_$RiverDatabase db) =>
      db.articles.createAlias(
        $_aliasNameGenerator(db.knowledgeItems.articleId, db.articles.id),
      );

  $$ArticlesTableProcessedTableManager? get articleId {
    final $_column = $_itemColumn<String>('article_id');
    if ($_column == null) return null;
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KnowledgeItemsTableFilterComposer
    extends Composer<_$RiverDatabase, $KnowledgeItemsTable> {
  $$KnowledgeItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
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

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeItemsTableOrderingComposer
    extends Composer<_$RiverDatabase, $KnowledgeItemsTable> {
  $$KnowledgeItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
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

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeItemsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $KnowledgeItemsTable> {
  $$KnowledgeItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeItemsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $KnowledgeItemsTable,
          KnowledgeItem,
          $$KnowledgeItemsTableFilterComposer,
          $$KnowledgeItemsTableOrderingComposer,
          $$KnowledgeItemsTableAnnotationComposer,
          $$KnowledgeItemsTableCreateCompanionBuilder,
          $$KnowledgeItemsTableUpdateCompanionBuilder,
          (KnowledgeItem, $$KnowledgeItemsTableReferences),
          KnowledgeItem,
          PrefetchHooks Function({bool articleId})
        > {
  $$KnowledgeItemsTableTableManager(
    _$RiverDatabase db,
    $KnowledgeItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnowledgeItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnowledgeItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnowledgeItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> articleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> originalUrl = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeItemsCompanion(
                id: id,
                articleId: articleId,
                title: title,
                originalUrl: originalUrl,
                markdown: markdown,
                summaryJson: summaryJson,
                tagsJson: tagsJson,
                contentHash: contentHash,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> articleId = const Value.absent(),
                required String title,
                required String originalUrl,
                required String markdown,
                Value<String?> summaryJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                required String contentHash,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeItemsCompanion.insert(
                id: id,
                articleId: articleId,
                title: title,
                originalUrl: originalUrl,
                markdown: markdown,
                summaryJson: summaryJson,
                tagsJson: tagsJson,
                contentHash: contentHash,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KnowledgeItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable: $$KnowledgeItemsTableReferences
                                    ._articleIdTable(db),
                                referencedColumn:
                                    $$KnowledgeItemsTableReferences
                                        ._articleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KnowledgeItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $KnowledgeItemsTable,
      KnowledgeItem,
      $$KnowledgeItemsTableFilterComposer,
      $$KnowledgeItemsTableOrderingComposer,
      $$KnowledgeItemsTableAnnotationComposer,
      $$KnowledgeItemsTableCreateCompanionBuilder,
      $$KnowledgeItemsTableUpdateCompanionBuilder,
      (KnowledgeItem, $$KnowledgeItemsTableReferences),
      KnowledgeItem,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$AudioItemsTableCreateCompanionBuilder =
    AudioItemsCompanion Function({
      required String id,
      required String kind,
      required String title,
      required String sourceUri,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<double> playbackRate,
      Value<String?> downloadedPath,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AudioItemsTableUpdateCompanionBuilder =
    AudioItemsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> title,
      Value<String> sourceUri,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<double> playbackRate,
      Value<String?> downloadedPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AudioItemsTableFilterComposer
    extends Composer<_$RiverDatabase, $AudioItemsTable> {
  $$AudioItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadedPath => $composableBuilder(
    column: $table.downloadedPath,
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

class $$AudioItemsTableOrderingComposer
    extends Composer<_$RiverDatabase, $AudioItemsTable> {
  $$AudioItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadedPath => $composableBuilder(
    column: $table.downloadedPath,
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

class $$AudioItemsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $AudioItemsTable> {
  $$AudioItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadedPath => $composableBuilder(
    column: $table.downloadedPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AudioItemsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $AudioItemsTable,
          AudioItem,
          $$AudioItemsTableFilterComposer,
          $$AudioItemsTableOrderingComposer,
          $$AudioItemsTableAnnotationComposer,
          $$AudioItemsTableCreateCompanionBuilder,
          $$AudioItemsTableUpdateCompanionBuilder,
          (
            AudioItem,
            BaseReferences<_$RiverDatabase, $AudioItemsTable, AudioItem>,
          ),
          AudioItem,
          PrefetchHooks Function()
        > {
  $$AudioItemsTableTableManager(_$RiverDatabase db, $AudioItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceUri = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<String?> downloadedPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioItemsCompanion(
                id: id,
                kind: kind,
                title: title,
                sourceUri: sourceUri,
                positionMs: positionMs,
                durationMs: durationMs,
                playbackRate: playbackRate,
                downloadedPath: downloadedPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String title,
                required String sourceUri,
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<String?> downloadedPath = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioItemsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                sourceUri: sourceUri,
                positionMs: positionMs,
                durationMs: durationMs,
                playbackRate: playbackRate,
                downloadedPath: downloadedPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $AudioItemsTable,
      AudioItem,
      $$AudioItemsTableFilterComposer,
      $$AudioItemsTableOrderingComposer,
      $$AudioItemsTableAnnotationComposer,
      $$AudioItemsTableCreateCompanionBuilder,
      $$AudioItemsTableUpdateCompanionBuilder,
      (AudioItem, BaseReferences<_$RiverDatabase, $AudioItemsTable, AudioItem>),
      AudioItem,
      PrefetchHooks Function()
    >;
typedef $$BackgroundJobsTableCreateCompanionBuilder =
    BackgroundJobsCompanion Function({
      required String id,
      required String type,
      required String idempotencyKey,
      required String payloadJson,
      Value<String> status,
      Value<int> attempt,
      Value<int> maxAttempts,
      required DateTime availableAt,
      Value<DateTime?> leaseUntil,
      Value<String?> lastErrorCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BackgroundJobsTableUpdateCompanionBuilder =
    BackgroundJobsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> idempotencyKey,
      Value<String> payloadJson,
      Value<String> status,
      Value<int> attempt,
      Value<int> maxAttempts,
      Value<DateTime> availableAt,
      Value<DateTime?> leaseUntil,
      Value<String?> lastErrorCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BackgroundJobsTableFilterComposer
    extends Composer<_$RiverDatabase, $BackgroundJobsTable> {
  $$BackgroundJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
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

class $$BackgroundJobsTableOrderingComposer
    extends Composer<_$RiverDatabase, $BackgroundJobsTable> {
  $$BackgroundJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
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

class $$BackgroundJobsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $BackgroundJobsTable> {
  $$BackgroundJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BackgroundJobsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $BackgroundJobsTable,
          BackgroundJob,
          $$BackgroundJobsTableFilterComposer,
          $$BackgroundJobsTableOrderingComposer,
          $$BackgroundJobsTableAnnotationComposer,
          $$BackgroundJobsTableCreateCompanionBuilder,
          $$BackgroundJobsTableUpdateCompanionBuilder,
          (
            BackgroundJob,
            BaseReferences<
              _$RiverDatabase,
              $BackgroundJobsTable,
              BackgroundJob
            >,
          ),
          BackgroundJob,
          PrefetchHooks Function()
        > {
  $$BackgroundJobsTableTableManager(
    _$RiverDatabase db,
    $BackgroundJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackgroundJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackgroundJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackgroundJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> maxAttempts = const Value.absent(),
                Value<DateTime> availableAt = const Value.absent(),
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackgroundJobsCompanion(
                id: id,
                type: type,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                status: status,
                attempt: attempt,
                maxAttempts: maxAttempts,
                availableAt: availableAt,
                leaseUntil: leaseUntil,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String idempotencyKey,
                required String payloadJson,
                Value<String> status = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> maxAttempts = const Value.absent(),
                required DateTime availableAt,
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BackgroundJobsCompanion.insert(
                id: id,
                type: type,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                status: status,
                attempt: attempt,
                maxAttempts: maxAttempts,
                availableAt: availableAt,
                leaseUntil: leaseUntil,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackgroundJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $BackgroundJobsTable,
      BackgroundJob,
      $$BackgroundJobsTableFilterComposer,
      $$BackgroundJobsTableOrderingComposer,
      $$BackgroundJobsTableAnnotationComposer,
      $$BackgroundJobsTableCreateCompanionBuilder,
      $$BackgroundJobsTableUpdateCompanionBuilder,
      (
        BackgroundJob,
        BaseReferences<_$RiverDatabase, $BackgroundJobsTable, BackgroundJob>,
      ),
      BackgroundJob,
      PrefetchHooks Function()
    >;
typedef $$SyncTombstonesTableCreateCompanionBuilder =
    SyncTombstonesCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required DateTime deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$SyncTombstonesTableUpdateCompanionBuilder =
    SyncTombstonesCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<DateTime> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$SyncTombstonesTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncTombstonesTable> {
  $$SyncTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncTombstonesTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncTombstonesTable> {
  $$SyncTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncTombstonesTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncTombstonesTable> {
  $$SyncTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$SyncTombstonesTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncTombstonesTable,
          SyncTombstone,
          $$SyncTombstonesTableFilterComposer,
          $$SyncTombstonesTableOrderingComposer,
          $$SyncTombstonesTableAnnotationComposer,
          $$SyncTombstonesTableCreateCompanionBuilder,
          $$SyncTombstonesTableUpdateCompanionBuilder,
          (
            SyncTombstone,
            BaseReferences<
              _$RiverDatabase,
              $SyncTombstonesTable,
              SyncTombstone
            >,
          ),
          SyncTombstone,
          PrefetchHooks Function()
        > {
  $$SyncTombstonesTableTableManager(
    _$RiverDatabase db,
    $SyncTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncTombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncTombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncTombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncTombstonesCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required DateTime deletedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => SyncTombstonesCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncTombstonesTable,
      SyncTombstone,
      $$SyncTombstonesTableFilterComposer,
      $$SyncTombstonesTableOrderingComposer,
      $$SyncTombstonesTableAnnotationComposer,
      $$SyncTombstonesTableCreateCompanionBuilder,
      $$SyncTombstonesTableUpdateCompanionBuilder,
      (
        SyncTombstone,
        BaseReferences<_$RiverDatabase, $SyncTombstonesTable, SyncTombstone>,
      ),
      SyncTombstone,
      PrefetchHooks Function()
    >;

class $RiverDatabaseManager {
  final _$RiverDatabase _db;
  $RiverDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$FeedSubscriptionsTableTableManager get feedSubscriptions =>
      $$FeedSubscriptionsTableTableManager(_db, _db.feedSubscriptions);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$ArticleContentsTableTableManager get articleContents =>
      $$ArticleContentsTableTableManager(_db, _db.articleContents);
  $$ReadingEventsTableTableManager get readingEvents =>
      $$ReadingEventsTableTableManager(_db, _db.readingEvents);
  $$KnowledgeItemsTableTableManager get knowledgeItems =>
      $$KnowledgeItemsTableTableManager(_db, _db.knowledgeItems);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db, _db.audioItems);
  $$BackgroundJobsTableTableManager get backgroundJobs =>
      $$BackgroundJobsTableTableManager(_db, _db.backgroundJobs);
  $$SyncTombstonesTableTableManager get syncTombstones =>
      $$SyncTombstonesTableTableManager(_db, _db.syncTombstones);
}
