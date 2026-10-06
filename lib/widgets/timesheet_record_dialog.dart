// lib/widgets/timesheet_record_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../utils/day_draft.dart';
import '../utils/string_utils.dart';
import 'common_widgets.dart';
import 'adaptive_dialog.dart';
import 'day_mark_button.dart';

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

  /// Выбранная отметка; null — не выбрана (новая ячейка или старая запись
  /// без места работы).
  DayMark? _mark;
  final _notesController = TextEditingController();

  String? _markError;
  bool _isSaving = false;
  EmployeeRate? _rateAtDate;

  @override
  void initState() {
    super.initState();
    _date = widget.record?.date ?? widget.defaultDate;

    if (widget.record != null) {
      final r = widget.record!;
      _mark = DayMark.of(r);
      _notesController.text = r.notes ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRateAtDate());
  }

  /// Ставки показываются всем, кроме оператора (сервер ему их не отдаёт).
  bool get _showRates => !context.read<AppProvider>().operatorMode;

  Future<void> _loadRateAtDate() async {
    final id = widget.employee.id;
    if (id == null || !_showRates) return;
    final rate = await context.read<AppProvider>().getEmployeeRateAtDate(
      id,
      _date,
    );
    if (!mounted) return;
    setState(() => _rateAtDate = rate);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record?.id != null;

    return AppDialog(
      title: Text('${isEditing ? 'Редактировать' : 'Добавить'} запись'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmployeeHeader(),
              const Divider(height: 24),

              // Отметка дня — кнопками, как в «Вводе за день» (решение
              // владельца 2026-10-06).
              Text(
                'Отметка',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mark in DayMark.all)
                    DayMarkButton(
                      mark: mark,
                      selected: _mark == mark,
                      onPressed: () => setState(() {
                        _mark = mark;
                        _markError = null;
                      }),
                    ),
                ],
              ),
              if (_markError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _markError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_showRates && _mark?.workPlace != null) ...[
                const SizedBox(height: 6),
                Text(
                  _mark!.workPlace == 'base'
                      ? 'Ставка на базе: ${StringUtils.formatDayRate(_rateAtDate?.baseRate ?? widget.employee.baseRate)}'
                      : 'Ставка в поле: ${StringUtils.formatDayRate(_rateAtDate?.fieldRate ?? widget.employee.fieldRate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 12),

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
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Сохранить' : 'Добавить'),
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
        if (_showRates) ...[
          const SizedBox(height: 4),
          Text(
            'Ставки: база ${StringUtils.formatDayRate(_rateAtDate?.baseRate ?? widget.employee.baseRate)}'
            ' · поле ${StringUtils.formatDayRate(_rateAtDate?.fieldRate ?? widget.employee.fieldRate)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
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
            if (picked != null) {
              setState(() => _date = picked);
              _loadRateAtDate();
            }
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    final mark = _mark;
    if (mark == null) {
      setState(() => _markError = 'Выберите отметку дня');
      return;
    }

    // Дополнительная проверка на существование employeeId
    if (widget.employee.id == null) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text(
            'Неизвестный сотрудник. Попробуйте обновить список.',
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

    final record = TimesheetRecord(
      id: widget.record?.id,
      employeeId: widget.employee.id!,
      date: _date,
      dayType: mark.dayType,
      days: mark.days,
      workPlace: mark.workPlace,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    setState(() => _isSaving = true);
    try {
      await context.read<AppProvider>().saveTimesheetRecord(record);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка сохранения'),
          content: Text('Не удалось сохранить запись:\n$e'),
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
}
