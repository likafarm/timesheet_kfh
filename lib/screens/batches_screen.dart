// lib/screens/batches_screen.dart
//
// «Продажи → Выдачи» (этап 11.5): выдачи (дни забоя), у каждой —
// сборочный лист (что из каждого товара заказано и кому: бронь частей
// туши), итог (заказано / выдано / не выдано, по товарам; кому не
// хватило), взвешивание подряд (`weighing_screen.dart`), печать пакетов,
// бирок и маршрута доставки, «Выдать собранные».

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/orders_provider.dart';
import '../services/batch_pdf.dart';
import '../services/print_service.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/row_table.dart';
import 'order_editor_screen.dart';
import 'weighing_screen.dart';

final _date = DateFormat('dd.MM.yyyy, EEE', 'ru');
final _shortDate = DateFormat('dd.MM.yyyy', 'ru');

/// «Выдача 27.06.2026, сб» (с диапазоном — «… – 29.06.2026»).
String batchTitle(SaleBatch b) {
  final to = b.dayTo;
  final days = to == null || to == b.day
      ? _date.format(b.day)
      : '${_shortDate.format(b.day)} – ${_shortDate.format(to)}';
  final title = (b.title ?? '').trim();
  return title.isEmpty ? days : '$days · $title';
}

String kg(double v) => '${fmtQty(double.parse(v.toStringAsFixed(3)))} кг';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late final OrdersProvider _orders = OrdersProvider(
    context.read<AppProvider>(),
  )..load();

  @override
  void dispose() {
    _orders.dispose();
    super.dispose();
  }

  Future<void> _add(BuildContext context, OrdersProvider p) async {
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'День выдачи',
    );
    if (day == null || !context.mounted) return;
    final b = await p.addBatch(day);
    if (b != null && context.mounted) openBatch(context, b.id);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _orders,
      child: Consumer<OrdersProvider>(
        builder: (context, p, _) {
          final today = calendarDay(DateTime.now());
          return Scaffold(
            appBar: AppBar(
              title: const Text('Выдачи'),
              actions: [
                IconButton(
                  tooltip: 'Допуск отклонения веса',
                  icon: const Icon(Icons.tune),
                  onPressed: () => askTolerance(context, p),
                ),
              ],
            ),
            floatingActionButton: p.canEdit && p.loaded
                ? FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () => _add(context, p),
                    icon: const Icon(Icons.add),
                    label: const Text('Выдача'),
                  )
                : null,
            body: !p.loaded
                ? const Center(child: CircularProgressIndicator())
                : p.batches.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Выдач пока нет. Выдача появляется с первым заказом '
                        'на день или кнопкой «Выдача».',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWideScreen(context) ? 1300 : 860,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                        children: [
                          // На компьютере — таблица, на телефоне — карточки.
                          if (isWideScreen(context)) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: RowTableHeader(_batchCols),
                            ),
                            for (final b in p.batches)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _BatchRow(
                                  b,
                                  past: calendarDay(b.day).isBefore(today),
                                ),
                              ),
                          ] else
                            for (final b in p.batches)
                              _BatchTile(
                                b,
                                past: calendarDay(b.day).isBefore(today),
                              ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

const _batchCols = [
  RowCol('', width: 32),
  RowCol('Выдача', flex: 4),
  RowCol('Заказов', width: 80, right: true),
  RowCol('Взвешено', width: 110, right: true),
  RowCol('Выдано', width: 80, right: true),
  RowCol('Не хватило', width: 100, right: true),
  RowCol('К оплате', width: 130, right: true),
  RowCol('Оплачено', width: 120, right: true),
  RowCol('Долг', width: 110, right: true),
];

/// Выдача строкой таблицы (компьютер).
class _BatchRow extends StatelessWidget {
  final SaleBatch batch;
  final bool past;
  const _BatchRow(this.batch, {required this.past});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final s = p.summaryOf(batch.id);
    final theme = Theme.of(context);
    final issued = s.byStatus[OrderStatus.issued] ?? 0;
    final done = s.orders > 0 && issued == s.orders;
    var paid = 0, debt = 0;
    for (final o in p.liveOrdersOf(batch.id)) {
      final pay = p.paymentOf(o);
      paid += pay.paid;
      if (p.owes(o)) debt += pay.left;
    }
    return RowTableRow(
      cols: _batchCols,
      onTap: () => openBatch(context, batch.id),
      cells: [
        Icon(
          done ? Icons.task_alt : Icons.inventory_2_outlined,
          size: 20,
          color: done
              ? theme.colorScheme.primary
              : past
              ? theme.colorScheme.outline
              : null,
        ),
        CellText(batchTitle(batch), bold: true),
        CellText('${s.orders}', right: true),
        CellText(
          s.toWeigh == 0 ? '' : '${s.toWeigh - s.open} из ${s.toWeigh}',
          right: true,
        ),
        CellText('$issued', right: true),
        CellText(
          s.missing > 0 ? '${s.missing}' : '',
          right: true,
          color: theme.colorScheme.error,
        ),
        CellText(
          s.due > 0 ? '${s.final_ ? '' : '≈ '}${rub(s.due)}' : '',
          right: true,
          bold: true,
        ),
        CellText(paid > 0 ? rub(paid) : '', right: true),
        CellText(
          debt > 0 ? rub(debt) : '',
          right: true,
          color: theme.colorScheme.error,
        ),
      ],
    );
  }
}

