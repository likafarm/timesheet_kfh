import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

const _ivan = '00000000-0000-7000-8000-000000000001';
const _petr = '00000000-0000-7000-8000-000000000002';

String _id(int n) => '00000000-0000-7000-9000-${n.toString().padLeft(12, '0')}';

final _at = DateTime.utc(2026, 9, 1, 10);

SyncChange _employee(String uuid, String name, {bool deleted = false}) =>
    SyncChange(
      table: 'employees',
      uuid: uuid,
      updatedAt: _at,
      deleted: deleted,
      data: {
        'legacy_id': null,
        'full_name': name,
        'position': 'Рабочий',
        'hire_date': '2025-03-01',
        'dismissal_date': null,
        'base_rate': 1000.0,
        'field_rate': 1500.0,
      },
    );

SyncChange _day(
  int n,
  String employee,
  String date, {
  String place = 'field',
  double days = 1,
  bool deleted = false,
}) => SyncChange(
  table: 'timesheet',
  uuid: _id(n),
  updatedAt: _at,
  deleted: deleted,
  data: {
    'legacy_id': null,
    'employee_uuid': employee,
    'date': date,
    'day_type': 'work',
    'days': days,
    'work_place': place,
    'notes': null,
    'created_at': '2026-09-01T10:00:00.000',
  },
);

SyncChange _payment(int n, String employee, String date, double amount) =>
    SyncChange(
      table: 'payments',
      uuid: _id(n),
      updatedAt: _at,
      deleted: false,
      data: {
        'legacy_id': null,
        'employee_uuid': employee,
        'payment_date': date,
        'amount': amount,
        'payment_type': 'salary',
        'period_start': null,
        'period_end': null,
        'payment_method': null,
        'document_number': null,
        'notes': null,
        'created_at': '2026-09-01T10:00:00.000',
      },
    );

SyncChange _payroll(int n, String employee) => SyncChange(
  table: 'payroll_results',
  uuid: _id(n),
  updatedAt: _at,
  deleted: false,
  data: {
    'legacy_id': null,
    'employee_uuid': employee,
    'year': 2026,
    'month': 9,
    'base_days': 0.0,
    'field_days': 1.0,
    'sick_days': 0.0,
    'vacation_days': 0.0,
    'total_salary': 1500.0,
    'base_rate_used': 1000.0,
    'field_rate_used': 1500.0,
    'calculated_at': '2026-09-01T10:00:00.000',
    'status': 'calculated',
    'skipped_work_days': 0,
  },
);

