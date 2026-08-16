// lib/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<PayrollResult> _results = [];
  Map<int, double> _paymentsByEmployee = {};
  Map<int, double> _bonusByEmployee = {};
  Map<int, bool> _upToDateStatus = {};
  bool _isLoading = false;
  bool _isCalculatingAll = false;
  final Set<int> _calculatingSingle = {};

  static const double _colNum = 40;
  static const double _colEmployee = 220;
  static const double _colDays = 120;
  static const double _colSalary = 130;
  static const double _colBonus = 110;
  static const double _colPayments = 130;
  static const double _colBalance = 130;
  static const double _colActions = 70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Подписываемся на изменения провайдера
    final provider = context.watch<AppProvider>();
    // Если нужен рефреш – планируем загрузку данных
    if (provider.needRefreshReports) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    } else if (_results.isEmpty) {
      // Если данных нет, тоже загружаем (первое открытие)
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
      await provider.loadPayrollResultsForMonth(_selectedYear, _selectedMonth);
      setState(() {
        _results = provider.payrollResults;
      });
      await _loadPayments();
      await _checkAllStatus();
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
    final Map<int, double> total = {};
    final Map<int, double> bonus = {};
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

  Future<void> _checkAllStatus() async {
    final provider = context.read<AppProvider>();
    final Map<int, bool> status = {};
    for (var result in _results) {
      final isUpToDate = await provider.isPayrollUpToDate(
        result.employeeId,
        _selectedYear,
        _selectedMonth,
      );
      status[result.employeeId] = isUpToDate;
    }
    if (!mounted) return;
    setState(() {
      _upToDateStatus = status;
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

  Future<void> _calculateAll() async {
    if (_isCalculatingAll) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Массовый расчёт зарплаты'),
        content: Text(
          'Рассчитать зарплату для всех сотрудников за ${DateFormat('LLLL yyyy', 'ru').format(DateTime(_selectedYear, _selectedMonth))}?',
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Рассчитать',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCalculatingAll = true);
    if (!mounted) return;
    try {
      final provider = context.read<AppProvider>();
      await provider.calculatePayrollForMonth(_selectedYear, _selectedMonth);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Зарплата рассчитана для всех сотрудников'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка расчёта: $e')));
    } finally {
      if (mounted) setState(() => _isCalculatingAll = false);
    }
  }

  Future<void> _recalculateSingle(int employeeId) async {
    if (_calculatingSingle.contains(employeeId)) return;
    setState(() => _calculatingSingle.add(employeeId));
    try {
      final provider = context.read<AppProvider>();
      await provider.recalculateSingleEmployee(
        employeeId,
        _selectedYear,
        _selectedMonth,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сотрудник пересчитан')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка пересчёта: $e')));
    } finally {
      if (mounted) setState(() => _calculatingSingle.remove(employeeId));
    }
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
      appBar: AppBar(
        title: const Text('Отчёты по зарплате'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadData();
              });
            },
            tooltip: 'Предыдущий месяц',
          ),
          GestureDetector(
            onTap: _selectMonth,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  capitalizedMonth,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadData();
              });
            },
            tooltip: 'Следующий месяц',
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _goToToday,
            tooltip: 'Текущий месяц',
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _isCalculatingAll ? null : _calculateAll,
            tooltip: 'Рассчитать зарплату за месяц',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
          const SizedBox(width: 8),
        ],
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
                    'Нажмите "Рассчитать" для расчёта',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width:
                    _colNum +
                    _colEmployee +
                    _colDays +
                    _colSalary +
                    _colBonus +
                    _colPayments +
                    _colBalance +
                    _colActions +
                    32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTableHeader(),
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 180,
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
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
          SizedBox(
            width: _colDays,
            child: Text('Отработано', style: headerStyle()),
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
    final isUpToDate = _upToDateStatus[result.employeeId] ?? false;
    final totalPaid = _paymentsByEmployee[result.employeeId] ?? 0.0;
    final bonus = _bonusByEmployee[result.employeeId] ?? 0.0;
    final totalDays = result.baseDays + result.fieldDays;
    final balance = result.totalSalary + bonus - totalPaid;

    final daysFormat = NumberFormat('#,##0.0', 'ru');
    final currencyFormat = NumberFormat('#,##0.00', 'ru');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        color: isUpToDate ? null : Colors.orange[50],
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
                Text(
                  employee.position,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            width: _colDays,
            child: Text(
              '${daysFormat.format(totalDays)} дн.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: _colSalary,
            child: Text(
              '${currencyFormat.format(result.totalSalary)} ₽',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                color: balance > 0 ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _colActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isUpToDate)
                  IconButton(
                    icon: _calculatingSingle.contains(result.employeeId)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.orange,
                          ),
                    onPressed: _calculatingSingle.contains(result.employeeId)
                        ? null
                        : () => _recalculateSingle(result.employeeId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Пересчитать',
                  ),
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_upToDateStatus.containsKey(result.employeeId)
                        ? Colors.grey
                        : isUpToDate
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
