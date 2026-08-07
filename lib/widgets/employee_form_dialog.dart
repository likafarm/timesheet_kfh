import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class EmployeeFormDialog extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormDialog({super.key, this.employee});

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passportSeriesController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _snilsController = TextEditingController();
  final _innController = TextEditingController();
  final _rateController = TextEditingController();
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();

  final _rateFocusNode = FocusNode();
  final _salaryFocusNode = FocusNode();

  DateTime _hireDate = DateTime.now();
  DateTime? _birthDate;
  String _paymentType = 'hourly';

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      final e = widget.employee!;
      _nameController.text = e.fullName;
      _positionController.text = e.position;
      _phoneController.text = e.phone ?? '';
      _passportSeriesController.text = e.passportSeries ?? '';
      _passportNumberController.text = e.passportNumber ?? '';
      _snilsController.text = e.snils ?? '';
      _innController.text = e.inn ?? '';
      _rateController.text = e.hourlyRate.toString();
      _salaryController.text = e.fixedSalary?.toString() ?? '';
      _notesController.text = e.notes ?? '';
      _hireDate = e.hireDate;
      _birthDate = e.birthDate;
      _paymentType = e.paymentType;

      _formatControllerText(_rateController);
      _formatControllerText(_salaryController);
    }
    _setupNumberField(_rateController, _rateFocusNode);
    _setupNumberField(_salaryController, _salaryFocusNode);
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
    _nameController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    _passportSeriesController.dispose();
    _passportNumberController.dispose();
    _snilsController.dispose();
    _innController.dispose();
    _rateController.dispose();
    _salaryController.dispose();
    _notesController.dispose();
    _rateFocusNode.dispose();
    _salaryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;
    return AlertDialog(
      title: Text(isEditing ? 'Редактирование сотрудника' : 'Новый сотрудник'),
      content: SizedBox(
        width: 500,
        height: 550, // чуть уменьшил, так как убрали свитч
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Основная информация'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ФИО *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _positionController,
                  decoration: const InputDecoration(
                    labelText: 'Должность *',
                    prefixIcon: Icon(Icons.work),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildDatePicker(
                  label: 'Дата рождения',
                  date: _birthDate,
                  onPick: (date) => setState(() => _birthDate = date),
                ),
                _buildDatePicker(
                  label: 'Дата приёма *',
                  date: _hireDate,
                  onPick: (date) {
                    if (date != null) setState(() => _hireDate = date);
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Паспортные данные'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _passportSeriesController,
                        decoration: const InputDecoration(labelText: 'Серия'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _passportNumberController,
                        decoration: const InputDecoration(labelText: 'Номер'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _snilsController,
                  decoration: const InputDecoration(
                    labelText: 'СНИЛС',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _innController,
                  decoration: const InputDecoration(
                    labelText: 'ИНН',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Оплата труда'),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Тип оплаты',
                    prefixIcon: Icon(Icons.payments),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentType,
                      isDense: true,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'hourly',
                          child: Text('Почасовая'),
                        ),
                        DropdownMenuItem(value: 'salary', child: Text('Оклад')),
                        DropdownMenuItem(
                          value: 'piecework',
                          child: Text('Сдельная'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _paymentType = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_paymentType == 'hourly')
                  _buildNumberField(
                    controller: _rateController,
                    focusNode: _rateFocusNode,
                    label: 'Почасовая ставка (₽/час) *',
                    icon: Icons.attach_money,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Обязательное поле';
                      }
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                      return null;
                    },
                  ),
                if (_paymentType == 'salary')
                  _buildNumberField(
                    controller: _salaryController,
                    focusNode: _salaryFocusNode,
                    label: 'Оклад (₽) *',
                    icon: Icons.money,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Обязательное поле';
                      }
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                      return null;
                    },
                  ),
                if (_paymentType == 'piecework')
                  _buildNumberField(
                    controller: _rateController,
                    focusNode: _rateFocusNode,
                    label: 'Базовая ставка (₽/час) *',
                    icon: Icons.attach_money,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Обязательное поле';
                      }
                      final raw = v
                          .replaceAll(RegExp(r'\s'), '')
                          .replaceAll(',', '.');
                      if (double.tryParse(raw) == null) return 'Введите число';
                      return null;
                    },
                  ),
                const SizedBox(height: 16),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required void Function(DateTime?) onPick,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: Text(label),
      subtitle: Text(
        date != null ? DateFormat('dd.MM.yyyy').format(date) : 'Не выбрано',
      ),
      trailing: date != null
          ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () => onPick(null),
            )
          : null,
      dense: true,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        onPick(picked);
      },
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
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*$')),
      ],
      validator: validator,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    String getRaw(String text) =>
        text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    double rate = 0;
    double? salary;
    if (_paymentType == 'hourly' || _paymentType == 'piecework') {
      rate = double.parse(getRaw(_rateController.text));
    } else if (_paymentType == 'salary') {
      salary = double.parse(getRaw(_salaryController.text));
    }
    final employee = Employee(
      id: widget.employee?.id,
      fullName: _nameController.text.trim(),
      position: _positionController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      hireDate: _hireDate,
      birthDate: _birthDate,
      passportSeries: _passportSeriesController.text.trim().isEmpty
          ? null
          : _passportSeriesController.text.trim(),
      passportNumber: _passportNumberController.text.trim().isEmpty
          ? null
          : _passportNumberController.text.trim(),
      snils: _snilsController.text.trim().isEmpty
          ? null
          : _snilsController.text.trim(),
      inn: _innController.text.trim().isEmpty
          ? null
          : _innController.text.trim(),
      hourlyRate: rate,
      fixedSalary: salary,
      paymentType: _paymentType,
      isActive:
          widget.employee?.isActive ??
          true, // сохраняем текущий статус (при создании — true)
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dismissalDate: widget.employee?.dismissalDate,
      dismissalReason: widget.employee?.dismissalReason,
    );
    final provider = context.read<AppProvider>();
    if (widget.employee != null) {
      provider.updateEmployee(employee);
    } else {
      provider.addEmployee(employee);
    }
    Navigator.pop(context);
  }
}