class _BatchTile extends StatelessWidget {
  final SaleBatch batch;
  final bool past;
  const _BatchTile(this.batch, {required this.past});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final s = p.summaryOf(batch.id);
    final theme = Theme.of(context);
    final issued = s.byStatus[OrderStatus.issued] ?? 0;
    final done = s.orders > 0 && issued == s.orders;
    return ListTile(
      onTap: () => openBatch(context, batch.id),
      leading: Icon(
        done ? Icons.task_alt : Icons.inventory_2_outlined,
        color: done
            ? theme.colorScheme.primary
            : past
            ? theme.colorScheme.outline
            : null,
      ),
      title: Text(batchTitle(batch)),
      subtitle: Text(
        [
          'заказов: ${s.orders}',
          if (s.toWeigh > 0) 'взвешено ${s.toWeigh - s.open} из ${s.toWeigh}',
          if (issued > 0 && !done) 'выдано: $issued',
          if (s.missing > 0) 'не хватило: ${s.missing}',
        ].join(' · '),
      ),
      trailing: s.due > 0
          ? Text(
              '${s.final_ ? '' : '≈ '}${rub(s.due)}',
              style: theme.textTheme.titleSmall,
            )
          : null,
    );
  }
}

/// Допуск отклонения веса от заказанного (на этом устройстве).
Future<void> askTolerance(BuildContext context, OrdersProvider p) async {
  final percent = await showAppDialog<int>(
    context: context,
    builder: (context) => AppDialog(
      title: const Text('Допуск отклонения веса'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Вес больше или меньше заказанного сверх допуска выделяется '
            'красным. Допуск хранится на этом устройстве.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in const [5, 10, 15, 20, 25, 30])
                ChoiceChip(
                  label: Text('$v %'),
                  selected: (p.tolerance * 100).round() == v,
                  onSelected: (_) => Navigator.pop(context, v),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
  if (percent != null) await p.setTolerance(percent / 100);
}

/// Открыть выдачу [batchId] (поверх раздела, с тем же OrdersProvider).
Future<void> openBatch(BuildContext context, String batchId) {
  final p = context.read<OrdersProvider>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: BatchScreen(batchId: batchId),
      ),
    ),
  );
}

enum _Print { packages, labels, tags, route }

class BatchScreen extends StatelessWidget {
  final String batchId;
  const BatchScreen({super.key, required this.batchId});

  Future<void> _edit(BuildContext context, OrdersProvider p, SaleBatch b) =>
      showAppDialog<void>(
        context: context,
        builder: (_) =>
            ChangeNotifierProvider.value(value: p, child: _BatchEditDialog(b)),
      );

  Future<void> _issue(BuildContext context, OrdersProvider p) async {
    final s = p.summaryOf(batchId);
    final n = s.byStatus[OrderStatus.assembled] ?? 0;
    if (n == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Собранных заказов нет')));
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Выдать собранные?'),
        content: Text('Заказов «Собран»: $n — станут «Выдан».'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выдать'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await p.issueAssembled(batchId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Выдано заказов: $done')));
    }
  }

  Future<void> _print(
    BuildContext context,
    OrdersProvider p,
    SaleBatch b,
    _Print what,
  ) async {
    final data = batchPrintData(p, b);
    try {
      switch (what) {
        case _Print.packages:
          await PrintService.printBatchPackages(data);
        case _Print.labels:
          await PrintService.printBatchLabels(data);
        case _Print.tags:
          await PrintService.printBatchTags(data);
        case _Print.route:
          await PrintService.printBatchRoute(data);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не напечатано: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final b = p.batch(batchId);
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Выдача не найдена')),
      );
    }
    final s = p.summaryOf(batchId);
    final wide = isWideScreen(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(batchTitle(b)),
        actions: [
          if (p.canEdit)
            IconButton(
              tooltip: 'Название и примечание',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, p, b),
            ),
          PopupMenuButton<_Print>(
            tooltip: 'Печать',
            icon: const Icon(Icons.print_outlined),
            onSelected: (w) => _print(context, p, b, w),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Print.packages,
                child: Text('Список пакетов'),
              ),
              PopupMenuItem(
                value: _Print.labels,
                child: Text('Этикетки 70×50 (принтер этикеток)'),
              ),
              PopupMenuItem(
                value: _Print.tags,
                child: Text('Бирки на листе А4'),
              ),
              PopupMenuItem(
                value: _Print.route,
                child: Text('Маршрут доставки'),
              ),
            ],
          ),
          if (p.canEdit)
            IconButton(
              tooltip: 'Выдать собранные',
              icon: const Icon(Icons.done_all),
              onPressed: () => _issue(context, p),
            ),
        ],
      ),
      floatingActionButton: p.canEdit && s.toWeigh > 0
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => openWeighing(context, batchId),
              icon: const Icon(Icons.scale_outlined),
              label: Text(s.open == 0 ? 'Весы' : 'Взвешивать (${s.open})'),
            )
          : null,
      // Сборочный лист, под ним — итог выдачи.
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1300 : 860),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              _PickList(batchId),
              const Divider(height: 32),
              _SummaryView(batchId),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- сборочный лист

