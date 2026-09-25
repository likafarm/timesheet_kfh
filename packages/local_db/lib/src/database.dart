import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'daos/employees_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/payroll_dao.dart';
import 'daos/rates_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_state_dao.dart';
import 'daos/timesheet_dao.dart';
import 'tables/tables.dart';

part 'database.g.dart';

/// Ключ id устройства в `sync_state`.
const deviceIdKey = 'device_id';

/// Настройки хозяйства — одна строка с фиксированным uuid, одинаковым на
/// всех устройствах, чтобы синхронизация не плодила вторую строку.
const companySettingsUuid = '00000000-0000-0000-0000-000000000001';

const _uuid = Uuid();

/// Новый ключ записи: UUID v7 (упорядочен по времени создания).
String newUuid() => _uuid.v7();

/// Локальная база, схема v2.
///
/// Версия схемы drift начинается с 1: это новый файл
/// (`kfx_time_tracking_v2.db`), старая база v8 в него переносится
/// конвертером, а не миграцией.
@DriftDatabase(
  tables: [
    CompanySettings,
    Employees,
    EmployeeRates,
    Timesheet,
    Payments,
    SickLeave,
    Vacation,
    PayrollResults,
    PendingChanges,
    SyncState,
  ],
  daos: [
    EmployeesDao,
    RatesDao,
    TimesheetDao,
    PaymentsDao,
    PayrollDao,
    SettingsDao,
    SyncStateDao,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// База в файле; запросы выполняются в фоновом изоляте.
  factory LocalDatabase.file(File file, {DateTime Function()? clock}) =>
      LocalDatabase(NativeDatabase.createInBackground(file), clock: clock);

  /// База в памяти — для тестов.
  factory LocalDatabase.memory({DateTime Function()? clock}) =>
      LocalDatabase(NativeDatabase.memory(), clock: clock);

  final DateTime Function() _clock;
  String? _deviceId;

  @override
  int get schemaVersion => 1;

  /// Текущий момент в UTC — для `updated_at`.
  DateTime nowUtc() => _clock().toUtc();

  /// Текущий момент по локальному времени — для `created_at`,
  /// в том же формате, что и в старой базе.
  String nowLocalIso() => _clock().toLocal().toIso8601String();

  /// Id этого устройства; пишется в `edited_by`. Drift открывает базу
  /// лениво, поэтому id загружается при первом обращении к базе.
  Future<String> deviceId() async {
    if (_deviceId == null) await doWhenOpened((_) {});
    return _deviceId!;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(companySettings).insert(
        CompanySettingsCompanion.insert(
          uuid: companySettingsUuid,
          updatedAt: nowUtc(),
        ),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      _deviceId = await syncStateDao.getValue(deviceIdKey);
      if (_deviceId == null) {
        _deviceId = newUuid();
        await syncStateDao.setValue(deviceIdKey, _deviceId!);
      }
    },
  );
}
