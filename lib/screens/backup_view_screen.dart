// lib/screens/backup_view_screen.dart
//
// Открытая копия (модуль «Резервные копии»): что в ней лежит.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../theme/app_theme.dart';

/// Откуда копия.
enum BackupSource { local, server }

/// Таблицы копии для человека.
const backupTableLabels = <String, String>{
  'employees': 'Сотрудники',
  'employee_rates': 'Ставки',
  'timesheet': 'Дни табеля',
  'payments': 'Выплаты',
  'sick_leave': 'Больничные',
  'vacation': 'Отпуска',
  'payroll_results': 'Расчёты ЗП',
  'company_settings': 'Реквизиты хозяйства',
};

class BackupViewScreen extends StatelessWidget {
  final String title;
  final DateTime takenAt;
  final BackupSource source;
  final DataSnapshot snapshot;

  const BackupViewScreen({
    super.key,
    required this.title,
    required this.takenAt,
    required this.source,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = snapshot.counts;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        children: [
          Text(
            '${source == BackupSource.server ? 'Копия сервера' : 'Копия этого компьютера'}'
            ' на ${DateFormat('dd.MM.yyyy HH:mm').format(takenAt)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final MapEntry(key: table, value: label)
                    in backupTableLabels.entries)
                  ListTile(
                    dense: true,
                    title: Text(label),
                    trailing: Text(
                      '${counts[table] ?? 0}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
