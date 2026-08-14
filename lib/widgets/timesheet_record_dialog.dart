import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Диалог добавления/редактирования записи табеля (дни)
class TimesheetRecordDialog extends StatefulWidget {
  final Employee employee;
  final TimesheetRecord? record;
  final DateTime defaultDate;

  const TimesheetRecordDialog({
    super.key,
    required this.employee,
    this.record,
    required this.defaultDate,
  });

  @override
  State<TimesheetRecordDialog> createState() => _TimesheetRecordDialogState();
}

class _TimesheetRecordDialogState extends State<TimesheetRecordDialog> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now();
  String _dayType = 'work'; // work, sick, vacation, dayoff
  double _days = 1.0; // 0.5 или 1
  String? _workPlace; // 'base' или 'field'
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.record?.date ?? widget.defaultDate;

    if (widget.record != null) {
      final r = widget.record!;
      _dayType = r.dayType;
      _days = r.days;
      _workPlace = r.workPlace;
      _notesController.text = r.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record?.id != null;

    return AlertDialog(
      title: Text('${isEditing ? 'Редактировать' : 'Добавить'} запись'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Сотрудник и дата
              _buildEmployeeHeader(),
              const Divider(height: 24),

              // Тип дня
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Тип дня',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dayType,
                    isDense: true,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'work',
                        child: Text('Рабочий день'),
                      ),
                      DropdownMenuItem(
                        value: 'sick',
                        child: Text('Больничный'),
                      ),
                      DropdownMenuItem(
                        value: 'vacation',
                        child: Text('Отпуск'),
                      ),
                      DropdownMenuItem(
                        value: 'dayoff',
                        child: Text('Выходной'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _dayType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Количество дней (только для рабочего дня)
              if (_dayType == 'work') ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Количество дней',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: _days,
                      isDense: true,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 0.5, child: Text('0.5 дня')),
                        DropdownMenuItem(value: 1.0, child: Text('1 день')),
                      ],
                      onChanged: (v) => setState(() => _days = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Место работы
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Место работы',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _workPlace,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('Выберите место'),
                      items: const [
                        DropdownMenuItem(value: 'base', child: Text('База')),
                        DropdownMenuItem(value: 'field', child: Text('Поле')),
                      ],
                      onChanged: (v) => setState(() => _workPlace = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Примечания
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Примечания',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteTimesheetRecord(
                widget.record!.id!,
              );
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }

  Widget _buildEmployeeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.employee.fullName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          widget.employee.position,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, size: 20),
          title: const Text('Дата', style: TextStyle(fontSize: 13)),
          subtitle: Text(
            DateFormat('dd.MM.yyyy').format(_date),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          dense: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Валидация для рабочего дня
    if (_dayType == 'work' && _workPlace == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите место работы')));
      return;
    }

    final record = TimesheetRecord(
      id: widget.record?.id,
      employeeId: widget.employee.id!,
      date: _date,
      dayType: _dayType,
      days: _dayType == 'work' ? _days : 0,
      workPlace: _dayType == 'work' ? _workPlace : null,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    final provider = context.read<AppProvider>();
    if (widget.record?.id != null) {
      provider.updateTimesheetRecord(record);
    } else {
      provider.addTimesheetRecord(record);
    }

    Navigator.pop(context);
  }
}
