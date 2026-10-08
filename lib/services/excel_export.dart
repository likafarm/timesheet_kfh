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
  // Нерабочий день — по производственному календарю РФ (6.6).
  bool weekend(int d) =>
      !ProductionCalendar.isWorkingDay(DateTime(month.year, month.month, d));
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

/// Строка списка операций для [financeWorkbook] — те же подписи, что на
/// экране «Финансы».
class FinanceExportRow {
  final DateTime date;
  final String type;
  final int amount; // копейки, всегда больше нуля
  final String account;
  final String what;
  final String direction;
  final String counterparty;
  final String description;

  /// Расход ЗП из выплаты табеля (только чтение).
  final bool payroll;

  const FinanceExportRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.account,
    required this.what,
    required this.direction,
    required this.counterparty,
    required this.description,
    this.payroll = false,
  });
}

/// Число дня для Excel (дни от 30.12.1899) — дата остаётся датой.
int _excelDay(DateTime d) => DateTime.utc(
  d.year,
  d.month,
  d.day,
).difference(DateTime.utc(1899, 12, 30)).inDays;

/// Список операций «Финансов» по отбору (8.7): строки — как на экране,
/// итоги — как над списком (доходы и расходы — формулами по столбцу «Вид»).
/// [period] — «Октябрь 2026»; [filters] — строки «Кошелёк: СБЕР»;
/// [balance] — остаток выбранного кошелька: подпись и копейки.
XlsxWorkbook financeWorkbook({
  required String period,
  required List<String> filters,
  required List<FinanceExportRow> rows,
  required FinanceTotals totals,
  (String, int)? balance,
  CompanySettings? companySettings,
}) {
  final title = 'Финансы — $period';
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('Финансы $period')..landscape = true;
  final headers = [
    '№',
    'Дата',
    'Вид',
    'Сумма',
    'Кошелёк',
    'Статья / куда',
    'Направление',
    'Контрагент',
    'Что',
  ];
  final lastColumn = headers.length - 1;
  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:${xlsxRef(lastColumn, 0)}');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:${xlsxRef(lastColumn, 1)}');
  sheet.addRow([
    XlsxCell.text(
      filters.isEmpty ? 'Отбор: все операции' : 'Отбор: ${filters.join('; ')}',
      _note,
    ),
  ]);
  sheet.merges.add('A3:${xlsxRef(lastColumn, 2)}');
  sheet.addRow([]);
  sheet.addRow([for (final h in headers) XlsxCell.text(h, _head)], height: 30);

  final money = _cell.copyWith(numFmt: _money);
  final date = _cell.copyWith(numFmt: 'dd.mm.yyyy', align: 'center');
  const payrollColor = 0xFF616161;
  final firstRow = sheet.rows.length;
  for (final (i, r) in rows.indexed) {
    XlsxStyle mark(XlsxStyle s) =>
        r.payroll ? s.copyWith(color: payrollColor) : s;
    sheet.addRow([
      XlsxCell.number(i + 1, mark(_cell.copyWith(align: 'center'))),
      XlsxCell.number(_excelDay(r.date), mark(date)),
      XlsxCell.text(r.type, mark(_cell)),
      XlsxCell.number(r.amount / 100, mark(money)),
      XlsxCell.text(r.account, mark(_cell)),
      XlsxCell.text(r.what, mark(_cell)),
      XlsxCell.text(r.direction, mark(_cell)),
      XlsxCell.text(r.counterparty, mark(_cell)),
      XlsxCell.text(
        [
          if (r.description.isNotEmpty) r.description,
          if (r.payroll) 'из табеля',
        ].join(' · '),
        mark(_cell),
      ),
    ]);
  }
  if (rows.isEmpty) {
    sheet.addRow([XlsxCell.text('Нет операций по отбору.', _note)]);
  }
  sheet.addRow([]);

  // Итоги — как над списком на экране.
  final last = firstRow + rows.length - 1;
  final typeRange = '${xlsxRef(2, firstRow)}:${xlsxRef(2, last)}';
  final sumRange = '${xlsxRef(3, firstRow)}:${xlsxRef(3, last)}';
  XlsxCell sumIf(String type, int cached) => XlsxCell(
    rows.isEmpty
        ? XlsxNumber(0)
        : XlsxFormula('SUMIF($typeRange,"$type",$sumRange)', cached / 100),
    _total.copyWith(numFmt: _money),
  );
  const label = _total;
  final incomeRow = sheet.rows.length;
  sheet.addRow([
    const XlsxCell.empty(),
    XlsxCell.text('Доходы', label),
    const XlsxCell.empty(label),
    sumIf(OperationType.income.title, totals.income + totals.refunds),
  ]);
  sheet.addRow([
    const XlsxCell.empty(),
    XlsxCell.text('Расходы', label),
    const XlsxCell.empty(label),
    sumIf(OperationType.expense.title, totals.expense + totals.capex),
  ]);
  void plain(String text, int kopecks) => sheet.addRow([
    const XlsxCell.empty(),
    XlsxCell.text(text, label),
    const XlsxCell.empty(label),
    XlsxCell.number(kopecks / 100, _total.copyWith(numFmt: _money)),
  ]);
  if (totals.capex != 0) plain('в т. ч. капвложения', totals.capex);
  sheet.addRow([
    const XlsxCell.empty(),
    XlsxCell.text('Итог', label),
    const XlsxCell.empty(label),
    XlsxCell(
      XlsxFormula(
        '${xlsxRef(3, incomeRow)}-${xlsxRef(3, incomeRow + 1)}',
        totals.result / 100,
      ),
      _total.copyWith(numFmt: _money),
    ),
  ]);
  if (totals.transfers != 0) plain('Переводы', totals.transfers);
  if (totals.debtIn != 0 || totals.debtOut != 0) {
    plain('Займы: пришло', totals.debtIn);
    plain('Займы: ушло', totals.debtOut);
  }
  if (balance != null) plain(balance.$1, balance.$2);
  for (var r = incomeRow; r < sheet.rows.length; r++) {
    sheet.merges.add('${xlsxRef(1, r)}:${xlsxRef(2, r)}');
  }
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      'Серым — выплаты зарплаты из табеля (правятся в «Выплатах»).',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);

  const widths = [5.0, 11.0, 10.0, 15.0, 16.0, 30.0, 22.0, 24.0, 40.0];
  for (final (i, w) in widths.indexed) {
    sheet.columnWidths[i] = w;
  }
  sheet.frozenRows = 5;
  return book;
}

