// lib/widgets/employee_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../screens/employee_rate_history_screen.dart';
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
                // Ставки меняются в истории ставок (добавление, правка,
                // удаление с любой даты); при добавлении сотрудника —
                // первая ставка.
                if (isEditing)
                  _CurrentRates(employee: widget.employee!)
                else
                  ..._firstRateFields(),
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

  List<Widget> _firstRateFields() => [
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
      labelText: 'Ставка действует с',
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
      'Потом ставки меняются в истории ставок сотрудника.',
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  ];

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<AppProvider>();
    // Ставки в карточке — копия текущей ставки из истории (её обновляет
    // AppProvider при правке истории, в том числе открытой из этой формы —
    // поэтому свежая карточка, а не та, с которой форма открылась); у
    // нового сотрудника — первая ставка.
    final old = widget.employee == null
        ? null
        : provider.getEmployeeById(widget.employee!.id!) ?? widget.employee;
    final baseRate =
        old?.baseRate ??
        double.parse(_baseRateController.text.replaceAll(',', '.'));
    final fieldRate =
        old?.fieldRate ??
        double.parse(_fieldRateController.text.replaceAll(',', '.'));

    final employee = Employee(
      id: widget.employee?.id,
      fullName: _nameController.text.trim(),
      position: _positionController.text.trim(),
      hireDate: _hireDate,
      dismissalDate: widget.employee?.dismissalDate,
      baseRate: baseRate,
      fieldRate: fieldRate,
    );

    setState(() => _isSaving = true);

    try {
      if (old != null) {
        await provider.updateEmployee(employee);
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

/// Ставки, действующие сегодня, — только показ; менять — в истории ставок.
class _CurrentRates extends StatelessWidget {
  final Employee employee;

  const _CurrentRates({required this.employee});

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<AppProvider>().currentRate(employee.id!);
    final money = NumberFormat('#,##0.00', 'ru');
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Текущие ставки',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (rate == null)
              Text(
                'На сегодня ставки нет — рабочие дни без ставки не '
                'оплачиваются.',
                style: TextStyle(color: scheme.error),
              )
            else ...[
              Text('База: ${money.format(rate.baseRate)} ₽/день'),
              Text('Поле: ${money.format(rate.fieldRate)} ₽/день'),
              Text(
                'с ${DateFormat('dd.MM.yyyy').format(rate.startDate)}'
                '${rate.endDate == null ? '' : ' по ${DateFormat('dd.MM.yyyy').format(rate.endDate!)}'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeRateHistoryScreen(
                      employeeId: employee.id!,
                      employeeName: employee.fullName,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('История ставок'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
