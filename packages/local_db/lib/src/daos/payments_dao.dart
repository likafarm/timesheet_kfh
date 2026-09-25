import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'payments_dao.g.dart';

@DriftAccessor(tables: [Payments])
class PaymentsDao extends DatabaseAccessor<LocalDatabase>
    with _$PaymentsDaoMixin, SyncStamping {
  PaymentsDao(super.db);

  /// Добавляет выплату, возвращает uuid.
  Future<String> insertPayment(PaymentsCompanion payment) async {
    final editor = await db.deviceId();
    final uuid = payment.uuid.present ? payment.uuid.value : newUuid();
    await into(payments).insert(
      payment.copyWith(
        uuid: Value(uuid),
        deleted: const Value(false),
        createdAt: Value(db.nowLocalIso()),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
    return uuid;
  }

  /// Выплаты, новые сверху. [employeeUuid] — только одного сотрудника;
  /// [start] и [end] (оба сразу) — период включительно.
  Future<List<PaymentRow>> paymentsList({
    String? employeeUuid,
    DateTime? start,
    DateTime? end,
  }) {
    final query = select(payments)..where((t) => t.deleted.equals(false));
    if (employeeUuid != null) {
      query.where((t) => t.employeeUuid.equals(employeeUuid));
    }
    if (start != null && end != null) {
      final (from, to) = dateRangeExclusiveEnd(start, end);
      query.where(
        (t) =>
            t.paymentDate.isBiggerOrEqualValue(from) &
            t.paymentDate.isSmallerThanValue(to),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.paymentDate)]);
    return query.get();
  }

  /// Сумма выплат по сотрудникам строго до [date].
  Future<Map<String, double>> paidBefore(DateTime date) async {
    final rows = await customSelect(
      'SELECT employee_uuid, SUM(amount) AS total FROM payments '
      'WHERE deleted = 0 AND payment_date < ? GROUP BY employee_uuid',
      variables: [Variable<String>(formatDateIso(date))],
      readsFrom: {payments},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('employee_uuid'): row.read<double>('total'),
    };
  }

  /// Обновляет выплату; ключ и служебные поля из [changes] игнорируются.
  Future<int> updatePayment(String uuid, PaymentsCompanion changes) async {
    final editor = await db.deviceId();
    return (update(
      payments,
    )..where((t) => t.uuid.equals(uuid) & t.deleted.equals(false))).write(
      changes.copyWith(
        uuid: const Value.absent(),
        legacyId: const Value.absent(),
        deleted: const Value.absent(),
        remoteUpdatedAt: const Value.absent(),
        createdAt: const Value.absent(),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
  }

  Future<int> softDeletePayment(String uuid) => softDeleteRow(payments, uuid);
}
