// lib/screens/home_screen.dart
//
// Главный экран-сводка (6.8, админ и бухгалтер): напоминания, долг по
// зарплате на сегодня, итог текущего месяца и закрытие месяцев. Данные —
// AppProvider.dashboard (логика — buildDashboard в kfh_domain); каждая
// строка ведёт туда, где это поправить.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/payroll_detail_dialog.dart';
import '../widgets/period_lock_dialogs.dart';
import '../widgets/section_navigation.dart';
import '../widgets/sync_status_bar.dart';
import 'employee_rate_history_screen.dart';
import 'periods_screen.dart';
import 'sync_screen.dart';

final _money = NumberFormat('#,##0.00', 'ru');
final _days = NumberFormat('#,##0.#', 'ru');

String _rub(double v) => '${_money.format(v)} ₽';

/// «август 2026».
String _monthName(int year, int month) =>
    DateFormat('LLLL yyyy', 'ru').format(DateTime(year, month));

String _capitalized(String s) =>
    s.substring(0, 1).toUpperCase() + s.substring(1);

/// Напоминание о синхронизации (null — всё в порядке).
@visibleForTesting
String? syncReminder({
  required SyncPhase phase,
  required bool linked,
  required int pending,
  required int rejected,
  required bool troubled,
  required DateTime? lastSyncAt,
  required DateTime now,
}) {
  if (phase == SyncPhase.signedOut && linked) {
    return 'Вход на сервер не выполнен — правки не уходят на сервер';
  }
  if (phase != SyncPhase.ready) return null;
  final parts = <String>[
    if (rejected > 0) 'не принято сервером: $rejected',
    if (pending > rejected && troubled) 'не отправлено: ${pending - rejected}',
  ];
  if (lastSyncAt != null &&
      now.difference(lastSyncAt) > const Duration(days: 1)) {
    parts.add(
      'последняя синхронизация ${SyncStatusBar.when(lastSyncAt, now: now)}',
    );
  }
  if (parts.isEmpty) return null;
  final text = parts.join(', ');
  return _capitalized(text);
}

class HomeScreen extends StatefulWidget {
  /// «Сегодня» для тестов (null — текущая дата).
  final DateTime? today;

  const HomeScreen({super.key, this.today});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppProvider _app;
  DashboardSummary? _summary;
  String? _error;
  Timer? _reload;
  bool _loading = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppProvider>()..addListener(_scheduleReload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reload?.cancel();
    _app.removeListener(_scheduleReload);
    super.dispose();
  }

  /// Данные изменились (правка, синхронизация, закрытие месяца) —
  /// пересчитать сводку, но не на каждое уведомление подряд.
  void _scheduleReload() {
    _reload?.cancel();
    _reload = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    try {
      final summary = await _app.dashboard(today: widget.today);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось собрать сводку: $e');
    } finally {
      _loading = false;
      if (_again && mounted) {
        _again = false;
        unawaited(_load());
      }
    }
  }

