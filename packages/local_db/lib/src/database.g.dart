// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CompanySettingsTable extends CompanySettings
    with TableInfo<$CompanySettingsTable, CompanySettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompanySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('КФХ'),
  );
  static const VerificationMeta _directorNameMeta = const VerificationMeta(
    'directorName',
  );
  @override
  late final GeneratedColumn<String> directorName = GeneratedColumn<String>(
    'director_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _innMeta = const VerificationMeta('inn');
  @override
  late final GeneratedColumn<String> inn = GeneratedColumn<String>(
    'inn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ogrnMeta = const VerificationMeta('ogrn');
  @override
  late final GeneratedColumn<String> ogrn = GeneratedColumn<String>(
    'ogrn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankAccountMeta = const VerificationMeta(
    'bankAccount',
  );
  @override
  late final GeneratedColumn<String> bankAccount = GeneratedColumn<String>(
    'bank_account',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _legalAddressMeta = const VerificationMeta(
    'legalAddress',
  );
  @override
  late final GeneratedColumn<String> legalAddress = GeneratedColumn<String>(
    'legal_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultWorkDayHoursMeta =
      const VerificationMeta('defaultWorkDayHours');
  @override
  late final GeneratedColumn<double> defaultWorkDayHours =
      GeneratedColumn<double>(
        'default_work_day_hours',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(8.0),
      );
  static const VerificationMeta _overtimeMultiplierMeta =
      const VerificationMeta('overtimeMultiplier');
  @override
  late final GeneratedColumn<double> overtimeMultiplier =
      GeneratedColumn<double>(
        'overtime_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.5),
      );
  static const VerificationMeta _nightShiftMultiplierMeta =
      const VerificationMeta('nightShiftMultiplier');
  @override
  late final GeneratedColumn<double> nightShiftMultiplier =
      GeneratedColumn<double>(
        'night_shift_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.2),
      );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    companyName,
    directorName,
    inn,
    ogrn,
    bankAccount,
    bankName,
    legalAddress,
    phone,
    defaultWorkDayHours,
    overtimeMultiplier,
    nightShiftMultiplier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'company_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompanySettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    }
    if (data.containsKey('director_name')) {
      context.handle(
        _directorNameMeta,
        directorName.isAcceptableOrUnknown(
          data['director_name']!,
          _directorNameMeta,
        ),
      );
    }
    if (data.containsKey('inn')) {
      context.handle(
        _innMeta,
        inn.isAcceptableOrUnknown(data['inn']!, _innMeta),
      );
    }
    if (data.containsKey('ogrn')) {
      context.handle(
        _ogrnMeta,
        ogrn.isAcceptableOrUnknown(data['ogrn']!, _ogrnMeta),
      );
    }
    if (data.containsKey('bank_account')) {
      context.handle(
        _bankAccountMeta,
        bankAccount.isAcceptableOrUnknown(
          data['bank_account']!,
          _bankAccountMeta,
        ),
      );
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    }
    if (data.containsKey('legal_address')) {
      context.handle(
        _legalAddressMeta,
        legalAddress.isAcceptableOrUnknown(
          data['legal_address']!,
          _legalAddressMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('default_work_day_hours')) {
      context.handle(
        _defaultWorkDayHoursMeta,
        defaultWorkDayHours.isAcceptableOrUnknown(
          data['default_work_day_hours']!,
          _defaultWorkDayHoursMeta,
        ),
      );
    }
    if (data.containsKey('overtime_multiplier')) {
      context.handle(
        _overtimeMultiplierMeta,
        overtimeMultiplier.isAcceptableOrUnknown(
          data['overtime_multiplier']!,
          _overtimeMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('night_shift_multiplier')) {
      context.handle(
        _nightShiftMultiplierMeta,
        nightShiftMultiplier.isAcceptableOrUnknown(
          data['night_shift_multiplier']!,
          _nightShiftMultiplierMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  CompanySettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompanySettingsRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      )!,
      directorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director_name'],
      ),
      inn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inn'],
      ),
      ogrn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ogrn'],
      ),
      bankAccount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_account'],
      ),
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      ),
      legalAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legal_address'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      defaultWorkDayHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_work_day_hours'],
      )!,
      overtimeMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}overtime_multiplier'],
      )!,
      nightShiftMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}night_shift_multiplier'],
      )!,
    );
  }

  @override
  $CompanySettingsTable createAlias(String alias) {
    return $CompanySettingsTable(attachedDatabase, alias);
  }
}

class CompanySettingsRow extends DataClass
    implements Insertable<CompanySettingsRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String companyName;
  final String? directorName;
  final String? inn;
  final String? ogrn;
  final String? bankAccount;
  final String? bankName;
  final String? legalAddress;
  final String? phone;
  final double defaultWorkDayHours;
  final double overtimeMultiplier;
  final double nightShiftMultiplier;
  const CompanySettingsRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.companyName,
    this.directorName,
    this.inn,
    this.ogrn,
    this.bankAccount,
    this.bankName,
    this.legalAddress,
    this.phone,
    required this.defaultWorkDayHours,
    required this.overtimeMultiplier,
    required this.nightShiftMultiplier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['company_name'] = Variable<String>(companyName);
    if (!nullToAbsent || directorName != null) {
      map['director_name'] = Variable<String>(directorName);
    }
    if (!nullToAbsent || inn != null) {
      map['inn'] = Variable<String>(inn);
    }
    if (!nullToAbsent || ogrn != null) {
      map['ogrn'] = Variable<String>(ogrn);
    }
    if (!nullToAbsent || bankAccount != null) {
      map['bank_account'] = Variable<String>(bankAccount);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || legalAddress != null) {
      map['legal_address'] = Variable<String>(legalAddress);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['default_work_day_hours'] = Variable<double>(defaultWorkDayHours);
    map['overtime_multiplier'] = Variable<double>(overtimeMultiplier);
    map['night_shift_multiplier'] = Variable<double>(nightShiftMultiplier);
    return map;
  }

  CompanySettingsCompanion toCompanion(bool nullToAbsent) {
    return CompanySettingsCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      companyName: Value(companyName),
      directorName: directorName == null && nullToAbsent
          ? const Value.absent()
          : Value(directorName),
      inn: inn == null && nullToAbsent ? const Value.absent() : Value(inn),
      ogrn: ogrn == null && nullToAbsent ? const Value.absent() : Value(ogrn),
      bankAccount: bankAccount == null && nullToAbsent
          ? const Value.absent()
          : Value(bankAccount),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      legalAddress: legalAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(legalAddress),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      defaultWorkDayHours: Value(defaultWorkDayHours),
      overtimeMultiplier: Value(overtimeMultiplier),
      nightShiftMultiplier: Value(nightShiftMultiplier),
    );
  }

  factory CompanySettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanySettingsRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      companyName: serializer.fromJson<String>(json['companyName']),
      directorName: serializer.fromJson<String?>(json['directorName']),
      inn: serializer.fromJson<String?>(json['inn']),
      ogrn: serializer.fromJson<String?>(json['ogrn']),
      bankAccount: serializer.fromJson<String?>(json['bankAccount']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      legalAddress: serializer.fromJson<String?>(json['legalAddress']),
      phone: serializer.fromJson<String?>(json['phone']),
      defaultWorkDayHours: serializer.fromJson<double>(
        json['defaultWorkDayHours'],
      ),
      overtimeMultiplier: serializer.fromJson<double>(
        json['overtimeMultiplier'],
      ),
      nightShiftMultiplier: serializer.fromJson<double>(
        json['nightShiftMultiplier'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'companyName': serializer.toJson<String>(companyName),
      'directorName': serializer.toJson<String?>(directorName),
      'inn': serializer.toJson<String?>(inn),
      'ogrn': serializer.toJson<String?>(ogrn),
      'bankAccount': serializer.toJson<String?>(bankAccount),
      'bankName': serializer.toJson<String?>(bankName),
      'legalAddress': serializer.toJson<String?>(legalAddress),
      'phone': serializer.toJson<String?>(phone),
      'defaultWorkDayHours': serializer.toJson<double>(defaultWorkDayHours),
      'overtimeMultiplier': serializer.toJson<double>(overtimeMultiplier),
      'nightShiftMultiplier': serializer.toJson<double>(nightShiftMultiplier),
    };
  }

  CompanySettingsRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? companyName,
    Value<String?> directorName = const Value.absent(),
    Value<String?> inn = const Value.absent(),
    Value<String?> ogrn = const Value.absent(),
    Value<String?> bankAccount = const Value.absent(),
    Value<String?> bankName = const Value.absent(),
    Value<String?> legalAddress = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    double? defaultWorkDayHours,
    double? overtimeMultiplier,
    double? nightShiftMultiplier,
  }) => CompanySettingsRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    companyName: companyName ?? this.companyName,
    directorName: directorName.present ? directorName.value : this.directorName,
    inn: inn.present ? inn.value : this.inn,
    ogrn: ogrn.present ? ogrn.value : this.ogrn,
    bankAccount: bankAccount.present ? bankAccount.value : this.bankAccount,
    bankName: bankName.present ? bankName.value : this.bankName,
    legalAddress: legalAddress.present ? legalAddress.value : this.legalAddress,
    phone: phone.present ? phone.value : this.phone,
    defaultWorkDayHours: defaultWorkDayHours ?? this.defaultWorkDayHours,
    overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    nightShiftMultiplier: nightShiftMultiplier ?? this.nightShiftMultiplier,
  );
  CompanySettingsRow copyWithCompanion(CompanySettingsCompanion data) {
    return CompanySettingsRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      directorName: data.directorName.present
          ? data.directorName.value
          : this.directorName,
      inn: data.inn.present ? data.inn.value : this.inn,
      ogrn: data.ogrn.present ? data.ogrn.value : this.ogrn,
      bankAccount: data.bankAccount.present
          ? data.bankAccount.value
          : this.bankAccount,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      legalAddress: data.legalAddress.present
          ? data.legalAddress.value
          : this.legalAddress,
      phone: data.phone.present ? data.phone.value : this.phone,
      defaultWorkDayHours: data.defaultWorkDayHours.present
          ? data.defaultWorkDayHours.value
          : this.defaultWorkDayHours,
      overtimeMultiplier: data.overtimeMultiplier.present
          ? data.overtimeMultiplier.value
          : this.overtimeMultiplier,
      nightShiftMultiplier: data.nightShiftMultiplier.present
          ? data.nightShiftMultiplier.value
          : this.nightShiftMultiplier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanySettingsRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('companyName: $companyName, ')
          ..write('directorName: $directorName, ')
          ..write('inn: $inn, ')
          ..write('ogrn: $ogrn, ')
          ..write('bankAccount: $bankAccount, ')
          ..write('bankName: $bankName, ')
          ..write('legalAddress: $legalAddress, ')
          ..write('phone: $phone, ')
          ..write('defaultWorkDayHours: $defaultWorkDayHours, ')
          ..write('overtimeMultiplier: $overtimeMultiplier, ')
          ..write('nightShiftMultiplier: $nightShiftMultiplier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    companyName,
    directorName,
    inn,
    ogrn,
    bankAccount,
    bankName,
    legalAddress,
    phone,
    defaultWorkDayHours,
    overtimeMultiplier,
    nightShiftMultiplier,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanySettingsRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.companyName == this.companyName &&
          other.directorName == this.directorName &&
          other.inn == this.inn &&
          other.ogrn == this.ogrn &&
          other.bankAccount == this.bankAccount &&
          other.bankName == this.bankName &&
          other.legalAddress == this.legalAddress &&
          other.phone == this.phone &&
          other.defaultWorkDayHours == this.defaultWorkDayHours &&
          other.overtimeMultiplier == this.overtimeMultiplier &&
          other.nightShiftMultiplier == this.nightShiftMultiplier);
}

