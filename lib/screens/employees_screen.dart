import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/employee_form_dialog.dart';
import '../widgets/employee_schedule_dialog.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadEmployees(activeOnly: !_showAll);
      provider.loadWorkScheduleTypes();
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
                  ElevatedButton(
                    onPressed: () =>
                        provider.loadEmployees(activeOnly: !_showAll),
                    child: const Text('Повторить'),
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
                  ElevatedButton.icon(
                    onPressed: () => _showEmployeeDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить сотрудника'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.employees.length,
            itemBuilder: (context, index) {
              final employee = provider.employees[index];
              return _EmployeeCard(
                employee: employee,
                onEdit: () => _showEmployeeDialog(context, employee: employee),
                onDelete: () => _confirmDelete(context, employee),
                onDismiss: () => _showDismissDialog(context, employee),
                onReinstate: () => _confirmReinstate(context, employee),
                onSchedule: () => _showScheduleDialog(context, employee),
              );
            },
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

  void _showScheduleDialog(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => EmployeeScheduleDialog(employee: employee),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().deleteEmployee(employee.id!);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
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
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Причина увольнения',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Укажите причину увольнения')),
                );
                return;
              }
              context.read<AppProvider>().dismissEmployee(
                employee.id!,
                selectedDate,
                reasonController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Уволить'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().reinstateEmployee(employee.id!);
              Navigator.pop(context);
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;
  final VoidCallback onReinstate;
  final VoidCallback onSchedule;

  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onDelete,
    required this.onDismiss,
    required this.onReinstate,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(employee.fullName);
    final isHourly = employee.paymentType == 'hourly';
    final formatter = NumberFormat('#,##0.00', 'ru');
    final rateText = isHourly
        ? '${formatter.format(employee.hourlyRate)} ₽/час'
        : employee.fixedSalary != null
        ? '${formatter.format(employee.fixedSalary!)} ₽ (оклад)'
        : 'Ставка не указана';

    String statusText = employee.isActive ? 'Активен' : 'Уволен';
    Color statusColor = employee.isActive ? Colors.green : Colors.red;

    // Получаем информацию о графике
    String scheduleInfo = 'Без графика';
    Color scheduleColor = Colors.grey;
    if (employee.isShiftWorker) {
      scheduleInfo = 'Сменный';
      scheduleColor = Colors.blue;
      // Попробуем получить название типа графика
      final provider = context.read<AppProvider>();
      final schedule = provider.employeeSchedules[employee.id];
      if (schedule != null) {
        final scheduleTypeId = schedule['schedule_type_id'] as int?;
        if (scheduleTypeId != null) {
          final types = provider.workScheduleTypes;
          final type = types.firstWhere(
            (t) => t['id'] == scheduleTypeId,
            orElse: () => const <String, dynamic>{},
          );
          if (type.isNotEmpty) {
            scheduleInfo = type['name'] as String? ?? 'Сменный';
          }
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: employee.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[300],
          child: Text(
            initials,
            style: TextStyle(
              color: employee.isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                employee.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: employee.isActive
                      ? null
                      : TextDecoration.lineThrough,
                  color: employee.isActive ? null : Colors.grey,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.position),
            const SizedBox(height: 4),
            Text(
              rateText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (employee.phone != null && employee.phone!.isNotEmpty)
              Text(
                'Тел: ${employee.phone}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (!employee.isActive && employee.dismissalDate != null)
              Text(
                'Уволен: ${DateFormat('dd.MM.yyyy').format(employee.dismissalDate!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (!employee.isActive && employee.dismissalReason != null)
              Text(
                'Причина: ${employee.dismissalReason}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            // Отображение информации о графике
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheduleColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                scheduleInfo,
                style: TextStyle(
                  fontSize: 11,
                  color: scheduleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == 'dismiss') onDismiss();
            if (value == 'reinstate') onReinstate();
            if (value == 'schedule') onSchedule();
          },
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[];
            if (employee.isActive) {
              items.add(
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Редактировать'),
                ),
              );
              items.add(
                const PopupMenuItem(
                  value: 'schedule',
                  child: Text('График работы'),
                ),
              );
              items.add(
                const PopupMenuItem(value: 'dismiss', child: Text('Уволить')),
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
                value: 'delete',
                child: Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            );
            return items;
          },
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
