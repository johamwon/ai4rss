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
  static const VerificationMeta _feedContentHtmlMeta = const VerificationMeta(
    'feedContentHtml',
  );
  @override
  late final GeneratedColumn<String> feedContentHtml = GeneratedColumn<String>(
    'feed_content_html',
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
    feedContentHtml,
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
    if (data.containsKey('feed_content_html')) {
      context.handle(
        _feedContentHtmlMeta,
        feedContentHtml.isAcceptableOrUnknown(
          data['feed_content_html']!,
          _feedContentHtmlMeta,
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
      feedContentHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_content_html'],
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
  final String? feedContentHtml;
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
    this.feedContentHtml,
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
    if (!nullToAbsent || feedContentHtml != null) {
      map['feed_content_html'] = Variable<String>(feedContentHtml);
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
      feedContentHtml: feedContentHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(feedContentHtml),
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
      feedContentHtml: serializer.fromJson<String?>(json['feedContentHtml']),
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
      'feedContentHtml': serializer.toJson<String?>(feedContentHtml),
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
    Value<String?> feedContentHtml = const Value.absent(),
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
    feedContentHtml: feedContentHtml.present
        ? feedContentHtml.value
        : this.feedContentHtml,
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
      feedContentHtml: data.feedContentHtml.present
          ? data.feedContentHtml.value
          : this.feedContentHtml,
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
          ..write('feedContentHtml: $feedContentHtml, ')
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
    feedContentHtml,
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
          other.feedContentHtml == this.feedContentHtml &&
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
  final Value<String?> feedContentHtml;
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
    this.feedContentHtml = const Value.absent(),
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
    this.feedContentHtml = const Value.absent(),
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
    Expression<String>? feedContentHtml,
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
      if (feedContentHtml != null) 'feed_content_html': feedContentHtml,
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
    Value<String?>? feedContentHtml,
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
      feedContentHtml: feedContentHtml ?? this.feedContentHtml,
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
    if (feedContentHtml.present) {
      map['feed_content_html'] = Variable<String>(feedContentHtml.value);
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
          ..write('feedContentHtml: $feedContentHtml, ')
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

class $ReaderSettingsRowsTable extends ReaderSettingsRows
    with TableInfo<$ReaderSettingsRowsTable, ReaderSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderSettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fontFamilyMeta = const VerificationMeta(
    'fontFamily',
  );
  @override
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
    'font_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _fontScaleMeta = const VerificationMeta(
    'fontScale',
  );
  @override
  late final GeneratedColumn<double> fontScale = GeneratedColumn<double>(
    'font_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lineHeightMeta = const VerificationMeta(
    'lineHeight',
  );
  @override
  late final GeneratedColumn<double> lineHeight = GeneratedColumn<double>(
    'line_height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.75),
  );
  static const VerificationMeta _contentWidthMeta = const VerificationMeta(
    'contentWidth',
  );
  @override
  late final GeneratedColumn<double> contentWidth = GeneratedColumn<double>(
    'content_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(760),
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
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
    fontFamily,
    fontScale,
    lineHeight,
    contentWidth,
    theme,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_settings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('font_family')) {
      context.handle(
        _fontFamilyMeta,
        fontFamily.isAcceptableOrUnknown(data['font_family']!, _fontFamilyMeta),
      );
    }
    if (data.containsKey('font_scale')) {
      context.handle(
        _fontScaleMeta,
        fontScale.isAcceptableOrUnknown(data['font_scale']!, _fontScaleMeta),
      );
    }
    if (data.containsKey('line_height')) {
      context.handle(
        _lineHeightMeta,
        lineHeight.isAcceptableOrUnknown(data['line_height']!, _lineHeightMeta),
      );
    }
    if (data.containsKey('content_width')) {
      context.handle(
        _contentWidthMeta,
        contentWidth.isAcceptableOrUnknown(
          data['content_width']!,
          _contentWidthMeta,
        ),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
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
  ReaderSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_family'],
      )!,
      fontScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_scale'],
      )!,
      lineHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}line_height'],
      )!,
      contentWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}content_width'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReaderSettingsRowsTable createAlias(String alias) {
    return $ReaderSettingsRowsTable(attachedDatabase, alias);
  }
}

