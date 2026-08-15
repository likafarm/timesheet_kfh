// lib/widgets/daily_timesheet_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/string_utils.dart';
import '../widgets/common_widgets.dart';

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

  Map<int, bool> _selected = {};
  Map<int, String> _dayTypes = {};
  Map<int, double> _dayCounts = {};
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
  final List<double> _dayCountOptions = [0.0, 0.5, 1.0];
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
        // Для всех типов дней, кроме work, ставим 1 день, для work оставляем как есть
        double days = record.days;
        if (record.dayType == 'work') {
          if (!_dayCountOptions.contains(days)) {
            days = 1.0;
          }
        } else {
          days = 1.0; // все нерабочие дни считаем как 1
        }
        _dayCounts[id] = days;
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
                                    ..._employees.asMap().entries.map((entry) {
                                      final index = entry.key + 1;
                                      final employee = entry.value;
                                      final id = employee.id!;
                                      final isSelected = _selected[id] ?? false;
                                      final dayType = _dayTypes[id]!;
                                      final dayCount = _dayCounts[id]!;
                                      final workPlace = _workPlaces[id];

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
                                                          // При смене типа корректируем дни
                                                          if (value ==
                                                              'dayoff') {
                                                            _dayCounts[id] =
                                                                1.0;
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
                                                items: _dayCountOptions.map((
                                                  d,
                                                ) {
                                                  String label = d == 0.0
                                                      ? '0'
                                                      : d.toStringAsFixed(1);
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

    for (var emp in _employees) {
      final id = emp.id!;
      if (_selected[id] == true) {
        final dayType = _dayTypes[id]!;
        final days = _dayCounts[id]!;
        final workPlace = _workPlaces[id];

        // Определяем итоговое количество дней для сохранения
        double finalDays;
        if (dayType == 'work') {
          finalDays = days; // 0.5 или 1
        } else {
          finalDays = 1.0; // для всех нерабочих дней – 1 целый день
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
