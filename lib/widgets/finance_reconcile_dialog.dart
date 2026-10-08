// lib/widgets/finance_reconcile_dialog.dart
//
// Сверка остатка кошелька (этап 8.7): фактический остаток на конец дня
// против расчётного по записям; расхождение записывается одной операцией
// «Корректировка остатка» (решение владельца 2026-10-08: без отдельного
// журнала сверок — сверку видно по этой операции).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../providers/finance_provider.dart';
import 'adaptive_dialog.dart';
import 'common_widgets.dart';

/// Открыть сверку (кошелёк [accountId] выбран заранее, если задан); true —
/// корректировка записана.
Future<bool> showReconcileDialog(
  BuildContext context,
  FinanceProvider finance, {
  String? accountId,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (_) =>
          FinanceReconcileDialog(finance: finance, accountId: accountId),
    ) ==
    true;

class FinanceReconcileDialog extends StatefulWidget {
  final FinanceProvider finance;
  final String? accountId;

  const FinanceReconcileDialog({
    super.key,
    required this.finance,
    this.accountId,
  });

  @override
  State<FinanceReconcileDialog> createState() => _FinanceReconcileDialogState();
}

class _FinanceReconcileDialogState extends State<FinanceReconcileDialog> {
  FinanceProvider get fin => widget.finance;

  late String? _accountId =
      widget.accountId ?? fin.accounts.where((a) => !a.closed).firstOrNull?.id;
  DateTime _date = calendarDay(DateTime.now());
  final _actual = TextEditingController();
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    _actual.dispose();
    super.dispose();
  }

  Reconciliation? get _result {
    final id = _accountId;
    final actual = parseRub(_actual.text);
    if (id == null || actual == null) return null;
    return fin.reconciliation(id, _date, actual);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(Reconciliation r) async {
    setState(() => _saving = true);
    final ok = await fin.applyReconciliation(r);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _problem = ok ? null : fin.lastProblem;
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _result;
    final expected = _accountId == null
        ? null
        : fin.accountBalancesAt(_date)[_accountId];
    Widget line(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
    final diff = r?.difference ?? 0;
    return AppDialog(
      title: const Text('Сверка остатка'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown<String>(
                labelText: 'Кошелёк',
                value: _accountId,
                items: [
                  for (final a in fin.accounts)
                    if (!a.closed || a.id == _accountId)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event, size: 18),
                label: Text(
                  'На конец дня ${DateFormat('dd.MM.yyyy').format(_date)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actual,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Фактический остаток, ₽',
                  helperText: 'Сколько на самом деле: по банку, в кассе',
                  prefixIcon: Icon(Icons.currency_ruble, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _problem = null),
              ),
              const SizedBox(height: 12),
              if (expected != null)
                line('По записям', '${formatRub(expected)} ₽'),
              if (r != null) ...[
                line('Факт', '${formatRub(r.actual)} ₽'),
                const Divider(),
                line(
                  diff == 0
                      ? 'Расхождения нет'
                      : diff > 0
                      ? 'Излишек — запишется доходом'
                      : 'Недостача — запишется расходом',
                  '${formatRub(diff)} ₽',
                  bold: true,
                  color: diff == 0
                      ? Colors.green[700]
                      : theme.colorScheme.error,
                ),
              ] else if (_actual.text.trim().isNotEmpty)
                Text(
                  'Не сумма',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  _problem!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Закрыть'),
        ),
        FilledButton(
          onPressed: r == null || diff == 0 || _saving ? null : () => _save(r),
          child: const Text('Записать корректировку'),
        ),
      ],
    );
  }
}
