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
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
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

enum _Print { packages, tags, route }

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                  value: _Print.tags,
                  child: Text('Бирки на пакеты'),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Сборка'),
              Tab(text: 'Итог'),
            ],
          ),
        ),
        floatingActionButton: p.canEdit && s.toWeigh > 0
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => openWeighing(context, batchId),
                icon: const Icon(Icons.scale_outlined),
                label: Text(s.open == 0 ? 'Весы' : 'Взвешивать (${s.open})'),
              )
            : null,
        body: TabBarView(
          children: [_PickListView(batchId), _SummaryView(batchId)],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- сборочный лист

class _PickListView extends StatelessWidget {
  final String batchId;
  const _PickListView(this.batchId);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final items = p.pickListOf(batchId);
    if (items.isEmpty) {
      return const Center(child: Text('Заказов в выдаче нет'));
    }
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [for (final i in items) _PickItemCard(i)],
        ),
      ),
    );
  }
}

/// Заказано товара — для заголовка: «12 кг + 3 шт + на 1 500 ₽ + 2 без
/// количества».
String pickOrdered(PickItem i) => [
  if (i.orderedKg > 0) kg(i.orderedKg),
  if (i.orderedPcs > 0) '${i.orderedPcs} шт',
  if (i.orderedRub > 0) 'на ${rub(i.orderedRub)}',
  if (i.orderedText > 0) '${i.orderedText} без количества',
].join(' + ');

class _PickItemCard extends StatelessWidget {
  final PickItem item;
  const _PickItemCard(this.item);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final product = p.products[item.productId];
    final fact = [
      if (item.factKg > 0) kg(item.factKg),
      if (item.factPcs > 0) '${item.factPcs} шт',
    ].join(' + ');
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                product?.name ?? 'Товар не найден',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text(
                [
                  'заказано: ${pickOrdered(item).ifEmpty('—')}',
                  if (fact.isNotEmpty) 'выдано: $fact',
                  if (item.open > 0) 'осталось строк: ${item.open}',
                  if (item.missing > 0) 'не хватило: ${item.missing}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final e in item.entries) _EntryTile(e),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final BatchEntry entry;
  const _EntryTile(this.entry);

  Future<void> _missing(BuildContext context, OrdersProvider p) async {
    final note = await askMissingReason(context, entry.line.note);
    if (note == null) return;
    await p.markMissing(entry.line, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final l = entry.line;
    final customer = p.customers[entry.order.customerId];
    final product = p.products[l.productId];
    final ordered = orderedText(l);
    final fact = factText(l, product, entry.parts);
    final off =
        !entry.isPart &&
        weightOff(l, parts: entry.parts, tolerance: p.tolerance);
    final (icon, color) = switch (l.state) {
      LineState.open => (
        Icons.radio_button_unchecked,
        theme.colorScheme.outline,
      ),
      LineState.assembled => (Icons.check_circle, theme.colorScheme.primary),
      LineState.missing => (
        Icons.remove_circle_outline,
        theme.colorScheme.error,
      ),
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text('${p.label(entry.order)} · ${customer?.name ?? '?'}'),
      subtitle: Text(
        [
          if (entry.isPart)
            'в наборе «${p.products[entry.parent!.productId]?.name ?? '?'}»',
          if (entry.isSet) 'набор из ${entry.parts.length} частей',
          if (ordered.isNotEmpty) ordered,
          if (entry.order.kind != OrderKind.sale) entry.order.kind.title,
          if (l.state == LineState.missing && (l.note ?? '').isNotEmpty)
            l.note!,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fact.isNotEmpty)
            Text(
              fact,
              style: theme.textTheme.titleSmall?.copyWith(
                color: off ? theme.colorScheme.error : null,
              ),
            ),
          if (p.canEdit)
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (a) async {
                switch (a) {
                  case 'weigh':
                    await openWeighing(
                      context,
                      entry.order.batchId,
                      start: l.id,
                    );
                  case 'missing':
                    await _missing(context, p);
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
                  const PopupMenuItem(
                    value: 'reopen',
                    child: Text('Вернуть к сборке'),
                  ),
                const PopupMenuItem(
                  value: 'order',
                  child: Text('Открыть заказ (заменить товар)'),
                ),
              ],
            ),
        ],
      ),
      onTap: entry.isSet || !p.canEdit
          ? () => openOrderEditor(context, order: entry.order)
          : () => openWeighing(context, entry.order.batchId, start: l.id),
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
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
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
            if (s.missing > 0)
              row(
                'Не выдано строк',
                '${s.missing}',
                color: theme.colorScheme.error,
              ),
            const SizedBox(height: 16),
            Text('По товарам', style: theme.textTheme.titleMedium),
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
