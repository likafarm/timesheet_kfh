import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../utils/string_utils.dart'; // <-- импорт

/// Экран отчётов и расчёта зарплаты (дни)
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int? _selectedEmployeeId;
  Map<String, dynamic>? _reportData;

  final List<int> _years = List.generate(
    10,
    (i) => DateTime.now().year - 5 + i,
  );

  final List<Map<String, dynamic>> _months = [
    {'value': 1, 'name': 'Январь'},
    {'value': 2, 'name': 'Февраль'},
    {'value': 3, 'name': 'Март'},
    {'value': 4, 'name': 'Апрель'},
    {'value': 5, 'name': 'Май'},
    {'value': 6, 'name': 'Июнь'},
    {'value': 7, 'name': 'Июль'},
    {'value': 8, 'name': 'Август'},
    {'value': 9, 'name': 'Сентябрь'},
    {'value': 10, 'name': 'Октябрь'},
    {'value': 11, 'name': 'Ноябрь'},
    {'value': 12, 'name': 'Декабрь'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadEmployees();
    });
  }

  Future<void> _generateReport() async {
    if (_selectedEmployeeId == null) return;

    try {
      final provider = context.read<AppProvider>();
      final data = await provider.calculateMonthlySalary(
        _selectedEmployeeId!,
        _selectedYear,
        _selectedMonth,
      );
      setState(() => _reportData = data);
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёты и расчёт зарплаты'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: Consumer<AppProvider>(
                      builder: (context, provider, child) {
                        final items = <DropdownMenuItem<int>>[
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Выберите...'),
                          ),
                          ...provider.employees.map((e) {
                            return DropdownMenuItem<int>(
                              value: e.id,
                              child: Text(StringUtils.getShortName(e.fullName)),
                            );
                          }),
                        ];
                        return AppDropdown<int>(
                          value: _selectedEmployeeId,
                          items: items,
                          onChanged: (value) {
                            setState(() {
                              _selectedEmployeeId = value;
                              _reportData = null;
                            });
                          },
                          labelText: 'Сотрудник',
                          prefixIcon: Icons.person,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: AppDropdown<int>(
                      value: _selectedMonth,
                      items: _months.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['value'] as int,
                          child: Text(m['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMonth = value!;
                          _reportData = null;
                        });
                      },
                      labelText: 'Месяц',
                      prefixIcon: Icons.calendar_today,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: AppDropdown<int>(
                      value: _selectedYear,
                      items: _years.map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text(y.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear = value!;
                          _reportData = null;
                        });
                      },
                      labelText: 'Год',
                      prefixIcon: Icons.date_range,
                    ),
                  ),
                  AppButton(
                    label: 'Рассчитать',
                    icon: Icons.calculate,
                    onPressed: _selectedEmployeeId != null
                        ? _generateReport
                        : null,
                    width: 160,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_reportData != null) _ReportCard(data: _reportData!),
          ],
        ),
      ),
    );
  }
}

/// Карточка отчёта по зарплате (дни)
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final employee = data['employee'] as Employee;
    final totalBaseDays = data['totalBaseDays'] as double;
    final totalFieldDays = data['totalFieldDays'] as double;
    final sickDays = data['sickDays'] as double;
    final vacationDays = data['vacationDays'] as double;
    final baseRate = data['baseRate'] as double;
    final fieldRate = data['fieldRate'] as double;
    final totalSalary = data['totalSalary'] as double;
    final totalPaid = data['totalPaid'] as double;
    final balance = data['balance'] as double;

    final currencyFormat = NumberFormat('#,##0.00', 'ru');
    final daysFormat = NumberFormat('#,##0.0', 'ru');

    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    employee.fullName.substring(0, 1),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        employee.position,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _ReportRow('Дней на базе:', daysFormat.format(totalBaseDays)),
            _ReportRow('Дней в поле:', daysFormat.format(totalFieldDays)),
            _ReportRow('Больничные дни:', daysFormat.format(sickDays)),
            _ReportRow('Отпускные дни:', daysFormat.format(vacationDays)),
            _ReportRow(
              'Ставка (база):',
              '${currencyFormat.format(baseRate)} ₽/день',
            ),
            _ReportRow(
              'Ставка (поле):',
              '${currencyFormat.format(fieldRate)} ₽/день',
            ),
            const Divider(height: 24),
            _ReportRow(
              'Начислено:',
              '${currencyFormat.format(totalSalary)} ₽',
              valueColor: Colors.green,
            ),
            _ReportRow(
              'Выплачено:',
              '${currencyFormat.format(totalPaid)} ₽',
              valueColor: Colors.blue,
            ),
            const Divider(height: 24),
            _ReportRow(
              'Остаток к выплате:',
              '${currencyFormat.format(balance)} ₽',
              valueColor: balance > 0 ? Colors.orange : Colors.green,
              isBold: true,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Печать',
                  icon: Icons.print,
                  isOutlined: true,
                  onPressed: () {},
                  width: 120,
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf,
                  isOutlined: true,
                  onPressed: () {},
                  width: 120,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _ReportRow(
    this.label,
    this.value, {
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
