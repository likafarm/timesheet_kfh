import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

/// Сообщение «табель внесён» (6.10).
void main() {
  Map<String, Object?> rec(
    String emp,
    String name,
    String user, {
    String type = 'work',
    double days = 1,
    String? place = 'base',
  }) => {
    'employee_uuid': emp,
    'employee_name': name,
    'day_type': type,
    'days': days,
    'work_place': place,
    'user_uuid': user,
    'user_login': user,
    'user_name': user == 'op' ? 'Оператор Олег' : 'Админ Иван',
    'user_role': user == 'op' ? 'operator' : 'admin',
    'at': '2026-09-30T15:00:00.000Z',
  };

  final day = TimesheetDayInfo.fromJson({
    'date': '2026-09-30',
    'active_employees': 5,
    'records': [
      rec('1', 'А', 'op'),
      rec('2', 'Б', 'op', place: 'field'),
      rec('3', 'В', 'op'),
      rec('4', 'Г', 'op', type: 'sick', place: null),
      rec('5', 'Д', 'adm', days: 0.5, place: 'field'),
    ],
  });

  test('разбор ответа сервера', () {
    expect(day.date, DateTime(2026, 9, 30));
    expect(day.records, hasLength(5));
    expect(day.filled, isTrue);
    expect(day.records.first.at, DateTime.utc(2026, 9, 30, 15));
  });

  test('итог отметок по видам', () {
    expect(
      describeMarks(day.records),
      '2 база, 1 поле, 1 ½ поле, 1 больничный',
    );
  });

  test('админу — что внёс оператор; своё не в счёт', () {
    final m = enteredByOthersMessage(day, 'adm')!;
    expect(m.title, 'Табель за сегодня внесён: Оператор Олег');
    expect(
      m.text,
      'Оператор Олег: 2 база, 1 поле, 1 больничный\nОтмечено 5 из 5',
    );
  });

  test('двое авторов — оба; только свои отметки — сообщения нет', () {
    final m = enteredByOthersMessage(day, 'someone')!;
    expect(m.title, 'Табель за сегодня внесён');
    expect(m.text, contains('Админ Иван: 1 ½ поле'));
    final mine = TimesheetDayInfo.fromJson({
      'date': '2026-09-30',
      'active_employees': 3,
      'records': [rec('1', 'А', 'op')],
    });
    expect(enteredByOthersMessage(mine, 'op'), isNull);
    expect(mine.filled, isFalse);
  });
}
