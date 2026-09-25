import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'payroll_dao.g.dart';

@DriftAccessor(tables: [PayrollResults])
class PayrollDao extends DatabaseAccessor<LocalDatabase>
    with _$PayrollDaoMixin, SyncStamping {
  PayrollDao(super.db);

  /// Сохраняет расчёт за месяц: обновляет существующий
  /// (сотрудник + год + месяц) или добавляет новый. Возвращает uuid.
  Future<String> saveResult(PayrollResultsCompanion result) =>
      transaction(() async {
        final existing = await resultFor(
          result.employeeUuid.value,
          result.year.value,
          result.month.value,
        );
        final editor = await db.deviceId();
        final stamped = result.copyWith(
          legacyId: const Value.absent(),
          deleted: const Value(false),
          remoteUpdatedAt: const Value.absent(),
          updatedAt: Value(db.nowUtc()),
          editedBy: Value(editor),
        );
        if (existing != null) {
          await (update(payrollResults)
                ..where((t) => t.uuid.equals(existing.uuid)))
              .write(stamped.copyWith(uuid: const Value.absent()));
          return existing.uuid;
        }
        final uuid = result.uuid.present ? result.uuid.value : newUuid();
        await into(payrollResults).insert(stamped.copyWith(uuid: Value(uuid)));
        return uuid;
      });

  Future<PayrollResultRow?> resultFor(
    String employeeUuid,
    int year,
    int month,
  ) =>
      (select(payrollResults)..where(
            (t) =>
                t.employeeUuid.equals(employeeUuid) &
                t.year.equals(year) &
                t.month.equals(month) &
                t.deleted.equals(false),
          ))
          .getSingleOrNull();

  Future<List<PayrollResultRow>> resultsForMonth(int year, int month) =>
      (select(payrollResults)
            ..where(
              (t) =>
                  t.year.equals(year) &
                  t.month.equals(month) &
                  t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.employeeUuid)]))
          .get();

  /// Начислено по сотрудникам за месяцы строго до [year]-[month].
  Future<Map<String, double>> accruedBefore(int year, int month) async {
    final rows = await customSelect(
      'SELECT employee_uuid, SUM(total_salary) AS total FROM payroll_results '
      'WHERE deleted = 0 AND (year < ? OR (year = ? AND month < ?)) '
      'GROUP BY employee_uuid',
      variables: [
        Variable<int>(year),
        Variable<int>(year),
        Variable<int>(month),
      ],
      readsFrom: {payrollResults},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('employee_uuid'): row.read<double>('total'),
    };
  }

  Future<int> softDeleteResult(String uuid) =>
      softDeleteRow(payrollResults, uuid);
}