class CompanySettingsCompanion extends UpdateCompanion<CompanySettingsRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> companyName;
  final Value<String?> directorName;
  final Value<String?> inn;
  final Value<String?> ogrn;
  final Value<String?> bankAccount;
  final Value<String?> bankName;
  final Value<String?> legalAddress;
  final Value<String?> phone;
  final Value<double> defaultWorkDayHours;
  final Value<double> overtimeMultiplier;
  final Value<double> nightShiftMultiplier;
  final Value<int> rowid;
  const CompanySettingsCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.companyName = const Value.absent(),
    this.directorName = const Value.absent(),
    this.inn = const Value.absent(),
    this.ogrn = const Value.absent(),
    this.bankAccount = const Value.absent(),
    this.bankName = const Value.absent(),
    this.legalAddress = const Value.absent(),
    this.phone = const Value.absent(),
    this.defaultWorkDayHours = const Value.absent(),
    this.overtimeMultiplier = const Value.absent(),
    this.nightShiftMultiplier = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompanySettingsCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.companyName = const Value.absent(),
    this.directorName = const Value.absent(),
    this.inn = const Value.absent(),
    this.ogrn = const Value.absent(),
    this.bankAccount = const Value.absent(),
    this.bankName = const Value.absent(),
    this.legalAddress = const Value.absent(),
    this.phone = const Value.absent(),
    this.defaultWorkDayHours = const Value.absent(),
    this.overtimeMultiplier = const Value.absent(),
    this.nightShiftMultiplier = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt);
  static Insertable<CompanySettingsRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? companyName,
    Expression<String>? directorName,
    Expression<String>? inn,
    Expression<String>? ogrn,
    Expression<String>? bankAccount,
    Expression<String>? bankName,
    Expression<String>? legalAddress,
    Expression<String>? phone,
    Expression<double>? defaultWorkDayHours,
    Expression<double>? overtimeMultiplier,
    Expression<double>? nightShiftMultiplier,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (companyName != null) 'company_name': companyName,
      if (directorName != null) 'director_name': directorName,
      if (inn != null) 'inn': inn,
      if (ogrn != null) 'ogrn': ogrn,
      if (bankAccount != null) 'bank_account': bankAccount,
      if (bankName != null) 'bank_name': bankName,
      if (legalAddress != null) 'legal_address': legalAddress,
      if (phone != null) 'phone': phone,
      if (defaultWorkDayHours != null)
        'default_work_day_hours': defaultWorkDayHours,
      if (overtimeMultiplier != null) 'overtime_multiplier': overtimeMultiplier,
      if (nightShiftMultiplier != null)
        'night_shift_multiplier': nightShiftMultiplier,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompanySettingsCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? companyName,
    Value<String?>? directorName,
    Value<String?>? inn,
    Value<String?>? ogrn,
    Value<String?>? bankAccount,
    Value<String?>? bankName,
    Value<String?>? legalAddress,
    Value<String?>? phone,
    Value<double>? defaultWorkDayHours,
    Value<double>? overtimeMultiplier,
    Value<double>? nightShiftMultiplier,
    Value<int>? rowid,
  }) {
    return CompanySettingsCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      companyName: companyName ?? this.companyName,
      directorName: directorName ?? this.directorName,
      inn: inn ?? this.inn,
      ogrn: ogrn ?? this.ogrn,
      bankAccount: bankAccount ?? this.bankAccount,
      bankName: bankName ?? this.bankName,
      legalAddress: legalAddress ?? this.legalAddress,
      phone: phone ?? this.phone,
      defaultWorkDayHours: defaultWorkDayHours ?? this.defaultWorkDayHours,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      nightShiftMultiplier: nightShiftMultiplier ?? this.nightShiftMultiplier,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (directorName.present) {
      map['director_name'] = Variable<String>(directorName.value);
    }
    if (inn.present) {
      map['inn'] = Variable<String>(inn.value);
    }
    if (ogrn.present) {
      map['ogrn'] = Variable<String>(ogrn.value);
    }
    if (bankAccount.present) {
      map['bank_account'] = Variable<String>(bankAccount.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (legalAddress.present) {
      map['legal_address'] = Variable<String>(legalAddress.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (defaultWorkDayHours.present) {
      map['default_work_day_hours'] = Variable<double>(
        defaultWorkDayHours.value,
      );
    }
    if (overtimeMultiplier.present) {
      map['overtime_multiplier'] = Variable<double>(overtimeMultiplier.value);
    }
    if (nightShiftMultiplier.present) {
      map['night_shift_multiplier'] = Variable<double>(
        nightShiftMultiplier.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompanySettingsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('companyName: $companyName, ')
          ..write('directorName: $directorName, ')
          ..write('inn: $inn, ')
          ..write('ogrn: $ogrn, ')
          ..write('bankAccount: $bankAccount, ')
          ..write('bankName: $bankName, ')
          ..write('legalAddress: $legalAddress, ')
          ..write('phone: $phone, ')
          ..write('defaultWorkDayHours: $defaultWorkDayHours, ')
          ..write('overtimeMultiplier: $overtimeMultiplier, ')
          ..write('nightShiftMultiplier: $nightShiftMultiplier, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, EmployeeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hireDateMeta = const VerificationMeta(
    'hireDate',
  );
  @override
  late final GeneratedColumn<String> hireDate = GeneratedColumn<String>(
    'hire_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissalDateMeta = const VerificationMeta(
    'dismissalDate',
  );
  @override
  late final GeneratedColumn<String> dismissalDate = GeneratedColumn<String>(
    'dismissal_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRateMeta = const VerificationMeta(
    'baseRate',
  );
  @override
  late final GeneratedColumn<double> baseRate = GeneratedColumn<double>(
    'base_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _fieldRateMeta = const VerificationMeta(
    'fieldRate',
  );
  @override
  late final GeneratedColumn<double> fieldRate = GeneratedColumn<double>(
    'field_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    fullName,
    position,
    hireDate,
    dismissalDate,
    baseRate,
    fieldRate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('hire_date')) {
      context.handle(
        _hireDateMeta,
        hireDate.isAcceptableOrUnknown(data['hire_date']!, _hireDateMeta),
      );
    } else if (isInserting) {
      context.missing(_hireDateMeta);
    }
    if (data.containsKey('dismissal_date')) {
      context.handle(
        _dismissalDateMeta,
        dismissalDate.isAcceptableOrUnknown(
          data['dismissal_date']!,
          _dismissalDateMeta,
        ),
      );
    }
    if (data.containsKey('base_rate')) {
      context.handle(
        _baseRateMeta,
        baseRate.isAcceptableOrUnknown(data['base_rate']!, _baseRateMeta),
      );
    }
    if (data.containsKey('field_rate')) {
      context.handle(
        _fieldRateMeta,
        fieldRate.isAcceptableOrUnknown(data['field_rate']!, _fieldRateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  EmployeeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      )!,
      hireDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hire_date'],
      )!,
      dismissalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dismissal_date'],
      ),
      baseRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_rate'],
      )!,
      fieldRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}field_rate'],
      )!,
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }
}

class EmployeeRow extends DataClass implements Insertable<EmployeeRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String fullName;
  final String position;
  final String hireDate;
  final String? dismissalDate;
  final double baseRate;
  final double fieldRate;
  const EmployeeRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.fullName,
    required this.position,
    required this.hireDate,
    this.dismissalDate,
    required this.baseRate,
    required this.fieldRate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['full_name'] = Variable<String>(fullName);
    map['position'] = Variable<String>(position);
    map['hire_date'] = Variable<String>(hireDate);
    if (!nullToAbsent || dismissalDate != null) {
      map['dismissal_date'] = Variable<String>(dismissalDate);
    }
    map['base_rate'] = Variable<double>(baseRate);
    map['field_rate'] = Variable<double>(fieldRate);
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      fullName: Value(fullName),
      position: Value(position),
      hireDate: Value(hireDate),
      dismissalDate: dismissalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissalDate),
      baseRate: Value(baseRate),
      fieldRate: Value(fieldRate),
    );
  }

  factory EmployeeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      fullName: serializer.fromJson<String>(json['fullName']),
      position: serializer.fromJson<String>(json['position']),
      hireDate: serializer.fromJson<String>(json['hireDate']),
      dismissalDate: serializer.fromJson<String?>(json['dismissalDate']),
      baseRate: serializer.fromJson<double>(json['baseRate']),
      fieldRate: serializer.fromJson<double>(json['fieldRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'fullName': serializer.toJson<String>(fullName),
      'position': serializer.toJson<String>(position),
      'hireDate': serializer.toJson<String>(hireDate),
      'dismissalDate': serializer.toJson<String?>(dismissalDate),
      'baseRate': serializer.toJson<double>(baseRate),
      'fieldRate': serializer.toJson<double>(fieldRate),
    };
  }

  EmployeeRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? fullName,
    String? position,
    String? hireDate,
    Value<String?> dismissalDate = const Value.absent(),
    double? baseRate,
    double? fieldRate,
  }) => EmployeeRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    fullName: fullName ?? this.fullName,
    position: position ?? this.position,
    hireDate: hireDate ?? this.hireDate,
    dismissalDate: dismissalDate.present
        ? dismissalDate.value
        : this.dismissalDate,
    baseRate: baseRate ?? this.baseRate,
    fieldRate: fieldRate ?? this.fieldRate,
  );
  EmployeeRow copyWithCompanion(EmployeesCompanion data) {
    return EmployeeRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      position: data.position.present ? data.position.value : this.position,
      hireDate: data.hireDate.present ? data.hireDate.value : this.hireDate,
      dismissalDate: data.dismissalDate.present
          ? data.dismissalDate.value
          : this.dismissalDate,
      baseRate: data.baseRate.present ? data.baseRate.value : this.baseRate,
      fieldRate: data.fieldRate.present ? data.fieldRate.value : this.fieldRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('fullName: $fullName, ')
          ..write('position: $position, ')
          ..write('hireDate: $hireDate, ')
          ..write('dismissalDate: $dismissalDate, ')
          ..write('baseRate: $baseRate, ')
          ..write('fieldRate: $fieldRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    fullName,
    position,
    hireDate,
    dismissalDate,
    baseRate,
    fieldRate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.fullName == this.fullName &&
          other.position == this.position &&
          other.hireDate == this.hireDate &&
          other.dismissalDate == this.dismissalDate &&
          other.baseRate == this.baseRate &&
          other.fieldRate == this.fieldRate);
}

class EmployeesCompanion extends UpdateCompanion<EmployeeRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> fullName;
  final Value<String> position;
  final Value<String> hireDate;
  final Value<String?> dismissalDate;
  final Value<double> baseRate;
  final Value<double> fieldRate;
  final Value<int> rowid;
  const EmployeesCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.fullName = const Value.absent(),
    this.position = const Value.absent(),
    this.hireDate = const Value.absent(),
    this.dismissalDate = const Value.absent(),
    this.baseRate = const Value.absent(),
    this.fieldRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmployeesCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String fullName,
    required String position,
    required String hireDate,
    this.dismissalDate = const Value.absent(),
    this.baseRate = const Value.absent(),
    this.fieldRate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       fullName = Value(fullName),
       position = Value(position),
       hireDate = Value(hireDate);
  static Insertable<EmployeeRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? fullName,
    Expression<String>? position,
    Expression<String>? hireDate,
    Expression<String>? dismissalDate,
    Expression<double>? baseRate,
    Expression<double>? fieldRate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (fullName != null) 'full_name': fullName,
      if (position != null) 'position': position,
      if (hireDate != null) 'hire_date': hireDate,
      if (dismissalDate != null) 'dismissal_date': dismissalDate,
      if (baseRate != null) 'base_rate': baseRate,
      if (fieldRate != null) 'field_rate': fieldRate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmployeesCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? fullName,
    Value<String>? position,
    Value<String>? hireDate,
    Value<String?>? dismissalDate,
    Value<double>? baseRate,
    Value<double>? fieldRate,
    Value<int>? rowid,
  }) {
    return EmployeesCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      hireDate: hireDate ?? this.hireDate,
      dismissalDate: dismissalDate ?? this.dismissalDate,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (hireDate.present) {
      map['hire_date'] = Variable<String>(hireDate.value);
    }
    if (dismissalDate.present) {
      map['dismissal_date'] = Variable<String>(dismissalDate.value);
    }
    if (baseRate.present) {
      map['base_rate'] = Variable<double>(baseRate.value);
    }
    if (fieldRate.present) {
      map['field_rate'] = Variable<double>(fieldRate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('fullName: $fullName, ')
          ..write('position: $position, ')
          ..write('hireDate: $hireDate, ')
          ..write('dismissalDate: $dismissalDate, ')
          ..write('baseRate: $baseRate, ')
          ..write('fieldRate: $fieldRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmployeeRatesTable extends EmployeeRates
    with TableInfo<$EmployeeRatesTable, EmployeeRateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeeRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _baseRateMeta = const VerificationMeta(
    'baseRate',
  );
  @override
  late final GeneratedColumn<double> baseRate = GeneratedColumn<double>(
    'base_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldRateMeta = const VerificationMeta(
    'fieldRate',
  );
  @override
  late final GeneratedColumn<double> fieldRate = GeneratedColumn<double>(
    'field_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    baseRate,
    fieldRate,
    startDate,
    endDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employee_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeRateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('base_rate')) {
      context.handle(
        _baseRateMeta,
        baseRate.isAcceptableOrUnknown(data['base_rate']!, _baseRateMeta),
      );
    } else if (isInserting) {
      context.missing(_baseRateMeta);
    }
    if (data.containsKey('field_rate')) {
      context.handle(
        _fieldRateMeta,
        fieldRate.isAcceptableOrUnknown(data['field_rate']!, _fieldRateMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldRateMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  EmployeeRateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeRateRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      baseRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_rate'],
      )!,
      fieldRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}field_rate'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
    );
  }

  @override
  $EmployeeRatesTable createAlias(String alias) {
    return $EmployeeRatesTable(attachedDatabase, alias);
  }
}

class EmployeeRateRow extends DataClass implements Insertable<EmployeeRateRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final double baseRate;
  final double fieldRate;
  final String startDate;
  final String? endDate;
  const EmployeeRateRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.baseRate,
    required this.fieldRate,
    required this.startDate,
    this.endDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['base_rate'] = Variable<double>(baseRate);
    map['field_rate'] = Variable<double>(fieldRate);
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    return map;
  }

  EmployeeRatesCompanion toCompanion(bool nullToAbsent) {
    return EmployeeRatesCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      baseRate: Value(baseRate),
      fieldRate: Value(fieldRate),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
    );
  }

  factory EmployeeRateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeRateRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      baseRate: serializer.fromJson<double>(json['baseRate']),
      fieldRate: serializer.fromJson<double>(json['fieldRate']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String?>(json['endDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'baseRate': serializer.toJson<double>(baseRate),
      'fieldRate': serializer.toJson<double>(fieldRate),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String?>(endDate),
    };
  }

  EmployeeRateRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    double? baseRate,
    double? fieldRate,
    String? startDate,
    Value<String?> endDate = const Value.absent(),
  }) => EmployeeRateRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    baseRate: baseRate ?? this.baseRate,
    fieldRate: fieldRate ?? this.fieldRate,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
  );
  EmployeeRateRow copyWithCompanion(EmployeeRatesCompanion data) {
    return EmployeeRateRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      baseRate: data.baseRate.present ? data.baseRate.value : this.baseRate,
      fieldRate: data.fieldRate.present ? data.fieldRate.value : this.fieldRate,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeRateRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('baseRate: $baseRate, ')
          ..write('fieldRate: $fieldRate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    baseRate,
    fieldRate,
    startDate,
    endDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeRateRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.baseRate == this.baseRate &&
          other.fieldRate == this.fieldRate &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate);
}

