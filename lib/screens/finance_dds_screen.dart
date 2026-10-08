// lib/screens/finance_dds_screen.dart
//
// «Финансы → Отчёты → Движение денег (ДДС)» (8Б.3, факт): остаток денег на
// начало месяца, потоки операционной, инвестиционной и финансовой
// деятельности, остаток на конец — по месяцам года. Расчёт — ddsReport
// (kfh_domain). План (БДДС) — шаг 8Б.5.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/excel_export.dart';
import '../widgets/excel_export_action.dart';
import 'finance_report_screen.dart' show formatRubWhole;

class FinanceDdsScreen extends StatefulWidget {
  const FinanceDdsScreen({super.key});

  @override
  State<FinanceDdsScreen> createState() => _FinanceDdsScreenState();
}

class _FinanceDdsScreenState extends State<FinanceDdsScreen> {
  int _year = DateTime.now().year;

  static const _nameWidth = 260.0;
  static const _cellWidth = 96.0;
  static const _totalWidth = 112.0;

  Future<void> _export(DdsReport report) async {
    final app = context.read<AppProvider>();
    if (app.companySettings == null) await app.loadCompanySettings();
    if (!mounted) return;
    await exportToExcel(
      context,
      fileName: 'ДДС_$_year.xlsx',
      build: () async => ddsWorkbook(
        report: report,
        title: 'Движение денег (ДДС) — $_year',
        companySettings: app.companySettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final report = fin.loaded
        ? ddsReport(
            operations: fin.allOperations,
            catalog: fin.catalog,
            from: DateTime(_year),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Движение денег (ДДС)'),
        actions: [
          IconButton(
            tooltip: 'Предыдущий год',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Center(
            child: Text(
              '$_year',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Следующий год',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year++),
          ),
          IconButton(
            tooltip: 'Выгрузить в Excel',
            icon: const Icon(Icons.table_view),
            onPressed: report == null ? null : () => _export(report),
          ),
        ],
      ),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : _table(report),
    );
  }

  String _amount(int k) => k == 0 ? '' : formatRubWhole(k);
  int _sum(List<int> v) => v.fold(0, (a, b) => a + b);

  Widget _table(DdsReport r) {
    final theme = Theme.of(context);
    const small = TextStyle(fontSize: 12);
    final bold = small.copyWith(fontWeight: FontWeight.bold);
    final width = _nameWidth + r.columns.length * _cellWidth + _totalWidth + 32;
    Widget flows(
      List<int> values,
      String name, {
      TextStyle? style,
      Color? fill,
    }) => _row(
      name,
      [for (final v in values) _amount(v)],
      formatRubWhole(_sum(values)),
      style: style ?? bold,
      fill: fill,
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    List<Widget> section(CashFlowSection s, String name, {int sign = 1}) => [
      _row(
        name,
        [for (final v in s.values) _amount(sign * v)],
        formatRubWhole(sign * s.total),
        style: bold,
        fill: theme.colorScheme.surfaceContainerHigh,
      ),
      for (final g in s.groups)
        for (final l in g.lines)
          _row(
            l.name,
            [for (final v in l.values) _amount(sign * v)],
            formatRubWhole(sign * l.total),
            style: small,
            indent: true,
          ),
    ];
    final total = theme.colorScheme.surfaceContainerHighest;
    final rows = <Widget>[
      _row(
        '',
        [for (final m in r.columns) DateFormat('LLL', 'ru').format(m)],
        'Год',
        style: bold,
        border: true,
      ),
      _row(
        'Деньги на начало месяца',
        [for (final v in r.opening) formatRubWhole(v)],
        formatRubWhole(r.opening.first),
        style: bold,
        fill: total,
      ),
      heading('Операционная деятельность'),
      ...section(r.operatingIn, 'Поступления'),
      ...section(r.operatingOut, 'Платежи', sign: -1),
      flows(r.operatingNet, 'Итого операционная'),
      heading('Инвестиционная деятельность'),
      ...section(r.investingOut, 'Капвложения', sign: -1),
      flows(r.investingNet, 'Итого инвестиционная'),
      heading('Финансовая деятельность (займы)'),
      for (final l in r.financing)
        _row(
          l.name,
          [for (final v in l.values) _amount(v)],
          formatRubWhole(l.total),
          style: small,
          indent: true,
        ),
      flows(r.financingNet, 'Итого финансовая'),
      const SizedBox(height: 8),
      if (r.hasOther)
        flows(
          r.other,
          'Прочее: начальные остатки новых кошельков',
          style: small.copyWith(fontStyle: FontStyle.italic),
        ),
      flows(r.netFlow, 'Изменение денег за месяц', fill: total),
      _row(
        'Деньги на конец месяца',
        [for (final v in r.closing) formatRubWhole(v)],
        formatRubWhole(r.closing.last),
        style: bold,
        fill: total,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
        child: Text(
          'Суммы — в рублях, со знаком: приход — плюс, уход — минус. '
          'Переводы между кошельками деньги хозяйства не меняют и в отчёт не '
          'входят. Остатки верны, если кошельки сверены с банком и кассой.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: rows,
        ),
      ),
    );
  }

  Widget _row(
    String name,
    List<String> months,
    String total, {
    required TextStyle style,
    Color? fill,
    bool border = false,
    bool indent = false,
  }) {
    final theme = Theme.of(context);
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          bottom: BorderSide(
            color: border ? Colors.grey : theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _nameWidth,
            child: Padding(
              padding: EdgeInsets.fromLTRB(indent ? 16 : 4, 6, 4, 6),
              child: Text(
                name,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (final m in months) cell(m, _cellWidth),
          cell(total, _totalWidth),
        ],
      ),
    );
  }
}
