// lib/widgets/payroll_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../models/payroll_result.dart';
import '../models/employee.dart';

class PayrollDetailDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
              const SizedBox(height: 0),
              _buildStartTotals(currencyFormat, startingBalance),
              const SizedBox(height: 16),
              _buildAccrualSection(currencyFormat, daysFormat),
              const SizedBox(height: 16),
              _buildPaymentsSection(sortedPayments, currencyFormat),
              const SizedBox(height: 20),
              _buildTotals(currencyFormat, balance),
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

  Widget _buildAccrualSection(NumberFormat currency, NumberFormat days) {
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
      Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          _headerRow(['Вид', 'Дни', 'Ставка', 'Сумма']),
          ...rows.map(
            (r) => _row([
              r.name,
              days.format(double.tryParse(r.days) ?? 0),
              r.rate != null
                  ? currency.format(double.tryParse(r.rate!) ?? 0)
                  : '—',
              currency.format(double.tryParse(r.amount) ?? 0),
            ]),
          ),
          _footerRow(['ИТОГО', '', '', currency.format(result.totalSalary)]),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(List<Payment> items, NumberFormat currency) {
    return _buildSection(
      'Выплаты',
      Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          _headerRow(['Дата', 'Вид', 'Способ', 'Сумма']),
          ...items.map(
            (p) => _row([
              DateFormat('dd.MM.yyyy').format(p.paymentDate),
              p.paymentTypeName,
              p.paymentMethodName,
              currency.format(p.amount),
            ]),
          ),
          _footerRow([
            'ИТОГО',
            '',
            '',
            currency.format(items.fold<double>(0, (s, i) => s + i.amount)),
          ]),
        ],
      ),
    );
  }

  TableRow _headerRow(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      children: cells
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                t,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _row(List<String> cells) {
    return TableRow(
      children: cells
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(t, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
    );
  }

  TableRow _footerRow(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      children: cells
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                t,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTotals(NumberFormat currency, double balance) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'К выплате на конец месяца:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
        children: [
          const Text(
            'К выплате на начало месяца:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