/// Отчёт «статьи / направления × месяцы» (вторая очередь этапа 8): строки
/// — как на экране, суммы — числами; итоги групп, разделов, «Итого» и
/// результат — формулами.
XlsxWorkbook cashFlowWorkbook({
  required CashFlowReport report,
  required String title,
  required String sheetName,
  CompanySettings? companySettings,
}) {
  final bySeason = report.period == CashFlowPeriod.season;
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet(sheetName)..landscape = true;
  final n = report.columns.length;
  final totalCol = n + 1;
  final byCategory = report.by == CashFlowBy.category;
  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:${xlsxRef(totalCol, 0)}');
  sheet.addRow([
    XlsxCell.text(
      '${_company(companySettings)} · ${report.by.title.toLowerCase()}',
      _note,
    ),
  ]);
  sheet.merges.add('A2:${xlsxRef(totalCol, 1)}');
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(byCategory ? 'Статья' : 'Направление', _head),
    for (final m in report.columns)
      XlsxCell.text(bySeason ? 'Сезон ${m.year}' : _monthTitle(m), _head),
    XlsxCell.text('Итого', _head),
  ], height: 30);

  final money = _cell.copyWith(numFmt: _money);
  final groupLabel = _cell.copyWith(bold: true, fill: _gray);
  final groupMoney = groupLabel.copyWith(numFmt: _money);
  final totalMoney = _total.copyWith(numFmt: _money);
  final noteLabel = _note.copyWith(border: true);
  final noteMoney = noteLabel.copyWith(numFmt: _money);

  int sum(List<int> months) => months.fold(0, (a, b) => a + b);

  /// Суммы строки: числами, «Итого» — формулой по месяцам.
  void values(List<int> months, XlsxStyle style, List<XlsxCell> row) {
    final r = sheet.rows.length;
    row.addAll([
      for (final k in months)
        k == 0 ? XlsxCell.empty(style) : XlsxCell.number(k / 100, style),
      XlsxCell(
        XlsxFormula(
          'SUM(${xlsxRef(1, r)}:${xlsxRef(n, r)})',
          sum(months) / 100,
        ),
        style,
      ),
    ]);
  }

  /// Строка-формула по столбцам: [expression] из ссылки столбца.
  void formulas(
    String name,
    List<int> months,
    XlsxStyle label,
    XlsxStyle style,
    String Function(int column) expression,
  ) => sheet.addRow([
    XlsxCell.text(name, label),
    for (var c = 1; c <= n; c++)
      XlsxCell(XlsxFormula(expression(c), months[c - 1] / 100), style),
    XlsxCell(XlsxFormula(expression(totalCol), sum(months) / 100), style),
  ]);

  String range(int column, int from, int to) =>
      from > to ? '0' : 'SUM(${xlsxRef(column, from)}:${xlsxRef(column, to)})';

  /// Раздел; возвращает строку его итога.
  int section(CashFlowSection s, String name, String special) {
    sheet.addRow([XlsxCell.text(name, _total)]);
    final groupRows = <int>[];
    for (final g in s.groups) {
      if (byCategory) {
        // Группа: итог — формулой по её статьям ниже.
        final r = sheet.rows.length;
        groupRows.add(r);
        formulas(
          g.name,
          g.values,
          groupLabel,
          groupMoney,
          (c) => range(c, r + 1, r + g.lines.length),
        );
      }
      for (final l in g.lines) {
        if (!byCategory) groupRows.add(sheet.rows.length);
        final row = [
          XlsxCell.text(byCategory ? '    ${l.name}' : l.name, _cell),
        ];
        values(l.values, money, row);
        sheet.addRow(row);
      }
    }
    final total = sheet.rows.length;
    formulas(
      'Всего — ${name.toLowerCase()}',
      s.values,
      _total,
      totalMoney,
      (c) => groupRows.isEmpty
          ? '0'
          : groupRows.map((r) => xlsxRef(c, r)).join('+'),
    );
    if (s.specialTotal != 0) {
      final row = [XlsxCell.text(special, noteLabel)];
      values(s.special, noteMoney, row);
      sheet.addRow(row);
    }
    sheet.addRow([]);
    return total;
  }

  final income = section(
    report.income,
    bySeason ? 'Выручка' : 'Доходы',
    'в т. ч. возвраты',
  );
  final expense = section(
    report.expense,
    bySeason ? 'Затраты' : 'Расходы',
    'в т. ч. капвложения',
  );
  formulas(
    bySeason ? 'Итог: выручка − затраты' : 'Итог: доходы − расходы',
    report.result,
    _total,
    totalMoney,
    (c) => '${xlsxRef(c, income)}-${xlsxRef(c, expense)}',
  );
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      bySeason
          ? 'Сезон — урожай, под который потрачены деньги (по умолчанию — год '
                'операции). Расход по ключу входит долей направления; '
                'общехозяйственные расходы не распределяются.'
          : 'Переводы между кошельками и займы — не доходы и не расходы, в '
                'отчёт не входят. Расходы по ключу распределения в отчёте по '
                'направлениям разложены по долям ключа.',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);

  sheet.columnWidths[0] = 34;
  for (var c = 1; c <= totalCol; c++) {
    sheet.columnWidths[c] = 14;
  }
  sheet.frozenRows = 4;
  sheet.frozenColumns = 1;
  return book;
}

