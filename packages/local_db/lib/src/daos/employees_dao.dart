import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../tables/tables.dart';
import 'sync_stamping.dart';

part 'employees_dao.g.dart';

@DriftAccessor(tables: [Employees])
class EmployeesDao extends DatabaseAccessor<LocalDatabase>
    with _$EmployeesDaoMixin, SyncStamping {
  EmployeesDao(super.db);

  /// Добавляет сотрудника, возвращает его uuid.
  Future<String> insertEmployee(EmployeesCompanion employee) async {
    final editor = await db.deviceId();
    final uuid = employee.uuid.present ? employee.uuid.value : newUuid();
    await into(employees).insert(
      employee.copyWith(
        uuid: Value(uuid),
        deleted: const Value(false),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
    return uuid;
  }

  /// Сотрудники по ФИО. [activeOn] — только не уволенные на эту дату
  /// (`dismissal_date` пуста или позже даты).
  Future<List<EmployeeRow>> allEmployees({DateTime? activeOn}) {
    final query = select(employees)..where((t) => t.deleted.equals(false));
    if (activeOn != null) {
      final day = formatDateIso(activeOn);
      query.where(
        (t) =>
            t.dismissalDate.isNull() | t.dismissalDate.isBiggerThanValue(day),
      );
    }
    query.orderBy([(t) => OrderingTerm.asc(t.fullName)]);
    return query.get();
  }

  /// Сотрудник по uuid; удалённые — только с [includeDeleted].
  Future<EmployeeRow?> employeeByUuid(
    String uuid, {
    bool includeDeleted = false,
  }) {
    final query = select(employees)..where((t) => t.uuid.equals(uuid));
    if (!includeDeleted) query.where((t) => t.deleted.equals(false));
    return query.getSingleOrNull();
  }

  /// Обновляет сотрудника; ключ и служебные поля из [changes] игнорируются.
  Future<int> updateEmployee(String uuid, EmployeesCompanion changes) async {
    final editor = await db.deviceId();
    return (update(
      employees,
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

  /// Мягкое удаление без каскада: история сотрудника остаётся.
  Future<int> softDeleteEmployee(String uuid) => softDeleteRow(employees, uuid);
}
