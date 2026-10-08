// lib/screens/finance_report_screen.dart
//
// Отчёты финансов (вторая очередь этапа 8): доходы и расходы за год по
// месяцам — строками по статьям (с группами) или по направлениям; нажатие
// на сумму открывает операции этого месяца и строки.
// Себестоимость кормов — затраты и выручка направления по сезонам урожая.
// Выгрузка — в Excel.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/excel_export.dart';
import '../widgets/common_widgets.dart';
import '../widgets/excel_export_action.dart';
import '../widgets/finance_operation_dialog.dart';
import '../widgets/month_switcher.dart';
import 'finance_screen.dart';

/// Вид отчёта.
enum FinanceReportMode {
  category('По статьям'),
  direction('По направлениям'),
  season('Корма по сезонам');

  final String title;
  const FinanceReportMode(this.title);
}

/// Открывает отчёт за год [year] (себестоимость кормов — сезоны по
/// [year]).
Future<void> openFinanceReport(
  BuildContext context,
  FinanceProvider fin, {
  required int year,
  FinanceReportMode mode = FinanceReportMode.category,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: fin,
      child: FinanceReportScreen(year: year, mode: mode),
    ),
  ),
);

class FinanceReportScreen extends StatefulWidget {
  final int year;
  final FinanceReportMode mode;

  const FinanceReportScreen({
    super.key,
    required this.year,
    this.mode = FinanceReportMode.category,
  });

  @override
  State<FinanceReportScreen> createState() => _FinanceReportScreenState();
}

/// Сумма в отчёте — в целых рублях (точно — в Excel).
String formatRubWhole(int kopecks) {
  final rub = kopecks >= 0 ? (kopecks + 50) ~/ 100 : -((-kopecks + 50) ~/ 100);
  return formatRub(rub * 100).replaceFirst(',00', '');
}

/// Сумма месяца: ноль не показывается.
String _amount(int kopecks) => kopecks == 0 ? '' : formatRubWhole(kopecks);

class _FinanceReportScreenState extends State<FinanceReportScreen> {
  late int _year = widget.year;
  late FinanceReportMode _mode = widget.mode;

  /// Направление себестоимости; null — по умолчанию ([feedDirection]).
  String? _directionId;

  /// Сезонов в отчёте себестоимости.
  static const _seasons = 3;

  bool get _bySeason => _mode == FinanceReportMode.season;

  static const _nameWidth = 230.0;
  static const _cellWidth = 96.0;
  static const _totalWidth = 112.0;

  String? _direction(FinanceProvider fin) {
    final id = _directionId;
    if (id != null && fin.catalog.directions.containsKey(id)) return id;
    return feedDirection(fin.catalog) ?? fin.directions.firstOrNull?.id;
  }

  String get _seasonRange => '${_year - _seasons + 1}–$_year';

  CashFlowReport? _report(FinanceProvider fin) {
    if (!_bySeason) {
      return cashFlowReport(
        operations: fin.allOperations,
        catalog: fin.catalog,
        from: DateTime(_year),
        by: _mode == FinanceReportMode.direction
            ? CashFlowBy.direction
            : CashFlowBy.category,
      );
    }
    final direction = _direction(fin);
    if (direction == null) return null;
    return seasonCostReport(
      operations: fin.allOperations,
      catalog: fin.catalog,
      directionId: direction,
      lastSeason: _year,
      count: _seasons,
    );
  }

  Future<void> _export(FinanceProvider fin, CashFlowReport report) async {
    final app = context.read<AppProvider>();
    if (app.companySettings == null) await app.loadCompanySettings();
    if (!mounted) return;
    final direction = fin.catalog.directions[report.directionId]?.name;
    await exportToExcel(
      context,
      fileName: _bySeason
          ? 'Себестоимость_по_сезонам_$_year.xlsx'
          : 'Финансы_по_месяцам_$_year.xlsx',
      build: () async => cashFlowWorkbook(
        report: report,
        title: _bySeason
            ? 'Себестоимость по сезонам $_seasonRange — $direction'
            : 'Доходы и расходы по месяцам — $_year',
        sheetName: _bySeason ? 'Сезоны $_seasonRange' : 'По месяцам $_year',
        companySettings: app.companySettings,
      ),
    );
  }

