// lib/screens/finance_balances_screen.dart
//
// Остатки кошельков и займов на конец дня (этап 8.7). Нажатие на кошелёк —
// отбор операций по нему в «Финансах», «Сверить» — сверка остатка.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/finance_reconcile_dialog.dart';

class FinanceBalancesScreen extends StatefulWidget {
  /// День, на конец которого показать остатки.
  final DateTime day;

  const FinanceBalancesScreen({super.key, required this.day});

  @override
  State<FinanceBalancesScreen> createState() => _FinanceBalancesScreenState();
}

class _FinanceBalancesScreenState extends State<FinanceBalancesScreen> {
  late DateTime _day = calendarDay(widget.day);

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _reconcile(FinanceProvider fin, [String? accountId]) async {
    final ok = await showReconcileDialog(context, fin, accountId: accountId);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Корректировка записана')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final s = fin.summaryAt(_day);
    final theme = Theme.of(context);
    final today = calendarDay(DateTime.now());
    Text money(int v, {bool bold = false}) => Text(
      '${formatRub(v)} ₽',
      style: TextStyle(
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: v < 0 ? theme.colorScheme.error : null,
      ),
    );
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t, style: theme.textTheme.titleMedium),
    );
    final debtsReceived = s.debts.where(
      (d) => d.debt.kind == DebtKind.received,
    );
    final debtsGiven = s.debts.where((d) => d.debt.kind == DebtKind.given);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Остатки'),
        actions: [
          TextButton.icon(
            onPressed: () => _reconcile(fin),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Сверка'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDay,
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(
                        'На конец дня ${DateFormat('dd.MM.yyyy').format(_day)}',
                      ),
                    ),
                    if (_day != today)
                      TextButton(
                        onPressed: () => setState(() => _day = today),
                        child: const Text('Сегодня'),
                      ),
                  ],
                ),
              ),
              heading('Кошельки'),
              for (final a in s.accounts)
                ListTile(
                  title: Text(a.account.name),
                  subtitle: Text(
                    [
                      a.account.kind.title,
                      if (a.account.closed) 'закрыт',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      money(a.balance),
                      IconButton(
                        tooltip: 'Сверить остаток',
                        icon: const Icon(Icons.fact_check_outlined),
                        onPressed: () => _reconcile(fin, a.account.id),
                      ),
                    ],
                  ),
                  // Отбор операций по кошельку в «Финансах».
                  onTap: () => Navigator.of(context).pop(a.account.id),
                ),
              ListTile(
                title: const Text(
                  'Итого',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Минус кредитки — долг банку'),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: money(s.total, bold: true),
                ),
              ),
              const Divider(),
              heading('Займы'),
              if (s.debts.isEmpty) const ListTile(title: Text('Долгов нет')),
              for (final d in [...debtsReceived, ...debtsGiven])
                ListTile(
                  title: Text(fin.counterpartyName(d.debt.counterpartyId)),
                  subtitle: Text(
                    d.debt.kind == DebtKind.received
                        ? 'Должны мы'
                        : 'Должны нам',
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: money(d.balance),
                  ),
                ),
              if (s.debts.isNotEmpty) ...[
                ListTile(
                  title: const Text('Всего должны мы'),
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: money(s.weOwe, bold: true),
                  ),
                ),
                ListTile(
                  title: const Text('Всего должны нам'),
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: money(s.owedToUs, bold: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
