// lib/widgets/closed_month.dart
//
// Закрытые на сервере месяцы в интерфейсе: отметка рядом с названием месяца
// и объяснение при попытке правки (правка всё равно не записалась бы —
// см. AppProvider, и сервер её не принял бы).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

const _closedColor = Color(0xFFB26A00);

String _monthText(int year, int month) =>
    '${month.toString().padLeft(2, '0')}.$year';

/// Отметка «закрыт» рядом с названием месяца; пусто, если месяц открыт.
class ClosedMonthBadge extends StatelessWidget {
  final int year;
  final int month;

  const ClosedMonthBadge({super.key, required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppProvider, bool>(
      (p) => p.isMonthLocked(year, month),
    );
    if (!locked) return const SizedBox.shrink();
    return Tooltip(
      message:
          'Месяц ${_monthText(year, month)} закрыт на сервере: правки в нём не '
          'сохраняются. Открыть месяц может бухгалтер или администратор.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _closedColor),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 14, color: _closedColor),
            SizedBox(width: 4),
            Text('закрыт', style: TextStyle(fontSize: 12, color: _closedColor)),
          ],
        ),
      ),
    );
  }
}

/// Перед правкой: месяц открыт — true; закрыт — объяснение и false.
Future<bool> ensureMonthOpen(BuildContext context, int year, int month) async {
  if (!context.read<AppProvider>().isMonthLocked(year, month)) return true;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_outline, color: _closedColor),
      title: Text('Месяц ${_monthText(year, month)} закрыт'),
      content: const SizedBox(
        width: 400,
        child: Text(
          'Месяц закрыт на сервере — табель, выплаты и расчёт за него '
          'изменить нельзя. Если нужно исправление, попросите бухгалтера или '
          'администратора открыть месяц; после синхронизации правки снова '
          'станут доступны.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
  return false;
}