/// Как сгруппирован сборочный лист.
enum PickGrouping {
  product('По товарам'),
  customer('По покупателям');

  final String title;
  const PickGrouping(this.title);
}

/// Группа сборочного листа: товар (все его строки) или заказ покупателя.
class _PickGroup {
  final String key;
  final String title;
  final String subtitle;
  final List<BatchEntry> entries;
  const _PickGroup(this.key, this.title, this.subtitle, this.entries);
}

/// Сборочный лист выдачи: по товарам или по покупателям; группы и наборы
/// сворачиваются. На компьютере — таблица, на телефоне — карточки.
class _PickList extends StatefulWidget {
  final String batchId;
  const _PickList(this.batchId);

  @override
  State<_PickList> createState() => _PickListState();
}

class _PickListState extends State<_PickList> {
  PickGrouping _grouping = PickGrouping.product;

  /// Свёрнутые группы и наборы (ключ группы или id строки набора).
  final _collapsed = <String>{};

  List<_PickGroup> _groups(OrdersProvider p, ThemeData theme) {
    if (_grouping == PickGrouping.product) {
      return [
        for (final i in p.pickListOf(widget.batchId))
          _PickGroup(
            'p:${i.productId}',
            p.products[i.productId]?.name ?? 'Товар не найден',
            _productSubtitle(p, i),
            i.entries,
          ),
      ];
    }
    final byOrder = <String, List<BatchEntry>>{};
    for (final e in p.entriesOf(widget.batchId)) {
      if (!e.isPart) (byOrder[e.order.id] ??= []).add(e);
    }
    return [
      for (final o in p.liveOrdersOf(widget.batchId))
        if (byOrder[o.id] case final entries?)
          _orderGroup(p, theme, o, entries),
    ];
  }