  /// Отбор списка операций по месяцу [i] и строке [line].
  void _open(CashFlowSection section, CashFlowLine line, int i) {
    if (line.id == noCategory || line.id == unassignedDirection) return;
    final type = section.type == CategoryType.income
        ? OperationType.income
        : OperationType.expense;
    FinanceScreen.push(
      context,
      FinanceFilter(
        month: DateTime(_year, i + 1),
        type: type,
        categoryId: _mode == FinanceReportMode.category ? line.id : null,
        directionId: _mode == FinanceReportMode.direction ? line.id : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final report = _report(fin);
    final compact = MonthSwitcher.isCompact(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _bySeason
              ? (compact ? 'Корма' : 'Себестоимость кормов по сезонам')
              : (compact ? 'По месяцам' : 'Доходы и расходы по месяцам'),
        ),
        actions: [
          IconButton(
            tooltip: 'Предыдущий год',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Center(
            child: Text(
              _bySeason ? _seasonRange : '$_year',
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
            onPressed: report == null ? null : () => _export(fin, report),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<FinanceReportMode>(
                segments: [
                  for (final m in FinanceReportMode.values)
                    ButtonSegment(value: m, label: Text(m.title)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.single),
              ),
            ),
          ),
          if (_bySeason && fin.directions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: 320,
                child: AppDropdown<String>(
                  labelText: 'Направление',
                  value: _direction(fin),
                  items: [
                    for (final d in fin.directions)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() => _directionId = v),
                ),
              ),
            ),
          Expanded(
            child: report == null || report.isEmpty
                ? Center(
                    child: Text(
                      report == null
                          ? 'Нет направлений — заведите их в справочниках'
                          : _bySeason
                          ? 'Нет затрат и выручки за сезоны $_seasonRange'
                          : 'Нет доходов и расходов за $_year год',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : _table(report),
          ),
        ],
      ),
    );
  }

  Widget _table(CashFlowReport report) {
    final theme = Theme.of(context);
    final width =
        _nameWidth + report.columns.length * _cellWidth + _totalWidth + 32;
    final rows = <Widget>[
      _row(
        report.by == CashFlowBy.category ? 'Статья' : 'Направление',
        [
          for (final m in report.columns)
            _bySeason ? 'Сезон ${m.year}' : DateFormat('LLL', 'ru').format(m),
        ],
        'Итого',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        border: true,
      ),
      ..._section(
        report,
        report.income,
        _bySeason ? 'Выручка' : 'Доходы',
        'в т. ч. возвраты',
      ),
      ..._section(
        report,
        report.expense,
        _bySeason ? 'Затраты' : 'Расходы',
        'в т. ч. капвложения',
      ),
      _row(
        _bySeason ? 'Итог: выручка − затраты' : 'Итог: доходы − расходы',
        [for (final k in report.result) _amount(k)],
        formatRubWhole(report.resultTotal),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        fill: theme.colorScheme.surfaceContainerHighest,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        child: Text(
          _bySeason
              ? 'Суммы — в рублях. Сезон — урожай, под который потрачены '
                    'деньги: по умолчанию — год операции, меняется полем '
                    '«Сезон урожая» в окне операции. Расход по ключу входит '
                    'долей направления; общехозяйственные расходы не '
                    'распределяются. Итог со знаком минус — во сколько '
                    'обошлись свои корма за сезон.'
              : 'Суммы — в рублях. Переводы и займы в отчёт не входят. '
                    'Нажмите на сумму — откроются операции месяца по этой '
                    'строке.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: rows,
        ),
      ),
    );
  }

  List<Widget> _section(
    CashFlowReport report,
    CashFlowSection s,
    String name,
    String special,
  ) {
    final theme = Theme.of(context);
    final color = s.type == CategoryType.income
        ? operationTypeColors[OperationType.income]
        : operationTypeColors[OperationType.expense];
    const small = TextStyle(fontSize: 12);
    final bold = small.copyWith(fontWeight: FontWeight.bold);
    final byCategory = report.by == CashFlowBy.category;
    return [
      _row(
        name,
        [for (final k in s.values) _amount(k)],
        formatRubWhole(s.total),
        style: bold.copyWith(color: color),
        fill: theme.colorScheme.surfaceContainerHigh,
      ),
      for (final g in s.groups) ...[
        if (byCategory)
          _row(
            g.name,
            [for (final k in g.values) _amount(k)],
            formatRubWhole(g.total),
            style: bold,
          ),
        for (final l in g.lines)
          _row(
            l.name,
            [for (final k in l.values) _amount(k)],
            formatRubWhole(l.total),
            style: small,
            indent: byCategory,
            onTap: _bySeason ? null : (i) => _open(s, l, i),
          ),
      ],
      if (s.specialTotal != 0)
        _row(
          special,
          [for (final k in s.special) _amount(k)],
          formatRubWhole(s.specialTotal),
          style: small.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          indent: true,
        ),
      const SizedBox(height: 8),
    ];
  }

  Widget _row(
    String name,
    List<String> months,
    String total, {
    required TextStyle style,
    Color? fill,
    bool border = false,
    bool indent = false,
    void Function(int month)? onTap,
  }) {
    final theme = Theme.of(context);
    Widget cell(String text, double width, {VoidCallback? tap}) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      return SizedBox(
        width: width,
        child: tap == null || text.isEmpty
            ? child
            : InkWell(onTap: tap, child: child),
      );
    }

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
          for (final (i, m) in months.indexed)
            cell(m, _cellWidth, tap: onTap == null ? null : () => onTap(i)),
          cell(total, _totalWidth),
        ],
      ),
    );
  }
}
