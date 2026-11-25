// lib/screens/order_editor_screen.dart
//
// Карточка заказа (этап 11.4): покупатель (поиск или новый), день выдачи
// (по нему — номер `ДДМ-N` и цены прайса), вид и доставка, строки. Строка
// — товар прайса, «заказано» (кг, шт или на сумму, и что просили
// словами) и «фактически» (вес или штуки), состояние при сборке; набор —
// с частями и ценой на выбор. Внизу — предварительная сумма и сумма к
// оплате по факту.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';

final _date = DateFormat('dd.MM.yyyy');

String rub(int kopecks) => '${formatPrice(kopecks)} ₽';

/// Число из поля: «2,5», «2.5»; пусто или не число — null.
double? _num(String text) {
  final t = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

String fmtQty(double? v) {
  if (v == null) return '';
  final s = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

/// Что заказано — для человека: «2 кг», «на 5 000 ₽», «4–5 шт».
String orderedText(SaleOrderLine l) => [
  if (l.orderedQty != null)
    l.orderedUnit == OrderedUnit.rub
        ? 'на ${rub((l.orderedQty! * 100).round())}'
        : '${fmtQty(l.orderedQty)} ${l.orderedUnit?.title ?? ''}'.trim(),
  ?l.orderedText,
].join(' · ');

/// Факт — для человека: «2,6 кг», «1 шт».
String factText(SaleOrderLine l, Product? p, List<SaleOrderLine> parts) {
  if (l.state == LineState.missing) return 'не выдана';
  final qty = factQty(l, p, parts: parts);
  if (qty == null) return '';
  final kg = parts.isNotEmpty || (p?.unit ?? ProductUnit.kg) == ProductUnit.kg;
  return '${fmtQty(qty)} ${kg ? 'кг' : p!.unit.title}';
}

/// Открыть карточку заказа: [order] — правка, null — новый (на выдачу
/// [day] покупателю [customerId], если заданы; [repeatOf] — заказ, строки
/// которого повторить).
Future<void> openOrderEditor(
  BuildContext context, {
  SaleOrder? order,
  DateTime? day,
  String? customerId,
  SaleOrder? repeatOf,
}) {
  final p = context.read<OrdersProvider>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: OrderEditorScreen(
          order: order,
          day: day,
          customerId: customerId,
          repeatOf: repeatOf,
        ),
      ),
    ),
  );
}

class OrderEditorScreen extends StatefulWidget {
  final SaleOrder? order;
  final DateTime? day;
  final String? customerId;
  final SaleOrder? repeatOf;

  const OrderEditorScreen({
    super.key,
    this.order,
    this.day,
    this.customerId,
    this.repeatOf,
  });

  @override
  State<OrderEditorScreen> createState() => _OrderEditorScreenState();
}

class _OrderEditorScreenState extends State<OrderEditorScreen> {
  OrdersProvider get _p => context.read<OrdersProvider>();

  late SaleBatch _batch;
  late SaleOrder _order;
  late List<SaleOrderLine> _lines;
  final _comment = TextEditingController();
  final _address = TextEditingController();
  final _number = TextEditingController();
  String? _problem;
  bool _saving = false;

  bool get _isNew => widget.order == null;

  @override
  void initState() {
    super.initState();
    final p = _p;
    final existing = widget.order;
    if (existing != null) {
      _batch = p.batch(existing.batchId) ?? p.batchFor(DateTime.now());
      _order = existing;
      _lines = p.linesOf(existing.id);
    } else {
      _batch = p.batchFor(widget.day ?? p.nearestBatch?.day ?? DateTime.now());
      _order = p.draft(_batch, widget.customerId ?? '');
      _lines = widget.repeatOf == null
          ? []
          : p.repeatLines(widget.repeatOf!.id, _order.id, _batch.day);
    }
    _comment.text = _order.comment ?? '';
    _address.text = _order.address ?? '';
    _number.text = '${_order.number}';
  }

  @override
  void dispose() {
    _comment.dispose();
    _address.dispose();
    _number.dispose();
    super.dispose();
  }

