import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/timesheet_record_dialog.dart';

/// Экран табеля учёта рабочего времени
/// Календарная сетка: строки = сотрудники, столбцы = дни месяца
class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadEmployees();
      provider.loadWorkTypes();
      provider.loadWorkSites();
      _loadTimesheet();
    });
  }

  void _loadTimesheet() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    context.read<AppProvider>().loadTimesheet(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'ru').format(_selectedMonth);
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Табель учёта времени'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
              _loadTimesheet();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                monthName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
              _loadTimesheet();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.employees.isEmpty) {
            return const Center(
              child: Text(
                'Нет сотрудников.\nДобавьте сотрудников в разделе "Сотрудники".',
                textAlign: TextAlign.center,
              ),
            );
          }

          return _TimesheetGrid(
            employees: provider.employees,
            records: provider.timesheetRecords,
            selectedMonth: _selectedMonth,
            daysInMonth: daysInMonth,
            onCellTap: (employee, day) => _showRecordDialog(
              context,
              employee,
              DateTime(_selectedMonth.year, _selectedMonth.month, day),
            ),
          );
        },
      ),
    );
  }

  void _showRecordDialog(
    BuildContext context,
    Employee employee,
    DateTime date,
  ) {
    // Ищем существующую запись
    final provider = context.read<AppProvider>();
    final existingRecord = provider.timesheetRecords.firstWhere(
      (r) =>
          r.employeeId == employee.id &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
      orElse: () =>
          TimesheetRecord(employeeId: employee.id!, date: date, hoursWorked: 0),
    );

    showDialog(
      context: context,
      builder: (context) => TimesheetRecordDialog(
        employee: employee,
        record: existingRecord.id != null ? existingRecord : null,
        defaultDate: date,
      ),
    );
  }
}

/// Календарная сетка табеля
class _TimesheetGrid extends StatelessWidget {
  final List<Employee> employees;
  final List<TimesheetRecord> records;
  final DateTime selectedMonth;
  final int daysInMonth;
  final void Function(Employee, int) onCellTap;

  const _TimesheetGrid({
    required this.employees,
    required this.records,
    required this.selectedMonth,
    required this.daysInMonth,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    // Фиксированная ширина столбцов
    const employeeColumnWidth = 200.0;
    const dayColumnWidth = 50.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с днями месяца
          _buildHeader(employeeColumnWidth, dayColumnWidth),
          // Строки сотрудников
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: employees.map((employee) {
                  return _buildEmployeeRow(
                    employee,
                    employeeColumnWidth,
                    dayColumnWidth,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double employeeWidth, double dayWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Row(
        children: [
          // Колонка сотрудника
          Container(
            width: employeeWidth,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Сотрудник',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Колонки дней
          ...List.generate(daysInMonth, (index) {
            final day = index + 1;
            final date = DateTime(selectedMonth.year, selectedMonth.month, day);
            final isWeekend =
                date.weekday == DateTime.saturday ||
                date.weekday == DateTime.sunday;
            final isToday =
                date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;

            return Container(
              width: dayWidth,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.blue[100]
                    : isWeekend
                    ? Colors.red[50]
                    : null,
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isWeekend ? Colors.red : null,
                    ),
                  ),
                  Text(
                    _getWeekdayShort(date.weekday),
                    style: TextStyle(
                      fontSize: 10,
                      color: isWeekend ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }),
          // Колонка итого
          Container(
            width: dayWidth,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Text(
              'Итого',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(
    Employee employee,
    double employeeWidth,
    double dayWidth,
  ) {
    // Считаем итого часов за месяц
    double totalHours = 0;
    for (final record in records) {
      if (record.employeeId == employee.id) {
        totalHours += record.hoursWorked;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Имя сотрудника
          Container(
            width: employeeWidth,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  employee.position,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Ячейки дней
          ...List.generate(daysInMonth, (index) {
            final day = index + 1;
            final date = DateTime(selectedMonth.year, selectedMonth.month, day);
            final isWeekend =
                date.weekday == DateTime.saturday ||
                date.weekday == DateTime.sunday;

            // Ищем запись для этого дня
            final record = records.firstWhere(
              (r) =>
                  r.employeeId == employee.id &&
                  r.date.year == date.year &&
                  r.date.month == date.month &&
                  r.date.day == date.day,
              orElse: () => TimesheetRecord(
                employeeId: employee.id!,
                date: date,
                hoursWorked: 0,
              ),
            );

            final hasRecord = record.id != null;
            final hours = record.hoursWorked;

            return GestureDetector(
              onTap: () => onCellTap(employee, day),
              child: Container(
                width: dayWidth,
                height: 50,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: hasRecord
                      ? (hours > 0 ? Colors.green[50] : Colors.orange[50])
                      : isWeekend
                      ? Colors.grey[100]
                      : null,
                  border: Border(left: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Center(
                  child: hasRecord && hours > 0
                      ? Text(
                          hours.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hours > 0 ? Colors.green[800] : null,
                          ),
                        )
                      : hasRecord
                      ? Icon(
                          Icons.remove_circle_outline,
                          size: 14,
                          color: Colors.orange[400],
                        )
                      : null,
                ),
              ),
            );
          }),
          // Итого
          Container(
            width: dayWidth,
            height: 50,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Center(
              child: Text(
                totalHours.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }
}