/// Управленческий баланс (8Б.2) на две даты: разделы актива и пассива со
/// строками, итоги разделов, актива, пассива и капитал — формулами, как и
/// «Изменение».
XlsxWorkbook managementBalanceWorkbook({
  required ManagementBalance start,
  required ManagementBalance end,
  required String startLabel,
  required String endLabel,
  CompanySettings? companySettings,
}) {
  final title =
      'Управленческий баланс — ${DateFormat('dd.MM.yyyy').format(end.day)}';
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('Баланс');
  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:D1');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:D2');
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text('', _head),
    XlsxCell.text(startLabel, _head),
    XlsxCell.text(endLabel, _head),
    XlsxCell.text('Изменение', _head),
  ], height: 30);

  final money = _cell.copyWith(numFmt: _money);
  final groupLabel = _cell.copyWith(bold: true, fill: _gray);
  final groupMoney = groupLabel.copyWith(numFmt: _money);
  final totalMoney = _total.copyWith(numFmt: _money);

  XlsxCell change(int r, XlsxStyle style, int cached) => XlsxCell(
    XlsxFormula('${xlsxRef(2, r)}-${xlsxRef(1, r)}', cached / 100),
    style,
  );

  /// Сторона баланса; возвращает строку её итога.
  int side(
    String heading,
    String totalName,
    List<BalanceSection> a,
    List<BalanceSection> b,
  ) {
    sheet.addRow([XlsxCell.text(heading, _total)]);
    final sectionRows = <int>[];
    for (var i = 0; i < b.length; i++) {
      final names = {
        for (final l in b[i].lines) l.name,
        for (final l in a[i].lines) l.name,
      }.toList();
      final r = sheet.rows.length;
      sectionRows.add(r);
      String sum(int c) => names.isEmpty
          ? '0'
          : 'SUM(${xlsxRef(c, r + 1)}:${xlsxRef(c, r + names.length)})';
      sheet.addRow([
        XlsxCell.text(b[i].title, groupLabel),
        XlsxCell(XlsxFormula(sum(1), a[i].total / 100), groupMoney),
        XlsxCell(XlsxFormula(sum(2), b[i].total / 100), groupMoney),
        change(r, groupMoney, b[i].total - a[i].total),
      ]);
      for (final name in names) {
        int? amount(BalanceSection s) =>
            s.lines.where((l) => l.name == name).firstOrNull?.amount;
        final x = amount(a[i]), y = amount(b[i]);
        final row = sheet.rows.length;
        sheet.addRow([
          XlsxCell.text('    $name', _cell),
          x == null ? XlsxCell.empty(money) : XlsxCell.number(x / 100, money),
          y == null ? XlsxCell.empty(money) : XlsxCell.number(y / 100, money),
          change(row, money, (y ?? 0) - (x ?? 0)),
        ]);
      }
    }
    final total = sheet.rows.length;
    String plus(int c) => sectionRows.map((r) => xlsxRef(c, r)).join('+');
    final ta = a.fold(0, (s, x) => s + x.total);
    final tb = b.fold(0, (s, x) => s + x.total);
    sheet.addRow([
      XlsxCell.text(totalName, _total),
      XlsxCell(XlsxFormula(plus(1), ta / 100), totalMoney),
      XlsxCell(XlsxFormula(plus(2), tb / 100), totalMoney),
      change(total, totalMoney, tb - ta),
    ]);
    sheet.addRow([]);
    return total;
  }

  final assets = side(
    'Актив — что есть',
    'Итого актив',
    start.assets,
    end.assets,
  );
  final liabilities = side(
    'Пассив — что должны',
    'Итого пассив',
    start.liabilities,
    end.liabilities,
  );
  final r = sheet.rows.length;
  String diff(int c) => '${xlsxRef(c, assets)}-${xlsxRef(c, liabilities)}';
  sheet.addRow([
    XlsxCell.text('Капитал (актив − пассив)', _total),
    XlsxCell(XlsxFormula(diff(1), start.equity / 100), totalMoney),
    XlsxCell(XlsxFormula(diff(2), end.equity / 100), totalMoney),
    change(r, totalMoney, end.equity - start.equity),
  ]);
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      'Имущество — по справочной стоимости, без стада и запасов кормов.',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);
  sheet.columnWidths[0] = 44;
  for (var c = 1; c <= 3; c++) {
    sheet.columnWidths[c] = 18;
  }
  sheet.frozenRows = 4;
  return book;
}