  static String _productSubtitle(OrdersProvider p, PickItem i) {
    final fact = [
      if (i.factKg > 0) kg(i.factKg),
      if (i.factPcs > 0) '${i.factPcs} шт',
    ].join(' + ');
    final composition = [
      for (final c in setComposition(i))
        '${p.products[c.productId]?.name ?? '?'} ×${c.count}'
            '${c.weight > 0 ? ' (${kg(c.weight)})' : ''}',
    ];
    return [
      'заказов: ${i.entries.length}',
      'заказано: ${pickOrdered(i).ifEmpty('—')}',
      if (fact.isNotEmpty) 'выдано: $fact',
      if (i.open > 0) 'осталось: ${i.open}',
      if (i.missing > 0) 'не хватило: ${i.missing}',
      if (composition.isNotEmpty) 'состав: ${composition.join(', ')}',
    ].join(' · ');
  }

  _PickGroup _orderGroup(
    OrdersProvider p,
    ThemeData theme,
    SaleOrder o,
    List<BatchEntry> entries,
  ) {
    final customer = p.customers[o.customerId];
    final totals = p.totals(o.id);
    final open = entries
        .expand((e) => e.isSet ? e.parts : [e.line])
        .where((l) => l.state == LineState.open)
        .length;
    final address = o.delivery == Delivery.delivery
        ? (o.address ?? customer?.address)
        : null;
    return _PickGroup(
      'o:${o.id}',
      '${p.label(o)} · ${customer?.name ?? '?'}',
      [
        o.status.title,
        if (o.delivery == Delivery.delivery)
          'доставка${address == null ? '' : ': $address'}',
        if (o.kind != OrderKind.sale) o.kind.title,
        if (open > 0) 'не взвешено строк: $open',
        '${totals.complete ? '' : '≈ '}${rub(totals.due)}',
        if ((o.comment ?? '').trim().isNotEmpty) o.comment!.trim(),
      ].join(' · '),
      entries,
    );
  }

  void _toggle(String key) => setState(() {
    if (!_collapsed.remove(key)) _collapsed.add(key);
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final wide = isWideScreen(context);
    final groups = _groups(p, theme);
    final setKeys = [
      for (final g in groups)
        for (final e in g.entries)
          if (e.isSet) e.line.id,
    ];
    final allKeys = [for (final g in groups) g.key, ...setKeys];
    final anyOpen = allKeys.any((k) => !_collapsed.contains(k));
    final byProduct = _grouping == PickGrouping.product;
    final cols = byProduct ? _byProductCols : _byCustomerCols;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Сборочный лист', style: theme.textTheme.titleLarge),
              SegmentedButton<PickGrouping>(
                showSelectedIcon: false,
                segments: [
                  for (final g in PickGrouping.values)
                    ButtonSegment(value: g, label: Text(g.title)),
                ],
                selected: {_grouping},
                onSelectionChanged: (s) => setState(() => _grouping = s.first),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  if (anyOpen) {
                    _collapsed.addAll(allKeys);
                  } else {
                    _collapsed.clear();
                  }
                }),
                icon: Icon(anyOpen ? Icons.unfold_less : Icons.unfold_more),
                label: Text(anyOpen ? 'Свернуть всё' : 'Развернуть всё'),
              ),
            ],
          ),
        ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Заказов в выдаче нет')),
          ),
        if (wide && groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RowTableHeader(cols),
          ),
        for (final g in groups)
          Padding(
            padding: wide
                ? const EdgeInsets.symmetric(horizontal: 12)
                : const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _GroupView(
              group: g,
              wide: wide,
              byProduct: byProduct,
              collapsed: _collapsed,
              onToggle: _toggle,
            ),
          ),
      ],
    );
  }
}

