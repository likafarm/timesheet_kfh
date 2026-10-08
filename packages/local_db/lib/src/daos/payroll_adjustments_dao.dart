import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'payroll_adjustments_dao.g.dart';

@DriftAccessor(tables: [PayrollAdjustments])
class PayrollAdjustmentsDao extends DatabaseAccessor<LocalDatabase>
    with _$PayrollAdjustmentsDaoMixin, SyncStamping {
  PayrollAdjustmentsDao(super.db);

  /// Добавляет корректировку (uuid — заданный или новый), возвращает uuid.
  Future<String> insertAdjustment(PayrollAdjustmentsCompanion row) async {
    final editor = await db.deviceId();
    final uuid = row.uuid.present ? row.uuid.value : newUuid();
    await into(payrollAdjustments).insert(
      row.copyWith(
        uuid: Value(uuid),
        deleted: const Value(false),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
    return uuid;
  }

  /// Обновляет корректировку; ключ и служебные поля из [changes]
  /// игнорируются.
  Future<int> updateAdjustment(
    String uuid,
    PayrollAdjustmentsCompanion changes,
  ) async {
    final editor = await db.deviceId();
    return (update(payrollAdjustments)
          ..where((t) => t.uuid.equals(uuid) & t.deleted.equals(false)))
        .write(
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

  /// Живые корректировки; [year]/[month] и [employeeUuid] — отбор.
  Future<List<PayrollAdjustmentRow>> adjustments({
    int? year,
    int? month,
    String? employeeUuid,
  }) {
    final query = select(payrollAdjustments)
      ..where((t) => t.deleted.equals(false));
    if (year != null) query.where((t) => t.year.equals(year));
    if (month != null) query.where((t) => t.month.equals(month));
    if (employeeUuid != null) {
      query.where((t) => t.employeeUuid.equals(employeeUuid));
    }
    query.orderBy([
      (t) => OrderingTerm.asc(t.year),
      (t) => OrderingTerm.asc(t.month),
      (t) => OrderingTerm.asc(t.uuid),
    ]);
    return query.get();
  }

  Future<int> softDeleteAdjustment(String uuid) =>
      softDeleteRow(payrollAdjustments, uuid);
}
