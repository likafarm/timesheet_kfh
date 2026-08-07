import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';

/// Экран отчётов и расчёта зарплаты
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
  bool _isLoading = false;

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

    setState(() => _isLoading = true);
    try {
      final db = DatabaseService();
      final data = await db.calculateMonthlySalary(
        _selectedEmployeeId!,
        _selectedYear,
        _selectedMonth,
      );
      setState(() => _reportData = data);
    } finally {
      setState(() => _isLoading = false);
    }
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
            // Панель фильтров
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Выбор сотрудника
                    SizedBox(
                      width: 250,
                      child: Consumer<AppProvider>(
                        builder: (context, provider, child) {
                          return InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Сотрудник',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedEmployeeId,
                                isDense: true,
                                isExpanded: true,
                                hint: const Text('Выберите...'),
                                items: provider.employees.map((e) {
                                  return DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.fullName),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() {
                                  _selectedEmployeeId = v;
                                  _reportData = null;
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Выбор месяца
                    SizedBox(
                      width: 150,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Месяц',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedMonth,
                            isDense: true,
                            isExpanded: true,
                            items: _months.map((m) {
                              return DropdownMenuItem(
                                value: m['value'] as int,
                                child: Text(m['name'] as String),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() {
                              _selectedMonth = v!;
                              _reportData = null;
                            }),
                          ),
                        ),
                      ),
                    ),
                    // Выбор года
                    SizedBox(
                      width: 120,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Год',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isDense: true,
                            isExpanded: true,
                            items: _years.map((y) {
                              return DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() {
                              _selectedYear = v!;
                              _reportData = null;
                            }),
                          ),
                        ),
                      ),
                    ),
                    // Кнопка расчёта
                    ElevatedButton.icon(
                      onPressed: _selectedEmployeeId != null
                          ? _generateReport
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate),
                      label: const Text('Рассчитать'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Результаты
            if (_reportData != null) _ReportCard(data: _reportData!),
          ],
        ),
      ),
    );
  }
}

/// Карточка отчёта по зарплате
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final employee = data['employee'] as Employee;
    final totalHours = data['totalHours'] as double;
    final totalOvertime = data['totalOvertime'] as double;
    final totalQuantity = data['totalQuantity'] as double;
    final totalPiecework = data['totalPiecework'] as double;
    final totalSalary = data['totalSalary'] as double;
    final totalPaid = data['totalPaid'] as double;
    final balance = data['balance'] as double;

    final currencyFormat = NumberFormat('#,##0.00', 'ru');
    final hoursFormat = NumberFormat('#,##0.0', 'ru');

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
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

              // Детализация
              _ReportRow('Всего часов:', hoursFormat.format(totalHours)),
              _ReportRow('Переработка:', hoursFormat.format(totalOvertime)),
              if (totalQuantity > 0)
                _ReportRow(
                  'Сдельный объём:',
                  hoursFormat.format(totalQuantity),
                ),
              if (totalPiecework > 0)
                _ReportRow(
                  'Сдельная оплата:',
                  '${currencyFormat.format(totalPiecework)} ₽',
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

              // Кнопки экспорта
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print),
                    label: const Text('Печать'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка отчёта
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
