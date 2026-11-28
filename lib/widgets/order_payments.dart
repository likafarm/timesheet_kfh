// lib/widgets/order_payments.dart
//
// Оплата заказа (этап 11.6): к оплате / оплачено / осталось или
// переплата, оплаты и возвраты (операции финансов со ссылкой на заказ),
// окно «Оплата» (сумма, кошелёк, статья, дата), долг или аванс
// покупателя по всем заказам, сообщение покупателю «собрано …, к оплате
// …» — скопировать или отправить.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/orders_provider.dart';
import '../screens/order_editor_screen.dart' show rub;
import '../services/platform.dart';
import 'adaptive_dialog.dart';
import 'row_table.dart';

final _day = DateFormat('dd.MM.yyyy', 'ru');

/// Оплата заказа [order] (уже записанного); [totals] — итоги с правками,
/// ещё не сохранёнными в карточке.
class OrderPaymentsView extends StatelessWidget {
  final SaleOrder order;
  final OrderTotals totals;
  const OrderPaymentsView({
    super.key,
    required this.order,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final payments = p.paymentsOf(order.id);
    final pay = orderPayment(order, totals, payments);
    final balance = p.balanceOf(order.customerId);
    final error = theme.colorScheme.error;
    final sale = order.kind == OrderKind.sale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Оплата', style: theme.textTheme.titleMedium)),
            if (p.canEdit && sale)
              FilledButton.tonalIcon(
                onPressed: () => openPaymentDialog(context, order, pay),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Оплата'),
              ),
            if (p.canEdit && pay.paid > 0) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    openPaymentDialog(context, order, pay, refund: true),
                child: const Text('Возврат'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (!sale)
          Text('${order.kind.title} — денег не ждём')
        else ...[
          Text(
            [
              '${pay.dueFinal ? 'К оплате' : 'Предварительно'} '
                  '${pay.dueFinal ? '' : '≈ '}${rub(pay.due)}',
              'оплачено ${rub(pay.paid)}',
            ].join(' · '),
          ),
          Text(
            switch (pay.state) {
              PaymentState.unpaid => 'Не оплачен',
              PaymentState.partial => 'Осталось доплатить ${rub(pay.left)}',
              PaymentState.paid =>
                pay.left < 0
                    ? 'Оплачено с запасом ${rub(-pay.left)} (вес ещё не весь)'
                    : 'Оплачен',
              PaymentState.overpaid =>
                'Переплата ${rub(-pay.left)} — останется авансом покупателя',
              PaymentState.none => '',
              PaymentState.history =>
                'Заказ перенесён из Excel — оплачен до программы',
            },
            style: theme.textTheme.titleSmall?.copyWith(
              color: switch (pay.state) {
                PaymentState.unpaid || PaymentState.partial => error,
                _ => theme.colorScheme.primary,
              },
            ),
          ),
        ],
        // Оплаты и возвраты: на компьютере — таблица.
        if (isWideScreen(context) && payments.isNotEmpty) ...[
          const SizedBox(height: 8),
          const RowTableHeader(_payCols),
          for (final op in payments)
            RowTableRow(
              cols: _payCols,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              cells: [
                _padded(CellText(_day.format(op.date))),
                _padded(
                  CellText(
                    op.type == OperationType.income ? 'Оплата' : 'Возврат',
                    color: op.type == OperationType.income ? null : error,
                  ),
                ),
                _padded(
                  CellText(
                    '${op.type == OperationType.income ? '' : '−'}'
                    '${rub(op.amount)}',
                    right: true,
                    bold: true,
                    color: op.type == OperationType.income ? null : error,
                  ),
                ),
                _padded(CellText(p.accountName(op.accountId))),
                _padded(CellText(op.notes ?? '')),
                p.canDeletePayment(op)
                    ? IconButton(
                        tooltip: 'Удалить оплату',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, p, op),
                      )
                    : const SizedBox(height: 40),
              ],
            ),
        ] else
          for (final op in payments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                op.type == OperationType.income
                    ? Icons.south_west
                    : Icons.north_east,
                color: op.type == OperationType.income ? null : error,
              ),
              title: Text(
                '${op.type == OperationType.income ? '' : 'Возврат −'}'
                '${rub(op.amount)} · ${p.accountName(op.accountId)}',
              ),
              subtitle: Text([_day.format(op.date), ?op.notes].join(' · ')),
              trailing: p.canDeletePayment(op)
                  ? IconButton(
                      tooltip: 'Удалить оплату',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, p, op),
                    )
                  : null,
            ),
        if (balance.debt > 0 || balance.advance > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              balance.debt > 0
                  ? 'По всем выданным заказам покупатель должен '
                        '${rub(balance.debt)}'
                  : 'Аванс покупателя по всем заказам: '
                        '${rub(balance.advance)}',
              style: TextStyle(color: balance.debt > 0 ? error : null),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showCustomerMessage(context, order),
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Сообщение покупателю'),
          ),
        ),
      ],
    );
  }

  static const _payCols = [
    RowCol('Дата', width: 110),
    RowCol('Вид', width: 90),
    RowCol('Сумма', width: 120, right: true),
    RowCol('Кошелёк', flex: 2),
    RowCol('Примечание', flex: 3),
    RowCol('', width: 48),
  ];

  static Widget _padded(Widget w) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: w);

  Future<void> _delete(
    BuildContext context,
    OrdersProvider p,
    FinOperation op,
  ) async {
    final sure = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить оплату?'),
        content: Text(
          '${rub(op.amount)} от ${_day.format(op.date)} — операция '
          'пропадёт и из финансов.',
        ),
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
    if (sure == true) await p.deletePayment(op);
  }
}

