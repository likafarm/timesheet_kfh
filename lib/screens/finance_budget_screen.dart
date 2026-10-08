// lib/screens/finance_budget_screen.dart
//
// «Финансы → Отчёты → Бюджет (БДДС)» (8Б.5): план поступлений и платежей
// по статьям за год или месяц рядом с фактом и отклонением. Нажатие на
// статью — план по месяцам (одинаково во все месяцы — одной суммой);
// «Заполнить из факта» — план года по прошлому году для статей без плана.
// Расчёт — budgetReport (kfh_domain), план — таблица fin_budget.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/excel_export.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/common_widgets.dart';
import '../widgets/excel_export_action.dart';
import '../widgets/finance_operation_dialog.dart';
import 'finance_report_screen.dart' show formatRubWhole;

class FinanceBudgetScreen extends StatefulWidget {
  const FinanceBudgetScreen({super.key});

  @override
  State<FinanceBudgetScreen> createState() => _FinanceBudgetScreenState();
}

class _FinanceBudgetScreenState extends State<FinanceBudgetScreen> {
  int _year = DateTime.now().year;

  /// Месяц 1–12; null — весь год.
  int? _month = DateTime.now().month;
  List<BudgetEntry>? _entries;
  Object? _key;

  List<int>? get _months => _month == null ? null : [_month!];

  Future<void> _reload(FinanceProvider fin) async {
    final year = _year;
    final entries = await fin.budget(year);
    if (mounted && year == _year) setState(() => _entries = entries);
  }

  String get _periodTitle => _month == null
      ? '$_year год'
      : DateFormat('LLLL yyyy', 'ru')
            .format(DateTime(_year, _month!))
            .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

