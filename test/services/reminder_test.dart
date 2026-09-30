import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/services/reminder.dart';

/// Напоминание о табеле (6.10, решения владельца 2026-09-30).
void main() {
  test('время по роли: оператор 19:00, админ 19:20, бухгалтеру — нет', () {
    expect(defaultReminderTime('operator'), (hour: 19, minute: 0));
    expect(defaultReminderTime('admin'), (hour: 19, minute: 20));
    expect(defaultReminderTime('accountant'), isNull);
    expect(defaultReminderTime(null), isNull);
  });

  test('каждый день, выходные и праздники тоже', () {
    // Пятница 30.10.2026, 18:00: 31.10 суббота, 1.11 воскресенье,
    // 4.11 — праздник.
    final times = reminderTimes(
      now: DateTime(2026, 10, 30, 18),
      settings: const ReminderSettings(hour: 19, minute: 20),
      days: 6,
    );
    expect(times, [
      for (final d in [30, 31]) DateTime(2026, 10, d, 19, 20),
      for (final d in [1, 2, 3, 4]) DateTime(2026, 11, d, 19, 20),
    ]);
  });

  test('время прошло или «Сегодня не нужно» — со следующего дня', () {
    final now = DateTime(2026, 10, 29, 18);
    const s = ReminderSettings();
    expect(
      reminderTimes(now: now, settings: s, days: 2).first,
      DateTime(2026, 10, 29, 19),
    );
    expect(
      reminderTimes(
        now: now,
        settings: s,
        skipDay: DateTime(2026, 10, 29),
        days: 2,
      ),
      [DateTime(2026, 10, 30, 19)],
    );
    // Вчерашний «не нужно» сегодня не действует.
    expect(
      reminderTimes(
        now: now,
        settings: s,
        skipDay: DateTime(2026, 10, 28),
        days: 2,
      ).first.day,
      29,
    );
    expect(
      reminderTimes(now: DateTime(2026, 10, 29, 19, 30), settings: s, days: 2),
      [DateTime(2026, 10, 30, 19)],
    );
    expect(
      reminderTimes(now: now, settings: const ReminderSettings(enabled: false)),
      isEmpty,
    );
  });

  group('что показать', () {
    Map<String, Object?> rec(String emp, String user) => {
      'employee_uuid': emp,
      'employee_name': emp,
      'day_type': 'work',
      'days': 1,
      'work_place': 'base',
      'user_uuid': user,
      'user_name': user == 'op' ? 'Оператор Олег' : 'Админ Иван',
    };
    TimesheetDayInfo day(int active, List<Map<String, Object?>> records) =>
        TimesheetDayInfo.fromJson({
          'date': '2026-09-30',
          'active_employees': active,
          'records': records,
        });

    test('нет связи — обычное напоминание', () {
      expect(decideReminder(null, 'adm').kind, ReminderKind.remind);
    });

    test('пусто — напоминание', () {
      expect(decideReminder(day(3, []), 'adm').kind, ReminderKind.remind);
    });

    test('внёс другой — «табель внесён» с итогом', () {
      final d = decideReminder(day(3, [rec('А', 'op'), rec('Б', 'op')]), 'adm');
      expect(d.kind, ReminderKind.entered);
      expect(d.title, 'Табель за сегодня внесён: Оператор Олег');
      expect(d.text, 'Оператор Олег: 2 база\nОтмечено 2 из 3');
    });

    test('всё внёс сам — ничего; внёс не всё — напоминание', () {
      expect(
        decideReminder(day(2, [rec('А', 'op'), rec('Б', 'op')]), 'op').kind,
        ReminderKind.none,
      );
      expect(
        decideReminder(day(3, [rec('А', 'op')]), 'op').kind,
        ReminderKind.remind,
      );
    });
  });
}
