import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/utils/date_utils.dart';

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
      expect(
        dateRangeExclusiveEnd(DateTime(2028, 2, 1), end),
        ('2028-02-01', '2028-03-01'),
      );
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
