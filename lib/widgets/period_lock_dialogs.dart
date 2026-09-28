// lib/widgets/period_lock_dialogs.dart
//
// Закрытие и открытие месяцев (шаг 6.2): окно с тем, что будет
// зафиксировано и что станет нельзя, затем запрос к серверу через
// SyncProvider. Закрывают бухгалтер и админ, открывает только админ
// (решение владельца 2026-09-28).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';
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
  final closed = await _run(context, () async {
    await sync.lockMonth(year, month, note: note);
    return true;
  }, done: '${monthTitle(year, month)} закрыт');
  return closed ?? false;
}

/// Открыть закрытый месяц (только админ): сервер показывает, как изменятся
/// начисления и остатки, админ подтверждает; прежние суммы сервер сохраняет
/// снимком. true — открыт.
Future<bool> openMonth(BuildContext context, int year, int month) async {
  final sync = context.read<SyncProvider>();
  final preview = await _run(context, () => sync.unlockPreview(year, month));
  if (preview == null || !context.mounted) return false;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => _OpenMonthDialog(preview: preview),
  );
  if (ok != true || !context.mounted) return false;
  final opened = await _run(
    context,
    () async {
      await sync.unlockMonth(year, month);
      return true;
    },
    done:
        '${monthTitle(year, month)} открыт. Прежние суммы сохранены в снимке '
        '(Настройки, «Закрытие месяцев»).',
  );
  return opened ?? false;
}

/// Выполнить запрос с окном ожидания; ошибка — окно с объяснением и null.
/// [done] — сообщение внизу окна после успеха (и отчёты перечитываются).
Future<T?> _run<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  String? error;
  T? result;
  try {
    result = await action();
  } on SyncUserException catch (e) {
    error = e.message;
  } catch (e) {
    error = '$e';
  }
  if (!context.mounted) return null;
  Navigator.of(context, rootNavigator: true).pop();
  if (error == null) {
    if (done != null) {
      context.read<AppProvider>().setNeedRefreshReports(true);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }
    return result;
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
  return null;
}

final _money = NumberFormat('#,##0.00', 'ru');

/// «1 000,00 ₽».
String rub(double v) => '${_money.format(v)} ₽';

String _dateTime(DateTime at) =>
    DateFormat('dd.MM.yyyy HH:mm').format(at.toLocal());

/// Таблица изменений остатков по месяцам: только изменившиеся строки;
/// в изменившейся ячейке прежнее значение зачёркнуто, под ним новое
/// (стрелки в шрифте веб-версии нет), в неизменной — одно значение.
class BalanceChangesTable extends StatelessWidget {
  final List<MonthRows<BalanceChange>> changes;

  const BalanceChangesTable({super.key, required this.changes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);

    Widget value(double before, double after, {bool bold = false}) {
      final changed = (before - after).abs() >= 0.005;
      final now = Text(
        rub(after),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : null,
          color: changed ? status.warningText : scheme.onSurfaceVariant,
        ),
      );
      if (!changed) return now;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            rub(before),
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          now,
        ],
      );
    }

    final head = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    final rows = <TableRow>[
      TableRow(
        children: [
          Text('Сотрудник', style: head),
          for (final h in ['На начало', 'Начислено', 'Выплачено', 'На конец'])
            Text(h, style: head, textAlign: TextAlign.right),
        ],
      ),
    ];
    for (final m in changes) {
      rows.add(
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                monthTitle(m.year, m.month),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (var i = 0; i < 4; i++) const SizedBox(),
          ],
        ),
      );
      for (final c in m.rows) {
        rows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(c.fullName, style: const TextStyle(fontSize: 12)),
              ),
              value(c.before.starting, c.after.starting),
              value(c.before.accrued, c.after.accrued),
              value(c.before.paid, c.after.paid),
              value(c.before.closing, c.after.closing, bold: true),
            ],
          ),
        );
      }
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1.7),
        2: FlexColumnWidth(1.7),
        3: FlexColumnWidth(1.7),
        4: FlexColumnWidth(1.7),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}

/// Сколько сотрудников и строк (сотрудник × месяц) изменилось.
String _changesSummary(List<MonthRows<BalanceChange>> changes) {
  final people = {
    for (final m in changes)
      for (final c in m.rows) c.after.employeeUuid,
  };
  final lines = changes.fold<int>(0, (n, m) => n + m.rows.length);
  return 'Изменилось строк: $lines, сотрудников: ${people.length}.';
}

/// Подтверждение открытия: что изменит пересчёт.
class _OpenMonthDialog extends StatelessWidget {
  final UnlockPreview preview;

  const _OpenMonthDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lock = preview.lock;
    final lockedBy = [
      if (lock?.lockedByName != null) lock!.lockedByName!,
      if (lock?.lockedAt != null) _dateTime(lock!.lockedAt!),
    ].join(', ');

