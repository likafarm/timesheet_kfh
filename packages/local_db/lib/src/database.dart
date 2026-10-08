import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'connection/memory_unsupported.dart'
    if (dart.library.ffi) 'connection/memory_native.dart';

import 'daos/employees_dao.dart';
import 'daos/finance_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/payroll_adjustments_dao.dart';
import 'daos/payroll_dao.dart';
import 'daos/rates_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_state_dao.dart';
import 'daos/timesheet_dao.dart';
import 'schema_versions.dart';
import 'tables/finance_tables.dart';
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
/// конвертером, а не миграцией. Схема 2 (этап 8) — финансы, схема 3 —
/// корректировки начисления за месяц. Снимки схем —
/// `drift_schemas/`, помощник шагов — `schema_versions.dart`
/// (`drift_dev schema steps`); миграции только добавляют.
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
    // Финансы (этап 8, схема 2)
    FinDirections,
    FinAllocationKeys,
    FinAllocationPeriods,
    FinAccounts,
    FinAssets,
    FinCategories,
    Counterparties,
    FinDebts,
    FinOperations,
    FinPayrollMapping,
    // Корректировки начисления (схема 3)
    PayrollAdjustments,
  ],
  daos: [
    EmployeesDao,
    RatesDao,
    TimesheetDao,
    PaymentsDao,
    PayrollDao,
    SettingsDao,
    SyncStateDao,
    FinanceDao,
    PayrollAdjustmentsDao,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// База в памяти — для тестов (только Dart VM). База в файле —
  /// `openLocalDatabaseFile` из `native.dart`, в браузере — `web.dart`.
  factory LocalDatabase.memory({DateTime Function()? clock}) =>
      LocalDatabase(memoryExecutor(), clock: clock);

  final DateTime Function() _clock;
  String? _deviceId;

  @override
  int get schemaVersion => 3;

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
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // Финансы: новые таблицы и индексы, старые таблицы не меняются.
        for (final table in [
          schema.finDirections,
          schema.finAllocationKeys,
          schema.finAllocationPeriods,
          schema.finAccounts,
          schema.finAssets,
          schema.finCategories,
          schema.counterparties,
          schema.finDebts,
          schema.finOperations,
          schema.finPayrollMapping,
        ]) {
          await m.createTable(table);
        }
        for (final index in [
          schema.idxFinDirectionsName,
          schema.idxFinAllocationKeysName,
          schema.idxFinAllocationPeriodsUnique,
          schema.idxFinAccountsName,
          schema.idxFinCategoriesName,
          schema.idxCounterpartiesName,
          schema.idxFinOperationsDate,
          schema.idxFinOperationsAccount,
          schema.idxFinOperationsCategory,
          schema.idxFinPayrollMappingUnique,
        ]) {
          await m.createIndex(index);
        }
      },
      from2To3: (m, schema) async {
        // Корректировки начисления: новая таблица, старые не меняются.
        await m.createTable(schema.payrollAdjustments);
        await m.createIndex(schema.idxPayrollAdjustmentsMonth);
        await m.createIndex(schema.idxPayrollAdjustmentsEmployee);
      },
    ),
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
