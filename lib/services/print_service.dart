// lib/services/print_service.dart

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:kfh_domain/kfh_domain.dart';
import '../utils/string_utils.dart';

/// Формирование и вывод на печать табеля и детального отчёта по сотруднику.
class PrintService {
  PrintService._();

  static pw.Font? _font;
  static pw.Font? _fontBold;
  static pw.ThemeData? _theme;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static Future<void> _ensureFonts() async {
    if (_theme != null) return;

    pw.Font regular;
    pw.Font bold;
    try {
      regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    } catch (_) {
      throw Exception(
        'Не найдены шрифты печати (assets/fonts/Roboto-Regular.ttf). '
        'Проверьте установку приложения.',
      );
    }

    _font = regular;
    _fontBold = bold;
    _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static String _companyName(CompanySettings? settings) {
    final name = settings?.companyName;
    if (name == null || name.trim().isEmpty) return 'КФХ';
    return name.trim();
  }

  static String? _directorName(CompanySettings? settings) {
    final name = settings?.directorName;
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  static String _monthTitle(DateTime month) {
    final raw = DateFormat('LLLL yyyy', 'ru').format(month);
    return raw.substring(0, 1).toUpperCase() + raw.substring(1);
  }

  static String _cellMark(TimesheetRecord record) {
    if (record.id == null) return '';
    switch (record.dayType) {
      case 'work':
        if (record.days <= 0) return '';
        final daysStr = record.days == 0.5 ? '0.5' : '1';
        if (record.workPlace == 'base') return '$daysStrб';
        if (record.workPlace == 'field') return '$daysStrп';
        return daysStr;
      case 'sick':
        return 'Б';
      case 'vacation':
        return 'О';
      case 'dayoff':
        return 'В';
      default:
        return '';
    }
  }

  static PdfColor? _cellColor(TimesheetRecord record) {
    if (record.id == null) return null;
    switch (record.dayType) {
      case 'work':
        return record.days > 0 ? PdfColor.fromInt(0xFFE8F5E9) : null;
      case 'sick':
        return PdfColor.fromInt(0xFFE3F2FD);
      case 'vacation':
        return PdfColor.fromInt(0xFFF3E5F5);
      case 'dayoff':
        return PdfColor.fromInt(0xFFEEEEEE);
      default:
        return null;
    }
  }

  static TimesheetRecord _recordForDay(
    List<TimesheetRecord> records,
    String employeeId,
    DateTime date,
  ) {
    return records.firstWhere(
      (r) =>
          r.employeeId == employeeId &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
      orElse: () => TimesheetRecord(
        employeeId: employeeId,
        date: date,
        dayType: 'work',
        days: 0,
      ),
    );
  }

  static ({double work, double dayoff, double sick, double vacation}) _totals(
    List<TimesheetRecord> records,
    String employeeId,
  ) {
    var work = 0.0;
    var dayoff = 0.0;
    var sick = 0.0;
    var vacation = 0.0;
    for (final record in records) {
      if (record.employeeId != employeeId) continue;
      switch (record.dayType) {
        case 'work':
          work += record.days;
          break;
        case 'dayoff':
          dayoff += record.days;
          break;
        case 'sick':
          sick += record.days;
          break;
        case 'vacation':
          vacation += record.days;
          break;
      }
    }
    return (work: work, dayoff: dayoff, sick: sick, vacation: vacation);
  }

  static String _fmtDays(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  /// Печать табеля учёта рабочего времени за месяц.
  static Future<void> printTimesheet({
    required DateTime month,
    required List<Employee> employees,
    required List<TimesheetRecord> records,
    CompanySettings? companySettings,
  }) async {
    if (employees.isEmpty) {
      throw StateError('Нет сотрудников для печати табеля');
    }

    await _ensureFonts();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final company = _companyName(companySettings);
    final director = _directorName(companySettings);
    final monthTitle = _monthTitle(month);
    final printedAt = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
        theme: _theme,
        header: (context) => _timesheetHeader(company, monthTitle),
        footer: (context) => _pageFooter(printedAt, context),
        build: (context) => [
          _timesheetTable(employees, records, month, daysInMonth),
          pw.SizedBox(height: 10),
          _timesheetLegend(),
          pw.SizedBox(height: 18),
          _signatureBlock(director),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Табель_$monthTitle',
      format: PdfPageFormat.a4.landscape,
    );
  }

  /// Печать детального отчёта по сотруднику за месяц.
  static Future<void> printEmployeeReport({
    required Employee employee,
    required PayrollResult result,
    required List<Payment> payments,
    required double startingBalance,
    CompanySettings? companySettings,
  }) async {
    await _ensureFonts();
    final company = _companyName(companySettings);
    final director = _directorName(companySettings);
    final monthTitle = _monthTitle(DateTime(result.year, result.month));
    final printedAt = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final currency = NumberFormat('#,##0.00', 'ru');
    final days = NumberFormat('#,##0.0', 'ru');

    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final totalPaid = sortedPayments.fold<double>(0, (s, p) => s + p.amount);
    final bonus = sortedPayments
        .where((p) => p.paymentType == 'bonus')
        .fold<double>(0, (s, p) => s + p.amount);
    final balance = startingBalance + result.totalSalary - totalPaid;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        theme: _theme,
        footer: (context) => _pageFooter(printedAt, context),
        build: (context) => [
          pw.Text(company, style: pw.TextStyle(font: _fontBold, fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Детальный отчёт по сотруднику',
            style: pw.TextStyle(font: _fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            monthTitle,
            style: pw.TextStyle(
              font: _font,
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 14),
          _kv('Сотрудник', employee.fullName),
          _kv('Должность', employee.position),
          pw.SizedBox(height: 16),
          _amountRow(
            'К выплате на начало месяца',
            '${currency.format(startingBalance)} ₽',
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Начисления',
            style: pw.TextStyle(font: _fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 6),
          _simpleTable(
            headers: const ['Вид', 'Дни', 'Ставка', 'Сумма'],
            rows: [
              [
                'Работа на базе',
                days.format(result.baseDays),
                result.baseRateUsed != null
                    ? currency.format(result.baseRateUsed)
                    : '—',
                currency.format(result.baseDays * (result.baseRateUsed ?? 0)),
              ],
              [
                'Работа в поле',
                days.format(result.fieldDays),
                result.fieldRateUsed != null
                    ? currency.format(result.fieldRateUsed)
                    : '—',
                currency.format(result.fieldDays * (result.fieldRateUsed ?? 0)),
              ],
              ['Больничный', days.format(result.sickDays), '—', '—'],
              ['Отпуск', days.format(result.vacationDays), '—', '—'],
            ],
            footer: ['ИТОГО', '', '', currency.format(result.totalSalary)],
            alignRight: const {1, 2, 3},
          ),
          if (bonus > 0) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Премия (в выплатах): ${currency.format(bonus)} ₽',
              style: pw.TextStyle(
                font: _font,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Выплаты',
            style: pw.TextStyle(font: _fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 6),
          if (sortedPayments.isEmpty)
            pw.Text(
              'Выплат за период нет',
              style: pw.TextStyle(
                font: _font,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            )
          else
            _simpleTable(
              headers: const ['Дата', 'Вид', 'Способ', 'Сумма'],
              rows: sortedPayments
                  .map(
                    (p) => [
                      DateFormat('dd.MM.yyyy').format(p.paymentDate),
                      p.paymentTypeName,
                      p.paymentMethodName,
                      currency.format(p.amount),
                    ],
                  )
                  .toList(),
              footer: ['ИТОГО', '', '', currency.format(totalPaid)],
              alignRight: const {3},
            ),
          pw.SizedBox(height: 18),
          _amountRow(
            'К выплате на конец месяца',
            '${currency.format(balance)} ₽',
            emphasize: true,
          ),
          pw.SizedBox(height: 28),
          _signatureBlock(director),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Отчёт_${employee.fullName}_$monthTitle',
    );
  }

  static pw.Widget _timesheetHeader(String company, String monthTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              company,
              style: pw.TextStyle(font: _fontBold, fontSize: 11),
            ),
            pw.Text(
              'Табель учёта рабочего времени',
              style: pw.TextStyle(font: _fontBold, fontSize: 13),
            ),
            pw.Text(
              monthTitle,
              style: pw.TextStyle(font: _fontBold, fontSize: 11),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _pageFooter(String printedAt, pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Сформировано: $printedAt',
            style: pw.TextStyle(
              font: _font,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Стр. ${context.pageNumber} из ${context.pagesCount}',
            style: pw.TextStyle(
              font: _font,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _timesheetTable(
    List<Employee> employees,
    List<TimesheetRecord> records,
    DateTime month,
    int daysInMonth,
  ) {
    final headerStyle = pw.TextStyle(font: _fontBold, fontSize: 7);
    final cellStyle = pw.TextStyle(font: _font, fontSize: 7);
    final nameStyle = pw.TextStyle(font: _fontBold, fontSize: 7.5);
    final posStyle = pw.TextStyle(
      font: _font,
      fontSize: 6,
      color: PdfColors.grey700,
    );

    pw.Widget headerCell(String text, {PdfColor? color, PdfColor? textColor}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 1),
        color: color,
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          style: textColor != null
              ? headerStyle.copyWith(color: textColor)
              : headerStyle,
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    final header = pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(3),
          color: PdfColors.grey200,
          child: pw.Text('ФИО', style: headerStyle),
        ),
        ...List.generate(daysInMonth, (i) {
          final day = i + 1;
          final date = DateTime(month.year, month.month, day);
          final isWeekend =
              date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday;
          return headerCell(
            '$day\n${_weekdays[date.weekday - 1]}',
            color: isWeekend ? PdfColor.fromInt(0xFFFFEBEE) : PdfColors.grey200,
            textColor: isWeekend ? PdfColors.red : null,
          );
        }),
        headerCell('Раб.', color: PdfColors.grey300),
        headerCell('Вых.', color: PdfColors.grey200),
        headerCell('Бол.', color: PdfColor.fromInt(0xFFE3F2FD)),
        headerCell('Отп.', color: PdfColor.fromInt(0xFFF3E5F5)),
      ],
    );

    final rows = employees.map((employee) {
      final totals = _totals(records, employee.id!);
      return pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  StringUtils.getShortName(employee.fullName),
                  style: nameStyle,
                ),
                pw.Text(employee.position, style: posStyle),
              ],
            ),
          ),
          ...List.generate(daysInMonth, (i) {
            final date = DateTime(month.year, month.month, i + 1);
            final record = _recordForDay(records, employee.id!, date);
            final mark = _cellMark(record);
            final bg = _cellColor(record);
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              color: bg,
              alignment: pw.Alignment.center,
              child: pw.Text(mark, style: cellStyle),
            );
          }),
          _totalCell(_fmtDays(totals.work), PdfColors.grey300, headerStyle),
          _totalCell(_fmtDays(totals.dayoff), PdfColors.grey200, cellStyle),
          _totalCell(
            _fmtDays(totals.sick),
            PdfColor.fromInt(0xFFE3F2FD),
            cellStyle,
          ),
          _totalCell(
            _fmtDays(totals.vacation),
            PdfColor.fromInt(0xFFF3E5F5),
            cellStyle,
          ),
        ],
      );
    }).toList();

    final nameWidth = 78.0;
    final totalWidth = 22.0;
    final remaining =
        PdfPageFormat.a4.landscape.width - 48 - nameWidth - totalWidth * 4;
    final dayWidth = remaining / daysInMonth;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FixedColumnWidth(78),
        for (var i = 1; i <= daysInMonth; i++) i: pw.FixedColumnWidth(dayWidth),
        daysInMonth + 1: const pw.FixedColumnWidth(22),
        daysInMonth + 2: const pw.FixedColumnWidth(22),
        daysInMonth + 3: const pw.FixedColumnWidth(22),
        daysInMonth + 4: const pw.FixedColumnWidth(22),
      },
      children: [header, ...rows],
    );
  }

  static pw.Widget _totalCell(String text, PdfColor color, pw.TextStyle style) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      color: color,
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: style),
    );
  }

  static pw.Widget _timesheetLegend() {
    final style = pw.TextStyle(font: _font, fontSize: 8);
    pw.Widget item(String mark, String label, PdfColor color) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 22,
            height: 12,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: color,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
            ),
            child: pw.Text(
              mark,
              style: pw.TextStyle(font: _fontBold, fontSize: 7),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(label, style: style),
          pw.SizedBox(width: 12),
        ],
      );
    }

    return pw.Row(
      children: [
        item('1б', 'база', PdfColor.fromInt(0xFFE8F5E9)),
        item('1п', 'поле', PdfColor.fromInt(0xFFE8F5E9)),
        item('0.5', 'полдня', PdfColor.fromInt(0xFFE8F5E9)),
        item('Б', 'больничный', PdfColor.fromInt(0xFFE3F2FD)),
        item('О', 'отпуск', PdfColor.fromInt(0xFFF3E5F5)),
        item('В', 'выходной', PdfColor.fromInt(0xFFEEEEEE)),
      ],
    );
  }

  static pw.Widget _signatureLine({double width = 110}) {
    return pw.SizedBox(
      width: width,
      height: 14,
      child: pw.DecoratedBox(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
          ),
        ),
      ),
    );
  }

  static pw.Widget _signatureBlock(String? director) {
    final style = pw.TextStyle(font: _font, fontSize: 10);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Глава КФХ', style: style),
            pw.SizedBox(width: 16),
            _signatureLine(),
            pw.SizedBox(width: 12),
            pw.Text(
              director != null ? '/ $director /' : '/              /',
              style: style,
            ),
          ],
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Дата', style: style),
            pw.SizedBox(width: 16),
            _signatureLine(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: _font,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(value, style: pw.TextStyle(font: _fontBold, fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final size = emphasize ? 12.0 : 11.0;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(font: _fontBold, fontSize: size),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: _fontBold, fontSize: size),
        ),
      ],
    );
  }

  static pw.Widget _simpleTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<String> footer,
    Set<int> alignRight = const {},
  }) {
    pw.Alignment align(int i) => alignRight.contains(i)
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;

    pw.TableRow buildRow(
      List<String> cells, {
      bool header = false,
      bool footerRow = false,
    }) {
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: header
              ? PdfColors.grey200
              : footerRow
              ? PdfColors.grey100
              : null,
        ),
        children: [
          for (var i = 0; i < cells.length; i++)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              alignment: align(i),
              child: pw.Text(
                cells[i],
                style: pw.TextStyle(
                  font: header || footerRow ? _fontBold : _font,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FlexColumnWidth(1.3),
      },
      children: [
        buildRow(headers, header: true),
        ...rows.map(buildRow),
        buildRow(footer, footerRow: true),
      ],
    );
  }
}