  void _open(AppSection section, {DateTime? month}) =>
      context.read<SectionNavigator?>()?.open(section, month: month);

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _showDebt(EmployeeDebt debt) async {
    final summary = _summary!;
    final employee = summary.employees[debt.employeeId];
    if (employee == null) return;
    final today = summary.today;
    final report = await _app.payrollReportFor(today.year, today.month);
    final payments = await _app.paymentsInMonth(
      debt.employeeId,
      today.year,
      today.month,
    );
    if (!mounted) return;
    final result =
        report.results
            .where((r) => r.employeeId == debt.employeeId)
            .firstOrNull ??
        PayrollResult(
          employeeId: debt.employeeId,
          year: today.year,
          month: today.month,
          baseDays: 0,
          fieldDays: 0,
          sickDays: 0,
          vacationDays: 0,
          totalSalary: 0,
        );
    await showDialog<void>(
      context: context,
      builder: (_) => PayrollDetailDialog(
        employee: employee,
        result: result,
        payments: payments,
        startingBalance: debt.opening,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: summary == null
          ? Center(
              child: _error != null
                  ? Text(_error!)
                  : const CircularProgressIndicator(),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final reminders = _Reminders(
                  summary: summary,
                  open: _open,
                  push: _push,
                );
                final debts = _Debts(summary: summary, onTap: _showDebt);
                final month = _MonthCard(
                  summary: summary,
                  openReport: () =>
                      _open(AppSection.reports, month: summary.today),
                );
                final periods = _PeriodsCard(
                  summary: summary,
                  openPeriods: () => _push(const PeriodsScreen()),
                );
                const gap = SizedBox(height: 12, width: 12);
                if (constraints.maxWidth < 900) {
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [reminders, gap, debts, gap, month, gap, periods],
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: debts),
                      gap,
                      Expanded(
                        child: Column(
                          children: [reminders, gap, month, gap, periods],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Карточка с заголовком.
class _Block extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Block({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Reminders extends StatelessWidget {
  final DashboardSummary summary;
  final void Function(AppSection, {DateTime? month}) open;
  final void Function(Widget) push;

  const _Reminders({
    required this.summary,
    required this.open,
    required this.push,
  });

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final items = <Widget>[];

    final missing = summary.missingDays;
    if (missing.isNotEmpty) {
      final dates = [
        for (final d in missing.take(6)) DateFormat('dd.MM').format(d),
      ].join(', ');
      final more = missing.length > 6 ? ' и ещё ${missing.length - 6}' : '';
      items.add(
        _Item(
          icon: Icons.edit_calendar_outlined,
          title: 'Табель не внесён: ${missing.length} раб. дн.',
          subtitle: '$dates$more — за эти дни нет ни одной записи',
          onTap: () => open(AppSection.timesheet, month: missing.first),
        ),
      );
    }

    for (final u in summary.unpaidDays) {
      final employee = summary.employees[u.employeeId];
      final name = employee?.fullName ?? 'Сотрудник';
      items.add(
        _Item(
          icon: Icons.money_off_outlined,
          title: '$name: ${u.days} раб. дн. без ставки',
          subtitle:
              '${_capitalized(_monthName(u.year, u.month))} — эти дни не '
              'оплачиваются, нужна ставка',
          onTap: employee == null
              ? null
              : () => push(
                  EmployeeRateHistoryScreen(
                    employeeId: u.employeeId,
                    employeeName: name,
                  ),
                ),
        ),
      );
    }

    for (final (y, m) in summary.monthsToClose) {
      items.add(
        _Item(
          icon: Icons.lock_open_outlined,
          title: 'Не закрыт ${_monthName(y, m)}',
          subtitle: 'Закрытый месяц фиксирует расчёт и защищает от правок',
          onTap: () => push(const PeriodsScreen()),
          action: sync.canLockMonths
              ? TextButton(
                  onPressed: () => closeMonth(context, y, m),
                  child: const Text('Закрыть…'),
                )
              : null,
        ),
      );
    }

    final syncText = syncReminder(
      phase: sync.phase,
      linked: sync.isLinked,
      pending: sync.pending,
      rejected: sync.rejected,
      troubled: sync.problem != null || sync.isOffline,
      lastSyncAt: sync.lastSyncAt,
      now: DateTime.now(),
    );
    if (syncText != null) {
      items.add(
        _Item(
          icon: Icons.cloud_off_outlined,
          title: syncText,
          subtitle: 'Сервер синхронизации',
          onTap: () => push(const SyncScreen()),
        ),
      );
    }

    return _Block(
      title: 'Напоминания',
      icon: Icons.notifications_outlined,
      children: items.isEmpty
          ? [
              ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade700,
                ),
                title: const Text('Всё в порядке'),
                subtitle: const Text(
                  'Табель внесён, прошлые месяцы закрыты, ставки есть',
                ),
              ),
            ]
          : items,
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? action;

  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      icon,
      // Предупреждающий цвет, различимый в обеих темах.
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.orange.shade300
          : const Color(0xFFB26A00),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing:
        action ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}

class _Debts extends StatelessWidget {
  final DashboardSummary summary;
  final void Function(EmployeeDebt) onTap;

  const _Debts({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final overpaidColor = theme.colorScheme.error;
    final debts = summary.debts;
    return _Block(
      title: 'Долг по зарплате на сегодня',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                debts.isEmpty ? 'Долгов нет' : _rub(summary.totalDebt),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary.totalOverpaid > 0)
                Text(
                  'Переплачено: ${_rub(summary.totalOverpaid)}',
                  style: TextStyle(color: overpaidColor),
                ),
              Text(
                'Остаток на 1-е число + начислено в этом месяце − выплачено '
                'в этом месяце',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        if (debts.isNotEmpty) const Divider(height: 1),
        for (final d in debts)
          ListTile(
            dense: true,
            title: Text(
              summary.employees[d.employeeId]?.fullName ?? 'Сотрудник',
            ),
            subtitle: Text(
              '${_money.format(d.opening)} + ${_money.format(d.accrued)} − '
              '${_money.format(d.paid)}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _rub(d.balance.abs()),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: d.balance < 0 ? overpaidColor : null,
                  ),
                ),
                if (d.balance < 0)
                  Text(
                    'переплата',
                    style: TextStyle(fontSize: 12, color: overpaidColor),
                  ),
              ],
            ),
            onTap: () => onTap(d),
          ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DashboardSummary summary;
  final VoidCallback openReport;

  const _MonthCard({required this.summary, required this.openReport});

  @override
  Widget build(BuildContext context) {
    final m = summary.month;
    final today = summary.today;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return _Block(
      title: _capitalized(_monthName(today.year, today.month)),
      icon: Icons.calendar_month_outlined,
      children: [
        row('Начислено', _rub(m.accrued)),
        row('Выплачено', _rub(m.paid)),
        row(
          'Отработано (база / поле)',
          '${_days.format(m.baseDays)} / ${_days.format(m.fieldDays)} дн.',
        ),
        row('Норма по календарю', '${m.normDays} раб. дн.'),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: openReport,
              child: const Text('Отчёт за месяц'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodsCard extends StatelessWidget {
  final DashboardSummary summary;
  final VoidCallback openPeriods;

  const _PeriodsCard({required this.summary, required this.openPeriods});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final sync = context.watch<SyncProvider>();
    final theme = Theme.of(context);
    final open = summary.openPastMonths;
    final locked = app.lockedMonths.toList()..sort();
    final lastClosed = locked.isEmpty
        ? null
        : (locked.last ~/ 12, locked.last % 12 + 1);
    return _Block(
      title: 'Закрытие месяцев',
      icon: Icons.lock_outline,
      children: [
        ListTile(
          dense: true,
          title: Text(
            lastClosed == null
                ? 'Закрытых месяцев нет'
                : 'Последний закрытый — ${_monthName(lastClosed.$1, lastClosed.$2)}',
          ),
          subtitle: Text(
            open.isEmpty
                ? 'Все прошлые месяцы закрыты'
                : 'Открыты прошлые: '
                      '${open.map((p) => _monthName(p.$1, p.$2)).join(', ')}',
          ),
        ),
        if (sync.phase != SyncPhase.ready)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Нет связи с сервером: список — на момент последней '
              'синхронизации',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: openPeriods,
              child: const Text('Все месяцы'),
            ),
          ),
        ),
      ],
    );
  }
}