/// ДДС (8Б.3) по месяцам: строки — как на экране, суммы со знаком
/// (приход — плюс); итоги видов деятельности, изменение и остаток на конец
/// — формулами (конец = начало + изменение + прочее).
XlsxWorkbook ddsWorkbook({
  required DdsReport report,
  required String title,
  CompanySettings? companySettings,
}) {
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('ДДС')..landscape = true;
  final n = report.columns.length;
  final yearCol = n + 1;
  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:${xlsxRef(yearCol, 0)}');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:${xlsxRef(yearCol, 1)}');
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text('', _head),
    for (final m in report.columns) XlsxCell.text(_monthTitle(m), _head),
    XlsxCell.text('Год', _head),
  ], height: 30);

  final money = _cell.copyWith(numFmt: _money);
  final groupLabel = _cell.copyWith(bold: true, fill: _gray);
  final groupMoney = groupLabel.copyWith(numFmt: _money);
  final totalMoney = _total.copyWith(numFmt: _money);
  int sum(List<int> v) => v.fold(0, (a, b) => a + b);

  /// Строка чисел; «Год» — формулой суммы месяцев.
  int numbers(String name, List<int> values, XlsxStyle label, XlsxStyle style) {
    final r = sheet.rows.length;
    sheet.addRow([
      XlsxCell.text(name, label),
      for (final v in values)
        v == 0 ? XlsxCell.empty(style) : XlsxCell.number(v / 100, style),
      XlsxCell(
        XlsxFormula(
          'SUM(${xlsxRef(1, r)}:${xlsxRef(n, r)})',
          sum(values) / 100,
        ),
        style,
      ),
    ]);
    return r;
  }

  /// Строка-формула по столбцам.
  int formulas(
    String name,
    List<int> values,
    int yearValue,
    XlsxStyle label,
    XlsxStyle style,
    String Function(int column) expression,
  ) {
    final r = sheet.rows.length;
    sheet.addRow([
      XlsxCell.text(name, label),
      for (var c = 1; c <= n; c++)
        XlsxCell(XlsxFormula(expression(c), values[c - 1] / 100), style),
      XlsxCell(XlsxFormula(expression(yearCol), yearValue / 100), style),
    ]);
    return r;
  }

  String sumRows(int c, List<int> rows) =>
      rows.isEmpty ? '0' : rows.map((r) => xlsxRef(c, r)).join('+');

  /// Раздел по статьям со знаком [sign]; возвращает строку итога.
  int section(CashFlowSection s, String name, int sign) {
    final lines = [for (final g in s.groups) ...g.lines];
    final r = sheet.rows.length;
    formulas(
      name,
      [for (final v in s.values) sign * v],
      sign * s.total,
      groupLabel,
      groupMoney,
      (c) => lines.isEmpty
          ? '0'
          : 'SUM(${xlsxRef(c, r + 1)}:${xlsxRef(c, r + lines.length)})',
    );
    for (final l in lines) {
      numbers(
        '    ${l.name}',
        [for (final v in l.values) sign * v],
        _cell,
        money,
      );
    }
    return r;
  }

  final opening = sheet.rows.length;
  sheet.addRow([
    XlsxCell.text('Деньги на начало месяца', _total),
    for (final v in report.opening) XlsxCell.number(v / 100, totalMoney),
    XlsxCell(
      XlsxFormula(xlsxRef(1, opening), report.opening.first / 100),
      totalMoney,
    ),
  ]);

  sheet.addRow([XlsxCell.text('Операционная деятельность', _total)]);
  final inRow = section(report.operatingIn, 'Поступления', 1);
  final outRow = section(report.operatingOut, 'Платежи', -1);
  final operating = formulas(
    'Итого операционная',
    report.operatingNet,
    sum(report.operatingNet),
    _total,
    totalMoney,
    (c) => sumRows(c, [inRow, outRow]),
  );

  sheet.addRow([XlsxCell.text('Инвестиционная деятельность', _total)]);
  final capexRow = section(report.investingOut, 'Капвложения', -1);
  final investing = formulas(
    'Итого инвестиционная',
    report.investingNet,
    sum(report.investingNet),
    _total,
    totalMoney,
    (c) => sumRows(c, [capexRow]),
  );

  sheet.addRow([XlsxCell.text('Финансовая деятельность (займы)', _total)]);
  final loanRows = [
    for (final l in report.financing)
      numbers('    ${l.name}', l.values, _cell, money),
  ];
  final financing = formulas(
    'Итого финансовая',
    report.financingNet,
    sum(report.financingNet),
    _total,
    totalMoney,
    (c) => sumRows(c, loanRows),
  );
  sheet.addRow([]);
  final other = report.hasOther
      ? numbers(
          'Прочее: начальные остатки новых кошельков',
          report.other,
          _note.copyWith(border: true),
          money,
        )
      : null;
  final change = formulas(
    'Изменение денег за месяц',
    report.netFlow,
    sum(report.netFlow),
    _total,
    totalMoney,
    (c) => sumRows(c, [operating, investing, financing]),
  );
  formulas(
    'Деньги на конец месяца',
    report.closing,
    report.closing.last,
    _total,
    totalMoney,
    (c) => c == yearCol
        ? xlsxRef(n, sheet.rows.length)
        : '${xlsxRef(c, opening)}+${xlsxRef(c, change)}'
              '${other == null ? '' : '+${xlsxRef(c, other)}'}',
  );
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      'Со знаком: приход — плюс, уход — минус. Переводы между кошельками не '
      'входят.',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);
  sheet.columnWidths[0] = 40;
  for (var c = 1; c <= yearCol; c++) {
    sheet.columnWidths[c] = 14;
  }
  sheet.frozenRows = 4;
  sheet.frozenColumns = 1;
  return book;
}

