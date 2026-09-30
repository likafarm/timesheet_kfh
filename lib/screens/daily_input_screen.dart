// lib/screens/daily_input_screen.dart
//
// Ввод табеля за день на телефоне (шаг 4.4): список работающих сотрудников,
// у каждого — крупные кнопки отметок; удобно одной рукой. Сумм и ставок
// здесь нет.
//
// 6.10 (решение владельца 2026-09-30): касание меняет черновик
// ([DayDraft]), в базу — по «Сохранить» одной транзакцией. Уход с дня с
// несохранёнными отметками (другой день, «назад», выход) — окно «Сохранить
// отметки?» со списком изменений. Черновик хранится на диске и
// восстанавливается, если программу закрыла система.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_draft.dart';
import '../utils/string_utils.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/closed_month.dart';

export '../utils/day_draft.dart' show DayMark;

class DailyInputScreen extends StatefulWidget {
  final DateTime? initialDate;

  /// Отдельная страница (с кнопкой «назад»), а не раздел навигации.
  final bool standalone;

  /// Заголовок страницы.
  final String title;

  /// Над списком (например, текст напоминания).
  final Widget? header;

  /// Черновик сохранён кнопкой «Сохранить».
  final VoidCallback? onSaved;

  /// Отметки можно ставить (окно напоминания: false, пока телефон
  /// заблокирован).
  final bool inputEnabled;

  const DailyInputScreen({
    super.key,
    this.initialDate,
    this.standalone = false,
    this.title = 'Ввод за день',
    this.header,
    this.onSaved,
    this.inputEnabled = true,
  });

  @override
  State<DailyInputScreen> createState() => _DailyInputScreenState();
}

class _DailyInputScreenState extends State<DailyInputScreen> {
  late DateTime _date;
  late DayDraft _draft;

