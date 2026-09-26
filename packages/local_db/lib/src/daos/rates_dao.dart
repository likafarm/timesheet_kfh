import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'rates_dao.g.dart';

@DriftAccessor(tables: [EmployeeRates])
class RatesDao extends DatabaseAccessor<LocalDatabase>
    with _$RatesDaoMixin, SyncStamping {
  RatesDao(super.db);

  /// Новая ставка с [startDate]; действующие (без даты окончания) ставки
  /// сотрудника закрываются датой «начало − 1 день». Возвращает uuid.
  Future<String> addRate({
    required String employeeUuid,
    required double baseRate,
    required double fieldRate,
    required DateTime startDate,
  }) => transaction(() async {
    final editor = await db.deviceId();
    final now = db.nowUtc();
    await (update(employeeRates)..where(
          (t) =>
              t.employeeUuid.equals(employeeUuid) &
              t.endDate.isNull() &
              t.deleted.equals(false),
        ))
        .write(
          EmployeeRatesCompanion(
            endDate: Value(
              formatDateIso(startDate.subtract(const Duration(days: 1))),
            ),
            updatedAt: Value(now),
            editedBy: Value(editor),
          ),
        );
    final uuid = newUuid();
    await into(employeeRates).insert(
      EmployeeRatesCompanion.insert(
        uuid: uuid,
        employeeUuid: employeeUuid,
        baseRate: baseRate,
        fieldRate: fieldRate,
        startDate: formatDateIso(startDate),
        updatedAt: now,
        editedBy: Value(editor),
      ),
    );
    return uuid;
  });

  /// История ставок сотрудника по дате начала.
  Future<List<EmployeeRateRow>> rateHistory(String employeeUuid) =>
      (select(employeeRates)
            ..where(
              (t) =>
                  t.employeeUuid.equals(employeeUuid) & t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
          .get();

  /// Ставка, действующая на [date]; при пересечении — с более поздним началом.
  Future<EmployeeRateRow?> rateAt(String employeeUuid, DateTime date) {
    final day = formatDateIso(date);
    return (select(employeeRates)
          ..where(
            (t) =>
                t.employeeUuid.equals(employeeUuid) &
                t.deleted.equals(false) &
                t.startDate.isSmallerOrEqualValue(day) &
                (t.endDate.isNull() | t.endDate.isBiggerOrEqualValue(day)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Обновляет ставку; ключ и служебные поля из [changes] игнорируются.
  Future<int> updateRate(String uuid, EmployeeRatesCompanion changes) async {
    final editor = await db.deviceId();
    return (update(
      employeeRates,
    )..where((t) => t.uuid.equals(uuid) & t.deleted.equals(false))).write(
      changes.copyWith(
        uuid: const Value.absent(),
        legacyId: const Value.absent(),
        deleted: const Value.absent(),
        remoteUpdatedAt: const Value.absent(),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
  }

  Future<int> softDeleteRate(String uuid) => softDeleteRow(employeeRates, uuid);
}