  Customer? get _customer => _p.customers[_order.customerId];

  List<SaleOrderLine> get _top =>
      _lines.where((l) => l.parentId == null).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<SaleOrderLine> _partsOf(String id) =>
      _lines.where((l) => l.parentId == id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _batch.day,
      firstDate: DateTime(2025),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (picked == null) return;
    final batch = _p.batchFor(picked);
    setState(() {
      final moved = batch.id != _batch.id;
      _batch = batch;
      if (moved) {
        _order = _order.copyWith(
          batchId: batch.id,
          number: _isNew || widget.order!.batchId != batch.id
              ? _p.nextNumber(batch.id)
              : widget.order!.number,
        );
        _number.text = '${_order.number}';
        // Цены прайса — на новый день (свои цены не трогаются).
        _lines = [
          for (final l in _lines)
            l.pricing == LinePricing.manual || l.pricing == LinePricing.fixed
                ? l
                : l.copyWith(price: () => _p.priceOn(l.productId, batch.day)),
        ];
      }
    });
  }

  Future<void> _pickCustomer() async {
    final id = await showAppDialog<String>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: _p,
        child: const _CustomerPicker(),
      ),
    );
    if (id == null) return;
    setState(() {
      _order = _order.copyWith(customerId: id);
      final address = _p.customers[id]?.address;
      if (_address.text.trim().isEmpty && address != null) {
        _address.text = address;
      }
    });
  }

  Future<void> _addLine() async {
    final product = await pickProduct(context, _p, _batch.day);
    if (product == null) return;
    final kg = product.unit == ProductUnit.kg;
    final line = SaleOrderLine(
      id: _p.newId(),
      orderId: _order.id,
      productId: product.id,
      sortOrder: _top.length,
      orderedUnit: kg ? OrderedUnit.kg : OrderedUnit.pcs,
      price: _p.priceOn(product.id, _batch.day),
      added: !_isNew && _order.status != OrderStatus.accepted,
    );
    setState(() => _lines = [..._lines, line]);
    if (mounted) await _editLine(line);
  }

  Future<void> _editLine(SaleOrderLine line) async {
    final result = await showAppDialog<_LineResult>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: _p,
        child: _LineDialog(
          line: line,
          parts: _partsOf(line.id),
          day: _batch.day,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _lines = [
        for (final l in _lines)
          if (l.id != line.id && l.parentId != line.id) l,
      ];
      if (!result.delete) {
        _lines = [..._lines, result.line, ...result.parts];
      } else {
        // Порядок оставшихся строк — без пропусков.
        var i = 0;
        _lines = [
          for (final l in _lines)
            l.parentId == null ? l.copyWith(sortOrder: i++) : l,
        ];
      }
    });
  }

  Future<void> _save() async {
    final number = int.tryParse(_number.text.trim());
    if (number == null || number < 1) {
      setState(() => _problem = 'Номер заказа — целое число с 1');
      return;
    }
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final order = _order.copyWith(
      number: number,
      comment: () => opt(_comment),
      address: () =>
          _order.delivery == Delivery.delivery ? opt(_address) : null,
    );
    setState(() {
      _saving = true;
      _problem = null;
    });
    final ok = await _p.save(order, _lines, batch: _batch);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _problem = _p.lastProblem);
    }
  }

  Future<void> _delete() async {
    final sure = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить заказ?'),
        content: Text('Заказ ${_p.label(_order)} со всеми строками.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (await _p.delete(_order.id) && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final totals = orderTotals(_lines, _order.id, p.products);
    final customer = _customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? 'Новый заказ'
              : 'Заказ ${batchCode(_batch.day)}-${_order.number}',
        ),
        actions: [
          if (!_isNew && p.canEdit)
            IconButton(
              tooltip: 'Повторить заказ',
              icon: const Icon(Icons.replay),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: p,
                    child: OrderEditorScreen(
                      customerId: _order.customerId,
                      repeatOf: _order,
                      day: p.nearestBatch?.day,
                    ),
                  ),
                ),
              ),
            ),
          if (!_isNew && p.canEdit)
            IconButton(
              tooltip: 'Удалить заказ',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          if (p.canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить'),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(customer?.name ?? 'Выберите покупателя'),
                  subtitle: customer == null
                      ? null
                      : Text(
                          [
                            if (formatPhone(customer.phone).isNotEmpty)
                              formatPhone(customer.phone),
                            [
                              ?customer.channel?.short,
                              ?customer.contact,
                            ].join(' '),
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: p.canEdit ? _pickCustomer : null,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: p.canEdit ? _pickDay : null,
                    icon: const Icon(Icons.event),
                    label: Text('Выдача ${_date.format(_batch.day)}'),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _number,
                      readOnly: !p.canEdit,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Номер',
                        prefixText: '${batchCode(_batch.day)}-',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ChoiceGroup<OrderKind>(
                label: 'Вид',
                value: _order.kind,
                options: [
                  for (final k in OrderKind.values)
                    ChoiceOption(k, k.title, theme.colorScheme.primary),
                ],
                onChanged: p.canEdit
                    ? (k) => setState(() => _order = _order.copyWith(kind: k))
                    : null,
              ),
              const SizedBox(height: 12),
              ChoiceGroup<Delivery>(
                label: 'Получение',
                value: _order.delivery,
                options: [
                  for (final d in Delivery.values)
                    ChoiceOption(d, d.title, theme.colorScheme.primary),
                ],
                onChanged: p.canEdit
                    ? (d) =>
                          setState(() => _order = _order.copyWith(delivery: d))
                    : null,
              ),
              if (_order.delivery == Delivery.delivery) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  readOnly: !p.canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Адрес доставки',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ChoiceGroup<OrderStatus>(
                label: 'Состояние',
                value: _order.status,
                options: [
                  for (final s in OrderStatus.values)
                    ChoiceOption(s, s.title, theme.colorScheme.primary),
                ],
                onChanged: p.canEdit
                    ? (s) => setState(() => _order = _order.copyWith(status: s))
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                readOnly: !p.canEdit,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Комментарий («напомнить забрать»)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('Товары', style: theme.textTheme.titleMedium),
                  ),
                  if (p.canEdit)
                    FilledButton.tonalIcon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Товар'),
                    ),
                ],
              ),
              if (_top.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Добавьте товары из прайса',
                    style: TextStyle(color: muted),
                  ),
                ),
              for (final l in _top)
                _LineTile(
                  line: l,
                  parts: _partsOf(l.id),
                  onTap: p.canEdit ? () => _editLine(l) : null,
                ),
              const Divider(height: 32),
              _TotalsView(totals),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsView extends StatelessWidget {
  final OrderTotals totals;
  const _TotalsView(this.totals);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          t.complete
              ? 'К оплате ${rub(t.fact)}'
              : 'Предварительно ≈ ${rub(t.estimate)}',
          style: theme.textTheme.titleLarge,
        ),
        if (!t.complete && t.fact > 0) Text('уже взвешено на ${rub(t.fact)}'),
        if (t.unknown > 0)
          Text(
            'Без суммы (заказано словами): ${t.unknown}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (t.weight > 0) Text('Вес по факту ${fmtQty(t.weight)} кг'),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  final SaleOrderLine line;
  final List<SaleOrderLine> parts;
  final VoidCallback? onTap;
  const _LineTile({required this.line, required this.parts, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final product = p.products[line.productId];
    final amount = lineAmount(line, p.products, parts: parts);
    final estimate = lineEstimate(line, p.products, parts: parts);
    final fact = factText(line, product, parts);
    final off = weightOff(line, parts: parts);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        [
          product?.name ?? 'Товар удалён',
          if (line.added) '(добавлено при сборке)',
        ].join(' '),
        style: line.state == LineState.missing
            ? TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'заказано: ${orderedText(line).ifEmpty('—')}'),
            if (fact.isNotEmpty)
              TextSpan(
                text: '   факт: $fact',
                style: off
                    ? TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            if (parts.isNotEmpty)
              TextSpan(
                text:
                    '\nсостав: ${parts.map((x) => '${p.products[x.productId]?.name ?? '?'} ${fmtQty(x.weight)}').join(', ')}',
              ),
            if (parts.isNotEmpty)
              if (setProgress(line, parts, p.products).leftKg case final left?
                  when left > 0.0005)
                TextSpan(
                  text:
                      '   осталось ${fmtQty(double.parse(left.toStringAsFixed(3)))} кг',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
            if (line.pricing != LinePricing.list)
              TextSpan(text: '\nцена: ${line.pricing.title.toLowerCase()}'),
            if (line.note != null) TextSpan(text: '\n${line.note}'),
          ],
        ),
      ),
      trailing: Text(
        amount != null
            ? rub(amount)
            : estimate != null
            ? '≈ ${rub(estimate)}'
            : '',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// ------------------------------------------------------------ выбор товара

/// Товар прайса на день [day] (по группам, с поиском); null — отмена.
Future<Product?> pickProduct(
  BuildContext context,
  OrdersProvider p,
  DateTime day,
) => showAppDialog<Product>(
  context: context,
  builder: (_) => _ProductPicker(view: p.catalog(day)),
);

class _ProductPicker extends StatefulWidget {
  final PriceListView view;
  const _ProductPicker({required this.view});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final theme = Theme.of(context);
    return AppDialog(
      title: const Text('Товар'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            for (final s in widget.view.sections)
              if (s.rows.any(
                (r) => r.product.name.toLowerCase().contains(q),
              )) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    s.group.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final r in s.rows)
                  if (r.product.name.toLowerCase().contains(q))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.product.name),
                      trailing: Text(
                        r.price == null
                            ? 'нет цены'
                            : '${rub(r.price!.price)} / ${r.product.unit.title}',
                      ),
                      onTap: () => Navigator.pop(context, r.product),
                    ),
              ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------- выбор покупателя

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _query = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final p = context.read<OrdersProvider>();
    final name = _query.text.trim();
    if (name.isEmpty) return;
    final digits = name.replaceAll(RegExp(r'\D'), '');
    final customer = Customer(
      id: p.newId(),
      name: digits.length >= 5 ? 'Покупатель $digits' : name,
      phone: digits.length >= 5 ? name : null,
    );
    if (await p.addCustomer(customer) && mounted) {
      Navigator.pop(context, customer.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final list = searchCustomers(p.customers.values, _query.text);
    return AppDialog(
      title: const Text('Покупатель'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              // На телефоне клавиатура закрыла бы половину списка.
              autofocus:
                  MediaQuery.sizeOf(context).width >= AppTheme.compactWidth,
              onChanged: (_) {
                if (_scroll.hasClients) _scroll.jumpTo(0);
                setState(() {});
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Имя, ник или телефон',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.text.trim().isEmpty
                  ? 'Все покупатели: ${list.length}'
                  : 'Найдено: ${list.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            // Список прокручивается — выбрать можно и не вводя имени.
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.5).clamp(
                200.0,
                460.0,
              ),
              child: list.isEmpty
                  ? const Center(child: Text('Не найдено'))
                  : Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scroll,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(right: 12),
                            title: Text(c.name),
                            subtitle: Text(
                              [
                                formatPhone(c.phone),
                                ?c.contact,
                                ?c.address,
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            onTap: () => Navigator.pop(context, c.id),
                          );
                        },
                      ),
                    ),
            ),
            if (_query.text.trim().isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt),
                title: Text('Новый покупатель «${_query.text.trim()}»'),
                subtitle: const Text(
                  'Телефон, адрес и мессенджер — потом в «Покупателях»',
                ),
                onTap: _create,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ окно строки

class _LineResult {
  final SaleOrderLine line;
  final List<SaleOrderLine> parts;
  final bool delete;
  const _LineResult(this.line, this.parts, {this.delete = false});
}

class _LineDialog extends StatefulWidget {
  final SaleOrderLine line;
  final List<SaleOrderLine> parts;
  final DateTime day;
  const _LineDialog({
    required this.line,
    required this.parts,
    required this.day,
  });

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  late SaleOrderLine _l = widget.line;
  late List<SaleOrderLine> _parts = [...widget.parts];
  late final _qty = TextEditingController(text: _qtyText(_l));
  late final _text = TextEditingController(text: _l.orderedText ?? '');
  late final _weight = TextEditingController(text: fmtQty(_l.weight));
  late final _pieces = TextEditingController(text: '${_l.pieces ?? ''}');
  late final _price = TextEditingController(
    text: _l.price == null ? '' : formatPrice(_l.price!),
  );
  late final _fixed = TextEditingController(
    text: _l.fixedAmount == null ? '' : formatPrice(_l.fixedAmount!),
  );
  late final _note = TextEditingController(text: _l.note ?? '');
  late final _partWeights = {
    for (final x in widget.parts)
      x.id: TextEditingController(text: fmtQty(x.weight)),
  };
  String? _problem;

  static String _qtyText(SaleOrderLine l) => fmtQty(l.orderedQty);

  @override
  void dispose() {
    for (final c in [_qty, _text, _weight, _pieces, _price, _fixed, _note]) {
      c.dispose();
    }
    for (final c in _partWeights.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ход сборки по тому, что сейчас введено в окне.
  SetProgress _progress(OrdersProvider p) =>
      setProgress(_l.copyWith(orderedQty: () => _num(_qty.text)), [
        for (final x in _parts)
          x.copyWith(weight: () => _num(_partWeights[x.id]!.text)),
      ], p.products);

  Future<void> _addPart() async {
    final p = context.read<OrdersProvider>();
    final product = await pickProduct(context, p, widget.day);
    if (product == null) return;
    final part = SaleOrderLine(
      id: p.newId(),
      orderId: _l.orderId,
      parentId: _l.id,
      productId: product.id,
      sortOrder: _parts.length,
      price: p.priceOn(product.id, widget.day),
    );
    setState(() {
      _parts = [..._parts, part];
      _partWeights[part.id] = TextEditingController();
    });
  }

  void _save() {
    final price = parseRub(_price.text.trim());
    final fixed = parseRub(_fixed.text.trim());
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final pieces = int.tryParse(_pieces.text.trim());
    final line = _l.copyWith(
      orderedQty: () => _num(_qty.text),
      orderedText: () => opt(_text),
      weight: () => _num(_weight.text),
      pieces: () => pieces,
      price: () => _l.pricing == LinePricing.manual ? price : _l.price,
      fixedAmount: () => _l.pricing == LinePricing.fixed ? fixed : null,
      note: () => opt(_note),
      state:
          _l.state == LineState.open &&
              (_num(_weight.text) != null || pieces != null)
          ? LineState.assembled
          : _l.state,
    );
    final parts = [
      for (final x in _parts)
        x.copyWith(
          weight: () => _num(_partWeights[x.id]!.text),
          state: _num(_partWeights[x.id]!.text) != null
              ? LineState.assembled
              : x.state,
        ),
    ];
    final problem = orderLineProblem(line);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context, _LineResult(line, parts));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final product = p.products[_l.productId];
    final kg = (product?.unit ?? ProductUnit.kg) == ProductUnit.kg;
    final isSet = _parts.isNotEmpty;
    final listPrice = p.priceOn(_l.productId, widget.day);
    Widget field(
      TextEditingController c,
      String label, {
      String? suffix,
      double width = 140,
    }) => SizedBox(
      width: width,
      child: TextField(
        controller: c,
        // Ход сборки набора пересчитывается на каждый ввод.
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return AppDialog(
      title: Text(product?.name ?? 'Товар'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              listPrice == null
                  ? 'Цены в прайсе на ${_date.format(widget.day)} нет'
                  : 'Прайс: ${rub(listPrice)} / ${product?.unit.title ?? 'кг'}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text('Заказано', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                field(_qty, 'Сколько'),
                ChoiceGroup<OrderedUnit?>(
                  label: '',
                  value: _l.orderedUnit,
                  options: [
                    for (final u in OrderedUnit.values)
                      ChoiceOption(u, u.title, theme.colorScheme.primary),
                  ],
                  onChanged: (u) =>
                      setState(() => _l = _l.copyWith(orderedUnit: () => u)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Что просили словами («кусок побольше», «4–5 шт»)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Фактически', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (!isSet)
              kg
                  ? field(_weight, 'Вес', suffix: 'кг')
                  : field(_pieces, 'Штук', suffix: product?.unit.title),
            if (isSet || _l.pricing == LinePricing.parts) ...[
              Text(
                'Состав набора — вес каждой части; общий вес считается сам',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              for (final x in _parts)
                Row(
                  children: [
                    Expanded(child: Text(p.products[x.productId]?.name ?? '?')),
                    field(_partWeights[x.id]!, 'Вес', suffix: 'кг', width: 120),
                    IconButton(
                      tooltip: 'Убрать часть',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(
                        () => _parts = [
                          for (final y in _parts)
                            if (y.id != x.id) y,
                        ],
                      ),
                    ),
                  ],
                ),
              if (isSet) _SetProgressView(_progress(p)),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPart,
                icon: const Icon(Icons.add),
                label: Text(isSet ? 'Часть набора' : 'Состав набора'),
              ),
            ),
            const SizedBox(height: 8),
            ChoiceGroup<LineState>(
              label: 'При сборке',
              value: _l.state,
              options: [
                for (final s in LineState.values)
                  ChoiceOption(s, s.title, theme.colorScheme.primary),
              ],
              onChanged: (s) => setState(() => _l = _l.copyWith(state: s)),
            ),
            const SizedBox(height: 16),
            ChoiceGroup<LinePricing>(
              label: 'Цена',
              value: _l.pricing,
              options: [
                for (final pr in LinePricing.values)
                  if (pr != LinePricing.parts || isSet)
                    ChoiceOption(pr, pr.title, theme.colorScheme.primary),
              ],
              onChanged: (pr) => setState(() => _l = _l.copyWith(pricing: pr)),
            ),
            if (_l.pricing == LinePricing.manual) ...[
              const SizedBox(height: 8),
              field(
                _price,
                'Цена',
                suffix: '₽/${kg || isSet ? 'кг' : product!.unit.title}',
              ),
            ],
            if (_l.pricing == LinePricing.fixed) ...[
              const SizedBox(height: 8),
              field(_fixed, 'Сумма за всё', suffix: '₽'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Примечание (почему не выдана, чем заменили)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _problem!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _LineResult(_l, const [], delete: true)),
          child: const Text('Убрать товар'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Готово')),
      ],
    );
  }
}

/// «Собрано 2,05 кг из 3 кг · осталось 0,95 кг» — под частями набора;
/// перебор или недобор сверх допуска — красным.
class _SetProgressView extends StatelessWidget {
  final SetProgress progress;
  const _SetProgressView(this.progress);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pr = progress;
    String kg(double v) => '${fmtQty(double.parse(v.toStringAsFixed(3)))} кг';
    final parts = <String>[
      if (pr.orderedKg != null)
        'Собрано ${kg(pr.collected)} из ${kg(pr.orderedKg!)}'
      else
        'Собрано ${kg(pr.collected)}',
      if (pr.leftKg != null)
        pr.leftKg! > 0.0005
            ? 'осталось ${kg(pr.leftKg!)}'
            : pr.leftKg! < -0.0005
            ? 'перебор ${kg(-pr.leftKg!)}'
            : 'ровно',
      if (pr.collectedAmount != null && pr.collectedAmount! > 0)
        'на ${rub(pr.collectedAmount!)}',
      if (pr.leftAmount != null)
        pr.leftAmount! > 0
            ? 'до суммы осталось ${rub(pr.leftAmount!)}'
            : pr.leftAmount! < 0
            ? 'сверх суммы ${rub(-pr.leftAmount!)}'
            : 'сумма набрана',
    ];
    final off = pr.off();
    final color = off ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
