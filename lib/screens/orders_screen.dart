// lib/screens/orders_screen.dart
//
// «Продажи → Заказы» (этап 11.4): заказы выдачи (по умолчанию —
// ближайшей) по номеру: покупатель, что заказано, сумма (≈ — пока
// предварительная), состояние. Отбор по состоянию и поиск по покупателю.
// «Повторить заказ» — в карточке заказа. Выдачи и сборка — шаг 11.5,
// оплата — 11.6.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/orders_provider.dart';
import 'history_import_screen.dart';
import 'order_editor_screen.dart';

final _date = DateFormat('dd.MM.yyyy, EEE', 'ru');

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersProvider _orders = OrdersProvider(
    context.read<AppProvider>(),
  )..load();
  String? _batchId;
  OrderStatus? _status;

  /// «Долги»: собранные и выданные заказы с недоплатой — по всем выдачам.
  bool _debts = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _orders.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _orders,
      child: Consumer<OrdersProvider>(
        builder: (context, p, _) {
          final batch =
              (_batchId == null ? null : p.batch(_batchId!)) ?? p.nearestBatch;
          final q = _query.text.trim();
          // «Принят» — все невыданные заказы, по всем выдачам (в том числе
          // прошедшим): иначе принятый, но забытый заказ не найти.
          final allBatches = _debts || _status == OrderStatus.accepted;
          final all = _debts
              ? p.debtOrders
              : allBatches
              ? p.acceptedOrders
              : batch == null
              ? <SaleOrder>[]
              : p.ordersOf(batch.id);
          final matched = q.isEmpty
              ? null
              : {for (final c in searchCustomers(p.customers.values, q)) c.id};
          final list = [
            for (final o in all)
              if ((_debts || _status == null || o.status == _status) &&
                  (matched == null || matched.contains(o.customerId)))
                o,
          ];
          final sum = _debts
              ? list.fold<int>(0, (s, o) => s + p.paymentOf(o).left)
              : list
                    .where((o) => o.status != OrderStatus.cancelled)
                    .fold<int>(0, (s, o) => s + p.totals(o.id).due);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Заказы'),
              actions: [
                if (p.canImportHistory && p.loaded)
                  IconButton(
                    tooltip: 'Перенести историю из Excel',
                    icon: const Icon(Icons.history_edu),
                    onPressed: () => openHistoryImport(context),
                  ),
              ],
            ),
            floatingActionButton: p.canEdit && p.loaded
                ? FloatingActionButton.extended(
                    // Пункты меню живут рядом (IndexedStack) — без общего героя.
                    heroTag: null,
                    onPressed: () => openOrderEditor(context, day: batch?.day),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Заказ'),
                  )
                : null,
            body: !p.loaded
                ? const Center(child: CircularProgressIndicator())
                : Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: allBatches
                                ? Text(
                                    _debts
                                        ? 'Недоплаченные заказы всех выдач'
                                        : 'Принятые заказы всех выдач',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  )
                                : p.batches.isEmpty
                                ? const Text(
                                    'Выдач пока нет — первый заказ создаст '
                                    'выдачу на выбранный день',
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: batch?.id,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Выдача',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: [
                                      for (final b in p.batches)
                                        DropdownMenuItem(
                                          value: b.id,
                                          child: Text(
                                            '${_date.format(b.day)} · '
                                            'заказов: ${p.ordersOf(b.id).length}',
                                          ),
                                        ),
                                    ],
                                    onChanged: (id) =>
                                        setState(() => _batchId = id),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ChoiceChip(
                                  label: const Text('Все'),
                                  selected: !_debts && _status == null,
                                  onSelected: (_) => setState(() {
                                    _status = null;
                                    _debts = false;
                                  }),
                                ),
                                for (final s in OrderStatus.values)
                                  ChoiceChip(
                                    label: Text(s.title),
                                    selected: !_debts && _status == s,
                                    onSelected: (_) => setState(() {
                                      _status = s;
                                      _debts = false;
                                    }),
                                  ),
                                ChoiceChip(
                                  label: const Text('Долги'),
                                  selected: _debts,
                                  onSelected: (_) => setState(() {
                                    _debts = true;
                                    _status = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: TextField(
                              controller: _query,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Покупатель: имя, ник, телефон',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          if (list.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Text(
                                _debts
                                    ? 'Заказов: ${list.length}, долг '
                                          '${rub(sum)}'
                                    : 'Заказов: ${list.length}, на сумму ≈ '
                                          '${rub(sum)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          if ((batch != null || allBatches) && list.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('Заказов нет')),
                            ),
                          for (var i = 0; i < list.length; i++) ...[
                            if (allBatches &&
                                (i == 0 ||
                                    list[i].batchId != list[i - 1].batchId))
                              _BatchHeader(p.batch(list[i].batchId)),
                            _OrderTile(list[i]),
                          ],
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

/// Заголовок выдачи в списке по всем выдачам; прошедшая — с пометкой.
class _BatchHeader extends StatelessWidget {
  final SaleBatch? batch;
  const _BatchHeader(this.batch);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = batch;
    final past =
        b != null && calendarDay(b.day).isBefore(calendarDay(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        b == null
            ? 'Выдача не найдена'
            : 'Выдача ${_date.format(b.day)}${past ? ' — прошла' : ''}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: past ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final SaleOrder order;
  const _OrderTile(this.order);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final customer = p.customers[order.customerId];
    final totals = p.totals(order.id);
    final (:top, :parts) = orderLines(p.linesOf(order.id), order.id);
    final cancelled = order.status == OrderStatus.cancelled;
    return ListTile(
      onTap: () => openOrderEditor(context, order: order),
      leading: CircleAvatar(
        radius: 22,
        child: Text(
          p.label(order),
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(
        [
          customer?.name ?? 'Покупатель удалён',
          if (order.delivery == Delivery.delivery) '· доставка',
          if (order.kind != OrderKind.sale)
            '· ${order.kind.title.toLowerCase()}',
        ].join(' '),
        style: cancelled
            ? TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: Text(
        [
          for (final l in top)
            [
              p.products[l.productId]?.name ?? '?',
              orderedText(l),
              if (factText(l, p.products[l.productId], parts[l.id] ?? const [])
                  case final f when f.isNotEmpty)
                '→ $f',
            ].where((s) => s.isNotEmpty).join(' '),
        ].join('; '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${totals.complete ? '' : '≈ '}${rub(totals.due)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            [order.status.title, ?_payText(p.paymentOf(order))].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: switch (p.paymentOf(order).state) {
                PaymentState.unpaid || PaymentState.partial
                    when p.owes(order) =>
                  theme.colorScheme.error,
                _ => null,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Оплата заказа одной строкой для списка; null — нечего сказать.
String? _payText(OrderPayment pay) => switch (pay.state) {
  PaymentState.none => null,
  PaymentState.unpaid => 'не оплачен',
  PaymentState.partial => 'долг ${rub(pay.left)}',
  PaymentState.paid => 'оплачен',
  PaymentState.history => 'оплачен до программы',
  PaymentState.overpaid => 'переплата ${rub(-pay.left)}',
};