const _byProductCols = [
  RowCol('', width: 32),
  RowCol('№', width: 80),
  RowCol('Покупатель', flex: 3),
  RowCol('Заказано', flex: 3),
  RowCol('Фактически', width: 120, right: true),
  RowCol('Примечание', flex: 2),
  RowCol('', width: 48),
];

const _byCustomerCols = [
  RowCol('', width: 32),
  RowCol('Товар', flex: 4),
  RowCol('Заказано', flex: 3),
  RowCol('Фактически', width: 120, right: true),
  RowCol('Примечание', flex: 2),
  RowCol('', width: 48),
];

/// Заказано товара — для заголовка: «12 кг + 3 шт + на 1 500 ₽ + 2 без
/// количества».
String pickOrdered(PickItem i) => [
  if (i.orderedKg > 0) kg(i.orderedKg),
  if (i.orderedPcs > 0) '${i.orderedPcs} шт',
  if (i.orderedRub > 0) 'на ${rub(i.orderedRub)}',
  if (i.orderedText > 0) '${i.orderedText} без количества',
].join(' + ');

/// Группа: заголовок (нажатие — свернуть) и строки.
class _GroupView extends StatelessWidget {
  final _PickGroup group;
  final bool wide;
  final bool byProduct;
  final Set<String> collapsed;
  final void Function(String key) onToggle;
  const _GroupView({
    required this.group,
    required this.wide,
    required this.byProduct,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = !collapsed.contains(group.key);
    final header = InkWell(
      onTap: () => onToggle(group.key),
      child: Container(
        color: wide ? theme.colorScheme.surfaceContainerHigh : null,
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(open ? Icons.expand_more : Icons.chevron_right),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title, style: theme.textTheme.titleMedium),
                  Text(group.subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final rows = [
      for (final e in group.entries) ...[
        if (wide)
          _EntryRow(
            e,
            byProduct: byProduct,
            collapsed: e.isSet && collapsed.contains(e.line.id),
            onToggle: e.isSet ? () => onToggle(e.line.id) : null,
          )
        else
          _EntryTile(
            e,
            byProduct: byProduct,
            collapsed: e.isSet && collapsed.contains(e.line.id),
            onToggle: e.isSet ? () => onToggle(e.line.id) : null,
          ),
        if (e.isSet && !collapsed.contains(e.line.id))
          for (final part in e.parts)
            if (wide)
              _EntryRow(
                BatchEntry(order: e.order, line: part, parent: e.line),
                byProduct: byProduct,
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: _EntryTile(
                  BatchEntry(order: e.order, line: part, parent: e.line),
                  byProduct: byProduct,
                ),
              ),
      ],
    ];
    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, if (open) ...rows],
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, if (open) ...rows],
      ),
    );
  }
}

(IconData, Color) _stateIcon(
  ThemeData theme,
  LineState state,
) => switch (state) {
  LineState.open => (Icons.radio_button_unchecked, theme.colorScheme.outline),
  LineState.assembled => (Icons.check_circle, theme.colorScheme.primary),
  LineState.missing => (Icons.remove_circle_outline, theme.colorScheme.error),
};

/// Что показать о строке выдачи — одинаково для таблицы и карточки.
class _EntryInfo {
  final String who;
  final String product;
  final String ordered;
  final String fact;
  final String note;
  final bool off;
  final Color? noteColor;
  const _EntryInfo({
    required this.who,
    required this.product,
    required this.ordered,
    required this.fact,
    required this.note,
    required this.off,
    this.noteColor,
  });

