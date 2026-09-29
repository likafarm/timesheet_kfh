// lib/services/excel_export.dart
//
// Выгрузка в Excel (этап 6.4): табель и отчёт по зарплате за месяц. Числа —
// настоящими числами (стандарт п. 1.4): дни табеля — 1 или 0,5, а вид «1б»,
// «0,5п», как в печати, задаёт числовой формат ячейки; суммы — числами с
// денежным форматом; итоги и остатки — формулами с готовым значением.

import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import 'xlsx.dart';

const _money = '#,##0.00\\ "₽"';
const _days = '0.0';
const _green = 0xFFE8F5E9, _blue = 0xFFE3F2FD, _purple = 0xFFF3E5F5;
const _gray = 0xFFEEEEEE, _pink = 0xFFFFEBEE, _red = 0xFFC62828;
const _headerFill = 0xFFF5F5F5;

const _title = XlsxStyle(bold: true, fontSize: 14);
const _note = XlsxStyle(color: 0xFF616161);
const _head = XlsxStyle(
  bold: true,
  fill: _headerFill,
  border: true,
  align: 'center',
  wrap: true,
);
const _cell = XlsxStyle(border: true);
const _total = XlsxStyle(bold: true, border: true, fill: _headerFill);

String _monthTitle(DateTime month) {
  final raw = DateFormat('LLLL yyyy', 'ru').format(month);
  return raw.substring(0, 1).toUpperCase() + raw.substring(1);
}

String _company(CompanySettings? s) {
  final name = s?.companyName.trim() ?? '';
  return name.isEmpty ? 'КФХ' : name;
}

String _stamp() =>
    'Выгружено ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}';

/// Имя файла: «Табель_2026-09.xlsx».
String excelFileName(String what, DateTime month) =>
    '${what}_${month.year}-${month.month.toString().padLeft(2, '0')}.xlsx';

