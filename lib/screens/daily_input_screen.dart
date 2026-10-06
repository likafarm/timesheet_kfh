// lib/screens/daily_input_screen.dart
//
// Ввод табеля за день (шаг 4.4): список работающих сотрудников, у каждого —
// кнопки отметок. На телефоне — карточки с крупными кнопками, удобно одной
// рукой; на компьютере и в браузере (решение владельца 2026-10-06) — тот же
// экран строками: ФИО и кнопки в одну линию, клавиши 1–7, ↑/↓, Delete,
// Ctrl+S. «Всем без отметки» ставит выбранную отметку всем, у кого её нет.
//
// 6.10 (решение владельца 2026-09-30): касание меняет черновик
// ([DayDraft]), в базу — по «Сохранить» одной транзакцией. Уход с дня с
// несохранёнными отметками (другой день, «назад», выход) — окно «Сохранить
// отметки?» со списком изменений. Черновик хранится на диске и
// восстанавливается, если программу закрыла система.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_draft.dart';
import '../utils/string_utils.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/closed_month.dart';
import '../widgets/day_mark_button.dart';

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

/// Высота строки сотрудника на широком экране (строки одной высоты —
/// клавиши ↑/↓ прокручивают список без замеров).
const double _rowExtent = 60;

/// Клавиши отметок: 1–7 в порядке [DayMark.all].
const _markKeys = [
  [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
  [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
  [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
  [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
  [LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5],
  [LogicalKeyboardKey.digit6, LogicalKeyboardKey.numpad6],
  [LogicalKeyboardKey.digit7, LogicalKeyboardKey.numpad7],
];

class _DailyInputScreenState extends State<DailyInputScreen> {
  late DateTime _date;
  late DayDraft _draft;

  /// Записи дня в базе.
  Map<String, TimesheetRecord> _records = {};

  /// Ставки на день (не оператору): подсказка над кнопками на компьютере.
  Map<String, EmployeeRate?> _rates = {};
  bool _saving = false;
  late final AppProvider _app;

  /// Строка, к которой относятся клавиши (номер в списке дня).
  int? _cursor;
  final _keys = FocusNode(debugLabel: 'Ввод за день');
  final _scroll = ScrollController();

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
    _keys.dispose();
    _scroll.dispose();
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
    final rates = <String, EmployeeRate?>{};
    if (!_app.operatorMode) {
      for (final e in _app.employees) {
        rates[e.id!] = await _app.getEmployeeRateAtDate(e.id!, date);
      }
    }
    if (!mounted || date != _date) return;
    setState(() {
      _records = {for (final r in list) r.employeeId: r};
      _rates = rates;
    });
  }

  void _setDate(DateTime d) {
    setState(() {
      _date = DateTime(d.year, d.month, d.day);
      _draft = DayDraft(_date);
      _records = {};
      _rates = {};
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

  /// Есть ли у сотрудника отметка с учётом черновика.
  bool _marked(Employee e) => _draft.changes(e.id!)
      ? _draft.markOf(e.id!) != null
      : _records.containsKey(e.id);

  /// «Всем без отметки»: [mark] — каждому, у кого отметки нет.
  void _fillUnmarked(List<Employee> employees, DayMark mark) {
    final targets = employees.where((e) => !_marked(e)).toList();
    if (targets.isEmpty) return;
    setState(() {
      for (final e in targets) {
        _draft.set(e.id!, mark, _records[e.id]);
      }
    });
    DayDraftStore.save(_draft);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${mark.label}» — отмечено: ${targets.length}')),
    );
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

  Future<void> _saveAndReport() async {
    if (await _save()) widget.onSaved?.call();
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

  /// Перевести строку клавишами и показать её.
  void _moveCursor(int to, int count) {
    if (count == 0) return;
    final row = to.clamp(0, count - 1);
    setState(() => _cursor = row);
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final top = row * _rowExtent;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (top + _rowExtent >
        position.pixels + position.viewportDimension) {
      _scroll.jumpTo(
        (top + _rowExtent - position.viewportDimension).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
    }
  }

  KeyEventResult _onKey(
    KeyEvent event,
    List<Employee> employees,
    bool enabled,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = employees.length;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed && key == LogicalKeyboardKey.keyS) {
      if (!_draft.isEmpty && !_saving) _saveAndReport();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(_cursor == null ? 0 : _cursor! + 1, count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveCursor(_cursor == null ? 0 : _cursor! - 1, count);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent || count == 0 || !enabled) {
      return KeyEventResult.ignored;
    }
    final row = (_cursor ?? 0).clamp(0, count - 1);
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _mark(employees[row], null);
      _moveCursor(row, count);
      return KeyEventResult.handled;
    }
    for (final (i, keys) in _markKeys.indexed) {
      if (keys.contains(key)) {
        _mark(employees[row], DayMark.all[i]);
        // Следующая строка — чтобы идти по списку одними цифрами.
        _moveCursor(row + 1, count);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Подсказка над кнопкой на компьютере: клавиша и ставка дня.
  String? _hint(Employee e, DayMark mark, bool wide) {
    final parts = <String>[
      if (wide) 'Клавиша ${DayMark.all.indexOf(mark) + 1}',
    ];
    if (!_app.operatorMode && mark.workPlace != null) {
      final rate = _rates[e.id];
      final value = mark.workPlace == 'base'
          ? rate?.baseRate ?? e.baseRate
          : rate?.fieldRate ?? e.fieldRate;
      parts.add(
        mark.days == 1
            ? 'Ставка: ${StringUtils.formatDayRate(value)}'
            : 'Ставка: ${StringUtils.formatDayRate(value)}, полдня — половина',
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
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
    final enabled = !locked && !_saving && widget.inputEnabled;
    final markedCount = employees.where(_marked).length;
    final unmarked = employees.length - markedCount;
    final today = DateTime.now();
    final isToday = day == DateTime(today.year, today.month, today.day);
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.compactWidth;
    final cursor = _cursor == null || employees.isEmpty
        ? null
        : _cursor!.clamp(0, employees.length - 1);

    final status = Text(
      locked
          ? 'Месяц закрыт — отметки менять нельзя.'
          : 'Отмечено $markedCount из ${employees.length}',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final fill = _FillUnmarkedButton(
      onSelected: enabled && unmarked > 0
          ? (mark) => _fillUnmarked(employees, mark)
          : null,
    );

    final Widget body;
    if (employees.isEmpty) {
      body = Center(
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
      );
    } else if (wide) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?widget.header,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: [status, const Spacer(), fill]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Клавиши: 1–7 — отметка (по порядку кнопок), ↑/↓ — '
                  'строка, Delete — очистить, Ctrl+S — сохранить.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: _rowExtent,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: employees.length,
                  itemBuilder: (context, i) {
                    final e = employees[i];
                    final saved = _records[e.id];
                    return _EmployeeDayRow(
                      employee: e,
                      record: saved,
                      changed: _draft.changes(e.id!),
                      draftMark: _draft.markOf(e.id!),
                      before: _draft.beforeOf(e.id!),
                      meanwhile: _draft.changedMeanwhile(e.id!, saved),
                      current: i == cursor,
                      enabled: enabled,
                      hint: (mark) => _hint(e, mark, true),
                      onMark: (mark) {
                        _mark(e, mark);
                        setState(() => _cursor = i);
                        _keys.requestFocus();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView.builder(
        // Отдельной страницей экран доходит до системных кнопок.
        padding: EdgeInsets.only(
          bottom:
              16 +
              (_draft.isEmpty ? MediaQuery.viewPaddingOf(context).bottom : 0),
        ),
        itemCount: employees.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?widget.header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(child: status),
                      fill,
                    ],
                  ),
                ),
              ],
            );
          }
          final e = employees[i - 1];
          final saved = _records[e.id];
          return _EmployeeDayCard(
            employee: e,
            record: saved,
            changed: _draft.changes(e.id!),
            draftMark: _draft.markOf(e.id!),
            before: _draft.beforeOf(e.id!),
            meanwhile: _draft.changedMeanwhile(e.id!, saved),
            enabled: enabled,
            hint: (mark) => _hint(e, mark, false),
            onMark: (mark) => _mark(e, mark),
          );
        },
      );
    }

    return PopScope(
      canPop: _draft.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: (_, event) => _onKey(event, employees, enabled),
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
                                DateFormat(
                                  'EEE, d MMMM yyyy',
                                  'ru',
                                ).format(day),
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
                  onSave: _saveAndReport,
                ),
          body: body,
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
        // На компьютере полоса не растягивается на всё окно.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
        ),
      ),
    );
  }
}

/// «Всем без отметки»: меню отметок, выбранная ставится всем, у кого
/// отметки нет. [onSelected] = null — некому ставить (или месяц закрыт).
class _FillUnmarkedButton extends StatelessWidget {
  final void Function(DayMark mark)? onSelected;

  const _FillUnmarkedButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final select = onSelected;
    return MenuAnchor(
      menuChildren: [
        for (final mark in DayMark.all)
          MenuItemButton(
            leadingIcon: Icon(Icons.circle, size: 14, color: mark.color),
            onPressed: select == null ? null : () => select(mark),
            child: Text(mark.label),
          ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        onPressed: select == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.playlist_add_check),
        label: const Text('Всем без отметки'),
      ),
    );
  }
}

/// Строка «было / уже изменено другим» под именем сотрудника.
List<Widget> _draftNotes(
  BuildContext context, {
  required bool changed,
  required String? before,
  required String? meanwhile,
}) => [
  if (changed)
    Text(
      'не сохранено · было: ${before ?? '—'}',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.primary,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  if (meanwhile != null)
    Text(
      'уже изменено другим: $meanwhile',
      style: TextStyle(
        fontSize: 12,
        color: StatusColors.of(context).warningText,
      ),
      overflow: TextOverflow.ellipsis,
    ),
];

/// Сотрудник на широком экране: ФИО и кнопки отметок в одну строку.
class _EmployeeDayRow extends StatelessWidget {
  final Employee employee;
  final TimesheetRecord? record;
  final bool changed;
  final DayMark? draftMark;
  final String? before;
  final String? meanwhile;

  /// Строка под клавишами.
  final bool current;
  final bool enabled;
  final String? Function(DayMark mark) hint;
  final void Function(DayMark? mark) onMark;

  const _EmployeeDayRow({
    required this.employee,
    required this.record,
    required this.changed,
    required this.draftMark,
    required this.before,
    required this.meanwhile,
    required this.current,
    required this.enabled,
    required this.hint,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final theme = Theme.of(context);
    bool selected(DayMark mark) =>
        changed ? draftMark == mark : r != null && mark.matches(r);
    final hasMark = changed ? draftMark != null : r != null;
    return Container(
      decoration: BoxDecoration(
        color: current
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : null,
        border: Border(
          left: BorderSide(
            width: 4,
            color: changed ? theme.colorScheme.primary : Colors.transparent,
          ),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                ..._draftNotes(
                  context,
                  changed: changed,
                  before: before,
                  meanwhile: meanwhile,
                ).take(1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final mark in DayMark.all) ...[
            DayMarkButton(
              mark: mark,
              selected: selected(mark),
              dense: true,
              tooltip: hint(mark),
              onPressed: enabled ? () => onMark(mark) : null,
            ),
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: 40,
            child: hasMark
                ? IconButton(
                    tooltip: 'Очистить отметку (Delete)',
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    onPressed: enabled ? () => onMark(null) : null,
                  )
                : null,
          ),
        ],
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
  final String? Function(DayMark mark) hint;
  final void Function(DayMark? mark) onMark;

  const _EmployeeDayCard({
    required this.employee,
    required this.record,
    required this.changed,
    required this.draftMark,
    required this.before,
    required this.meanwhile,
    required this.enabled,
    required this.hint,
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
                      ..._draftNotes(
                        context,
                        changed: changed,
                        before: before,
                        meanwhile: meanwhile,
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
                  DayMarkButton(
                    mark: mark,
                    selected: selected(mark),
                    tooltip: hint(mark),
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
