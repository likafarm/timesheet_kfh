// lib/widgets/employee_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/employee_rate.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

/// Диалог добавления/редактирования сотрудника (упрощённый)
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

  DateTime _hireDate = DateTime.now();

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
    } else {
      _hireDateController.text = DateFormat(
        'dd.MM.yyyy',
      ).format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _hireDateController.dispose();
    _baseRateController.dispose();
    _fieldRateController.dispose();
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
            ],
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
          onPressed: _save,
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

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

    if (widget.employee != null) {
      provider.updateEmployee(employee);
      final old = widget.employee!;
      if (old.baseRate != baseRate || old.fieldRate != fieldRate) {
        final rate = EmployeeRate(
          employeeId: employee.id!,
          baseRate: baseRate,
          fieldRate: fieldRate,
          startDate: DateTime.now(),
        );
        provider.addEmployeeRate(rate);
      }
    } else {
      provider.addEmployee(employee);
    }

    Navigator.pop(context);
  }
}
