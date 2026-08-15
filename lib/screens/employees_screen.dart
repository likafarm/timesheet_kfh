// lib/screens/employees_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/employee_form_dialog.dart';
import 'employee_rate_history_screen.dart'; // новый импорт

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _showAll = false;
  final double _tableWidth = 960.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadEmployees(activeOnly: !_showAll);
    });
  }

  void _toggleFilter() {
    setState(() {
      _showAll = !_showAll;
      context.read<AppProvider>().loadEmployees(activeOnly: !_showAll);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники'),
        centerTitle: false,
        actions: [
          Row(
            children: [
              const Text('Только активные'),
              Switch(value: !_showAll, onChanged: (_) => _toggleFilter()),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showEmployeeDialog(context),
            tooltip: 'Добавить сотрудника',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Повторить',
                    onPressed: () =>
                        provider.loadEmployees(activeOnly: !_showAll),
                    isFilled: true,
                  ),
                ],
              ),
            );
          }
          if (provider.employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _showAll ? 'Нет сотрудников' : 'Нет активных сотрудников',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Добавить сотрудника',
                    icon: Icons.add,
                    onPressed: () => _showEmployeeDialog(context),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _tableWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '№',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 200,
                          child: Text(
                            'ФИО',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'Должность',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'Дата приёма',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Ставка (база)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Ставка (поле)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Статус',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: provider.employees.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key + 1;
                            final employee = entry.value;
                            final isActive =
                                employee.dismissalDate == null ||
                                employee.dismissalDate!.isAfter(DateTime.now());
                            final formatter = NumberFormat('#,##0.00', 'ru');

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                ),
                                color: isActive ? null : Colors.grey[50],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '$index',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      employee.fullName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        decoration: isActive
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      employee.position,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      DateFormat(
                                        'dd.MM.yyyy',
                                      ).format(employee.hireDate),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${formatter.format(employee.baseRate)} ₽',
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${formatter.format(employee.fieldRate)} ₽',
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 80,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green[100]
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isActive ? 'Активен' : 'Уволен',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isActive
                                              ? Colors.green[800]
                                              : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 48,
                                    child: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEmployeeDialog(
                                            context,
                                            employee: employee,
                                          );
                                        } else if (value == 'dismiss') {
                                          _showDismissDialog(context, employee);
                                        } else if (value == 'reinstate') {
                                          _confirmReinstate(context, employee);
                                        } else if (value == 'delete') {
                                          _confirmDelete(context, employee);
                                        } else if (value == 'history') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EmployeeRateHistoryScreen(
                                                    employeeId: employee.id!,
                                                    employeeName:
                                                        employee.fullName,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final items = <PopupMenuItem<String>>[];
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Редактировать'),
                                          ),
                                        );
                                        if (isActive) {
                                          items.add(
                                            const PopupMenuItem(
                                              value: 'dismiss',
                                              child: Text('Уволить'),
                                            ),
                                          );
                                        } else {
                                          items.add(
                                            const PopupMenuItem(
                                              value: 'reinstate',
                                              child: Text('Восстановить'),
                                            ),
                                          );
                                        }
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'history',
                                            child: Text('История ставок'),
                                          ),
                                        );
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Удалить',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        );
                                        return items;
                                      },
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEmployeeDialog(BuildContext context, {Employee? employee}) {
    showDialog(
      context: context,
      builder: (context) => EmployeeFormDialog(employee: employee),
    );
  }

  void _showDismissDialog(BuildContext context, Employee employee) {
    final dateController = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(DateTime.now()),
    );
    final reasonController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Увольнение ${employee.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата увольнения'),
              subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  selectedDate = date;
                  dateController.text = DateFormat('dd.MM.yyyy').format(date);
                }
              },
            ),
            AppTextField(
              controller: reasonController,
              labelText: 'Причина увольнения',
              prefixIcon: Icons.description,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            width: 100,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'Уволить',
            width: 100,
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Укажите причину увольнения')),
                );
                return;
              }
              final updated = employee.copyWith(dismissalDate: selectedDate);
              context.read<AppProvider>().updateEmployee(updated);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmReinstate(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Восстановление ${employee.fullName}'),
        content: const Text(
          'Восстановить сотрудника? Он снова станет активным.',
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            width: 100,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'Восстановить',
            width: 100,
            onPressed: () {
              final updated = employee.copyWith(dismissalDate: null);
              context.read<AppProvider>().updateEmployee(updated);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление сотрудника'),
        content: Text(
          'Удалить ${employee.fullName}?\n\n'
          'Все записи табеля и выплаты этого сотрудника также будут удалены.',
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            width: 100,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'Удалить',
            width: 100,
            onPressed: () {
              context.read<AppProvider>().deleteEmployee(employee.id!);
              Navigator.pop(context);
            },
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