class EmployeeRatesCompanion extends UpdateCompanion<EmployeeRateRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<double> baseRate;
  final Value<double> fieldRate;
  final Value<String> startDate;
  final Value<String?> endDate;
  final Value<int> rowid;
  const EmployeeRatesCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.baseRate = const Value.absent(),
    this.fieldRate = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmployeeRatesCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required double baseRate,
    required double fieldRate,
    required String startDate,
    this.endDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       baseRate = Value(baseRate),
       fieldRate = Value(fieldRate),
       startDate = Value(startDate);
  static Insertable<EmployeeRateRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<double>? baseRate,
    Expression<double>? fieldRate,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (baseRate != null) 'base_rate': baseRate,
      if (fieldRate != null) 'field_rate': fieldRate,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmployeeRatesCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<double>? baseRate,
    Value<double>? fieldRate,
    Value<String>? startDate,
    Value<String?>? endDate,
    Value<int>? rowid,
  }) {
    return EmployeeRatesCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (baseRate.present) {
      map['base_rate'] = Variable<double>(baseRate.value);
    }
    if (fieldRate.present) {
      map['field_rate'] = Variable<double>(fieldRate.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeRatesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('baseRate: $baseRate, ')
          ..write('fieldRate: $fieldRate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimesheetTable extends Timesheet
    with TableInfo<$TimesheetTable, TimesheetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimesheetTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayTypeMeta = const VerificationMeta(
    'dayType',
  );
  @override
  late final GeneratedColumn<String> dayType = GeneratedColumn<String>(
    'day_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('work'),
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<double> days = GeneratedColumn<double>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _workPlaceMeta = const VerificationMeta(
    'workPlace',
  );
  @override
  late final GeneratedColumn<String> workPlace = GeneratedColumn<String>(
    'work_place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    date,
    dayType,
    days,
    workPlace,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timesheet';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimesheetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('day_type')) {
      context.handle(
        _dayTypeMeta,
        dayType.isAcceptableOrUnknown(data['day_type']!, _dayTypeMeta),
      );
    }
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    }
    if (data.containsKey('work_place')) {
      context.handle(
        _workPlaceMeta,
        workPlace.isAcceptableOrUnknown(data['work_place']!, _workPlaceMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  TimesheetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimesheetRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      dayType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_type'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}days'],
      )!,
      workPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_place'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TimesheetTable createAlias(String alias) {
    return $TimesheetTable(attachedDatabase, alias);
  }
}

class TimesheetRow extends DataClass implements Insertable<TimesheetRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final String date;

  /// `work` | `sick` | `vacation` | `dayoff`
  final String dayType;

  /// Для `work` — 1 или 0.5.
  final double days;

  /// `base` | `field` (только для `work`).
  final String? workPlace;
  final String? notes;
  final String createdAt;
  const TimesheetRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.date,
    required this.dayType,
    required this.days,
    this.workPlace,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['date'] = Variable<String>(date);
    map['day_type'] = Variable<String>(dayType);
    map['days'] = Variable<double>(days);
    if (!nullToAbsent || workPlace != null) {
      map['work_place'] = Variable<String>(workPlace);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  TimesheetCompanion toCompanion(bool nullToAbsent) {
    return TimesheetCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      date: Value(date),
      dayType: Value(dayType),
      days: Value(days),
      workPlace: workPlace == null && nullToAbsent
          ? const Value.absent()
          : Value(workPlace),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory TimesheetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimesheetRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      date: serializer.fromJson<String>(json['date']),
      dayType: serializer.fromJson<String>(json['dayType']),
      days: serializer.fromJson<double>(json['days']),
      workPlace: serializer.fromJson<String?>(json['workPlace']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'date': serializer.toJson<String>(date),
      'dayType': serializer.toJson<String>(dayType),
      'days': serializer.toJson<double>(days),
      'workPlace': serializer.toJson<String?>(workPlace),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  TimesheetRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    String? date,
    String? dayType,
    double? days,
    Value<String?> workPlace = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
  }) => TimesheetRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    date: date ?? this.date,
    dayType: dayType ?? this.dayType,
    days: days ?? this.days,
    workPlace: workPlace.present ? workPlace.value : this.workPlace,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  TimesheetRow copyWithCompanion(TimesheetCompanion data) {
    return TimesheetRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      date: data.date.present ? data.date.value : this.date,
      dayType: data.dayType.present ? data.dayType.value : this.dayType,
      days: data.days.present ? data.days.value : this.days,
      workPlace: data.workPlace.present ? data.workPlace.value : this.workPlace,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimesheetRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('date: $date, ')
          ..write('dayType: $dayType, ')
          ..write('days: $days, ')
          ..write('workPlace: $workPlace, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    date,
    dayType,
    days,
    workPlace,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimesheetRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.date == this.date &&
          other.dayType == this.dayType &&
          other.days == this.days &&
          other.workPlace == this.workPlace &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class TimesheetCompanion extends UpdateCompanion<TimesheetRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<String> date;
  final Value<String> dayType;
  final Value<double> days;
  final Value<String?> workPlace;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const TimesheetCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.date = const Value.absent(),
    this.dayType = const Value.absent(),
    this.days = const Value.absent(),
    this.workPlace = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimesheetCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required String date,
    this.dayType = const Value.absent(),
    this.days = const Value.absent(),
    this.workPlace = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<TimesheetRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<String>? date,
    Expression<String>? dayType,
    Expression<double>? days,
    Expression<String>? workPlace,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (date != null) 'date': date,
      if (dayType != null) 'day_type': dayType,
      if (days != null) 'days': days,
      if (workPlace != null) 'work_place': workPlace,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimesheetCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<String>? date,
    Value<String>? dayType,
    Value<double>? days,
    Value<String?>? workPlace,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return TimesheetCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      date: date ?? this.date,
      dayType: dayType ?? this.dayType,
      days: days ?? this.days,
      workPlace: workPlace ?? this.workPlace,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (dayType.present) {
      map['day_type'] = Variable<String>(dayType.value);
    }
    if (days.present) {
      map['days'] = Variable<double>(days.value);
    }
    if (workPlace.present) {
      map['work_place'] = Variable<String>(workPlace.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimesheetCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('date: $date, ')
          ..write('dayType: $dayType, ')
          ..write('days: $days, ')
          ..write('workPlace: $workPlace, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _paymentDateMeta = const VerificationMeta(
    'paymentDate',
  );
  @override
  late final GeneratedColumn<String> paymentDate = GeneratedColumn<String>(
    'payment_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentTypeMeta = const VerificationMeta(
    'paymentType',
  );
  @override
  late final GeneratedColumn<String> paymentType = GeneratedColumn<String>(
    'payment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('salary'),
  );
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<String> periodStart = GeneratedColumn<String>(
    'period_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<String> periodEnd = GeneratedColumn<String>(
    'period_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentNumberMeta = const VerificationMeta(
    'documentNumber',
  );
  @override
  late final GeneratedColumn<String> documentNumber = GeneratedColumn<String>(
    'document_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    paymentDate,
    amount,
    paymentType,
    periodStart,
    periodEnd,
    paymentMethod,
    documentNumber,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('payment_date')) {
      context.handle(
        _paymentDateMeta,
        paymentDate.isAcceptableOrUnknown(
          data['payment_date']!,
          _paymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentDateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('payment_type')) {
      context.handle(
        _paymentTypeMeta,
        paymentType.isAcceptableOrUnknown(
          data['payment_type']!,
          _paymentTypeMeta,
        ),
      );
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('document_number')) {
      context.handle(
        _documentNumberMeta,
        documentNumber.isAcceptableOrUnknown(
          data['document_number']!,
          _documentNumberMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      paymentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      paymentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_type'],
      )!,
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_start'],
      ),
      periodEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_end'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      ),
      documentNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_number'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final String paymentDate;
  final double amount;
  final String paymentType;
  final String? periodStart;
  final String? periodEnd;
  final String? paymentMethod;
  final String? documentNumber;
  final String? notes;
  final String createdAt;
  const PaymentRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    this.periodStart,
    this.periodEnd,
    this.paymentMethod,
    this.documentNumber,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['payment_date'] = Variable<String>(paymentDate);
    map['amount'] = Variable<double>(amount);
    map['payment_type'] = Variable<String>(paymentType);
    if (!nullToAbsent || periodStart != null) {
      map['period_start'] = Variable<String>(periodStart);
    }
    if (!nullToAbsent || periodEnd != null) {
      map['period_end'] = Variable<String>(periodEnd);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    if (!nullToAbsent || documentNumber != null) {
      map['document_number'] = Variable<String>(documentNumber);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      paymentDate: Value(paymentDate),
      amount: Value(amount),
      paymentType: Value(paymentType),
      periodStart: periodStart == null && nullToAbsent
          ? const Value.absent()
          : Value(periodStart),
      periodEnd: periodEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(periodEnd),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      documentNumber: documentNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(documentNumber),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory PaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      paymentDate: serializer.fromJson<String>(json['paymentDate']),
      amount: serializer.fromJson<double>(json['amount']),
      paymentType: serializer.fromJson<String>(json['paymentType']),
      periodStart: serializer.fromJson<String?>(json['periodStart']),
      periodEnd: serializer.fromJson<String?>(json['periodEnd']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      documentNumber: serializer.fromJson<String?>(json['documentNumber']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'paymentDate': serializer.toJson<String>(paymentDate),
      'amount': serializer.toJson<double>(amount),
      'paymentType': serializer.toJson<String>(paymentType),
      'periodStart': serializer.toJson<String?>(periodStart),
      'periodEnd': serializer.toJson<String?>(periodEnd),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'documentNumber': serializer.toJson<String?>(documentNumber),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  PaymentRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    String? paymentDate,
    double? amount,
    String? paymentType,
    Value<String?> periodStart = const Value.absent(),
    Value<String?> periodEnd = const Value.absent(),
    Value<String?> paymentMethod = const Value.absent(),
    Value<String?> documentNumber = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
  }) => PaymentRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    paymentDate: paymentDate ?? this.paymentDate,
    amount: amount ?? this.amount,
    paymentType: paymentType ?? this.paymentType,
    periodStart: periodStart.present ? periodStart.value : this.periodStart,
    periodEnd: periodEnd.present ? periodEnd.value : this.periodEnd,
    paymentMethod: paymentMethod.present
        ? paymentMethod.value
        : this.paymentMethod,
    documentNumber: documentNumber.present
        ? documentNumber.value
        : this.documentNumber,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      paymentDate: data.paymentDate.present
          ? data.paymentDate.value
          : this.paymentDate,
      amount: data.amount.present ? data.amount.value : this.amount,
      paymentType: data.paymentType.present
          ? data.paymentType.value
          : this.paymentType,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      documentNumber: data.documentNumber.present
          ? data.documentNumber.value
          : this.documentNumber,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('amount: $amount, ')
          ..write('paymentType: $paymentType, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    paymentDate,
    amount,
    paymentType,
    periodStart,
    periodEnd,
    paymentMethod,
    documentNumber,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.paymentDate == this.paymentDate &&
          other.amount == this.amount &&
          other.paymentType == this.paymentType &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.paymentMethod == this.paymentMethod &&
          other.documentNumber == this.documentNumber &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<String> paymentDate;
  final Value<double> amount;
  final Value<String> paymentType;
  final Value<String?> periodStart;
  final Value<String?> periodEnd;
  final Value<String?> paymentMethod;
  final Value<String?> documentNumber;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.paymentDate = const Value.absent(),
    this.amount = const Value.absent(),
    this.paymentType = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required String paymentDate,
    required double amount,
    this.paymentType = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       paymentDate = Value(paymentDate),
       amount = Value(amount),
       createdAt = Value(createdAt);
  static Insertable<PaymentRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<String>? paymentDate,
    Expression<double>? amount,
    Expression<String>? paymentType,
    Expression<String>? periodStart,
    Expression<String>? periodEnd,
    Expression<String>? paymentMethod,
    Expression<String>? documentNumber,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (paymentDate != null) 'payment_date': paymentDate,
      if (amount != null) 'amount': amount,
      if (paymentType != null) 'payment_type': paymentType,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (documentNumber != null) 'document_number': documentNumber,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<String>? paymentDate,
    Value<double>? amount,
    Value<String>? paymentType,
    Value<String?>? periodStart,
    Value<String?>? periodEnd,
    Value<String?>? paymentMethod,
    Value<String?>? documentNumber,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      documentNumber: documentNumber ?? this.documentNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (paymentDate.present) {
      map['payment_date'] = Variable<String>(paymentDate.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (paymentType.present) {
      map['payment_type'] = Variable<String>(paymentType.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<String>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<String>(periodEnd.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (documentNumber.present) {
      map['document_number'] = Variable<String>(documentNumber.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('amount: $amount, ')
          ..write('paymentType: $paymentType, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SickLeaveTable extends SickLeave
    with TableInfo<$SickLeaveTable, SickLeaveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SickLeaveTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentNumberMeta = const VerificationMeta(
    'documentNumber',
  );
  @override
  late final GeneratedColumn<String> documentNumber = GeneratedColumn<String>(
    'document_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _daysCountMeta = const VerificationMeta(
    'daysCount',
  );
  @override
  late final GeneratedColumn<int> daysCount = GeneratedColumn<int>(
    'days_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidByEmployerMeta = const VerificationMeta(
    'paidByEmployer',
  );
  @override
  late final GeneratedColumn<double> paidByEmployer = GeneratedColumn<double>(
    'paid_by_employer',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidByFssMeta = const VerificationMeta(
    'paidByFss',
  );
  @override
  late final GeneratedColumn<double> paidByFss = GeneratedColumn<double>(
    'paid_by_fss',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    startDate,
    endDate,
    documentNumber,
    daysCount,
    paidByEmployer,
    paidByFss,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sick_leave';
  @override
  VerificationContext validateIntegrity(
    Insertable<SickLeaveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('document_number')) {
      context.handle(
        _documentNumberMeta,
        documentNumber.isAcceptableOrUnknown(
          data['document_number']!,
          _documentNumberMeta,
        ),
      );
    }
    if (data.containsKey('days_count')) {
      context.handle(
        _daysCountMeta,
        daysCount.isAcceptableOrUnknown(data['days_count']!, _daysCountMeta),
      );
    } else if (isInserting) {
      context.missing(_daysCountMeta);
    }
    if (data.containsKey('paid_by_employer')) {
      context.handle(
        _paidByEmployerMeta,
        paidByEmployer.isAcceptableOrUnknown(
          data['paid_by_employer']!,
          _paidByEmployerMeta,
        ),
      );
    }
    if (data.containsKey('paid_by_fss')) {
      context.handle(
        _paidByFssMeta,
        paidByFss.isAcceptableOrUnknown(data['paid_by_fss']!, _paidByFssMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  SickLeaveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SickLeaveRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
      documentNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_number'],
      ),
      daysCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_count'],
      )!,
      paidByEmployer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}paid_by_employer'],
      ),
      paidByFss: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}paid_by_fss'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $SickLeaveTable createAlias(String alias) {
    return $SickLeaveTable(attachedDatabase, alias);
  }
}

class SickLeaveRow extends DataClass implements Insertable<SickLeaveRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final String startDate;
  final String endDate;
  final String? documentNumber;
  final int daysCount;
  final double? paidByEmployer;
  final double? paidByFss;
  final String? notes;
  const SickLeaveRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.startDate,
    required this.endDate,
    this.documentNumber,
    required this.daysCount,
    this.paidByEmployer,
    this.paidByFss,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    if (!nullToAbsent || documentNumber != null) {
      map['document_number'] = Variable<String>(documentNumber);
    }
    map['days_count'] = Variable<int>(daysCount);
    if (!nullToAbsent || paidByEmployer != null) {
      map['paid_by_employer'] = Variable<double>(paidByEmployer);
    }
    if (!nullToAbsent || paidByFss != null) {
      map['paid_by_fss'] = Variable<double>(paidByFss);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SickLeaveCompanion toCompanion(bool nullToAbsent) {
    return SickLeaveCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      startDate: Value(startDate),
      endDate: Value(endDate),
      documentNumber: documentNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(documentNumber),
      daysCount: Value(daysCount),
      paidByEmployer: paidByEmployer == null && nullToAbsent
          ? const Value.absent()
          : Value(paidByEmployer),
      paidByFss: paidByFss == null && nullToAbsent
          ? const Value.absent()
          : Value(paidByFss),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory SickLeaveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SickLeaveRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
      documentNumber: serializer.fromJson<String?>(json['documentNumber']),
      daysCount: serializer.fromJson<int>(json['daysCount']),
      paidByEmployer: serializer.fromJson<double?>(json['paidByEmployer']),
      paidByFss: serializer.fromJson<double?>(json['paidByFss']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
      'documentNumber': serializer.toJson<String?>(documentNumber),
      'daysCount': serializer.toJson<int>(daysCount),
      'paidByEmployer': serializer.toJson<double?>(paidByEmployer),
      'paidByFss': serializer.toJson<double?>(paidByFss),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SickLeaveRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    String? startDate,
    String? endDate,
    Value<String?> documentNumber = const Value.absent(),
    int? daysCount,
    Value<double?> paidByEmployer = const Value.absent(),
    Value<double?> paidByFss = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => SickLeaveRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    documentNumber: documentNumber.present
        ? documentNumber.value
        : this.documentNumber,
    daysCount: daysCount ?? this.daysCount,
    paidByEmployer: paidByEmployer.present
        ? paidByEmployer.value
        : this.paidByEmployer,
    paidByFss: paidByFss.present ? paidByFss.value : this.paidByFss,
    notes: notes.present ? notes.value : this.notes,
  );
  SickLeaveRow copyWithCompanion(SickLeaveCompanion data) {
    return SickLeaveRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      documentNumber: data.documentNumber.present
          ? data.documentNumber.value
          : this.documentNumber,
      daysCount: data.daysCount.present ? data.daysCount.value : this.daysCount,
      paidByEmployer: data.paidByEmployer.present
          ? data.paidByEmployer.value
          : this.paidByEmployer,
      paidByFss: data.paidByFss.present ? data.paidByFss.value : this.paidByFss,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SickLeaveRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('daysCount: $daysCount, ')
          ..write('paidByEmployer: $paidByEmployer, ')
          ..write('paidByFss: $paidByFss, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    startDate,
    endDate,
    documentNumber,
    daysCount,
    paidByEmployer,
    paidByFss,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SickLeaveRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.documentNumber == this.documentNumber &&
          other.daysCount == this.daysCount &&
          other.paidByEmployer == this.paidByEmployer &&
          other.paidByFss == this.paidByFss &&
          other.notes == this.notes);
}

class SickLeaveCompanion extends UpdateCompanion<SickLeaveRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<String?> documentNumber;
  final Value<int> daysCount;
  final Value<double?> paidByEmployer;
  final Value<double?> paidByFss;
  final Value<String?> notes;
  final Value<int> rowid;
  const SickLeaveCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.daysCount = const Value.absent(),
    this.paidByEmployer = const Value.absent(),
    this.paidByFss = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SickLeaveCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required String startDate,
    required String endDate,
    this.documentNumber = const Value.absent(),
    required int daysCount,
    this.paidByEmployer = const Value.absent(),
    this.paidByFss = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       startDate = Value(startDate),
       endDate = Value(endDate),
       daysCount = Value(daysCount);
  static Insertable<SickLeaveRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<String>? documentNumber,
    Expression<int>? daysCount,
    Expression<double>? paidByEmployer,
    Expression<double>? paidByFss,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (documentNumber != null) 'document_number': documentNumber,
      if (daysCount != null) 'days_count': daysCount,
      if (paidByEmployer != null) 'paid_by_employer': paidByEmployer,
      if (paidByFss != null) 'paid_by_fss': paidByFss,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SickLeaveCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<String?>? documentNumber,
    Value<int>? daysCount,
    Value<double?>? paidByEmployer,
    Value<double?>? paidByFss,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return SickLeaveCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      documentNumber: documentNumber ?? this.documentNumber,
      daysCount: daysCount ?? this.daysCount,
      paidByEmployer: paidByEmployer ?? this.paidByEmployer,
      paidByFss: paidByFss ?? this.paidByFss,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (documentNumber.present) {
      map['document_number'] = Variable<String>(documentNumber.value);
    }
    if (daysCount.present) {
      map['days_count'] = Variable<int>(daysCount.value);
    }
    if (paidByEmployer.present) {
      map['paid_by_employer'] = Variable<double>(paidByEmployer.value);
    }
    if (paidByFss.present) {
      map['paid_by_fss'] = Variable<double>(paidByFss.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SickLeaveCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('daysCount: $daysCount, ')
          ..write('paidByEmployer: $paidByEmployer, ')
          ..write('paidByFss: $paidByFss, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VacationTable extends Vacation
    with TableInfo<$VacationTable, VacationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VacationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vacationTypeMeta = const VerificationMeta(
    'vacationType',
  );
  @override
  late final GeneratedColumn<String> vacationType = GeneratedColumn<String>(
    'vacation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('annual'),
  );
  static const VerificationMeta _daysCountMeta = const VerificationMeta(
    'daysCount',
  );
  @override
  late final GeneratedColumn<int> daysCount = GeneratedColumn<int>(
    'days_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isApprovedMeta = const VerificationMeta(
    'isApproved',
  );
  @override
  late final GeneratedColumn<bool> isApproved = GeneratedColumn<bool>(
    'is_approved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_approved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    startDate,
    endDate,
    vacationType,
    daysCount,
    isApproved,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vacation';
  @override
  VerificationContext validateIntegrity(
    Insertable<VacationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('vacation_type')) {
      context.handle(
        _vacationTypeMeta,
        vacationType.isAcceptableOrUnknown(
          data['vacation_type']!,
          _vacationTypeMeta,
        ),
      );
    }
    if (data.containsKey('days_count')) {
      context.handle(
        _daysCountMeta,
        daysCount.isAcceptableOrUnknown(data['days_count']!, _daysCountMeta),
      );
    } else if (isInserting) {
      context.missing(_daysCountMeta);
    }
    if (data.containsKey('is_approved')) {
      context.handle(
        _isApprovedMeta,
        isApproved.isAcceptableOrUnknown(data['is_approved']!, _isApprovedMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  VacationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VacationRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
      vacationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vacation_type'],
      )!,
      daysCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_count'],
      )!,
      isApproved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_approved'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $VacationTable createAlias(String alias) {
    return $VacationTable(attachedDatabase, alias);
  }
}

class VacationRow extends DataClass implements Insertable<VacationRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final String startDate;
  final String endDate;
  final String vacationType;
  final int daysCount;
  final bool isApproved;
  final String? notes;
  const VacationRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.startDate,
    required this.endDate,
    required this.vacationType,
    required this.daysCount,
    required this.isApproved,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    map['vacation_type'] = Variable<String>(vacationType);
    map['days_count'] = Variable<int>(daysCount);
    map['is_approved'] = Variable<bool>(isApproved);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  VacationCompanion toCompanion(bool nullToAbsent) {
    return VacationCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      startDate: Value(startDate),
      endDate: Value(endDate),
      vacationType: Value(vacationType),
      daysCount: Value(daysCount),
      isApproved: Value(isApproved),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory VacationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VacationRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
      vacationType: serializer.fromJson<String>(json['vacationType']),
      daysCount: serializer.fromJson<int>(json['daysCount']),
      isApproved: serializer.fromJson<bool>(json['isApproved']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
      'vacationType': serializer.toJson<String>(vacationType),
      'daysCount': serializer.toJson<int>(daysCount),
      'isApproved': serializer.toJson<bool>(isApproved),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  VacationRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    String? startDate,
    String? endDate,
    String? vacationType,
    int? daysCount,
    bool? isApproved,
    Value<String?> notes = const Value.absent(),
  }) => VacationRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    vacationType: vacationType ?? this.vacationType,
    daysCount: daysCount ?? this.daysCount,
    isApproved: isApproved ?? this.isApproved,
    notes: notes.present ? notes.value : this.notes,
  );
  VacationRow copyWithCompanion(VacationCompanion data) {
    return VacationRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      vacationType: data.vacationType.present
          ? data.vacationType.value
          : this.vacationType,
      daysCount: data.daysCount.present ? data.daysCount.value : this.daysCount,
      isApproved: data.isApproved.present
          ? data.isApproved.value
          : this.isApproved,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VacationRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('vacationType: $vacationType, ')
          ..write('daysCount: $daysCount, ')
          ..write('isApproved: $isApproved, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    startDate,
    endDate,
    vacationType,
    daysCount,
    isApproved,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VacationRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.vacationType == this.vacationType &&
          other.daysCount == this.daysCount &&
          other.isApproved == this.isApproved &&
          other.notes == this.notes);
}

class VacationCompanion extends UpdateCompanion<VacationRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<String> vacationType;
  final Value<int> daysCount;
  final Value<bool> isApproved;
  final Value<String?> notes;
  final Value<int> rowid;
  const VacationCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.vacationType = const Value.absent(),
    this.daysCount = const Value.absent(),
    this.isApproved = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VacationCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required String startDate,
    required String endDate,
    this.vacationType = const Value.absent(),
    required int daysCount,
    this.isApproved = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       startDate = Value(startDate),
       endDate = Value(endDate),
       daysCount = Value(daysCount);
  static Insertable<VacationRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<String>? vacationType,
    Expression<int>? daysCount,
    Expression<bool>? isApproved,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (vacationType != null) 'vacation_type': vacationType,
      if (daysCount != null) 'days_count': daysCount,
      if (isApproved != null) 'is_approved': isApproved,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VacationCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<String>? vacationType,
    Value<int>? daysCount,
    Value<bool>? isApproved,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return VacationCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      vacationType: vacationType ?? this.vacationType,
      daysCount: daysCount ?? this.daysCount,
      isApproved: isApproved ?? this.isApproved,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (vacationType.present) {
      map['vacation_type'] = Variable<String>(vacationType.value);
    }
    if (daysCount.present) {
      map['days_count'] = Variable<int>(daysCount.value);
    }
    if (isApproved.present) {
      map['is_approved'] = Variable<bool>(isApproved.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VacationCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('vacationType: $vacationType, ')
          ..write('daysCount: $daysCount, ')
          ..write('isApproved: $isApproved, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayrollResultsTable extends PayrollResults
    with TableInfo<$PayrollResultsTable, PayrollResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayrollResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<int> legacyId = GeneratedColumn<int>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedByMeta = const VerificationMeta(
    'editedBy',
  );
  @override
  late final GeneratedColumn<String> editedBy = GeneratedColumn<String>(
    'edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _employeeUuidMeta = const VerificationMeta(
    'employeeUuid',
  );
  @override
  late final GeneratedColumn<String> employeeUuid = GeneratedColumn<String>(
    'employee_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (uuid) DEFERRABLE INITIALLY DEFERRED',
    ),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseDaysMeta = const VerificationMeta(
    'baseDays',
  );
  @override
  late final GeneratedColumn<double> baseDays = GeneratedColumn<double>(
    'base_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _fieldDaysMeta = const VerificationMeta(
    'fieldDays',
  );
  @override
  late final GeneratedColumn<double> fieldDays = GeneratedColumn<double>(
    'field_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _sickDaysMeta = const VerificationMeta(
    'sickDays',
  );
  @override
  late final GeneratedColumn<double> sickDays = GeneratedColumn<double>(
    'sick_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _vacationDaysMeta = const VerificationMeta(
    'vacationDays',
  );
  @override
  late final GeneratedColumn<double> vacationDays = GeneratedColumn<double>(
    'vacation_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _totalSalaryMeta = const VerificationMeta(
    'totalSalary',
  );
  @override
  late final GeneratedColumn<double> totalSalary = GeneratedColumn<double>(
    'total_salary',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _baseRateUsedMeta = const VerificationMeta(
    'baseRateUsed',
  );
  @override
  late final GeneratedColumn<double> baseRateUsed = GeneratedColumn<double>(
    'base_rate_used',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldRateUsedMeta = const VerificationMeta(
    'fieldRateUsed',
  );
  @override
  late final GeneratedColumn<double> fieldRateUsed = GeneratedColumn<double>(
    'field_rate_used',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calculatedAtMeta = const VerificationMeta(
    'calculatedAt',
  );
  @override
  late final GeneratedColumn<String> calculatedAt = GeneratedColumn<String>(
    'calculated_at',
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
    defaultValue: const Constant('calculated'),
  );
  static const VerificationMeta _skippedWorkDaysMeta = const VerificationMeta(
    'skippedWorkDays',
  );
  @override
  late final GeneratedColumn<int> skippedWorkDays = GeneratedColumn<int>(
    'skipped_work_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    year,
    month,
    baseDays,
    fieldDays,
    sickDays,
    vacationDays,
    totalSalary,
    baseRateUsed,
    fieldRateUsed,
    calculatedAt,
    status,
    skippedWorkDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payroll_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayrollResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('edited_by')) {
      context.handle(
        _editedByMeta,
        editedBy.isAcceptableOrUnknown(data['edited_by']!, _editedByMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('employee_uuid')) {
      context.handle(
        _employeeUuidMeta,
        employeeUuid.isAcceptableOrUnknown(
          data['employee_uuid']!,
          _employeeUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_employeeUuidMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('base_days')) {
      context.handle(
        _baseDaysMeta,
        baseDays.isAcceptableOrUnknown(data['base_days']!, _baseDaysMeta),
      );
    }
    if (data.containsKey('field_days')) {
      context.handle(
        _fieldDaysMeta,
        fieldDays.isAcceptableOrUnknown(data['field_days']!, _fieldDaysMeta),
      );
    }
    if (data.containsKey('sick_days')) {
      context.handle(
        _sickDaysMeta,
        sickDays.isAcceptableOrUnknown(data['sick_days']!, _sickDaysMeta),
      );
    }
    if (data.containsKey('vacation_days')) {
      context.handle(
        _vacationDaysMeta,
        vacationDays.isAcceptableOrUnknown(
          data['vacation_days']!,
          _vacationDaysMeta,
        ),
      );
    }
    if (data.containsKey('total_salary')) {
      context.handle(
        _totalSalaryMeta,
        totalSalary.isAcceptableOrUnknown(
          data['total_salary']!,
          _totalSalaryMeta,
        ),
      );
    }
    if (data.containsKey('base_rate_used')) {
      context.handle(
        _baseRateUsedMeta,
        baseRateUsed.isAcceptableOrUnknown(
          data['base_rate_used']!,
          _baseRateUsedMeta,
        ),
      );
    }
    if (data.containsKey('field_rate_used')) {
      context.handle(
        _fieldRateUsedMeta,
        fieldRateUsed.isAcceptableOrUnknown(
          data['field_rate_used']!,
          _fieldRateUsedMeta,
        ),
      );
    }
    if (data.containsKey('calculated_at')) {
      context.handle(
        _calculatedAtMeta,
        calculatedAt.isAcceptableOrUnknown(
          data['calculated_at']!,
          _calculatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calculatedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('skipped_work_days')) {
      context.handle(
        _skippedWorkDaysMeta,
        skippedWorkDays.isAcceptableOrUnknown(
          data['skipped_work_days']!,
          _skippedWorkDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  PayrollResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayrollResultRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      editedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edited_by'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      employeeUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_uuid'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      baseDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_days'],
      )!,
      fieldDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}field_days'],
      )!,
      sickDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sick_days'],
      )!,
      vacationDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vacation_days'],
      )!,
      totalSalary: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_salary'],
      )!,
      baseRateUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_rate_used'],
      ),
      fieldRateUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}field_rate_used'],
      ),
      calculatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calculated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      skippedWorkDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped_work_days'],
      )!,
    );
  }

  @override
  $PayrollResultsTable createAlias(String alias) {
    return $PayrollResultsTable(attachedDatabase, alias);
  }
}

class PayrollResultRow extends DataClass
    implements Insertable<PayrollResultRow> {
  final String uuid;

  /// `id` строки в старой базе v8 — для сверки после переноса.
  final int? legacyId;
  final DateTime updatedAt;
  final bool deleted;

  /// Кто изменил запись последним: пока — id устройства.
  final String? editedBy;

  /// `updated_at` версии, полученной с сервера (этап 3).
  final DateTime? remoteUpdatedAt;
  final String employeeUuid;
  final int year;
  final int month;
  final double baseDays;
  final double fieldDays;
  final double sickDays;
  final double vacationDays;
  final double totalSalary;
  final double? baseRateUsed;
  final double? fieldRateUsed;
  final String calculatedAt;

  /// `calculated` | `verified` | `discrepancy`
  final String status;
  final int skippedWorkDays;
  const PayrollResultRow({
    required this.uuid,
    this.legacyId,
    required this.updatedAt,
    required this.deleted,
    this.editedBy,
    this.remoteUpdatedAt,
    required this.employeeUuid,
    required this.year,
    required this.month,
    required this.baseDays,
    required this.fieldDays,
    required this.sickDays,
    required this.vacationDays,
    required this.totalSalary,
    this.baseRateUsed,
    this.fieldRateUsed,
    required this.calculatedAt,
    required this.status,
    required this.skippedWorkDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<int>(legacyId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || editedBy != null) {
      map['edited_by'] = Variable<String>(editedBy);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['employee_uuid'] = Variable<String>(employeeUuid);
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['base_days'] = Variable<double>(baseDays);
    map['field_days'] = Variable<double>(fieldDays);
    map['sick_days'] = Variable<double>(sickDays);
    map['vacation_days'] = Variable<double>(vacationDays);
    map['total_salary'] = Variable<double>(totalSalary);
    if (!nullToAbsent || baseRateUsed != null) {
      map['base_rate_used'] = Variable<double>(baseRateUsed);
    }
    if (!nullToAbsent || fieldRateUsed != null) {
      map['field_rate_used'] = Variable<double>(fieldRateUsed);
    }
    map['calculated_at'] = Variable<String>(calculatedAt);
    map['status'] = Variable<String>(status);
    map['skipped_work_days'] = Variable<int>(skippedWorkDays);
    return map;
  }

  PayrollResultsCompanion toCompanion(bool nullToAbsent) {
    return PayrollResultsCompanion(
      uuid: Value(uuid),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      editedBy: editedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(editedBy),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      employeeUuid: Value(employeeUuid),
      year: Value(year),
      month: Value(month),
      baseDays: Value(baseDays),
      fieldDays: Value(fieldDays),
      sickDays: Value(sickDays),
      vacationDays: Value(vacationDays),
      totalSalary: Value(totalSalary),
      baseRateUsed: baseRateUsed == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRateUsed),
      fieldRateUsed: fieldRateUsed == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldRateUsed),
      calculatedAt: Value(calculatedAt),
      status: Value(status),
      skippedWorkDays: Value(skippedWorkDays),
    );
  }

  factory PayrollResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayrollResultRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      legacyId: serializer.fromJson<int?>(json['legacyId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      editedBy: serializer.fromJson<String?>(json['editedBy']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      employeeUuid: serializer.fromJson<String>(json['employeeUuid']),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      baseDays: serializer.fromJson<double>(json['baseDays']),
      fieldDays: serializer.fromJson<double>(json['fieldDays']),
      sickDays: serializer.fromJson<double>(json['sickDays']),
      vacationDays: serializer.fromJson<double>(json['vacationDays']),
      totalSalary: serializer.fromJson<double>(json['totalSalary']),
      baseRateUsed: serializer.fromJson<double?>(json['baseRateUsed']),
      fieldRateUsed: serializer.fromJson<double?>(json['fieldRateUsed']),
      calculatedAt: serializer.fromJson<String>(json['calculatedAt']),
      status: serializer.fromJson<String>(json['status']),
      skippedWorkDays: serializer.fromJson<int>(json['skippedWorkDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'legacyId': serializer.toJson<int?>(legacyId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'editedBy': serializer.toJson<String?>(editedBy),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'employeeUuid': serializer.toJson<String>(employeeUuid),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'baseDays': serializer.toJson<double>(baseDays),
      'fieldDays': serializer.toJson<double>(fieldDays),
      'sickDays': serializer.toJson<double>(sickDays),
      'vacationDays': serializer.toJson<double>(vacationDays),
      'totalSalary': serializer.toJson<double>(totalSalary),
      'baseRateUsed': serializer.toJson<double?>(baseRateUsed),
      'fieldRateUsed': serializer.toJson<double?>(fieldRateUsed),
      'calculatedAt': serializer.toJson<String>(calculatedAt),
      'status': serializer.toJson<String>(status),
      'skippedWorkDays': serializer.toJson<int>(skippedWorkDays),
    };
  }

  PayrollResultRow copyWith({
    String? uuid,
    Value<int?> legacyId = const Value.absent(),
    DateTime? updatedAt,
    bool? deleted,
    Value<String?> editedBy = const Value.absent(),
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? employeeUuid,
    int? year,
    int? month,
    double? baseDays,
    double? fieldDays,
    double? sickDays,
    double? vacationDays,
    double? totalSalary,
    Value<double?> baseRateUsed = const Value.absent(),
    Value<double?> fieldRateUsed = const Value.absent(),
    String? calculatedAt,
    String? status,
    int? skippedWorkDays,
  }) => PayrollResultRow(
    uuid: uuid ?? this.uuid,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    editedBy: editedBy.present ? editedBy.value : this.editedBy,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    employeeUuid: employeeUuid ?? this.employeeUuid,
    year: year ?? this.year,
    month: month ?? this.month,
    baseDays: baseDays ?? this.baseDays,
    fieldDays: fieldDays ?? this.fieldDays,
    sickDays: sickDays ?? this.sickDays,
    vacationDays: vacationDays ?? this.vacationDays,
    totalSalary: totalSalary ?? this.totalSalary,
    baseRateUsed: baseRateUsed.present ? baseRateUsed.value : this.baseRateUsed,
    fieldRateUsed: fieldRateUsed.present
        ? fieldRateUsed.value
        : this.fieldRateUsed,
    calculatedAt: calculatedAt ?? this.calculatedAt,
    status: status ?? this.status,
    skippedWorkDays: skippedWorkDays ?? this.skippedWorkDays,
  );
  PayrollResultRow copyWithCompanion(PayrollResultsCompanion data) {
    return PayrollResultRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      editedBy: data.editedBy.present ? data.editedBy.value : this.editedBy,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      employeeUuid: data.employeeUuid.present
          ? data.employeeUuid.value
          : this.employeeUuid,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      baseDays: data.baseDays.present ? data.baseDays.value : this.baseDays,
      fieldDays: data.fieldDays.present ? data.fieldDays.value : this.fieldDays,
      sickDays: data.sickDays.present ? data.sickDays.value : this.sickDays,
      vacationDays: data.vacationDays.present
          ? data.vacationDays.value
          : this.vacationDays,
      totalSalary: data.totalSalary.present
          ? data.totalSalary.value
          : this.totalSalary,
      baseRateUsed: data.baseRateUsed.present
          ? data.baseRateUsed.value
          : this.baseRateUsed,
      fieldRateUsed: data.fieldRateUsed.present
          ? data.fieldRateUsed.value
          : this.fieldRateUsed,
      calculatedAt: data.calculatedAt.present
          ? data.calculatedAt.value
          : this.calculatedAt,
      status: data.status.present ? data.status.value : this.status,
      skippedWorkDays: data.skippedWorkDays.present
          ? data.skippedWorkDays.value
          : this.skippedWorkDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayrollResultRow(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('baseDays: $baseDays, ')
          ..write('fieldDays: $fieldDays, ')
          ..write('sickDays: $sickDays, ')
          ..write('vacationDays: $vacationDays, ')
          ..write('totalSalary: $totalSalary, ')
          ..write('baseRateUsed: $baseRateUsed, ')
          ..write('fieldRateUsed: $fieldRateUsed, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('status: $status, ')
          ..write('skippedWorkDays: $skippedWorkDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    legacyId,
    updatedAt,
    deleted,
    editedBy,
    remoteUpdatedAt,
    employeeUuid,
    year,
    month,
    baseDays,
    fieldDays,
    sickDays,
    vacationDays,
    totalSalary,
    baseRateUsed,
    fieldRateUsed,
    calculatedAt,
    status,
    skippedWorkDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayrollResultRow &&
          other.uuid == this.uuid &&
          other.legacyId == this.legacyId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.editedBy == this.editedBy &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.employeeUuid == this.employeeUuid &&
          other.year == this.year &&
          other.month == this.month &&
          other.baseDays == this.baseDays &&
          other.fieldDays == this.fieldDays &&
          other.sickDays == this.sickDays &&
          other.vacationDays == this.vacationDays &&
          other.totalSalary == this.totalSalary &&
          other.baseRateUsed == this.baseRateUsed &&
          other.fieldRateUsed == this.fieldRateUsed &&
          other.calculatedAt == this.calculatedAt &&
          other.status == this.status &&
          other.skippedWorkDays == this.skippedWorkDays);
}

class PayrollResultsCompanion extends UpdateCompanion<PayrollResultRow> {
  final Value<String> uuid;
  final Value<int?> legacyId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<String?> editedBy;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> employeeUuid;
  final Value<int> year;
  final Value<int> month;
  final Value<double> baseDays;
  final Value<double> fieldDays;
  final Value<double> sickDays;
  final Value<double> vacationDays;
  final Value<double> totalSalary;
  final Value<double?> baseRateUsed;
  final Value<double?> fieldRateUsed;
  final Value<String> calculatedAt;
  final Value<String> status;
  final Value<int> skippedWorkDays;
  final Value<int> rowid;
  const PayrollResultsCompanion({
    this.uuid = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.employeeUuid = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.baseDays = const Value.absent(),
    this.fieldDays = const Value.absent(),
    this.sickDays = const Value.absent(),
    this.vacationDays = const Value.absent(),
    this.totalSalary = const Value.absent(),
    this.baseRateUsed = const Value.absent(),
    this.fieldRateUsed = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.skippedWorkDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayrollResultsCompanion.insert({
    required String uuid,
    this.legacyId = const Value.absent(),
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.editedBy = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String employeeUuid,
    required int year,
    required int month,
    this.baseDays = const Value.absent(),
    this.fieldDays = const Value.absent(),
    this.sickDays = const Value.absent(),
    this.vacationDays = const Value.absent(),
    this.totalSalary = const Value.absent(),
    this.baseRateUsed = const Value.absent(),
    this.fieldRateUsed = const Value.absent(),
    required String calculatedAt,
    this.status = const Value.absent(),
    this.skippedWorkDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       updatedAt = Value(updatedAt),
       employeeUuid = Value(employeeUuid),
       year = Value(year),
       month = Value(month),
       calculatedAt = Value(calculatedAt);
  static Insertable<PayrollResultRow> custom({
    Expression<String>? uuid,
    Expression<int>? legacyId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<String>? editedBy,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? employeeUuid,
    Expression<int>? year,
    Expression<int>? month,
    Expression<double>? baseDays,
    Expression<double>? fieldDays,
    Expression<double>? sickDays,
    Expression<double>? vacationDays,
    Expression<double>? totalSalary,
    Expression<double>? baseRateUsed,
    Expression<double>? fieldRateUsed,
    Expression<String>? calculatedAt,
    Expression<String>? status,
    Expression<int>? skippedWorkDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (legacyId != null) 'legacy_id': legacyId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (editedBy != null) 'edited_by': editedBy,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (employeeUuid != null) 'employee_uuid': employeeUuid,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (baseDays != null) 'base_days': baseDays,
      if (fieldDays != null) 'field_days': fieldDays,
      if (sickDays != null) 'sick_days': sickDays,
      if (vacationDays != null) 'vacation_days': vacationDays,
      if (totalSalary != null) 'total_salary': totalSalary,
      if (baseRateUsed != null) 'base_rate_used': baseRateUsed,
      if (fieldRateUsed != null) 'field_rate_used': fieldRateUsed,
      if (calculatedAt != null) 'calculated_at': calculatedAt,
      if (status != null) 'status': status,
      if (skippedWorkDays != null) 'skipped_work_days': skippedWorkDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayrollResultsCompanion copyWith({
    Value<String>? uuid,
    Value<int?>? legacyId,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<String?>? editedBy,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? employeeUuid,
    Value<int>? year,
    Value<int>? month,
    Value<double>? baseDays,
    Value<double>? fieldDays,
    Value<double>? sickDays,
    Value<double>? vacationDays,
    Value<double>? totalSalary,
    Value<double?>? baseRateUsed,
    Value<double?>? fieldRateUsed,
    Value<String>? calculatedAt,
    Value<String>? status,
    Value<int>? skippedWorkDays,
    Value<int>? rowid,
  }) {
    return PayrollResultsCompanion(
      uuid: uuid ?? this.uuid,
      legacyId: legacyId ?? this.legacyId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      editedBy: editedBy ?? this.editedBy,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      employeeUuid: employeeUuid ?? this.employeeUuid,
      year: year ?? this.year,
      month: month ?? this.month,
      baseDays: baseDays ?? this.baseDays,
      fieldDays: fieldDays ?? this.fieldDays,
      sickDays: sickDays ?? this.sickDays,
      vacationDays: vacationDays ?? this.vacationDays,
      totalSalary: totalSalary ?? this.totalSalary,
      baseRateUsed: baseRateUsed ?? this.baseRateUsed,
      fieldRateUsed: fieldRateUsed ?? this.fieldRateUsed,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      status: status ?? this.status,
      skippedWorkDays: skippedWorkDays ?? this.skippedWorkDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<int>(legacyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (editedBy.present) {
      map['edited_by'] = Variable<String>(editedBy.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (employeeUuid.present) {
      map['employee_uuid'] = Variable<String>(employeeUuid.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (baseDays.present) {
      map['base_days'] = Variable<double>(baseDays.value);
    }
    if (fieldDays.present) {
      map['field_days'] = Variable<double>(fieldDays.value);
    }
    if (sickDays.present) {
      map['sick_days'] = Variable<double>(sickDays.value);
    }
    if (vacationDays.present) {
      map['vacation_days'] = Variable<double>(vacationDays.value);
    }
    if (totalSalary.present) {
      map['total_salary'] = Variable<double>(totalSalary.value);
    }
    if (baseRateUsed.present) {
      map['base_rate_used'] = Variable<double>(baseRateUsed.value);
    }
    if (fieldRateUsed.present) {
      map['field_rate_used'] = Variable<double>(fieldRateUsed.value);
    }
    if (calculatedAt.present) {
      map['calculated_at'] = Variable<String>(calculatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (skippedWorkDays.present) {
      map['skipped_work_days'] = Variable<int>(skippedWorkDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayrollResultsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('legacyId: $legacyId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('editedBy: $editedBy, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('employeeUuid: $employeeUuid, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('baseDays: $baseDays, ')
          ..write('fieldDays: $fieldDays, ')
          ..write('sickDays: $sickDays, ')
          ..write('vacationDays: $vacationDays, ')
          ..write('totalSalary: $totalSalary, ')
          ..write('baseRateUsed: $baseRateUsed, ')
          ..write('fieldRateUsed: $fieldRateUsed, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('status: $status, ')
          ..write('skippedWorkDays: $skippedWorkDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingChangesTable extends PendingChanges
    with TableInfo<$PendingChangesTable, PendingChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingChangesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTableMeta = const VerificationMeta(
    'entityTable',
  );
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
    'entity_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityUuidMeta = const VerificationMeta(
    'entityUuid',
  );
  @override
  late final GeneratedColumn<String> entityUuid = GeneratedColumn<String>(
    'entity_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
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
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityTable,
    entityUuid,
    operation,
    payload,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_table')) {
      context.handle(
        _entityTableMeta,
        entityTable.isAcceptableOrUnknown(
          data['entity_table']!,
          _entityTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('entity_uuid')) {
      context.handle(
        _entityUuidMeta,
        entityUuid.isAcceptableOrUnknown(data['entity_uuid']!, _entityUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_entityUuidMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
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
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingChangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_table'],
      )!,
      entityUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_uuid'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingChangesTable createAlias(String alias) {
    return $PendingChangesTable(attachedDatabase, alias);
  }
}

class PendingChangeRow extends DataClass
    implements Insertable<PendingChangeRow> {
  final int id;
  final String entityTable;
  final String entityUuid;

  /// `upsert` | `delete`
  final String operation;

  /// Снимок записи в JSON на момент изменения.
  final String? payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const PendingChangeRow({
    required this.id,
    required this.entityTable,
    required this.entityUuid,
    required this.operation,
    this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_table'] = Variable<String>(entityTable);
    map['entity_uuid'] = Variable<String>(entityUuid);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingChangesCompanion toCompanion(bool nullToAbsent) {
    return PendingChangesCompanion(
      id: Value(id),
      entityTable: Value(entityTable),
      entityUuid: Value(entityUuid),
      operation: Value(operation),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingChangeRow(
      id: serializer.fromJson<int>(json['id']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      entityUuid: serializer.fromJson<String>(json['entityUuid']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityTable': serializer.toJson<String>(entityTable),
      'entityUuid': serializer.toJson<String>(entityUuid),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingChangeRow copyWith({
    int? id,
    String? entityTable,
    String? entityUuid,
    String? operation,
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => PendingChangeRow(
    id: id ?? this.id,
    entityTable: entityTable ?? this.entityTable,
    entityUuid: entityUuid ?? this.entityUuid,
    operation: operation ?? this.operation,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingChangeRow copyWithCompanion(PendingChangesCompanion data) {
    return PendingChangeRow(
      id: data.id.present ? data.id.value : this.id,
      entityTable: data.entityTable.present
          ? data.entityTable.value
          : this.entityTable,
      entityUuid: data.entityUuid.present
          ? data.entityUuid.value
          : this.entityUuid,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingChangeRow(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('entityUuid: $entityUuid, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityTable,
    entityUuid,
    operation,
    payload,
    createdAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingChangeRow &&
          other.id == this.id &&
          other.entityTable == this.entityTable &&
          other.entityUuid == this.entityUuid &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingChangesCompanion extends UpdateCompanion<PendingChangeRow> {
  final Value<int> id;
  final Value<String> entityTable;
  final Value<String> entityUuid;
  final Value<String> operation;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PendingChangesCompanion({
    this.id = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.entityUuid = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingChangesCompanion.insert({
    this.id = const Value.absent(),
    required String entityTable,
    required String entityUuid,
    required String operation,
    this.payload = const Value.absent(),
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : entityTable = Value(entityTable),
       entityUuid = Value(entityUuid),
       operation = Value(operation),
       createdAt = Value(createdAt);
  static Insertable<PendingChangeRow> custom({
    Expression<int>? id,
    Expression<String>? entityTable,
    Expression<String>? entityUuid,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityTable != null) 'entity_table': entityTable,
      if (entityUuid != null) 'entity_uuid': entityUuid,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? entityTable,
    Value<String>? entityUuid,
    Value<String>? operation,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return PendingChangesCompanion(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      entityUuid: entityUuid ?? this.entityUuid,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (entityUuid.present) {
      map['entity_uuid'] = Variable<String>(entityUuid.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingChangesCompanion(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('entityUuid: $entityUuid, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $CompanySettingsTable companySettings = $CompanySettingsTable(
    this,
  );
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $EmployeeRatesTable employeeRates = $EmployeeRatesTable(this);
  late final $TimesheetTable timesheet = $TimesheetTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $SickLeaveTable sickLeave = $SickLeaveTable(this);
  late final $VacationTable vacation = $VacationTable(this);
  late final $PayrollResultsTable payrollResults = $PayrollResultsTable(this);
  late final $PendingChangesTable pendingChanges = $PendingChangesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final Index idxEmployeesFullName = Index(
    'idx_employees_full_name',
    'CREATE INDEX idx_employees_full_name ON employees (full_name)',
  );
  late final Index idxEmployeeRatesEmployee = Index(
    'idx_employee_rates_employee',
    'CREATE INDEX idx_employee_rates_employee ON employee_rates (employee_uuid, start_date)',
  );
  late final Index idxTimesheetUnique = Index(
    'idx_timesheet_unique',
    'CREATE UNIQUE INDEX idx_timesheet_unique ON timesheet (employee_uuid, date) WHERE deleted = 0',
  );
  late final Index idxTimesheetDate = Index(
    'idx_timesheet_date',
    'CREATE INDEX idx_timesheet_date ON timesheet (date)',
  );
  late final Index idxPaymentsEmployeeDate = Index(
    'idx_payments_employee_date',
    'CREATE INDEX idx_payments_employee_date ON payments (employee_uuid, payment_date)',
  );
  late final Index idxPaymentsDate = Index(
    'idx_payments_date',
    'CREATE INDEX idx_payments_date ON payments (payment_date)',
  );
  late final Index idxSickLeaveEmployee = Index(
    'idx_sick_leave_employee',
    'CREATE INDEX idx_sick_leave_employee ON sick_leave (employee_uuid)',
  );
  late final Index idxVacationEmployee = Index(
    'idx_vacation_employee',
    'CREATE INDEX idx_vacation_employee ON vacation (employee_uuid)',
  );
  late final Index idxPayrollUnique = Index(
    'idx_payroll_unique',
    'CREATE UNIQUE INDEX idx_payroll_unique ON payroll_results (employee_uuid, year, month) WHERE deleted = 0',
  );
  late final Index idxPayrollPeriod = Index(
    'idx_payroll_period',
    'CREATE INDEX idx_payroll_period ON payroll_results (year, month)',
  );
  late final EmployeesDao employeesDao = EmployeesDao(this as LocalDatabase);
  late final RatesDao ratesDao = RatesDao(this as LocalDatabase);
  late final TimesheetDao timesheetDao = TimesheetDao(this as LocalDatabase);
  late final PaymentsDao paymentsDao = PaymentsDao(this as LocalDatabase);
  late final PayrollDao payrollDao = PayrollDao(this as LocalDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as LocalDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as LocalDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    companySettings,
    employees,
    employeeRates,
    timesheet,
    payments,
    sickLeave,
    vacation,
    payrollResults,
    pendingChanges,
    syncState,
    idxEmployeesFullName,
    idxEmployeeRatesEmployee,
    idxTimesheetUnique,
    idxTimesheetDate,
    idxPaymentsEmployeeDate,
    idxPaymentsDate,
    idxSickLeaveEmployee,
    idxVacationEmployee,
    idxPayrollUnique,
    idxPayrollPeriod,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CompanySettingsTableCreateCompanionBuilder =
    CompanySettingsCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> companyName,
      Value<String?> directorName,
      Value<String?> inn,
      Value<String?> ogrn,
      Value<String?> bankAccount,
      Value<String?> bankName,
      Value<String?> legalAddress,
      Value<String?> phone,
      Value<double> defaultWorkDayHours,
      Value<double> overtimeMultiplier,
      Value<double> nightShiftMultiplier,
      Value<int> rowid,
    });
typedef $$CompanySettingsTableUpdateCompanionBuilder =
    CompanySettingsCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> companyName,
      Value<String?> directorName,
      Value<String?> inn,
      Value<String?> ogrn,
      Value<String?> bankAccount,
      Value<String?> bankName,
      Value<String?> legalAddress,
      Value<String?> phone,
      Value<double> defaultWorkDayHours,
      Value<double> overtimeMultiplier,
      Value<double> nightShiftMultiplier,
      Value<int> rowid,
    });

class $$CompanySettingsTableFilterComposer
    extends Composer<_$LocalDatabase, $CompanySettingsTable> {
  $$CompanySettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directorName => $composableBuilder(
    column: $table.directorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inn => $composableBuilder(
    column: $table.inn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ogrn => $composableBuilder(
    column: $table.ogrn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legalAddress => $composableBuilder(
    column: $table.legalAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get defaultWorkDayHours => $composableBuilder(
    column: $table.defaultWorkDayHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get overtimeMultiplier => $composableBuilder(
    column: $table.overtimeMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nightShiftMultiplier => $composableBuilder(
    column: $table.nightShiftMultiplier,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompanySettingsTableOrderingComposer
    extends Composer<_$LocalDatabase, $CompanySettingsTable> {
  $$CompanySettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directorName => $composableBuilder(
    column: $table.directorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inn => $composableBuilder(
    column: $table.inn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ogrn => $composableBuilder(
    column: $table.ogrn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legalAddress => $composableBuilder(
    column: $table.legalAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get defaultWorkDayHours => $composableBuilder(
    column: $table.defaultWorkDayHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get overtimeMultiplier => $composableBuilder(
    column: $table.overtimeMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nightShiftMultiplier => $composableBuilder(
    column: $table.nightShiftMultiplier,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompanySettingsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $CompanySettingsTable> {
  $$CompanySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get directorName => $composableBuilder(
    column: $table.directorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inn =>
      $composableBuilder(column: $table.inn, builder: (column) => column);

  GeneratedColumn<String> get ogrn =>
      $composableBuilder(column: $table.ogrn, builder: (column) => column);

  GeneratedColumn<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get legalAddress => $composableBuilder(
    column: $table.legalAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<double> get defaultWorkDayHours => $composableBuilder(
    column: $table.defaultWorkDayHours,
    builder: (column) => column,
  );

  GeneratedColumn<double> get overtimeMultiplier => $composableBuilder(
    column: $table.overtimeMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nightShiftMultiplier => $composableBuilder(
    column: $table.nightShiftMultiplier,
    builder: (column) => column,
  );
}

class $$CompanySettingsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $CompanySettingsTable,
          CompanySettingsRow,
          $$CompanySettingsTableFilterComposer,
          $$CompanySettingsTableOrderingComposer,
          $$CompanySettingsTableAnnotationComposer,
          $$CompanySettingsTableCreateCompanionBuilder,
          $$CompanySettingsTableUpdateCompanionBuilder,
          (
            CompanySettingsRow,
            BaseReferences<
              _$LocalDatabase,
              $CompanySettingsTable,
              CompanySettingsRow
            >,
          ),
          CompanySettingsRow,
          PrefetchHooks Function()
        > {
  $$CompanySettingsTableTableManager(
    _$LocalDatabase db,
    $CompanySettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompanySettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompanySettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompanySettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> companyName = const Value.absent(),
                Value<String?> directorName = const Value.absent(),
                Value<String?> inn = const Value.absent(),
                Value<String?> ogrn = const Value.absent(),
                Value<String?> bankAccount = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> legalAddress = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<double> defaultWorkDayHours = const Value.absent(),
                Value<double> overtimeMultiplier = const Value.absent(),
                Value<double> nightShiftMultiplier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompanySettingsCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                companyName: companyName,
                directorName: directorName,
                inn: inn,
                ogrn: ogrn,
                bankAccount: bankAccount,
                bankName: bankName,
                legalAddress: legalAddress,
                phone: phone,
                defaultWorkDayHours: defaultWorkDayHours,
                overtimeMultiplier: overtimeMultiplier,
                nightShiftMultiplier: nightShiftMultiplier,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> companyName = const Value.absent(),
                Value<String?> directorName = const Value.absent(),
                Value<String?> inn = const Value.absent(),
                Value<String?> ogrn = const Value.absent(),
                Value<String?> bankAccount = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> legalAddress = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<double> defaultWorkDayHours = const Value.absent(),
                Value<double> overtimeMultiplier = const Value.absent(),
                Value<double> nightShiftMultiplier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompanySettingsCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                companyName: companyName,
                directorName: directorName,
                inn: inn,
                ogrn: ogrn,
                bankAccount: bankAccount,
                bankName: bankName,
                legalAddress: legalAddress,
                phone: phone,
                defaultWorkDayHours: defaultWorkDayHours,
                overtimeMultiplier: overtimeMultiplier,
                nightShiftMultiplier: nightShiftMultiplier,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompanySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $CompanySettingsTable,
      CompanySettingsRow,
      $$CompanySettingsTableFilterComposer,
      $$CompanySettingsTableOrderingComposer,
      $$CompanySettingsTableAnnotationComposer,
      $$CompanySettingsTableCreateCompanionBuilder,
      $$CompanySettingsTableUpdateCompanionBuilder,
      (
        CompanySettingsRow,
        BaseReferences<
          _$LocalDatabase,
          $CompanySettingsTable,
          CompanySettingsRow
        >,
      ),
      CompanySettingsRow,
      PrefetchHooks Function()
    >;
typedef $$EmployeesTableCreateCompanionBuilder =
    EmployeesCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String fullName,
      required String position,
      required String hireDate,
      Value<String?> dismissalDate,
      Value<double> baseRate,
      Value<double> fieldRate,
      Value<int> rowid,
    });
typedef $$EmployeesTableUpdateCompanionBuilder =
    EmployeesCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> fullName,
      Value<String> position,
      Value<String> hireDate,
      Value<String?> dismissalDate,
      Value<double> baseRate,
      Value<double> fieldRate,
      Value<int> rowid,
    });

final class $$EmployeesTableReferences
    extends BaseReferences<_$LocalDatabase, $EmployeesTable, EmployeeRow> {
  $$EmployeesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EmployeeRatesTable, List<EmployeeRateRow>>
  _employeeRatesRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.employeeRates,
    aliasName: 'employees__uuid__employee_rates__employee_uuid',
  );

  $$EmployeeRatesTableProcessedTableManager get employeeRatesRefs {
    final manager = $$EmployeeRatesTableTableManager($_db, $_db.employeeRates)
        .filter(
          (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_employeeRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimesheetTable, List<TimesheetRow>>
  _timesheetRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.timesheet,
    aliasName: 'employees__uuid__timesheet__employee_uuid',
  );

  $$TimesheetTableProcessedTableManager get timesheetRefs {
    final manager = $$TimesheetTableTableManager($_db, $_db.timesheet).filter(
      (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_timesheetRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentsTable, List<PaymentRow>>
  _paymentsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'employees__uuid__payments__employee_uuid',
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager($_db, $_db.payments).filter(
      (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SickLeaveTable, List<SickLeaveRow>>
  _sickLeaveRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.sickLeave,
    aliasName: 'employees__uuid__sick_leave__employee_uuid',
  );

  $$SickLeaveTableProcessedTableManager get sickLeaveRefs {
    final manager = $$SickLeaveTableTableManager($_db, $_db.sickLeave).filter(
      (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_sickLeaveRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VacationTable, List<VacationRow>>
  _vacationRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.vacation,
    aliasName: 'employees__uuid__vacation__employee_uuid',
  );

  $$VacationTableProcessedTableManager get vacationRefs {
    final manager = $$VacationTableTableManager($_db, $_db.vacation).filter(
      (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_vacationRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayrollResultsTable, List<PayrollResultRow>>
  _payrollResultsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.payrollResults,
    aliasName: 'employees__uuid__payroll_results__employee_uuid',
  );

  $$PayrollResultsTableProcessedTableManager get payrollResultsRefs {
    final manager = $$PayrollResultsTableTableManager($_db, $_db.payrollResults)
        .filter(
          (f) => f.employeeUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_payrollResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EmployeesTableFilterComposer
    extends Composer<_$LocalDatabase, $EmployeesTable> {
  $$EmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hireDate => $composableBuilder(
    column: $table.hireDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dismissalDate => $composableBuilder(
    column: $table.dismissalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fieldRate => $composableBuilder(
    column: $table.fieldRate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> employeeRatesRefs(
    Expression<bool> Function($$EmployeeRatesTableFilterComposer f) f,
  ) {
    final $$EmployeeRatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.employeeRates,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeeRatesTableFilterComposer(
            $db: $db,
            $table: $db.employeeRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timesheetRefs(
    Expression<bool> Function($$TimesheetTableFilterComposer f) f,
  ) {
    final $$TimesheetTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.timesheet,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimesheetTableFilterComposer(
            $db: $db,
            $table: $db.timesheet,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sickLeaveRefs(
    Expression<bool> Function($$SickLeaveTableFilterComposer f) f,
  ) {
    final $$SickLeaveTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.sickLeave,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SickLeaveTableFilterComposer(
            $db: $db,
            $table: $db.sickLeave,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> vacationRefs(
    Expression<bool> Function($$VacationTableFilterComposer f) f,
  ) {
    final $$VacationTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.vacation,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VacationTableFilterComposer(
            $db: $db,
            $table: $db.vacation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payrollResultsRefs(
    Expression<bool> Function($$PayrollResultsTableFilterComposer f) f,
  ) {
    final $$PayrollResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.payrollResults,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayrollResultsTableFilterComposer(
            $db: $db,
            $table: $db.payrollResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EmployeesTableOrderingComposer
    extends Composer<_$LocalDatabase, $EmployeesTable> {
  $$EmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hireDate => $composableBuilder(
    column: $table.hireDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dismissalDate => $composableBuilder(
    column: $table.dismissalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fieldRate => $composableBuilder(
    column: $table.fieldRate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $EmployeesTable> {
  $$EmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get hireDate =>
      $composableBuilder(column: $table.hireDate, builder: (column) => column);

  GeneratedColumn<String> get dismissalDate => $composableBuilder(
    column: $table.dismissalDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseRate =>
      $composableBuilder(column: $table.baseRate, builder: (column) => column);

  GeneratedColumn<double> get fieldRate =>
      $composableBuilder(column: $table.fieldRate, builder: (column) => column);

  Expression<T> employeeRatesRefs<T extends Object>(
    Expression<T> Function($$EmployeeRatesTableAnnotationComposer a) f,
  ) {
    final $$EmployeeRatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.employeeRates,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeeRatesTableAnnotationComposer(
            $db: $db,
            $table: $db.employeeRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timesheetRefs<T extends Object>(
    Expression<T> Function($$TimesheetTableAnnotationComposer a) f,
  ) {
    final $$TimesheetTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.timesheet,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimesheetTableAnnotationComposer(
            $db: $db,
            $table: $db.timesheet,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sickLeaveRefs<T extends Object>(
    Expression<T> Function($$SickLeaveTableAnnotationComposer a) f,
  ) {
    final $$SickLeaveTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.sickLeave,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SickLeaveTableAnnotationComposer(
            $db: $db,
            $table: $db.sickLeave,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> vacationRefs<T extends Object>(
    Expression<T> Function($$VacationTableAnnotationComposer a) f,
  ) {
    final $$VacationTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.vacation,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VacationTableAnnotationComposer(
            $db: $db,
            $table: $db.vacation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payrollResultsRefs<T extends Object>(
    Expression<T> Function($$PayrollResultsTableAnnotationComposer a) f,
  ) {
    final $$PayrollResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.payrollResults,
      getReferencedColumn: (t) => t.employeeUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayrollResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.payrollResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EmployeesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $EmployeesTable,
          EmployeeRow,
          $$EmployeesTableFilterComposer,
          $$EmployeesTableOrderingComposer,
          $$EmployeesTableAnnotationComposer,
          $$EmployeesTableCreateCompanionBuilder,
          $$EmployeesTableUpdateCompanionBuilder,
          (EmployeeRow, $$EmployeesTableReferences),
          EmployeeRow,
          PrefetchHooks Function({
            bool employeeRatesRefs,
            bool timesheetRefs,
            bool paymentsRefs,
            bool sickLeaveRefs,
            bool vacationRefs,
            bool payrollResultsRefs,
          })
        > {
  $$EmployeesTableTableManager(_$LocalDatabase db, $EmployeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> position = const Value.absent(),
                Value<String> hireDate = const Value.absent(),
                Value<String?> dismissalDate = const Value.absent(),
                Value<double> baseRate = const Value.absent(),
                Value<double> fieldRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmployeesCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                fullName: fullName,
                position: position,
                hireDate: hireDate,
                dismissalDate: dismissalDate,
                baseRate: baseRate,
                fieldRate: fieldRate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String fullName,
                required String position,
                required String hireDate,
                Value<String?> dismissalDate = const Value.absent(),
                Value<double> baseRate = const Value.absent(),
                Value<double> fieldRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmployeesCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                fullName: fullName,
                position: position,
                hireDate: hireDate,
                dismissalDate: dismissalDate,
                baseRate: baseRate,
                fieldRate: fieldRate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EmployeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                employeeRatesRefs = false,
                timesheetRefs = false,
                paymentsRefs = false,
                sickLeaveRefs = false,
                vacationRefs = false,
                payrollResultsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (employeeRatesRefs) db.employeeRates,
                    if (timesheetRefs) db.timesheet,
                    if (paymentsRefs) db.payments,
                    if (sickLeaveRefs) db.sickLeave,
                    if (vacationRefs) db.vacation,
                    if (payrollResultsRefs) db.payrollResults,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (employeeRatesRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          EmployeeRateRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._employeeRatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).employeeRatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (timesheetRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          TimesheetRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._timesheetRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).timesheetRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (paymentsRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          PaymentRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._paymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (sickLeaveRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          SickLeaveRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._sickLeaveRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).sickLeaveRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (vacationRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          VacationRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._vacationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).vacationRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (payrollResultsRefs)
                        await $_getPrefetchedData<
                          EmployeeRow,
                          $EmployeesTable,
                          PayrollResultRow
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._payrollResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).payrollResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeUuid == item.uuid,
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

typedef $$EmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $EmployeesTable,
      EmployeeRow,
      $$EmployeesTableFilterComposer,
      $$EmployeesTableOrderingComposer,
      $$EmployeesTableAnnotationComposer,
      $$EmployeesTableCreateCompanionBuilder,
      $$EmployeesTableUpdateCompanionBuilder,
      (EmployeeRow, $$EmployeesTableReferences),
      EmployeeRow,
      PrefetchHooks Function({
        bool employeeRatesRefs,
        bool timesheetRefs,
        bool paymentsRefs,
        bool sickLeaveRefs,
        bool vacationRefs,
        bool payrollResultsRefs,
      })
    >;
typedef $$EmployeeRatesTableCreateCompanionBuilder =
    EmployeeRatesCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required double baseRate,
      required double fieldRate,
      required String startDate,
      Value<String?> endDate,
      Value<int> rowid,
    });
typedef $$EmployeeRatesTableUpdateCompanionBuilder =
    EmployeeRatesCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<double> baseRate,
      Value<double> fieldRate,
      Value<String> startDate,
      Value<String?> endDate,
      Value<int> rowid,
    });

final class $$EmployeeRatesTableReferences
    extends
        BaseReferences<_$LocalDatabase, $EmployeeRatesTable, EmployeeRateRow> {
  $$EmployeeRatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) => db.employees
      .createAlias('employee_rates__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EmployeeRatesTableFilterComposer
    extends Composer<_$LocalDatabase, $EmployeeRatesTable> {
  $$EmployeeRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fieldRate => $composableBuilder(
    column: $table.fieldRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmployeeRatesTableOrderingComposer
    extends Composer<_$LocalDatabase, $EmployeeRatesTable> {
  $$EmployeeRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fieldRate => $composableBuilder(
    column: $table.fieldRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmployeeRatesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $EmployeeRatesTable> {
  $$EmployeeRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseRate =>
      $composableBuilder(column: $table.baseRate, builder: (column) => column);

  GeneratedColumn<double> get fieldRate =>
      $composableBuilder(column: $table.fieldRate, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmployeeRatesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $EmployeeRatesTable,
          EmployeeRateRow,
          $$EmployeeRatesTableFilterComposer,
          $$EmployeeRatesTableOrderingComposer,
          $$EmployeeRatesTableAnnotationComposer,
          $$EmployeeRatesTableCreateCompanionBuilder,
          $$EmployeeRatesTableUpdateCompanionBuilder,
          (EmployeeRateRow, $$EmployeeRatesTableReferences),
          EmployeeRateRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$EmployeeRatesTableTableManager(
    _$LocalDatabase db,
    $EmployeeRatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeeRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeeRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeeRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<double> baseRate = const Value.absent(),
                Value<double> fieldRate = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmployeeRatesCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                baseRate: baseRate,
                fieldRate: fieldRate,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required double baseRate,
                required double fieldRate,
                required String startDate,
                Value<String?> endDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmployeeRatesCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                baseRate: baseRate,
                fieldRate: fieldRate,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EmployeeRatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$EmployeeRatesTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn: $$EmployeeRatesTableReferences
                                    ._employeeUuidTable(db)
                                    .uuid,
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

typedef $$EmployeeRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $EmployeeRatesTable,
      EmployeeRateRow,
      $$EmployeeRatesTableFilterComposer,
      $$EmployeeRatesTableOrderingComposer,
      $$EmployeeRatesTableAnnotationComposer,
      $$EmployeeRatesTableCreateCompanionBuilder,
      $$EmployeeRatesTableUpdateCompanionBuilder,
      (EmployeeRateRow, $$EmployeeRatesTableReferences),
      EmployeeRateRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$TimesheetTableCreateCompanionBuilder =
    TimesheetCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required String date,
      Value<String> dayType,
      Value<double> days,
      Value<String?> workPlace,
      Value<String?> notes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$TimesheetTableUpdateCompanionBuilder =
    TimesheetCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<String> date,
      Value<String> dayType,
      Value<double> days,
      Value<String?> workPlace,
      Value<String?> notes,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$TimesheetTableReferences
    extends BaseReferences<_$LocalDatabase, $TimesheetTable, TimesheetRow> {
  $$TimesheetTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) =>
      db.employees.createAlias('timesheet__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimesheetTableFilterComposer
    extends Composer<_$LocalDatabase, $TimesheetTable> {
  $$TimesheetTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayType => $composableBuilder(
    column: $table.dayType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workPlace => $composableBuilder(
    column: $table.workPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimesheetTableOrderingComposer
    extends Composer<_$LocalDatabase, $TimesheetTable> {
  $$TimesheetTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayType => $composableBuilder(
    column: $table.dayType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workPlace => $composableBuilder(
    column: $table.workPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimesheetTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TimesheetTable> {
  $$TimesheetTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dayType =>
      $composableBuilder(column: $table.dayType, builder: (column) => column);

  GeneratedColumn<double> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<String> get workPlace =>
      $composableBuilder(column: $table.workPlace, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimesheetTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $TimesheetTable,
          TimesheetRow,
          $$TimesheetTableFilterComposer,
          $$TimesheetTableOrderingComposer,
          $$TimesheetTableAnnotationComposer,
          $$TimesheetTableCreateCompanionBuilder,
          $$TimesheetTableUpdateCompanionBuilder,
          (TimesheetRow, $$TimesheetTableReferences),
          TimesheetRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$TimesheetTableTableManager(_$LocalDatabase db, $TimesheetTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimesheetTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimesheetTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimesheetTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> dayType = const Value.absent(),
                Value<double> days = const Value.absent(),
                Value<String?> workPlace = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimesheetCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                date: date,
                dayType: dayType,
                days: days,
                workPlace: workPlace,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required String date,
                Value<String> dayType = const Value.absent(),
                Value<double> days = const Value.absent(),
                Value<String?> workPlace = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TimesheetCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                date: date,
                dayType: dayType,
                days: days,
                workPlace: workPlace,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimesheetTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$TimesheetTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn: $$TimesheetTableReferences
                                    ._employeeUuidTable(db)
                                    .uuid,
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

typedef $$TimesheetTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $TimesheetTable,
      TimesheetRow,
      $$TimesheetTableFilterComposer,
      $$TimesheetTableOrderingComposer,
      $$TimesheetTableAnnotationComposer,
      $$TimesheetTableCreateCompanionBuilder,
      $$TimesheetTableUpdateCompanionBuilder,
      (TimesheetRow, $$TimesheetTableReferences),
      TimesheetRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$PaymentsTableCreateCompanionBuilder =
    PaymentsCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required String paymentDate,
      required double amount,
      Value<String> paymentType,
      Value<String?> periodStart,
      Value<String?> periodEnd,
      Value<String?> paymentMethod,
      Value<String?> documentNumber,
      Value<String?> notes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$PaymentsTableUpdateCompanionBuilder =
    PaymentsCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<String> paymentDate,
      Value<double> amount,
      Value<String> paymentType,
      Value<String?> periodStart,
      Value<String?> periodEnd,
      Value<String?> paymentMethod,
      Value<String?> documentNumber,
      Value<String?> notes,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$PaymentsTableReferences
    extends BaseReferences<_$LocalDatabase, $PaymentsTable, PaymentRow> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) =>
      db.employees.createAlias('payments__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentsTableFilterComposer
    extends Composer<_$LocalDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$LocalDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PaymentsTable,
          PaymentRow,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (PaymentRow, $$PaymentsTableReferences),
          PaymentRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$PaymentsTableTableManager(_$LocalDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<String> paymentDate = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> paymentType = const Value.absent(),
                Value<String?> periodStart = const Value.absent(),
                Value<String?> periodEnd = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<String?> documentNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                paymentDate: paymentDate,
                amount: amount,
                paymentType: paymentType,
                periodStart: periodStart,
                periodEnd: periodEnd,
                paymentMethod: paymentMethod,
                documentNumber: documentNumber,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required String paymentDate,
                required double amount,
                Value<String> paymentType = const Value.absent(),
                Value<String?> periodStart = const Value.absent(),
                Value<String?> periodEnd = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<String?> documentNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                paymentDate: paymentDate,
                amount: amount,
                paymentType: paymentType,
                periodStart: periodStart,
                periodEnd: periodEnd,
                paymentMethod: paymentMethod,
                documentNumber: documentNumber,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$PaymentsTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn: $$PaymentsTableReferences
                                    ._employeeUuidTable(db)
                                    .uuid,
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

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PaymentsTable,
      PaymentRow,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (PaymentRow, $$PaymentsTableReferences),
      PaymentRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$SickLeaveTableCreateCompanionBuilder =
    SickLeaveCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required String startDate,
      required String endDate,
      Value<String?> documentNumber,
      required int daysCount,
      Value<double?> paidByEmployer,
      Value<double?> paidByFss,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$SickLeaveTableUpdateCompanionBuilder =
    SickLeaveCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<String> startDate,
      Value<String> endDate,
      Value<String?> documentNumber,
      Value<int> daysCount,
      Value<double?> paidByEmployer,
      Value<double?> paidByFss,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$SickLeaveTableReferences
    extends BaseReferences<_$LocalDatabase, $SickLeaveTable, SickLeaveRow> {
  $$SickLeaveTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) =>
      db.employees.createAlias('sick_leave__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SickLeaveTableFilterComposer
    extends Composer<_$LocalDatabase, $SickLeaveTable> {
  $$SickLeaveTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysCount => $composableBuilder(
    column: $table.daysCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get paidByEmployer => $composableBuilder(
    column: $table.paidByEmployer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get paidByFss => $composableBuilder(
    column: $table.paidByFss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SickLeaveTableOrderingComposer
    extends Composer<_$LocalDatabase, $SickLeaveTable> {
  $$SickLeaveTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysCount => $composableBuilder(
    column: $table.daysCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get paidByEmployer => $composableBuilder(
    column: $table.paidByEmployer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get paidByFss => $composableBuilder(
    column: $table.paidByFss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SickLeaveTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SickLeaveTable> {
  $$SickLeaveTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get daysCount =>
      $composableBuilder(column: $table.daysCount, builder: (column) => column);

  GeneratedColumn<double> get paidByEmployer => $composableBuilder(
    column: $table.paidByEmployer,
    builder: (column) => column,
  );

  GeneratedColumn<double> get paidByFss =>
      $composableBuilder(column: $table.paidByFss, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SickLeaveTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SickLeaveTable,
          SickLeaveRow,
          $$SickLeaveTableFilterComposer,
          $$SickLeaveTableOrderingComposer,
          $$SickLeaveTableAnnotationComposer,
          $$SickLeaveTableCreateCompanionBuilder,
          $$SickLeaveTableUpdateCompanionBuilder,
          (SickLeaveRow, $$SickLeaveTableReferences),
          SickLeaveRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$SickLeaveTableTableManager(_$LocalDatabase db, $SickLeaveTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SickLeaveTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SickLeaveTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SickLeaveTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<String?> documentNumber = const Value.absent(),
                Value<int> daysCount = const Value.absent(),
                Value<double?> paidByEmployer = const Value.absent(),
                Value<double?> paidByFss = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SickLeaveCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                startDate: startDate,
                endDate: endDate,
                documentNumber: documentNumber,
                daysCount: daysCount,
                paidByEmployer: paidByEmployer,
                paidByFss: paidByFss,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required String startDate,
                required String endDate,
                Value<String?> documentNumber = const Value.absent(),
                required int daysCount,
                Value<double?> paidByEmployer = const Value.absent(),
                Value<double?> paidByFss = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SickLeaveCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                startDate: startDate,
                endDate: endDate,
                documentNumber: documentNumber,
                daysCount: daysCount,
                paidByEmployer: paidByEmployer,
                paidByFss: paidByFss,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SickLeaveTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$SickLeaveTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn: $$SickLeaveTableReferences
                                    ._employeeUuidTable(db)
                                    .uuid,
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

typedef $$SickLeaveTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SickLeaveTable,
      SickLeaveRow,
      $$SickLeaveTableFilterComposer,
      $$SickLeaveTableOrderingComposer,
      $$SickLeaveTableAnnotationComposer,
      $$SickLeaveTableCreateCompanionBuilder,
      $$SickLeaveTableUpdateCompanionBuilder,
      (SickLeaveRow, $$SickLeaveTableReferences),
      SickLeaveRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$VacationTableCreateCompanionBuilder =
    VacationCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required String startDate,
      required String endDate,
      Value<String> vacationType,
      required int daysCount,
      Value<bool> isApproved,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$VacationTableUpdateCompanionBuilder =
    VacationCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<String> startDate,
      Value<String> endDate,
      Value<String> vacationType,
      Value<int> daysCount,
      Value<bool> isApproved,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$VacationTableReferences
    extends BaseReferences<_$LocalDatabase, $VacationTable, VacationRow> {
  $$VacationTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) =>
      db.employees.createAlias('vacation__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VacationTableFilterComposer
    extends Composer<_$LocalDatabase, $VacationTable> {
  $$VacationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vacationType => $composableBuilder(
    column: $table.vacationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysCount => $composableBuilder(
    column: $table.daysCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isApproved => $composableBuilder(
    column: $table.isApproved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VacationTableOrderingComposer
    extends Composer<_$LocalDatabase, $VacationTable> {
  $$VacationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vacationType => $composableBuilder(
    column: $table.vacationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysCount => $composableBuilder(
    column: $table.daysCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isApproved => $composableBuilder(
    column: $table.isApproved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VacationTableAnnotationComposer
    extends Composer<_$LocalDatabase, $VacationTable> {
  $$VacationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get vacationType => $composableBuilder(
    column: $table.vacationType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get daysCount =>
      $composableBuilder(column: $table.daysCount, builder: (column) => column);

  GeneratedColumn<bool> get isApproved => $composableBuilder(
    column: $table.isApproved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VacationTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $VacationTable,
          VacationRow,
          $$VacationTableFilterComposer,
          $$VacationTableOrderingComposer,
          $$VacationTableAnnotationComposer,
          $$VacationTableCreateCompanionBuilder,
          $$VacationTableUpdateCompanionBuilder,
          (VacationRow, $$VacationTableReferences),
          VacationRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$VacationTableTableManager(_$LocalDatabase db, $VacationTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VacationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VacationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VacationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<String> vacationType = const Value.absent(),
                Value<int> daysCount = const Value.absent(),
                Value<bool> isApproved = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VacationCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                startDate: startDate,
                endDate: endDate,
                vacationType: vacationType,
                daysCount: daysCount,
                isApproved: isApproved,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required String startDate,
                required String endDate,
                Value<String> vacationType = const Value.absent(),
                required int daysCount,
                Value<bool> isApproved = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VacationCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                startDate: startDate,
                endDate: endDate,
                vacationType: vacationType,
                daysCount: daysCount,
                isApproved: isApproved,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VacationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$VacationTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn: $$VacationTableReferences
                                    ._employeeUuidTable(db)
                                    .uuid,
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

typedef $$VacationTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $VacationTable,
      VacationRow,
      $$VacationTableFilterComposer,
      $$VacationTableOrderingComposer,
      $$VacationTableAnnotationComposer,
      $$VacationTableCreateCompanionBuilder,
      $$VacationTableUpdateCompanionBuilder,
      (VacationRow, $$VacationTableReferences),
      VacationRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$PayrollResultsTableCreateCompanionBuilder =
    PayrollResultsCompanion Function({
      required String uuid,
      Value<int?> legacyId,
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      required String employeeUuid,
      required int year,
      required int month,
      Value<double> baseDays,
      Value<double> fieldDays,
      Value<double> sickDays,
      Value<double> vacationDays,
      Value<double> totalSalary,
      Value<double?> baseRateUsed,
      Value<double?> fieldRateUsed,
      required String calculatedAt,
      Value<String> status,
      Value<int> skippedWorkDays,
      Value<int> rowid,
    });
typedef $$PayrollResultsTableUpdateCompanionBuilder =
    PayrollResultsCompanion Function({
      Value<String> uuid,
      Value<int?> legacyId,
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<String?> editedBy,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> employeeUuid,
      Value<int> year,
      Value<int> month,
      Value<double> baseDays,
      Value<double> fieldDays,
      Value<double> sickDays,
      Value<double> vacationDays,
      Value<double> totalSalary,
      Value<double?> baseRateUsed,
      Value<double?> fieldRateUsed,
      Value<String> calculatedAt,
      Value<String> status,
      Value<int> skippedWorkDays,
      Value<int> rowid,
    });

final class $$PayrollResultsTableReferences
    extends
        BaseReferences<
          _$LocalDatabase,
          $PayrollResultsTable,
          PayrollResultRow
        > {
  $$PayrollResultsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeUuidTable(_$LocalDatabase db) => db.employees
      .createAlias('payroll_results__employee_uuid__employees__uuid');

  $$EmployeesTableProcessedTableManager get employeeUuid {
    final $_column = $_itemColumn<String>('employee_uuid')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PayrollResultsTableFilterComposer
    extends Composer<_$LocalDatabase, $PayrollResultsTable> {
  $$PayrollResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseDays => $composableBuilder(
    column: $table.baseDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fieldDays => $composableBuilder(
    column: $table.fieldDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sickDays => $composableBuilder(
    column: $table.sickDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vacationDays => $composableBuilder(
    column: $table.vacationDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalSalary => $composableBuilder(
    column: $table.totalSalary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseRateUsed => $composableBuilder(
    column: $table.baseRateUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fieldRateUsed => $composableBuilder(
    column: $table.fieldRateUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skippedWorkDays => $composableBuilder(
    column: $table.skippedWorkDays,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeUuid {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayrollResultsTableOrderingComposer
    extends Composer<_$LocalDatabase, $PayrollResultsTable> {
  $$PayrollResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editedBy => $composableBuilder(
    column: $table.editedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseDays => $composableBuilder(
    column: $table.baseDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fieldDays => $composableBuilder(
    column: $table.fieldDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sickDays => $composableBuilder(
    column: $table.sickDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vacationDays => $composableBuilder(
    column: $table.vacationDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalSalary => $composableBuilder(
    column: $table.totalSalary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseRateUsed => $composableBuilder(
    column: $table.baseRateUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fieldRateUsed => $composableBuilder(
    column: $table.fieldRateUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skippedWorkDays => $composableBuilder(
    column: $table.skippedWorkDays,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeUuid {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayrollResultsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PayrollResultsTable> {
  $$PayrollResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get editedBy =>
      $composableBuilder(column: $table.editedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<double> get baseDays =>
      $composableBuilder(column: $table.baseDays, builder: (column) => column);

  GeneratedColumn<double> get fieldDays =>
      $composableBuilder(column: $table.fieldDays, builder: (column) => column);

  GeneratedColumn<double> get sickDays =>
      $composableBuilder(column: $table.sickDays, builder: (column) => column);

  GeneratedColumn<double> get vacationDays => $composableBuilder(
    column: $table.vacationDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalSalary => $composableBuilder(
    column: $table.totalSalary,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseRateUsed => $composableBuilder(
    column: $table.baseRateUsed,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fieldRateUsed => $composableBuilder(
    column: $table.fieldRateUsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get skippedWorkDays => $composableBuilder(
    column: $table.skippedWorkDays,
    builder: (column) => column,
  );

  $$EmployeesTableAnnotationComposer get employeeUuid {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeUuid,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayrollResultsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PayrollResultsTable,
          PayrollResultRow,
          $$PayrollResultsTableFilterComposer,
          $$PayrollResultsTableOrderingComposer,
          $$PayrollResultsTableAnnotationComposer,
          $$PayrollResultsTableCreateCompanionBuilder,
          $$PayrollResultsTableUpdateCompanionBuilder,
          (PayrollResultRow, $$PayrollResultsTableReferences),
          PayrollResultRow,
          PrefetchHooks Function({bool employeeUuid})
        > {
  $$PayrollResultsTableTableManager(
    _$LocalDatabase db,
    $PayrollResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayrollResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayrollResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayrollResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int?> legacyId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> employeeUuid = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<double> baseDays = const Value.absent(),
                Value<double> fieldDays = const Value.absent(),
                Value<double> sickDays = const Value.absent(),
                Value<double> vacationDays = const Value.absent(),
                Value<double> totalSalary = const Value.absent(),
                Value<double?> baseRateUsed = const Value.absent(),
                Value<double?> fieldRateUsed = const Value.absent(),
                Value<String> calculatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> skippedWorkDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayrollResultsCompanion(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                year: year,
                month: month,
                baseDays: baseDays,
                fieldDays: fieldDays,
                sickDays: sickDays,
                vacationDays: vacationDays,
                totalSalary: totalSalary,
                baseRateUsed: baseRateUsed,
                fieldRateUsed: fieldRateUsed,
                calculatedAt: calculatedAt,
                status: status,
                skippedWorkDays: skippedWorkDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int?> legacyId = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<String?> editedBy = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String employeeUuid,
                required int year,
                required int month,
                Value<double> baseDays = const Value.absent(),
                Value<double> fieldDays = const Value.absent(),
                Value<double> sickDays = const Value.absent(),
                Value<double> vacationDays = const Value.absent(),
                Value<double> totalSalary = const Value.absent(),
                Value<double?> baseRateUsed = const Value.absent(),
                Value<double?> fieldRateUsed = const Value.absent(),
                required String calculatedAt,
                Value<String> status = const Value.absent(),
                Value<int> skippedWorkDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayrollResultsCompanion.insert(
                uuid: uuid,
                legacyId: legacyId,
                updatedAt: updatedAt,
                deleted: deleted,
                editedBy: editedBy,
                remoteUpdatedAt: remoteUpdatedAt,
                employeeUuid: employeeUuid,
                year: year,
                month: month,
                baseDays: baseDays,
                fieldDays: fieldDays,
                sickDays: sickDays,
                vacationDays: vacationDays,
                totalSalary: totalSalary,
                baseRateUsed: baseRateUsed,
                fieldRateUsed: fieldRateUsed,
                calculatedAt: calculatedAt,
                status: status,
                skippedWorkDays: skippedWorkDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PayrollResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeUuid = false}) {
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
                    if (employeeUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.employeeUuid,
                                referencedTable: $$PayrollResultsTableReferences
                                    ._employeeUuidTable(db),
                                referencedColumn:
                                    $$PayrollResultsTableReferences
                                        ._employeeUuidTable(db)
                                        .uuid,
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

typedef $$PayrollResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PayrollResultsTable,
      PayrollResultRow,
      $$PayrollResultsTableFilterComposer,
      $$PayrollResultsTableOrderingComposer,
      $$PayrollResultsTableAnnotationComposer,
      $$PayrollResultsTableCreateCompanionBuilder,
      $$PayrollResultsTableUpdateCompanionBuilder,
      (PayrollResultRow, $$PayrollResultsTableReferences),
      PayrollResultRow,
      PrefetchHooks Function({bool employeeUuid})
    >;
typedef $$PendingChangesTableCreateCompanionBuilder =
    PendingChangesCompanion Function({
      Value<int> id,
      required String entityTable,
      required String entityUuid,
      required String operation,
      Value<String?> payload,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$PendingChangesTableUpdateCompanionBuilder =
    PendingChangesCompanion Function({
      Value<int> id,
      Value<String> entityTable,
      Value<String> entityUuid,
      Value<String> operation,
      Value<String?> payload,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$PendingChangesTableFilterComposer
    extends Composer<_$LocalDatabase, $PendingChangesTable> {
  $$PendingChangesTableFilterComposer({
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

  ColumnFilters<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityUuid => $composableBuilder(
    column: $table.entityUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingChangesTableOrderingComposer
    extends Composer<_$LocalDatabase, $PendingChangesTable> {
  $$PendingChangesTableOrderingComposer({
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

  ColumnOrderings<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityUuid => $composableBuilder(
    column: $table.entityUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingChangesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PendingChangesTable> {
  $$PendingChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityUuid => $composableBuilder(
    column: $table.entityUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingChangesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PendingChangesTable,
          PendingChangeRow,
          $$PendingChangesTableFilterComposer,
          $$PendingChangesTableOrderingComposer,
          $$PendingChangesTableAnnotationComposer,
          $$PendingChangesTableCreateCompanionBuilder,
          $$PendingChangesTableUpdateCompanionBuilder,
          (
            PendingChangeRow,
            BaseReferences<
              _$LocalDatabase,
              $PendingChangesTable,
              PendingChangeRow
            >,
          ),
          PendingChangeRow,
          PrefetchHooks Function()
        > {
  $$PendingChangesTableTableManager(
    _$LocalDatabase db,
    $PendingChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityTable = const Value.absent(),
                Value<String> entityUuid = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingChangesCompanion(
                id: id,
                entityTable: entityTable,
                entityUuid: entityUuid,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityTable,
                required String entityUuid,
                required String operation,
                Value<String?> payload = const Value.absent(),
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingChangesCompanion.insert(
                id: id,
                entityTable: entityTable,
                entityUuid: entityUuid,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PendingChangesTable,
      PendingChangeRow,
      $$PendingChangesTableFilterComposer,
      $$PendingChangesTableOrderingComposer,
      $$PendingChangesTableAnnotationComposer,
      $$PendingChangesTableCreateCompanionBuilder,
      $$PendingChangesTableUpdateCompanionBuilder,
      (
        PendingChangeRow,
        BaseReferences<_$LocalDatabase, $PendingChangesTable, PendingChangeRow>,
      ),
      PendingChangeRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$LocalDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$LocalDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$LocalDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$CompanySettingsTableTableManager get companySettings =>
      $$CompanySettingsTableTableManager(_db, _db.companySettings);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db, _db.employees);
  $$EmployeeRatesTableTableManager get employeeRates =>
      $$EmployeeRatesTableTableManager(_db, _db.employeeRates);
  $$TimesheetTableTableManager get timesheet =>
      $$TimesheetTableTableManager(_db, _db.timesheet);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$SickLeaveTableTableManager get sickLeave =>
      $$SickLeaveTableTableManager(_db, _db.sickLeave);
  $$VacationTableTableManager get vacation =>
      $$VacationTableTableManager(_db, _db.vacation);
  $$PayrollResultsTableTableManager get payrollResults =>
      $$PayrollResultsTableTableManager(_db, _db.payrollResults);
  $$PendingChangesTableTableManager get pendingChanges =>
      $$PendingChangesTableTableManager(_db, _db.pendingChanges);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