  factory _EntryInfo.of(OrdersProvider p, ThemeData theme, BatchEntry e) {
    final l = e.line;
    final product = p.products[l.productId];
    final name = product?.name ?? '?';
    if (e.isSet) {
      final progress = setProgress(l, e.parts, p.products);
      return _EntryInfo(
        who:
            '${p.label(e.order)} · ${p.customers[e.order.customerId]?.name ?? '?'}',
        product: '$name (набор, частей: ${e.parts.length})',
        ordered: orderedText(l),
        fact: factText(l, product, e.parts),
        note: setProgressText(progress),
        off: progress.off(p.tolerance),
        noteColor: progress.off(p.tolerance)
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      );
    }
    return _EntryInfo(
      who:
          '${p.label(e.order)} · ${p.customers[e.order.customerId]?.name ?? '?'}',
      product: e.isPart ? '— $name' : name,
      ordered: orderedText(l),
      fact: factText(l, product, e.parts),
      note: [
        if (!e.isPart && e.order.kind != OrderKind.sale) e.order.kind.title,
        if (l.state == LineState.missing && (l.note ?? '').isNotEmpty) l.note!,
      ].join(' · '),
      off: !e.isPart && weightOff(l, parts: e.parts, tolerance: p.tolerance),
    );
  }
}

/// Нажатие на строку: набор — открыть заказ, иначе — взвесить.
Future<void> _openEntry(BuildContext context, OrdersProvider p, BatchEntry e) =>
    e.isSet || !p.canEdit
    ? openOrderEditor(context, order: e.order)
    : openWeighing(context, e.order.batchId, start: e.line.id);

/// Строка выдачи таблицей (компьютер).
class _EntryRow extends StatelessWidget {
  final BatchEntry entry;
  final bool byProduct;
  final bool collapsed;
  final VoidCallback? onToggle;
  const _EntryRow(
    this.entry, {
    required this.byProduct,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final e = entry;
    final info = _EntryInfo.of(p, theme, e);
    final (icon, color) = _stateIcon(theme, e.line.state);
    final missing = e.line.state == LineState.missing;
    final lead = onToggle != null
        ? InkWell(
            onTap: onToggle,
            child: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
          )
        : Icon(icon, color: color, size: 20);
    final fact = CellText(
      info.fact,
      right: true,
      bold: true,
      color: info.off ? theme.colorScheme.error : null,
    );
    final note = CellText(info.note, color: info.noteColor, maxLines: 2);
    final menu = p.canEdit ? _EntryMenu(e) : const SizedBox(height: 36);
    final cells = byProduct
        ? <Widget>[
            lead,
            if (e.isPart)
              const SizedBox.shrink()
            else
              CellText(p.label(e.order), bold: true, muted: missing),
            CellText(
              e.isPart
                  ? info.product
                  : [
                      p.customers[e.order.customerId]?.name ?? '?',
                      if (e.isSet) '— ${info.product}',
                    ].join(' '),
              muted: missing,
            ),
            CellText(info.ordered.ifEmpty(e.isPart ? '' : '—')),
            fact,
            note,
            menu,
          ]
        : <Widget>[
            lead,
            CellText(info.product, bold: !e.isPart, muted: missing),
            CellText(info.ordered.ifEmpty(e.isPart ? '' : '—')),
            fact,
            note,
            menu,
          ];
    // Текст — на одной линии с кнопкой меню.
    Widget pad(Widget w) => w is _EntryMenu || w is SizedBox
        ? w
        : Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: w);
    return RowTableRow(
      cols: byProduct ? _byProductCols : _byCustomerCols,
      cells: [for (final c in cells) pad(c)],
      indent: e.isPart ? 24 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      onTap: () => _openEntry(context, p, e),
    );
  }
}

