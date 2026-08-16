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

  late final Map<int, bool> _selected;
  late final Map<int, String> _dayTypes;
  late final Map<int, double> _dayCounts;
  late final Map<int, String?> _workPlaces;
  final Map<int, String> _workPlaceErrors = {};

  bool _isLoading = false;
  bool _allSelected = false;
  bool _isSaving = false;

  final List<String> _dayTypeOptions = ['work', 'sick', 'vacation', 'dayoff'];
  final List<String> _dayTypeLabels = [
    'Работа',
    'Больничный',
    'Отпуск',
    'Выходной',
  ];
  final List<double> _dayCountOptions = [0.5, 1.0];
  final List<String> _workPlaceOptions = ['base', 'field'];
  final List<String> _workPlaceLabels = ['База', 'Поле'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selected = {};
    _dayTypes = {};
    _dayCounts = {};
    _workPlaces = {};
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
        double days = record.days;
        if (record.dayType == 'work') {
          if (!_dayCountOptions.contains(days)) {
            days = 1.0;
          }
        } else {
          days = 1.0;
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
                          _workPlaceErrors.clear();
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
                                      final hasError = _workPlaceErrors
                                          .containsKey(id);

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
                                          color: hasError
                                              ? Colors.red[50]
                                              : null,
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
                                                  if (value == true) {
                                                    _workPlaceErrors.remove(id);
                                                  }
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
                                            // Тип дня
                                            SizedBox(
                                              width: 110,
                                              child: DropdownButton<String>(
                                                value: dayType,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                items: _dayTypeOptions.map((e) {
                                                  final idx = _dayTypeOptions
                                                      .indexOf(e);
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: e,
                                                    child: Text(
                                                      _dayTypeLabels[idx],
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
                                                          _workPlaceErrors
                                                              .remove(id);
                                                          if (value == 'work') {
                                                            if (!_dayCountOptions
                                                                .contains(
                                                                  _dayCounts[id],
                                                                )) {
                                                              _dayCounts[id] =
                                                                  1.0;
                                                            }
                                                          } else {
                                                            _dayCounts[id] =
                                                                1.0;
                                                            _workPlaces[id] =
                                                                null;
                                                          }
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Дней
                                            SizedBox(
                                              width: 70,
                                              child: dayType == 'work'
                                                  ? DropdownButton<double>(
                                                      value: dayCount,
                                                      isExpanded: true,
                                                      underline:
                                                          const SizedBox(),
                                                      items: _dayCountOptions.map((
                                                        d,
                                                      ) {
                                                        return DropdownMenuItem<
                                                          double
                                                        >(
                                                          value: d,
                                                          child: Text(
                                                            d == 0.5
                                                                ? '0.5'
                                                                : '1',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: isSelected
                                                          ? (value) {
                                                              setState(() {
                                                                _dayCounts[id] =
                                                                    value!;
                                                              });
                                                            }
                                                          : null,
                                                    )
                                                  : const Text(
                                                      '1',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Место
                                            SizedBox(
                                              width: 100,
                                              child: dayType == 'work'
                                                  ? DropdownButton<String?>(
                                                      value: workPlace,
                                                      isExpanded: true,
                                                      underline:
                                                          const SizedBox(),
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
                                                        ..._workPlaceOptions.map((
                                                          e,
                                                        ) {
                                                          final idx =
                                                              _workPlaceOptions
                                                                  .indexOf(e);
                                                          return DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: e,
                                                            child: Text(
                                                              _workPlaceLabels[idx],
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                      onChanged: isSelected
                                                          ? (value) {
                                                              setState(() {
                                                                _workPlaces[id] =
                                                                    value;
                                                                if (value !=
                                                                    null) {
                                                                  _workPlaceErrors
                                                                      .remove(
                                                                        id,
                                                                      );
                                                                }
                                                              });
                                                            }
                                                          : null,
                                                    )
                                                  : const Text(
                                                      '—',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
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
        AppButton(
          label: _isSaving ? 'Сохранение...' : 'Сохранить',
          width: 100,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _workPlaceErrors.clear();
    });

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

        if (dayType == 'work' && workPlace == null) {
          hasError = true;
          setState(() {
            _workPlaceErrors[id] = 'Укажите место';
          });
          continue;
        }

        double finalDays = (dayType == 'work') ? days : 1.0;

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

    if (hasError) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text(
            'Для сотрудников с рабочим днём необходимо указать место работы. Ошибочные строки выделены.',
          ),
          actions: [
            AppButton(
              label: 'OK',
              isText: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    if (selectedEmployees.isEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Выберите хотя бы одного сотрудника.'),
          actions: [
            AppButton(
              label: 'OK',
              isText: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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
              onPressed: () => Navigator.pop(context, false),
            ),
            AppButton(
              label: 'Перезаписать',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    List<TimesheetRecord> recordsToSave = [];
    for (var entry in newEntries) {
      final emp = entry['employee'] as Employee;
      final dayType = entry['dayType'] as String;
      final days = entry['days'] as double;
      final workPlace = entry['workPlace'] as String?;
      recordsToSave.add(
        TimesheetRecord(
          employeeId: emp.id!,
          date: _selectedDate,
          dayType: dayType,
          days: days,
          workPlace: workPlace,
        ),
      );
    }

    setState(() => _isSaving = true);
    try {
      await provider.saveDailyTimesheet(recordsToSave, _selectedDate);
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        setState(() => _isSaving = false);
        return;
      }
      setState(() => _isSaving = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка сохранения'),
          content: Text('Не удалось сохранить записи:\n$e'),
          actions: [
            AppButton(
              label: 'OK',
              isText: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
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