void main() {
  final people = [_employee(_ivan, 'Иванов'), _employee(_petr, 'Петров')];

  group('что изменилось с момента копии', () {
    test('добавлено, изменено, удалено; одинаковое и расчёты — не в счёт', () {
      final then = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01'),
        _day(2, _ivan, '2026-09-02'),
        _day(3, _ivan, '2026-09-03'),
        _day(5, _ivan, '2026-09-05', deleted: true),
        _payroll(90, _ivan),
      ]);
      final now = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01'),
        _day(2, _ivan, '2026-09-02', place: 'base', days: 0.5),
        _day(3, _ivan, '2026-09-03', deleted: true),
        _day(4, _petr, '2026-09-04'),
        _day(5, _ivan, '2026-09-05', deleted: true),
      ]);
      final diff = diffSnapshots(then, now);
      expect(
        [for (final c in diff) (c.uuid, c.kind)],
        [
          (_id(2), RecordChangeKind.changed),
          (_id(3), RecordChangeKind.removed),
          (_id(4), RecordChangeKind.added),
        ],
      );
      expect(diff[0].changedFields, ['days', 'work_place']);
      expect(diff[2].employeeUuid, _petr);
    });

    test('удалённая в копии и живая сейчас — добавлена', () {
      final then = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01', deleted: true),
      ]);
      final now = DataSnapshot([...people, _day(1, _ivan, '2026-09-01')]);
      expect(diffSnapshots(then, now).single.kind, RecordChangeKind.added);
    });

    test('отбор по месяцу и сотруднику', () {
      final then = DataSnapshot(people);
      final now = DataSnapshot([
        _employee(_ivan, 'Иванов И.'),
        people[1],
        _day(1, _ivan, '2026-08-31'),
        _payment(2, _petr, '2026-09-10', 5000),
      ]);
      final diff = diffSnapshots(then, now);
      expect(diff.map((c) => c.table), ['employees', 'timesheet', 'payments']);
      expect(diff[0].employeeUuid, _ivan);
      expect(diff[0].touchesMonth(2026, 9), isFalse);
      expect(diff[1].touchesMonth(2026, 8), isTrue);
      expect(diff[1].touchesMonth(2026, 9), isFalse);
      expect(diff[2].touchesMonth(2026, 9), isTrue);
    });
  });

  group('план возврата', () {
    test('добавленное удаляется, изменённое и удалённое возвращаются', () {
      final then = DataSnapshot([
        ...people,
        _day(2, _ivan, '2026-09-02'),
        _day(3, _ivan, '2026-09-03'),
      ]);
      final now = DataSnapshot([
        ...people,
        _day(2, _ivan, '2026-09-02', place: 'base'),
        _day(3, _ivan, '2026-09-03', deleted: true),
        _day(4, _petr, '2026-09-04'),
      ]);
      final plan = planRestore(
        diffSnapshots(then, now),
        now: now,
        lockedMonths: const {},
      );
      expect(plan.skipped, isEmpty);
      expect(
        [for (final e in plan.edits) (e.uuid, e.deleted, e.data['work_place'])],
        [
          (_id(4), true, 'field'),
          (_id(2), false, 'field'),
          (_id(3), false, 'field'),
        ],
      );
    });

    test('закрытый месяц не трогается — с объяснением', () {
      final then = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-08-20'),
        _day(2, _ivan, '2026-09-02'),
      ]);
      final now = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-08-20', place: 'base'),
        _day(2, _ivan, '2026-09-02', place: 'base'),
      ]);
      final plan = planRestore(
        diffSnapshots(then, now),
        now: now,
        lockedMonths: {PeriodGuard.monthKey(2026, 8)},
      );
      expect(plan.edits.single.uuid, _id(2));
      expect(plan.skipped.single.change.uuid, _id(1));
      expect(plan.skipped.single.reason, contains('08.2026 закрыт'));
    });

    test('занятый день табеля освобождается', () {
      final then = DataSnapshot([...people, _day(1, _ivan, '2026-09-01')]);
      final now = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01', deleted: true),
        _day(2, _ivan, '2026-09-01', place: 'base'),
      ]);
      final removed = diffSnapshots(
        then,
        now,
      ).where((c) => c.kind == RecordChangeKind.removed);
      final plan = planRestore(removed, now: now, lockedMonths: const {});
      expect(
        [for (final e in plan.edits) (e.uuid, e.deleted, e.implied)],
        [(_id(2), true, true), (_id(1), false, false)],
      );
    });

    test('запись, уезжающая на свой день, день не занимает', () {
      final then = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01'),
        _day(2, _ivan, '2026-09-02'),
      ]);
      final now = DataSnapshot([
        ...people,
        _day(1, _ivan, '2026-09-01', deleted: true),
        _day(2, _ivan, '2026-09-01'),
      ]);
      final plan = planRestore(
        diffSnapshots(then, now),
        now: now,
        lockedMonths: const {},
      );
      expect(plan.skipped, isEmpty);
      expect(
        [for (final e in plan.edits) (e.uuid, e.data['date'], e.deleted)],
        [(_id(1), '2026-09-01', false), (_id(2), '2026-09-02', false)],
      );
    });

    test('запись без сотрудника пропускается, с ним вместе — возвращается', () {
      final then = DataSnapshot([...people, _day(1, _petr, '2026-09-01')]);
      final now = DataSnapshot([
        people[0],
        _employee(_petr, 'Петров', deleted: true),
        _day(1, _petr, '2026-09-01', deleted: true),
      ]);
      final diff = diffSnapshots(then, now);
      final alone = planRestore(
        diff.where((c) => c.table == 'timesheet'),
        now: now,
        lockedMonths: const {},
      );
      expect(alone.edits, isEmpty);
      expect(alone.skipped.single.reason, contains('Сотрудника'));

      final both = planRestore(diff, now: now, lockedMonths: const {});
      expect(both.edits.map((e) => e.table), ['employees', 'timesheet']);
    });

    test('расчёты ЗП не возвращаются', () {
      final then = DataSnapshot([...people, _payroll(90, _ivan)]);
      final now = DataSnapshot(people);
      final diff = diffSnapshots(then, now, tables: const ['payroll_results']);
      final plan = planRestore(diff, now: now, lockedMonths: const {});
      expect(plan.edits, isEmpty);
      expect(plan.skipped.single.reason, contains('сервер'));
    });
  });

  group('файл выгрузки сервера', () {
    test('туда и обратно', () {
      final file = SnapshotFile(
        createdAt: DateTime.utc(2026, 9, 30, 0, 30),
        source: 'server 0.8.0',
        rows: [...people, _day(1, _ivan, '2026-09-01')],
      );
      final back = SnapshotFile.fromJson(jsonDecode(jsonEncode(file.toJson())));
      expect(back.createdAt, file.createdAt);
      expect(back.source, 'server 0.8.0');
      expect(back.snapshot.counts['employees'], 2);
      expect(diffSnapshots(file.snapshot, back.snapshot), isEmpty);
    });

    test('чужой файл и новая версия — понятный отказ', () {
      expect(
        () => SnapshotFile.fromJson({'format': 'x'}),
        throwsA(isA<SyncFormatException>()),
      );
      expect(
        () => SnapshotFile.fromJson({
          'format': SnapshotFile.formatName,
          'version': 2,
        }),
        throwsA(
          isA<SyncFormatException>().having(
            (e) => e.message,
            'message',
            contains('обновите программу'),
          ),
        ),
      );
    });
  });
}