/// Строка выдачи карточкой (телефон).
class _EntryTile extends StatelessWidget {
  final BatchEntry entry;
  final bool byProduct;
  final bool collapsed;
  final VoidCallback? onToggle;
  const _EntryTile(
    this.entry, {
    required this.byProduct,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final e = entry;
    final info = _EntryInfo.of(p, theme, e);
    final (icon, color) = _stateIcon(theme, e.line.state);
    final title = e.isPart
        ? info.product
        : byProduct
        ? info.who
        : info.product;
    return ListTile(
      dense: true,
      leading: onToggle != null
          ? IconButton(
              tooltip: collapsed ? 'Показать части' : 'Скрыть части',
              icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
              onPressed: onToggle,
            )
          : Icon(icon, color: color),
      title: Text(byProduct && e.isSet ? '$title — ${info.product}' : title),
      subtitle: Text(
        [
          if (info.ordered.isNotEmpty) info.ordered,
          if (info.note.isNotEmpty) info.note,
        ].join(' · '),
        style: info.noteColor == null ? null : TextStyle(color: info.noteColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.fact.isNotEmpty)
            Text(
              info.fact,
              style: theme.textTheme.titleSmall?.copyWith(
                color: info.off ? theme.colorScheme.error : null,
              ),
            ),
          if (p.canEdit) _EntryMenu(e),
        ],
      ),
      onTap: () => _openEntry(context, p, e),
    );
  }
}

/// Меню строки выдачи: взвесить, снять, вернуть, открыть заказ.
class _EntryMenu extends StatelessWidget {
  final BatchEntry entry;
  const _EntryMenu(this.entry);

  @override
  Widget build(BuildContext context) {
    final p = context.read<OrdersProvider>();
    final l = entry.line;
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      onSelected: (a) async {
        switch (a) {
          case 'weigh':
            await openWeighing(context, entry.order.batchId, start: l.id);
          case 'missing':
            final note = await askMissingReason(context, l.note);
            if (note == null) return;
            await p.markMissing(l, note.isEmpty ? null : note);
          case 'reopen':
            await p.reopenLine(l);
          case 'order':
            if (context.mounted) {
              await openOrderEditor(context, order: entry.order);
            }
        }
      },
      itemBuilder: (_) => [
        if (!entry.isSet)
          const PopupMenuItem(value: 'weigh', child: Text('Взвесить')),
        if (l.state != LineState.missing)
          const PopupMenuItem(
            value: 'missing',
            child: Text('Не хватило — снять'),
          )
        else
          const PopupMenuItem(value: 'reopen', child: Text('Вернуть к сборке')),
        const PopupMenuItem(
          value: 'order',
          child: Text('Открыть заказ (состав, замена товара)'),
        ),
      ],
    );
  }
}

/// Спросить причину снятия строки; null — отмена, '' — без причины.
Future<String?> askMissingReason(BuildContext context, String? current) =>
    showAppDialog<String>(
      context: context,
      builder: (_) => _MissingReasonDialog(current ?? 'не хватило'),
    );

class _MissingReasonDialog extends StatefulWidget {
  final String initial;
  const _MissingReasonDialog(this.initial);

  @override
  State<_MissingReasonDialog> createState() => _MissingReasonDialogState();
}

class _MissingReasonDialogState extends State<_MissingReasonDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: const Text('Не выдавать строку'),
    content: TextField(
      controller: _c,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Причина',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (v) => Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _c.text.trim()),
        child: const Text('Снять'),
      ),
    ],
  );
}

// ------------------------------------------------------------------ итог

