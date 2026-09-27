import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('смена рабочего дня на больничный снимает место работы', () async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final repos = DriftRepositories(db);
    final app = AppProvider(AppDatabase(db, ':memory:'));
    final emp = await repos.employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    final day = DateTime(2026, 9, 3);
    await app.saveTimesheetRecord(
      TimesheetRecord(
        employeeId: emp,
        date: day,
        dayType: 'work',
        days: 1,
        workPlace: 'field',
        notes: 'заметка',
      ),
    );
    await app.saveTimesheetRecord(
      TimesheetRecord(employeeId: emp, date: day, dayType: 'sick', days: 1),
    );
    final saved = (await repos.timesheet.on(emp, day))!;
    expect(saved.dayType, 'sick');
    expect(saved.workPlace, isNull);
    expect(saved.notes, 'заметка');
  });
}