/// Табель за месяц: сотрудники × дни, итоги по видам дней.
XlsxWorkbook timesheetWorkbook({
  required DateTime month,
  required List<Employee> employees,
  required List<TimesheetRecord> records,
  CompanySettings? companySettings,
}) {
  final title = 'Табель учёта рабочего времени — ${_monthTitle(month)}';
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('Табель ${_monthTitle(month)}')..landscape = true;
  final days = DateTime(month.year, month.month + 1, 0).day;
  const firstDay = 3; // столбец D
  final lastDay = firstDay + days - 1;
  final totals = [
    'Отработано, дн.',
    'из них база',
    'из них поле',
    'Больничный',
    'Отпуск',
    'Выходные',
  ];
  final lastColumn = lastDay + totals.length;

  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:${xlsxRef(lastColumn, 0)}');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:${xlsxRef(lastColumn, 1)}');
  sheet.addRow([]);

  const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  bool weekend(int d) => DateTime(month.year, month.month, d).weekday >= 6;
  XlsxStyle dayHead(int d) =>
      weekend(d) ? _head.copyWith(fill: _pink, color: _red) : _head;
  sheet.addRow([
    XlsxCell.text('№', _head),
    XlsxCell.text('ФИО', _head),
    XlsxCell.text('Должность', _head),
    for (var d = 1; d <= days; d++) XlsxCell.number(d, dayHead(d)),
    for (final t in totals) XlsxCell.text(t, _head),
  ]);
  sheet.addRow([
    const XlsxCell.empty(_head),
    const XlsxCell.empty(_head),
    const XlsxCell.empty(_head),
    for (var d = 1; d <= days; d++)
      XlsxCell.text(
        weekdays[DateTime(month.year, month.month, d).weekday - 1],
        dayHead(d),
      ),
    for (final _ in totals) const XlsxCell.empty(_head),
  ]);
  // Шапка — две строки: номер дня и день недели; итоги и ФИО — на обе.
  for (final c in [
    0,
    1,
    2,
    for (var i = 0; i < totals.length; i++) lastDay + 1 + i,
  ]) {
    sheet.merges.add('${xlsxRef(c, 3)}:${xlsxRef(c, 4)}');
  }

  final byEmployeeDay = <(String, int), TimesheetRecord>{
    for (final r in records)
      if (r.date.year == month.year && r.date.month == month.month)
        (r.employeeId, r.date.day): r,
  };
  final center = _cell.copyWith(align: 'center');
  final firstRow = sheet.rows.length; // индекс первой строки сотрудников
  for (final (i, e) in employees.indexed) {
    var work = 0.0, base = 0.0, field = 0.0, sick = 0.0, vacation = 0.0;
    var dayoff = 0.0;
    final cells = <XlsxCell>[];
    for (var d = 1; d <= days; d++) {
      final r = byEmployeeDay[(e.id, d)];
      switch (r?.dayType) {
        case 'work' when r!.days > 0:
          work += r.days;
          if (r.workPlace == 'base') base += r.days;
          if (r.workPlace == 'field') field += r.days;
          cells.add(
            XlsxCell.number(
              r.days,
              center.copyWith(
                fill: _green,
                numFmt: switch (r.workPlace) {
                  'base' => 'General"б"',
                  'field' => 'General"п"',
                  _ => null,
                },
              ),
            ),
          );
        case 'sick':
          sick += r!.days;
          cells.add(XlsxCell.text('Б', center.copyWith(fill: _blue)));
        case 'vacation':
          vacation += r!.days;
          cells.add(XlsxCell.text('О', center.copyWith(fill: _purple)));
        case 'dayoff':
          dayoff += r!.days;
          cells.add(XlsxCell.text('В', center.copyWith(fill: _gray)));
        default:
          cells.add(
            XlsxCell.empty(weekend(d) ? _cell.copyWith(fill: _pink) : _cell),
          );
      }
    }
    final row = firstRow + i;
    final dayRange = '${xlsxRef(firstDay, row)}:${xlsxRef(lastDay, row)}';
    final numbers = _cell.copyWith(numFmt: 'General');
    sheet.addRow([
      XlsxCell.number(i + 1, center),
      XlsxCell.text(e.fullName, _cell),
      XlsxCell.text(e.position, _cell),
      ...cells,
      // Все рабочие дни табеля — числа: сумма строки = отработано.
      XlsxCell(
        XlsxFormula('SUM($dayRange)', work),
        numbers.copyWith(bold: true),
      ),
      XlsxCell.number(base, numbers),
      XlsxCell.number(field, numbers),
      XlsxCell.number(sick, numbers),
      XlsxCell.number(vacation, numbers),
      XlsxCell.number(dayoff, numbers),
    ]);
  }

  if (employees.isNotEmpty) {
    final last = sheet.rows.length - 1;
    sheet.addRow([
      const XlsxCell.empty(_total),
      XlsxCell.text('Итого', _total),
      const XlsxCell.empty(_total),
      for (var d = firstDay; d <= lastDay; d++) const XlsxCell.empty(_total),
      for (var t = 0; t < totals.length; t++)
        XlsxCell(
          XlsxFormula(
            'SUM(${xlsxRef(lastDay + 1 + t, firstRow)}:${xlsxRef(lastDay + 1 + t, last)})',
            _columnSum(sheet, lastDay + 1 + t, firstRow, last),
          ),
          _total.copyWith(numFmt: 'General'),
        ),
    ]);
  }

  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      'Обозначения: 1б / 0,5б — база, 1п / 0,5п — поле (в ячейке число дней), '
      'Б — больничный, О — отпуск, В — выходной.',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);

  sheet.columnWidths[0] = 4;
  sheet.columnWidths[1] = 30;
  sheet.columnWidths[2] = 16;
  for (var d = firstDay; d <= lastDay; d++) {
    sheet.columnWidths[d] = 5;
  }
  for (var t = 0; t < totals.length; t++) {
    sheet.columnWidths[lastDay + 1 + t] = 13;
  }
  sheet.rowHeights[3] = 32;
  sheet.frozenRows = 5;
  sheet.frozenColumns = 2;
  return book;
}