class _SummaryView extends StatelessWidget {
  final String batchId;
  const _SummaryView(this.batchId);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final s = p.summaryOf(batchId);
    final items = p.pickListOf(batchId);
    final b = p.batch(batchId);
    var paid = 0, debt = 0;
    for (final o in p.liveOrdersOf(batchId)) {
      final pay = p.paymentOf(o);
      paid += pay.paid;
      if (p.owes(o)) debt += pay.left;
    }
    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
    // Цифры — рядом с подписями, не у дальнего края широкого окна.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Итог выдачи', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if ((b?.notes ?? '').trim().isNotEmpty) ...[
              Text(b!.notes!.trim(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            row('Заказов', '${s.orders}'),
            for (final st in OrderStatus.values)
              if ((s.byStatus[st] ?? 0) > 0)
                row('   ${st.title}', '${s.byStatus[st]}'),
            row('Взвешено строк', '${s.toWeigh - s.open} из ${s.toWeigh}'),
            row('Заказано', kg(s.orderedKg)),
            row('Выдано', kg(s.factKg)),
            if (s.freeKg > 0) row('   из них без оплаты и себе', kg(s.freeKg)),
            row(
              s.final_ ? 'К оплате' : 'К оплате (предварительно)',
              '${s.final_ ? '' : '≈ '}${rub(s.due)}',
            ),
            // Оплата (11.6): получено по заказам выдачи и долг по собранным
            // и выданным.
            row('Оплачено', rub(paid)),
            if (debt > 0)
              row(
                'Долг по собранным и выданным',
                rub(debt),
                color: theme.colorScheme.error,
              ),
            if (s.missing > 0)
              row(
                'Не выдано строк',
                '${s.missing}',
                color: theme.colorScheme.error,
              ),
            const SizedBox(height: 16),
            Text('Итог по товарам', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    for (final h in ['Товар', 'Заказано', 'Выдано', 'Нет'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(h, style: theme.textTheme.labelMedium),
                      ),
                  ],
                ),
                for (final i in items)
                  TableRow(
                    children: [
                      _cell(p.products[i.productId]?.name ?? '?'),
                      _cell(pickOrdered(i).ifEmpty('—')),
                      _cell(
                        [
                          if (i.factKg > 0) kg(i.factKg),
                          if (i.factPcs > 0) '${i.factPcs} шт',
                        ].join(' + ').ifEmpty(i.open > 0 ? '…' : '—'),
                      ),
                      _cell(i.missing > 0 ? '${i.missing}' : ''),
                    ],
                  ),
              ],
            ),
            if (s.shortages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Кому не хватило', style: theme.textTheme.titleMedium),
              for (final e in s.shortages)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    '${p.label(e.order)} · '
                    '${p.customers[e.order.customerId]?.name ?? '?'}',
                  ),
                  subtitle: Text(
                    [
                      p.products[e.line.productId]?.name ?? '?',
                      orderedText(e.line),
                      ?e.line.note,
                    ].where((x) => x.isNotEmpty).join(' · '),
                  ),
                  onTap: () => openOrderEditor(context, order: e.order),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _cell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(text),
  );
}

// ------------------------------------------------------- правка выдачи

class _BatchEditDialog extends StatefulWidget {
  final SaleBatch batch;
  const _BatchEditDialog(this.batch);

  @override
  State<_BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<_BatchEditDialog> {
  late final _title = TextEditingController(text: widget.batch.title ?? '');
  late final _notes = TextEditingController(text: widget.batch.notes ?? '');
  late DateTime? _dayTo = widget.batch.dayTo;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final p = context.read<OrdersProvider>();
    final ok = await p.saveBatch(
      widget.batch.copyWith(
        title: () => _opt(_title),
        notes: () => _opt(_notes),
        dayTo: () => _dayTo,
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    return AppDialog(
      title: Text('Выдача ${_shortDate.format(b.day)}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Название (например, «бычок Борька»)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dayTo == null
                        ? 'Один день'
                        : 'По ${_shortDate.format(_dayTo!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dayTo ?? b.day,
                      firstDate: b.day,
                      lastDate: addCalendarDays(b.day, 30),
                      helpText: 'Последний день выдачи',
                    );
                    if (d != null) {
                      setState(() => _dayTo = d == b.day ? null : d);
                    }
                  },
                  child: const Text('Несколько дней…'),
                ),
                if (_dayTo != null)
                  IconButton(
                    tooltip: 'Один день',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _dayTo = null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
