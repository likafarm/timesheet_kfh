// lib/widgets/employee_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

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
  final _hireDateController = TextEditingController();
  final _baseRateController = TextEditingController();
  final _fieldRateController = TextEditingController();
  final _rateStartDateController = TextEditingController();

  DateTime _hireDate = DateTime.now();
  DateTime _rateStartDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      final e = widget.employee!;
      _nameController.text = e.fullName;
      _positionController.text = e.position;
      _hireDate = e.hireDate;
      _hireDateController.text = DateFormat('dd.MM.yyyy').format(e.hireDate);
      _baseRateController.text = e.baseRate.toString();
      _fieldRateController.text = e.fieldRate.toString();
      _rateStartDate = DateTime.now();
      _rateStartDateController.text = DateFormat(
        'dd.MM.yyyy',
      ).format(_rateStartDate);
    } else {
      _hireDate = DateTime.now();
      _hireDateController.text = DateFormat('dd.MM.yyyy').format(_hireDate);
      _rateStartDate = _hireDate;
      _rateStartDateController.text = DateFormat(
        'dd.MM.yyyy',
      ).format(_rateStartDate);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _hireDateController.dispose();
    _baseRateController.dispose();
    _fieldRateController.dispose();
    _rateStartDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;

    return AlertDialog(
      title: Text(isEditing ? 'Редактирование сотрудника' : 'Новый сотрудник'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: _nameController,
                  labelText: 'ФИО *',
                  prefixIcon: Icons.person,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _positionController,
                  labelText: 'Должность *',
                  prefixIcon: Icons.work,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _hireDateController,
                  labelText: 'Дата приёма *',
                  prefixIcon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _hireDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _hireDate = date;
                        _hireDateController.text = DateFormat(
                          'dd.MM.yyyy',
                        ).format(date);
                        if (_rateStartDate.isBefore(date)) {
                          _rateStartDate = date;
                          _rateStartDateController.text = DateFormat(
                            'dd.MM.yyyy',
                          ).format(date);
                        }
                      });
                    }
                  },
                  validator: (v) =>
                      v?.isEmpty == true ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _baseRateController,
                  labelText: 'Ставка (база, ₽/день) *',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Обязательное поле';
                    }
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Введите число';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _fieldRateController,
                  labelText: 'Ставка (поле, ₽/день) *',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Обязательное поле';
                    }
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Введите число';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _rateStartDateController,
                  labelText: 'Дата начала действия ставки',
                  prefixIcon: Icons.date_range,
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _rateStartDate,
                      firstDate: _hireDate,
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        _rateStartDate = date;
                        _rateStartDateController.text = DateFormat(
                          'dd.MM.yyyy',
                        ).format(date);
                      });
                    }
                  },
                  validator: (v) {
                    if (_rateStartDate.isBefore(_hireDate)) {
                      return 'Дата начала не может быть раньше даты приёма';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Новая ставка будет действовать с указанной даты.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Если ставки не изменились, новая запись не создаётся.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
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
          label: isEditing ? 'Сохранить' : 'Добавить',
          width: 100,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseRate = double.parse(
      _baseRateController.text.replaceAll(',', '.'),
    );
    final fieldRate = double.parse(
      _fieldRateController.text.replaceAll(',', '.'),
    );

    final employee = Employee(
      id: widget.employee?.id,
      fullName: _nameController.text.trim(),
      position: _positionController.text.trim(),
      hireDate: _hireDate,
      dismissalDate: widget.employee?.dismissalDate,
      baseRate: baseRate,
      fieldRate: fieldRate,
    );

    final provider = context.read<AppProvider>();
    setState(() => _isSaving = true);

    try {
      if (widget.employee != null) {
        // Редактирование
        final old = widget.employee!;
        final ratesChanged =
            old.baseRate != baseRate || old.fieldRate != fieldRate;

        await provider.updateEmployee(employee);

        if (ratesChanged) {
          final rate = EmployeeRate(
            employeeId: employee.id!,
            baseRate: baseRate,
            fieldRate: fieldRate,
            startDate: _rateStartDate,
          );
          await provider.addEmployeeRate(rate);
        } else {
          // Показываем уведомление, что ставки не изменились
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ставки не изменены, новая запись не создана'),
            ),
          );
        }
      } else {
        // Новый сотрудник
        final startDate = _rateStartDate.isAfter(_hireDate)
            ? _rateStartDate
            : _hireDate;
        await provider.addEmployee(employee, rateStartDate: startDate);
      }

      if (!mounted) return;
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
          content: Text('Не удалось сохранить данные:\n$e'),
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
