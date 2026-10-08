// lib/screens/payment_calendar_screen.dart
//
// «Финансы → Платёжный календарь» (8Б.4): плановые платежи и поступления
// на 60 дней вперёд с прогнозом денег (все кошельки) и предупреждением о
// нехватке; просроченное — сегодня. «Оплачено» — окно операции из плана
// (операция помнит план и день), «Пропустить» — этот раз не нужен.
// Вкладка «Планы» — все планы: добавить, изменить, закрыть, удалить.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/closed_month.dart';
import '../widgets/finance_operation_dialog.dart';
import '../widgets/finance_plan_dialog.dart';

class PaymentCalendarScreen extends StatelessWidget {
  const PaymentCalendarScreen({super.key});

  /// Дней прогноза.
  static const days = 60;

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Платёжный календарь'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ближайшие'),
              Tab(text: 'Планы'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              icon: const Icon(Icons.refresh),
              onPressed: fin.load,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          // Пункты меню живут рядом (IndexedStack) — без общего героя.
          heroTag: null,
          tooltip: 'Новый план',
          onPressed: fin.loaded ? () => showPlanDialog(context, fin) : null,
          icon: const Icon(Icons.add),
          label: const Text('План'),
        ),
        body: !fin.loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_Upcoming(fin), _Plans(fin)]),
      ),
    );
  }
}

String _rub(int k) => '${formatRub(k)} ₽';
final _day = DateFormat('dd.MM.yyyy');
final _weekday = DateFormat('EEEE, d MMMM', 'ru');

String _planName(FinanceProvider fin, FinPlan p) => [
  ?p.description,
  if (p.description == null) fin.categoryName(p.categoryId),
].join();

class _Upcoming extends StatelessWidget {
  final FinanceProvider fin;
  const _Upcoming(this.fin);

  Future<void> _pay(BuildContext context, PlanOccurrence o) async {
    final today = calendarDay(DateTime.now());
    if (!await ensureMonthOpen(context, today.year, today.month) ||
        !context.mounted) {
      return;
    }
    final op = fin.paymentFor(o);
    final ok = await showOperationDialog(
      context,
      fin,
      template: op,
      type: op.type,
      sourceRef: op.sourceRef,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Оплата записана')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forecast = fin.forecast(days: PaymentCalendarScreen.days);
    final today = calendarDay(DateTime.now());
    final shortfall = firstShortfall(forecast);
    final last = forecast.last;
    final banner = Card(
      color: shortfall == null
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          shortfall == null ? Icons.check_circle_outline : Icons.warning_amber,
          color: shortfall == null ? null : theme.colorScheme.error,
        ),
        title: Text(
          shortfall == null
              ? 'Денег хватает на ${PaymentCalendarScreen.days} дней'
              : '${_day.format(shortfall.day)} не хватит '
                    '${_rub(-shortfall.balance)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Сейчас во всех кошельках: '
          '${_rub(forecast.first.balance - forecast.first.flow)}; '
          'через ${PaymentCalendarScreen.days} дней по плану: '
          '${_rub(last.balance)}',
        ),
      ),
    );
    final tiles = <Widget>[banner];
    for (final d in forecast) {
      if (d.items.isEmpty) continue;
      tiles.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  d.day == today ? 'Сегодня' : _weekday.format(d.day),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                'останется ${_rub(d.balance)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: d.balance < 0 ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
      for (final o in d.items) {
        final overdue = o.day.isBefore(today);
        tiles.add(
          Card(
            child: ListTile(
              title: Text(_planName(fin, o.plan)),
              subtitle: Text(
                [
                  if (overdue) 'просрочено с ${_day.format(o.day)}',
                  ?fin.catalog.counterparties[o.plan.counterpartyId]?.name,
                  if (o.plan.accountId != null)
                    fin.accountName(o.plan.accountId),
                  if (o.plan.repeat != PlanRepeat.none)
                    o.plan.repeat.title.toLowerCase(),
                ].join(' · '),
                style: overdue
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${o.signedAmount > 0 ? '+' : '−'}'
                    '${formatRub(o.plan.amount)} ₽',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: operationTypeColors[o.plan.type],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Действия',
                    onSelected: (v) => switch (v) {
                      'pay' => _pay(context, o),
                      'skip' => fin.skipOccurrence(o),
                      'edit' => showPlanDialog(context, fin, plan: o.plan),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pay',
                        child: Text(
                          o.plan.type == OperationType.income
                              ? 'Получено'
                              : 'Оплачено',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'skip',
                        child: Text('Пропустить этот раз'),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Изменить план'),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () => _pay(context, o),
            ),
          ),
        );
      }
    }
    if (tiles.length == 1) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'На ${PaymentCalendarScreen.days} дней платежей нет. Добавьте '
            'план: аренду, кредит, налог, ожидаемую оплату покупателя.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
          children: tiles,
        ),
      ),
    );
  }
}

class _Plans extends StatelessWidget {
  final FinanceProvider fin;
  const _Plans(this.fin);

  Future<void> _delete(BuildContext context, FinPlan p) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить план?'),
        content: Text(
          '${_planName(fin, p)}\nЗаписанные оплаты останутся операциями.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await fin.deletePlan(p);
  }

  @override
  Widget build(BuildContext context) {
    final today = calendarDay(DateTime.now());
    final plans = [...fin.plans]
      ..sort((a, b) {
        if (a.closed != b.closed) return a.closed ? 1 : -1;
        return a.startDate.compareTo(b.startDate);
      });
    if (plans.isEmpty) {
      return Center(
        child: Text('Планов нет', style: TextStyle(color: Colors.grey[600])),
      );
    }
    String next(FinPlan p) {
      final open = fin
          .occurrences(today, DateTime(today.year + 2, today.month))
          .where((o) => o.plan.id == p.id && o.open)
          .firstOrNull;
      return open == null
          ? 'больше не повторяется'
          : 'следующий ${_day.format(open.day)}';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: plans.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = plans[i];
            return ListTile(
              enabled: !p.closed,
              title: Text(_planName(fin, p)),
              subtitle: Text(
                [
                  p.repeat.title,
                  if (p.untilDate != null) 'до ${_day.format(p.untilDate!)}',
                  if (p.closed) 'закрыт' else next(p),
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${p.type == OperationType.income ? '+' : '−'}'
                    '${formatRub(p.amount)} ₽',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: operationTypeColors[p.type],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Действия',
                    onSelected: (v) => switch (v) {
                      'edit' => showPlanDialog(context, fin, plan: p),
                      'close' => fin.savePlan(p.copyWith(closed: !p.closed)),
                      'delete' => _delete(context, p),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Изменить'),
                      ),
                      PopupMenuItem(
                        value: 'close',
                        child: Text(p.closed ? 'Открыть снова' : 'Закрыть'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () => showPlanDialog(context, fin, plan: p),
            );
          },
        ),
      ),
    );
  }
}
