import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfx_time_tracking/services/excel_export.dart';
import 'package:kfx_time_tracking/services/xlsx.dart';

/// Выгрузка в Excel (6.4): числа — числами, итоги — формулами, вид дней
/// табеля — числовым форматом. Проверка открытия файла сторонней
/// программой — `KFH_XLSX_OUT=<папка>`: файлы кладутся туда.
void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  final sept = DateTime(2026, 9);
  final ivan = Employee(
    id: 'e1',
    fullName: 'Иванов Иван',
    position: 'Механизатор',
    hireDate: DateTime(2025, 1, 1),
    baseRate: 0,
    fieldRate: 0,
  );
  final olga = Employee(
    id: 'e2',
    fullName: 'Ольгина <Ольга> & Ко',
    position: 'Техничка',
    hireDate: DateTime(2025, 1, 1),
    baseRate: 0,
    fieldRate: 0,
  );

  TimesheetRecord day(
    String e,
    int d,
    String type, {
    double days = 1,
    String? place,
  }) => TimesheetRecord(
    id: '$e-$d',
    employeeId: e,
    date: DateTime(2026, 9, d),
    dayType: type,
    days: days,
    workPlace: place,
  );

  /// Ячейки листа: адрес → (атрибуты, значение, формула).
  Map<String, ({String? type, String? v, String? f, int s})> cells(
    List<int> bytes, [
    int sheet = 1,
  ]) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(
      zip.findFile('xl/worksheets/sheet$sheet.xml')!.content as List<int>,
    );
    final result = <String, ({String? type, String? v, String? f, int s})>{};
    for (final m in RegExp(
      r'<c r="([A-Z]+\d+)"([^>]*?)(?:/>|>(.*?)</c>)',
    ).allMatches(xml)) {
      final attrs = m[2]!;
      final body = m[3] ?? '';
      result[m[1]!] = (
        type: RegExp(r't="(\w+)"').firstMatch(attrs)?[1],
        v:
            RegExp(r'<v>(.*?)</v>').firstMatch(body)?[1] ??
            RegExp(r'<t[^>]*>(.*?)</t>').firstMatch(body)?[1],
        f: RegExp(r'<f>(.*?)</f>').firstMatch(body)?[1],
        s: int.parse(RegExp(r's="(\d+)"').firstMatch(attrs)?[1] ?? '0'),
      );
    }
    return result;
  }

  String styles(List<int> bytes) => utf8.decode(
    ZipDecoder().decodeBytes(bytes).findFile('xl/styles.xml')!.content
        as List<int>,
  );

  void save(String name, List<int> bytes) {
    final out = Platform.environment['KFH_XLSX_OUT'];
    if (out != null) File('$out/$name').writeAsBytesSync(bytes);
  }

  test('имена столбцов и адреса', () {
    expect(xlsxColumn(0), 'A');
    expect(xlsxColumn(25), 'Z');
    expect(xlsxColumn(26), 'AA');
    expect(xlsxColumn(33), 'AH');
    expect(xlsxRef(3, 5), 'D6');
    expect(excelFileName('Табель', sept), 'Табель_2026-09.xlsx');
  });

  test('табель: дни — числа с видом «1б/0,5п», итоги — формулами', () {
    final bytes = timesheetWorkbook(
      month: sept,
      employees: [ivan, olga],
      records: [
        day('e1', 1, 'work', place: 'base'),
        day('e1', 2, 'work', days: 0.5, place: 'field'),
        day('e1', 3, 'sick'),
        day('e1', 4, 'vacation'),
        day('e1', 5, 'dayoff'),
        day('e2', 1, 'work', place: 'field'),
        // Другой месяц — не в табель.
        TimesheetRecord(
          employeeId: 'e1',
          date: DateTime(2026, 10, 1),
          dayType: 'work',
          days: 1,
          workPlace: 'base',
        ),
      ],
    ).encode();
    save('timesheet.xlsx', bytes);
    final c = cells(bytes);
    // Строка 6 — первый сотрудник; D — 1-е число.
    expect(c['B6']!.v, 'Иванов Иван');
    expect((c['D6']!.type, c['D6']!.v), (null, '1'), reason: 'число');
    expect((c['E6']!.type, c['E6']!.v), (null, '0.5'));
    expect((c['F6']!.type, c['F6']!.v), ('inlineStr', 'Б'));
    expect(c['G6']!.v, 'О');
    expect(c['H6']!.v, 'В');
    // Сентябрь — 30 дней: D..AG; итоги с AH.
    expect(c['AH6']!.f, 'SUM(D6:AG6)');
    expect(c['AH6']!.v, '1.5');
    expect((c['AI6']!.v, c['AJ6']!.v, c['AK6']!.v), ('1', '0.5', '1'));
    expect(c['B7']!.v, 'Ольгина &lt;Ольга&gt; &amp; Ко', reason: 'XML');
    expect(c['B8']!.v, 'Итого');
    expect(c['AH8']!.f, 'SUM(AH6:AH7)');
    expect(c['AH8']!.v, '2.5');
    final st = styles(bytes);
    expect(st, contains('formatCode="General&quot;б&quot;"'));
    expect(st, contains('formatCode="General&quot;п&quot;"'));
    expect(c['D6']!.s, isNot(c['E6']!.s), reason: 'база и поле — разный вид');
  });

  test('отчёт по зарплате: суммы — числами, остаток и итоги — формулами', () {
    final report = PayrollMonthReport(
      year: 2026,
      month: 9,
      locked: true,
      differs: {'e2'},
      startingBalances: {'e1': 1000, 'e2': -200},
      results: [
        PayrollResult(
          employeeId: 'e1',
          year: 2026,
          month: 9,
          baseDays: 1.5,
          fieldDays: 2.5,
          sickDays: 1,
          vacationDays: 0,
          totalSalary: 5650,
          skippedWorkDays: 1,
        ),
        PayrollResult(
          employeeId: 'e2',
          year: 2026,
          month: 9,
          baseDays: 0,
          fieldDays: 0,
          sickDays: 0,
          vacationDays: 0,
          totalSalary: 0,
        ),
      ],
    );
    final bytes = payrollWorkbook(
      report: report,
      employees: {'e1': ivan, 'e2': olga},
      payments: [
        Payment(
          employeeId: 'e1',
          paymentDate: DateTime(2026, 9, 5),
          amount: 1000,
        ),
        Payment(
          employeeId: 'e1',
          paymentDate: DateTime(2026, 9, 20),
          amount: 500,
          paymentType: 'bonus',
        ),
        // Другой месяц — не в отчёт.
        Payment(
          employeeId: 'e1',
          paymentDate: DateTime(2026, 10, 1),
          amount: 9,
        ),
      ],
    ).encode();
    save('payroll.xlsx', bytes);
    final c = cells(bytes);
    expect(c['A3']!.v, contains('Месяц закрыт'));
    expect(c['A3']!.v, contains('у 1 сотр.'));
    // Строка 6 — Иванов.
    expect((c['D6']!.type, c['D6']!.v), (null, '1000'));
    expect(c['E6']!.f, 'F6+G6');
    expect(c['E6']!.v, '4');
    expect(c['K6']!.v, '5650');
    expect((c['L6']!.v, c['M6']!.v), ('500', '1500'));
    expect(c['N6']!.f, 'D6+K6+L6-M6');
    expect(c['N6']!.v, '5650');
    expect(c['N7']!.v, '-200');
    expect(c['B8']!.v, 'Итого');
    expect(c['K8']!.f, 'SUM(K6:K7)');
    expect(c['N8']!.v, '5450');
    expect(styles(bytes), contains('formatCode="#,##0.00\\ &quot;₽&quot;"'));
    // Разошедшийся расчёт — другой фон.
    expect(c['B7']!.s, isNot(c['B6']!.s));
  });

  test('пустой отчёт и пустой табель собираются', () {
    final empty = payrollWorkbook(
      report: const PayrollMonthReport(
        year: 2026,
        month: 10,
        locked: false,
        results: [],
        startingBalances: {},
      ),
      employees: const {},
      payments: const [],
    ).encode();
    expect(cells(empty)['A6']!.v, contains('нет начислений'));
    expect(
      () => timesheetWorkbook(month: sept, employees: [], records: []).encode(),
      returnsNormally,
    );
  });
}
