import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Экран управления выплатами сотрудникам
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выплаты'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => _showGroupPaymentDialog(context),
            tooltip: 'Групповая выплата',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.employees.isEmpty) {
            return const Center(child: Text('Нет сотрудников'));
          }

          return Row(
            children: [
              // Список сотрудников слева
              SizedBox(
                width: 260,
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Сотрудники',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: provider.employees.length,
                          itemBuilder: (context, index) {
                            final emp = provider.employees[index];
                            final isSelected = emp.id == _selectedEmployeeId;

                            return ListTile(
                              selected: isSelected,
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[300],
                                child: Text(
                                  emp.fullName.substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              title: Text(
                                emp.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : null,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                emp.position,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                setState(() => _selectedEmployeeId = emp.id);
                                provider.loadPayments(emp.id!);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // Список выплат справа
              Expanded(
                child: _selectedEmployeeId == null
                    ? const Center(
                        child: Text(
                          'Выберите сотрудника\nдля просмотра выплат',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _PaymentsList(employeeId: _selectedEmployeeId!),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedEmployeeId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPaymentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Выплата'),
            )
          : null,
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    final employee = provider.getEmployeeById(_selectedEmployeeId!);
    if (employee == null) return;

    showDialog(
      context: context,
      builder: (context) => _PaymentFormDialog(
        employee: employee,
        onSave: (payment) => provider.addPayment(payment),
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, Payment payment) {
    final provider = context.read<AppProvider>();
    final employee = provider.getEmployeeById(payment.employeeId);
    if (employee == null) return;

    showDialog(
      context: context,
      builder: (context) => _PaymentFormDialog(
        employee: employee,
        payment: payment,
        onSave: (updatedPayment) => provider.updatePayment(updatedPayment),
      ),
    );
  }

  void _showGroupPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GroupPaymentFormDialog(
        onSave: (payments) {
          final provider = context.read<AppProvider>();
          for (var payment in payments) {
            provider.addPayment(payment);
          }
          if (_selectedEmployeeId != null) {
            provider.loadPayments(_selectedEmployeeId!);
          }
        },
      ),
    );
  }
}

/// Список выплат сотрудника
class _PaymentsList extends StatelessWidget {
  final int employeeId;

  const _PaymentsList({required this.employeeId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.payments.isEmpty) {
          return const Center(
            child: Text('Нет выплат', style: TextStyle(color: Colors.grey)),
          );
        }

        final total = provider.payments.fold(0.0, (sum, p) => sum + p.amount);
        final formatter = NumberFormat('#,##0.00', 'ru');

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Всего выплачено:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${formatter.format(total)} ₽',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.payments.length,
                itemBuilder: (context, index) {
                  final payment = provider.payments[index];
                  return _PaymentCard(
                    payment: payment,
                    employeeId: employeeId,
                    onEdit: () {
                      final screen = context
                          .findAncestorStateOfType<_PaymentsScreenState>();
                      screen?._showEditPaymentDialog(context, payment);
                    },
                    onDelete: () =>
                        provider.deletePayment(payment.id!, employeeId),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Карточка выплаты
class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final int employeeId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentCard({
    required this.payment,
    required this.employeeId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.00', 'ru');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPaymentColor(payment.paymentType),
          child: Icon(
            _getPaymentIcon(payment.paymentType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                '${formatter.format(payment.amount)} ₽',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getPaymentColor(payment.paymentType).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                payment.paymentTypeName,
                style: TextStyle(
                  fontSize: 11,
                  color: _getPaymentColor(payment.paymentType),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd.MM.yyyy').format(payment.paymentDate),
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (payment.periodStart != null && payment.periodEnd != null)
              Text(
                'Период: ${payment.periodStart} — ${payment.periodEnd}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            if (payment.paymentMethod != null)
              Text(
                'Способ: ${payment.paymentMethodName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            if (payment.documentNumber != null)
              Text(
                'Документ: ${payment.documentNumber}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentColor(String type) {
    switch (type) {
      case 'salary':
        return Colors.green;
      case 'advance':
        return Colors.orange;
      case 'bonus':
        return Colors.blue;
      case 'vacation':
        return Colors.purple;
      case 'sick_leave':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'salary':
        return Icons.payments;
      case 'advance':
        return Icons.money_off;
      case 'bonus':
        return Icons.card_giftcard;
      case 'vacation':
        return Icons.beach_access;
      case 'sick_leave':
        return Icons.local_hospital;
      default:
        return Icons.money;
    }
  }
}

/// Диалог добавления/редактирования выплаты
class _PaymentFormDialog extends StatefulWidget {
  final Employee employee;
  final Payment? payment;
  final Function(Payment) onSave;

  const _PaymentFormDialog({
    required this.employee,
    this.payment,
    required this.onSave,
  });

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();

  late String _paymentType;
  String? _paymentMethod;
  late DateTime _date;
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      final p = widget.payment!;
      _amountController.text = p.amount.toString();
      _paymentType = p.paymentType;
      _paymentMethod = p.paymentMethod;
      _date = p.paymentDate;
      _documentController.text = p.documentNumber ?? '';
      _notesController.text = p.notes ?? '';
    } else {
      _paymentType = 'salary';
      _date = DateTime.now();
    }

    _formatControllerText(_amountController);
    _setupNumberField(_amountController, _amountFocusNode);
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
    _amountController.dispose();
    _amountFocusNode.dispose();
    _documentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.payment != null;
    final title = isEditing ? 'Редактирование выплаты' : 'Новая выплата';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.employee.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            widget.employee.position,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Сумма (₽) *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*$')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите сумму';
                  final raw = v
                      .replaceAll(RegExp(r'\s'), '')
                      .replaceAll(',', '.');
                  if (double.tryParse(raw) == null) return 'Введите число';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Тип выплаты',
                  prefixIcon: Icon(Icons.category),
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
                        value: 'salary',
                        child: Text('Зарплата'),
                      ),
                      DropdownMenuItem(value: 'advance', child: Text('Аванс')),
                      DropdownMenuItem(value: 'bonus', child: Text('Премия')),
                      DropdownMenuItem(
                        value: 'vacation',
                        child: Text('Отпускные'),
                      ),
                      DropdownMenuItem(
                        value: 'sick_leave',
                        child: Text('Больничные'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _paymentType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Способ оплаты',
                  prefixIcon: Icon(Icons.payment),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _paymentMethod,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('Не указано'),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('— Не указано —'),
                      ),
                      DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                      DropdownMenuItem(value: 'card', child: Text('На карту')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Перевод'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Дата выплаты'),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy').format(_date),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _documentController,
                decoration: const InputDecoration(
                  labelText: 'Номер документа',
                  prefixIcon: Icon(Icons.description),
                  hintText: '№ расходного ордера',
                ),
              ),
              const SizedBox(height: 12),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final rawAmount = _amountController.text
                .replaceAll(RegExp(r'\s'), '')
                .replaceAll(',', '.');
            if (rawAmount.isEmpty) return;
            final amount = double.tryParse(rawAmount);
            if (amount == null || amount <= 0) return;

            final payment = Payment(
              id: widget.payment?.id,
              employeeId: widget.employee.id!,
              paymentDate: _date,
              amount: amount,
              paymentType: _paymentType,
              paymentMethod: _paymentMethod,
              documentNumber: _documentController.text.isEmpty
                  ? null
                  : _documentController.text,
              notes: _notesController.text.isEmpty
                  ? null
                  : _notesController.text,
            );
            widget.onSave(payment);
            Navigator.pop(context);
          },
          child: Text(isEditing ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}

/// Диалог группового добавления выплат
class _GroupPaymentFormDialog extends StatefulWidget {
  final Function(List<Payment>) onSave;

  const _GroupPaymentFormDialog({required this.onSave});

  @override
  State<_GroupPaymentFormDialog> createState() =>
      _GroupPaymentFormDialogState();
}

class _GroupPaymentFormDialogState extends State<_GroupPaymentFormDialog> {
  DateTime _date = DateTime.now();
  String _paymentType = 'salary';
  String? _paymentMethod;
  final _documentController = TextEditingController();
  final _periodStartController = TextEditingController();
  final _periodEndController = TextEditingController();

  // ignore: prefer_final_fields
  List<Employee> _employees = [];
  // ignore: prefer_final_fields
  Map<int, bool> _selected = {};
  // ignore: prefer_final_fields
  Map<int, TextEditingController> _amountControllers = {};

  bool _isLoading = false;
  bool _allSelected = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.loadEmployees(activeOnly: true);
      setState(() {
        _employees = provider.employees;
        for (var emp in _employees) {
          if (emp.id != null) {
            _selected[emp.id!] = false;
            _amountControllers[emp.id!] = TextEditingController();
          }
        }
        _allSelected = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки сотрудников: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var controller in _amountControllers.values) {
      controller.dispose();
    }
    _documentController.dispose();
    _periodStartController.dispose();
    _periodEndController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _allSelected = value ?? false;
      for (var key in _selected.keys) {
        _selected[key] = _allSelected;
      }
    });
  }

  void _fillAllAmounts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заполнить сумму'),
        content: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Сумма для всех (₽)',
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*$')),
          ],
          onChanged: (value) {
            final amount = double.tryParse(value.replaceAll(',', '.'));
            if (amount != null && amount > 0) {
              setState(() {
                for (var key in _selected.keys) {
                  if (_selected[key] == true) {
                    _amountControllers[key]?.text = amount.toStringAsFixed(2);
                  }
                }
              });
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _save() {
    List<Payment> payments = [];
    bool hasError = false;

    for (var emp in _employees) {
      final id = emp.id!;
      if (_selected[id] == true) {
        final amountText = _amountControllers[id]?.text.trim() ?? '';
        if (amountText.isEmpty) {
          hasError = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Для ${emp.fullName} не указана сумма')),
          );
          break;
        }
        final amount = double.tryParse(amountText.replaceAll(',', '.'));
        if (amount == null || amount <= 0) {
          hasError = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('У ${emp.fullName} некорректная сумма')),
          );
          break;
        }
        final payment = Payment(
          employeeId: id,
          paymentDate: _date,
          amount: amount,
          paymentType: _paymentType,
          periodStart: _periodStartController.text.trim().isEmpty
              ? null
              : _periodStartController.text.trim(),
          periodEnd: _periodEndController.text.trim().isEmpty
              ? null
              : _periodEndController.text.trim(),
          paymentMethod: _paymentMethod,
          documentNumber: _documentController.text.trim().isEmpty
              ? null
              : _documentController.text.trim(),
        );
        payments.add(payment);
      }
    }

    if (hasError) return;
    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного сотрудника')),
      );
      return;
    }

    widget.onSave(payments);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.group_add),
          SizedBox(width: 8),
          Text('Групповая выплата'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildCommonFields(),
                  const Divider(height: 24),
                  Expanded(child: _buildEmployeesList()),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Тип выплаты',
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
                        value: 'salary',
                        child: Text('Зарплата'),
                      ),
                      DropdownMenuItem(value: 'advance', child: Text('Аванс')),
                      DropdownMenuItem(value: 'bonus', child: Text('Премия')),
                      DropdownMenuItem(
                        value: 'vacation',
                        child: Text('Отпускные'),
                      ),
                      DropdownMenuItem(
                        value: 'sick_leave',
                        child: Text('Больничные'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _paymentType = v!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Способ оплаты',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _paymentMethod,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('Не указано'),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('— Не указано —'),
                      ),
                      DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                      DropdownMenuItem(value: 'card', child: Text('На карту')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Перевод'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Дата выплаты'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _documentController,
                decoration: const InputDecoration(
                  labelText: 'Номер документа',
                  prefixIcon: Icon(Icons.description),
                  hintText: '№ расходного ордера',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _periodStartController,
                decoration: const InputDecoration(
                  labelText: 'Период с',
                  prefixIcon: Icon(Icons.date_range),
                  hintText: '01.01.2025',
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    _periodStartController.text = DateFormat(
                      'dd.MM.yyyy',
                    ).format(date);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _periodEndController,
                decoration: const InputDecoration(
                  labelText: 'Период по',
                  prefixIcon: Icon(Icons.date_range),
                  hintText: '31.01.2025',
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    _periodEndController.text = DateFormat(
                      'dd.MM.yyyy',
                    ).format(date);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeesList() {
    if (_employees.isEmpty) {
      return const Center(child: Text('Нет активных сотрудников'));
    }

    return Column(
      children: [
        Row(
          children: [
            Checkbox(value: _allSelected, onChanged: _toggleSelectAll),
            const Expanded(
              child: Text('ФИО', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(
              width: 100,
              child: Text(
                'Сумма (₽)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: _fillAllAmounts,
              tooltip: 'Заполнить сумму для всех выбранных',
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _employees.length,
            itemBuilder: (context, index) {
              final emp = _employees[index];
              final id = emp.id!;
              return Row(
                children: [
                  Checkbox(
                    value: _selected[id] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selected[id] = value ?? false;
                        _allSelected = _selected.values.every((v) => v);
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      emp.fullName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _amountControllers[id],
                      enabled: _selected[id] ?? false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '0.00',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[,.]?\d*$'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