/// БДДС (8Б.5): план, факт, отклонение (факт − план) и исполнение по
/// статьям за месяцы [months] (null — год); итоги групп и разделов,
/// отклонение и исполнение — формулами.
XlsxWorkbook budgetWorkbook({
  required BudgetReport report,
  required List<int>? months,
  required String title,
  CompanySettings? companySettings,
}) {
  final book = XlsxWorkbook(title: title, author: _company(companySettings));
  final sheet = book.addSheet('БДДС');
  sheet.addRow([XlsxCell.text(title, _title)], height: 20);
  sheet.merges.add('A1:E1');
  sheet.addRow([XlsxCell.text(_company(companySettings), _note)]);
  sheet.merges.add('A2:E2');
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text('Статья', _head),
    XlsxCell.text('План', _head),
    XlsxCell.text('Факт', _head),
    XlsxCell.text('Отклонение', _head),
    XlsxCell.text('Исполнение', _head),
  ], height: 30);

  final money = _cell.copyWith(numFmt: _money);
  final percent = _cell.copyWith(numFmt: '0%');
  final groupLabel = _cell.copyWith(bold: true, fill: _gray);
  final groupMoney = groupLabel.copyWith(numFmt: _money);
  final groupPercent = groupLabel.copyWith(numFmt: '0%');
  final totalMoney = _total.copyWith(numFmt: _money);
  final totalPercent = _total.copyWith(numFmt: '0%');

  /// Отклонение и исполнение строки [r] — формулами.
  List<XlsxCell> tail(int r, int plan, int fact, XlsxStyle m, XlsxStyle p) => [
    XlsxCell(
      XlsxFormula('${xlsxRef(2, r)}-${xlsxRef(1, r)}', (fact - plan) / 100),
      m,
    ),
    XlsxCell(
      XlsxFormula(
        'IF(${xlsxRef(1, r)}=0,"",${xlsxRef(2, r)}/${xlsxRef(1, r)})',
        plan == 0 ? 0 : fact / plan,
      ),
      p,
    ),
  ];

  /// Строка-сумма строк [rows] по столбцам плана и факта.
  int sumRow(
    String name,
    List<int> rows,
    int plan,
    int fact,
    XlsxStyle label,
    XlsxStyle m,
    XlsxStyle p,
  ) {
    final r = sheet.rows.length;
    String f(int c) =>
        rows.isEmpty ? '0' : rows.map((x) => xlsxRef(c, x)).join('+');
    sheet.addRow([
      XlsxCell.text(name, label),
      XlsxCell(XlsxFormula(f(1), plan / 100), m),
      XlsxCell(XlsxFormula(f(2), fact / 100), m),
      ...tail(r, plan, fact, m, p),
    ]);
    return r;
  }

  int section(BudgetSection s, String name) {
    final groupRows = <int>[];
    final header = sheet.rows.length;
    sheet.addRow([]); // заголовок раздела — после подсчёта строк
    for (final g in s.groups) {
      final gr = sheet.rows.length;
      groupRows.add(gr);
      final lineRows = [for (var i = 0; i < g.lines.length; i++) gr + 1 + i];
      sumRow(
        g.name,
        lineRows,
        g.planOf(months),
        g.factOf(months),
        groupLabel,
        groupMoney,
        groupPercent,
      );
      for (final l in g.lines) {
        final r = sheet.rows.length;
        final plan = l.planOf(months), fact = l.factOf(months);
        sheet.addRow([
          XlsxCell.text('    ${l.name}', _cell),
          XlsxCell.number(plan / 100, money),
          XlsxCell.number(fact / 100, money),
          ...tail(r, plan, fact, money, percent),
        ]);
      }
    }
    // Заголовок раздела с итогом — на своё место.
    final plan = s.planOf(months), fact = s.factOf(months);
    String f(int c) =>
        groupRows.isEmpty ? '0' : groupRows.map((x) => xlsxRef(c, x)).join('+');
    sheet.rows[header] = [
      XlsxCell.text(name, _total),
      XlsxCell(XlsxFormula(f(1), plan / 100), totalMoney),
      XlsxCell(XlsxFormula(f(2), fact / 100), totalMoney),
      ...tail(header, plan, fact, totalMoney, totalPercent),
    ];
    sheet.addRow([]);
    return header;
  }

  final income = section(report.income, 'Поступления');
  final expense = section(report.expense, 'Платежи');
  final r = sheet.rows.length;
  final plan = report.income.planOf(months) - report.expense.planOf(months);
  final fact = report.income.factOf(months) - report.expense.factOf(months);
  sheet.addRow([
    XlsxCell.text('Итог: поступления − платежи', _total),
    XlsxCell(
      XlsxFormula('${xlsxRef(1, income)}-${xlsxRef(1, expense)}', plan / 100),
      totalMoney,
    ),
    XlsxCell(
      XlsxFormula('${xlsxRef(2, income)}-${xlsxRef(2, expense)}', fact / 100),
      totalMoney,
    ),
    ...tail(r, plan, fact, totalMoney, totalPercent),
  ]);
  sheet.addRow([]);
  sheet.addRow([
    XlsxCell.text(
      'Отклонение — факт минус план. Займы и переводы в бюджет не входят.',
      _note,
    ),
  ]);
  sheet.addRow([XlsxCell.text(_stamp(), _note)]);
  sheet.columnWidths[0] = 40;
  for (var c = 1; c <= 4; c++) {
    sheet.columnWidths[c] = 16;
  }
  sheet.frozenRows = 4;
  return book;
}
