// lib/widgets/payroll_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../models/payroll_result.dart';
import '../models/employee.dart';

/// Детальная расшифровка начислений/удержаний/выплат сотрудника за месяц.
class PayrollDetailDialog extends StatelessWidget {
  final Employee employee;
  final PayrollResult result;
  final List<Payment> payments;

  const PayrollDetailDialog({
    super.key,
    required this.employee,
    required this.result,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('LLLL yyyy', 'ru').format(
      DateTime(result.year, result.month),
    );
    final capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    final currencyFormat = NumberFormat('#,##0.00', 'ru');
    final daysFormat = NumberFormat('#,##0.0', 'ru');

    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    final totalAccrued = result.totalSalary;
    final totalPaid = sortedPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final balance = totalAccrued - totalPaid;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(employee.fullName),
          const SizedBox(height: 4),
          Text(
            '${employee.position} · $capitalizedMonth',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
              _sectionTitle('Начисления'),
              _buildAccrualTable(currencyFormat, daysFormat),
              const SizedBox(height: 16),
              _sectionTitle('Выплаты'),
              _buildPaymentsTable(sortedPayments, currencyFormat),
              const SizedBox(height: 20),
              _buildTotals(
                currencyFormat,
                totalAccrued,
                totalPaid,
                balance,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAccrualTable(NumberFormat currency, NumberFormat days) {
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
      _AccrualRow(
        'Больничный',
        result.sickDays,
        null,
        0,
      ),
      _AccrualRow(
        'Отпуск',
        result.vacationDays,
        null,
        0,
      ),
    ];

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        _headerRow(['Вид', 'Дни', 'Ставка, ₽', 'Сумма, ₽']),
        ...rows.map((r) {
          return TableRow(
            children: [
              _cell(r.name),
              _cell(days.format(r.days), align: TextAlign.right),
              _cell(
                r.rate != null ? currency.format(r.rate) : '—',
                align: TextAlign.right,
              ),
              _cell(currency.format(r.amount), align: TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPaymentsTable(List<Payment> items, NumberFormat currency) {
    if (items.isEmpty) {
      return Text(
        'Выплат нет',
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        _headerRow(['Дата', 'Вид', 'Способ', 'Сумма, ₽']),
        ...items.map((p) {
          final date = DateFormat('dd.MM.yyyy').format(p.paymentDate);
          final method = p.paymentMethodName != 'Не указано'
              ? p.paymentMethodName
              : '—';
          return TableRow(
            children: [
              _cell(date),
              _cell(p.paymentTypeName),
              _cell(method),
              _cell(
                '${currency.format(p.amount)} ₽',
                align: TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  TableRow _headerRow(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      children: cells
          .map(
            (text) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _cell(
    String text, {
    TextAlign align = TextAlign.left,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, color: color),
      ),
    );
  }

  Widget _buildTotals(
    NumberFormat currency,
    double totalAccrued,
    double totalPaid,
    double balance,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow('Начислено', totalAccrued, currency),
          _buildSummaryRow('Выплачено', totalPaid, currency),
          const Divider(),
          _buildSummaryRow('Остаток', balance, currency, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    NumberFormat currency, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${currency.format(value)} ₽',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: value < 0
                  ? Colors.red
                  : (value > 0 ? Colors.green[800] : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccrualRow {
  final String name;
  final double days;
  final double? rate;
  final double amount;

  _AccrualRow(this.name, this.days, this.rate, this.amount);
}
