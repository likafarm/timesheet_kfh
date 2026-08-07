import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Диалог добавления/редактирования записи табеля
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
  final _hoursController = TextEditingController();
  final _overtimeController = TextEditingController(text: '0');
  final _quantityDoneController = TextEditingController();
  final _quantityUnitController = TextEditingController();
  final _pieceworkRateController = TextEditingController();
  final _bonusController = TextEditingController(text: '0');
  final _penaltyController = TextEditingController(text: '0');
  final _weatherController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedWorkTypeId;
  int? _selectedWorkSiteId;
  int? _selectedMachineryId;

  @override
  void initState() {
    super.initState();
    _date = widget.record?.date ?? widget.defaultDate;

    if (widget.record != null) {
      final r = widget.record!;
      _hoursController.text = r.hoursWorked.toString();
      _overtimeController.text = (r.overtimeHours ?? 0).toString();
      _selectedWorkTypeId = r.workTypeId;
      _selectedWorkSiteId = r.workSiteId;
      _selectedMachineryId = r.machineryId;
      _quantityDoneController.text = r.quantityDone?.toString() ?? '';
      _quantityUnitController.text = r.quantityUnit ?? '';
      _pieceworkRateController.text = r.pieceworkRate?.toString() ?? '';
      _bonusController.text = (r.bonus ?? 0).toString();
      _penaltyController.text = (r.penalty ?? 0).toString();
      _weatherController.text = r.weatherCondition ?? '';
      _notesController.text = r.notes ?? '';
    }

    // Загружаем справочники
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.workTypes.isEmpty) provider.loadWorkTypes();
      if (provider.workSites.isEmpty) provider.loadWorkSites();
      if (provider.machinery.isEmpty) provider.loadMachinery();
    });
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _overtimeController.dispose();
    _quantityDoneController.dispose();
    _quantityUnitController.dispose();
    _pieceworkRateController.dispose();
    _bonusController.dispose();
    _penaltyController.dispose();
    _weatherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record?.id != null;

    return AlertDialog(
      title: Text('${isEditing ? 'Редактировать' : 'Добавить'} запись'),
      content: SizedBox(
        width: 450,
        height: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Сотрудник и дата
                _buildEmployeeHeader(),
                const Divider(height: 24),

                // Основные часы
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Часы *',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Обязательно';
                          if (double.tryParse(v!) == null) return 'Число';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _overtimeController,
                        decoration: const InputDecoration(
                          labelText: 'Перераб.',
                          prefixIcon: Icon(Icons.more_time),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Вид работы и участок
                _buildWorkTypeDropdown(),
                const SizedBox(height: 12),
                _buildWorkSiteDropdown(),
                const SizedBox(height: 12),
                _buildMachineryDropdown(),
                const SizedBox(height: 12),

                // Сдельная работа
                const Text(
                  'Сдельная работа (если применимо)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityDoneController,
                        decoration: const InputDecoration(labelText: 'Объём'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Ед.',
                          hintText: 'га, т',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _pieceworkRateController,
                        decoration: const InputDecoration(
                          labelText: 'Расценка',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Бонус/штраф
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bonusController,
                        decoration: const InputDecoration(
                          labelText: 'Надбавка (₽)',
                          prefixIcon: Icon(Icons.add_circle_outline),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _penaltyController,
                        decoration: const InputDecoration(
                          labelText: 'Удержание (₽)',
                          prefixIcon: Icon(Icons.remove_circle_outline),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Погода и примечания
                TextFormField(
                  controller: _weatherController,
                  decoration: const InputDecoration(
                    labelText: 'Погода',
                    prefixIcon: Icon(Icons.wb_sunny),
                    hintText: 'Ясно, +25°C',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
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

  Widget _buildWorkTypeDropdown() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Вид работы',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedWorkTypeId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите вид работы...'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— Не указано —'),
                ),
                ...provider.workTypes.map((wt) {
                  return DropdownMenuItem<int?>(
                    value: wt.id,
                    child: Text('${wt.name} (${wt.categoryName})'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedWorkTypeId = v),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkSiteDropdown() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Участок/поле',
            prefixIcon: Icon(Icons.agriculture),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedWorkSiteId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите участок...'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— Не указано —'),
                ),
                ...provider.workSites.map((ws) {
                  return DropdownMenuItem<int?>(
                    value: ws.id,
                    child: Text(ws.name),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedWorkSiteId = v),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMachineryDropdown() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Техника',
            prefixIcon: Icon(Icons.precision_manufacturing),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedMachineryId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите технику...'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— Не указано —'),
                ),
                ...provider.machinery.where((m) => m.isActive).map((m) {
                  return DropdownMenuItem<int?>(
                    value: m.id,
                    child: Text('${m.name} (${m.typeName})'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedMachineryId = v),
            ),
          ),
        );
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final record = TimesheetRecord(
      id: widget.record?.id,
      employeeId: widget.employee.id!,
      date: _date,
      hoursWorked: double.parse(_hoursController.text),
      overtimeHours: double.tryParse(_overtimeController.text) ?? 0,
      workTypeId: _selectedWorkTypeId,
      workSiteId: _selectedWorkSiteId,
      machineryId: _selectedMachineryId,
      quantityDone: _quantityDoneController.text.isEmpty
          ? null
          : double.parse(_quantityDoneController.text),
      quantityUnit: _quantityUnitController.text.isEmpty
          ? null
          : _quantityUnitController.text,
      pieceworkRate: _pieceworkRateController.text.isEmpty
          ? null
          : double.parse(_pieceworkRateController.text),
      bonus: double.tryParse(_bonusController.text) ?? 0,
      penalty: double.tryParse(_penaltyController.text) ?? 0,
      weatherCondition: _weatherController.text.isEmpty
          ? null
          : _weatherController.text,
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
