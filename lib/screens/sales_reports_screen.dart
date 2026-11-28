// lib/screens/sales_reports_screen.dart
//
// «Продажи → Отчёты» (этап 11.8): за год или месяц (по дню выдачи) —
// продажи по товарам (итог или по месяцам), по выдачам, заказано против
// выданного и покупатели (давно не заказывали, долги и авансы); выгрузка
// всех четырёх в Excel. Расчёты — `packages/domain/lib/src/sales/reports.dart`.
// На телефоне таблицы прокручиваются вбок.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/orders_provider.dart';
import '../services/excel_export.dart';
import '../widgets/excel_export_action.dart';
import '../widgets/row_table.dart';
import 'batches_screen.dart' show batchTitle, openBatch;
import 'order_editor_screen.dart' show fmtQty, rub;

final _day = DateFormat('dd.MM.yyyy', 'ru');
final _monthName = DateFormat('LLLL', 'ru');

enum SalesView {
  products('По товарам'),
  batches('По выдачам'),
  ordered('Заказано и выдано'),
  customers('Покупатели');

  final String title;
  const SalesView(this.title);
}

/// Покупатель «давно не заказывал» — дней с последнего заказа.
const longAgoDays = 60;

String _qty(double v, bool byWeight) =>
    '${fmtQty(double.parse(v.toStringAsFixed(3)))} ${byWeight ? 'кг' : 'шт'}';

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  late final OrdersProvider _orders = OrdersProvider(
    context.read<AppProvider>(),
  )..load();

  /// null — весь период.
  int? _year = DateTime.now().year;

  /// null — весь год.
  int? _month;
  SalesView _view = SalesView.products;
  bool _byMonths = false;
  bool _onlyLongAgo = false;

  @override
  void dispose() {
    _orders.dispose();
    super.dispose();
  }

  SalesPeriod get _period => _year == null
      ? const SalesPeriod()
      : _month == null
      ? SalesPeriod.year(_year!)
      : SalesPeriod.month(_year!, _month!);

  String get _periodTitle => _year == null
      ? 'весь период'
      : _month == null
      ? '$_year год'
      : '${_monthName.format(DateTime(_year!, _month!))} $_year';

  Future<void> _export(BuildContext context, OrdersProvider p) {
    final data = p.salesData;
    final period = _period;
    return exportToExcel(
      context,
      fileName: 'Продажи ${_periodTitle.replaceAll(' ', '_')}.xlsx',
      build: () async => salesReportWorkbook(
        periodTitle: _periodTitle,
        products: productSales(data, period, groupOrder: p.groupOrder),
        batches: batchSales(data, period),
        ordered: orderedVsIssued(data, period, tolerance: p.tolerance),
        customers: customerSales(data, period),
        productName: (id) => p.products[id]?.name ?? '?',
        customerName: (id) => p.customers[id]?.name ?? '?',
        batchName: batchTitle,
        today: DateTime.now(),
        companySettings: context.read<AppProvider>().companySettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _orders,
      child: Consumer<OrdersProvider>(
        builder: (context, p, _) {
          final years = {
            for (final b in p.batches) b.day.year,
            DateTime.now().year,
          }.toList()..sort((a, b) => b.compareTo(a));
          return Scaffold(
            appBar: AppBar(
              title: const Text('Отчёты по продажам'),
              actions: [
                if (p.loaded)
                  IconButton(
                    tooltip: 'Выгрузить в Excel',
                    icon: const Icon(Icons.table_view_outlined),
                    onPressed: () => _export(context, p),
                  ),
              ],
            ),
            body: !p.loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<int?>(
                            value: _year,
                            items: [
                              for (final y in years)
                                DropdownMenuItem(value: y, child: Text('$y')),
                              const DropdownMenuItem(
                                child: Text('Весь период'),
                              ),
                            ],
                            onChanged: (y) => setState(() {
                              _year = y;
                              if (y == null) _month = null;
                            }),
                          ),
                          if (_year != null)
                            DropdownButton<int?>(
                              value: _month,
                              items: [
                                const DropdownMenuItem(
                                  child: Text('Все месяцы'),
                                ),
                                for (var m = 1; m <= 12; m++)
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      _monthName.format(DateTime(2000, m)),
                                    ),
                                  ),
                              ],
                              onChanged: (m) => setState(() => _month = m),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final v in SalesView.values)
                            ChoiceChip(
                              label: Text(v.title),
                              selected: _view == v,
                              onSelected: (_) => setState(() => _view = v),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...switch (_view) {
                        SalesView.products => _products(context, p),
                        SalesView.batches => _batches(context, p),
                        SalesView.ordered => _ordered(context, p),
                        SalesView.customers => _customers(context, p),
                      },
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// Таблица: на узком экране — прокрутка вбок с шириной [minWidth].
  Widget _table(
    BuildContext context,
    List<RowCol> cols,
    List<Widget> rows, {
    double minWidth = 900,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [RowTableHeader(cols), ...rows],
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= minWidth
          ? body
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: body),
            ),
    );
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: Text('За этот период выданных заказов нет')),
  );

  // ---------------------------------------------------------- по товарам

  List<Widget> _products(BuildContext context, OrdersProvider p) {
    final theme = Theme.of(context);
    final r = productSales(p.salesData, _period, groupOrder: p.groupOrder);
    if (r.rows.isEmpty) return [_empty()];
    final months = r.months;
    final total = Text(
      'Выручка: ${rub(r.total.amount)}'
      '${r.freeValue + r.ownValue > 0 ? ' · без оплаты и себе — на ${rub(r.freeValue + r.ownValue)}' : ''}',
      style: theme.textTheme.titleMedium,
    );
    final toggle = Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Итого'),
          selected: !_byMonths,
          onSelected: (_) => setState(() => _byMonths = false),
        ),
        ChoiceChip(
          label: const Text('По месяцам'),
          selected: _byMonths,
          onSelected: months.length < 2
              ? null
              : (_) => setState(() => _byMonths = true),
        ),
      ],
    );
    String name(String id) => p.products[id]?.name ?? '?';
    if (_byMonths && months.length >= 2) {
      final cols = [
        const RowCol('Товар', width: 200),
        for (final (y, m) in months)
          RowCol(
            '${_monthName.format(DateTime(y, m)).substring(0, 3)} '
            '${y % 100}',
            width: 110,
            right: true,
          ),
        const RowCol('Итого', width: 120, right: true),
      ];
      Widget cell(SalesCell? c, bool byWeight) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CellText(
            c == null || c.qty == 0 ? '' : _qty(c.qty, byWeight),
            right: true,
          ),
          CellText(
            c == null || c.amount == 0 ? '' : rub(c.amount),
            right: true,
            bold: true,
          ),
        ],
      );
      return [
        total,
        const SizedBox(height: 8),
        toggle,
        const SizedBox(height: 8),
        _table(context, cols, [
          for (final row in r.rows)
            RowTableRow(
              cols: cols,
              cells: [
                CellText(name(row.productId), bold: true),
                for (final m in months) cell(row.months[m], row.byWeight),
                cell(row.total, row.byWeight),
              ],
            ),
          RowTableRow(
            cols: cols,
            color: theme.colorScheme.surfaceContainerHigh,
            cells: [
              const CellText('Итого', bold: true),
              for (final m in months)
                CellText(
                  rub(r.monthTotals[m]?.amount ?? 0),
                  right: true,
                  bold: true,
                ),
              CellText(rub(r.total.amount), right: true, bold: true),
            ],
          ),
        ], minWidth: 200 + 110.0 * months.length + 150),
      ];
    }
    const cols = [
      RowCol('Товар', flex: 3),
      RowCol('Продано', width: 120, right: true),
      RowCol('Сумма', width: 130, right: true),
      RowCol('Средняя цена', width: 130, right: true),
      RowCol('Заказов', width: 80, right: true),
      RowCol('Без оплаты и себе', width: 160, right: true),
    ];
    return [
      total,
      const SizedBox(height: 8),
      toggle,
      const SizedBox(height: 8),
      _table(context, cols, [
        for (final row in r.rows)
          RowTableRow(
            cols: cols,
            cells: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CellText(name(row.productId), bold: true),
                  if (row.noQty > 0)
                    Text(
                      'без веса: ${row.noQty}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              CellText(_qty(row.total.qty, row.byWeight), right: true),
              CellText(rub(row.total.amount), right: true, bold: true),
              CellText(
                row.total.averagePrice == null
                    ? '—'
                    : '${rub(row.total.averagePrice!)}/'
                          '${row.byWeight ? 'кг' : 'шт'}',
                right: true,
              ),
              CellText('${row.orders}', right: true),
              CellText(
                row.freeQty + row.ownQty == 0
                    ? ''
                    : '${_qty(row.freeQty + row.ownQty, row.byWeight)} · '
                          '${rub(row.freeValue + row.ownValue)}',
                right: true,
              ),
            ],
          ),
      ]),
    ];
  }

  // ---------------------------------------------------------- по выдачам

  List<Widget> _batches(BuildContext context, OrdersProvider p) {
    final theme = Theme.of(context);
    final rows = batchSales(p.salesData, _period);
    if (rows.isEmpty) return [_empty()];
    const cols = [
      RowCol('Выдача', flex: 3),
      RowCol('Заказов', width: 80, right: true),
      RowCol('Продано', width: 110, right: true),
      RowCol('Выручка', width: 130, right: true),
      RowCol('Без оплаты', width: 110, right: true),
      RowCol('Себе', width: 90, right: true),
      RowCol('Оплачено', width: 130, right: true),
      RowCol('Долг', width: 120, right: true),
    ];
    final sum = rows.fold<int>(0, (s, b) => s + b.saleAmount);
    final debt = rows.fold<int>(0, (s, b) => s + b.debt);
    return [
      Text(
        'Выдач: ${rows.length} · выручка ${rub(sum)}'
        '${debt > 0 ? ' · долг ${rub(debt)}' : ''}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      _table(context, cols, [
        for (final b in rows)
          RowTableRow(
            cols: cols,
            onTap: () => openBatch(context, b.batch.id),
            cells: [
              CellText(batchTitle(b.batch), bold: true),
              CellText('${b.orders}', right: true),
              CellText(_qty(b.saleKg, true), right: true),
              CellText(rub(b.saleAmount), right: true, bold: true),
              CellText(b.freeKg > 0 ? _qty(b.freeKg, true) : '', right: true),
              CellText(b.ownKg > 0 ? _qty(b.ownKg, true) : '', right: true),
              CellText(b.paid > 0 ? rub(b.paid) : '', right: true),
              CellText(
                b.debt > 0 ? rub(b.debt) : '',
                right: true,
                color: theme.colorScheme.error,
              ),
            ],
          ),
      ]),
    ];
  }

  // -------------------------------------------- заказано против выданного

  List<Widget> _ordered(BuildContext context, OrdersProvider p) {
    final theme = Theme.of(context);
    final rows = orderedVsIssued(p.salesData, _period, tolerance: p.tolerance);
    if (rows.isEmpty) return [_empty()];
    const cols = [
      RowCol('Товар', flex: 3),
      RowCol('Строк', width: 70, right: true),
      RowCol('Заказано', width: 110, right: true),
      RowCol('Выдано', width: 110, right: true),
      RowCol('Отклонение', width: 110, right: true),
      RowCol('Больше / меньше допуска', width: 180, right: true),
      RowCol('Не хватило', width: 150, right: true),
    ];
    final tol = (p.tolerance * 100).round();
    return [
      Text(
        'Только строки, заказанные в килограммах; допуск — $tol % '
        '(меняется в «Выдачах»).',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      _table(context, cols, [
        for (final r in rows)
          RowTableRow(
            cols: cols,
            cells: [
              CellText(p.products[r.productId]?.name ?? '?', bold: true),
              CellText(r.lines > 0 ? '${r.lines}' : '', right: true),
              CellText(r.lines > 0 ? _qty(r.orderedKg, true) : '', right: true),
              CellText(r.lines > 0 ? _qty(r.factKg, true) : '', right: true),
              CellText(
                switch (r.deviation) {
                  null => '',
                  final d =>
                    '${d >= 0 ? '+' : '−'}${(d.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')} %',
                },
                right: true,
                color: (r.deviation?.abs() ?? 0) > p.tolerance
                    ? theme.colorScheme.error
                    : null,
              ),
              CellText(
                r.over + r.under == 0 ? '' : '${r.over} / ${r.under}',
                right: true,
              ),
              CellText(
                r.missing == 0
                    ? ''
                    : '${r.missing} раз'
                          '${r.missingKg > 0 ? ' · ${_qty(r.missingKg, true)}' : ''}',
                right: true,
                color: theme.colorScheme.error,
              ),
            ],
          ),
      ]),
    ];
  }

  // ---------------------------------------------------------- покупатели

  List<Widget> _customers(BuildContext context, OrdersProvider p) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final all = customerSales(p.salesData, _period);
    final rows = [
      for (final c in all)
        if (!_onlyLongAgo || (c.daysSince(today) ?? 0) > longAgoDays) c,
    ];
    final debt = all.fold<int>(
      0,
      (s, c) => s + (c.balance < 0 ? -c.balance : 0),
    );
    final advance = all.fold<int>(
      0,
      (s, c) => s + (c.balance > 0 ? c.balance : 0),
    );
    const cols = [
      RowCol('Покупатель', flex: 3),
      RowCol('Заказов', width: 80, right: true),
      RowCol('Сумма', width: 130, right: true),
      RowCol('Средний чек', width: 120, right: true),
      RowCol('Первый', width: 110, right: true),
      RowCol('Последний', width: 110, right: true),
      RowCol('Дней назад', width: 100, right: true),
      RowCol('Долг / аванс', width: 140, right: true),
    ];
    return [
      Text(
        'Покупателей: ${all.length}'
        '${debt > 0 ? ' · должны ${rub(debt)}' : ''}'
        '${advance > 0 ? ' · авансы ${rub(advance)}' : ''}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      FilterChip(
        label: Text('Давно не заказывали (больше $longAgoDays дней)'),
        selected: _onlyLongAgo,
        onSelected: (v) => setState(() => _onlyLongAgo = v),
      ),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        _empty()
      else
        _table(context, cols, [
          for (final c in rows)
            RowTableRow(
              cols: cols,
              cells: [
                CellText(p.customers[c.customerId]?.name ?? '?', bold: true),
                CellText(c.orders > 0 ? '${c.orders}' : '', right: true),
                CellText(c.amount > 0 ? rub(c.amount) : '', right: true),
                CellText(
                  c.averageCheck == null ? '' : rub(c.averageCheck!),
                  right: true,
                ),
                CellText(
                  c.first == null ? '' : _day.format(c.first!),
                  right: true,
                ),
                CellText(
                  c.last == null ? '' : _day.format(c.last!),
                  right: true,
                ),
                CellText(
                  '${c.daysSince(today) ?? ''}',
                  right: true,
                  color: (c.daysSince(today) ?? 0) > longAgoDays
                      ? theme.colorScheme.error
                      : null,
                ),
                CellText(
                  c.balance < 0
                      ? 'долг ${rub(-c.balance)}'
                      : c.balance > 0
                      ? 'аванс ${rub(c.balance)}'
                      : '',
                  right: true,
                  bold: c.balance != 0,
                  color: c.balance < 0
                      ? theme.colorScheme.error
                      : c.balance > 0
                      ? theme.colorScheme.primary
                      : null,
                ),
              ],
            ),
        ]),
    ];
  }
}
