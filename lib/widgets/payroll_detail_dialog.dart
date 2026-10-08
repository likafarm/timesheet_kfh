// lib/widgets/payroll_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import 'adaptive_dialog.dart';

class PayrollDetailDialog extends StatefulWidget {
  final Employee employee;
  final PayrollResult result;
  final List<Payment> payments;
  final double startingBalance;

  const PayrollDetailDialog({
    super.key,
    required this.employee,
    required this.result,
    required this.payments,
    required this.startingBalance,
  });

  @override
  State<PayrollDetailDialog> createState() => _PayrollDetailDialogState();
}

class _PayrollDetailDialogState extends State<PayrollDetailDialog> {
  late PayrollResult result = widget.result;
  List<PayrollAdjustment> _adjustments = const [];

  Employee get employee => widget.employee;
  List<Payment> get payments => widget.payments;
  double get startingBalance => widget.startingBalance;

  @override
  void initState() {
    super.initState();
    _loadAdjustments();
  }

  Future<void> _loadAdjustments() async {
    final id = employee.id;
    if (id == null) return;
    final list = await context.read<AppProvider>().adjustmentsInMonth(
      id,
      result.year,
      result.month,
    );
    if (mounted) setState(() => _adjustments = list);
  }

  /// После правки корректировки: открытый месяц — свежий пересчёт.
  Future<void> _afterChange() async {
    final provider = context.read<AppProvider>();
    await _loadAdjustments();
    if (!provider.isMonthLocked(result.year, result.month)) {
      final calc = await provider.calculatePayroll(
        employee.id!,
        result.year,
        result.month,
      );
      if (mounted) {
        setState(() => result = PayrollResult.fromCalculation(calc));
      }
    }
    await provider.loadPayrollReport(result.year, result.month);
  }

  Future<void> _editAdjustment([PayrollAdjustment? old]) async {
    final provider = context.read<AppProvider>();
    final edited = await showAppDialog<_AdjustmentEdit>(
      context: context,
      builder: (_) => _AdjustmentDialog(old: old),
    );
    if (edited == null || !mounted) return;
    final bool ok;
    if (edited.delete) {
      ok = await provider.deleteAdjustment(old!);
    } else {
      ok = await provider.saveAdjustment(
        PayrollAdjustment(
          id: old?.id,
          employeeId: employee.id!,
          year: result.year,
          month: result.month,
          amount: edited.amount,
          notes: edited.notes,
        ),
        old: old,
      );
    }
    if (ok) await _afterChange();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final canEdit =
        !provider.operatorMode &&
        employee.id != null &&
        !provider.isMonthLocked(result.year, result.month);
    final monthName = DateFormat(
      'LLLL yyyy',
      'ru',
    ).format(DateTime(result.year, result.month));
    final capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    final currencyFormat = NumberFormat('#,##0.00', 'ru');
    final daysFormat = NumberFormat('#,##0.0', 'ru');

    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    final totalAccrued = result.totalSalary;
    final totalPaid = sortedPayments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );
    final balance = startingBalance + totalAccrued - totalPaid;

