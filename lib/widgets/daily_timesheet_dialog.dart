import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

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

  // ignore: prefer_final_fields
  Map<int, TextEditingController> _hoursControllers = {};

  // ignore: prefer_final_fields
  Map<int, TextEditingController> _overtimeControllers = {};

  // ignore: prefer_final_fields
  Map<int, int?> _workTypeIds = {};

  bool _isLoading = false;

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
        // Очищаем старые контроллеры
        for (var controller in _hoursControllers.values) {
          controller.dispose();
        }
        for (var controller in _overtimeControllers.values) {
          controller.dispose();
        }
        _hoursControllers.clear();
        _overtimeControllers.clear();
        _workTypeIds.clear();

        // Инициализируем контроллеры для каждого сотрудника
        for (var employee in _employees) {
          if (employee.id != null) {
            _hoursControllers[employee.id!] = TextEditingController();
            _overtimeControllers[employee.id!] = TextEditingController();
            _workTypeIds[employee.id!] = null;
          }
        }
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
      final employeeId = record.employeeId;
      if (_hoursControllers.containsKey(employeeId)) {
        _hoursControllers[employeeId]!.text = record.hoursWorked > 0
            ? record.hoursWorked.toString()
            : '';
        _overtimeControllers[employeeId]!.text = (record.overtimeHours ?? 0) > 0
            ? record.overtimeHours.toString()
            : '';
        _workTypeIds[employeeId] = record.workTypeId;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in _hoursControllers.values) {
      controller.dispose();
    }
    for (var controller in _overtimeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    bool hasError = false;
    List<TimesheetRecord> recordsToSave = [];

    for (var employee in _employees) {
      final id = employee.id!;
      final hoursText = _hoursControllers[id]!.text.trim();
      final overtimeText = _overtimeControllers[id]!.text.trim();
      final hours = double.tryParse(hoursText) ?? 0;
      final overtime = double.tryParse(overtimeText) ?? 0;

      if (hours == 0 && overtime == 0) continue;

      if (hours > 12) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('У ${employee.fullName} часы не могут превышать 12'),
          ),
        );
        hasError = true;
        break;
      }
      if (overtime > 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'У ${employee.fullName} переработка не может превышать 4',
            ),
          ),
        );
        hasError = true;
        break;
      }

      final record = TimesheetRecord(
        employeeId: id,
        date: _selectedDate,
        hoursWorked: hours,
        overtimeHours: overtime > 0 ? overtime : null,
        workTypeId: _workTypeIds[id],
      );
      recordsToSave.add(record);
    }

    if (hasError) return;

    await provider.saveDailyTimesheet(recordsToSave, _selectedDate);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
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
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата'),
              subtitle: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _employees.isEmpty
                  ? const Center(child: Text('Нет активных сотрудников'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(
                              label: Text(
                                '№',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ФИО',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Отработано, ч.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Переработка, ч.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Вид работ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: _employees.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final employee = entry.value;
                            final id = employee.id!;
                            return DataRow(
                              cells: [
                                DataCell(Text('$index')),
                                DataCell(Text(employee.fullName)),
                                DataCell(
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: _hoursControllers[id],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d*$'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: _overtimeControllers[id],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d*$'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Consumer<AppProvider>(
                                      builder: (context, provider, child) {
                                        return DropdownButton<int>(
                                          value: _workTypeIds[id],
                                          isExpanded: true,
                                          hint: const Text('Выберите'),
                                          items: [
                                            const DropdownMenuItem<int>(
                                              value: null,
                                              child: Text('— Не указано —'),
                                            ),
                                            ...provider.workTypes.map((wt) {
                                              return DropdownMenuItem<int>(
                                                value: wt.id,
                                                child: Text(wt.name),
                                              );
                                            }),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _workTypeIds[id] = value;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
