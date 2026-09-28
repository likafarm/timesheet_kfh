// lib/widgets/period_lock_dialogs.dart
//
// Закрытие и открытие месяцев (шаг 6.2): окно с тем, что будет
// зафиксировано и что станет нельзя, затем запрос к серверу через
// SyncProvider. Закрывают бухгалтер и админ, открывает только админ
// (решение владельца 2026-09-28).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import 'adaptive_dialog.dart';

/// «сентябрь 2026» — внутри фразы.
String monthName(int year, int month) =>
    DateFormat('LLLL yyyy', 'ru').format(DateTime(year, month));

/// «Сентябрь 2026» — в начале строки.
String monthTitle(int year, int month) {
  final name = monthName(year, month);
  return name.substring(0, 1).toUpperCase() + name.substring(1);
}

/// Закрыть месяц: окно подтверждения, затем закрытие на сервере. true —
/// месяц закрыт.
Future<bool> closeMonth(BuildContext context, int year, int month) async {
  final app = context.read<AppProvider>();
  final sync = context.read<SyncProvider>();
  final report = await app.payrollReportFor(year, month);
  final earlierOpen = [
    for (final (y, m) in await app.dataMonths())
      if ((y < year || (y == year && m < month)) && !app.isMonthLocked(y, m))
        (y, m),
  ];
  final unsent = await sync.pendingInMonth(year, month);
  if (!context.mounted) return false;
  final note = await showAppDialog<String>(
    context: context,
    builder: (context) => _CloseMonthDialog(
      year: year,
      month: month,
      report: report,
      earlierOpen: earlierOpen,
      unsent: unsent,
    ),
  );
  if (note == null || !context.mounted) return false;
  return _run(
    context,
    () => sync.lockMonth(year, month, note: note),
    done: '${monthTitle(year, month)} закрыт',
  );
}

/// Открыть закрытый месяц (только админ). true — открыт.
Future<bool> openMonth(BuildContext context, int year, int month) async {
  final sync = context.read<SyncProvider>();
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      icon: const Icon(Icons.lock_open),
      title: Text('Открыть ${monthName(year, month)}?'),
      content: const SizedBox(
        width: 440,
        child: Text(
          'Табель, выплаты и ставки за месяц снова можно будет менять на всех '
          'устройствах. Сервер пересчитает расчёт месяца по текущим данным — '
          'зафиксированные суммы могут измениться, как и остатки следующих '
          'месяцев.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Открыть месяц'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  return _run(
    context,
    () => sync.unlockMonth(year, month),
    done: '${monthTitle(year, month)} открыт',
  );
}

/// Выполнить запрос с окном ожидания; ошибка — окно с объяснением.
Future<bool> _run(
  BuildContext context,
  Future<void> Function() action, {
  required String done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  String? error;
  try {
    await action();
  } on SyncUserException catch (e) {
    error = e.message;
  } catch (e) {
    error = '$e';
  }
  if (!context.mounted) return false;
  Navigator.of(context, rootNavigator: true).pop();
  if (error == null) {
    context.read<AppProvider>().setNeedRefreshReports(true);
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  }
  await showAppDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      icon: const Icon(Icons.error_outline),
      title: const Text('Не получилось'),
      content: SizedBox(width: 440, child: Text(error!)),
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

class _CloseMonthDialog extends StatefulWidget {
  final int year;
  final int month;
  final PayrollMonthReport report;
  final List<(int, int)> earlierOpen;
  final int unsent;

  const _CloseMonthDialog({
    required this.year,
    required this.month,
    required this.report,
    required this.earlierOpen,
    required this.unsent,
  });

  @override
  State<_CloseMonthDialog> createState() => _CloseMonthDialogState();
}

class _CloseMonthDialogState extends State<_CloseMonthDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final money = NumberFormat('#,##0.00', 'ru');
    final results = widget.report.results;
    final accrued = results.fold<double>(0, (sum, r) => sum + r.totalSalary);
    Widget warning(String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: 18, color: status.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: status.warningText)),
          ),
        ],
      ),
    );

    return AppDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text('Закрыть ${monthName(widget.year, widget.month)}?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                results.isEmpty
                    ? 'Начислений, выплат и остатков в месяце нет — '
                          'фиксировать нечего.'
                    : 'Будет зафиксирован расчёт: ${results.length} сотр., '
                          'начислено ${money.format(accrued)} ₽.',
              ),
              const SizedBox(height: 8),
              const Text(
                'После закрытия табель, выплаты и ставки за этот месяц нельзя '
                'изменить ни на одном устройстве, а расчёт больше не '
                'пересчитывается. Открыть месяц снова может только '
                'администратор.',
              ),
              if (widget.earlierOpen.isNotEmpty)
                warning(
                  'Раньше этого месяца ещё открыты: '
                  '${widget.earlierOpen.map((m) => monthName(m.$1, m.$2)).join(', ')}. '
                  'Их правки изменят остаток на начало закрываемого месяца.',
                ),
              if (widget.unsent > 0)
                warning(
                  'На этом компьютере ${widget.unsent} неотправл. правок за '
                  'этот месяц. Перед закрытием будет синхронизация; если они '
                  'не дойдут до сервера, месяц не закроется.',
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Примечание (необязательно)',
                  hintText: 'Например: ведомость сдана',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: const Text('Закрыть месяц'),
        ),
      ],
    );
  }
}
