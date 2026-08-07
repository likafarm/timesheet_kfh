import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Выплаты'), centerTitle: false),
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

        // Считаем итого
        final total = provider.payments.fold(0.0, (sum, p) => sum + p.amount);

        return Column(
          children: [
            // Итого
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
                    '${total.toStringAsFixed(2)} ₽',
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
            // Список
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.payments.length,
                itemBuilder: (context, index) {
                  final payment = provider.payments[index];
                  return _PaymentCard(
                    payment: payment,
                    onDelete: () => provider.deletePayment(payment.id!),
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
  final VoidCallback onDelete;

  const _PaymentCard({required this.payment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            Text(
              '${payment.amount.toStringAsFixed(2)} ₽',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление выплаты'),
        content: Text(
          'Удалить выплату ${payment.paymentTypeName} на ${payment.amount.toStringAsFixed(2)} ₽?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
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

/// Диалог добавления выплаты
class _PaymentFormDialog extends StatefulWidget {
  final Employee employee;
  final Function(Payment) onSave;

  const _PaymentFormDialog({required this.employee, required this.onSave});

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final _amountController = TextEditingController();
  String _paymentType = 'salary';
  String? _paymentMethod;
  DateTime _date = DateTime.now();
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая выплата'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Сотрудник
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
              // Сумма
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма (₽) *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              // Тип выплаты
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
              // Способ оплаты
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
              // Дата
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
              // Номер документа
              TextField(
                controller: _documentController,
                decoration: const InputDecoration(
                  labelText: 'Номер документа',
                  prefixIcon: Icon(Icons.description),
                  hintText: '№ расходного ордера',
                ),
              ),
              const SizedBox(height: 12),
              // Примечания
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
            if (_amountController.text.isEmpty) return;
            final amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) return;

            final payment = Payment(
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
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
