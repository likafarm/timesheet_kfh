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
          final all = batch == null ? <SaleOrder>[] : p.ordersOf(batch.id);
          final matched = q.isEmpty
              ? null
              : {for (final c in searchCustomers(p.customers.values, q)) c.id};
          final list = [
            for (final o in all)
              if ((_status == null || o.status == _status) &&
                  (matched == null || matched.contains(o.customerId)))
                o,
          ];
          final sum = list
              .where((o) => o.status != OrderStatus.cancelled)
              .fold<int>(0, (s, o) => s + p.totals(o.id).due);
          return Scaffold(
            appBar: AppBar(title: const Text('Заказы')),
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
                            child: p.batches.isEmpty
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
                                  selected: _status == null,
                                  onSelected: (_) =>
                                      setState(() => _status = null),
                                ),
                                for (final s in OrderStatus.values)
                                  ChoiceChip(
                                    label: Text(s.title),
                                    selected: _status == s,
                                    onSelected: (_) =>
                                        setState(() => _status = s),
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
                                'Заказов: ${list.length}, на сумму ≈ '
                                '${rub(sum)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          if (batch != null && list.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('Заказов нет')),
                            ),
                          for (final o in list) _OrderTile(o),
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
          Text(order.status.title, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