  /// Записи дня в базе.
  Map<String, TimesheetRecord> _records = {};
  bool _saving = false;
  late final AppProvider _app;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now();
    _date = DateTime(d.year, d.month, d.day);
    _draft = DayDraft(_date);
    _app = context.read<AppProvider>();
    // Синхронизация приняла данные — отметки дня могли измениться.
    _app.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreDraft();
      await _app.loadEmployees();
      await _refresh();
    });
  }

  @override
  void dispose() {
    _app.removeListener(_refresh);
    super.dispose();
  }

  /// Черновик, оставшийся с прошлого раза (программу закрыла система).
  Future<void> _restoreDraft() async {
    final saved = await DayDraftStore.load();
    if (saved == null || !mounted) return;
    setState(() {
      _date = saved.date;
      _draft = saved;
      _records = {};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Восстановлены несохранённые отметки за '
          '${DateFormat('d MMMM', 'ru').format(saved.date)}',
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final date = _date;
    final list = await _app.getTimesheetForDate(date);
    if (!mounted || date != _date) return;
    setState(() => _records = {for (final r in list) r.employeeId: r});
  }

  void _setDate(DateTime d) {
    setState(() {
      _date = DateTime(d.year, d.month, d.day);
      _draft = DayDraft(_date);
      _records = {};
    });
    _refresh();
  }

  /// Перейти на другой день — сначала решить судьбу черновика.
  Future<void> _go(DateTime d) async {
    if (await _confirmLeave()) _setDate(d);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'День табеля',
    );
    if (picked != null) await _go(picked);
  }

  void _mark(Employee e, DayMark? mark) {
    final id = e.id!;
    setState(() => _draft.set(id, mark, _records[id]));
    DayDraftStore.save(_draft);
  }

  void _undoAll() {
    final copy = _draft.toJson();
    setState(_draft.clear);
    DayDraftStore.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Изменения отменены'),
        action: SnackBarAction(
          label: 'Вернуть',
          onPressed: () {
            final back = DayDraft.fromJson(copy);
            if (back == null || !mounted || back.date != _date) return;
            setState(() => _draft = back);
            DayDraftStore.save(back);
          },
        ),
      ),
    );
  }

  /// Записать черновик в базу. Не получилось (месяц закрыт, ошибка) —
  /// false, черновик на месте.
  Future<bool> _save() async {
    if (_draft.isEmpty) return true;
    if (!await ensureMonthOpen(context, _date.year, _date.month)) return false;
    setState(() => _saving = true);
    final count = _draft.length;
    final ok = await _app.saveDayMarks(_date, _draft.toRecords());
    if (!mounted) return ok;
    setState(() => _saving = false);
    if (!ok) return false;
    setState(_draft.clear);
    await DayDraftStore.clear();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Сохранено отметок: $count')));
    }
    return true;
  }

  /// Можно уйти с дня: черновик пуст, сохранён или отброшен.
  Future<bool> _confirmLeave() async {
    if (_draft.isEmpty) return true;
    await _refresh();
    if (!mounted) return false;
    final decision = await confirmDayDraft(
      context,
      draft: _draft,
      saved: _records,
      employees: _app.employees,
    );
    switch (decision) {
      case DraftDecision.save:
        return _save();
      case DraftDecision.discard:
        setState(_draft.clear);
        await DayDraftStore.clear();
        return true;
      case DraftDecision.stay:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final day = _date;
    final employees = provider.employees
        .where(
          (e) => !calendarDay(e.hireDate).isAfter(day) && e.isActiveOn(day),
        )
        .toList();
    final locked = provider.isMonthLocked(day.year, day.month);
    bool marked(Employee e) => _draft.changes(e.id!)
        ? _draft.markOf(e.id!) != null
        : _records.containsKey(e.id);
    final markedCount = employees.where(marked).length;
    final today = DateTime.now();
    final isToday = day == DateTime(today.year, today.month, today.day);

    return PopScope(
      canPop: _draft.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: false,
          automaticallyImplyLeading: widget.standalone,
          actions: [
            if (!isToday)
              TextButton(
                onPressed: () => _go(DateTime.now()),
                child: const Text('Сегодня'),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Row(
              children: [
                IconButton(
                  iconSize: 32,
                  tooltip: 'Предыдущий день',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _go(addCalendarDays(day, -1)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat('EEE, d MMMM yyyy', 'ru').format(day),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ClosedMonthBadge(year: day.year, month: day.month),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 32,
                  tooltip: 'Следующий день',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _go(addCalendarDays(day, 1)),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _draft.isEmpty
            ? null
            : _DraftBar(
                count: _draft.length,
                saving: _saving,
                onUndo: _undoAll,
                onSave: () async {
                  if (await _save()) widget.onSaved?.call();
                },
              ),
        body: employees.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'В этот день нет работающих сотрудников.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                // Отдельной страницей экран доходит до системных кнопок.
                padding: EdgeInsets.only(
                  bottom:
                      16 +
                      (_draft.isEmpty
                          ? MediaQuery.viewPaddingOf(context).bottom
                          : 0),
                ),
                itemCount: employees.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ?widget.header,
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            locked
                                ? 'Месяц закрыт — отметки менять нельзя.'
                                : 'Отмечено $markedCount из ${employees.length}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final e = employees[i - 1];
                  final saved = _records[e.id];
                  final changed = _draft.changes(e.id!);
                  return _EmployeeDayCard(
                    employee: e,
                    record: saved,
                    changed: changed,
                    draftMark: _draft.markOf(e.id!),
                    before: _draft.beforeOf(e.id!),
                    meanwhile: _draft.changedMeanwhile(e.id!, saved),
                    enabled: !locked && !_saving && widget.inputEnabled,
                    onMark: (mark) => _mark(e, mark),
                  );
                },
              ),
      ),
    );
  }
}

/// Окно «Сохранить отметки?»: что изменено у кого (было → станет) и что
/// успело измениться в базе. Закрыли окно мимо кнопок — [DraftDecision.stay].
Future<DraftDecision> confirmDayDraft(
  BuildContext context, {
  required DayDraft draft,
  required Map<String, TimesheetRecord> saved,
  required List<Employee> employees,
}) async {
  final names = {for (final e in employees) e.id: e.fullName};
  final changes = draft.list(saved);
  final theme = Theme.of(context);
  final warning = StatusColors.of(context).warningText;
  final decision = await showAppDialog<DraftDecision>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(
        'Сохранить отметки за '
        '${DateFormat('d MMMM', 'ru').format(draft.date)}?',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Не сохранено изменений: ${changes.length}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final c in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      StringUtils.getShortName(names[c.employeeId] ?? '—'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: c.after,
                            style: TextStyle(
                              color: c.mark?.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '  (было: ${c.before})',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.changedMeanwhile != null)
                      Text(
                        'Уже изменено другим: ${c.changedMeanwhile}',
                        style: TextStyle(color: warning),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(DraftDecision.stay),
          child: const Text('Вернуться'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DraftDecision.discard),
          child: const Text('Не сохранять'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DraftDecision.save),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  return decision ?? DraftDecision.stay;
}

/// Полоса внизу: сколько не сохранено, «Отменить», «Сохранить».
class _DraftBar extends StatelessWidget {
  final int count;
  final bool saving;
  final VoidCallback onUndo;
  final VoidCallback onSave;

  const _DraftBar({
    required this.count,
    required this.saving,
    required this.onUndo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          // Две строки (просьба владельца): надпись, под ней — кнопки во
          // всю ширину.
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Не сохранено: $count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: saving ? null : onUndo,
                      child: const Text('Отменить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeDayCard extends StatelessWidget {
  final Employee employee;

  /// Запись в базе.
  final TimesheetRecord? record;

  /// Отметка изменена в черновике: [draftMark] — новая (null — снята),
  /// [before] — что было.
  final bool changed;
  final DayMark? draftMark;
  final String? before;

  /// Запись в базе изменилась после начала правки — что там сейчас.
  final String? meanwhile;
  final bool enabled;
  final void Function(DayMark? mark) onMark;

  const _EmployeeDayCard({
    required this.employee,
    required this.record,
    required this.changed,
    required this.draftMark,
    required this.before,
    required this.meanwhile,
    required this.enabled,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final theme = Theme.of(context);
    bool selected(DayMark mark) =>
        changed ? draftMark == mark : r != null && mark.matches(r);
    final hasMark = changed ? draftMark != null : r != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: changed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (changed)
                        Text(
                          'не сохранено · было: ${before ?? '—'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      if (meanwhile != null)
                        Text(
                          'уже изменено другим: $meanwhile',
                          style: TextStyle(
                            fontSize: 12,
                            color: StatusColors.of(context).warningText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasMark)
                  IconButton(
                    tooltip: 'Очистить отметку',
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: enabled ? () => onMark(null) : null,
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mark in DayMark.all)
                  _MarkButton(
                    mark: mark,
                    selected: selected(mark),
                    onPressed: enabled ? () => onMark(mark) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  final DayMark mark;
  final bool selected;
  final VoidCallback? onPressed;

  const _MarkButton({
    required this.mark,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const size = Size(76, 48);
    const padding = EdgeInsets.symmetric(horizontal: 10);
    final label = Text(mark.label, style: const TextStyle(fontSize: 14));
    if (selected) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: mark.color,
          disabledBackgroundColor: mark.color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          minimumSize: size,
          padding: padding,
        ),
        onPressed: onPressed,
        child: label,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: mark.color,
        minimumSize: size,
        padding: padding,
      ),
      onPressed: onPressed,
      child: label,
    );
  }
}
