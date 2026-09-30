// lib/screens/timesheet_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../widgets/closed_month.dart';
import '../widgets/month_switcher.dart';
import '../widgets/section_navigation.dart';
import '../widgets/timesheet_record_dialog.dart';
import '../widgets/common_widgets.dart';
import '../utils/string_utils.dart';
import '../widgets/daily_timesheet_dialog.dart';
import '../services/excel_export.dart';
import '../services/print_service.dart';
import '../widgets/excel_export_action.dart';
import '../theme/app_theme.dart';
import 'daily_input_screen.dart';
import 'reminder_screen.dart';
import '../services/platform.dart';
import '../services/reminder.dart';
import '../utils/day_draft.dart';
import '../widgets/adaptive_dialog.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  DateTime _selectedMonth = DateTime.now();
  SectionNavigator? _sections;

  /// Несохранённые отметки ввода за день (6.10) — остались после закрытия
  /// программы системой.
  DayDraft? _pendingDraft;

  @override
  void initState() {
    super.initState();
    _sections = context.read<SectionNavigator?>()?..addListener(_openRequested);
    _checkPendingDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadEmployees(activeOnly: true);
      _loadTimesheet();
    });
  }

  @override
  void dispose() {
    _sections?.removeListener(_openRequested);
    super.dispose();
  }

  /// Сводка открыла табель на нужном месяце.
  void _openRequested() {
    final month = _sections!.takeMonth(AppSection.timesheet);
    if (month == null || !mounted) return;
    setState(() => _selectedMonth = month);
    _loadTimesheet();
  }

  void _loadTimesheet() {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    context.read<AppProvider>().loadTimesheet(start, end);
  }

  void _goToToday() {
    setState(() {
      _selectedMonth = DateTime.now();
    });
    _loadTimesheet();
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите месяц и год',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadTimesheet();
    }
  }

  Future<void> _checkPendingDraft() async {
    final draft = await DayDraftStore.load();
    if (mounted) setState(() => _pendingDraft = draft);
  }

  void _showDailyInputDialog(BuildContext context) {
    // Телефон — отдельный экран с крупными кнопками, Windows — окно.
    if (MediaQuery.sizeOf(context).width < AppTheme.compactWidth ||
        _pendingDraft != null) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => const DailyInputScreen(standalone: true),
            ),
          )
          .then((_) {
            _loadTimesheet();
            _checkPendingDraft();
          });
      return;
    }
    showDialog(
      context: context,
      builder: (context) => DailyTimesheetDialog(
        initialDate: DateTime.now(),
        onSaved: _loadTimesheet,
      ),
    );
  }

  Future<void> _printTimesheet() async {
    final provider = context.read<AppProvider>();
    if (provider.employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет сотрудников для печати')),
      );
      return;
    }
    if (provider.companySettings == null) {
      await provider.loadCompanySettings();
    }
    try {
      await PrintService.printTimesheet(
        month: _selectedMonth,
        employees: provider.employees,
        records: provider.timesheetRecords,
        companySettings: provider.companySettings,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка печати: $e')));
    }
  }

  /// «Отметить выходные» (6.6): «В» во все пустые клетки нерабочих по
  /// производственному календарю дней — после подтверждения.
  Future<void> _fillDaysOff() async {
    final month = _selectedMonth;
    if (!await ensureMonthOpen(context, month.year, month.month) || !mounted) {
      return;
    }
    final provider = context.read<AppProvider>();
    final empty = await provider.emptyDaysOff(month.year, month.month);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (empty.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Все нерабочие дни месяца уже заполнены')),
      );
      return;
    }
    final people = {for (final (e, _) in empty) e.id}.length;
    final days = ProductionCalendar.daysOff(month.year, month.month);
    final monthName = DateFormat('LLLL yyyy', 'ru').format(month);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const Icon(Icons.event_busy),
        title: Text('Отметить выходные — $monthName?'),
        content: SizedBox(
          width: 440,
          child: Text(
            'Нерабочие дни по производственному календарю: '
            '${_dayRanges(days)}.\n\n'
            '«В» будет поставлено в ${empty.length} пустых клеток у '
            '$people сотр. (только в дни, когда сотрудник работает в '
            'хозяйстве). Заполненные клетки не меняются.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Отметить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final added = await provider.fillDaysOff(month.year, month.month);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Отмечено выходных: $added')),
    );
  }

  /// «1–11, 17, 18, 24, 25» — подряд идущие числа одним отрезком.
  static String _dayRanges(List<int> days) {
    final parts = <String>[];
    var i = 0;
    while (i < days.length) {
      var j = i;
      while (j + 1 < days.length && days[j + 1] == days[j] + 1) {
        j++;
      }
      parts.add(
        j - i >= 2
            ? '${days[i]}–${days[j]}'
            : days.sublist(i, j + 1).join(', '),
      );
      i = j + 1;
    }
    return parts.join(', ');
  }

  Future<void> _exportTimesheet() async {
    final provider = context.read<AppProvider>();
    if (provider.companySettings == null) {
      await provider.loadCompanySettings();
    }
    if (!mounted) return;
    final month = _selectedMonth;
    await exportToExcel(
      context,
      fileName: excelFileName('Табель', month),
      build: () async => timesheetWorkbook(
        month: month,
        employees: provider.employees,
        records: provider.timesheetRecords,
        companySettings: provider.companySettings,
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadTimesheet();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final compact = MediaQuery.sizeOf(context).width < AppTheme.compactWidth;
    final operator = context.read<AppProvider>().operatorMode;

    return Scaffold(
      // Месяц — в строке заголовка, как в отчётах (на телефоне — вместо
      // заголовка).
      appBar: monthAppBar(
        context,
        title: 'Табель учёта времени',
        switcher: MonthSwitcher(
          month: _selectedMonth,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onPick: _selectMonth,
          onToday: _goToToday,
        ),
        menu: [
          AppBarMenuItem(Icons.event_busy, 'Отметить выходные', _fillDaysOff),
          if (isAndroidApp && Reminders.instance.available)
            AppBarMenuItem(
              Icons.alarm,
              'Напоминание о табеле',
              () => showReminderSettings(context),
            ),
          if (!operator) ...[
            AppBarMenuItem(Icons.print, 'Печать табеля', _printTimesheet),
            AppBarMenuItem(
              Icons.table_view,
              'Выгрузить в Excel',
              _exportTimesheet,
            ),
          ],
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () => _showDailyInputDialog(context),
            tooltip: 'Ввод за день',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.employees.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  operator
                      ? 'Сотрудников нет. Они придут с сервера после '
                            'входа (раздел «Сервер»).'
                      : 'Нет сотрудников.\nДобавьте сотрудников в '
                            'разделе "Сотрудники".',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final pending = _pendingDraft;
          return Column(
            children: [
              if (pending != null)
                MaterialBanner(
                  leading: const Icon(Icons.edit_note),
                  content: Text(
                    'Есть несохранённые отметки за '
                    '${DateFormat('d MMMM', 'ru').format(pending.date)} '
                    '(${pending.length})',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await DayDraftStore.clear();
                        _checkPendingDraft();
                      },
                      child: const Text('Отбросить'),
                    ),
                    TextButton(
                      onPressed: () => _showDailyInputDialog(context),
                      child: const Text('Продолжить'),
                    ),
                  ],
                ),
              Expanded(
                child: _TimesheetGrid(
                  employees: provider.employees,
                  records: provider.timesheetRecords,
                  selectedMonth: _selectedMonth,
                  daysInMonth: daysInMonth,
                  compact: compact,
                  onCellTap: (employee, day) async {
                    final month = _selectedMonth;
                    if (!await ensureMonthOpen(
                          context,
                          month.year,
                          month.month,
                        ) ||
                        !context.mounted) {
                      return;
                    }
                    _showRecordDialog(
                      context,
                      employee,
                      DateTime(month.year, month.month, day),
                    );
                  },
                ),
              ),
              _buildLegend(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    final c = TimesheetColors.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _legendItem('1 / 0.5', c.work, c),
          _legendItem('Б', c.sick, c),
          _legendItem('О', c.vacation, c),
          _legendItem('В', c.dayoff, c),
          _monthNorm(c),
        ],
      ),
    );
  }

  /// Норма месяца по производственному календарю РФ.
  Widget _monthNorm(TimesheetColors c) {
    final norm = ProductionCalendar.monthNorm(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    return Text(
      'Норма: ${norm.workdays} раб. дн.'
      '${norm.shortDays > 0 ? ', из них ${norm.shortDays} сокращ. (*)' : ''}',
      style: TextStyle(fontSize: 12, color: c.mutedText),
    );
  }

  Widget _legendItem(String label, Color color, TimesheetColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label == '1 / 0.5'
              ? '— Работа (база/поле)'
              : label == 'Б'
              ? '— Больничный'
              : label == 'О'
              ? '— Отпуск'
              : '— Выходной',
          style: TextStyle(fontSize: 12, color: c.mutedText),
        ),
      ],
    );
  }

  void _showRecordDialog(
    BuildContext context,
    Employee employee,
    DateTime date,
  ) {
    final provider = context.read<AppProvider>();
    final existingRecord = provider.timesheetRecords.firstWhere(
      (r) =>
          r.employeeId == employee.id &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
      orElse: () => TimesheetRecord(
        employeeId: employee.id!,
        date: date,
        dayType: 'work',
        days: 0,
      ),
    );

    showAppDialog<void>(
      context: context,
      builder: (context) => TimesheetRecordDialog(
        employee: employee,
        record: existingRecord.id != null ? existingRecord : null,
        defaultDate: date,
      ),
    );
  }
}

