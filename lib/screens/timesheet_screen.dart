import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/timesheet_record_dialog.dart';
import '../widgets/common_widgets.dart';
import '../utils/string_utils.dart';

/// Экран табеля учёта времени (дни)
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

/// Календарная сетка табеля с фиксированной колонкой "Сотрудник"
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

    // Добавляем три дополнительные колонки: выходные, больничные, отпуска
    const extraColumns = 3;
    const extraWidth = dayColumnWidth * extraColumns;
    final rightPartWidth =
        (widget.daysInMonth * dayColumnWidth) + dayColumnWidth + extraWidth;

    // Левая фиксированная часть: заголовок "Сотрудник" + список сотрудников
    Widget leftPart = SizedBox(
      width: employeeColumnWidth,
      child: Column(
        children: [
          // Заголовок "Сотрудник"
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
          // Список сотрудников с вертикальной прокруткой
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

    // Правая часть: заголовок + строки с единой горизонтальной прокруткой
    Widget rightPart = Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: rightPartWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок дней + дополнительные колонки
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
                    // Колонка итого (рабочие дни)
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
                        'Работа',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Колонка выходные (целые дни)
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
                    // Колонка больничные (целые дни)
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
                    // Колонка отпуска (целые дни)
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
              // Строки сотрудников
              SizedBox(
                height: widget.employees.length * cellHeight,
                child: ListView.builder(
                  controller: _verticalScrollController,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) {
                    final employee = widget.employees[index];

                    // Подсчёт сумм по типам
                    double totalWorkDays = 0;
                    int totalSickDays = 0;
                    int totalVacationDays = 0;
                    int totalDayoffDays = 0;

                    for (final record in widget.records) {
                      if (record.employeeId == employee.id) {
                        if (record.dayType == 'work') {
                          totalWorkDays += record.days;
                        } else if (record.dayType == 'sick') {
                          totalSickDays += 1; // считаем количество записей
                        } else if (record.dayType == 'vacation') {
                          totalVacationDays += 1;
                        } else if (record.dayType == 'dayoff') {
                          totalDayoffDays += 1;
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

                    // Итоговые колонки
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
                            totalDayoffDays.toString(),
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
                            totalSickDays.toString(),
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
                            totalVacationDays.toString(),
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

/// Ячейка табеля (дни)
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
          if (record.days == 0.5) {
            displayText = '0.5';
          } else {
            displayText = '1';
          }
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

/// Диалог быстрого ввода табеля за день (с выбором сотрудников и проверкой существующих записей)
class DailyTimesheetDialog extends StatefulWidget {
  final DateTime initialDate;
  final VoidCallback onSaved;

  const DailyTimesheetDialog({
    super.key,
    required this.initialDate,
    required this.onSaved,
  });

  @override
  State<DailyTimesheetDialog> createState() => _DailyTimesheetDialogState();
}

class _DailyTimesheetDialogState extends State<DailyTimesheetDialog> {
  late DateTime _selectedDate;
  List<Employee> _employees = [];

  // Для каждого сотрудника храним: выбран ли, тип дня, количество дней, место работы
  // ignore: prefer_final_fields
  Map<int, bool> _selected = {};
  // ignore: prefer_final_fields
  Map<int, String> _dayTypes = {};
  // ignore: prefer_final_fields
  Map<int, double> _dayCounts = {};
  // ignore: prefer_final_fields
  Map<int, String?> _workPlaces = {};

  bool _isLoading = false;
  bool _allSelected = false;

  final List<String> _dayTypeOptions = ['work', 'sick', 'vacation', 'dayoff'];
  final List<String> _dayTypeLabels = [
    'Работа',
    'Больничный',
    'Отпуск',
    'Выходной',
  ];
  final List<double> _dayCountOptions = [0.0, 0.5, 1.0]; // для работы
  final List<String> _workPlaceOptions = ['base', 'field'];
  final List<String> _workPlaceLabels = ['База', 'Поле'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.loadEmployees(activeOnly: true);
      setState(() {
        _employees = provider.employees;
        for (var emp in _employees) {
          if (emp.id != null) {
            _selected[emp.id!] = true;
            _dayTypes[emp.id!] = 'work';
            _dayCounts[emp.id!] = 1.0;
            _workPlaces[emp.id!] = null;
          }
        }
        _allSelected = true;
        _loadExistingRecords();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingRecords() async {
    final provider = context.read<AppProvider>();
    final records = await provider.getTimesheetForDate(_selectedDate);
    for (var record in records) {
      final id = record.employeeId;
      if (_selected.containsKey(id)) {
        _selected[id] = true;
        _dayTypes[id] = record.dayType;
        // Устанавливаем корректные дни в зависимости от типа
        if (record.dayType == 'sick' || record.dayType == 'vacation') {
          _dayCounts[id] = 1.0;
        } else if (record.dayType == 'dayoff') {
          _dayCounts[id] = 0.0;
        } else {
          // work — сохраняем как есть
          double days = record.days;
          if (!_dayCountOptions.contains(days)) {
            days = 1.0;
          }
          _dayCounts[id] = days;
        }
        _workPlaces[id] = record.workPlace;
      }
    }
    setState(() {});
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _allSelected = value ?? false;
      for (var key in _selected.keys) {
        _selected[key] = _allSelected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_calendar),
          const SizedBox(width: 8),
          Text('Быстрый ввод за день'),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Выбор даты
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Дата'),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy').format(_selectedDate),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                        _loadExistingRecords();
                      }
                    },
                  ),
                  const Divider(),
                  // Таблица с фиксированной шириной и горизонтальной прокруткой
                  Expanded(
                    child: _employees.isEmpty
                        ? const Center(child: Text('Нет активных сотрудников'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 630,
                                child: Column(
                                  children: [
                                    // Шапка таблицы
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      color: Colors.grey[200],
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _allSelected,
                                            onChanged: _toggleSelectAll,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 20),
                                          const SizedBox(
                                            width: 30,
                                            child: Text(
                                              '№',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 150,
                                            child: Text(
                                              'ФИО',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 110,
                                            child: Text(
                                              'Тип дня',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 70,
                                            child: Text(
                                              'Дней',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 100,
                                            child: Text(
                                              'Место',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    // Строки сотрудников
                                    ..._employees.asMap().entries.map((entry) {
                                      final index = entry.key + 1;
                                      final employee = entry.value;
                                      final id = employee.id!;
                                      final isSelected = _selected[id] ?? false;
                                      final dayType = _dayTypes[id]!;
                                      final dayCount = _dayCounts[id]!;
                                      final workPlace = _workPlaces[id];

                                      // Определяем доступные варианты дней в зависимости от типа
                                      List<double> availableDays;
                                      if (dayType == 'work') {
                                        availableDays = [0.5, 1.0];
                                      } else if (dayType == 'sick' ||
                                          dayType == 'vacation') {
                                        availableDays = [1.0];
                                      } else {
                                        // dayoff
                                        availableDays = [0.0];
                                      }

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selected[id] =
                                                      value ?? false;
                                                  _allSelected = _selected
                                                      .values
                                                      .every((v) => v);
                                                });
                                              },
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            const SizedBox(width: 20),
                                            SizedBox(
                                              width: 30,
                                              child: Text(
                                                '$index',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                StringUtils.getShortName(
                                                  employee.fullName,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 110,
                                              child: DropdownButton<String>(
                                                value: dayType,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                items: _dayTypeOptions.map((e) {
                                                  final index = _dayTypeOptions
                                                      .indexOf(e);
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: e,
                                                    child: Text(
                                                      _dayTypeLabels[index],
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: isSelected
                                                    ? (value) {
                                                        setState(() {
                                                          _dayTypes[id] =
                                                              value!;
                                                          // При смене типа автоматически корректируем дни
                                                          if (value ==
                                                              'dayoff') {
                                                            _dayCounts[id] =
                                                                0.0;
                                                          } else if (value ==
                                                                  'sick' ||
                                                              value ==
                                                                  'vacation') {
                                                            _dayCounts[id] =
                                                                1.0;
                                                          } else {
                                                            _dayCounts[id] =
                                                                1.0; // work
                                                          }
                                                          // Сбрасываем место для нерабочих дней
                                                          if (value != 'work') {
                                                            _workPlaces[id] =
                                                                null;
                                                          }
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 70,
                                              child: DropdownButton<double>(
                                                value: dayCount,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                items: availableDays.map((d) {
                                                  String label = d == 0.0
                                                      ? '0'
                                                      : d == 0.5
                                                      ? '0.5'
                                                      : '1';
                                                  return DropdownMenuItem<
                                                    double
                                                  >(
                                                    value: d,
                                                    child: Text(
                                                      label,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged:
                                                    isSelected &&
                                                        dayType == 'work'
                                                    ? (value) {
                                                        setState(() {
                                                          _dayCounts[id] =
                                                              value!;
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 100,
                                              child: DropdownButton<String?>(
                                                value: workPlace,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                hint: const Text(
                                                  '—',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                items: [
                                                  const DropdownMenuItem<
                                                    String?
                                                  >(
                                                    value: null,
                                                    child: Text(
                                                      '—',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  ..._workPlaceOptions.map((e) {
                                                    final index =
                                                        _workPlaceOptions
                                                            .indexOf(e);
                                                    return DropdownMenuItem<
                                                      String?
                                                    >(
                                                      value: e,
                                                      child: Text(
                                                        _workPlaceLabels[index],
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                                onChanged:
                                                    isSelected &&
                                                        dayType == 'work'
                                                    ? (value) {
                                                        setState(() {
                                                          _workPlaces[id] =
                                                              value;
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        AppButton(
          label: 'Отмена',
          isText: true,
          width: 100,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(label: 'Сохранить', width: 100, onPressed: _save),
      ],
    );
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();

    final existingRecords = await provider.getTimesheetForDate(_selectedDate);

    List<Map<String, dynamic>> newEntries = [];
    List<Employee> selectedEmployees = [];

    bool hasError = false;

    for (var emp in _employees) {
      final id = emp.id!;
      if (_selected[id] == true) {
        final dayType = _dayTypes[id]!;
        final days = _dayCounts[id]!;
        final workPlace = _workPlaces[id];

        // Валидация: если тип "Работа", то место обязательно
        if (dayType == 'work' && workPlace == null) {
          hasError = true;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Для ${emp.fullName} укажите место работы (база/поле)',
              ),
            ),
          );
          break;
        }

        // Определяем итоговое количество дней для сохранения
        double finalDays;
        if (dayType == 'work') {
          finalDays = days; // 0.5 или 1
        } else if (dayType == 'sick' || dayType == 'vacation') {
          finalDays = 1.0; // всегда целый день
        } else {
          // dayoff
          finalDays = 0.0;
        }

        TimesheetRecord? existing;
        for (var r in existingRecords) {
          if (r.employeeId == id) {
            existing = r;
            break;
          }
        }

        newEntries.add({
          'employee': emp,
          'dayType': dayType,
          'days': finalDays,
          'workPlace': (dayType == 'work') ? workPlace : null,
          'existing': existing,
        });
        selectedEmployees.add(emp);
      }
    }

    if (hasError) return;

    if (selectedEmployees.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного сотрудника')),
      );
      return;
    }

    final conflicts = newEntries.where((e) => e['existing'] != null).toList();

    if (conflicts.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('У следующих сотрудников уже есть записи за этот день:');
      for (var c in conflicts) {
        final emp = c['employee'] as Employee;
        final existing = c['existing'] as TimesheetRecord;
        buffer.writeln('• ${emp.fullName}:');
        buffer.writeln('  Тип: ${_getDayTypeName(existing.dayType)}');
        if (existing.dayType == 'work') {
          buffer.writeln('  Дней: ${existing.days.toStringAsFixed(1)}');
          buffer.writeln(
            '  Место: ${existing.workPlace == 'base'
                ? 'База'
                : existing.workPlace == 'field'
                ? 'Поле'
                : '—'}',
          );
        }
        if (existing.notes != null && existing.notes!.isNotEmpty) {
          buffer.writeln('  Примечания: ${existing.notes}');
        }
      }
      buffer.writeln('\nПерезаписать существующие записи?');

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Внимание!'),
          content: SingleChildScrollView(child: Text(buffer.toString())),
          actions: [
            AppButton(
              label: 'Отмена',
              isText: true,
              width: 100,
              onPressed: () => Navigator.pop(context, false),
            ),
            AppButton(
              label: 'Перезаписать',
              width: 100,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }
    }

    List<TimesheetRecord> recordsToSave = [];
    for (var entry in newEntries) {
      final emp = entry['employee'] as Employee;
      final dayType = entry['dayType'] as String;
      final days = entry['days'] as double;
      final workPlace = entry['workPlace'] as String?;

      final record = TimesheetRecord(
        employeeId: emp.id!,
        date: _selectedDate,
        dayType: dayType,
        days: days,
        workPlace: workPlace,
      );
      recordsToSave.add(record);
    }

    await provider.saveDailyTimesheet(recordsToSave, _selectedDate);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
  }

  String _getDayTypeName(String type) {
    switch (type) {
      case 'work':
        return 'Работа';
      case 'sick':
        return 'Больничный';
      case 'vacation':
        return 'Отпуск';
      case 'dayoff':
        return 'Выходной';
      default:
        return type;
    }
  }
}
