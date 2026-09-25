import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../exceptions.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'timesheet_dao.g.dart';

@DriftAccessor(tables: [Timesheet])
class TimesheetDao extends DatabaseAccessor<LocalDatabase>
    with _$TimesheetDaoMixin, SyncStamping {
  TimesheetDao(super.db);

  /// Добавляет запись табеля, возвращает uuid.
  /// Если на эту дату у сотрудника уже есть запись — [DuplicateEntryException].
  Future<String> insertRecord(TimesheetCompanion record) =>
      transaction(() async {
        final existing = await recordOn(
          record.employeeUuid.value,
          parseDateIso(record.date.value),
        );
        if (existing != null) {
          throw const DuplicateEntryException('Запись на эту дату уже есть');
        }
        final editor = await db.deviceId();
        final uuid = record.uuid.present ? record.uuid.value : newUuid();
        await into(timesheet).insert(
          record.copyWith(
            uuid: Value(uuid),
            deleted: const Value(false),
            createdAt: Value(db.nowLocalIso()),
            updatedAt: Value(db.nowUtc()),
            editedBy: Value(editor),
          ),
        );
        return uuid;
      });

  /// Записи за период [start]–[end] включительно, новые сверху.
  Future<List<TimesheetRow>> recordsInPeriod(
    DateTime start,
    DateTime end, {
    String? employeeUuid,
  }) {
    final (from, to) = dateRangeExclusiveEnd(start, end);
    final query = select(timesheet)
      ..where(
        (t) =>
            t.deleted.equals(false) &
            t.date.isBiggerOrEqualValue(from) &
            t.date.isSmallerThanValue(to),
      );
    if (employeeUuid != null) {
      query.where((t) => t.employeeUuid.equals(employeeUuid));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.asc(t.employeeUuid),
    ]);
    return query.get();
  }

  /// Запись сотрудника на день [date].
  Future<TimesheetRow?> recordOn(String employeeUuid, DateTime date) =>
      (select(timesheet)..where(
            (t) =>
                t.employeeUuid.equals(employeeUuid) &
                t.date.equals(formatDateIso(date)) &
                t.deleted.equals(false),
          ))
          .getSingleOrNull();

  /// Обновляет запись; ключ и служебные поля из [changes] игнорируются.
  Future<int> updateRecord(String uuid, TimesheetCompanion changes) async {
    final editor = await db.deviceId();
    return (update(
      timesheet,
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

  Future<int> softDeleteRecord(String uuid) => softDeleteRow(timesheet, uuid);
}
