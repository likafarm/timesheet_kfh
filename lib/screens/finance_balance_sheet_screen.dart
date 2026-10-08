// lib/screens/finance_balance_sheet_screen.dart
//
// «Финансы → Отчёты → Управленческий баланс» (8Б.2): что у хозяйства есть
// и что оно должно на начало года и на выбранный день, изменение за
// период; капитал — разница. Расчёт — buildManagementBalance (kfh_domain),
// долг по зарплате — AppProvider.payrollBalancesOn.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/excel_export.dart';
import '../widgets/excel_export_action.dart';

class FinanceBalanceSheetScreen extends StatefulWidget {
  const FinanceBalanceSheetScreen({super.key});

  @override
  State<FinanceBalanceSheetScreen> createState() =>
      _FinanceBalanceSheetScreenState();
}

/// Баланс на две даты: начало года дня и сам день.
typedef BalancePair = (ManagementBalance start, ManagementBalance end);

class _FinanceBalanceSheetScreenState extends State<FinanceBalanceSheetScreen> {
  DateTime _day = calendarDay(DateTime.now());
  Future<BalancePair>? _future;
  Object? _key;

  DateTime get _start => DateTime(_day.year, 1, 1);

  /// Конец дня перед началом года — остатки «на 01.01».
  DateTime get _startEve => DateTime(_day.year, 1, 0);

  Future<BalancePair> _load(AppProvider app, FinanceProvider fin) async {
    final names = {for (final e in app.employees) e.id!: e.fullName};
    Future<ManagementBalance> on(DateTime day) async => buildManagementBalance(
      day: day,
      catalog: fin.catalog,
      operations: fin.allOperations,
      payrollBalances: await app.payrollBalancesOn(day),
      employeeName: (id) => names[id] ?? 'Сотрудник',
    );
    return (await on(_startEve), await on(_day));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _day = calendarDay(picked));
  }

  String _date(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  Future<void> _export(BalancePair pair) async {
    final app = context.read<AppProvider>();
    if (app.companySettings == null) await app.loadCompanySettings();
    if (!mounted) return;
    await exportToExcel(
      context,
      fileName:
          'Управленческий_баланс_${DateFormat('yyyy-MM-dd').format(_day)}.xlsx',
      build: () async => managementBalanceWorkbook(
        start: pair.$1,
        end: pair.$2,
        startLabel: 'На ${_date(_start)}',
        endLabel: 'На ${_date(_day)}',
        companySettings: app.companySettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final fin = context.watch<FinanceProvider>();
    // Пересчёт — при смене дня и после правок или приёма с сервера.
    final key = (_day, app.dataVersion, fin.loaded, fin.allOperations.length);
    if (fin.loaded && key != _key) {
      _key = key;
      _future = _load(app, fin);
    }
    return FutureBuilder<BalancePair>(
      future: _future,
      builder: (context, snap) {
        final pair = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Управленческий баланс'),
            actions: [
              TextButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.event, size: 18),
                label: Text('На ${_date(_day)}'),
              ),
              IconButton(
                tooltip: 'Выгрузить в Excel',
                icon: const Icon(Icons.table_view),
                onPressed: pair == null ? null : () => _export(pair),
              ),
            ],
          ),
          body: snap.hasError
              ? Center(child: Text('Не удалось посчитать: ${snap.error}'))
              : pair == null
              ? const Center(child: CircularProgressIndicator())
              : _table(pair),
        );
      },
    );
  }

  static const _nameWidth = 300.0;
  static const _cell = 140.0;

  Widget _table(BalancePair pair) {
    final (start, end) = pair;
    final theme = Theme.of(context);
    final rows = <Widget>[
      _row(
        '',
        'На ${_date(_start)}',
        'На ${_date(_day)}',
        'Изменение',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        border: true,
      ),
      ..._side('Актив — что есть', start.assets, end.assets),
      _total('Итого актив', start.totalAssets, end.totalAssets),
      const SizedBox(height: 12),
      ..._side('Пассив — что должны', start.liabilities, end.liabilities),
      _total('Итого пассив', start.totalLiabilities, end.totalLiabilities),
      const SizedBox(height: 12),
      _total(
        'Капитал (актив − пассив)',
        start.equity,
        end.equity,
        fill: theme.colorScheme.primaryContainer,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
        child: Text(
          'Имущество — по справочной стоимости (износа нет), без стада и '
          'запасов кормов. Остатки денег верны, если остатки кошельков '
          'сверены с банком и кассой.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _nameWidth + 3 * _cell + 32,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: rows,
        ),
      ),
    );
  }

  String _money(int? k) => k == null ? '' : '${formatRub(k)} ₽';

  List<Widget> _side(
    String title,
    List<BalanceSection> start,
    List<BalanceSection> end,
  ) {
    final theme = Theme.of(context);
    const small = TextStyle(fontSize: 12);
    final bold = small.copyWith(fontWeight: FontWeight.w600);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(title, style: theme.textTheme.titleSmall),
      ),
      // Пустой на обе даты раздел не показывается.
      for (var i = 0; i < end.length; i++)
        if (end[i].lines.isNotEmpty || start[i].lines.isNotEmpty) ...[
          _row(
            end[i].title,
            _money(start[i].total),
            _money(end[i].total),
            _money(end[i].total - start[i].total),
            style: bold,
            fill: theme.colorScheme.surfaceContainerHigh,
          ),
          for (final name in {
            for (final l in end[i].lines) l.name,
            for (final l in start[i].lines) l.name,
          })
            () {
              int? amount(BalanceSection s) =>
                  s.lines.where((l) => l.name == name).firstOrNull?.amount;
              final a = amount(start[i]), b = amount(end[i]);
              return _row(
                name,
                _money(a),
                _money(b),
                _money((b ?? 0) - (a ?? 0)),
                style: small,
                indent: true,
              );
            }(),
        ],
    ];
  }

  Widget _total(String name, int start, int end, {Color? fill}) => _row(
    name,
    _money(start),
    _money(end),
    _money(end - start),
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    fill: fill ?? Theme.of(context).colorScheme.surfaceContainerHighest,
  );

  Widget _row(
    String name,
    String start,
    String end,
    String change, {
    required TextStyle style,
    Color? fill,
    bool border = false,
    bool indent = false,
  }) {
    final theme = Theme.of(context);
    Widget cell(String text) => SizedBox(
      width: _cell,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(text, style: style, textAlign: TextAlign.right),
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
          cell(start),
          cell(end),
          cell(change),
        ],
      ),
    );
  }
}