    return AppDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(employee.fullName),
          const SizedBox(height: 4),
          Text(
            '${employee.position} · $capitalizedMonth',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.skippedWorkDays > 0) ...[
                Material(
                  color: StatusColors.of(context).warningBackground,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'В расчёт не вошли рабочие дни без ставки: ${result.skippedWorkDays}. '
                      'Проверьте историю ставок сотрудника.',
                      style: TextStyle(
                        color: StatusColors.of(context).warningText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildStartTotals(currencyFormat, startingBalance),
              const SizedBox(height: 16),
              _buildAccrualSection(currencyFormat, daysFormat, canEdit),
              const SizedBox(height: 16),
              _buildPaymentsSection(sortedPayments, currencyFormat),
              const SizedBox(height: 20),
              _buildTotals(currencyFormat, balance),
            ],
          ),
        ),
      ),
      actions: [
        if (canEdit)
          TextButton.icon(
            onPressed: _editAdjustment,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Корректировка'),
          ),
        TextButton.icon(
          onPressed: () async {
            final provider = context.read<AppProvider>();
            if (provider.companySettings == null) {
              await provider.loadCompanySettings();
            }
            try {
              await PrintService.printEmployeeReport(
                employee: employee,
                result: result,
                payments: sortedPayments,
                startingBalance: startingBalance,
                adjustments: _adjustments,
                companySettings: provider.companySettings,
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Ошибка печати: $e')));
            }
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Печать'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildAccrualSection(
    NumberFormat currency,
    NumberFormat days,
    bool canEdit,
  ) {
    final rows = [
      _AccrualRow(
        'Работа на базе',
        result.baseDays,
        result.baseRateUsed,
        result.baseDays * (result.baseRateUsed ?? 0),
      ),
      _AccrualRow(
        'Работа в поле',
        result.fieldDays,
        result.fieldRateUsed,
        result.fieldDays * (result.fieldRateUsed ?? 0),
      ),
      _AccrualRow('Больничный', result.sickDays, null, 0),
      _AccrualRow('Отпуск', result.vacationDays, null, 0),
    ];

    return _buildSection(
      'Начисления',
      // Таблица — по ширине окна (телефон, 6.10): текст переносится,
      // числа — целиком и по правому краю.
      Table(
        columnWidths: const {0: FlexColumnWidth()},
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          _headerRow(['Вид', 'Дни', 'Ставка', 'Сумма'], numeric: {1, 2, 3}),
          ...rows.map(
            (r) => _row(
              [
                r.name,
                days.format(double.tryParse(r.days) ?? 0),
                r.rate != null
                    ? currency.format(double.tryParse(r.rate!) ?? 0)
                    : '—',
                currency.format(double.tryParse(r.amount) ?? 0),
              ],
              numeric: {1, 2, 3},
            ),
          ),
          for (final a in _adjustments)
            TableRow(
              children: [
                for (final (i, t) in [
                  _adjustmentName(a),
                  '',
                  '—',
                  currency.format(a.amount),
                ].indexed)
                  TableRowInkWell(
                    onTap: canEdit ? () => _editAdjustment(a) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 13),
                        textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                      ),
                    ),
                  ),
              ],
            ),
          _footerRow(
            ['ИТОГО', '', '', currency.format(result.totalSalary)],
            numeric: {3},
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(List<Payment> items, NumberFormat currency) {
    return _buildSection(
      'Выплаты',
      Table(
        columnWidths: const {1: FlexColumnWidth(), 2: FlexColumnWidth()},
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          _headerRow(['Дата', 'Вид', 'Способ', 'Сумма'], numeric: {3}),
          ...items.map(
            (p) => _row(
              [
                DateFormat('dd.MM.yyyy').format(p.paymentDate),
                p.paymentTypeName,
                p.paymentMethodName,
                currency.format(p.amount),
              ],
              numeric: {3},
            ),
          ),
          _footerRow(
            [
              'ИТОГО',
              '',
              '',
              currency.format(items.fold<double>(0, (s, i) => s + i.amount)),
            ],
            numeric: {3},
          ),
        ],
      ),
    );
  }

  /// Ячейки строки таблицы; [numeric] — номера столбцов с числами (по
  /// правому краю).
  List<Widget> _cells(
    List<String> cells,
    TextStyle style, {
    Set<int> numeric = const {},
  }) => [
    for (final (i, t) in cells.indexed)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Text(
          t,
          style: style,
          textAlign: numeric.contains(i) ? TextAlign.right : TextAlign.left,
        ),
      ),
  ];

  TableRow _headerRow(List<String> cells, {Set<int> numeric = const {}}) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      children: _cells(
        cells,
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        numeric: numeric,
      ),
    );
  }

  TableRow _row(List<String> cells, {Set<int> numeric = const {}}) {
    return TableRow(
      children: _cells(cells, const TextStyle(fontSize: 13), numeric: numeric),
    );
  }

  TableRow _footerRow(List<String> cells, {Set<int> numeric = const {}}) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      children: _cells(
        cells,
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        numeric: numeric,
      ),
    );
  }

  Widget _buildTotals(NumberFormat currency, double balance) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Надпись переносится, сумма — всегда целиком.
          const Expanded(
            child: Text(
              'К выплате на конец месяца:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${currency.format(balance)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: balance < 0 ? Colors.red : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartTotals(NumberFormat currency, double startingBalance) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Надпись переносится, сумма — всегда целиком.
          const Expanded(
            child: Text(
              'К выплате на начало месяца:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${currency.format(startingBalance)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: startingBalance < 0 ? Colors.red : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccrualRow {
  final String name;
  final String days;
  final String? rate;
  final String amount;

  _AccrualRow(this.name, double d, double? r, double a)
    : days = d.toString(),
      rate = r?.toString(),
      amount = a.toString();
}

/// Подпись корректировки в таблице начислений.
String _adjustmentName(PayrollAdjustment a) =>
    a.notes == null || a.notes!.isEmpty
    ? 'Корректировка'
    : 'Корректировка: ${a.notes}';

/// Итог окна корректировки: сумма и примечание или удаление.
class _AdjustmentEdit {
  final double amount;
  final String? notes;
  final bool delete;
  const _AdjustmentEdit(this.amount, this.notes, {this.delete = false});
}

/// Окно корректировки начисления: сумма (минус — удержание) и примечание.
class _AdjustmentDialog extends StatefulWidget {
  final PayrollAdjustment? old;
  const _AdjustmentDialog({this.old});

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  late final _amount = TextEditingController(
    text: widget.old == null
        ? ''
        : NumberFormat('0.##', 'ru').format(widget.old!.amount),
  );
  late final _notes = TextEditingController(text: widget.old?.notes ?? '');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final text = _amount.text
        .replaceAll(RegExp(r'[\s ]'), '')
        .replaceAll(',', '.')
        .replaceAll('−', '-');
    final value = double.tryParse(text);
    if (value == null || value == 0) {
      setState(() => _error = 'Введите сумму, для удержания — с минусом');
      return;
    }
    final notes = _notes.text.trim();
    Navigator.of(
      context,
    ).pop(_AdjustmentEdit(value, notes.isEmpty ? null : notes));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Корректировка начисления'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Сумма, ₽',
                helperText: 'Плюс — доплата, минус — удержание',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                hintText: 'Надбавка, премия, вычет…',
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.old != null)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _AdjustmentEdit(0, null, delete: true)),
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