class ReaderSettingsRow extends DataClass
    implements Insertable<ReaderSettingsRow> {
  final String id;
  final String fontFamily;
  final double fontScale;
  final double lineHeight;
  final double contentWidth;
  final String theme;
  final DateTime updatedAt;
  const ReaderSettingsRow({
    required this.id,
    required this.fontFamily,
    required this.fontScale,
    required this.lineHeight,
    required this.contentWidth,
    required this.theme,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['font_family'] = Variable<String>(fontFamily);
    map['font_scale'] = Variable<double>(fontScale);
    map['line_height'] = Variable<double>(lineHeight);
    map['content_width'] = Variable<double>(contentWidth);
    map['theme'] = Variable<String>(theme);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReaderSettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return ReaderSettingsRowsCompanion(
      id: Value(id),
      fontFamily: Value(fontFamily),
      fontScale: Value(fontScale),
      lineHeight: Value(lineHeight),
      contentWidth: Value(contentWidth),
      theme: Value(theme),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReaderSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderSettingsRow(
      id: serializer.fromJson<String>(json['id']),
      fontFamily: serializer.fromJson<String>(json['fontFamily']),
      fontScale: serializer.fromJson<double>(json['fontScale']),
      lineHeight: serializer.fromJson<double>(json['lineHeight']),
      contentWidth: serializer.fromJson<double>(json['contentWidth']),
      theme: serializer.fromJson<String>(json['theme']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fontFamily': serializer.toJson<String>(fontFamily),
      'fontScale': serializer.toJson<double>(fontScale),
      'lineHeight': serializer.toJson<double>(lineHeight),
      'contentWidth': serializer.toJson<double>(contentWidth),
      'theme': serializer.toJson<String>(theme),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReaderSettingsRow copyWith({
    String? id,
    String? fontFamily,
    double? fontScale,
    double? lineHeight,
    double? contentWidth,
    String? theme,
    DateTime? updatedAt,
  }) => ReaderSettingsRow(
    id: id ?? this.id,
    fontFamily: fontFamily ?? this.fontFamily,
    fontScale: fontScale ?? this.fontScale,
    lineHeight: lineHeight ?? this.lineHeight,
    contentWidth: contentWidth ?? this.contentWidth,
    theme: theme ?? this.theme,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReaderSettingsRow copyWithCompanion(ReaderSettingsRowsCompanion data) {
    return ReaderSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      fontFamily: data.fontFamily.present
          ? data.fontFamily.value
          : this.fontFamily,
      fontScale: data.fontScale.present ? data.fontScale.value : this.fontScale,
      lineHeight: data.lineHeight.present
          ? data.lineHeight.value
          : this.lineHeight,
      contentWidth: data.contentWidth.present
          ? data.contentWidth.value
          : this.contentWidth,
      theme: data.theme.present ? data.theme.value : this.theme,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderSettingsRow(')
          ..write('id: $id, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontScale: $fontScale, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('contentWidth: $contentWidth, ')
          ..write('theme: $theme, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fontFamily,
    fontScale,
    lineHeight,
    contentWidth,
    theme,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderSettingsRow &&
          other.id == this.id &&
          other.fontFamily == this.fontFamily &&
          other.fontScale == this.fontScale &&
          other.lineHeight == this.lineHeight &&
          other.contentWidth == this.contentWidth &&
          other.theme == this.theme &&
          other.updatedAt == this.updatedAt);
}

class ReaderSettingsRowsCompanion extends UpdateCompanion<ReaderSettingsRow> {
  final Value<String> id;
  final Value<String> fontFamily;
  final Value<double> fontScale;
  final Value<double> lineHeight;
  final Value<double> contentWidth;
  final Value<String> theme;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReaderSettingsRowsCompanion({
    this.id = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.lineHeight = const Value.absent(),
    this.contentWidth = const Value.absent(),
    this.theme = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderSettingsRowsCompanion.insert({
    required String id,
    this.fontFamily = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.lineHeight = const Value.absent(),
    this.contentWidth = const Value.absent(),
    this.theme = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<ReaderSettingsRow> custom({
    Expression<String>? id,
    Expression<String>? fontFamily,
    Expression<double>? fontScale,
    Expression<double>? lineHeight,
    Expression<double>? contentWidth,
    Expression<String>? theme,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fontFamily != null) 'font_family': fontFamily,
      if (fontScale != null) 'font_scale': fontScale,
      if (lineHeight != null) 'line_height': lineHeight,
      if (contentWidth != null) 'content_width': contentWidth,
      if (theme != null) 'theme': theme,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderSettingsRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? fontFamily,
    Value<double>? fontScale,
    Value<double>? lineHeight,
    Value<double>? contentWidth,
    Value<String>? theme,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReaderSettingsRowsCompanion(
      id: id ?? this.id,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      lineHeight: lineHeight ?? this.lineHeight,
      contentWidth: contentWidth ?? this.contentWidth,
      theme: theme ?? this.theme,
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
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (fontScale.present) {
      map['font_scale'] = Variable<double>(fontScale.value);
    }
    if (lineHeight.present) {
      map['line_height'] = Variable<double>(lineHeight.value);
    }
    if (contentWidth.present) {
      map['content_width'] = Variable<double>(contentWidth.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
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
    return (StringBuffer('ReaderSettingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontScale: $fontScale, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('contentWidth: $contentWidth, ')
          ..write('theme: $theme, ')
          ..write('updatedAt: $updatedAt, ')
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
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _characterOffsetMeta = const VerificationMeta(
    'characterOffset',
  );
  @override
  late final GeneratedColumn<int> characterOffset = GeneratedColumn<int>(
    'character_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentRevisionMeta = const VerificationMeta(
    'contentRevision',
  );
  @override
  late final GeneratedColumn<String> contentRevision = GeneratedColumn<String>(
    'content_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _pitchMeta = const VerificationMeta('pitch');
  @override
  late final GeneratedColumn<double> pitch = GeneratedColumn<double>(
    'pitch',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _voiceIdMeta = const VerificationMeta(
    'voiceId',
  );
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
    'voice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageTagMeta = const VerificationMeta(
    'languageTag',
  );
  @override
  late final GeneratedColumn<String> languageTag = GeneratedColumn<String>(
    'language_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    segmentIndex,
    characterOffset,
    contentRevision,
    durationMs,
    playbackRate,
    pitch,
    voiceId,
    languageTag,
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
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    }
    if (data.containsKey('character_offset')) {
      context.handle(
        _characterOffsetMeta,
        characterOffset.isAcceptableOrUnknown(
          data['character_offset']!,
          _characterOffsetMeta,
        ),
      );
    }
    if (data.containsKey('content_revision')) {
      context.handle(
        _contentRevisionMeta,
        contentRevision.isAcceptableOrUnknown(
          data['content_revision']!,
          _contentRevisionMeta,
        ),
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
    if (data.containsKey('pitch')) {
      context.handle(
        _pitchMeta,
        pitch.isAcceptableOrUnknown(data['pitch']!, _pitchMeta),
      );
    }
    if (data.containsKey('voice_id')) {
      context.handle(
        _voiceIdMeta,
        voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta),
      );
    }
    if (data.containsKey('language_tag')) {
      context.handle(
        _languageTagMeta,
        languageTag.isAcceptableOrUnknown(
          data['language_tag']!,
          _languageTagMeta,
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
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      ),
      characterOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_offset'],
      ),
      contentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_revision'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      playbackRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}playback_rate'],
      )!,
      pitch: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pitch'],
      )!,
      voiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_id'],
      ),
      languageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_tag'],
      ),
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
  final int? segmentIndex;
  final int? characterOffset;
  final String? contentRevision;
  final int? durationMs;
  final double playbackRate;
  final double pitch;
  final String? voiceId;
  final String? languageTag;
  final String? downloadedPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AudioItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUri,
    required this.positionMs,
    this.segmentIndex,
    this.characterOffset,
    this.contentRevision,
    this.durationMs,
    required this.playbackRate,
    required this.pitch,
    this.voiceId,
    this.languageTag,
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
    if (!nullToAbsent || segmentIndex != null) {
      map['segment_index'] = Variable<int>(segmentIndex);
    }
    if (!nullToAbsent || characterOffset != null) {
      map['character_offset'] = Variable<int>(characterOffset);
    }
    if (!nullToAbsent || contentRevision != null) {
      map['content_revision'] = Variable<String>(contentRevision);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['playback_rate'] = Variable<double>(playbackRate);
    map['pitch'] = Variable<double>(pitch);
    if (!nullToAbsent || voiceId != null) {
      map['voice_id'] = Variable<String>(voiceId);
    }
    if (!nullToAbsent || languageTag != null) {
      map['language_tag'] = Variable<String>(languageTag);
    }
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
      segmentIndex: segmentIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentIndex),
      characterOffset: characterOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(characterOffset),
      contentRevision: contentRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(contentRevision),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      playbackRate: Value(playbackRate),
      pitch: Value(pitch),
      voiceId: voiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceId),
      languageTag: languageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(languageTag),
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
      segmentIndex: serializer.fromJson<int?>(json['segmentIndex']),
      characterOffset: serializer.fromJson<int?>(json['characterOffset']),
      contentRevision: serializer.fromJson<String?>(json['contentRevision']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      playbackRate: serializer.fromJson<double>(json['playbackRate']),
      pitch: serializer.fromJson<double>(json['pitch']),
      voiceId: serializer.fromJson<String?>(json['voiceId']),
      languageTag: serializer.fromJson<String?>(json['languageTag']),
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
      'segmentIndex': serializer.toJson<int?>(segmentIndex),
      'characterOffset': serializer.toJson<int?>(characterOffset),
      'contentRevision': serializer.toJson<String?>(contentRevision),
      'durationMs': serializer.toJson<int?>(durationMs),
      'playbackRate': serializer.toJson<double>(playbackRate),
      'pitch': serializer.toJson<double>(pitch),
      'voiceId': serializer.toJson<String?>(voiceId),
      'languageTag': serializer.toJson<String?>(languageTag),
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
    Value<int?> segmentIndex = const Value.absent(),
    Value<int?> characterOffset = const Value.absent(),
    Value<String?> contentRevision = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    double? playbackRate,
    double? pitch,
    Value<String?> voiceId = const Value.absent(),
    Value<String?> languageTag = const Value.absent(),
    Value<String?> downloadedPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AudioItem(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    sourceUri: sourceUri ?? this.sourceUri,
    positionMs: positionMs ?? this.positionMs,
    segmentIndex: segmentIndex.present ? segmentIndex.value : this.segmentIndex,
    characterOffset: characterOffset.present
        ? characterOffset.value
        : this.characterOffset,
    contentRevision: contentRevision.present
        ? contentRevision.value
        : this.contentRevision,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    playbackRate: playbackRate ?? this.playbackRate,
    pitch: pitch ?? this.pitch,
    voiceId: voiceId.present ? voiceId.value : this.voiceId,
    languageTag: languageTag.present ? languageTag.value : this.languageTag,
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
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      characterOffset: data.characterOffset.present
          ? data.characterOffset.value
          : this.characterOffset,
      contentRevision: data.contentRevision.present
          ? data.contentRevision.value
          : this.contentRevision,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      playbackRate: data.playbackRate.present
          ? data.playbackRate.value
          : this.playbackRate,
      pitch: data.pitch.present ? data.pitch.value : this.pitch,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      languageTag: data.languageTag.present
          ? data.languageTag.value
          : this.languageTag,
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
          ..write('segmentIndex: $segmentIndex, ')
          ..write('characterOffset: $characterOffset, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('pitch: $pitch, ')
          ..write('voiceId: $voiceId, ')
          ..write('languageTag: $languageTag, ')
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
    segmentIndex,
    characterOffset,
    contentRevision,
    durationMs,
    playbackRate,
    pitch,
    voiceId,
    languageTag,
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
          other.segmentIndex == this.segmentIndex &&
          other.characterOffset == this.characterOffset &&
          other.contentRevision == this.contentRevision &&
          other.durationMs == this.durationMs &&
          other.playbackRate == this.playbackRate &&
          other.pitch == this.pitch &&
          other.voiceId == this.voiceId &&
          other.languageTag == this.languageTag &&
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
  final Value<int?> segmentIndex;
  final Value<int?> characterOffset;
  final Value<String?> contentRevision;
  final Value<int?> durationMs;
  final Value<double> playbackRate;
  final Value<double> pitch;
  final Value<String?> voiceId;
  final Value<String?> languageTag;
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
    this.segmentIndex = const Value.absent(),
    this.characterOffset = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.pitch = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.languageTag = const Value.absent(),
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
    this.segmentIndex = const Value.absent(),
    this.characterOffset = const Value.absent(),
    this.contentRevision = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.pitch = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.languageTag = const Value.absent(),
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
    Expression<int>? segmentIndex,
    Expression<int>? characterOffset,
    Expression<String>? contentRevision,
    Expression<int>? durationMs,
    Expression<double>? playbackRate,
    Expression<double>? pitch,
    Expression<String>? voiceId,
    Expression<String>? languageTag,
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
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (characterOffset != null) 'character_offset': characterOffset,
      if (contentRevision != null) 'content_revision': contentRevision,
      if (durationMs != null) 'duration_ms': durationMs,
      if (playbackRate != null) 'playback_rate': playbackRate,
      if (pitch != null) 'pitch': pitch,
      if (voiceId != null) 'voice_id': voiceId,
      if (languageTag != null) 'language_tag': languageTag,
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
    Value<int?>? segmentIndex,
    Value<int?>? characterOffset,
    Value<String?>? contentRevision,
    Value<int?>? durationMs,
    Value<double>? playbackRate,
    Value<double>? pitch,
    Value<String?>? voiceId,
    Value<String?>? languageTag,
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
      segmentIndex: segmentIndex ?? this.segmentIndex,
      characterOffset: characterOffset ?? this.characterOffset,
      contentRevision: contentRevision ?? this.contentRevision,
      durationMs: durationMs ?? this.durationMs,
      playbackRate: playbackRate ?? this.playbackRate,
      pitch: pitch ?? this.pitch,
      voiceId: voiceId ?? this.voiceId,
      languageTag: languageTag ?? this.languageTag,
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
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (characterOffset.present) {
      map['character_offset'] = Variable<int>(characterOffset.value);
    }
    if (contentRevision.present) {
      map['content_revision'] = Variable<String>(contentRevision.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (playbackRate.present) {
      map['playback_rate'] = Variable<double>(playbackRate.value);
    }
    if (pitch.present) {
      map['pitch'] = Variable<double>(pitch.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (languageTag.present) {
      map['language_tag'] = Variable<String>(languageTag.value);
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
          ..write('segmentIndex: $segmentIndex, ')
          ..write('characterOffset: $characterOffset, ')
          ..write('contentRevision: $contentRevision, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('pitch: $pitch, ')
          ..write('voiceId: $voiceId, ')
          ..write('languageTag: $languageTag, ')
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

class $SyncReplicaEntriesTable extends SyncReplicaEntries
    with TableInfo<$SyncReplicaEntriesTable, SyncReplicaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncReplicaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectKindMeta = const VerificationMeta(
    'objectKind',
  );
  @override
  late final GeneratedColumn<String> objectKind = GeneratedColumn<String>(
    'object_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectIdMeta = const VerificationMeta(
    'objectId',
  );
  @override
  late final GeneratedColumn<String> objectId = GeneratedColumn<String>(
    'object_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clearPayloadJsonMeta = const VerificationMeta(
    'clearPayloadJson',
  );
  @override
  late final GeneratedColumn<String> clearPayloadJson = GeneratedColumn<String>(
    'clear_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    accountId,
    objectKind,
    objectId,
    envelopeJson,
    clearPayloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_replica_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncReplicaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('object_kind')) {
      context.handle(
        _objectKindMeta,
        objectKind.isAcceptableOrUnknown(data['object_kind']!, _objectKindMeta),
      );
    } else if (isInserting) {
      context.missing(_objectKindMeta);
    }
    if (data.containsKey('object_id')) {
      context.handle(
        _objectIdMeta,
        objectId.isAcceptableOrUnknown(data['object_id']!, _objectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_objectIdMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('clear_payload_json')) {
      context.handle(
        _clearPayloadJsonMeta,
        clearPayloadJson.isAcceptableOrUnknown(
          data['clear_payload_json']!,
          _clearPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clearPayloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {accountId, objectKind, objectId};
  @override
  SyncReplicaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncReplicaEntry(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      objectKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_kind'],
      )!,
      objectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_id'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      clearPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clear_payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncReplicaEntriesTable createAlias(String alias) {
    return $SyncReplicaEntriesTable(attachedDatabase, alias);
  }
}

class SyncReplicaEntry extends DataClass
    implements Insertable<SyncReplicaEntry> {
  final String accountId;
  final String objectKind;
  final String objectId;
  final String envelopeJson;
  final String clearPayloadJson;
  final DateTime updatedAt;
  const SyncReplicaEntry({
    required this.accountId,
    required this.objectKind,
    required this.objectId,
    required this.envelopeJson,
    required this.clearPayloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['object_kind'] = Variable<String>(objectKind);
    map['object_id'] = Variable<String>(objectId);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['clear_payload_json'] = Variable<String>(clearPayloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncReplicaEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncReplicaEntriesCompanion(
      accountId: Value(accountId),
      objectKind: Value(objectKind),
      objectId: Value(objectId),
      envelopeJson: Value(envelopeJson),
      clearPayloadJson: Value(clearPayloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncReplicaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncReplicaEntry(
      accountId: serializer.fromJson<String>(json['accountId']),
      objectKind: serializer.fromJson<String>(json['objectKind']),
      objectId: serializer.fromJson<String>(json['objectId']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      clearPayloadJson: serializer.fromJson<String>(json['clearPayloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'objectKind': serializer.toJson<String>(objectKind),
      'objectId': serializer.toJson<String>(objectId),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'clearPayloadJson': serializer.toJson<String>(clearPayloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncReplicaEntry copyWith({
    String? accountId,
    String? objectKind,
    String? objectId,
    String? envelopeJson,
    String? clearPayloadJson,
    DateTime? updatedAt,
  }) => SyncReplicaEntry(
    accountId: accountId ?? this.accountId,
    objectKind: objectKind ?? this.objectKind,
    objectId: objectId ?? this.objectId,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    clearPayloadJson: clearPayloadJson ?? this.clearPayloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncReplicaEntry copyWithCompanion(SyncReplicaEntriesCompanion data) {
    return SyncReplicaEntry(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      objectKind: data.objectKind.present
          ? data.objectKind.value
          : this.objectKind,
      objectId: data.objectId.present ? data.objectId.value : this.objectId,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      clearPayloadJson: data.clearPayloadJson.present
          ? data.clearPayloadJson.value
          : this.clearPayloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncReplicaEntry(')
          ..write('accountId: $accountId, ')
          ..write('objectKind: $objectKind, ')
          ..write('objectId: $objectId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('clearPayloadJson: $clearPayloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    objectKind,
    objectId,
    envelopeJson,
    clearPayloadJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncReplicaEntry &&
          other.accountId == this.accountId &&
          other.objectKind == this.objectKind &&
          other.objectId == this.objectId &&
          other.envelopeJson == this.envelopeJson &&
          other.clearPayloadJson == this.clearPayloadJson &&
          other.updatedAt == this.updatedAt);
}

class SyncReplicaEntriesCompanion extends UpdateCompanion<SyncReplicaEntry> {
  final Value<String> accountId;
  final Value<String> objectKind;
  final Value<String> objectId;
  final Value<String> envelopeJson;
  final Value<String> clearPayloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncReplicaEntriesCompanion({
    this.accountId = const Value.absent(),
    this.objectKind = const Value.absent(),
    this.objectId = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.clearPayloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncReplicaEntriesCompanion.insert({
    required String accountId,
    required String objectKind,
    required String objectId,
    required String envelopeJson,
    required String clearPayloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       objectKind = Value(objectKind),
       objectId = Value(objectId),
       envelopeJson = Value(envelopeJson),
       clearPayloadJson = Value(clearPayloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<SyncReplicaEntry> custom({
    Expression<String>? accountId,
    Expression<String>? objectKind,
    Expression<String>? objectId,
    Expression<String>? envelopeJson,
    Expression<String>? clearPayloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (objectKind != null) 'object_kind': objectKind,
      if (objectId != null) 'object_id': objectId,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (clearPayloadJson != null) 'clear_payload_json': clearPayloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncReplicaEntriesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? objectKind,
    Value<String>? objectId,
    Value<String>? envelopeJson,
    Value<String>? clearPayloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncReplicaEntriesCompanion(
      accountId: accountId ?? this.accountId,
      objectKind: objectKind ?? this.objectKind,
      objectId: objectId ?? this.objectId,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      clearPayloadJson: clearPayloadJson ?? this.clearPayloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (objectKind.present) {
      map['object_kind'] = Variable<String>(objectKind.value);
    }
    if (objectId.present) {
      map['object_id'] = Variable<String>(objectId.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (clearPayloadJson.present) {
      map['clear_payload_json'] = Variable<String>(clearPayloadJson.value);
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
    return (StringBuffer('SyncReplicaEntriesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('objectKind: $objectKind, ')
          ..write('objectId: $objectId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('clearPayloadJson: $clearPayloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxRowsTable extends SyncOutboxRows
    with TableInfo<$SyncOutboxRowsTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    accountId,
    deviceId,
    envelopeJson,
    queuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
    );
  }

  @override
  $SyncOutboxRowsTable createAlias(String alias) {
    return $SyncOutboxRowsTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  final String mutationId;
  final String accountId;
  final String deviceId;
  final String envelopeJson;
  final DateTime queuedAt;
  const SyncOutboxRow({
    required this.mutationId,
    required this.accountId,
    required this.deviceId,
    required this.envelopeJson,
    required this.queuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['account_id'] = Variable<String>(accountId);
    map['device_id'] = Variable<String>(deviceId);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    return map;
  }

  SyncOutboxRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxRowsCompanion(
      mutationId: Value(mutationId),
      accountId: Value(accountId),
      deviceId: Value(deviceId),
      envelopeJson: Value(envelopeJson),
      queuedAt: Value(queuedAt),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'accountId': serializer.toJson<String>(accountId),
      'deviceId': serializer.toJson<String>(deviceId),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
    };
  }

  SyncOutboxRow copyWith({
    String? mutationId,
    String? accountId,
    String? deviceId,
    String? envelopeJson,
    DateTime? queuedAt,
  }) => SyncOutboxRow(
    mutationId: mutationId ?? this.mutationId,
    accountId: accountId ?? this.accountId,
    deviceId: deviceId ?? this.deviceId,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    queuedAt: queuedAt ?? this.queuedAt,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxRowsCompanion data) {
    return SyncOutboxRow(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('deviceId: $deviceId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mutationId, accountId, deviceId, envelopeJson, queuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.mutationId == this.mutationId &&
          other.accountId == this.accountId &&
          other.deviceId == this.deviceId &&
          other.envelopeJson == this.envelopeJson &&
          other.queuedAt == this.queuedAt);
}

class SyncOutboxRowsCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<String> mutationId;
  final Value<String> accountId;
  final Value<String> deviceId;
  final Value<String> envelopeJson;
  final Value<DateTime> queuedAt;
  final Value<int> rowid;
  const SyncOutboxRowsCompanion({
    this.mutationId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxRowsCompanion.insert({
    required String mutationId,
    required String accountId,
    required String deviceId,
    required String envelopeJson,
    required DateTime queuedAt,
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       accountId = Value(accountId),
       deviceId = Value(deviceId),
       envelopeJson = Value(envelopeJson),
       queuedAt = Value(queuedAt);
  static Insertable<SyncOutboxRow> custom({
    Expression<String>? mutationId,
    Expression<String>? accountId,
    Expression<String>? deviceId,
    Expression<String>? envelopeJson,
    Expression<DateTime>? queuedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (accountId != null) 'account_id': accountId,
      if (deviceId != null) 'device_id': deviceId,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxRowsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? accountId,
    Value<String>? deviceId,
    Value<String>? envelopeJson,
    Value<DateTime>? queuedAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxRowsCompanion(
      mutationId: mutationId ?? this.mutationId,
      accountId: accountId ?? this.accountId,
      deviceId: deviceId ?? this.deviceId,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      queuedAt: queuedAt ?? this.queuedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRowsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('deviceId: $deviceId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorRowsTable extends SyncCursorRows
    with TableInfo<$SyncCursorRowsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
    'protocol_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSequenceMeta = const VerificationMeta(
    'serverSequence',
  );
  @override
  late final GeneratedColumn<int> serverSequence = GeneratedColumn<int>(
    'server_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opaqueTokenMeta = const VerificationMeta(
    'opaqueToken',
  );
  @override
  late final GeneratedColumn<String> opaqueToken = GeneratedColumn<String>(
    'opaque_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    accountId,
    deviceId,
    protocolVersion,
    serverSequence,
    opaqueToken,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursor_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_protocolVersionMeta);
    }
    if (data.containsKey('server_sequence')) {
      context.handle(
        _serverSequenceMeta,
        serverSequence.isAcceptableOrUnknown(
          data['server_sequence']!,
          _serverSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverSequenceMeta);
    }
    if (data.containsKey('opaque_token')) {
      context.handle(
        _opaqueTokenMeta,
        opaqueToken.isAcceptableOrUnknown(
          data['opaque_token']!,
          _opaqueTokenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_opaqueTokenMeta);
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
  Set<GeneratedColumn> get $primaryKey => {accountId, deviceId};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol_version'],
      )!,
      serverSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_sequence'],
      )!,
      opaqueToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opaque_token'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncCursorRowsTable createAlias(String alias) {
    return $SyncCursorRowsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  final String accountId;
  final String deviceId;
  final int protocolVersion;
  final int serverSequence;
  final String opaqueToken;
  final DateTime updatedAt;
  const SyncCursorRow({
    required this.accountId,
    required this.deviceId,
    required this.protocolVersion,
    required this.serverSequence,
    required this.opaqueToken,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['device_id'] = Variable<String>(deviceId);
    map['protocol_version'] = Variable<int>(protocolVersion);
    map['server_sequence'] = Variable<int>(serverSequence);
    map['opaque_token'] = Variable<String>(opaqueToken);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncCursorRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorRowsCompanion(
      accountId: Value(accountId),
      deviceId: Value(deviceId),
      protocolVersion: Value(protocolVersion),
      serverSequence: Value(serverSequence),
      opaqueToken: Value(opaqueToken),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      serverSequence: serializer.fromJson<int>(json['serverSequence']),
      opaqueToken: serializer.fromJson<String>(json['opaqueToken']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'deviceId': serializer.toJson<String>(deviceId),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'serverSequence': serializer.toJson<int>(serverSequence),
      'opaqueToken': serializer.toJson<String>(opaqueToken),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncCursorRow copyWith({
    String? accountId,
    String? deviceId,
    int? protocolVersion,
    int? serverSequence,
    String? opaqueToken,
    DateTime? updatedAt,
  }) => SyncCursorRow(
    accountId: accountId ?? this.accountId,
    deviceId: deviceId ?? this.deviceId,
    protocolVersion: protocolVersion ?? this.protocolVersion,
    serverSequence: serverSequence ?? this.serverSequence,
    opaqueToken: opaqueToken ?? this.opaqueToken,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncCursorRow copyWithCompanion(SyncCursorRowsCompanion data) {
    return SyncCursorRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      serverSequence: data.serverSequence.present
          ? data.serverSequence.value
          : this.serverSequence,
      opaqueToken: data.opaqueToken.present
          ? data.opaqueToken.value
          : this.opaqueToken,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('accountId: $accountId, ')
          ..write('deviceId: $deviceId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('opaqueToken: $opaqueToken, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    deviceId,
    protocolVersion,
    serverSequence,
    opaqueToken,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.accountId == this.accountId &&
          other.deviceId == this.deviceId &&
          other.protocolVersion == this.protocolVersion &&
          other.serverSequence == this.serverSequence &&
          other.opaqueToken == this.opaqueToken &&
          other.updatedAt == this.updatedAt);
}

class SyncCursorRowsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> accountId;
  final Value<String> deviceId;
  final Value<int> protocolVersion;
  final Value<int> serverSequence;
  final Value<String> opaqueToken;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncCursorRowsCompanion({
    this.accountId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.serverSequence = const Value.absent(),
    this.opaqueToken = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorRowsCompanion.insert({
    required String accountId,
    required String deviceId,
    required int protocolVersion,
    required int serverSequence,
    required String opaqueToken,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       deviceId = Value(deviceId),
       protocolVersion = Value(protocolVersion),
       serverSequence = Value(serverSequence),
       opaqueToken = Value(opaqueToken),
       updatedAt = Value(updatedAt);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? accountId,
    Expression<String>? deviceId,
    Expression<int>? protocolVersion,
    Expression<int>? serverSequence,
    Expression<String>? opaqueToken,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (deviceId != null) 'device_id': deviceId,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (serverSequence != null) 'server_sequence': serverSequence,
      if (opaqueToken != null) 'opaque_token': opaqueToken,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorRowsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? deviceId,
    Value<int>? protocolVersion,
    Value<int>? serverSequence,
    Value<String>? opaqueToken,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncCursorRowsCompanion(
      accountId: accountId ?? this.accountId,
      deviceId: deviceId ?? this.deviceId,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      serverSequence: serverSequence ?? this.serverSequence,
      opaqueToken: opaqueToken ?? this.opaqueToken,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (serverSequence.present) {
      map['server_sequence'] = Variable<int>(serverSequence.value);
    }
    if (opaqueToken.present) {
      map['opaque_token'] = Variable<String>(opaqueToken.value);
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
    return (StringBuffer('SyncCursorRowsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('deviceId: $deviceId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('opaqueToken: $opaqueToken, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictRowsTable extends SyncConflictRows
    with TableInfo<$SyncConflictRowsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectKindMeta = const VerificationMeta(
    'objectKind',
  );
  @override
  late final GeneratedColumn<String> objectKind = GeneratedColumn<String>(
    'object_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectIdMeta = const VerificationMeta(
    'objectId',
  );
  @override
  late final GeneratedColumn<String> objectId = GeneratedColumn<String>(
    'object_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clearPayloadJsonMeta = const VerificationMeta(
    'clearPayloadJson',
  );
  @override
  late final GeneratedColumn<String> clearPayloadJson = GeneratedColumn<String>(
    'clear_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionKindMeta = const VerificationMeta(
    'resolutionKind',
  );
  @override
  late final GeneratedColumn<String> resolutionKind = GeneratedColumn<String>(
    'resolution_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unresolved'),
  );
  static const VerificationMeta _resolutionMutationIdMeta =
      const VerificationMeta('resolutionMutationId');
  @override
  late final GeneratedColumn<String> resolutionMutationId =
      GeneratedColumn<String>(
        'resolution_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    accountId,
    objectKind,
    objectId,
    envelopeJson,
    clearPayloadJson,
    detectedAt,
    resolutionKind,
    resolutionMutationId,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflict_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('object_kind')) {
      context.handle(
        _objectKindMeta,
        objectKind.isAcceptableOrUnknown(data['object_kind']!, _objectKindMeta),
      );
    } else if (isInserting) {
      context.missing(_objectKindMeta);
    }
    if (data.containsKey('object_id')) {
      context.handle(
        _objectIdMeta,
        objectId.isAcceptableOrUnknown(data['object_id']!, _objectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_objectIdMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('clear_payload_json')) {
      context.handle(
        _clearPayloadJsonMeta,
        clearPayloadJson.isAcceptableOrUnknown(
          data['clear_payload_json']!,
          _clearPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clearPayloadJsonMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('resolution_kind')) {
      context.handle(
        _resolutionKindMeta,
        resolutionKind.isAcceptableOrUnknown(
          data['resolution_kind']!,
          _resolutionKindMeta,
        ),
      );
    }
    if (data.containsKey('resolution_mutation_id')) {
      context.handle(
        _resolutionMutationIdMeta,
        resolutionMutationId.isAcceptableOrUnknown(
          data['resolution_mutation_id']!,
          _resolutionMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      objectKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_kind'],
      )!,
      objectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_id'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      clearPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clear_payload_json'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
      resolutionKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_kind'],
      )!,
      resolutionMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_mutation_id'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $SyncConflictRowsTable createAlias(String alias) {
    return $SyncConflictRowsTable(attachedDatabase, alias);
  }
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final String mutationId;
  final String accountId;
  final String objectKind;
  final String objectId;
  final String envelopeJson;
  final String clearPayloadJson;
  final DateTime detectedAt;
  final String resolutionKind;
  final String? resolutionMutationId;
  final DateTime? resolvedAt;
  const SyncConflictRow({
    required this.mutationId,
    required this.accountId,
    required this.objectKind,
    required this.objectId,
    required this.envelopeJson,
    required this.clearPayloadJson,
    required this.detectedAt,
    required this.resolutionKind,
    this.resolutionMutationId,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['account_id'] = Variable<String>(accountId);
    map['object_kind'] = Variable<String>(objectKind);
    map['object_id'] = Variable<String>(objectId);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['clear_payload_json'] = Variable<String>(clearPayloadJson);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['resolution_kind'] = Variable<String>(resolutionKind);
    if (!nullToAbsent || resolutionMutationId != null) {
      map['resolution_mutation_id'] = Variable<String>(resolutionMutationId);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncConflictRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictRowsCompanion(
      mutationId: Value(mutationId),
      accountId: Value(accountId),
      objectKind: Value(objectKind),
      objectId: Value(objectId),
      envelopeJson: Value(envelopeJson),
      clearPayloadJson: Value(clearPayloadJson),
      detectedAt: Value(detectedAt),
      resolutionKind: Value(resolutionKind),
      resolutionMutationId: resolutionMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionMutationId),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      objectKind: serializer.fromJson<String>(json['objectKind']),
      objectId: serializer.fromJson<String>(json['objectId']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      clearPayloadJson: serializer.fromJson<String>(json['clearPayloadJson']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      resolutionKind: serializer.fromJson<String>(json['resolutionKind']),
      resolutionMutationId: serializer.fromJson<String?>(
        json['resolutionMutationId'],
      ),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'accountId': serializer.toJson<String>(accountId),
      'objectKind': serializer.toJson<String>(objectKind),
      'objectId': serializer.toJson<String>(objectId),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'clearPayloadJson': serializer.toJson<String>(clearPayloadJson),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'resolutionKind': serializer.toJson<String>(resolutionKind),
      'resolutionMutationId': serializer.toJson<String?>(resolutionMutationId),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncConflictRow copyWith({
    String? mutationId,
    String? accountId,
    String? objectKind,
    String? objectId,
    String? envelopeJson,
    String? clearPayloadJson,
    DateTime? detectedAt,
    String? resolutionKind,
    Value<String?> resolutionMutationId = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => SyncConflictRow(
    mutationId: mutationId ?? this.mutationId,
    accountId: accountId ?? this.accountId,
    objectKind: objectKind ?? this.objectKind,
    objectId: objectId ?? this.objectId,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    clearPayloadJson: clearPayloadJson ?? this.clearPayloadJson,
    detectedAt: detectedAt ?? this.detectedAt,
    resolutionKind: resolutionKind ?? this.resolutionKind,
    resolutionMutationId: resolutionMutationId.present
        ? resolutionMutationId.value
        : this.resolutionMutationId,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  SyncConflictRow copyWithCompanion(SyncConflictRowsCompanion data) {
    return SyncConflictRow(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      objectKind: data.objectKind.present
          ? data.objectKind.value
          : this.objectKind,
      objectId: data.objectId.present ? data.objectId.value : this.objectId,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      clearPayloadJson: data.clearPayloadJson.present
          ? data.clearPayloadJson.value
          : this.clearPayloadJson,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
      resolutionKind: data.resolutionKind.present
          ? data.resolutionKind.value
          : this.resolutionKind,
      resolutionMutationId: data.resolutionMutationId.present
          ? data.resolutionMutationId.value
          : this.resolutionMutationId,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('objectKind: $objectKind, ')
          ..write('objectId: $objectId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('clearPayloadJson: $clearPayloadJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolutionKind: $resolutionKind, ')
          ..write('resolutionMutationId: $resolutionMutationId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mutationId,
    accountId,
    objectKind,
    objectId,
    envelopeJson,
    clearPayloadJson,
    detectedAt,
    resolutionKind,
    resolutionMutationId,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.mutationId == this.mutationId &&
          other.accountId == this.accountId &&
          other.objectKind == this.objectKind &&
          other.objectId == this.objectId &&
          other.envelopeJson == this.envelopeJson &&
          other.clearPayloadJson == this.clearPayloadJson &&
          other.detectedAt == this.detectedAt &&
          other.resolutionKind == this.resolutionKind &&
          other.resolutionMutationId == this.resolutionMutationId &&
          other.resolvedAt == this.resolvedAt);
}

class SyncConflictRowsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<String> mutationId;
  final Value<String> accountId;
  final Value<String> objectKind;
  final Value<String> objectId;
  final Value<String> envelopeJson;
  final Value<String> clearPayloadJson;
  final Value<DateTime> detectedAt;
  final Value<String> resolutionKind;
  final Value<String?> resolutionMutationId;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const SyncConflictRowsCompanion({
    this.mutationId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.objectKind = const Value.absent(),
    this.objectId = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.clearPayloadJson = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.resolutionKind = const Value.absent(),
    this.resolutionMutationId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictRowsCompanion.insert({
    required String mutationId,
    required String accountId,
    required String objectKind,
    required String objectId,
    required String envelopeJson,
    required String clearPayloadJson,
    required DateTime detectedAt,
    this.resolutionKind = const Value.absent(),
    this.resolutionMutationId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       accountId = Value(accountId),
       objectKind = Value(objectKind),
       objectId = Value(objectId),
       envelopeJson = Value(envelopeJson),
       clearPayloadJson = Value(clearPayloadJson),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflictRow> custom({
    Expression<String>? mutationId,
    Expression<String>? accountId,
    Expression<String>? objectKind,
    Expression<String>? objectId,
    Expression<String>? envelopeJson,
    Expression<String>? clearPayloadJson,
    Expression<DateTime>? detectedAt,
    Expression<String>? resolutionKind,
    Expression<String>? resolutionMutationId,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (accountId != null) 'account_id': accountId,
      if (objectKind != null) 'object_kind': objectKind,
      if (objectId != null) 'object_id': objectId,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (clearPayloadJson != null) 'clear_payload_json': clearPayloadJson,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (resolutionKind != null) 'resolution_kind': resolutionKind,
      if (resolutionMutationId != null)
        'resolution_mutation_id': resolutionMutationId,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictRowsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? accountId,
    Value<String>? objectKind,
    Value<String>? objectId,
    Value<String>? envelopeJson,
    Value<String>? clearPayloadJson,
    Value<DateTime>? detectedAt,
    Value<String>? resolutionKind,
    Value<String?>? resolutionMutationId,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return SyncConflictRowsCompanion(
      mutationId: mutationId ?? this.mutationId,
      accountId: accountId ?? this.accountId,
      objectKind: objectKind ?? this.objectKind,
      objectId: objectId ?? this.objectId,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      clearPayloadJson: clearPayloadJson ?? this.clearPayloadJson,
      detectedAt: detectedAt ?? this.detectedAt,
      resolutionKind: resolutionKind ?? this.resolutionKind,
      resolutionMutationId: resolutionMutationId ?? this.resolutionMutationId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (objectKind.present) {
      map['object_kind'] = Variable<String>(objectKind.value);
    }
    if (objectId.present) {
      map['object_id'] = Variable<String>(objectId.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (clearPayloadJson.present) {
      map['clear_payload_json'] = Variable<String>(clearPayloadJson.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (resolutionKind.present) {
      map['resolution_kind'] = Variable<String>(resolutionKind.value);
    }
    if (resolutionMutationId.present) {
      map['resolution_mutation_id'] = Variable<String>(
        resolutionMutationId.value,
      );
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRowsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('objectKind: $objectKind, ')
          ..write('objectId: $objectId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('clearPayloadJson: $clearPayloadJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolutionKind: $resolutionKind, ')
          ..write('resolutionMutationId: $resolutionMutationId, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSeenMutationRowsTable extends SyncSeenMutationRows
    with TableInfo<$SyncSeenMutationRowsTable, SyncSeenMutationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSeenMutationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    accountId,
    envelopeJson,
    firstSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_seen_mutation_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncSeenMutationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  SyncSeenMutationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSeenMutationRow(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
    );
  }

  @override
  $SyncSeenMutationRowsTable createAlias(String alias) {
    return $SyncSeenMutationRowsTable(attachedDatabase, alias);
  }
}

class SyncSeenMutationRow extends DataClass
    implements Insertable<SyncSeenMutationRow> {
  final String mutationId;
  final String accountId;
  final String envelopeJson;
  final DateTime firstSeenAt;
  const SyncSeenMutationRow({
    required this.mutationId,
    required this.accountId,
    required this.envelopeJson,
    required this.firstSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['account_id'] = Variable<String>(accountId);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    return map;
  }

  SyncSeenMutationRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncSeenMutationRowsCompanion(
      mutationId: Value(mutationId),
      accountId: Value(accountId),
      envelopeJson: Value(envelopeJson),
      firstSeenAt: Value(firstSeenAt),
    );
  }

  factory SyncSeenMutationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSeenMutationRow(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'accountId': serializer.toJson<String>(accountId),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
    };
  }

  SyncSeenMutationRow copyWith({
    String? mutationId,
    String? accountId,
    String? envelopeJson,
    DateTime? firstSeenAt,
  }) => SyncSeenMutationRow(
    mutationId: mutationId ?? this.mutationId,
    accountId: accountId ?? this.accountId,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
  );
  SyncSeenMutationRow copyWithCompanion(SyncSeenMutationRowsCompanion data) {
    return SyncSeenMutationRow(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSeenMutationRow(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('firstSeenAt: $firstSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mutationId, accountId, envelopeJson, firstSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSeenMutationRow &&
          other.mutationId == this.mutationId &&
          other.accountId == this.accountId &&
          other.envelopeJson == this.envelopeJson &&
          other.firstSeenAt == this.firstSeenAt);
}

class SyncSeenMutationRowsCompanion
    extends UpdateCompanion<SyncSeenMutationRow> {
  final Value<String> mutationId;
  final Value<String> accountId;
  final Value<String> envelopeJson;
  final Value<DateTime> firstSeenAt;
  final Value<int> rowid;
  const SyncSeenMutationRowsCompanion({
    this.mutationId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSeenMutationRowsCompanion.insert({
    required String mutationId,
    required String accountId,
    required String envelopeJson,
    required DateTime firstSeenAt,
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       accountId = Value(accountId),
       envelopeJson = Value(envelopeJson),
       firstSeenAt = Value(firstSeenAt);
  static Insertable<SyncSeenMutationRow> custom({
    Expression<String>? mutationId,
    Expression<String>? accountId,
    Expression<String>? envelopeJson,
    Expression<DateTime>? firstSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (accountId != null) 'account_id': accountId,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSeenMutationRowsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? accountId,
    Value<String>? envelopeJson,
    Value<DateTime>? firstSeenAt,
    Value<int>? rowid,
  }) {
    return SyncSeenMutationRowsCompanion(
      mutationId: mutationId ?? this.mutationId,
      accountId: accountId ?? this.accountId,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSeenMutationRowsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastShowsTable extends PodcastShows
    with TableInfo<$PodcastShowsTable, PodcastShow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastShowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalFeedUrlMeta = const VerificationMeta(
    'canonicalFeedUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalFeedUrl = GeneratedColumn<String>(
    'canonical_feed_url',
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _websiteUrlMeta = const VerificationMeta(
    'websiteUrl',
  );
  @override
  late final GeneratedColumn<String> websiteUrl = GeneratedColumn<String>(
    'website_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _explicitRatingMeta = const VerificationMeta(
    'explicitRating',
  );
  @override
  late final GeneratedColumn<String> explicitRating = GeneratedColumn<String>(
    'explicit_rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultPlaybackRateMeta =
      const VerificationMeta('defaultPlaybackRate');
  @override
  late final GeneratedColumn<double> defaultPlaybackRate =
      GeneratedColumn<double>(
        'default_playback_rate',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
      );
  static const VerificationMeta _downloadPolicyMeta = const VerificationMeta(
    'downloadPolicy',
  );
  @override
  late final GeneratedColumn<String> downloadPolicy = GeneratedColumn<String>(
    'download_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
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
        false,
        type: DriftSqlType.dateTime,
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
    canonicalFeedUrl,
    title,
    description,
    author,
    websiteUrl,
    imageUrl,
    language,
    explicitRating,
    defaultPlaybackRate,
    downloadPolicy,
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
  static const String $name = 'podcast_shows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastShow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('canonical_feed_url')) {
      context.handle(
        _canonicalFeedUrlMeta,
        canonicalFeedUrl.isAcceptableOrUnknown(
          data['canonical_feed_url']!,
          _canonicalFeedUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalFeedUrlMeta);
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
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('website_url')) {
      context.handle(
        _websiteUrlMeta,
        websiteUrl.isAcceptableOrUnknown(data['website_url']!, _websiteUrlMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('explicit_rating')) {
      context.handle(
        _explicitRatingMeta,
        explicitRating.isAcceptableOrUnknown(
          data['explicit_rating']!,
          _explicitRatingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explicitRatingMeta);
    }
    if (data.containsKey('default_playback_rate')) {
      context.handle(
        _defaultPlaybackRateMeta,
        defaultPlaybackRate.isAcceptableOrUnknown(
          data['default_playback_rate']!,
          _defaultPlaybackRateMeta,
        ),
      );
    }
    if (data.containsKey('download_policy')) {
      context.handle(
        _downloadPolicyMeta,
        downloadPolicy.isAcceptableOrUnknown(
          data['download_policy']!,
          _downloadPolicyMeta,
        ),
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
    } else if (isInserting) {
      context.missing(_lastRefreshedAtMeta);
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
    {canonicalFeedUrl},
  ];
  @override
  PodcastShow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastShow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      canonicalFeedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_feed_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      websiteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website_url'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      explicitRating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explicit_rating'],
      )!,
      defaultPlaybackRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_playback_rate'],
      )!,
      downloadPolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_policy'],
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
  $PodcastShowsTable createAlias(String alias) {
    return $PodcastShowsTable(attachedDatabase, alias);
  }
}

class PodcastShow extends DataClass implements Insertable<PodcastShow> {
  final String id;
  final String canonicalFeedUrl;
  final String title;
  final String? description;
  final String? author;
  final String? websiteUrl;
  final String? imageUrl;
  final String? language;
  final String explicitRating;
  final double defaultPlaybackRate;
  final String downloadPolicy;
  final String? etag;
  final String? lastModified;
  final DateTime lastRefreshedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PodcastShow({
    required this.id,
    required this.canonicalFeedUrl,
    required this.title,
    this.description,
    this.author,
    this.websiteUrl,
    this.imageUrl,
    this.language,
    required this.explicitRating,
    required this.defaultPlaybackRate,
    required this.downloadPolicy,
    this.etag,
    this.lastModified,
    required this.lastRefreshedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['canonical_feed_url'] = Variable<String>(canonicalFeedUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || websiteUrl != null) {
      map['website_url'] = Variable<String>(websiteUrl);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['explicit_rating'] = Variable<String>(explicitRating);
    map['default_playback_rate'] = Variable<double>(defaultPlaybackRate);
    map['download_policy'] = Variable<String>(downloadPolicy);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    map['last_refreshed_at'] = Variable<DateTime>(lastRefreshedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PodcastShowsCompanion toCompanion(bool nullToAbsent) {
    return PodcastShowsCompanion(
      id: Value(id),
      canonicalFeedUrl: Value(canonicalFeedUrl),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      websiteUrl: websiteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(websiteUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      explicitRating: Value(explicitRating),
      defaultPlaybackRate: Value(defaultPlaybackRate),
      downloadPolicy: Value(downloadPolicy),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      lastRefreshedAt: Value(lastRefreshedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PodcastShow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastShow(
      id: serializer.fromJson<String>(json['id']),
      canonicalFeedUrl: serializer.fromJson<String>(json['canonicalFeedUrl']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      author: serializer.fromJson<String?>(json['author']),
      websiteUrl: serializer.fromJson<String?>(json['websiteUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      language: serializer.fromJson<String?>(json['language']),
      explicitRating: serializer.fromJson<String>(json['explicitRating']),
      defaultPlaybackRate: serializer.fromJson<double>(
        json['defaultPlaybackRate'],
      ),
      downloadPolicy: serializer.fromJson<String>(json['downloadPolicy']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      lastRefreshedAt: serializer.fromJson<DateTime>(json['lastRefreshedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'canonicalFeedUrl': serializer.toJson<String>(canonicalFeedUrl),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'author': serializer.toJson<String?>(author),
      'websiteUrl': serializer.toJson<String?>(websiteUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'language': serializer.toJson<String?>(language),
      'explicitRating': serializer.toJson<String>(explicitRating),
      'defaultPlaybackRate': serializer.toJson<double>(defaultPlaybackRate),
      'downloadPolicy': serializer.toJson<String>(downloadPolicy),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'lastRefreshedAt': serializer.toJson<DateTime>(lastRefreshedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PodcastShow copyWith({
    String? id,
    String? canonicalFeedUrl,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> websiteUrl = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> language = const Value.absent(),
    String? explicitRating,
    double? defaultPlaybackRate,
    String? downloadPolicy,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    DateTime? lastRefreshedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PodcastShow(
    id: id ?? this.id,
    canonicalFeedUrl: canonicalFeedUrl ?? this.canonicalFeedUrl,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    author: author.present ? author.value : this.author,
    websiteUrl: websiteUrl.present ? websiteUrl.value : this.websiteUrl,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    language: language.present ? language.value : this.language,
    explicitRating: explicitRating ?? this.explicitRating,
    defaultPlaybackRate: defaultPlaybackRate ?? this.defaultPlaybackRate,
    downloadPolicy: downloadPolicy ?? this.downloadPolicy,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PodcastShow copyWithCompanion(PodcastShowsCompanion data) {
    return PodcastShow(
      id: data.id.present ? data.id.value : this.id,
      canonicalFeedUrl: data.canonicalFeedUrl.present
          ? data.canonicalFeedUrl.value
          : this.canonicalFeedUrl,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      author: data.author.present ? data.author.value : this.author,
      websiteUrl: data.websiteUrl.present
          ? data.websiteUrl.value
          : this.websiteUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      language: data.language.present ? data.language.value : this.language,
      explicitRating: data.explicitRating.present
          ? data.explicitRating.value
          : this.explicitRating,
      defaultPlaybackRate: data.defaultPlaybackRate.present
          ? data.defaultPlaybackRate.value
          : this.defaultPlaybackRate,
      downloadPolicy: data.downloadPolicy.present
          ? data.downloadPolicy.value
          : this.downloadPolicy,
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
    return (StringBuffer('PodcastShow(')
          ..write('id: $id, ')
          ..write('canonicalFeedUrl: $canonicalFeedUrl, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('language: $language, ')
          ..write('explicitRating: $explicitRating, ')
          ..write('defaultPlaybackRate: $defaultPlaybackRate, ')
          ..write('downloadPolicy: $downloadPolicy, ')
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
    canonicalFeedUrl,
    title,
    description,
    author,
    websiteUrl,
    imageUrl,
    language,
    explicitRating,
    defaultPlaybackRate,
    downloadPolicy,
    etag,
    lastModified,
    lastRefreshedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastShow &&
          other.id == this.id &&
          other.canonicalFeedUrl == this.canonicalFeedUrl &&
          other.title == this.title &&
          other.description == this.description &&
          other.author == this.author &&
          other.websiteUrl == this.websiteUrl &&
          other.imageUrl == this.imageUrl &&
          other.language == this.language &&
          other.explicitRating == this.explicitRating &&
          other.defaultPlaybackRate == this.defaultPlaybackRate &&
          other.downloadPolicy == this.downloadPolicy &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.lastRefreshedAt == this.lastRefreshedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PodcastShowsCompanion extends UpdateCompanion<PodcastShow> {
  final Value<String> id;
  final Value<String> canonicalFeedUrl;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> author;
  final Value<String?> websiteUrl;
  final Value<String?> imageUrl;
  final Value<String?> language;
  final Value<String> explicitRating;
  final Value<double> defaultPlaybackRate;
  final Value<String> downloadPolicy;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DateTime> lastRefreshedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PodcastShowsCompanion({
    this.id = const Value.absent(),
    this.canonicalFeedUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.websiteUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.language = const Value.absent(),
    this.explicitRating = const Value.absent(),
    this.defaultPlaybackRate = const Value.absent(),
    this.downloadPolicy = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.lastRefreshedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastShowsCompanion.insert({
    required String id,
    required String canonicalFeedUrl,
    required String title,
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.websiteUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.language = const Value.absent(),
    required String explicitRating,
    this.defaultPlaybackRate = const Value.absent(),
    this.downloadPolicy = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    required DateTime lastRefreshedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       canonicalFeedUrl = Value(canonicalFeedUrl),
       title = Value(title),
       explicitRating = Value(explicitRating),
       lastRefreshedAt = Value(lastRefreshedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PodcastShow> custom({
    Expression<String>? id,
    Expression<String>? canonicalFeedUrl,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? author,
    Expression<String>? websiteUrl,
    Expression<String>? imageUrl,
    Expression<String>? language,
    Expression<String>? explicitRating,
    Expression<double>? defaultPlaybackRate,
    Expression<String>? downloadPolicy,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<DateTime>? lastRefreshedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (canonicalFeedUrl != null) 'canonical_feed_url': canonicalFeedUrl,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (language != null) 'language': language,
      if (explicitRating != null) 'explicit_rating': explicitRating,
      if (defaultPlaybackRate != null)
        'default_playback_rate': defaultPlaybackRate,
      if (downloadPolicy != null) 'download_policy': downloadPolicy,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (lastRefreshedAt != null) 'last_refreshed_at': lastRefreshedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastShowsCompanion copyWith({
    Value<String>? id,
    Value<String>? canonicalFeedUrl,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? author,
    Value<String?>? websiteUrl,
    Value<String?>? imageUrl,
    Value<String?>? language,
    Value<String>? explicitRating,
    Value<double>? defaultPlaybackRate,
    Value<String>? downloadPolicy,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DateTime>? lastRefreshedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PodcastShowsCompanion(
      id: id ?? this.id,
      canonicalFeedUrl: canonicalFeedUrl ?? this.canonicalFeedUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      explicitRating: explicitRating ?? this.explicitRating,
      defaultPlaybackRate: defaultPlaybackRate ?? this.defaultPlaybackRate,
      downloadPolicy: downloadPolicy ?? this.downloadPolicy,
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
    if (canonicalFeedUrl.present) {
      map['canonical_feed_url'] = Variable<String>(canonicalFeedUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (websiteUrl.present) {
      map['website_url'] = Variable<String>(websiteUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (explicitRating.present) {
      map['explicit_rating'] = Variable<String>(explicitRating.value);
    }
    if (defaultPlaybackRate.present) {
      map['default_playback_rate'] = Variable<double>(
        defaultPlaybackRate.value,
      );
    }
    if (downloadPolicy.present) {
      map['download_policy'] = Variable<String>(downloadPolicy.value);
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
    return (StringBuffer('PodcastShowsCompanion(')
          ..write('id: $id, ')
          ..write('canonicalFeedUrl: $canonicalFeedUrl, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('language: $language, ')
          ..write('explicitRating: $explicitRating, ')
          ..write('defaultPlaybackRate: $defaultPlaybackRate, ')
          ..write('downloadPolicy: $downloadPolicy, ')
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

class $PodcastEpisodesTable extends PodcastEpisodes
    with TableInfo<$PodcastEpisodesTable, PodcastEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<String> showId = GeneratedColumn<String>(
    'show_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcast_shows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeUrlMeta = const VerificationMeta(
    'episodeUrl',
  );
  @override
  late final GeneratedColumn<String> episodeUrl = GeneratedColumn<String>(
    'episode_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaMimeTypeMeta = const VerificationMeta(
    'mediaMimeType',
  );
  @override
  late final GeneratedColumn<String> mediaMimeType = GeneratedColumn<String>(
    'media_mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaLengthBytesMeta = const VerificationMeta(
    'mediaLengthBytes',
  );
  @override
  late final GeneratedColumn<int> mediaLengthBytes = GeneratedColumn<int>(
    'media_length_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _explicitRatingMeta = const VerificationMeta(
    'explicitRating',
  );
  @override
  late final GeneratedColumn<String> explicitRating = GeneratedColumn<String>(
    'explicit_rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeTypeMeta = const VerificationMeta(
    'episodeType',
  );
  @override
  late final GeneratedColumn<String> episodeType = GeneratedColumn<String>(
    'episode_type',
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
    showId,
    externalId,
    title,
    description,
    author,
    episodeUrl,
    mediaUrl,
    imageUrl,
    mediaMimeType,
    mediaLengthBytes,
    publishedAt,
    durationMs,
    episodeNumber,
    seasonNumber,
    explicitRating,
    episodeType,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
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
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('episode_url')) {
      context.handle(
        _episodeUrlMeta,
        episodeUrl.isAcceptableOrUnknown(data['episode_url']!, _episodeUrlMeta),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaUrlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('media_mime_type')) {
      context.handle(
        _mediaMimeTypeMeta,
        mediaMimeType.isAcceptableOrUnknown(
          data['media_mime_type']!,
          _mediaMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('media_length_bytes')) {
      context.handle(
        _mediaLengthBytesMeta,
        mediaLengthBytes.isAcceptableOrUnknown(
          data['media_length_bytes']!,
          _mediaLengthBytesMeta,
        ),
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
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    }
    if (data.containsKey('explicit_rating')) {
      context.handle(
        _explicitRatingMeta,
        explicitRating.isAcceptableOrUnknown(
          data['explicit_rating']!,
          _explicitRatingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explicitRatingMeta);
    }
    if (data.containsKey('episode_type')) {
      context.handle(
        _episodeTypeMeta,
        episodeType.isAcceptableOrUnknown(
          data['episode_type']!,
          _episodeTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeTypeMeta);
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
    {showId, externalId},
  ];
  @override
  PodcastEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_id'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      episodeUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_url'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      mediaMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_mime_type'],
      ),
      mediaLengthBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_length_bytes'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      ),
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      ),
      explicitRating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explicit_rating'],
      )!,
      episodeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_type'],
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
  $PodcastEpisodesTable createAlias(String alias) {
    return $PodcastEpisodesTable(attachedDatabase, alias);
  }
}

class PodcastEpisode extends DataClass implements Insertable<PodcastEpisode> {
  final String id;
  final String showId;
  final String externalId;
  final String title;
  final String? description;
  final String? author;
  final String? episodeUrl;
  final String mediaUrl;
  final String? imageUrl;
  final String? mediaMimeType;
  final int? mediaLengthBytes;
  final DateTime? publishedAt;
  final int? durationMs;
  final int? episodeNumber;
  final int? seasonNumber;
  final String explicitRating;
  final String episodeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PodcastEpisode({
    required this.id,
    required this.showId,
    required this.externalId,
    required this.title,
    this.description,
    this.author,
    this.episodeUrl,
    required this.mediaUrl,
    this.imageUrl,
    this.mediaMimeType,
    this.mediaLengthBytes,
    this.publishedAt,
    this.durationMs,
    this.episodeNumber,
    this.seasonNumber,
    required this.explicitRating,
    required this.episodeType,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['show_id'] = Variable<String>(showId);
    map['external_id'] = Variable<String>(externalId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || episodeUrl != null) {
      map['episode_url'] = Variable<String>(episodeUrl);
    }
    map['media_url'] = Variable<String>(mediaUrl);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || mediaMimeType != null) {
      map['media_mime_type'] = Variable<String>(mediaMimeType);
    }
    if (!nullToAbsent || mediaLengthBytes != null) {
      map['media_length_bytes'] = Variable<int>(mediaLengthBytes);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    if (!nullToAbsent || seasonNumber != null) {
      map['season_number'] = Variable<int>(seasonNumber);
    }
    map['explicit_rating'] = Variable<String>(explicitRating);
    map['episode_type'] = Variable<String>(episodeType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PodcastEpisodesCompanion toCompanion(bool nullToAbsent) {
    return PodcastEpisodesCompanion(
      id: Value(id),
      showId: Value(showId),
      externalId: Value(externalId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      episodeUrl: episodeUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeUrl),
      mediaUrl: Value(mediaUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      mediaMimeType: mediaMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaMimeType),
      mediaLengthBytes: mediaLengthBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaLengthBytes),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      seasonNumber: seasonNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonNumber),
      explicitRating: Value(explicitRating),
      episodeType: Value(episodeType),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PodcastEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastEpisode(
      id: serializer.fromJson<String>(json['id']),
      showId: serializer.fromJson<String>(json['showId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      author: serializer.fromJson<String?>(json['author']),
      episodeUrl: serializer.fromJson<String?>(json['episodeUrl']),
      mediaUrl: serializer.fromJson<String>(json['mediaUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      mediaMimeType: serializer.fromJson<String?>(json['mediaMimeType']),
      mediaLengthBytes: serializer.fromJson<int?>(json['mediaLengthBytes']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      seasonNumber: serializer.fromJson<int?>(json['seasonNumber']),
      explicitRating: serializer.fromJson<String>(json['explicitRating']),
      episodeType: serializer.fromJson<String>(json['episodeType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'showId': serializer.toJson<String>(showId),
      'externalId': serializer.toJson<String>(externalId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'author': serializer.toJson<String?>(author),
      'episodeUrl': serializer.toJson<String?>(episodeUrl),
      'mediaUrl': serializer.toJson<String>(mediaUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'mediaMimeType': serializer.toJson<String?>(mediaMimeType),
      'mediaLengthBytes': serializer.toJson<int?>(mediaLengthBytes),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'seasonNumber': serializer.toJson<int?>(seasonNumber),
      'explicitRating': serializer.toJson<String>(explicitRating),
      'episodeType': serializer.toJson<String>(episodeType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PodcastEpisode copyWith({
    String? id,
    String? showId,
    String? externalId,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> episodeUrl = const Value.absent(),
    String? mediaUrl,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> mediaMimeType = const Value.absent(),
    Value<int?> mediaLengthBytes = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> episodeNumber = const Value.absent(),
    Value<int?> seasonNumber = const Value.absent(),
    String? explicitRating,
    String? episodeType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PodcastEpisode(
    id: id ?? this.id,
    showId: showId ?? this.showId,
    externalId: externalId ?? this.externalId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    author: author.present ? author.value : this.author,
    episodeUrl: episodeUrl.present ? episodeUrl.value : this.episodeUrl,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    mediaMimeType: mediaMimeType.present
        ? mediaMimeType.value
        : this.mediaMimeType,
    mediaLengthBytes: mediaLengthBytes.present
        ? mediaLengthBytes.value
        : this.mediaLengthBytes,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    episodeNumber: episodeNumber.present
        ? episodeNumber.value
        : this.episodeNumber,
    seasonNumber: seasonNumber.present ? seasonNumber.value : this.seasonNumber,
    explicitRating: explicitRating ?? this.explicitRating,
    episodeType: episodeType ?? this.episodeType,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PodcastEpisode copyWithCompanion(PodcastEpisodesCompanion data) {
    return PodcastEpisode(
      id: data.id.present ? data.id.value : this.id,
      showId: data.showId.present ? data.showId.value : this.showId,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      author: data.author.present ? data.author.value : this.author,
      episodeUrl: data.episodeUrl.present
          ? data.episodeUrl.value
          : this.episodeUrl,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      mediaMimeType: data.mediaMimeType.present
          ? data.mediaMimeType.value
          : this.mediaMimeType,
      mediaLengthBytes: data.mediaLengthBytes.present
          ? data.mediaLengthBytes.value
          : this.mediaLengthBytes,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      explicitRating: data.explicitRating.present
          ? data.explicitRating.value
          : this.explicitRating,
      episodeType: data.episodeType.present
          ? data.episodeType.value
          : this.episodeType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastEpisode(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('mediaMimeType: $mediaMimeType, ')
          ..write('mediaLengthBytes: $mediaLengthBytes, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('explicitRating: $explicitRating, ')
          ..write('episodeType: $episodeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    showId,
    externalId,
    title,
    description,
    author,
    episodeUrl,
    mediaUrl,
    imageUrl,
    mediaMimeType,
    mediaLengthBytes,
    publishedAt,
    durationMs,
    episodeNumber,
    seasonNumber,
    explicitRating,
    episodeType,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastEpisode &&
          other.id == this.id &&
          other.showId == this.showId &&
          other.externalId == this.externalId &&
          other.title == this.title &&
          other.description == this.description &&
          other.author == this.author &&
          other.episodeUrl == this.episodeUrl &&
          other.mediaUrl == this.mediaUrl &&
          other.imageUrl == this.imageUrl &&
          other.mediaMimeType == this.mediaMimeType &&
          other.mediaLengthBytes == this.mediaLengthBytes &&
          other.publishedAt == this.publishedAt &&
          other.durationMs == this.durationMs &&
          other.episodeNumber == this.episodeNumber &&
          other.seasonNumber == this.seasonNumber &&
          other.explicitRating == this.explicitRating &&
          other.episodeType == this.episodeType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PodcastEpisodesCompanion extends UpdateCompanion<PodcastEpisode> {
  final Value<String> id;
  final Value<String> showId;
  final Value<String> externalId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> author;
  final Value<String?> episodeUrl;
  final Value<String> mediaUrl;
  final Value<String?> imageUrl;
  final Value<String?> mediaMimeType;
  final Value<int?> mediaLengthBytes;
  final Value<DateTime?> publishedAt;
  final Value<int?> durationMs;
  final Value<int?> episodeNumber;
  final Value<int?> seasonNumber;
  final Value<String> explicitRating;
  final Value<String> episodeType;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PodcastEpisodesCompanion({
    this.id = const Value.absent(),
    this.showId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.episodeUrl = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaLengthBytes = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.explicitRating = const Value.absent(),
    this.episodeType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastEpisodesCompanion.insert({
    required String id,
    required String showId,
    required String externalId,
    required String title,
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.episodeUrl = const Value.absent(),
    required String mediaUrl,
    this.imageUrl = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaLengthBytes = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    required String explicitRating,
    required String episodeType,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       showId = Value(showId),
       externalId = Value(externalId),
       title = Value(title),
       mediaUrl = Value(mediaUrl),
       explicitRating = Value(explicitRating),
       episodeType = Value(episodeType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PodcastEpisode> custom({
    Expression<String>? id,
    Expression<String>? showId,
    Expression<String>? externalId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? author,
    Expression<String>? episodeUrl,
    Expression<String>? mediaUrl,
    Expression<String>? imageUrl,
    Expression<String>? mediaMimeType,
    Expression<int>? mediaLengthBytes,
    Expression<DateTime>? publishedAt,
    Expression<int>? durationMs,
    Expression<int>? episodeNumber,
    Expression<int>? seasonNumber,
    Expression<String>? explicitRating,
    Expression<String>? episodeType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (showId != null) 'show_id': showId,
      if (externalId != null) 'external_id': externalId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (episodeUrl != null) 'episode_url': episodeUrl,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (mediaMimeType != null) 'media_mime_type': mediaMimeType,
      if (mediaLengthBytes != null) 'media_length_bytes': mediaLengthBytes,
      if (publishedAt != null) 'published_at': publishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (explicitRating != null) 'explicit_rating': explicitRating,
      if (episodeType != null) 'episode_type': episodeType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastEpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? showId,
    Value<String>? externalId,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? author,
    Value<String?>? episodeUrl,
    Value<String>? mediaUrl,
    Value<String?>? imageUrl,
    Value<String?>? mediaMimeType,
    Value<int?>? mediaLengthBytes,
    Value<DateTime?>? publishedAt,
    Value<int?>? durationMs,
    Value<int?>? episodeNumber,
    Value<int?>? seasonNumber,
    Value<String>? explicitRating,
    Value<String>? episodeType,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PodcastEpisodesCompanion(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      episodeUrl: episodeUrl ?? this.episodeUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaLengthBytes: mediaLengthBytes ?? this.mediaLengthBytes,
      publishedAt: publishedAt ?? this.publishedAt,
      durationMs: durationMs ?? this.durationMs,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      explicitRating: explicitRating ?? this.explicitRating,
      episodeType: episodeType ?? this.episodeType,
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
    if (showId.present) {
      map['show_id'] = Variable<String>(showId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (episodeUrl.present) {
      map['episode_url'] = Variable<String>(episodeUrl.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (mediaMimeType.present) {
      map['media_mime_type'] = Variable<String>(mediaMimeType.value);
    }
    if (mediaLengthBytes.present) {
      map['media_length_bytes'] = Variable<int>(mediaLengthBytes.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (explicitRating.present) {
      map['explicit_rating'] = Variable<String>(explicitRating.value);
    }
    if (episodeType.present) {
      map['episode_type'] = Variable<String>(episodeType.value);
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
    return (StringBuffer('PodcastEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('episodeUrl: $episodeUrl, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('mediaMimeType: $mediaMimeType, ')
          ..write('mediaLengthBytes: $mediaLengthBytes, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('explicitRating: $explicitRating, ')
          ..write('episodeType: $episodeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastDownloadsTable extends PodcastDownloads
    with TableInfo<$PodcastDownloadsTable, PodcastDownload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastDownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcast_episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notDownloaded'),
  );
  static const VerificationMeta _partialPathMeta = const VerificationMeta(
    'partialPath',
  );
  @override
  late final GeneratedColumn<String> partialPath = GeneratedColumn<String>(
    'partial_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availablePathMeta = const VerificationMeta(
    'availablePath',
  );
  @override
  late final GeneratedColumn<String> availablePath = GeneratedColumn<String>(
    'available_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    episodeId,
    state,
    partialPath,
    availablePath,
    downloadedBytes,
    totalBytes,
    etag,
    failureCode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastDownload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('partial_path')) {
      context.handle(
        _partialPathMeta,
        partialPath.isAcceptableOrUnknown(
          data['partial_path']!,
          _partialPathMeta,
        ),
      );
    }
    if (data.containsKey('available_path')) {
      context.handle(
        _availablePathMeta,
        availablePath.isAcceptableOrUnknown(
          data['available_path']!,
          _availablePathMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  PodcastDownload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastDownload(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      partialPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partial_path'],
      ),
      availablePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_path'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PodcastDownloadsTable createAlias(String alias) {
    return $PodcastDownloadsTable(attachedDatabase, alias);
  }
}

class PodcastDownload extends DataClass implements Insertable<PodcastDownload> {
  final String episodeId;
  final String state;
  final String? partialPath;
  final String? availablePath;
  final int downloadedBytes;
  final int? totalBytes;
  final String? etag;
  final String? failureCode;
  final DateTime updatedAt;
  const PodcastDownload({
    required this.episodeId,
    required this.state,
    this.partialPath,
    this.availablePath,
    required this.downloadedBytes,
    this.totalBytes,
    this.etag,
    this.failureCode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<String>(episodeId);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || partialPath != null) {
      map['partial_path'] = Variable<String>(partialPath);
    }
    if (!nullToAbsent || availablePath != null) {
      map['available_path'] = Variable<String>(availablePath);
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PodcastDownloadsCompanion toCompanion(bool nullToAbsent) {
    return PodcastDownloadsCompanion(
      episodeId: Value(episodeId),
      state: Value(state),
      partialPath: partialPath == null && nullToAbsent
          ? const Value.absent()
          : Value(partialPath),
      availablePath: availablePath == null && nullToAbsent
          ? const Value.absent()
          : Value(availablePath),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      updatedAt: Value(updatedAt),
    );
  }

  factory PodcastDownload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastDownload(
      episodeId: serializer.fromJson<String>(json['episodeId']),
      state: serializer.fromJson<String>(json['state']),
      partialPath: serializer.fromJson<String?>(json['partialPath']),
      availablePath: serializer.fromJson<String?>(json['availablePath']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      etag: serializer.fromJson<String?>(json['etag']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<String>(episodeId),
      'state': serializer.toJson<String>(state),
      'partialPath': serializer.toJson<String?>(partialPath),
      'availablePath': serializer.toJson<String?>(availablePath),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'etag': serializer.toJson<String?>(etag),
      'failureCode': serializer.toJson<String?>(failureCode),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PodcastDownload copyWith({
    String? episodeId,
    String? state,
    Value<String?> partialPath = const Value.absent(),
    Value<String?> availablePath = const Value.absent(),
    int? downloadedBytes,
    Value<int?> totalBytes = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
    DateTime? updatedAt,
  }) => PodcastDownload(
    episodeId: episodeId ?? this.episodeId,
    state: state ?? this.state,
    partialPath: partialPath.present ? partialPath.value : this.partialPath,
    availablePath: availablePath.present
        ? availablePath.value
        : this.availablePath,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    etag: etag.present ? etag.value : this.etag,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PodcastDownload copyWithCompanion(PodcastDownloadsCompanion data) {
    return PodcastDownload(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      state: data.state.present ? data.state.value : this.state,
      partialPath: data.partialPath.present
          ? data.partialPath.value
          : this.partialPath,
      availablePath: data.availablePath.present
          ? data.availablePath.value
          : this.availablePath,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      etag: data.etag.present ? data.etag.value : this.etag,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastDownload(')
          ..write('episodeId: $episodeId, ')
          ..write('state: $state, ')
          ..write('partialPath: $partialPath, ')
          ..write('availablePath: $availablePath, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('etag: $etag, ')
          ..write('failureCode: $failureCode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    episodeId,
    state,
    partialPath,
    availablePath,
    downloadedBytes,
    totalBytes,
    etag,
    failureCode,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastDownload &&
          other.episodeId == this.episodeId &&
          other.state == this.state &&
          other.partialPath == this.partialPath &&
          other.availablePath == this.availablePath &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.etag == this.etag &&
          other.failureCode == this.failureCode &&
          other.updatedAt == this.updatedAt);
}

class PodcastDownloadsCompanion extends UpdateCompanion<PodcastDownload> {
  final Value<String> episodeId;
  final Value<String> state;
  final Value<String?> partialPath;
  final Value<String?> availablePath;
  final Value<int> downloadedBytes;
  final Value<int?> totalBytes;
  final Value<String?> etag;
  final Value<String?> failureCode;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PodcastDownloadsCompanion({
    this.episodeId = const Value.absent(),
    this.state = const Value.absent(),
    this.partialPath = const Value.absent(),
    this.availablePath = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.etag = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastDownloadsCompanion.insert({
    required String episodeId,
    this.state = const Value.absent(),
    this.partialPath = const Value.absent(),
    this.availablePath = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.etag = const Value.absent(),
    this.failureCode = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : episodeId = Value(episodeId),
       updatedAt = Value(updatedAt);
  static Insertable<PodcastDownload> custom({
    Expression<String>? episodeId,
    Expression<String>? state,
    Expression<String>? partialPath,
    Expression<String>? availablePath,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<String>? etag,
    Expression<String>? failureCode,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (state != null) 'state': state,
      if (partialPath != null) 'partial_path': partialPath,
      if (availablePath != null) 'available_path': availablePath,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (etag != null) 'etag': etag,
      if (failureCode != null) 'failure_code': failureCode,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastDownloadsCompanion copyWith({
    Value<String>? episodeId,
    Value<String>? state,
    Value<String?>? partialPath,
    Value<String?>? availablePath,
    Value<int>? downloadedBytes,
    Value<int?>? totalBytes,
    Value<String?>? etag,
    Value<String?>? failureCode,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PodcastDownloadsCompanion(
      episodeId: episodeId ?? this.episodeId,
      state: state ?? this.state,
      partialPath: partialPath ?? this.partialPath,
      availablePath: availablePath ?? this.availablePath,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      etag: etag ?? this.etag,
      failureCode: failureCode ?? this.failureCode,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (partialPath.present) {
      map['partial_path'] = Variable<String>(partialPath.value);
    }
    if (availablePath.present) {
      map['available_path'] = Variable<String>(availablePath.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
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
    return (StringBuffer('PodcastDownloadsCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('state: $state, ')
          ..write('partialPath: $partialPath, ')
          ..write('availablePath: $availablePath, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('etag: $etag, ')
          ..write('failureCode: $failureCode, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $ReaderSettingsRowsTable readerSettingsRows =
      $ReaderSettingsRowsTable(this);
  late final $KnowledgeItemsTable knowledgeItems = $KnowledgeItemsTable(this);
  late final $AudioItemsTable audioItems = $AudioItemsTable(this);
  late final $BackgroundJobsTable backgroundJobs = $BackgroundJobsTable(this);
  late final $SyncTombstonesTable syncTombstones = $SyncTombstonesTable(this);
  late final $SyncReplicaEntriesTable syncReplicaEntries =
      $SyncReplicaEntriesTable(this);
  late final $SyncOutboxRowsTable syncOutboxRows = $SyncOutboxRowsTable(this);
  late final $SyncCursorRowsTable syncCursorRows = $SyncCursorRowsTable(this);
  late final $SyncConflictRowsTable syncConflictRows = $SyncConflictRowsTable(
    this,
  );
  late final $SyncSeenMutationRowsTable syncSeenMutationRows =
      $SyncSeenMutationRowsTable(this);
  late final $PodcastShowsTable podcastShows = $PodcastShowsTable(this);
  late final $PodcastEpisodesTable podcastEpisodes = $PodcastEpisodesTable(
    this,
  );
  late final $PodcastDownloadsTable podcastDownloads = $PodcastDownloadsTable(
    this,
  );
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
    readerSettingsRows,
    knowledgeItems,
    audioItems,
    backgroundJobs,
    syncTombstones,
    syncReplicaEntries,
    syncOutboxRows,
    syncCursorRows,
    syncConflictRows,
    syncSeenMutationRows,
    podcastShows,
    podcastEpisodes,
    podcastDownloads,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcast_shows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('podcast_episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcast_episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('podcast_downloads', kind: UpdateKind.delete)],
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
        aliasName: 'folders__id__feed_subscriptions__folder_id',
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
      db.folders.createAlias('feed_subscriptions__folder_id__folders__id');

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
    aliasName: 'feed_subscriptions__id__articles__feed_id',
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
      Value<String?> feedContentHtml,
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
      Value<String?> feedContentHtml,
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

  static $FeedSubscriptionsTable _feedIdTable(_$RiverDatabase db) => db
      .feedSubscriptions
      .createAlias('articles__feed_id__feed_subscriptions__id');

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
        aliasName: 'articles__id__article_contents__article_id',
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
    aliasName: 'articles__id__reading_events__article_id',
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
    aliasName: 'articles__id__knowledge_items__article_id',
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

  ColumnFilters<String> get feedContentHtml => $composableBuilder(
    column: $table.feedContentHtml,
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

  ColumnOrderings<String> get feedContentHtml => $composableBuilder(
    column: $table.feedContentHtml,
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

  GeneratedColumn<String> get feedContentHtml => $composableBuilder(
    column: $table.feedContentHtml,
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
                Value<String?> feedContentHtml = const Value.absent(),
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
                feedContentHtml: feedContentHtml,
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
                Value<String?> feedContentHtml = const Value.absent(),
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
                feedContentHtml: feedContentHtml,
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
      db.articles.createAlias('article_contents__article_id__articles__id');

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
      db.articles.createAlias('reading_events__article_id__articles__id');

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
typedef $$ReaderSettingsRowsTableCreateCompanionBuilder =
    ReaderSettingsRowsCompanion Function({
      required String id,
      Value<String> fontFamily,
      Value<double> fontScale,
      Value<double> lineHeight,
      Value<double> contentWidth,
      Value<String> theme,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReaderSettingsRowsTableUpdateCompanionBuilder =
    ReaderSettingsRowsCompanion Function({
      Value<String> id,
      Value<String> fontFamily,
      Value<double> fontScale,
      Value<double> lineHeight,
      Value<double> contentWidth,
      Value<String> theme,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReaderSettingsRowsTableFilterComposer
    extends Composer<_$RiverDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableFilterComposer({
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

  ColumnFilters<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get contentWidth => $composableBuilder(
    column: $table.contentWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderSettingsRowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableOrderingComposer({
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

  ColumnOrderings<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get contentWidth => $composableBuilder(
    column: $table.contentWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderSettingsRowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fontScale =>
      $composableBuilder(column: $table.fontScale, builder: (column) => column);

  GeneratedColumn<double> get lineHeight => $composableBuilder(
    column: $table.lineHeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get contentWidth => $composableBuilder(
    column: $table.contentWidth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReaderSettingsRowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $ReaderSettingsRowsTable,
          ReaderSettingsRow,
          $$ReaderSettingsRowsTableFilterComposer,
          $$ReaderSettingsRowsTableOrderingComposer,
          $$ReaderSettingsRowsTableAnnotationComposer,
          $$ReaderSettingsRowsTableCreateCompanionBuilder,
          $$ReaderSettingsRowsTableUpdateCompanionBuilder,
          (
            ReaderSettingsRow,
            BaseReferences<
              _$RiverDatabase,
              $ReaderSettingsRowsTable,
              ReaderSettingsRow
            >,
          ),
          ReaderSettingsRow,
          PrefetchHooks Function()
        > {
  $$ReaderSettingsRowsTableTableManager(
    _$RiverDatabase db,
    $ReaderSettingsRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderSettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderSettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderSettingsRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fontFamily = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<double> lineHeight = const Value.absent(),
                Value<double> contentWidth = const Value.absent(),
                Value<String> theme = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderSettingsRowsCompanion(
                id: id,
                fontFamily: fontFamily,
                fontScale: fontScale,
                lineHeight: lineHeight,
                contentWidth: contentWidth,
                theme: theme,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> fontFamily = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<double> lineHeight = const Value.absent(),
                Value<double> contentWidth = const Value.absent(),
                Value<String> theme = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReaderSettingsRowsCompanion.insert(
                id: id,
                fontFamily: fontFamily,
                fontScale: fontScale,
                lineHeight: lineHeight,
                contentWidth: contentWidth,
                theme: theme,
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

typedef $$ReaderSettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $ReaderSettingsRowsTable,
      ReaderSettingsRow,
      $$ReaderSettingsRowsTableFilterComposer,
      $$ReaderSettingsRowsTableOrderingComposer,
      $$ReaderSettingsRowsTableAnnotationComposer,
      $$ReaderSettingsRowsTableCreateCompanionBuilder,
      $$ReaderSettingsRowsTableUpdateCompanionBuilder,
      (
        ReaderSettingsRow,
        BaseReferences<
          _$RiverDatabase,
          $ReaderSettingsRowsTable,
          ReaderSettingsRow
        >,
      ),
      ReaderSettingsRow,
      PrefetchHooks Function()
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
      db.articles.createAlias('knowledge_items__article_id__articles__id');

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
      Value<int?> segmentIndex,
      Value<int?> characterOffset,
      Value<String?> contentRevision,
      Value<int?> durationMs,
      Value<double> playbackRate,
      Value<double> pitch,
      Value<String?> voiceId,
      Value<String?> languageTag,
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
      Value<int?> segmentIndex,
      Value<int?> characterOffset,
      Value<String?> contentRevision,
      Value<int?> durationMs,
      Value<double> playbackRate,
      Value<double> pitch,
      Value<String?> voiceId,
      Value<String?> languageTag,
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

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get characterOffset => $composableBuilder(
    column: $table.characterOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
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

  ColumnFilters<double> get pitch => $composableBuilder(
    column: $table.pitch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
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

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get characterOffset => $composableBuilder(
    column: $table.characterOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
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

  ColumnOrderings<double> get pitch => $composableBuilder(
    column: $table.pitch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
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

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get characterOffset => $composableBuilder(
    column: $table.characterOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentRevision => $composableBuilder(
    column: $table.contentRevision,
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

  GeneratedColumn<double> get pitch =>
      $composableBuilder(column: $table.pitch, builder: (column) => column);

  GeneratedColumn<String> get voiceId =>
      $composableBuilder(column: $table.voiceId, builder: (column) => column);

  GeneratedColumn<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
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
                Value<int?> segmentIndex = const Value.absent(),
                Value<int?> characterOffset = const Value.absent(),
                Value<String?> contentRevision = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<double> pitch = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<String?> languageTag = const Value.absent(),
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
                segmentIndex: segmentIndex,
                characterOffset: characterOffset,
                contentRevision: contentRevision,
                durationMs: durationMs,
                playbackRate: playbackRate,
                pitch: pitch,
                voiceId: voiceId,
                languageTag: languageTag,
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
                Value<int?> segmentIndex = const Value.absent(),
                Value<int?> characterOffset = const Value.absent(),
                Value<String?> contentRevision = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<double> pitch = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<String?> languageTag = const Value.absent(),
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
                segmentIndex: segmentIndex,
                characterOffset: characterOffset,
                contentRevision: contentRevision,
                durationMs: durationMs,
                playbackRate: playbackRate,
                pitch: pitch,
                voiceId: voiceId,
                languageTag: languageTag,
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
typedef $$SyncReplicaEntriesTableCreateCompanionBuilder =
    SyncReplicaEntriesCompanion Function({
      required String accountId,
      required String objectKind,
      required String objectId,
      required String envelopeJson,
      required String clearPayloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncReplicaEntriesTableUpdateCompanionBuilder =
    SyncReplicaEntriesCompanion Function({
      Value<String> accountId,
      Value<String> objectKind,
      Value<String> objectId,
      Value<String> envelopeJson,
      Value<String> clearPayloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncReplicaEntriesTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncReplicaEntriesTable> {
  $$SyncReplicaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncReplicaEntriesTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncReplicaEntriesTable> {
  $$SyncReplicaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncReplicaEntriesTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncReplicaEntriesTable> {
  $$SyncReplicaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objectId =>
      $composableBuilder(column: $table.objectId, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncReplicaEntriesTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncReplicaEntriesTable,
          SyncReplicaEntry,
          $$SyncReplicaEntriesTableFilterComposer,
          $$SyncReplicaEntriesTableOrderingComposer,
          $$SyncReplicaEntriesTableAnnotationComposer,
          $$SyncReplicaEntriesTableCreateCompanionBuilder,
          $$SyncReplicaEntriesTableUpdateCompanionBuilder,
          (
            SyncReplicaEntry,
            BaseReferences<
              _$RiverDatabase,
              $SyncReplicaEntriesTable,
              SyncReplicaEntry
            >,
          ),
          SyncReplicaEntry,
          PrefetchHooks Function()
        > {
  $$SyncReplicaEntriesTableTableManager(
    _$RiverDatabase db,
    $SyncReplicaEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncReplicaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncReplicaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncReplicaEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> objectKind = const Value.absent(),
                Value<String> objectId = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<String> clearPayloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncReplicaEntriesCompanion(
                accountId: accountId,
                objectKind: objectKind,
                objectId: objectId,
                envelopeJson: envelopeJson,
                clearPayloadJson: clearPayloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String objectKind,
                required String objectId,
                required String envelopeJson,
                required String clearPayloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncReplicaEntriesCompanion.insert(
                accountId: accountId,
                objectKind: objectKind,
                objectId: objectId,
                envelopeJson: envelopeJson,
                clearPayloadJson: clearPayloadJson,
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

typedef $$SyncReplicaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncReplicaEntriesTable,
      SyncReplicaEntry,
      $$SyncReplicaEntriesTableFilterComposer,
      $$SyncReplicaEntriesTableOrderingComposer,
      $$SyncReplicaEntriesTableAnnotationComposer,
      $$SyncReplicaEntriesTableCreateCompanionBuilder,
      $$SyncReplicaEntriesTableUpdateCompanionBuilder,
      (
        SyncReplicaEntry,
        BaseReferences<
          _$RiverDatabase,
          $SyncReplicaEntriesTable,
          SyncReplicaEntry
        >,
      ),
      SyncReplicaEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxRowsTableCreateCompanionBuilder =
    SyncOutboxRowsCompanion Function({
      required String mutationId,
      required String accountId,
      required String deviceId,
      required String envelopeJson,
      required DateTime queuedAt,
      Value<int> rowid,
    });
typedef $$SyncOutboxRowsTableUpdateCompanionBuilder =
    SyncOutboxRowsCompanion Function({
      Value<String> mutationId,
      Value<String> accountId,
      Value<String> deviceId,
      Value<String> envelopeJson,
      Value<DateTime> queuedAt,
      Value<int> rowid,
    });

class $$SyncOutboxRowsTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncOutboxRowsTable> {
  $$SyncOutboxRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxRowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncOutboxRowsTable> {
  $$SyncOutboxRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxRowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncOutboxRowsTable> {
  $$SyncOutboxRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);
}

class $$SyncOutboxRowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncOutboxRowsTable,
          SyncOutboxRow,
          $$SyncOutboxRowsTableFilterComposer,
          $$SyncOutboxRowsTableOrderingComposer,
          $$SyncOutboxRowsTableAnnotationComposer,
          $$SyncOutboxRowsTableCreateCompanionBuilder,
          $$SyncOutboxRowsTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<
              _$RiverDatabase,
              $SyncOutboxRowsTable,
              SyncOutboxRow
            >,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxRowsTableTableManager(
    _$RiverDatabase db,
    $SyncOutboxRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxRowsCompanion(
                mutationId: mutationId,
                accountId: accountId,
                deviceId: deviceId,
                envelopeJson: envelopeJson,
                queuedAt: queuedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String accountId,
                required String deviceId,
                required String envelopeJson,
                required DateTime queuedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxRowsCompanion.insert(
                mutationId: mutationId,
                accountId: accountId,
                deviceId: deviceId,
                envelopeJson: envelopeJson,
                queuedAt: queuedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncOutboxRowsTable,
      SyncOutboxRow,
      $$SyncOutboxRowsTableFilterComposer,
      $$SyncOutboxRowsTableOrderingComposer,
      $$SyncOutboxRowsTableAnnotationComposer,
      $$SyncOutboxRowsTableCreateCompanionBuilder,
      $$SyncOutboxRowsTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$RiverDatabase, $SyncOutboxRowsTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorRowsTableCreateCompanionBuilder =
    SyncCursorRowsCompanion Function({
      required String accountId,
      required String deviceId,
      required int protocolVersion,
      required int serverSequence,
      required String opaqueToken,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncCursorRowsTableUpdateCompanionBuilder =
    SyncCursorRowsCompanion Function({
      Value<String> accountId,
      Value<String> deviceId,
      Value<int> protocolVersion,
      Value<int> serverSequence,
      Value<String> opaqueToken,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncCursorRowsTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncCursorRowsTable> {
  $$SyncCursorRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opaqueToken => $composableBuilder(
    column: $table.opaqueToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorRowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncCursorRowsTable> {
  $$SyncCursorRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opaqueToken => $composableBuilder(
    column: $table.opaqueToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorRowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncCursorRowsTable> {
  $$SyncCursorRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get opaqueToken => $composableBuilder(
    column: $table.opaqueToken,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncCursorRowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncCursorRowsTable,
          SyncCursorRow,
          $$SyncCursorRowsTableFilterComposer,
          $$SyncCursorRowsTableOrderingComposer,
          $$SyncCursorRowsTableAnnotationComposer,
          $$SyncCursorRowsTableCreateCompanionBuilder,
          $$SyncCursorRowsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<
              _$RiverDatabase,
              $SyncCursorRowsTable,
              SyncCursorRow
            >,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorRowsTableTableManager(
    _$RiverDatabase db,
    $SyncCursorRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> protocolVersion = const Value.absent(),
                Value<int> serverSequence = const Value.absent(),
                Value<String> opaqueToken = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorRowsCompanion(
                accountId: accountId,
                deviceId: deviceId,
                protocolVersion: protocolVersion,
                serverSequence: serverSequence,
                opaqueToken: opaqueToken,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String deviceId,
                required int protocolVersion,
                required int serverSequence,
                required String opaqueToken,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorRowsCompanion.insert(
                accountId: accountId,
                deviceId: deviceId,
                protocolVersion: protocolVersion,
                serverSequence: serverSequence,
                opaqueToken: opaqueToken,
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

typedef $$SyncCursorRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncCursorRowsTable,
      SyncCursorRow,
      $$SyncCursorRowsTableFilterComposer,
      $$SyncCursorRowsTableOrderingComposer,
      $$SyncCursorRowsTableAnnotationComposer,
      $$SyncCursorRowsTableCreateCompanionBuilder,
      $$SyncCursorRowsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$RiverDatabase, $SyncCursorRowsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictRowsTableCreateCompanionBuilder =
    SyncConflictRowsCompanion Function({
      required String mutationId,
      required String accountId,
      required String objectKind,
      required String objectId,
      required String envelopeJson,
      required String clearPayloadJson,
      required DateTime detectedAt,
      Value<String> resolutionKind,
      Value<String?> resolutionMutationId,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$SyncConflictRowsTableUpdateCompanionBuilder =
    SyncConflictRowsCompanion Function({
      Value<String> mutationId,
      Value<String> accountId,
      Value<String> objectKind,
      Value<String> objectId,
      Value<String> envelopeJson,
      Value<String> clearPayloadJson,
      Value<DateTime> detectedAt,
      Value<String> resolutionKind,
      Value<String?> resolutionMutationId,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

class $$SyncConflictRowsTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncConflictRowsTable> {
  $$SyncConflictRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionKind => $composableBuilder(
    column: $table.resolutionKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionMutationId => $composableBuilder(
    column: $table.resolutionMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictRowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncConflictRowsTable> {
  $$SyncConflictRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionKind => $composableBuilder(
    column: $table.resolutionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionMutationId => $composableBuilder(
    column: $table.resolutionMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictRowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncConflictRowsTable> {
  $$SyncConflictRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get objectKind => $composableBuilder(
    column: $table.objectKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objectId =>
      $composableBuilder(column: $table.objectId, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clearPayloadJson => $composableBuilder(
    column: $table.clearPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionKind => $composableBuilder(
    column: $table.resolutionKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionMutationId => $composableBuilder(
    column: $table.resolutionMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$SyncConflictRowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncConflictRowsTable,
          SyncConflictRow,
          $$SyncConflictRowsTableFilterComposer,
          $$SyncConflictRowsTableOrderingComposer,
          $$SyncConflictRowsTableAnnotationComposer,
          $$SyncConflictRowsTableCreateCompanionBuilder,
          $$SyncConflictRowsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<
              _$RiverDatabase,
              $SyncConflictRowsTable,
              SyncConflictRow
            >,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictRowsTableTableManager(
    _$RiverDatabase db,
    $SyncConflictRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> objectKind = const Value.absent(),
                Value<String> objectId = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<String> clearPayloadJson = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<String> resolutionKind = const Value.absent(),
                Value<String?> resolutionMutationId = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictRowsCompanion(
                mutationId: mutationId,
                accountId: accountId,
                objectKind: objectKind,
                objectId: objectId,
                envelopeJson: envelopeJson,
                clearPayloadJson: clearPayloadJson,
                detectedAt: detectedAt,
                resolutionKind: resolutionKind,
                resolutionMutationId: resolutionMutationId,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String accountId,
                required String objectKind,
                required String objectId,
                required String envelopeJson,
                required String clearPayloadJson,
                required DateTime detectedAt,
                Value<String> resolutionKind = const Value.absent(),
                Value<String?> resolutionMutationId = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictRowsCompanion.insert(
                mutationId: mutationId,
                accountId: accountId,
                objectKind: objectKind,
                objectId: objectId,
                envelopeJson: envelopeJson,
                clearPayloadJson: clearPayloadJson,
                detectedAt: detectedAt,
                resolutionKind: resolutionKind,
                resolutionMutationId: resolutionMutationId,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncConflictRowsTable,
      SyncConflictRow,
      $$SyncConflictRowsTableFilterComposer,
      $$SyncConflictRowsTableOrderingComposer,
      $$SyncConflictRowsTableAnnotationComposer,
      $$SyncConflictRowsTableCreateCompanionBuilder,
      $$SyncConflictRowsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<
          _$RiverDatabase,
          $SyncConflictRowsTable,
          SyncConflictRow
        >,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;
typedef $$SyncSeenMutationRowsTableCreateCompanionBuilder =
    SyncSeenMutationRowsCompanion Function({
      required String mutationId,
      required String accountId,
      required String envelopeJson,
      required DateTime firstSeenAt,
      Value<int> rowid,
    });
typedef $$SyncSeenMutationRowsTableUpdateCompanionBuilder =
    SyncSeenMutationRowsCompanion Function({
      Value<String> mutationId,
      Value<String> accountId,
      Value<String> envelopeJson,
      Value<DateTime> firstSeenAt,
      Value<int> rowid,
    });

class $$SyncSeenMutationRowsTableFilterComposer
    extends Composer<_$RiverDatabase, $SyncSeenMutationRowsTable> {
  $$SyncSeenMutationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncSeenMutationRowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $SyncSeenMutationRowsTable> {
  $$SyncSeenMutationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncSeenMutationRowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $SyncSeenMutationRowsTable> {
  $$SyncSeenMutationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );
}

class $$SyncSeenMutationRowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $SyncSeenMutationRowsTable,
          SyncSeenMutationRow,
          $$SyncSeenMutationRowsTableFilterComposer,
          $$SyncSeenMutationRowsTableOrderingComposer,
          $$SyncSeenMutationRowsTableAnnotationComposer,
          $$SyncSeenMutationRowsTableCreateCompanionBuilder,
          $$SyncSeenMutationRowsTableUpdateCompanionBuilder,
          (
            SyncSeenMutationRow,
            BaseReferences<
              _$RiverDatabase,
              $SyncSeenMutationRowsTable,
              SyncSeenMutationRow
            >,
          ),
          SyncSeenMutationRow,
          PrefetchHooks Function()
        > {
  $$SyncSeenMutationRowsTableTableManager(
    _$RiverDatabase db,
    $SyncSeenMutationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSeenMutationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSeenMutationRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncSeenMutationRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncSeenMutationRowsCompanion(
                mutationId: mutationId,
                accountId: accountId,
                envelopeJson: envelopeJson,
                firstSeenAt: firstSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String accountId,
                required String envelopeJson,
                required DateTime firstSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncSeenMutationRowsCompanion.insert(
                mutationId: mutationId,
                accountId: accountId,
                envelopeJson: envelopeJson,
                firstSeenAt: firstSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncSeenMutationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $SyncSeenMutationRowsTable,
      SyncSeenMutationRow,
      $$SyncSeenMutationRowsTableFilterComposer,
      $$SyncSeenMutationRowsTableOrderingComposer,
      $$SyncSeenMutationRowsTableAnnotationComposer,
      $$SyncSeenMutationRowsTableCreateCompanionBuilder,
      $$SyncSeenMutationRowsTableUpdateCompanionBuilder,
      (
        SyncSeenMutationRow,
        BaseReferences<
          _$RiverDatabase,
          $SyncSeenMutationRowsTable,
          SyncSeenMutationRow
        >,
      ),
      SyncSeenMutationRow,
      PrefetchHooks Function()
    >;
typedef $$PodcastShowsTableCreateCompanionBuilder =
    PodcastShowsCompanion Function({
      required String id,
      required String canonicalFeedUrl,
      required String title,
      Value<String?> description,
      Value<String?> author,
      Value<String?> websiteUrl,
      Value<String?> imageUrl,
      Value<String?> language,
      required String explicitRating,
      Value<double> defaultPlaybackRate,
      Value<String> downloadPolicy,
      Value<String?> etag,
      Value<String?> lastModified,
      required DateTime lastRefreshedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PodcastShowsTableUpdateCompanionBuilder =
    PodcastShowsCompanion Function({
      Value<String> id,
      Value<String> canonicalFeedUrl,
      Value<String> title,
      Value<String?> description,
      Value<String?> author,
      Value<String?> websiteUrl,
      Value<String?> imageUrl,
      Value<String?> language,
      Value<String> explicitRating,
      Value<double> defaultPlaybackRate,
      Value<String> downloadPolicy,
      Value<String?> etag,
      Value<String?> lastModified,
      Value<DateTime> lastRefreshedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PodcastShowsTableReferences
    extends BaseReferences<_$RiverDatabase, $PodcastShowsTable, PodcastShow> {
  $$PodcastShowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PodcastEpisodesTable, List<PodcastEpisode>>
  _podcastEpisodesRefsTable(_$RiverDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.podcastEpisodes,
        aliasName: 'podcast_shows__id__podcast_episodes__show_id',
      );

  $$PodcastEpisodesTableProcessedTableManager get podcastEpisodesRefs {
    final manager = $$PodcastEpisodesTableTableManager(
      $_db,
      $_db.podcastEpisodes,
    ).filter((f) => f.showId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _podcastEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PodcastShowsTableFilterComposer
    extends Composer<_$RiverDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableFilterComposer({
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

  ColumnFilters<String> get canonicalFeedUrl => $composableBuilder(
    column: $table.canonicalFeedUrl,
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

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get defaultPlaybackRate => $composableBuilder(
    column: $table.defaultPlaybackRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadPolicy => $composableBuilder(
    column: $table.downloadPolicy,
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

  Expression<bool> podcastEpisodesRefs(
    Expression<bool> Function($$PodcastEpisodesTableFilterComposer f) f,
  ) {
    final $$PodcastEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastShowsTableOrderingComposer
    extends Composer<_$RiverDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableOrderingComposer({
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

  ColumnOrderings<String> get canonicalFeedUrl => $composableBuilder(
    column: $table.canonicalFeedUrl,
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

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get defaultPlaybackRate => $composableBuilder(
    column: $table.defaultPlaybackRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadPolicy => $composableBuilder(
    column: $table.downloadPolicy,
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
}

class $$PodcastShowsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalFeedUrl => $composableBuilder(
    column: $table.canonicalFeedUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => column,
  );

  GeneratedColumn<double> get defaultPlaybackRate => $composableBuilder(
    column: $table.defaultPlaybackRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadPolicy => $composableBuilder(
    column: $table.downloadPolicy,
    builder: (column) => column,
  );

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

  Expression<T> podcastEpisodesRefs<T extends Object>(
    Expression<T> Function($$PodcastEpisodesTableAnnotationComposer a) f,
  ) {
    final $$PodcastEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastShowsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $PodcastShowsTable,
          PodcastShow,
          $$PodcastShowsTableFilterComposer,
          $$PodcastShowsTableOrderingComposer,
          $$PodcastShowsTableAnnotationComposer,
          $$PodcastShowsTableCreateCompanionBuilder,
          $$PodcastShowsTableUpdateCompanionBuilder,
          (PodcastShow, $$PodcastShowsTableReferences),
          PodcastShow,
          PrefetchHooks Function({bool podcastEpisodesRefs})
        > {
  $$PodcastShowsTableTableManager(_$RiverDatabase db, $PodcastShowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastShowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastShowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastShowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> canonicalFeedUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> websiteUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String> explicitRating = const Value.absent(),
                Value<double> defaultPlaybackRate = const Value.absent(),
                Value<String> downloadPolicy = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime> lastRefreshedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastShowsCompanion(
                id: id,
                canonicalFeedUrl: canonicalFeedUrl,
                title: title,
                description: description,
                author: author,
                websiteUrl: websiteUrl,
                imageUrl: imageUrl,
                language: language,
                explicitRating: explicitRating,
                defaultPlaybackRate: defaultPlaybackRate,
                downloadPolicy: downloadPolicy,
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
                required String canonicalFeedUrl,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> websiteUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> language = const Value.absent(),
                required String explicitRating,
                Value<double> defaultPlaybackRate = const Value.absent(),
                Value<String> downloadPolicy = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                required DateTime lastRefreshedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PodcastShowsCompanion.insert(
                id: id,
                canonicalFeedUrl: canonicalFeedUrl,
                title: title,
                description: description,
                author: author,
                websiteUrl: websiteUrl,
                imageUrl: imageUrl,
                language: language,
                explicitRating: explicitRating,
                defaultPlaybackRate: defaultPlaybackRate,
                downloadPolicy: downloadPolicy,
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
                  $$PodcastShowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({podcastEpisodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (podcastEpisodesRefs) db.podcastEpisodes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (podcastEpisodesRefs)
                    await $_getPrefetchedData<
                      PodcastShow,
                      $PodcastShowsTable,
                      PodcastEpisode
                    >(
                      currentTable: table,
                      referencedTable: $$PodcastShowsTableReferences
                          ._podcastEpisodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PodcastShowsTableReferences(
                            db,
                            table,
                            p0,
                          ).podcastEpisodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.showId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PodcastShowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $PodcastShowsTable,
      PodcastShow,
      $$PodcastShowsTableFilterComposer,
      $$PodcastShowsTableOrderingComposer,
      $$PodcastShowsTableAnnotationComposer,
      $$PodcastShowsTableCreateCompanionBuilder,
      $$PodcastShowsTableUpdateCompanionBuilder,
      (PodcastShow, $$PodcastShowsTableReferences),
      PodcastShow,
      PrefetchHooks Function({bool podcastEpisodesRefs})
    >;
typedef $$PodcastEpisodesTableCreateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      required String id,
      required String showId,
      required String externalId,
      required String title,
      Value<String?> description,
      Value<String?> author,
      Value<String?> episodeUrl,
      required String mediaUrl,
      Value<String?> imageUrl,
      Value<String?> mediaMimeType,
      Value<int?> mediaLengthBytes,
      Value<DateTime?> publishedAt,
      Value<int?> durationMs,
      Value<int?> episodeNumber,
      Value<int?> seasonNumber,
      required String explicitRating,
      required String episodeType,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PodcastEpisodesTableUpdateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      Value<String> id,
      Value<String> showId,
      Value<String> externalId,
      Value<String> title,
      Value<String?> description,
      Value<String?> author,
      Value<String?> episodeUrl,
      Value<String> mediaUrl,
      Value<String?> imageUrl,
      Value<String?> mediaMimeType,
      Value<int?> mediaLengthBytes,
      Value<DateTime?> publishedAt,
      Value<int?> durationMs,
      Value<int?> episodeNumber,
      Value<int?> seasonNumber,
      Value<String> explicitRating,
      Value<String> episodeType,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PodcastEpisodesTableReferences
    extends
        BaseReferences<_$RiverDatabase, $PodcastEpisodesTable, PodcastEpisode> {
  $$PodcastEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PodcastShowsTable _showIdTable(_$RiverDatabase db) => db.podcastShows
      .createAlias('podcast_episodes__show_id__podcast_shows__id');

  $$PodcastShowsTableProcessedTableManager get showId {
    final $_column = $_itemColumn<String>('show_id')!;

    final manager = $$PodcastShowsTableTableManager(
      $_db,
      $_db.podcastShows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_showIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PodcastDownloadsTable, List<PodcastDownload>>
  _podcastDownloadsRefsTable(_$RiverDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.podcastDownloads,
        aliasName: 'podcast_episodes__id__podcast_downloads__episode_id',
      );

  $$PodcastDownloadsTableProcessedTableManager get podcastDownloadsRefs {
    final manager = $$PodcastDownloadsTableTableManager(
      $_db,
      $_db.podcastDownloads,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _podcastDownloadsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PodcastEpisodesTableFilterComposer
    extends Composer<_$RiverDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableFilterComposer({
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

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaMimeType => $composableBuilder(
    column: $table.mediaMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaLengthBytes => $composableBuilder(
    column: $table.mediaLengthBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeType => $composableBuilder(
    column: $table.episodeType,
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

  $$PodcastShowsTableFilterComposer get showId {
    final $$PodcastShowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.podcastShows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastShowsTableFilterComposer(
            $db: $db,
            $table: $db.podcastShows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> podcastDownloadsRefs(
    Expression<bool> Function($$PodcastDownloadsTableFilterComposer f) f,
  ) {
    final $$PodcastDownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastDownloads,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastDownloadsTableFilterComposer(
            $db: $db,
            $table: $db.podcastDownloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastEpisodesTableOrderingComposer
    extends Composer<_$RiverDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableOrderingComposer({
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

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaMimeType => $composableBuilder(
    column: $table.mediaMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaLengthBytes => $composableBuilder(
    column: $table.mediaLengthBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeType => $composableBuilder(
    column: $table.episodeType,
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

  $$PodcastShowsTableOrderingComposer get showId {
    final $$PodcastShowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.podcastShows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastShowsTableOrderingComposer(
            $db: $db,
            $table: $db.podcastShows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastEpisodesTableAnnotationComposer
    extends Composer<_$RiverDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get episodeUrl => $composableBuilder(
    column: $table.episodeUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaMimeType => $composableBuilder(
    column: $table.mediaMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaLengthBytes => $composableBuilder(
    column: $table.mediaLengthBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explicitRating => $composableBuilder(
    column: $table.explicitRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeType => $composableBuilder(
    column: $table.episodeType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PodcastShowsTableAnnotationComposer get showId {
    final $$PodcastShowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.podcastShows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastShowsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastShows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> podcastDownloadsRefs<T extends Object>(
    Expression<T> Function($$PodcastDownloadsTableAnnotationComposer a) f,
  ) {
    final $$PodcastDownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastDownloads,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastDownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastDownloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastEpisodesTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $PodcastEpisodesTable,
          PodcastEpisode,
          $$PodcastEpisodesTableFilterComposer,
          $$PodcastEpisodesTableOrderingComposer,
          $$PodcastEpisodesTableAnnotationComposer,
          $$PodcastEpisodesTableCreateCompanionBuilder,
          $$PodcastEpisodesTableUpdateCompanionBuilder,
          (PodcastEpisode, $$PodcastEpisodesTableReferences),
          PodcastEpisode,
          PrefetchHooks Function({bool showId, bool podcastDownloadsRefs})
        > {
  $$PodcastEpisodesTableTableManager(
    _$RiverDatabase db,
    $PodcastEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> showId = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> episodeUrl = const Value.absent(),
                Value<String> mediaUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> mediaMimeType = const Value.absent(),
                Value<int?> mediaLengthBytes = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<int?> seasonNumber = const Value.absent(),
                Value<String> explicitRating = const Value.absent(),
                Value<String> episodeType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastEpisodesCompanion(
                id: id,
                showId: showId,
                externalId: externalId,
                title: title,
                description: description,
                author: author,
                episodeUrl: episodeUrl,
                mediaUrl: mediaUrl,
                imageUrl: imageUrl,
                mediaMimeType: mediaMimeType,
                mediaLengthBytes: mediaLengthBytes,
                publishedAt: publishedAt,
                durationMs: durationMs,
                episodeNumber: episodeNumber,
                seasonNumber: seasonNumber,
                explicitRating: explicitRating,
                episodeType: episodeType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String showId,
                required String externalId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> episodeUrl = const Value.absent(),
                required String mediaUrl,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> mediaMimeType = const Value.absent(),
                Value<int?> mediaLengthBytes = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<int?> seasonNumber = const Value.absent(),
                required String explicitRating,
                required String episodeType,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PodcastEpisodesCompanion.insert(
                id: id,
                showId: showId,
                externalId: externalId,
                title: title,
                description: description,
                author: author,
                episodeUrl: episodeUrl,
                mediaUrl: mediaUrl,
                imageUrl: imageUrl,
                mediaMimeType: mediaMimeType,
                mediaLengthBytes: mediaLengthBytes,
                publishedAt: publishedAt,
                durationMs: durationMs,
                episodeNumber: episodeNumber,
                seasonNumber: seasonNumber,
                explicitRating: explicitRating,
                episodeType: episodeType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PodcastEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({showId = false, podcastDownloadsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (podcastDownloadsRefs) db.podcastDownloads,
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
                        if (showId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.showId,
                                    referencedTable:
                                        $$PodcastEpisodesTableReferences
                                            ._showIdTable(db),
                                    referencedColumn:
                                        $$PodcastEpisodesTableReferences
                                            ._showIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (podcastDownloadsRefs)
                        await $_getPrefetchedData<
                          PodcastEpisode,
                          $PodcastEpisodesTable,
                          PodcastDownload
                        >(
                          currentTable: table,
                          referencedTable: $$PodcastEpisodesTableReferences
                              ._podcastDownloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PodcastEpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).podcastDownloadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.episodeId == item.id,
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

typedef $$PodcastEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $PodcastEpisodesTable,
      PodcastEpisode,
      $$PodcastEpisodesTableFilterComposer,
      $$PodcastEpisodesTableOrderingComposer,
      $$PodcastEpisodesTableAnnotationComposer,
      $$PodcastEpisodesTableCreateCompanionBuilder,
      $$PodcastEpisodesTableUpdateCompanionBuilder,
      (PodcastEpisode, $$PodcastEpisodesTableReferences),
      PodcastEpisode,
      PrefetchHooks Function({bool showId, bool podcastDownloadsRefs})
    >;
typedef $$PodcastDownloadsTableCreateCompanionBuilder =
    PodcastDownloadsCompanion Function({
      required String episodeId,
      Value<String> state,
      Value<String?> partialPath,
      Value<String?> availablePath,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<String?> etag,
      Value<String?> failureCode,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PodcastDownloadsTableUpdateCompanionBuilder =
    PodcastDownloadsCompanion Function({
      Value<String> episodeId,
      Value<String> state,
      Value<String?> partialPath,
      Value<String?> availablePath,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<String?> etag,
      Value<String?> failureCode,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PodcastDownloadsTableReferences
    extends
        BaseReferences<
          _$RiverDatabase,
          $PodcastDownloadsTable,
          PodcastDownload
        > {
  $$PodcastDownloadsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PodcastEpisodesTable _episodeIdTable(_$RiverDatabase db) => db
      .podcastEpisodes
      .createAlias('podcast_downloads__episode_id__podcast_episodes__id');

  $$PodcastEpisodesTableProcessedTableManager get episodeId {
    final $_column = $_itemColumn<String>('episode_id')!;

    final manager = $$PodcastEpisodesTableTableManager(
      $_db,
      $_db.podcastEpisodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PodcastDownloadsTableFilterComposer
    extends Composer<_$RiverDatabase, $PodcastDownloadsTable> {
  $$PodcastDownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partialPath => $composableBuilder(
    column: $table.partialPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availablePath => $composableBuilder(
    column: $table.availablePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PodcastEpisodesTableFilterComposer get episodeId {
    final $$PodcastEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastDownloadsTableOrderingComposer
    extends Composer<_$RiverDatabase, $PodcastDownloadsTable> {
  $$PodcastDownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partialPath => $composableBuilder(
    column: $table.partialPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availablePath => $composableBuilder(
    column: $table.availablePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PodcastEpisodesTableOrderingComposer get episodeId {
    final $$PodcastEpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastDownloadsTableAnnotationComposer
    extends Composer<_$RiverDatabase, $PodcastDownloadsTable> {
  $$PodcastDownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get partialPath => $composableBuilder(
    column: $table.partialPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availablePath => $composableBuilder(
    column: $table.availablePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PodcastEpisodesTableAnnotationComposer get episodeId {
    final $$PodcastEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastDownloadsTableTableManager
    extends
        RootTableManager<
          _$RiverDatabase,
          $PodcastDownloadsTable,
          PodcastDownload,
          $$PodcastDownloadsTableFilterComposer,
          $$PodcastDownloadsTableOrderingComposer,
          $$PodcastDownloadsTableAnnotationComposer,
          $$PodcastDownloadsTableCreateCompanionBuilder,
          $$PodcastDownloadsTableUpdateCompanionBuilder,
          (PodcastDownload, $$PodcastDownloadsTableReferences),
          PodcastDownload,
          PrefetchHooks Function({bool episodeId})
        > {
  $$PodcastDownloadsTableTableManager(
    _$RiverDatabase db,
    $PodcastDownloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastDownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastDownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastDownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> episodeId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> partialPath = const Value.absent(),
                Value<String?> availablePath = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastDownloadsCompanion(
                episodeId: episodeId,
                state: state,
                partialPath: partialPath,
                availablePath: availablePath,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                etag: etag,
                failureCode: failureCode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String episodeId,
                Value<String> state = const Value.absent(),
                Value<String?> partialPath = const Value.absent(),
                Value<String?> availablePath = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PodcastDownloadsCompanion.insert(
                episodeId: episodeId,
                state: state,
                partialPath: partialPath,
                availablePath: availablePath,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                etag: etag,
                failureCode: failureCode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PodcastDownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodeId = false}) {
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
                    if (episodeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.episodeId,
                                referencedTable:
                                    $$PodcastDownloadsTableReferences
                                        ._episodeIdTable(db),
                                referencedColumn:
                                    $$PodcastDownloadsTableReferences
                                        ._episodeIdTable(db)
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

typedef $$PodcastDownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$RiverDatabase,
      $PodcastDownloadsTable,
      PodcastDownload,
      $$PodcastDownloadsTableFilterComposer,
      $$PodcastDownloadsTableOrderingComposer,
      $$PodcastDownloadsTableAnnotationComposer,
      $$PodcastDownloadsTableCreateCompanionBuilder,
      $$PodcastDownloadsTableUpdateCompanionBuilder,
      (PodcastDownload, $$PodcastDownloadsTableReferences),
      PodcastDownload,
      PrefetchHooks Function({bool episodeId})
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
  $$ReaderSettingsRowsTableTableManager get readerSettingsRows =>
      $$ReaderSettingsRowsTableTableManager(_db, _db.readerSettingsRows);
  $$KnowledgeItemsTableTableManager get knowledgeItems =>
      $$KnowledgeItemsTableTableManager(_db, _db.knowledgeItems);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db, _db.audioItems);
  $$BackgroundJobsTableTableManager get backgroundJobs =>
      $$BackgroundJobsTableTableManager(_db, _db.backgroundJobs);
  $$SyncTombstonesTableTableManager get syncTombstones =>
      $$SyncTombstonesTableTableManager(_db, _db.syncTombstones);
  $$SyncReplicaEntriesTableTableManager get syncReplicaEntries =>
      $$SyncReplicaEntriesTableTableManager(_db, _db.syncReplicaEntries);
  $$SyncOutboxRowsTableTableManager get syncOutboxRows =>
      $$SyncOutboxRowsTableTableManager(_db, _db.syncOutboxRows);
  $$SyncCursorRowsTableTableManager get syncCursorRows =>
      $$SyncCursorRowsTableTableManager(_db, _db.syncCursorRows);
  $$SyncConflictRowsTableTableManager get syncConflictRows =>
      $$SyncConflictRowsTableTableManager(_db, _db.syncConflictRows);
  $$SyncSeenMutationRowsTableTableManager get syncSeenMutationRows =>
      $$SyncSeenMutationRowsTableTableManager(_db, _db.syncSeenMutationRows);
  $$PodcastShowsTableTableManager get podcastShows =>
      $$PodcastShowsTableTableManager(_db, _db.podcastShows);
  $$PodcastEpisodesTableTableManager get podcastEpisodes =>
      $$PodcastEpisodesTableTableManager(_db, _db.podcastEpisodes);
  $$PodcastDownloadsTableTableManager get podcastDownloads =>
      $$PodcastDownloadsTableTableManager(_db, _db.podcastDownloads);
}