    return AppDialog(
      icon: const Icon(Icons.lock_open),
      title: Text(
        'Открыть ${monthName(preview.year, preview.month)} и пересчитать?',
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lockedBy.isNotEmpty)
                Text(
                  'Месяц закрыт: $lockedBy'
                  '${lock?.note == null ? '' : ' («${lock!.note}»)'}.',
                ),
              const SizedBox(height: 8),
              const Text(
                'Табель, выплаты и ставки за месяц снова можно будет менять на '
                'всех устройствах, а расчёт этого и следующих открытых месяцев '
                'сервер пересчитает по текущим данным.',
              ),
              const SizedBox(height: 12),
              if (preview.changes.isEmpty)
                const Text(
                  'Пересчёт не изменит ни начислений, ни остатков.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                )
              else ...[
                Text(
                  'Что изменится (зачёркнуто — было, ниже — станет). '
                  '${_changesSummary(preview.changes)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                BalanceChangesTable(changes: preview.changes),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Прежние начисления и остатки сервер сохранит снимком — '
                      'посмотреть в «Настройки», «Закрытие месяцев», раздел '
                      '«Снимки до открытия»; там же кнопка «Что изменилось».',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            preview.changes.isEmpty ? 'Открыть месяц' : 'Открыть и пересчитать',
          ),
        ),
      ],
    );
  }
}

/// Снимок остатков до открытия месяца — таблицы по месяцам; кнопка «Что
/// изменилось» сравнивает его с расчётами сейчас.
Future<void> showPeriodSnapshot(BuildContext context, int id) async {
  final sync = context.read<SyncProvider>();
  final snapshot = await _run(context, () => sync.periodSnapshot(id));
  if (snapshot == null || !context.mounted) return;
  await showAppDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final head = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
      Widget sum(double v, {bool bold = false}) => Text(
        rub(v),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      );
      final at = snapshot.createdAt;
      return AppDialog(
        icon: const Icon(Icons.inventory_2_outlined),
        title: Text(
          'Остатки до открытия: ${monthName(snapshot.year, snapshot.month)}',
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Месяц открыт: ${snapshot.createdByName ?? '—'}'
                  '${at == null ? '' : ', ${_dateTime(at)}'}. Ниже — суммы по '
                  'расчётам, какими они были до пересчёта. Сравнить с тем, '
                  'что стало, — кнопка «Что изменилось».',
                ),
                for (final m in snapshot.months) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      monthTitle(m.year, m.month),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.4),
                      1: FlexColumnWidth(1.6),
                      2: FlexColumnWidth(1.6),
                      3: FlexColumnWidth(1.6),
                      4: FlexColumnWidth(1.6),
                    },
                    children: [
                      TableRow(
                        children: [
                          Text('Сотрудник', style: head),
                          for (final h in [
                            'На начало',
                            'Начислено',
                            'Выплачено',
                            'На конец',
                          ])
                            Text(h, style: head, textAlign: TextAlign.right),
                        ],
                      ),
                      for (final b in m.rows)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                b.fullName,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            sum(b.starting),
                            sum(b.accrued),
                            sum(b.paid),
                            sum(b.closing, bold: true),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.compare_arrows, size: 18),
            label: const Text('Что изменилось'),
            onPressed: () => showSnapshotChanges(context, id),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}

/// Что изменилось со времени снимка: только изменившиеся строки, было —
/// стало. Сравнение делает сервер: снимок против расчётов сейчас (и
/// пересчёт при открытии, и правки после него).
Future<void> showSnapshotChanges(BuildContext context, int id) async {
  final sync = context.read<SyncProvider>();
  final result = await _run(context, () => sync.periodSnapshotChanges(id));
  if (result == null || !context.mounted) return;
  final snap = result.snapshot;
  await showAppDialog<void>(
    context: context,
    builder: (context) {
      final created = snap.createdAt;
      final compared = result.comparedAt;
      return AppDialog(
        icon: const Icon(Icons.compare_arrows),
        title: Text('Что изменилось: ${monthName(snap.year, snap.month)}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Снимок перед открытием'
                  '${created == null ? '' : ' (${_dateTime(created)})'} '
                  'сравнён с расчётами на сервере сейчас'
                  '${compared == null ? '' : ' (${_dateTime(compared)})'}: '
                  'учтены и пересчёт при открытии, и правки после него. '
                  'Показаны только строки, где что-то стало другим: '
                  'зачёркнуто — было, ниже — стало.',
                ),
                const SizedBox(height: 12),
                if (result.changes.isEmpty)
                  const Text(
                    'С момента снимка начисления и остатки не изменились.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  )
                else ...[
                  Text(
                    _changesSummary(result.changes),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  BalanceChangesTable(changes: result.changes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
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
                          'начислено ${rub(accrued)}.',
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
