// lib/screens/daily_input_screen.dart
//
// Ввод табеля за день на телефоне (шаг 4.4): список работающих сотрудников,
// у каждого — крупные кнопки отметок. Одно касание — запись, без окон;
// удобно одной рукой. Сумм и ставок здесь нет.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/closed_month.dart';

/// Отметка дня: тип, доля дня и место работы.
class DayMark {
  final String label;
  final String dayType;
  final double days;
  final String? workPlace;
  final Color color;

  const DayMark(
    this.label,
    this.dayType,
    this.days,
    this.workPlace,
    this.color,
  );

  bool matches(TimesheetRecord r) =>
      r.dayType == dayType &&
      (dayType != 'work' || (r.days == days && r.workPlace == workPlace));

  static const all = [
    DayMark('База', 'work', 1, 'base', Color(0xFF2E7D32)),
    DayMark('Поле', 'work', 1, 'field', Color(0xFF558B2F)),
    DayMark('½ база', 'work', 0.5, 'base', Color(0xFF66BB6A)),
    DayMark('½ поле', 'work', 0.5, 'field', Color(0xFF9CCC65)),
    DayMark('Больничный', 'sick', 1, null, Color(0xFF1976D2)),
    DayMark('Отпуск', 'vacation', 1, null, Color(0xFF7B1FA2)),
    DayMark('Выходной', 'dayoff', 1, null, Color(0xFF757575)),
  ];
}

class DailyInputScreen extends StatefulWidget {
  final DateTime? initialDate;

  /// Отдельная страница (с кнопкой «назад»), а не раздел навигации.
  final bool standalone;

  const DailyInputScreen({
    super.key,
    this.initialDate,
    this.standalone = false,
  });

  @override
  State<DailyInputScreen> createState() => _DailyInputScreenState();
}

class _DailyInputScreenState extends State<DailyInputScreen> {
  late DateTime _date;
  Map<String, TimesheetRecord> _records = {};

  /// Сотрудник, чья отметка сейчас записывается.
  final Set<String> _saving = {};
  late final AppProvider _app;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now();
    _date = DateTime(d.year, d.month, d.day);
    _app = context.read<AppProvider>();
    // Синхронизация приняла данные — отметки дня могли измениться.
    _app.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _app.loadEmployees();
      await _refresh();
    });
  }

  @override
  void dispose() {
    _app.removeListener(_refresh);
    super.dispose();
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
      _records = {};
    });
    _refresh();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'День табеля',
    );
    if (picked != null) _setDate(picked);
  }

  Future<void> _mark(Employee e, DayMark? mark) async {
    if (!await ensureMonthOpen(context, _date.year, _date.month)) return;
    final id = e.id!;
    final existing = _records[id];
    if (mark != null && existing != null && mark.matches(existing)) return;
    setState(() => _saving.add(id));
    try {
      if (mark == null) {
        if (existing?.id != null) await _app.deleteTimesheetRecord(existing!.id!);
      } else {
        await _app.saveTimesheetRecord(
          TimesheetRecord(
            employeeId: id,
            date: _date,
            dayType: mark.dayType,
            days: mark.days,
            workPlace: mark.workPlace,
          ),
        );
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final day = _date;
    final employees = provider.employees
        .where(
          (e) =>
              !calendarDay(e.hireDate).isAfter(day) && e.isActiveOn(day),
        )
        .toList();
    final locked = provider.isMonthLocked(day.year, day.month);
    final marked = employees.where((e) => _records.containsKey(e.id)).length;
    final today = DateTime.now();
    final isToday =
        day == DateTime(today.year, today.month, today.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод за день'),
        centerTitle: false,
        automaticallyImplyLeading: widget.standalone,
        actions: [
          if (!isToday)
            TextButton(
              onPressed: () => _setDate(DateTime.now()),
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
                onPressed: () => _setDate(addCalendarDays(day, -1)),
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
                onPressed: () => _setDate(addCalendarDays(day, 1)),
              ),
            ],
          ),
        ),
      ),
      body: employees.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'В этот день нет работающих сотрудников.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.builder(
              // Отдельной страницей экран доходит до системных кнопок.
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: employees.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      locked
                          ? 'Месяц закрыт — отметки менять нельзя.'
                          : 'Отмечено $marked из ${employees.length}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                final e = employees[i - 1];
                return _EmployeeDayCard(
                  employee: e,
                  record: _records[e.id],
                  busy: _saving.contains(e.id),
                  enabled: !locked,
                  onMark: (mark) => _mark(e, mark),
                );
              },
            ),
    );
  }
}

class _EmployeeDayCard extends StatelessWidget {
  final Employee employee;
  final TimesheetRecord? record;
  final bool busy;
  final bool enabled;
  final void Function(DayMark? mark) onMark;

  const _EmployeeDayCard({
    required this.employee,
    required this.record,
    required this.busy,
    required this.enabled,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    employee.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (r != null)
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
                    selected: r != null && mark.matches(r),
                    onPressed: enabled && !busy ? () => onMark(mark) : null,
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
