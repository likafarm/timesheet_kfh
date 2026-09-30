// lib/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/excel_export.dart';
import '../widgets/excel_export_action.dart';
import '../widgets/month_switcher.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/payroll_detail_dialog.dart';
import '../widgets/period_lock_dialogs.dart';
import '../widgets/section_navigation.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<PayrollResult> _results = [];
  Map<String, double> _paymentsByEmployee = {};
  Map<String, double> _bonusByEmployee = {};

  /// Месяц закрыт — показан зафиксированный расчёт.
  bool _locked = false;

  /// Закрытый месяц: у кого зафиксированный расчёт расходится с данными.
  Set<String> _differs = {};
  bool _isLoading = false;

  static const double _colNum = 40;
  static const double _colEmployee = 220;
  static const double _colStart = 128;
  static const double _colDays = 112;
  static const double _colSalary = 110;
  static const double _colBonus = 110;
  static const double _colPayments = 130;
  static const double _colBalance = 130;
  static const double _colActions = 50;

  SectionNavigator? _sections;

  @override
  void initState() {
    super.initState();
    _sections = context.read<SectionNavigator?>()?..addListener(_openRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _sections?.removeListener(_openRequested);
    super.dispose();
  }

  /// Сводка открыла отчёт за нужный месяц.
  void _openRequested() {
    final month = _sections!.takeMonth(AppSection.reports);
    if (month == null || !mounted) return;
    setState(() {
      _selectedYear = month.year;
      _selectedMonth = month.month;
    });
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<AppProvider>();
    // Reload only if provider signals stale data AND we are not already loading.
    if (provider.needRefreshReports && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    final provider = context.read<AppProvider>();
    // Сбрасываем флаг, если он установлен (в любом случае)
    if (provider.needRefreshReports) {
      provider.setNeedRefreshReports(false);
    }
    setState(() => _isLoading = true);
    try {
      if (provider.employees.isEmpty) {
        await provider.loadEmployees(activeOnly: false);
      }
      await provider.loadPayrollReport(_selectedYear, _selectedMonth);
      final report = provider.payrollReport;
      setState(() {
        _results = provider.payrollResults;
        _locked = report?.locked ?? false;
        _differs = report?.differs ?? const {};
      });
      await _loadPayments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPayments() async {
    final provider = context.read<AppProvider>();
    final start = DateTime(_selectedYear, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 0);
    await provider.loadAllPayments(startDate: start, endDate: end);
    final Map<String, double> total = {};
    final Map<String, double> bonus = {};
    for (var p in provider.payments) {
      total[p.employeeId] = (total[p.employeeId] ?? 0) + p.amount;
      if (p.paymentType == 'bonus') {
        bonus[p.employeeId] = (bonus[p.employeeId] ?? 0) + p.amount;
      }
    }
    if (!mounted) return;
    setState(() {
      _paymentsByEmployee = total;
      _bonusByEmployee = bonus;
    });
  }

  /// Отчёт в Excel — ровно то, что на экране (те же строки, остатки и
  /// выплаты месяца).
  Future<void> _exportReport() async {
    final provider = context.read<AppProvider>();
    final report = provider.payrollReport;
    if (report == null) return;
    if (provider.companySettings == null) {
      await provider.loadCompanySettings();
    }
    // Выплаты именно этого месяца (экран выплат мог загрузить другой период).
    await provider.loadAllPayments(
      startDate: DateTime(report.year, report.month, 1),
      endDate: DateTime(report.year, report.month + 1, 0),
    );
    if (!mounted) return;
    await exportToExcel(
      context,
      fileName: excelFileName('Зарплата', DateTime(report.year, report.month)),
      build: () async => payrollWorkbook(
        report: report,
        employees: {
          for (final e in provider.employees)
            if (e.id != null) e.id!: e,
        },
        payments: provider.payments,
        companySettings: provider.companySettings,
      ),
    );
  }

  void _shiftMonth(int delta) {
    final m = DateTime(_selectedYear, _selectedMonth + delta);
    setState(() {
      _selectedYear = m.year;
      _selectedMonth = m.month;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите месяц и год',
    );
    if (picked != null) {
      setState(() {
        _selectedYear = picked.year;
        _selectedMonth = picked.month;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  void _showDetail(PayrollResult result, Employee employee) {
    final provider = context.read<AppProvider>();
    final employeePayments = provider.payments
        .where((p) => p.employeeId == employee.id)
        .toList();
    final startingBalance = provider.startingBalances[employee.id] ?? 0.0;
    showAppDialog(
      context: context,
      builder: (context) => PayrollDetailDialog(
        employee: employee,
        result: result,
        payments: employeePayments,
        startingBalance: startingBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat(
      'LLLL yyyy',
      'ru',
    ).format(DateTime(_selectedYear, _selectedMonth));
    final capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    return Scaffold(
      appBar: monthAppBar(
        context,
        title: 'Отчёты по зарплате',
        switcher: MonthSwitcher(
          month: DateTime(_selectedYear, _selectedMonth),
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onPick: _selectMonth,
          onToday: _goToToday,
        ),
        menu: [
          AppBarMenuItem(
            Icons.table_view,
            'Выгрузить в Excel',
            _isLoading ? null : _exportReport,
          ),
          AppBarMenuItem(Icons.refresh, 'Обновить', _loadData),
        ],
        actions: [_buildLockButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных за $capitalizedMonth',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _locked
                        ? 'Месяц закрыт без зафиксированного расчёта'
                        : 'Нет начислений, выплат и остатков',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  if (_differs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildMonthStatus(),
                  ],
                ],
              ),
            )
          : MonthSwitcher.isCompact(context)
          ? _buildCompactList()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width:
                    _colNum +
                    _colEmployee +
                    _colStart +
                    _colDays +
                    _colSalary +
                    _colBonus +
                    _colPayments +
                    _colBalance +
                    _colActions +
                    60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthStatus(),
                    _buildTableHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _results.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final result = entry.value;
                            final employee = context
                                .read<AppProvider>()
                                .getEmployeeById(result.employeeId);
                            if (employee == null) {
                              return const SizedBox.shrink();
                            }
                            return _buildRow(index, result, employee);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Телефон (6.9): сотрудники карточками — остаток на конец крупно,
  /// из чего он сложился — строкой ниже; касание — подробный расчёт.
  Widget _buildCompactList() {
    final provider = context.read<AppProvider>();
    final money = NumberFormat('#,##0.00', 'ru');
    final days = NumberFormat('#,##0.#', 'ru');
    final status = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      for (final r in _results)
        if (provider.getEmployeeById(r.employeeId) case final e?) (r, e),
    ];
    return ListView.separated(
      itemCount: rows.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) return _buildMonthStatus();
        final (result, employee) = rows[i - 1];
        final paid = _paymentsByEmployee[result.employeeId] ?? 0.0;
        final bonus = _bonusByEmployee[result.employeeId] ?? 0.0;
        final starting = provider.startingBalances[result.employeeId] ?? 0.0;
        final balance = starting + result.totalSalary + bonus - paid;
        final differs = _differs.contains(result.employeeId);
        return ListTile(
          tileColor: differs ? status.warningBackground : null,
          title: Text(employee.fullName, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              'На начало ${money.format(starting)} · '
                  '${days.format(result.baseDays + result.fieldDays)} дн.',
              [
                'начисл. ${money.format(result.totalSalary)}',
                if (bonus > 0) 'премия ${money.format(bonus)}',
                'выпл. ${money.format(paid)}',
              ].join(' · '),
              if (result.skippedWorkDays > 0)
                'Без ставки: ${result.skippedWorkDays} дн.',
            ].join('\n'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          trailing: Text(
            '${money.format(balance)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: balance > 0 ? status.positive : status.negative,
            ),
          ),
          onTap: () => _showDetail(result, employee),
        );
      },
    );
  }

  /// Закрыть выбранный месяц (бухгалтер, админ) или открыть (админ).
  Widget _buildLockButton() {
    final sync = context.watch<SyncProvider>();
    final locked = context.select<AppProvider, bool>(
      (p) => p.isMonthLocked(_selectedYear, _selectedMonth),
    );
    if (!locked && sync.canLockMonths) {
      return IconButton(
        icon: const Icon(Icons.lock_outline),
        tooltip: 'Закрыть месяц',
        onPressed: () async {
          if (await closeMonth(context, _selectedYear, _selectedMonth)) {
            await _loadData();
          }
        },
      );
    }
    if (locked && sync.canUnlockMonths) {
      return IconButton(
        icon: const Icon(Icons.lock_open),
        tooltip: 'Открыть месяц',
        onPressed: () async {
          if (await openMonth(context, _selectedYear, _selectedMonth)) {
            await _loadData();
          }
        },
      );
    }
    return const SizedBox.shrink();
  }

  /// Строка о том, откуда цифры: открытый месяц — расчёт по текущим
  /// данным, закрытый — зафиксированный (и расходится ли он с данными).
  Widget _buildMonthStatus() {
    final status = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String text, Color color) = !_locked
        ? (
            Icons.autorenew,
            'Месяц открыт — расчёт по текущим данным табеля, ставок и выплат',
            scheme.onSurfaceVariant,
          )
        : _differs.isEmpty
        ? (
            Icons.lock_outline,
            'Месяц закрыт — показан зафиксированный расчёт',
            scheme.onSurfaceVariant,
          )
        : (
            Icons.warning_amber,
            'Месяц закрыт — зафиксированный расчёт расходится с текущими '
                'данными у ${_differs.length} сотр. Пересчитать его можно, '
                'открыв месяц.',
            status.warningText,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _colNum,
            child: Text('№', style: headerStyle()),
          ),
          SizedBox(
            width: _colEmployee,
            child: Text('Сотрудник', style: headerStyle()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: _colStart,
              child: Text(
                'На начало',
                style: headerStyle(),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: SizedBox(
              width: _colDays,
              child: Text('Отработано', style: headerStyle()),
            ),
          ),
          SizedBox(
            width: _colSalary,
            child: Text(
              'Начислено',
              style: headerStyle(),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _colBonus,
            child: Text(
              'Премия',
              style: headerStyle(),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _colPayments,
            child: Text(
              'Выплаты',
              style: headerStyle(),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _colBalance,
            child: Text(
              'Остаток',
              style: headerStyle(),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _colActions,
            child: Text('', style: headerStyle()),
          ),
        ],
      ),
    );
  }

  TextStyle headerStyle() =>
      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);

  Widget _buildRow(int index, PayrollResult result, Employee employee) {
    final provider = context.read<AppProvider>();
    final differs = _differs.contains(result.employeeId);
    final totalPaid = _paymentsByEmployee[result.employeeId] ?? 0.0;
    final bonus = _bonusByEmployee[result.employeeId] ?? 0.0;
    final totalDays = result.baseDays + result.fieldDays;
    final starting = provider.startingBalances[result.employeeId] ?? 0.0;
    final balance = starting + result.totalSalary + bonus - totalPaid;

    final daysFormat = NumberFormat('#,##0.0', 'ru');
    final currencyFormat = NumberFormat('#,##0.00', 'ru');
    final status = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Одно касание (двойное заменено везде, этап 4).
    return InkWell(
      onTap: () => _showDetail(result, employee),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          // Зафиксированный расчёт расходится с данными — полупрозрачный
          // фон: текст читается и в тёмной теме.
          color: differs ? status.warningBackground : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: _colNum,
              child: Text('$index', style: const TextStyle(fontSize: 12)),
            ),
            SizedBox(
              width: _colEmployee,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.skippedWorkDays > 0)
                    Text(
                      'Без ставки: ${result.skippedWorkDays} дн.',
                      style: TextStyle(fontSize: 10, color: status.negative),
                    ),
                  Text(
                    employee.position,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: _colStart,
                child: Text(
                  '${currencyFormat.format(provider.startingBalances[result.employeeId] ?? 0.0)} ₽',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        (provider.startingBalances[result.employeeId] ?? 0.0) <
                            0
                        ? status.negative
                        : status.positive,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: SizedBox(
                width: _colDays,
                child: Text(
                  '${daysFormat.format(totalDays)} дн.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),

            SizedBox(
              width: _colSalary,
              child: Text(
                '${currencyFormat.format(result.totalSalary)} ₽',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: _colBonus,
              child: Text(
                bonus > 0 ? '${currencyFormat.format(bonus)} ₽' : '—',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: _colPayments,
              child: Text(
                '${currencyFormat.format(totalPaid)} ₽',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: _colBalance,
              child: Text(
                '${currencyFormat.format(balance)} ₽',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: balance > 0 ? status.positive : status.negative,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: _colActions,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (differs)
                    Tooltip(
                      message:
                          'Зафиксированный расчёт расходится с текущими данными',
                      child: Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: status.warningText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
