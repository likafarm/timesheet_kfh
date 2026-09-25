import 'package:test/test.dart';
import 'package:kfh_domain/kfh_domain.dart';

const _emp = 1;

EmployeeRate rate(
  double base,
  double field,
  DateTime start, [
  DateTime? end,
]) => EmployeeRate(
  employeeId: _emp,
  baseRate: base,
  fieldRate: field,
  startDate: start,
  endDate: end,
);

TimesheetRecord work(DateTime date, String place, [double days = 1.0]) =>
    TimesheetRecord(
      employeeId: _emp,
      date: date,
      dayType: 'work',
      days: days,
      workPlace: place,
    );

TimesheetRecord other(DateTime date, String type, [double days = 1.0]) =>
    TimesheetRecord(employeeId: _emp, date: date, dayType: type, days: days);

PayrollCalculation calc(
  List<TimesheetRecord> records,
  List<EmployeeRate> rates, {
  int year = 2026,
  int month = 9,
}) => calculateMonthlySalary(
  employeeId: _emp,
  year: year,
  month: month,
  records: records,
  rates: rates,
);

void main() {
  final rates = [rate(1000, 1500, DateTime(2026, 1, 1))];

  group('calculateMonthlySalary', () {
    test('пустой месяц — нули', () {
      final r = calc([], rates);
      expect(r.totalSalary, 0);
      expect(r.baseDays, 0);
      expect(r.fieldDays, 0);
      expect(r.skippedWorkDays, 0);
      expect(r.baseRateUsed, isNull);
    });

    test('полные дни на базе и в поле', () {
      final r = calc([
        work(DateTime(2026, 9, 1), 'base'),
        work(DateTime(2026, 9, 2), 'base'),
        work(DateTime(2026, 9, 3), 'field'),
      ], rates);
      expect(r.baseDays, 2);
      expect(r.fieldDays, 1);
      expect(r.totalSalary, 2 * 1000 + 1500);
      expect(r.baseRateUsed, 1000);
      expect(r.fieldRateUsed, 1500);
    });

    test('половина дня', () {
      final r = calc([
        work(DateTime(2026, 9, 1), 'base', 0.5),
        work(DateTime(2026, 9, 2), 'field', 0.5),
      ], rates);
      expect(r.baseDays, 0.5);
      expect(r.fieldDays, 0.5);
      expect(r.totalSalary, 500 + 750);
    });

    test('смена ставки внутри месяца', () {
      final history = [
        rate(1000, 1500, DateTime(2026, 1, 1), DateTime(2026, 9, 14)),
        rate(1200, 1800, DateTime(2026, 9, 15)),
      ];
      final r = calc([
        work(DateTime(2026, 9, 14), 'base'),
        work(DateTime(2026, 9, 15), 'base'),
        work(DateTime(2026, 9, 16), 'field'),
      ], history);
      expect(r.totalSalary, 1000 + 1200 + 1800);
      expect(r.baseRateUsed, 1200);
    });

    test('смена ставки на границе месяца', () {
      final history = [
        rate(1000, 1500, DateTime(2026, 1, 1), DateTime(2026, 8, 31)),
        rate(1200, 1800, DateTime(2026, 9, 1)),
      ];
      final aug = calc([work(DateTime(2026, 8, 31), 'base')], history,
          month: 8);
      final sep = calc([work(DateTime(2026, 9, 1), 'base')], history);
      expect(aug.totalSalary, 1000);
      expect(sep.totalSalary, 1200);
    });

    test('дни без ставки пропускаются и считаются', () {
      final history = [rate(1000, 1500, DateTime(2026, 9, 10))];
      final r = calc([
        work(DateTime(2026, 9, 5), 'base'),
        work(DateTime(2026, 9, 9), 'field'),
        work(DateTime(2026, 9, 10), 'base'),
      ], history);
      expect(r.skippedWorkDays, 2);
      expect(r.baseDays, 1);
      expect(r.fieldDays, 0);
      expect(r.totalSalary, 1000);
    });

    test('сотрудник без ставок — ничего не начислено', () {
      final r = calc([work(DateTime(2026, 9, 1), 'base')], []);
      expect(r.skippedWorkDays, 1);
      expect(r.totalSalary, 0);
    });

    test('больничный, отпуск и выходной не оплачиваются', () {
      final r = calc([
        other(DateTime(2026, 9, 1), 'sick'),
        other(DateTime(2026, 9, 2), 'sick'),
        other(DateTime(2026, 9, 3), 'vacation'),
        other(DateTime(2026, 9, 4), 'dayoff'),
      ], rates);
      expect(r.sickDays, 2);
      expect(r.vacationDays, 1);
      expect(r.totalSalary, 0);
      expect(r.skippedWorkDays, 0);
    });

    test('записи другого месяца игнорируются', () {
      final r = calc([
        work(DateTime(2026, 8, 31), 'base'),
        work(DateTime(2026, 9, 30), 'base'),
        work(DateTime(2026, 10, 1), 'base'),
      ], rates);
      expect(r.baseDays, 1);
      expect(r.totalSalary, 1000);
    });

    test('дробные ставки считаются без потерь до копейки', () {
      final r = calc([
        for (var d = 1; d <= 30; d++) work(DateTime(2026, 9, d), 'base'),
      ], [rate(1234.56, 0, DateTime(2026, 1, 1))]);
      expect(r.totalSalary, closeTo(30 * 1234.56, 0.005));
    });

    test('toMap сохраняет прежние ключи', () {
      final m = calc([work(DateTime(2026, 9, 1), 'base')], rates).toMap();
      expect(m.keys, containsAll(<String>[
        'employeeId', 'year', 'month', 'baseDays', 'fieldDays', 'sickDays',
        'vacationDays', 'totalSalary', 'baseRateUsed', 'fieldRateUsed',
        'skippedWorkDays',
      ]));
    });
  });

  group('findRateAtDate', () {
    test('включает дату начала и дату окончания', () {
      final r = rate(1, 1, DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(findRateAtDate([r], DateTime(2026, 9, 1)), r);
      expect(findRateAtDate([r], DateTime(2026, 9, 30)), r);
      expect(findRateAtDate([r], DateTime(2026, 8, 31)), isNull);
      expect(findRateAtDate([r], DateTime(2026, 10, 1)), isNull);
    });

    test('время суток в дате не мешает', () {
      final r = rate(1, 1, DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(findRateAtDate([r], DateTime(2026, 9, 30, 23, 59)), r);
    });

    test('при пересечении берётся более поздняя ставка', () {
      final old = rate(1, 1, DateTime(2026, 1, 1));
      final newer = rate(2, 2, DateTime(2026, 6, 1));
      expect(findRateAtDate([newer, old], DateTime(2026, 7, 1)), newer);
      expect(findRateAtDate([newer, old], DateTime(2026, 5, 1)), old);
    });
  });

  group('combineBalances', () {
    test('начислено минус выплачено, в т.ч. отрицательный остаток', () {
      final b = combineBalances(
        accrued: {1: 10000, 2: 5000},
        paid: {1: 4000, 2: 7000, 3: 1000},
      );
      expect(b, {1: 6000, 2: -2000, 3: -1000});
    });
  });
}