/// Окно оплаты (или возврата — [refund]) по заказу [order].
Future<bool?> openPaymentDialog(
  BuildContext context,
  SaleOrder order,
  OrderPayment pay, {
  bool refund = false,
}) {
  final p = context.read<OrdersProvider>();
  return showAppDialog<bool>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: p,
      child: _PaymentDialog(order: order, pay: pay, refund: refund),
    ),
  );
}

class _PaymentDialog extends StatefulWidget {
  final SaleOrder order;
  final OrderPayment pay;
  final bool refund;
  const _PaymentDialog({
    required this.order,
    required this.pay,
    required this.refund,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final OrdersProvider _p = context.read<OrdersProvider>();
  late final _amount = TextEditingController(text: _suggested());
  final _notes = TextEditingController();
  late String? _accountId = _initialAccount();
  late String? _categoryId =
      (widget.refund ? _p.refundCategory : _p.saleCategory)?.id;
  DateTime _date = DateTime.now();
  String? _problem;
  bool _saving = false;

  String _suggested() {
    final left = widget.pay.left;
    final v = widget.refund ? -left : left;
    return v > 0 ? formatPrice(v).replaceAll(RegExp(r'\s'), '') : '';
  }

  String? _initialAccount() {
    final all = _p.accounts;
    final last = _p.lastAccountId;
    if (last != null && all.any((a) => a.id == last)) return last;
    return all.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  int? _kopecks() {
    final t = _amount.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final v = double.tryParse(t);
    return v == null ? null : (v * 100).round();
  }

  Future<void> _save() async {
    final amount = _kopecks();
    if (amount == null || amount <= 0) {
      setState(() => _problem = 'Укажите сумму больше нуля');
      return;
    }
    if (_accountId == null) {
      setState(() => _problem = 'Выберите кошелёк');
      return;
    }
    if (_categoryId == null) {
      setState(() => _problem = 'Выберите статью');
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    final ok = await _p.addPayment(
      widget.order,
      amount: amount,
      accountId: _accountId!,
      categoryId: _categoryId!,
      date: _date,
      refund: widget.refund,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _problem = _p.lastProblem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = _p.accounts;
    final categories = _p.categoriesOf(
      widget.refund ? CategoryType.expense : CategoryType.income,
    );
    return AppDialog(
      title: Text(
        widget.refund
            ? 'Возврат по заказу ${_p.label(widget.order)}'
            : 'Оплата заказа ${_p.label(widget.order)}',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
              ],
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: 'Сумма',
                suffixText: '₽',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              Text(
                'Кошельков нет — их заводит бухгалтер в «Финансах»',
                style: TextStyle(color: theme.colorScheme.error),
              )
            else ...[
              Text(
                widget.refund ? 'Откуда вернули' : 'Куда пришли деньги',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    ChoiceChip(
                      label: Text(a.name),
                      selected: _accountId == a.id,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Статья',
                helperText: _categoryId == null
                    ? widget.refund
                          ? 'Нет статьи «Возврат покупателю» — выберите'
                          : 'Нет статьи «Реализация мяса» — выберите'
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Дата: ${_day.format(_date)}')),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: const Text('Другая дата'),
                ),
              ],
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Примечание («предоплата», «перевод на карту»)',
                border: OutlineInputBorder(),
                isDense: true,
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || accounts.isEmpty ? null : _save,
          child: Text(widget.refund ? 'Вернуть' : 'Записать оплату'),
        ),
      ],
    );
  }
}

/// Сообщение покупателю по заказу: скопировать или отправить.
Future<void> showCustomerMessage(BuildContext context, SaleOrder order) {
  final text = context.read<OrdersProvider>().customerMessage(order);
  return showAppDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: const Text('Сообщение покупателю'),
      content: SizedBox(width: 440, child: SelectableText(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        if (isAndroidApp)
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(context);
              await SharePlus.instance.share(ShareParams(text: text));
            },
            child: const Text('Отправить…'),
          ),
        FilledButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Скопировано — вставьте в мессенджер'),
                ),
              );
            }
          },
          child: const Text('Копировать'),
        ),
      ],
    ),
  );
}
