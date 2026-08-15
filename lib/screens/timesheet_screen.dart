// lib/screens/timesheet_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/timesheet_record_dialog.dart';
import '../widgets/common_widgets.dart';
import '../utils/string_utils.dart';
import '../widgets/daily_timesheet_dialog.dart';

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
      provider.loadEmployees(activeOnly: true);
      _loadTimesheet();
    });
  }

  void _loadTimesheet() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    context.read<AppProvider>().loadTimesheet(start, end);
  }

  void _goToToday() {
    setState(() {
      _selectedMonth = DateTime.now();
    });
    _loadTimesheet();
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите месяц и год',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadTimesheet();
    }
  }

  void _showDailyInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DailyTimesheetDialog(
        initialDate: DateTime.now(),
        onSaved: _loadTimesheet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('LLLL yyyy', 'ru').format(_selectedMonth);
    final capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);
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
              child: GestureDetector(
                onTap: _selectMonth,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
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
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _goToToday,
            tooltip: 'Текущий месяц',
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () => _showDailyInputDialog(context),
            tooltip: 'Быстрый ввод за день',
          ),
          const SizedBox(width: 8),
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

          return Column(
            children: [
              Expanded(
                child: _TimesheetGrid(
                  employees: provider.employees,
                  records: provider.timesheetRecords,
                  selectedMonth: _selectedMonth,
                  daysInMonth: daysInMonth,
                  onCellTap: (employee, day) => _showRecordDialog(
                    context,
                    employee,
                    DateTime(_selectedMonth.year, _selectedMonth.month, day),
                  ),
                ),
              ),
              _buildLegend(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _legendItem('1 / 0.5', Colors.green[50]!),
          _legendItem('Б', Colors.blue[50]!),
          _legendItem('О', Colors.purple[50]!),
          _legendItem('В', Colors.grey[200]!),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label == '1 / 0.5'
              ? '— Работа (база/поле)'
              : label == 'Б'
              ? '— Больничный'
              : label == 'О'
              ? '— Отпуск'
              : '— Выходной',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _showRecordDialog(
    BuildContext context,
    Employee employee,
    DateTime date,
  ) {
    final provider = context.read<AppProvider>();
    final existingRecord = provider.timesheetRecords.firstWhere(
      (r) =>
          r.employeeId == employee.id &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
      orElse: () => TimesheetRecord(
        employeeId: employee.id!,
        date: date,
        dayType: 'work',
        days: 0,
      ),
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

class _TimesheetGrid extends StatefulWidget {
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
  State<_TimesheetGrid> createState() => _TimesheetGridState();
}

class _TimesheetGridState extends State<_TimesheetGrid> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const employeeColumnWidth = 160.0;
    const dayColumnWidth = 40.0;
    const cellHeight = 40.0;

    const extraColumns = 3;
    const extraWidth = dayColumnWidth * extraColumns;
    final rightPartWidth =
        (widget.daysInMonth * dayColumnWidth) + dayColumnWidth + extraWidth;

    Widget leftPart = SizedBox(
      width: employeeColumnWidth,
      child: Column(
        children: [
          Container(
            height: cellHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Text(
              'Сотрудник',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _verticalScrollController,
              itemCount: widget.employees.length,
              itemBuilder: (context, index) {
                final employee = widget.employees[index];
                return Container(
                  height: cellHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        StringUtils.getShortName(employee.fullName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
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
                );
              },
            ),
          ),
        ],
      ),
    );

    Widget rightPart = Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: rightPartWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: cellHeight,
                child: Row(
                  children: [
                    ...List.generate(widget.daysInMonth, (index) {
                      final day = index + 1;
                      final date = DateTime(
                        widget.selectedMonth.year,
                        widget.selectedMonth.month,
                        day,
                      );
                      final isWeekend =
                          date.weekday == DateTime.saturday ||
                          date.weekday == DateTime.sunday;
                      final isToday =
                          date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      return Container(
                        width: dayColumnWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.blue[50]
                              : isWeekend
                              ? Colors.red[50]
                              : null,
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: isWeekend ? Colors.red : null,
                              ),
                            ),
                            Text(
                              _getWeekdayShort(date.weekday),
                              style: TextStyle(
                                fontSize: 8,
                                color: isWeekend
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Container(
                      width: dayColumnWidth,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Раб.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: dayColumnWidth,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Вых.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: dayColumnWidth,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Бол.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: dayColumnWidth,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Отп.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: widget.employees.length * cellHeight,
                child: ListView.builder(
                  controller: _verticalScrollController,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) {
                    final employee = widget.employees[index];

                    double totalWorkDays = 0;
                    double totalSickDays = 0;
                    double totalVacationDays = 0;
                    double totalDayoffDays = 0; // изменено на double

                    for (final record in widget.records) {
                      if (record.employeeId == employee.id) {
                        if (record.dayType == 'work') {
                          totalWorkDays += record.days;
                        } else if (record.dayType == 'sick') {
                          totalSickDays += record.days;
                        } else if (record.dayType == 'vacation') {
                          totalVacationDays += record.days;
                        } else if (record.dayType == 'dayoff') {
                          totalDayoffDays +=
                              record.days; // теперь суммируем days
                        }
                      }
                    }

                    List<Widget> dayCells = [];
                    for (int i = 0; i < widget.daysInMonth; i++) {
                      final day = i + 1;
                      final date = DateTime(
                        widget.selectedMonth.year,
                        widget.selectedMonth.month,
                        day,
                      );
                      final record = widget.records.firstWhere(
                        (r) =>
                            r.employeeId == employee.id &&
                            r.date.year == date.year &&
                            r.date.month == date.month &&
                            r.date.day == date.day,
                        orElse: () => TimesheetRecord(
                          employeeId: employee.id!,
                          date: date,
                          dayType: 'work',
                          days: 0,
                        ),
                      );
                      dayCells.add(
                        _TimesheetCell(
                          record: record,
                          dayWidth: dayColumnWidth,
                          cellHeight: cellHeight,
                          onDoubleTap: () => widget.onCellTap(employee, day),
                        ),
                      );
                    }

                    dayCells.add(
                      Container(
                        width: dayColumnWidth,
                        height: cellHeight,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            totalWorkDays.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );

                    dayCells.add(
                      Container(
                        width: dayColumnWidth,
                        height: cellHeight,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            totalDayoffDays.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );

                    dayCells.add(
                      Container(
                        width: dayColumnWidth,
                        height: cellHeight,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            totalSickDays.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );

                    dayCells.add(
                      Container(
                        width: dayColumnWidth,
                        height: cellHeight,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            totalVacationDays.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );

                    return Container(
                      height: cellHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(children: dayCells),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [leftPart, rightPart],
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }
}

class _TimesheetCell extends StatelessWidget {
  final TimesheetRecord record;
  final double dayWidth;
  final double cellHeight;
  final VoidCallback onDoubleTap;

  const _TimesheetCell({
    required this.record,
    required this.dayWidth,
    required this.cellHeight,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = record.id != null;

    String displayText = '';
    Color backgroundColor = Colors.transparent;
    Color textColor = Colors.black87;

    if (hasRecord) {
      if (record.dayType == 'work') {
        if (record.days > 0) {
          displayText = record.days == 0.5 ? '0.5' : '1';
          backgroundColor = Colors.green[50]!;
        }
      } else if (record.dayType == 'sick') {
        displayText = 'Б';
        backgroundColor = Colors.blue[50]!;
      } else if (record.dayType == 'vacation') {
        displayText = 'О';
        backgroundColor = Colors.purple[50]!;
      } else if (record.dayType == 'dayoff') {
        displayText = 'В';
        backgroundColor = Colors.grey[200]!;
      }
    }

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: dayWidth,
        height: cellHeight,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(left: BorderSide(color: Colors.grey[300]!)),
        ),
        alignment: Alignment.center,
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
