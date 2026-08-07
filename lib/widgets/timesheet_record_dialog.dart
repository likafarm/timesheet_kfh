import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _TimesheetRecordDialogState extends State<TimesheetRecordDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;

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

  final _hoursFocusNode = FocusNode();
  final _overtimeFocusNode = FocusNode();
  final _quantityDoneFocusNode = FocusNode();
  final _pieceworkRateFocusNode = FocusNode();
  final _bonusFocusNode = FocusNode();
  final _penaltyFocusNode = FocusNode();

  int? _selectedWorkTypeId;
  int? _selectedWorkSiteId;
  int? _selectedMachineryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      _formatControllerText(_hoursController);
      _formatControllerText(_overtimeController);
      _formatControllerText(_quantityDoneController);
      _formatControllerText(_pieceworkRateController);
      _formatControllerText(_bonusController);
      _formatControllerText(_penaltyController);
    }

    _setupNumberField(_hoursController, _hoursFocusNode);
    _setupNumberField(_overtimeController, _overtimeFocusNode);
    _setupNumberField(_quantityDoneController, _quantityDoneFocusNode);
    _setupNumberField(_pieceworkRateController, _pieceworkRateFocusNode);
    _setupNumberField(_bonusController, _bonusFocusNode);
    _setupNumberField(_penaltyController, _penaltyFocusNode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.workTypes.isEmpty) provider.loadWorkTypes();
      if (provider.workSites.isEmpty) provider.loadWorkSites();
      if (provider.machinery.isEmpty) provider.loadMachinery();
    });
  }

  void _formatControllerText(TextEditingController controller) {
    final raw = controller.text
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(',', '.');
    if (raw.isNotEmpty) {
      final value = double.tryParse(raw);
      if (value != null) {
        final formatter = NumberFormat('#,##0.00', 'ru');
        controller.text = formatter.format(value);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    }
  }

  void _setupNumberField(
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    controller.addListener(() {
      final text = controller.text;
      if (text.contains(',')) {
        controller.text = text.replaceAll(',', '.');
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    });

    focusNode.addListener(() {
      if (!mounted) return;
      if (!focusNode.hasFocus) {
        final raw = controller.text
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll(',', '.');
        if (raw.isNotEmpty) {
          final value = double.tryParse(raw);
          if (value != null) {
            final formatter = NumberFormat('#,##0.00', 'ru');
            controller.text = formatter.format(value);
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        }
      } else {
        final raw = controller.text
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll(',', '.');
        if (raw.isNotEmpty) {
          final value = double.tryParse(raw);
          if (value != null) {
            controller.text = value.toString();
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hoursController.dispose();
    _overtimeController.dispose();
    _quantityDoneController.dispose();
    _quantityUnitController.dispose();
    _pieceworkRateController.dispose();
    _bonusController.dispose();
    _penaltyController.dispose();
    _weatherController.dispose();
    _notesController.dispose();
    _hoursFocusNode.dispose();
    _overtimeFocusNode.dispose();
    _quantityDoneFocusNode.dispose();
    _pieceworkRateFocusNode.dispose();
    _bonusFocusNode.dispose();
    _penaltyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record?.id != null;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text('${isEditing ? 'Редактировать' : 'Добавить'} запись'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 420,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Шапка с сотрудником и датой
              _buildEmployeeHeader(),
              const SizedBox(height: 12),
              // Вкладки
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey[600],
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Основное'),
                  Tab(text: 'Сдельная'),
                  Tab(text: 'Дополнительно'),
                ],
              ),
              const SizedBox(height: 12),
              // Содержимое вкладок
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMainTab(),
                    _buildPieceworkTab(),
                    _buildExtraTab(),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              widget.employee.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.employee.position,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd.MM.yyyy').format(_date),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Вкладка "Основное" ===
  Widget _buildMainTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _hoursController,
                  focusNode: _hoursFocusNode,
                  label: 'Часы *',
                  icon: Icons.access_time,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Обязательно';
                    final raw = v
                        .replaceAll(RegExp(r'\s'), '')
                        .replaceAll(',', '.');
                    if (double.tryParse(raw) == null) return 'Введите число';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _overtimeController,
                  focusNode: _overtimeFocusNode,
                  label: 'Перераб.',
                  icon: Icons.more_time,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWorkTypeDropdown(),
          const SizedBox(height: 12),
          _buildWorkSiteDropdown(),
          const SizedBox(height: 12),
          _buildMachineryDropdown(),
        ],
      ),
    );
  }

  // === Вкладка "Сдельная" ===
  Widget _buildPieceworkTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildNumberField(
                  controller: _quantityDoneController,
                  focusNode: _quantityDoneFocusNode,
                  label: 'Объём',
                  icon: Icons.linear_scale,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                    }
                    return null;
                  },
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
                child: _buildNumberField(
                  controller: _pieceworkRateController,
                  focusNode: _pieceworkRateFocusNode,
                  label: 'Расценка',
                  icon: Icons.attach_money,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _bonusController,
                  focusNode: _bonusFocusNode,
                  label: 'Надбавка (₽)',
                  icon: Icons.add_circle_outline,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _penaltyController,
                  focusNode: _penaltyFocusNode,
                  label: 'Удержание (₽)',
                  icon: Icons.remove_circle_outline,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === Вкладка "Дополнительно" ===
  Widget _buildExtraTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
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
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*$')),
      ],
      validator: validator,
    );
  }

  Widget _buildWorkTypeDropdown() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Вид работы',
            prefixIcon: Icon(Icons.category),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedWorkTypeId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите...'),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedWorkSiteId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите...'),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedMachineryId,
              isDense: true,
              isExpanded: true,
              hint: const Text('Выберите...'),
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

    double? parseDouble(String text) {
      final raw = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
      if (raw.isEmpty) return null;
      return double.tryParse(raw);
    }

    final hours = parseDouble(_hoursController.text) ?? 0.0;
    final overtime = parseDouble(_overtimeController.text) ?? 0.0;

    if (hours > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Часы не могут превышать 12')),
      );
      return;
    }
    if (overtime > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Переработка не может превышать 4')),
      );
      return;
    }

    final record = TimesheetRecord(
      id: widget.record?.id,
      employeeId: widget.employee.id!,
      date: _date,
      hoursWorked: hours,
      overtimeHours: overtime > 0 ? overtime : null,
      workTypeId: _selectedWorkTypeId,
      workSiteId: _selectedWorkSiteId,
      machineryId: _selectedMachineryId,
      quantityDone: parseDouble(_quantityDoneController.text),
      quantityUnit: _quantityUnitController.text.isEmpty
          ? null
          : _quantityUnitController.text,
      pieceworkRate: parseDouble(_pieceworkRateController.text),
      bonus: parseDouble(_bonusController.text) ?? 0.0,
      penalty: parseDouble(_penaltyController.text) ?? 0.0,
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
