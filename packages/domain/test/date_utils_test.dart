import 'package:test/test.dart';
import 'package:kfh_domain/kfh_domain.dart';

void main() {
  group('formatDateIso', () {
    test('дополняет нулями и отбрасывает время', () {
      expect(formatDateIso(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });

    test('null-версия', () {
      expect(formatDateIsoOrNull(null), isNull);
      expect(formatDateIsoOrNull(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('parseDateIso', () {
    test('читает чистую дату', () {
      expect(parseDateIso('2026-09-25'), DateTime(2026, 9, 25));
    });

    test('читает старые значения со временем', () {
      expect(parseDateIso('2026-09-25T14:30:00.000'), DateTime(2026, 9, 25));
      expect(parseDateIso('  2026-09-25  '), DateTime(2026, 9, 25));
    });

    test('пустая строка — ошибка', () {
      expect(() => parseDateIso('  '), throwsFormatException);
    });

    test('null/пустая строка в OrNull-версии', () {
      expect(parseDateIsoOrNull(null), isNull);
      expect(parseDateIsoOrNull(''), isNull);
    });
  });

  test('dateOnlyString обрезает время', () {
    expect(dateOnlyString('2026-09-25T10:00:00'), '2026-09-25');
    expect(dateOnlyString(null), isNull);
    expect(dateOnlyString(' '), isNull);
  });

  group('около полуночи и моменты в UTC', () {
    // Ожидания считаются через toLocal(): тест верен в любом поясе.
    final moscow = DateTime.now().timeZoneOffset == const Duration(hours: 3);

    test('последняя и первая минута суток — тот же день', () {
      expect(formatDateIso(DateTime(2026, 8, 31, 23, 59, 59, 999)), '2026-08-31');
      expect(formatDateIso(DateTime(2026, 9, 1, 0, 0, 0)), '2026-09-01');
      expect(formatDateIso(DateTime(2026, 9, 1, 0, 0, 1)), '2026-09-01');
    });

    test('момент в UTC — день по местному календарю', () {
      // 21:30 UTC 31.08 — по Москве уже 00:30 01.09.
      final moment = DateTime.utc(2026, 8, 31, 21, 30);
      final local = moment.toLocal();
      final expected = DateTime(local.year, local.month, local.day);
      expect(calendarDay(moment), expected);
      expect(formatDateIso(moment), formatDateIso(expected));
      if (moscow) expect(formatDateIso(moment), '2026-09-01');
    });

    test('старое значение с поясом читается по местному дню', () {
      final expected = calendarDay(DateTime.utc(2026, 8, 31, 21, 30));
      expect(parseDateIso('2026-08-31T21:30:00Z'), expected);
      expect(parseDateIso('2026-08-31T21:30:00.000Z'), expected);
      expect(parseDateIso('2026-09-01T00:30:00+03:00'),
          calendarDay(DateTime.utc(2026, 8, 31, 21, 30)));
      if (moscow) expect(parseDateIso('2026-08-31T21:30:00Z'), DateTime(2026, 9, 1));
      // Без пояса — местное время, число не меняется.
      expect(parseDateIso('2026-08-31T23:59:59'), DateTime(2026, 8, 31));
    });

    test('dateOnlyString: момент с поясом — местный день, мусор — как есть', () {
      expect(dateOnlyString('2026-08-31T21:30:00Z'),
          formatDateIso(DateTime.utc(2026, 8, 31, 21, 30)));
      expect(dateOnlyString('31.08.2026 x'), '31.08.2026');
    });
  });

  group('addCalendarDays — сдвиг по календарю, не на 24 часа', () {
    test('границы месяца, года, високосный февраль', () {
      expect(addCalendarDays(DateTime(2026, 10, 1), -1), DateTime(2026, 9, 30));
      expect(addCalendarDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
      expect(addCalendarDays(DateTime(2028, 3, 1), -1), DateTime(2028, 2, 29));
      expect(addCalendarDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      expect(addCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    });

    test('время суток отбрасывается, результат — полночь', () {
      expect(addCalendarDays(DateTime(2026, 9, 16, 23, 59), -1), DateTime(2026, 9, 15));
      expect(addCalendarDays(DateTime(2026, 9, 16, 0, 1), -1), DateTime(2026, 9, 15));
    });

    test('каждый день двух лет: −1 день и +1 день обратно', () {
      // Если бы сдвиг шёл на 24 часа, в поясе с переводом часов нашёлся
      // бы день, где число не сходится.
      var day = DateTime(2025, 1, 1);
      for (var i = 0; i < 730; i++) {
        final prev = addCalendarDays(day, -1);
        expect(prev.hour, 0, reason: '$day');
        expect(addCalendarDays(prev, 1), day, reason: '$day');
        expect(formatDateIso(prev) == formatDateIso(day), isFalse);
        day = addCalendarDays(day, 1);
      }
      expect(day, DateTime(2027, 1, 1));
    });
  });

  group('dateRangeExclusiveEnd', () {
    test('обычный месяц', () {
      expect(
        dateRangeExclusiveEnd(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        ('2026-09-01', '2026-10-01'),
      );
    });

    test('31-е число и конец года', () {
      expect(
        dateRangeExclusiveEnd(DateTime(2026, 12, 1), DateTime(2026, 12, 31)),
        ('2026-12-01', '2027-01-01'),
      );
    });

    test('високосный февраль', () {
      final end = DateTime(2028, 3, 0); // 29.02.2028
      expect(end.day, 29);
      expect(dateRangeExclusiveEnd(DateTime(2028, 2, 1), end), (
        '2028-02-01',
        '2028-03-01',
      ));
    });

    test('конец включается даже если в нём есть время', () {
      expect(
        dateRangeExclusiveEnd(
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 30, 18, 0),
        ).$2,
        '2026-10-01',
      );
    });
  });
}
