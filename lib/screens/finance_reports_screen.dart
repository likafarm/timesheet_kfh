// lib/screens/finance_reports_screen.dart
//
// «Финансы → Отчёты» (8Б.1): список отчётов финансов вместо пункта меню на
// каждый. Отчёт открывается поверх списка, модель — общая.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import 'finance_balance_sheet_screen.dart';
import 'finance_report_screen.dart';

class FinanceReportsScreen extends StatelessWidget {
  const FinanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    void open(FinanceReportMode mode) => openFinanceReport(
      context,
      context.read<FinanceProvider>(),
      year: year,
      mode: mode,
    );
    Widget report(
      IconData icon,
      String title,
      String subtitle,
      FinanceReportMode mode,
    ) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(mode),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты по финансам')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.balance),
                  title: const Text('Управленческий баланс'),
                  subtitle: const Text(
                    'Что есть и что должны — на начало года и на дату; '
                    'капитал хозяйства',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final fin = context.read<FinanceProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: fin,
                          child: const FinanceBalanceSheetScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              report(
                Icons.calendar_view_month,
                'Доходы и расходы по месяцам',
                'Статьи или направления × месяцы года, итог «доходы − '
                    'расходы»; выгрузка в Excel',
                FinanceReportMode.category,
              ),
              report(
                Icons.agriculture_outlined,
                'Себестоимость кормов',
                'Затраты и выручка растениеводства по сезонам урожая',
                FinanceReportMode.season,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
