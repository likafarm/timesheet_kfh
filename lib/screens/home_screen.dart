// lib/screens/home_screen.dart
//
// Главный экран-сводка (6.8, админ и бухгалтер): напоминания, долг по
// зарплате на сегодня, итог текущего месяца и закрытие месяцев. Данные —
// AppProvider.dashboard (логика — buildDashboard в kfh_domain); каждая
// строка ведёт туда, где это поправить. Плитки финансов (8.7): остатки
// кошельков, займы, доходы и расходы месяца — buildFinanceSummary через
// FinanceProvider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/finance_operation_dialog.dart' show operationTypeColors;
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

  /// Финансы для плиток: сам перечитывается после правок и синхронизации.
  late final FinanceProvider _finance;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppProvider>()..addListener(_scheduleReload);
    _finance = FinanceProvider(_app)..addListener(_onFinance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      unawaited(_loadFinance());
    });
  }

  @override
  void dispose() {
    _reload?.cancel();
    _app.removeListener(_scheduleReload);
    _finance
      ..removeListener(_onFinance)
      ..dispose();
    super.dispose();
  }

  void _onFinance() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFinance() async {
    try {
      await _finance.load();
    } catch (_) {
      // Плитки финансов не обязательны: сводка табеля — без них.
    }
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
    await showAppDialog<void>(
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
            onPressed: () {
              _load();
              unawaited(_loadFinance());
            },
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
                final finance = _finance.loaded
                    ? _finance.summaryAt(summary.today)
                    : null;
                final money = finance == null || finance.isEmpty
                    ? null
                    : _FinanceCards(
                        summary: finance,
                        forecast: _finance.forecast(),
                        open: (section) => _open(section),
                      );
                const gap = SizedBox(height: 12, width: 12);
                if (constraints.maxWidth < 720) {
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      reminders,
                      gap,
                      if (money != null) ...[money, gap],
                      debts,
                      gap,
                      month,
                      gap,
                      periods,
                    ],
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            if (money != null) ...[money, gap],
                            debts,
                          ],
                        ),
                      ),
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

    final invalid = summary.invalidDays;
    if (invalid.isNotEmpty) {
      final list = [
        for (final r in invalid.take(4))
          '${summary.employees[r.employeeId]?.fullName ?? 'Сотрудник'} '
              '${DateFormat('dd.MM.yyyy').format(r.date)}',
      ].join(', ');
      final more = invalid.length > 4 ? ' и ещё ${invalid.length - 4}' : '';
      items.add(
        _Item(
          icon: Icons.place_outlined,
          title: 'Дни без места работы: ${invalid.length}',
          subtitle: '$list$more — укажите место (база или поле) или долю дня',
          onTap: () => open(AppSection.timesheet, month: invalid.first.date),
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

/// Плитки финансов (8.7): деньги в кошельках, займы, доходы и расходы
/// месяца; платежи на неделю и нехватка денег по платёжному календарю
/// (8Б.4). Ссылки — в пункты меню «Финансов» (8Б.1).
class _FinanceCards extends StatelessWidget {
  final FinanceSummary summary;

  /// Прогноз платёжного календаря на 60 дней.
  final List<ForecastDay> forecast;

  /// Переход в пункт меню «Финансов» (8Б.1).
  final void Function(AppSection section) open;

  const _FinanceCards({
    required this.summary,
    required this.forecast,
    required this.open,
  });

  /// Платежи ближайшей недели и первый день нехватки денег; пусто — нет
  /// ни того, ни другого.
  List<Widget> _payments(ThemeData theme, Widget gap) {
    final today = calendarDay(DateTime.now());
    final weekEnd = addCalendarDays(today, 7);
    final week = [
      for (final d in forecast)
        if (!d.day.isAfter(weekEnd)) ...d.items,
    ];
    final shortfall = firstShortfall(forecast);
    if (week.isEmpty && shortfall == null) return const [];
    final day = DateFormat('dd.MM');
    return [
      gap,
      _Block(
        title: 'Платежи на неделю',
        icon: Icons.event_note_outlined,
        children: [
          if (shortfall != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                '${DateFormat('dd.MM.yyyy').format(shortfall.day)} не хватит '
                '${formatRub(-shortfall.balance)} ₽',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final o in week.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      o.day.isBefore(today) ? 'долг' : day.format(o.day),
                      style: o.day.isBefore(today)
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      o.plan.description ??
                          (o.signedAmount > 0 ? 'Поступление' : 'Платёж'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${o.signedAmount > 0 ? '+' : '−'}'
                    '${formatRub(o.plan.amount)} ₽',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: operationTypeColors[o.plan.type],
                    ),
                  ),
                ],
              ),
            ),
          if (week.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('и ещё ${week.length - 5}'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => open(AppSection.calendar),
                child: const Text('Платёжный календарь'),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = summary.day;
    Widget row(
      String label,
      int kopecks, {
      bool bold = false,
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
            ),
          ),
          Text(
            '${formatRub(kopecks)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? (kopecks < 0 ? theme.colorScheme.error : null),
            ),
          ),
        ],
      ),
    );
    Widget link(String text, AppSection section) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton(onPressed: () => open(section), child: Text(text)),
      ),
    );
    final m = summary.month;
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Block(
          title: 'Деньги на ${DateFormat('dd.MM.yyyy').format(day)}',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            for (final a in summary.accounts) row(a.account.name, a.balance),
            const Divider(indent: 16, endIndent: 16),
            row('Итого', summary.total, bold: true),
            link('Банки и кассы', AppSection.banks),
          ],
        ),
        if (summary.debts.isNotEmpty) ...[
          gap,
          _Block(
            title: 'Займы',
            icon: Icons.handshake_outlined,
            children: [
              if (summary.weOwe != 0) row('Должны мы', summary.weOwe),
              if (summary.owedToUs != 0) row('Должны нам', summary.owedToUs),
              const SizedBox(height: 4),
            ],
          ),
        ],
        ..._payments(theme, gap),
        gap,
        _Block(
          title: 'Доходы и расходы — ${_monthName(day.year, day.month)}',
          icon: Icons.swap_vert,
          children: [
            row(
              'Доходы',
              m.income + m.refunds,
              color: operationTypeColors[OperationType.income],
            ),
            row(
              'Расходы',
              m.expense + m.capex,
              color: operationTypeColors[OperationType.expense],
            ),
            if (m.capex != 0) row('в т. ч. капвложения', m.capex),
            row('Итог', m.result, bold: true),
            link('Расходы месяца', AppSection.expense),
          ],
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
