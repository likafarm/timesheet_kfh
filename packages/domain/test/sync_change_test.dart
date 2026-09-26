import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  const employee = '01900000-0000-7000-8000-000000000001';
  const row = '01900000-0000-7000-8000-000000000002';

  Map<String, Object?> timesheetData({Map<String, Object?> patch = const {}}) =>
      {
        'legacy_id': null,
        'employee_uuid': employee,
        'date': '2026-09-01',
        'day_type': 'work',
        'days': 1,
        'work_place': 'field',
        'notes': null,
        'created_at': '2026-09-01T10:00:00.123456',
        ...patch,
      };

  Map<String, Object?> change({
    Map<String, Object?> data = const {},
    Map<String, Object?> patch = const {},
  }) =>
      {
        'change_id': '17',
        'table': 'timesheet',
        'uuid': row,
        'updated_at': '2026-09-26T04:54:54.502936Z',
        'deleted': false,
        'data': timesheetData(patch: data),
        ...patch,
      };

  test('верное изменение разбирается; число дней — double', () {
    final c = SyncChange.fromJson(change());
    expect(c.table, 'timesheet');
    expect(c.uuid, row);
    expect(c.changeId, '17');
    expect(c.updatedAt, DateTime.utc(2026, 9, 26, 4, 54, 54, 502, 936));
    expect(c.data['days'], isA<double>());
    expect(c.data['days'], 1.0);
  });

  test('toJson → fromJson без потерь, микросекунды сохраняются', () {
    final c = SyncChange.fromJson(change());
    final json = c.toJson();
    expect(json['updated_at'], '2026-09-26T04:54:54.502936Z');
    final back = SyncChange.fromJson(json);
    expect(back.updatedAt, c.updatedAt);
    expect(back.data, c.data);
  });

  group('отказы с понятной причиной', () {
    void rejects(Map<String, Object?> json, String fragment) => expect(
          () => SyncChange.fromJson(json),
          throwsA(isA<SyncFormatException>()
              .having((e) => e.message, 'message', contains(fragment))),
          reason: fragment,
        );

    test('таблица, uuid, deleted, время', () {
      rejects(change(patch: {'table': 'users'}), 'неизвестная таблица');
      rejects(change(patch: {'table': 'sync_state'}), 'неизвестная таблица');
      rejects(change(patch: {'uuid': '0190abcd-0000-7000-8000-00000000000A'}),
          'uuid');
      rejects(change(patch: {'uuid': 'abc'}), 'uuid');
      rejects(change(patch: {'deleted': 0}), 'deleted');
      rejects(change(patch: {'updated_at': '2026-09-26T04:54:54'}), 'UTC');
      rejects(change(patch: {'updated_at': '2026-09-26T07:54:54+03:00'}), 'UTC');
      rejects(change(patch: {'updated_at': 'вчера Z'}), 'updated_at');
      rejects(change(patch: {'change_id': 5}), 'change_id');
    });

    test('состав полей: лишнее и недостающее', () {
      rejects(change(data: {'password': 'x'}), 'неизвестные поля password');
      final missing = change();
      (missing['data'] as Map).remove('notes');
      rejects(missing, 'нет поля notes');
      rejects(change(patch: {'data': 'строка'}), 'data');
    });

    test('значения', () {
      rejects(change(data: {'date': '2026-02-30'}), 'timesheet.date');
      rejects(change(data: {'date': '01.09.2026'}), 'timesheet.date');
      rejects(change(data: {'day_type': 'holiday'}), 'недопустимое');
      rejects(change(data: {'work_place': 'office'}), 'недопустимое');
      rejects(change(data: {'days': 2}), 'вне границ');
      rejects(change(data: {'days': '1'}), 'не число');
      rejects(change(data: {'employee_uuid': null}), 'не может быть пустым');
      rejects(change(data: {'employee_uuid': 'x'}), 'не uuid');
      rejects(change(data: {'notes': 'я' * 10001}), 'длиннее');
      rejects(change(data: {'legacy_id': 1.5}), 'не целое');
    });
  });

  test('целое 5.0 приводится к int, is_approved — только bool', () {
    final vacation = syncTableByName('vacation')!;
    final data = <String, Object?>{
      'legacy_id': 3.0,
      'employee_uuid': employee,
      'start_date': '2026-07-01',
      'end_date': '2026-07-14',
      'vacation_type': 'annual',
      'days_count': 14.0,
      'is_approved': true,
      'notes': null,
    };
    final ok = validateSyncData(vacation, data);
    expect(ok['days_count'], isA<int>());
    expect(ok['legacy_id'], 3);
    expect(() => validateSyncData(vacation, {...data, 'is_approved': 1}),
        throwsA(isA<SyncFormatException>()));
  });

  test('дни: високосный февраль и конец месяца', () {
    expect(isIsoDay('2028-02-29'), isTrue);
    expect(isIsoDay('2026-02-29'), isFalse);
    expect(isIsoDay('2026-04-31'), isFalse);
    expect(isIsoDay('2026-12-31'), isTrue);
  });

  test('порядок таблиц: сотрудники раньше ссылающихся на них', () {
    final employees = syncTableOrder('employees');
    for (final t in syncTables.where((t) => t.hasEmployee)) {
      expect(syncTableOrder(t.name), greaterThan(employees), reason: t.name);
    }
  });
}