  Future<void> _fill(FinanceProvider fin) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Заполнить план из факта?'),
        content: Text(
          'Статьям без плана на $_year год поставить план по месяцам, как '
          'было в ${_year - 1} году (до рубля). Статьи, где план уже есть, '
          'не меняются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Заполнить'),
          ),
        ],
      ),
    );
    if (ok == true && await fin.fillBudgetFromLastYear(_year)) {
      await _reload(fin);
    }
  }

  Future<void> _edit(
    FinanceProvider fin,
    String categoryId,
    String name,
  ) async {
    final entries = _entries ?? const <BudgetEntry>[];
    final current = List.filled(12, 0);
    for (final e in entries) {
      if (e.categoryId == categoryId) current[e.month - 1] = e.amount;
    }
    final months = await showAppDialog<List<int>>(
      context: context,
      builder: (_) => _BudgetDialog(name: name, year: _year, months: current),
    );
    if (months == null || !mounted) return;
    if (await fin.saveBudgetFor(_year, categoryId, months)) await _reload(fin);
  }

  /// Статья, которой ещё нет в бюджете.
  Future<void> _addCategory(FinanceProvider fin) async {
    FinCategory? picked;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AppDialog(
          title: const Text('Статья в план'),
          content: SizedBox(
            width: 480,
            child: SearchPicker<FinCategory>(
              label: 'Статья',
              icon: Icons.category_outlined,
              items: [
                for (final c in fin.categories)
                  if (!c.hidden) c,
              ],
              nameOf: (c) => c.name,
              detailOf: (c) =>
                  '${fin.groupName(c)} · ${c.type.title.toLowerCase()}',
              selected: picked,
              onSelected: (c) => setLocal(() => picked = c),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: picked == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Дальше'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && picked != null && mounted) {
      await _edit(fin, picked!.id, picked!.name);
    }
  }

  Future<void> _export(BudgetReport report) async {
    final app = context.read<AppProvider>();
    if (app.companySettings == null) await app.loadCompanySettings();
    if (!mounted) return;
    await exportToExcel(
      context,
      fileName: 'БДДС_$_year.xlsx',
      build: () async => budgetWorkbook(
        report: report,
        months: _months,
        title: 'Бюджет движения денег — $_periodTitle',
        companySettings: app.companySettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final app = context.watch<AppProvider>();
    final key = (_year, app.dataVersion);
    if (key != _key) {
      _key = key;
      _entries = null;
      _reload(fin);
    }
    final entries = _entries;
    final report = fin.loaded && entries != null
        ? fin.budgetReportFor(_year, entries)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджет (БДДС)'),
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
            tooltip: 'Заполнить план из факта прошлого года',
            icon: const Icon(Icons.auto_fix_high),
            onPressed: report == null ? null : () => _fill(fin),
          ),
          IconButton(
            tooltip: 'Выгрузить в Excel',
            icon: const Icon(Icons.table_view),
            onPressed: report == null ? null : () => _export(report),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: 'Статья в план',
        onPressed: report == null ? null : () => _addCategory(fin),
        icon: const Icon(Icons.add),
        label: const Text('Статья'),
      ),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: 240,
                    child: AppDropdown<int?>(
                      labelText: 'Период',
                      value: _month,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Весь год'),
                        ),
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem<int?>(
                            value: m,
                            child: Text(
                              DateFormat('LLLL', 'ru')
                                  .format(DateTime(2000, m))
                                  .replaceFirstMapped(
                                    RegExp('^.'),
                                    (x) => x[0]!.toUpperCase(),
                                  ),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ),
                ),
                Expanded(
                  child: report.isEmpty
                      ? Center(
                          child: Text(
                            'Ни плана, ни факта за $_year год. Добавьте '
                            'статью в план или заполните из факта.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : _table(fin, report),
                ),
              ],
            ),
    );
  }

  static const _nameWidth = 300.0;
  static const _cell = 130.0;

  Widget _table(FinanceProvider fin, BudgetReport r) {
    final theme = Theme.of(context);
    const small = TextStyle(fontSize: 12);
    final bold = small.copyWith(fontWeight: FontWeight.bold);
    final months = _months;
    String money(int k) => k == 0 ? '' : formatRubWhole(k);

    /// Отклонение «факт − план»; для платежей перерасход — плохо.
    Widget row(
      String name,
      int plan,
      int fact, {
      required TextStyle style,
      required CategoryType type,
      Color? fill,
      bool indent = false,
      VoidCallback? onTap,
    }) {
      final diff = fact - plan;
      final bad = type == CategoryType.expense ? diff > 0 : diff < 0;
      final percent = plan == 0 ? '' : '${(fact * 100 / plan).round()} %';
      Widget cell(String text, {Color? color}) => SizedBox(
        width: _cell,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: style.copyWith(color: color),
          ),
        ),
      );
      return InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
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
              cell(money(plan)),
              cell(money(fact)),
              cell(
                plan == 0 && fact == 0 ? '' : formatRubWhole(diff),
                color: diff == 0 || plan == 0
                    ? null
                    : bad
                    ? theme.colorScheme.error
                    : Colors.green[700],
              ),
              cell(percent),
            ],
          ),
        ),
      );
    }

    List<Widget> section(BudgetSection s, String title) => [
      row(
        title,
        s.planOf(months),
        s.factOf(months),
        style: bold.copyWith(
          color:
              operationTypeColors[s.type == CategoryType.income
                  ? OperationType.income
                  : OperationType.expense],
        ),
        type: s.type,
        fill: theme.colorScheme.surfaceContainerHigh,
      ),
      for (final g in s.groups) ...[
        row(
          g.name,
          g.planOf(months),
          g.factOf(months),
          style: bold,
          type: s.type,
        ),
        for (final l in g.lines)
          row(
            l.name,
            l.planOf(months),
            l.factOf(months),
            style: small,
            type: s.type,
            indent: true,
            onTap: l.categoryId == noCategory
                ? null
                : () => _edit(fin, l.categoryId, l.name),
          ),
      ],
      const SizedBox(height: 8),
    ];

    final header = Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _nameWidth,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(_periodTitle, style: bold),
            ),
          ),
          for (final t in ['План', 'Факт', 'Отклонение', 'Исполнение'])
            SizedBox(
              width: _cell,
              child: Text(t, textAlign: TextAlign.right, style: bold),
            ),
        ],
      ),
    );
    final income = r.income.factOf(months), expense = r.expense.factOf(months);
    final planIn = r.income.planOf(months), planOut = r.expense.planOf(months);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _nameWidth + 4 * _cell + 32,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          children: [
            header,
            ...section(r.income, 'Поступления'),
            ...section(r.expense, 'Платежи'),
            row(
              'Итог: поступления − платежи',
              planIn - planOut,
              income - expense,
              style: bold,
              type: CategoryType.income,
              fill: theme.colorScheme.surfaceContainerHighest,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                'Суммы — в рублях. Отклонение — факт минус план: по платежам '
                'красным — перерасход, по поступлениям — недобор. Нажмите на '
                'статью — план по месяцам. Займы и переводы в бюджет не '
                'входят.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// План статьи по месяцам; результат — 12 сумм в копейках.
class _BudgetDialog extends StatefulWidget {
  final String name;
  final int year;
  final List<int> months;

  const _BudgetDialog({
    required this.name,
    required this.year,
    required this.months,
  });

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _fields = [
    for (final k in widget.months)
      TextEditingController(text: k == 0 ? '' : formatRubWhole(k)),
  ];
  final _all = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    _all.dispose();
    super.dispose();
  }

  void _fillAll() {
    final text = _all.text.trim();
    if (parseRub(text) == null) {
      setState(() => _problem = 'Не сумма');
      return;
    }
    setState(() {
      _problem = null;
      for (final f in _fields) {
        f.text = text;
      }
    });
  }

  void _save() {
    final result = <int>[];
    for (final (i, f) in _fields.indexed) {
      final text = f.text.trim();
      final k = text.isEmpty ? 0 : parseRub(text);
      if (k == null || k < 0) {
        setState(
          () => _problem =
              'Не сумма: ${DateFormat('LLLL', 'ru').format(DateTime(2000, i + 1))}',
        );
        return;
      }
      result.add(k);
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text('${widget.name} — план ${widget.year}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _all,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Одинаково в каждый месяц, ₽',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _fillAll,
                    child: const Text('Во все месяцы'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, f) in _fields.indexed)
                    SizedBox(
                      width: 128,
                      child: TextField(
                        controller: f,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: DateFormat(
                            'LLLL',
                            'ru',
                          ).format(DateTime(2000, i + 1)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
              if (_problem != null) ...[
                const SizedBox(height: 10),
                Text(
                  _problem!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
