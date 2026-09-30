// lib/screens/employees_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/common_widgets.dart';
import '../widgets/employee_form_dialog.dart';
import 'employee_rate_history_screen.dart';

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
    if (context.read<AppProvider>().operatorMode) {
      return _OperatorEmployeeList(showAll: _showAll, onToggle: _toggleFilter);
    }
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

          if (MediaQuery.sizeOf(context).width < AppTheme.compactWidth) {
            return _compactList(context, provider);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _tableWidth,
              child: Column(
                children: [
                  // ===== ШАПКА ТАБЛИЦЫ (С ЧЕРТОЙ) =====
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey)),
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
                  // ===== ТЕЛО ТАБЛИЦЫ =====
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
                            final isActive = employee.isActive;
                            final formatter = NumberFormat('#,##0.00', 'ru');
                            // Текущие ставки — из истории ставок (действующие
                            // сегодня), а не из карточки сотрудника.
                            final rate = provider.currentRate(employee.id!);
                            final scheme = Theme.of(context).colorScheme;
                            final status = StatusColors.of(context);

                            return InkWell(
                              onLongPress: () =>
                                  openEmployeeCard(context, employee: employee),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  color: isActive
                                      ? null
                                      : scheme.surfaceContainerHighest
                                            .withValues(alpha: 0.5),
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
                                        rate == null
                                            ? 'нет ставки'
                                            : '${formatter.format(rate.baseRate)} ₽',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: rate == null
                                              ? status.negative
                                              : null,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        rate == null
                                            ? '—'
                                            : '${formatter.format(rate.fieldRate)} ₽',
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
                                              ? status.positive.withValues(
                                                  alpha: 0.16,
                                                )
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          isActive ? 'Активен' : 'Уволен',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isActive
                                                ? status.positive
                                                : scheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 48,
                                      child: _menu(context, employee),
                                    ),
                                  ],
                                ),
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
    openEmployeeCard(context, employee: employee);
  }

  /// Меню сотрудника: карточка, увольнение или восстановление, ставки.
  Widget _menu(BuildContext context, Employee employee) =>
      PopupMenuButton<String>(
        tooltip: 'Действия',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _showEmployeeDialog(context, employee: employee);
            case 'dismiss':
              _showDismissDialog(context, employee);
            case 'reinstate':
              _confirmReinstate(context, employee);
            case 'history':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeRateHistoryScreen(
                    employeeId: employee.id!,
                    employeeName: employee.fullName,
                  ),
                ),
              );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
          if (employee.isActive)
            const PopupMenuItem(value: 'dismiss', child: Text('Уволить'))
          else
            const PopupMenuItem(
              value: 'reinstate',
              child: Text('Восстановить'),
            ),
          const PopupMenuItem(value: 'history', child: Text('Ставки')),
        ],
      );

  /// Телефон (6.10): список вместо широкой таблицы; карточка — долгим
  /// нажатием.
  Widget _compactList(BuildContext context, AppProvider provider) {
    final money = NumberFormat('#,##0', 'ru');
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: provider.employees.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = provider.employees[i];
        final rate = provider.currentRate(e.id!);
        final dismissal = e.dismissalDate;
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 4),
          title: Text(
            e.fullName,
            style: TextStyle(
              decoration: e.isActive ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (e.position.isNotEmpty) e.position,
                  'с ${DateFormat('dd.MM.yyyy').format(e.hireDate)}',
                  if (dismissal != null)
                    'уволен ${DateFormat('dd.MM.yyyy').format(dismissal)}',
                ].join(' · '),
              ),
              Text(
                rate == null
                    ? 'нет ставки'
                    : 'база ${money.format(rate.baseRate)} ₽ · '
                          'поле ${money.format(rate.fieldRate)} ₽',
                style: TextStyle(
                  color: rate == null
                      ? status.negative
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: _menu(context, e),
          onTap: () => showLongPressHint(context),
          onLongPress: () => openEmployeeCard(context, employee: e),
        );
      },
    );
  }

  void _showDismissDialog(BuildContext context, Employee employee) {
    showAppDialog<void>(
      context: context,
      builder: (_) => _DismissDialog(employee: employee),
    );
  }

  void _confirmReinstate(BuildContext context, Employee employee) {
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text('Восстановление ${employee.fullName}'),
        content: const Text(
          'Восстановить сотрудника? Он снова станет активным.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final updated = employee.copyWith(clearDismissalDate: true);
              context.read<AppProvider>().updateEmployee(updated);
              Navigator.pop(dialogContext);
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }
}

/// Подсказка на касание строки сотрудника: карточка — долгим нажатием.
void showLongPressHint(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Удерживайте строку, чтобы открыть карточку'),
        duration: Duration(seconds: 2),
      ),
    );
}

/// Увольнение (6.10: в стиле окна выплаты — на телефоне панель снизу).
class _DismissDialog extends StatefulWidget {
  final Employee employee;

  const _DismissDialog({required this.employee});

  @override
  State<_DismissDialog> createState() => _DismissDialogState();
}

class _DismissDialogState extends State<_DismissDialog> {
  DateTime _date = DateTime.now();
  final _reason = TextEditingController();
  String? _reasonError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final hired = calendarDay(widget.employee.hireDate);
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(hired) ? hired : _date,
      firstDate: hired,
      lastDate: DateTime.now(),
      helpText: 'Дата увольнения',
    );
    if (date != null) setState(() => _date = date);
  }

  void _dismiss() {
    if (_reason.text.trim().isEmpty) {
      setState(() => _reasonError = 'Укажите причину увольнения');
      return;
    }
    context.read<AppProvider>().updateEmployee(
      widget.employee.copyWith(dismissalDate: _date),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text('Увольнение ${widget.employee.fullName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата увольнения',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd.MM.yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Причина увольнения',
                prefixIcon: const Icon(Icons.description),
                border: const OutlineInputBorder(),
                errorText: _reasonError,
              ),
              onChanged: (_) {
                if (_reasonError != null) setState(() => _reasonError = null);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'День увольнения уже нерабочий.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _dismiss, child: const Text('Уволить')),
      ],
    );
  }
}

/// Сотрудники в программе оператора: только просмотр, без ставок (сервер
/// оператору их не отдаёт) и без правки.
class _OperatorEmployeeList extends StatelessWidget {
  final bool showAll;
  final VoidCallback onToggle;

  const _OperatorEmployeeList({required this.showAll, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final employees = provider.employees;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники'),
        centerTitle: false,
        actions: [
          const Text('Только работающие'),
          Switch(value: !showAll, onChanged: (_) => onToggle()),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  showAll
                      ? 'Сотрудников нет. Они придут с сервера после входа.'
                      : 'Нет работающих сотрудников.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = employees[i];
                final dismissal = e.dismissalDate;
                return ListTile(
                  onTap: () => showLongPressHint(context),
                  onLongPress: () => openEmployeeCard(context, employee: e),
                  title: Text(
                    e.fullName,
                    style: TextStyle(
                      decoration: e.isActive
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (e.position.isNotEmpty) e.position,
                      'с ${DateFormat('dd.MM.yyyy').format(e.hireDate)}',
                      if (dismissal != null)
                        'уволен ${DateFormat('dd.MM.yyyy').format(dismissal)}',
                    ].join(' · '),
                  ),
                );
              },
            ),
    );
  }
}
