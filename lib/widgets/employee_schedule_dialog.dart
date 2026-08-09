import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Диалог управления графиком работы сотрудника
class EmployeeScheduleDialog extends StatefulWidget {
  final Employee employee;

  const EmployeeScheduleDialog({super.key, required this.employee});

  @override
  State<EmployeeScheduleDialog> createState() => _EmployeeScheduleDialogState();
}

class _EmployeeScheduleDialogState extends State<EmployeeScheduleDialog> {
  int? _selectedScheduleTypeId;
  DateTime _startDate = DateTime.now();
  List<Map<String, dynamic>> _exceptions = [];
  Map<String, dynamic>? _currentSchedule;

  final _exceptionDateController = TextEditingController();
  final _exceptionNoteController = TextEditingController();
  String _exceptionType = 'work';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      if (provider.workScheduleTypes.isEmpty) {
        await provider.loadWorkScheduleTypes();
      }
      _currentSchedule = provider.employeeSchedules[widget.employee.id];
      if (_currentSchedule != null) {
        _selectedScheduleTypeId = _currentSchedule!['schedule_type_id'] as int?;
        _startDate = DateTime.parse(_currentSchedule!['start_date'] as String);
      } else {
        _startDate = DateTime.now();
      }
      await provider.loadScheduleExceptions(widget.employee.id!);
      _exceptions = provider.scheduleExceptions[widget.employee.id] ?? [];
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedScheduleTypeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите тип графика')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.assignEmployeeSchedule(
        widget.employee.id!,
        _selectedScheduleTypeId!,
        _startDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('График успешно назначен')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeSchedule() async {
    if (_currentSchedule == null) return;

    // ignore: use_build_context_synchronously
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить график?'),
        content: const Text(
          'Текущий график будет завершён сегодня. '
          'Сотрудник перестанет считаться сменным работником.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // ignore: use_build_context_synchronously
      final provider = context.read<AppProvider>();
      await provider.closeEmployeeSchedule(widget.employee.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('График завершён')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addException() async {
    if (_exceptionDateController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите дату')));
      return;
    }
    final date = DateTime.tryParse(_exceptionDateController.text);
    if (date == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Неверный формат даты')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.addScheduleException(
        widget.employee.id!,
        date,
        _exceptionType,
        note: _exceptionNoteController.text.trim().isEmpty
            ? null
            : _exceptionNoteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Исключение добавлено')));
      _exceptionDateController.clear();
      _exceptionNoteController.clear();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteException(int exceptionId) async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.deleteScheduleException(exceptionId, widget.employee.id!);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _exceptionDateController.dispose();
    _exceptionNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheduleTypes = provider.workScheduleTypes;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.schedule),
          const SizedBox(width: 8),
          Expanded(child: Text('График работы: ${widget.employee.fullName}')),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentSchedule != null
                            ? Colors.green[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentSchedule != null
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: _currentSchedule != null
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentSchedule != null
                                  ? 'График назначен с ${DateFormat('dd.MM.yyyy').format(_startDate)}'
                                  : 'График не назначен',
                              style: TextStyle(
                                fontWeight: _currentSchedule != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Тип графика',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedScheduleTypeId,
                          isExpanded: true,
                          hint: const Text('Выберите тип графика'),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('— Не выбран —'),
                            ),
                            ...scheduleTypes.map((type) {
                              final id = type['id'] as int;
                              final name = type['name'] as String;
                              final description =
                                  type['description'] as String?;
                              final workDays = type['work_days'] as int;
                              final restDays = type['rest_days'] as int;
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '$name ($workDays/$restDays)${description != null ? ' — $description' : ''}',
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedScheduleTypeId = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Дата начала'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy').format(_startDate),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _selectedScheduleTypeId != null
                                ? _saveSchedule
                                : null,
                            icon: const Icon(Icons.save),
                            label: Text(
                              _currentSchedule != null
                                  ? 'Обновить'
                                  : 'Назначить',
                            ),
                          ),
                        ),
                        if (_currentSchedule != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _closeSchedule,
                              icon: const Icon(Icons.close),
                              label: const Text('Завершить'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const Divider(height: 32),

                    const Text(
                      'Замены (исключения)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _exceptionDateController,
                            decoration: const InputDecoration(
                              hintText: 'Дата (ДД.ММ.ГГГГ)',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                _exceptionDateController.text = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _exceptionType,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'work',
                                    child: Text('Работа'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rest',
                                    child: Text('Отдых'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _exceptionType = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _exceptionNoteController,
                            decoration: const InputDecoration(
                              hintText: 'Примечание',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addException,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_exceptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Нет исключений',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Column(
                        children: _exceptions.map((exc) {
                          final id = exc['id'] as int;
                          final date = DateTime.parse(exc['date'] as String);
                          final type = exc['exception_type'] as String;
                          final note = exc['note'] as String?;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                type == 'work' ? Icons.work : Icons.bedtime,
                                color: type == 'work'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              title: Text(
                                DateFormat('dd.MM.yyyy').format(date),
                              ),
                              subtitle: note != null ? Text(note) : null,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteException(id),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
