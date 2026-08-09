import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../widgets/timesheet_record_dialog.dart';
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
      provider.loadEmployees();
      provider.loadWorkTypes();
      provider.loadWorkSites();
      provider.loadWorkScheduleTypes();
      provider.loadAllEmployeeSchedules();
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

          return _TimesheetGrid(
            employees: provider.employees,
            records: provider.timesheetRecords,
            workTypes: provider.workTypes,
            workSites: provider.workSites,
            machinery: provider.machinery,
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

class _TimesheetGrid extends StatefulWidget {
  final List<Employee> employees;
  final List<TimesheetRecord> records;
  final List<WorkType> workTypes;
  final List<WorkSite> workSites;
  final List<Machinery> machinery;
  final DateTime selectedMonth;
  final int daysInMonth;
  final void Function(Employee, int) onCellTap;

  const _TimesheetGrid({
    required this.employees,
    required this.records,
    required this.workTypes,
    required this.workSites,
    required this.machinery,
    required this.selectedMonth,
    required this.daysInMonth,
    required this.onCellTap,
  });

  @override
  State<_TimesheetGrid> createState() => _TimesheetGridState();
}

class _TimesheetGridState extends State<_TimesheetGrid> {
  String _getShortName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return fullName;
    if (parts.length == 1) return parts[0];
    final surname = parts[0];
    final initials = parts
        .skip(1)
        .map((p) => p.isNotEmpty ? '${p[0]}.' : '')
        .join(' ');
    return '$surname $initials';
  }

  @override
  Widget build(BuildContext context) {
    const employeeColumnWidth = 152.0;
    const dayColumnWidth = 51.0;
    const cellHeight = 46.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(employeeColumnWidth, dayColumnWidth, cellHeight),
          ...widget.employees.map((employee) {
            return _buildEmployeeRow(
              employee,
              employeeColumnWidth,
              dayColumnWidth,
              cellHeight,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(
    double employeeWidth,
    double dayWidth,
    double cellHeight,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Row(
        children: [
          Container(
            width: employeeWidth,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Сотрудник',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
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
              width: dayWidth,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
                      fontSize: 13,
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
          Container(
            width: dayWidth,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Text(
              'Итого',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    double cellHeight,
  ) {
    double totalHours = 0;
    for (final record in widget.records) {
      if (record.employeeId == employee.id) {
        totalHours += record.hoursWorked;
      }
    }

    final shortName = _getShortName(employee.fullName);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Container(
            width: employeeWidth,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  employee.position,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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

            final record = widget.records.firstWhere(
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

            return _TimesheetCell(
              record: record,
              dayWidth: dayWidth,
              cellHeight: cellHeight,
              isWeekend: isWeekend,
              employeeId: employee.id!,
              workTypes: widget.workTypes,
              workSites: widget.workSites,
              machinery: widget.machinery,
              employeeName: employee.fullName,
              onDoubleTap: () => widget.onCellTap(employee, day),
            );
          }),
          Container(
            width: dayWidth,
            height: cellHeight,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Center(
              child: Text(
                totalHours.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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

class _TimesheetCell extends StatelessWidget {
  final TimesheetRecord record;
  final double dayWidth;
  final double cellHeight;
  final bool isWeekend;
  final int employeeId;
  final List<WorkType> workTypes;
  final List<WorkSite> workSites;
  final List<Machinery> machinery;
  final String employeeName;
  final VoidCallback onDoubleTap;

  const _TimesheetCell({
    required this.record,
    required this.dayWidth,
    required this.cellHeight,
    required this.isWeekend,
    required this.employeeId,
    required this.workTypes,
    required this.workSites,
    required this.machinery,
    required this.employeeName,
    required this.onDoubleTap,
  });

  bool get hasExtraData {
    return record.overtimeHours != null && record.overtimeHours! > 0 ||
        record.workTypeId != null ||
        record.workSiteId != null ||
        record.machineryId != null ||
        (record.quantityDone != null && record.quantityDone! > 0) ||
        (record.pieceworkRate != null && record.pieceworkRate! > 0) ||
        (record.bonus != null && record.bonus! > 0) ||
        (record.penalty != null && record.penalty! > 0) ||
        (record.weatherCondition != null &&
            record.weatherCondition!.isNotEmpty) ||
        (record.notes != null && record.notes!.isNotEmpty);
  }

  String get tooltipText {
    final buffer = StringBuffer();
    buffer.writeln(
      '$employeeName, ${DateFormat('dd.MM.yyyy').format(record.date)}',
    );
    buffer.writeln('Отработано: ${record.hoursWorked.toStringAsFixed(1)} ч');
    if (record.overtimeHours != null && record.overtimeHours! > 0) {
      buffer.writeln(
        'Переработка: ${record.overtimeHours!.toStringAsFixed(1)} ч',
      );
    }
    if (record.workTypeId != null) {
      final wt = workTypes.firstWhere(
        (t) => t.id == record.workTypeId,
        orElse: () => WorkType(name: 'Неизвестно', category: ''),
      );
      buffer.writeln('Вид работы: ${wt.name} (${wt.categoryName})');
    }
    if (record.workSiteId != null) {
      final ws = workSites.firstWhere(
        (s) => s.id == record.workSiteId,
        orElse: () => WorkSite(name: 'Неизвестно'),
      );
      buffer.writeln('Участок: ${ws.name}');
    }
    if (record.machineryId != null) {
      final m = machinery.firstWhere(
        (m) => m.id == record.machineryId,
        orElse: () => Machinery(name: 'Неизвестно', type: ''),
      );
      buffer.writeln('Техника: ${m.name} (${m.typeName})');
    }
    if (record.quantityDone != null && record.quantityDone! > 0) {
      buffer.writeln(
        'Объём: ${record.quantityDone!.toStringAsFixed(2)} ${record.quantityUnit ?? ''}',
      );
    }
    if (record.pieceworkRate != null && record.pieceworkRate! > 0) {
      buffer.writeln('Расценка: ${record.pieceworkRate!.toStringAsFixed(2)} ₽');
    }
    if (record.bonus != null && record.bonus! > 0) {
      buffer.writeln('Надбавка: ${record.bonus!.toStringAsFixed(2)} ₽');
    }
    if (record.penalty != null && record.penalty! > 0) {
      buffer.writeln('Удержание: ${record.penalty!.toStringAsFixed(2)} ₽');
    }
    if (record.weatherCondition != null &&
        record.weatherCondition!.isNotEmpty) {
      buffer.writeln('Погода: ${record.weatherCondition}');
    }
    if (record.notes != null && record.notes!.isNotEmpty) {
      buffer.writeln('Примечания: ${record.notes}');
    }
    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecord = record.id != null;
    final hours = record.hoursWorked;

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final future = provider.getEmployeeStatusOnDate(
          employeeId,
          record.date,
        );

        return FutureBuilder<WorkStatus>(
          future: future,
          builder: (context, snapshot) {
            Color? backgroundColor;
            Widget? content;
            String? statusText;

            // Проверяем статус
            WorkStatus? status;
            if (snapshot.hasData) {
              status = snapshot.data!;
            }

            // Если есть запись с часами > 0
            if (hasRecord && hours > 0) {
              // Показываем часы и переработку, фон зелёный
              backgroundColor = Colors.green[50];
              content = Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hours.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (record.overtimeHours != null &&
                          record.overtimeHours! > 0)
                        Text(
                          '+${record.overtimeHours!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              );
              statusText = 'Отработано: ${hours.toStringAsFixed(1)} ч';
            } else if (hasRecord && hours == 0) {
              // Запись есть, но часы равны 0 (редкий случай) – оранжевый фон и иконка "минус"
              backgroundColor = Colors.orange[50];
              content = Center(
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 15,
                  color: Colors.orange[400],
                ),
              );
              statusText = 'Запись без часов';
            } else {
              // Нет записи (hasRecord == false)
              // Определяем фон и содержимое на основе статуса
              if (status == WorkStatus.regularWork ||
                  status == WorkStatus.exceptionWork) {
                // Рабочая смена по графику – тёмно-синий фон и буква "Г"
                backgroundColor = Colors.blue[900];
                content = Center(
                  child: Text(
                    'Г',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
                statusText = 'Смена по графику';
              } else {
                // Выходной по графику или неизвестно – без фона и без содержимого
                backgroundColor = null;
                content = null;
                statusText = null;
              }
            }

            // Если фон не определён и это выходной (weekend) – можно установить серый фон,
            // но по заданию мы убираем серый для выходных по графику. Однако для обычных выходных (без графика) оставляем?
            // Обычные выходные (isWeekend) мы ранее выделяли серым фоном, но это для всех сотрудников.
            // Теперь мы убираем серый для rest по графику, но для обычных выходных (isWeekend) можно оставить лёгкий фон.
            // Но так как мы переопределили фон для всех случаев, для unknown и isWeekend оставляем стандартный фон.
            if (backgroundColor == null && isWeekend) {
              backgroundColor = Colors.grey[100];
            }

            // Формируем tooltip
            String tooltipMessage = '';
            if (hasRecord && hours > 0) {
              tooltipMessage = tooltipText;
            } else if (statusText != null) {
              tooltipMessage =
                  '$employeeName, ${DateFormat('dd.MM.yyyy').format(record.date)}\n$statusText';
            }

            return GestureDetector(
              onDoubleTap: onDoubleTap,
              child: Tooltip(
                message: tooltipMessage,
                preferBelow: false,
                verticalOffset: 20,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                child: Container(
                  width: dayWidth,
                  height: cellHeight,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border(left: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Stack(
                    children: [
                      ?content,
                      // Красный уголок, если есть дополнительные данные
                      if (hasRecord && hours > 0 && hasExtraData)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
