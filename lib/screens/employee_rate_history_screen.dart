// lib/screens/employee_rate_history_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee_rate.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

class EmployeeRateHistoryScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;

  const EmployeeRateHistoryScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeRateHistoryScreen> createState() =>
      _EmployeeRateHistoryScreenState();
}

class _EmployeeRateHistoryScreenState extends State<EmployeeRateHistoryScreen> {
  List<EmployeeRate> _rates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<AppProvider>();
      await provider.loadEmployeeRates(employeeId: widget.employeeId);
      setState(() {
        _rates = provider.employeeRates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История ставок: ${widget.employeeName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка: $_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  AppButton(label: 'Повторить', onPressed: _loadHistory),
                ],
              ),
            )
          : _rates.isEmpty
          ? const Center(child: Text('История ставок пуста'))
          : ListView.builder(
              itemCount: _rates.length,
              itemBuilder: (context, index) {
                final rate = _rates[index];
                final formatter = NumberFormat('#,##0.00', 'ru');
                final isActive = rate.endDate == null;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Colors.green[100]
                          : Colors.grey[300],
                      child: Text(
                        isActive ? '✓' : '•',
                        style: TextStyle(
                          color: isActive
                              ? Colors.green[800]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'База: ${formatter.format(rate.baseRate)} ₽',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Поле: ${formatter.format(rate.fieldRate)} ₽',
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'c ${DateFormat('dd.MM.yyyy').format(rate.startDate)}'
                      '${rate.endDate != null ? ' по ${DateFormat('dd.MM.yyyy').format(rate.endDate!)}' : ' — действует'}',
                    ),
                    trailing: isActive
                        ? const Chip(
                            label: Text('Активна'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