class _TimesheetGrid extends StatefulWidget {
  final List<Employee> employees;
  final List<TimesheetRecord> records;
  final DateTime selectedMonth;
  final int daysInMonth;

  /// Телефон: столбец ФИО уже, ячейки крупнее под палец.
  final bool compact;
  final void Function(Employee, int) onCellTap;

  const _TimesheetGrid({
    required this.employees,
    required this.records,
    required this.selectedMonth,
    required this.daysInMonth,
    required this.compact,
    required this.onCellTap,
  });

  @override
  State<_TimesheetGrid> createState() => _TimesheetGridState();
}

/// Сетка табеля (UI_REQUIREMENTS п. 1.1, 4.1): шапка дней и столбец ФИО
/// закреплены; дни прокручиваются по горизонтали вместе с шапкой, строки —
/// по вертикали вместе с ФИО.
class _TimesheetGridState extends State<_TimesheetGrid> {
  final _namesVertical = ScrollController();
  final _cellsVertical = ScrollController();
  final _headerHorizontal = ScrollController();
  final _cellsHorizontal = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _link(_namesVertical, _cellsVertical);
    _link(_cellsVertical, _namesVertical);
    _cellsHorizontal.addListener(() {
      if (_headerHorizontal.hasClients) {
        _headerHorizontal.jumpTo(_cellsHorizontal.offset);
      }
    });
  }

  /// Прокрутка [from] повторяется в [to].
  void _link(ScrollController from, ScrollController to) {
    from.addListener(() {
      if (_syncing || !to.hasClients) return;
      _syncing = true;
      to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
      _syncing = false;
    });
  }

  @override
  void dispose() {
    _namesVertical.dispose();
    _cellsVertical.dispose();
    _headerHorizontal.dispose();
    _cellsHorizontal.dispose();
    super.dispose();
  }

  late TimesheetColors _c;
  BorderSide get _border => BorderSide(color: _c.border);

  @override
  Widget build(BuildContext context) {
    _c = TimesheetColors.of(context);
    final nameWidth = widget.compact ? 116.0 : 160.0;
    final dayWidth = widget.compact ? 44.0 : 40.0;
    final cellHeight = widget.compact ? 48.0 : 40.0;
    const totals = 4;
    final cellsWidth = (widget.daysInMonth + totals) * dayWidth;

    // Записи месяца: сотрудник → день.
    final byDay = <String, Map<int, TimesheetRecord>>{};
    for (final r in widget.records) {
      (byDay[r.employeeId] ??= {})[r.date.day] = r;
    }

    final now = DateTime.now();
    final header = Row(
      children: [
        for (var day = 1; day <= widget.daysInMonth; day++)
          _dayHeader(
            DateTime(
              widget.selectedMonth.year,
              widget.selectedMonth.month,
              day,
            ),
            now,
            dayWidth,
            cellHeight,
          ),
        _totalHeader('Раб.', _c.total, dayWidth, cellHeight),
        _totalHeader('Вых.', _c.totalAlt, dayWidth, cellHeight),
        _totalHeader('Бол.', _c.sick, dayWidth, cellHeight),
        _totalHeader('Отп.', _c.vacation, dayWidth, cellHeight),
      ],
    );

    Widget row(Employee employee) {
      final records = byDay[employee.id] ?? const {};
      var work = 0.0, sick = 0.0, vacation = 0.0, dayoff = 0.0;
      for (final r in records.values) {
        switch (r.dayType) {
          case 'work':
            work += r.days;
          case 'sick':
            sick += r.days;
          case 'vacation':
            vacation += r.days;
          case 'dayoff':
            dayoff += r.days;
        }
      }
      return Container(
        height: cellHeight,
        decoration: BoxDecoration(border: Border(bottom: _border)),
        child: Row(
          children: [
            for (var day = 1; day <= widget.daysInMonth; day++)
              _TimesheetCell(
                key: ValueKey('timesheet-cell-${employee.id}-$day'),
                record:
                    records[day] ??
                    TimesheetRecord(
                      employeeId: employee.id!,
                      date: DateTime(
                        widget.selectedMonth.year,
                        widget.selectedMonth.month,
                        day,
                      ),
                      dayType: 'work',
                      days: 0,
                    ),
                dayWidth: dayWidth,
                cellHeight: cellHeight,
                onTap: () => widget.onCellTap(employee, day),
              ),
            _totalCell(work, _c.total, dayWidth, cellHeight, true),
            _totalCell(dayoff, _c.totalAlt, dayWidth, cellHeight, false),
            _totalCell(sick, _c.sick, dayWidth, cellHeight, false),
            _totalCell(vacation, _c.vacation, dayWidth, cellHeight, false),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Закреплённая шапка.
        Row(
          children: [
            Container(
              width: nameWidth,
              height: cellHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(border: Border(bottom: _border)),
              child: const Text(
                'ФИО',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHorizontal,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(width: cellsWidth, child: header),
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Закреплённый столбец ФИО.
              SizedBox(
                width: nameWidth,
                child: ListView.builder(
                  controller: _namesVertical,
                  itemCount: widget.employees.length,
                  itemExtent: cellHeight,
                  itemBuilder: (context, index) =>
                      _nameCell(widget.employees[index]),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _cellsHorizontal,
                  thumbVisibility: !widget.compact,
                  child: SingleChildScrollView(
                    controller: _cellsHorizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: cellsWidth,
                      child: ListView.builder(
                        controller: _cellsVertical,
                        itemCount: widget.employees.length,
                        itemExtent: cellHeight,
                        itemBuilder: (context, index) =>
                            row(widget.employees[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nameCell(Employee employee) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(border: Border(bottom: _border)),
    child: Tooltip(
      message: employee.fullName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            StringUtils.getShortName(employee.fullName),
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            employee.position,
            style: TextStyle(fontSize: 10, color: _c.mutedText),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  Widget _dayHeader(DateTime date, DateTime now, double width, double height) {
    // Нерабочий день — по производственному календарю РФ (праздники,
    // переносы; рабочая суббота — обычный день).
    final isWeekend = !ProductionCalendar.isWorkingDay(date);
    final isShort =
        ProductionCalendar.kindOf(date) == CalendarDayKind.shortWorkday;
    final note = ProductionCalendar.note(date);
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final header = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isToday
            ? _c.today
            : isWeekend
            ? _c.weekend
            : null,
        border: Border(left: _border, bottom: _border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: isWeekend ? _c.weekendText : _c.text,
            ),
          ),
          Text(
            // Сокращённый предпраздничный день — со звёздочкой.
            '${_getWeekdayShort(date.weekday)}${isShort ? '*' : ''}',
            style: TextStyle(
              fontSize: 9,
              color: isWeekend ? _c.weekendText : _c.mutedText,
            ),
          ),
        ],
      ),
    );
    return note == null ? header : Tooltip(message: note, child: header);
  }

  Widget _totalHeader(String text, Color color, double width, double height) =>
      Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: Border(left: _border, bottom: _border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: _c.text,
          ),
          textAlign: TextAlign.center,
        ),
      );

  Widget _totalCell(
    double value,
    Color color,
    double width,
    double height,
    bool bold,
  ) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      border: Border(left: _border),
    ),
    child: Text(
      value.toStringAsFixed(1),
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: 10,
        color: _c.text,
      ),
    ),
  );

  String _getWeekdayShort(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }
}

/// Ячейка табеля с отображением места работы для рабочих дней
class _TimesheetCell extends StatelessWidget {
  final TimesheetRecord record;
  final double dayWidth;
  final double cellHeight;

  /// Одно касание открывает правку дня (двойное заменено везде, этап 4).
  final VoidCallback onTap;

  const _TimesheetCell({
    super.key,
    required this.record,
    required this.dayWidth,
    required this.cellHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = record.id != null;

    String displayText = '';
    final c = TimesheetColors.of(context);
    Color backgroundColor = Colors.transparent;
    final textColor = c.text;

    if (hasRecord) {
      if (record.dayType == 'work') {
        if (record.days > 0) {
          // Формируем текст: дни + место работы
          String daysStr = record.days == 0.5 ? '0.5' : '1';
          String placeStr = '';
          if (record.workPlace == 'base') {
            placeStr = '\nбаза';
          } else if (record.workPlace == 'field') {
            placeStr = '\nполе';
          }
          displayText = daysStr + placeStr;
          backgroundColor = c.work;
        }
      } else if (record.dayType == 'sick') {
        displayText = 'Б';
        backgroundColor = c.sick;
      } else if (record.dayType == 'vacation') {
        displayText = 'О';
        backgroundColor = c.vacation;
      } else if (record.dayType == 'dayoff') {
        displayText = 'В';
        backgroundColor = c.dayoff;
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        width: dayWidth,
        height: cellHeight,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(left: BorderSide(color: c.border)),
        ),
        alignment: Alignment.center,
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