/// Отчёт по зарплате за месяц — те же строки и суммы, что на экране отчётов.
XlsxWorkbook payrollWorkbook({
  required PayrollMonthReport report,
  required Map<String, Employee> employees,
  required List<Payment> payments,
  CompanySettings? companySettings,
}) {
  final month = DateTime(report.year, report.month);
  final title = 'Отчёт по зарплате — ${_monthTitle(month)}';
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('Зарплата ${_monthTitle(month)}')
    ..landscape = true;
  final headers = [
    '№',
    'Сотрудник',
    'Должность',
    'На начало',
    'Отработано, дн.',
    'из них база',
    'из них поле',
    'Больничный, дн.',
    'Отпуск, дн.',
    'Без ставки, дн.',
    'Начислено',
    'Премия',
    'Выплачено',
    'Остаток',
  ];
  final lastColumn = headers.length - 1;

  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:${xlsxRef(lastColumn, 0)}');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:${xlsxRef(lastColumn, 1)}');
  sheet.addRow([
    XlsxCell.text(
      report.locked
          ? 'Месяц закрыт — зафиксированный расчёт'
                '${report.differs.isEmpty ? '' : '; у ${report.differs.length} сотр. он расходится с текущими данными'}'
          : 'Месяц открыт — расчёт по текущим данным табеля, ставок и выплат',
      _note,
    ),
  ]);
  sheet.merges.add('A3:${xlsxRef(lastColumn, 2)}');
  sheet.addRow([]);
  sheet.addRow([for (final h in headers) XlsxCell.text(h, _head)], height: 45);

  final paid = <String, double>{}, bonus = <String, double>{};
  for (final p in payments) {
    if (p.paymentDate.year != report.year ||
        p.paymentDate.month != report.month) {
      continue;
    }
    paid[p.employeeId] = (paid[p.employeeId] ?? 0) + p.amount;
    if (p.paymentType == 'bonus') {
      bonus[p.employeeId] = (bonus[p.employeeId] ?? 0) + p.amount;
    }
  }

  final money = _cell.copyWith(numFmt: _money);
  final days = _cell.copyWith(numFmt: _days);
  final warn = 0xFFFFF3E0;
  final firstRow = sheet.rows.length;
  for (final (i, r) in report.results.indexed) {
    final e = employees[r.employeeId];
    final row = firstRow + i;
    final starting = report.startingBalances[r.employeeId] ?? 0;
    final b = bonus[r.employeeId] ?? 0, p = paid[r.employeeId] ?? 0;
    final differs = report.differs.contains(r.employeeId);
    XlsxStyle mark(XlsxStyle s) => differs ? s.copyWith(fill: warn) : s;
    String ref(int c) => xlsxRef(c, row);
    sheet.addRow([
      XlsxCell.number(i + 1, mark(_cell.copyWith(align: 'center'))),
      XlsxCell.text(e?.fullName ?? r.employeeId, mark(_cell)),
      XlsxCell.text(e?.position ?? '', mark(_cell)),
      XlsxCell.number(starting, mark(money)),
      XlsxCell(
        XlsxFormula('${ref(5)}+${ref(6)}', r.baseDays + r.fieldDays),
        mark(days),
      ),
      XlsxCell.number(r.baseDays, mark(days)),
      XlsxCell.number(r.fieldDays, mark(days)),
      XlsxCell.number(r.sickDays, mark(days)),
      XlsxCell.number(r.vacationDays, mark(days)),
      XlsxCell.number(r.skippedWorkDays, mark(_cell)),
      XlsxCell.number(r.totalSalary, mark(money)),
      XlsxCell.number(b, mark(money)),
      XlsxCell.number(p, mark(money)),
      // Как на экране: на начало + начислено + премия − выплачено.
      XlsxCell(
        XlsxFormula(
          '${ref(3)}+${ref(10)}+${ref(11)}-${ref(12)}',
          starting + r.totalSalary + b - p,
        ),
        mark(money.copyWith(bold: true)),
      ),
    ]);
  }

  if (report.results.isNotEmpty) {
    final last = sheet.rows.length - 1;
    XlsxCell sum(int c, String? fmt) => XlsxCell(
      XlsxFormula(
        'SUM(${xlsxRef(c, firstRow)}:${xlsxRef(c, last)})',
        _columnSum(sheet, c, firstRow, last),
      ),
      _total.copyWith(numFmt: fmt),
    );
    sheet.addRow([
      const XlsxCell.empty(_total),
      XlsxCell.text('Итого', _total),
      const XlsxCell.empty(_total),
      sum(3, _money),
      for (var c = 4; c <= 8; c++) sum(c, _days),
      sum(9, null),
      for (var c = 10; c <= 13; c++) sum(c, _money),
    ]);
  } else {
    sheet.addRow([
      XlsxCell.text('В месяце нет начислений, выплат и остатков.', _note),
    ]);
  }
  sheet.addRow([]);
  if (report.differs.isNotEmpty) {
    sheet.addRow([
      XlsxCell.text(
        'Строки с цветным фоном: зафиксированный расчёт расходится с '
        'текущими данными.',
        _note,
      ),
    ]);
  }
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);

  const widths = [
    4.0, 32.0, 16.0, 14.0, 13.0, 11.0, 11.0, 13.0, 11.0, 11.0, 14.0, 12.0, //
    14.0, 14.0,
  ];
  for (final (i, w) in widths.indexed) {
    sheet.columnWidths[i] = w;
  }
  sheet.frozenRows = 5;
  sheet.frozenColumns = 2;
  return book;
}

/// Сумма чисел столбца [c] в строках [from]..[to] — готовое значение для
/// формулы итога.
num _columnSum(XlsxSheet sheet, int c, int from, int to) {
  num total = 0;
  for (var r = from; r <= to; r++) {
    final row = sheet.rows[r];
    if (c >= row.length) continue;
    switch (row[c].value) {
      case XlsxNumber(:final value):
        total += value;
      case XlsxFormula(:final cached):
        total += cached;
      default:
    }
  }
  return total;
}
