import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  const emp = '01900000-0000-7000-8000-000000000001';

  SyncExport sample() => SyncExport(
        exportedAt: DateTime.utc(2026, 9, 27, 8, 0, 0, 0, 123),
        deviceId: 'dev-1',
        rows: [
          SyncChange(
            table: 'employees',
            uuid: emp,
            updatedAt: DateTime.utc(2026, 9, 26, 4, 54, 54, 502, 936),
            deleted: false,
            editedBy: 'dev-1',
            data: {
              'legacy_id': 1,
              'full_name': 'Иванов Иван',
              'position': 'Тракторист',
              'hire_date': '2026-01-15',
              'dismissal_date': null,
              'base_rate': 1000.0,
              'field_rate': 1500.0,
            },
          ),
        ],
        counts: {
          for (final t in syncTables) t.name: t.name == 'employees' ? (1, 0) : (0, 0),
        },
        payroll: [
          const PayrollCheck(
            employeeUuid: emp,
            year: 2026,
            month: 9,
            baseDays: 1,
            fieldDays: 2.5,
            sickDays: 0,
            vacationDays: 0,
            totalSalary: 4750.5,
            skippedWorkDays: 1,
            startingBalance: -100.25,
          ),
        ],
      );

  test('JSON туда и обратно без потерь', () {
    final back = SyncExport.fromJson(sample().toJson());
    expect(back.exportedAt, sample().exportedAt);
    expect(back.deviceId, 'dev-1');
    expect(back.rows.single.data, sample().rows.single.data);
    expect(back.rows.single.updatedAt, sample().rows.single.updatedAt);
    expect(back.rows.single.editedBy, 'dev-1');
    expect(back.counts['employees'], (1, 0));
    expect(back.payroll.single.toJson(), sample().payroll.single.toJson());
  });

  test('чужой формат — отказ', () {
    expect(() => SyncExport.fromJson({'format': 'kfh-export', 'version': 2}),
        throwsA(isA<SyncFormatException>()));
    expect(() => SyncExport.fromJson('строка'), throwsA(isA<SyncFormatException>()));
  });

  test('все ошибки — сразу, списком', () {
    final json = sample().toJson();
    (((json['rows'] as List).single as Map)['data'] as Map)['hire_date'] = '15.01.2026';
    (json['payroll'] as List).add({'employee_uuid': 'x'});
    json['device_id'] = '';
    json['counts'] = {'users': {'total': 1, 'deleted': 0}};
    expect(
      () => SyncExport.fromJson(json),
      throwsA(isA<SyncExportException>()
          .having((e) => e.problems, 'problems', hasLength(4))),
    );
  });
}
