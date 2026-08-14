import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../utils/string_utils.dart';

/// Экран управления выплатами (табличный вид с фильтрацией по периоду и сотруднику)
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  DateTime _selectedMonth = DateTime.now();
  int? _selectedEmployeeId;

  // Фиксированная ширина таблицы (гарантирует горизонтальную прокрутку)
  final double _tableWidth = 1020.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadEmployees();
      _loadPayments();
    });
  }

  void _loadPayments() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final provider = context.read<AppProvider>();
    if (_selectedEmployeeId == null) {
      provider.loadAllPayments(startDate: start, endDate: end);
    } else {
      provider.loadPaymentsByEmployee(
        _selectedEmployeeId!,
        startDate: start,
        endDate: end,
      );
    }
  }

  void _goToToday() {
    setState(() {
      _selectedMonth = DateTime.now();
    });
    _loadPayments();
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите месяц и год',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('LLLL yyyy', 'ru').format(_selectedMonth);
    final capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выплаты'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
              _loadPayments();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: GestureDetector(
                onTap: _selectMonth,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    capitalizedMonth,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
              _loadPayments();
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _goToToday,
            tooltip: 'Текущий месяц',
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => _showGroupPaymentDialog(context),
            tooltip: 'Групповая выплата',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Expanded(child: _buildEmployeeFilter(provider)),
                    const SizedBox(width: 16),
                    if (provider.payments.isNotEmpty)
                      Text(
                        'Всего: ${NumberFormat('#,##0.00', 'ru').format(provider.payments.fold(0.0, (sum, p) => sum + p.amount))} ₽',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'Добавить',
                      icon: Icons.add,
                      onPressed: () => _showAddPaymentDialog(context),
                      width: 120,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нет выплат за этот период',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        // ОБЩАЯ ГОРИЗОНТАЛЬНАЯ ПРОКРУТКА для заголовка и тела
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _tableWidth,
                          child: Column(
                            children: [
                              // Заголовок (фиксированная ширина, без фона)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: const [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Дата',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        'Сотрудник',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Тип',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Сумма',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        'Способ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Документ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        'Примечания',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Тело таблицы с вертикальной прокруткой
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      children: provider.payments.map((
                                        payment,
                                      ) {
                                        final employee = provider
                                            .getEmployeeById(
                                              payment.employeeId,
                                            );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 100,
                                                child: Text(
                                                  DateFormat(
                                                    'dd.MM.yyyy',
                                                  ).format(payment.paymentDate),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 200,
                                                child: Text(
                                                  employee?.fullName ??
                                                      'Неизвестно',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 80,
                                                child: Text(
                                                  payment.paymentTypeName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 100,
                                                child: Text(
                                                  '${NumberFormat('#,##0.00', 'ru').format(payment.amount)} ₽',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 90,
                                                child: Text(
                                                  payment.paymentMethodName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 100,
                                                child: Text(
                                                  payment.documentNumber ?? '—',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 150,
                                                child: Text(
                                                  payment.notes ?? '—',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 48,
                                                child: PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _showEditPaymentDialog(
                                                        context,
                                                        payment,
                                                      );
                                                    } else if (value ==
                                                        'delete') {
                                                      _confirmDelete(
                                                        context,
                                                        payment,
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text(
                                                        'Редактировать',
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text(
                                                        'Удалить',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                  ),
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmployeeFilter(AppProvider provider) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Все сотрудники')),
      ...provider.employees.map((e) {
        return DropdownMenuItem<int?>(
          value: e.id,
          child: Text(StringUtils.getShortName(e.fullName)),
        );
      }),
    ];

    return AppDropdown<int?>(
      value: _selectedEmployeeId,
      items: items,
      onChanged: (value) {
        setState(() {
          _selectedEmployeeId = value;
        });
        _loadPayments();
      },
      labelText: 'Сотрудник',
      prefixIcon: Icons.person,
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PaymentFormDialog(
        employeeId: _selectedEmployeeId,
        onSave: (payment) async {
          final provider = context.read<AppProvider>();
          await provider.addPayment(payment);
          _loadPayments();
        },
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => _PaymentFormDialog(
        employeeId: payment.employeeId,
        payment: payment,
        onSave: (updatedPayment) async {
          final provider = context.read<AppProvider>();
          await provider.updatePayment(updatedPayment);
          _loadPayments();
        },
      ),
    );
  }

  void _showGroupPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GroupPaymentFormDialog(
        onSave: (payments) async {
          final provider = context.read<AppProvider>();
          for (var payment in payments) {
            await provider.addPayment(payment);
          }
          _loadPayments();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление выплаты'),
        content: Text(
          'Удалить выплату ${payment.paymentTypeName} на ${NumberFormat('#,##0.00', 'ru').format(payment.amount)} ₽?',
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
            onPressed: () async {
              final provider = context.read<AppProvider>();
              await provider.deletePayment(payment.id!, payment.employeeId);
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              _loadPayments();
            },
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// ДИАЛОГ ДОБАВЛЕНИЯ/РЕДАКТИРОВАНИЯ ВЫПЛАТЫ
// ==========================================================================

class _PaymentFormDialog extends StatefulWidget {
  final int? employeeId;
  final Payment? payment;
  final Function(Payment) onSave;

  const _PaymentFormDialog({
    this.employeeId,
    this.payment,
    required this.onSave,
  });

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedEmployeeId;
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();

  String _paymentType = 'salary';
  String? _paymentMethod;
  DateTime _date = DateTime.now();
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.employeeId;
    if (widget.payment != null) {
      final p = widget.payment!;
      _selectedEmployeeId = p.employeeId;
      _amountController.text = p.amount.toString();
      _paymentType = p.paymentType;
      _paymentMethod = p.paymentMethod;
      _date = p.paymentDate;
      _documentController.text = p.documentNumber ?? '';
      _notesController.text = p.notes ?? '';
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedEmployeeId == null)
                  Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final items = provider.employees.map((e) {
                        return DropdownMenuItem<int>(
                          value: e.id,
                          child: Text(StringUtils.getShortName(e.fullName)),
                        );
                      }).toList();

                      return AppDropdown<int>(
                        value: _selectedEmployeeId,
                        items: items,
                        onChanged: (value) {
                          setState(() {
                            _selectedEmployeeId = value;
                          });
                        },
                        labelText: 'Сотрудник *',
                        prefixIcon: Icons.person,
                      );
                    },
                  ),
                if (_selectedEmployeeId != null)
                  Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final employee = provider.getEmployeeById(
                        _selectedEmployeeId!,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee?.fullName ?? 'Неизвестно',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    employee?.position ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  labelText: 'Сумма (₽) *',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                AppDropdown<String>(
                  value: _paymentType,
                  items: const [
                    DropdownMenuItem(value: 'salary', child: Text('Зарплата')),
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
                  labelText: 'Тип выплаты',
                  prefixIcon: Icons.category,
                ),
                const SizedBox(height: 12),
                AppDropdown<String?>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('— Не указано —'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                    DropdownMenuItem(value: 'card', child: Text('На карту')),
                    DropdownMenuItem(value: 'transfer', child: Text('Перевод')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v),
                  labelText: 'Способ оплаты',
                  prefixIcon: Icons.payment,
                ),
                const SizedBox(height: 12),
                ListTile(
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
                const SizedBox(height: 12),
                AppTextField(
                  controller: _documentController,
                  labelText: 'Номер документа',
                  prefixIcon: Icons.description,
                  hintText: '№ расходного ордера',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _notesController,
                  labelText: 'Примечания',
                  prefixIcon: Icons.notes,
                  maxLines: 2,
                ),
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
          onPressed: () {
            if (_selectedEmployeeId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Выберите сотрудника')),
              );
              return;
            }
            final rawAmount = _amountController.text
                .replaceAll(RegExp(r'\s'), '')
                .replaceAll(',', '.');
            if (rawAmount.isEmpty) return;
            final amount = double.tryParse(rawAmount);
            if (amount == null || amount <= 0) return;

            final payment = Payment(
              id: widget.payment?.id,
              employeeId: _selectedEmployeeId!,
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
        ),
      ],
    );
  }
}

// ==========================================================================
// ГРУППОВОЙ ДИАЛОГ ДОБАВЛЕНИЯ ВЫПЛАТ
// ==========================================================================

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
      if (!mounted) return;
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
        content: AppTextField(
          labelText: 'Сумма для всех (₽)',
          prefixIcon: Icons.attach_money,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
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
          AppButton(
            label: 'Закрыть',
            isText: true,
            width: 100,
            onPressed: () => Navigator.pop(context),
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
        AppButton(
          label: 'Отмена',
          isText: true,
          width: 100,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(label: 'Сохранить', width: 100, onPressed: _save),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdown<String>(
                value: _paymentType,
                items: const [
                  DropdownMenuItem(value: 'salary', child: Text('Зарплата')),
                  DropdownMenuItem(value: 'advance', child: Text('Аванс')),
                  DropdownMenuItem(value: 'bonus', child: Text('Премия')),
                  DropdownMenuItem(value: 'vacation', child: Text('Отпускные')),
                  DropdownMenuItem(
                    value: 'sick_leave',
                    child: Text('Больничные'),
                  ),
                ],
                onChanged: (v) => setState(() => _paymentType = v!),
                labelText: 'Тип выплаты',
                prefixIcon: Icons.category,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppDropdown<String?>(
                value: _paymentMethod,
                items: const [
                  DropdownMenuItem(value: null, child: Text('— Не указано —')),
                  DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                  DropdownMenuItem(value: 'card', child: Text('На карту')),
                  DropdownMenuItem(value: 'transfer', child: Text('Перевод')),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v),
                labelText: 'Способ оплаты',
                prefixIcon: Icons.payment,
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
              child: AppTextField(
                controller: _documentController,
                labelText: 'Номер документа',
                prefixIcon: Icons.description,
                hintText: '№ расходного ордера',
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
                      StringUtils.getShortName(emp.fullName),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: AppTextField(
                      controller: _amountControllers[id],
                      enabled: _selected[id] ?? false,
                      labelText: 'Сумма',
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
