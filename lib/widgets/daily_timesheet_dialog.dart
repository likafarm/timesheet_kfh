// lib/widgets/daily_timesheet_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../utils/day_draft.dart';
import '../utils/string_utils.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

/// Строка окна: тип дня, доля дня, место работы.
typedef _RowState = (String, double, String?);

/// Несохранённое изменение дня в групповом вводе: что было в базе и какую
/// запись даёт строка окна сейчас.
class DayChange {
  final Employee employee;

  /// Подпись записи в базе при открытии дня («—» — записи не было).
  final String before;

  /// Запись, которая будет сохранена.
  final TimesheetRecord record;

  const DayChange({
    required this.employee,
    required this.before,
    required this.record,
  });

  /// Почему запись нельзя сохранить (рабочий день без места); null — можно.
  String? get problem => timesheetRecordProblem(record);

  /// Подпись новой отметки.
  String get after => problem == null
      ? DayMark.describe(record)
      : '${DayMark.describe(record)}, место не указано';
}

/// Окно «Сохранить изменения за …?» группового ввода: у кого что было и что
/// станет. Закрыли окно мимо кнопок — [DraftDecision.stay].
Future<DraftDecision> confirmDayChanges(
  BuildContext context, {
  required DateTime date,
  required List<DayChange> changes,
}) async {
  final theme = Theme.of(context);
  final status = StatusColors.of(context);
  final decision = await showDialog<DraftDecision>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Сохранить изменения за ${DateFormat('dd.MM.yyyy').format(date)}?',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
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
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${StringUtils.getShortName(c.employee.fullName)}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: '${c.before} → '),
                        TextSpan(
                          text: c.after,
                          style: TextStyle(
                            color: c.problem == null
                                ? DayMark.of(c.record)?.color
                                : status.warningText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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

class DailyTimesheetDialog extends StatefulWidget {
  final DateTime initialDate;
  final VoidCallback onSaved;

  const DailyTimesheetDialog({
    super.key,
    required this.initialDate,
    required this.onSaved,
  });

  @override
  State<DailyTimesheetDialog> createState() => _DailyTimesheetDialogState();
}

class _DailyTimesheetDialogState extends State<DailyTimesheetDialog> {
  late DateTime _selectedDate;
  List<Employee> _employees = [];

  late final Map<String, bool> _selected;
  late final Map<String, String> _dayTypes;
  late final Map<String, double> _dayCounts;
  late final Map<String, String?> _workPlaces;
  final Map<String, EmployeeRate?> _ratesAtDate = {};
  final Map<String, String> _workPlaceErrors = {};

  /// Записи дня в базе на момент его открытия: сотрудник → запись.
  final Map<String, TimesheetRecord> _existing = {};

  /// Строки окна сразу после открытия дня.
  final Map<String, _RowState> _baseline = {};

  bool _isLoading = false;
  bool _allSelected = false;
  bool _isSaving = false;

  final List<String> _dayTypeOptions = ['work', 'sick', 'vacation', 'dayoff'];
  final List<String> _dayTypeLabels = [
    'Работа',
    'Больничный',
    'Отпуск',
    'Выходной',
  ];
  final List<double> _dayCountOptions = [0.5, 1.0];
  final List<String> _workPlaceOptions = ['base', 'field'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selected = {};
    _dayTypes = {};
    _dayCounts = {};
    _workPlaces = {};
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      await provider.loadEmployees(activeOnly: true);
      if (!mounted) return;
      _employees = provider.employees;
      await _loadDay();
      await _loadRatesAtDate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Строки окна на выбранный день: у всех «работа, целый день, место не
  /// выбрано», поверх — записи дня из базы. Это состояние запоминается как
  /// исходное ([_baseline]): отметки по умолчанию изменением не считаются.
  Future<void> _loadDay() async {
    final provider = context.read<AppProvider>();
    final records = await provider.getTimesheetForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _existing
        ..clear()
        ..addAll({for (final r in records) r.employeeId: r});
      for (final emp in _employees) {
        final id = emp.id;
        if (id == null) continue;
        final record = _existing[id];
        _selected[id] = true;
        _dayTypes[id] = record?.dayType ?? 'work';
        _dayCounts[id] =
            record != null &&
                record.dayType == 'work' &&
                _dayCountOptions.contains(record.days)
            ? record.days
            : 1.0;
        _workPlaces[id] = record?.workPlace;
      }
      _allSelected = true;
      _workPlaceErrors.clear();
      _baseline
        ..clear()
        ..addAll({for (final id in _selected.keys) id: _rowState(id)});
    });
  }

  _RowState _rowState(String id) =>
      (_dayTypes[id]!, _dayCounts[id]!, _workPlaces[id]);

  /// Запись табеля, которую даёт строка окна сейчас.
  TimesheetRecord _rowRecord(String id) {
    final dayType = _dayTypes[id]!;
    return TimesheetRecord(
      employeeId: id,
      date: _selectedDate,
      dayType: dayType,
      days: dayType == 'work' ? _dayCounts[id]! : 1.0,
      workPlace: dayType == 'work' ? _workPlaces[id] : null,
    );
  }

  /// Несохранённые изменения дня: отмеченные строки, которые человек
  /// поменял после открытия дня. Снятая галочка — не изменение: такая
  /// строка в базу не пишется.
  List<DayChange> _changes() => [
    for (final emp in _employees)
      if (emp.id case final id?
          when _selected[id] == true && _rowState(id) != _baseline[id])
        DayChange(
          employee: emp,
          before: DayMark.describe(_existing[id]),
          record: _rowRecord(id),
        ),
  ];

  /// Спросить о несохранённых изменениях и выполнить ответ. true — можно
  /// уходить с дня (сохранено или решено не сохранять), false — остаёмся.
  Future<bool> _resolveChanges() async {
    final changes = _changes();
    if (changes.isEmpty) return true;
    final decision = await confirmDayChanges(
      context,
      date: _selectedDate,
      changes: changes,
    );
    if (!mounted) return false;
    switch (decision) {
      case DraftDecision.stay:
        return false;
      case DraftDecision.discard:
        return true;
      case DraftDecision.save:
        final invalid = [
          for (final c in changes)
            if (c.problem != null) c.employee.id!,
        ];
        if (invalid.isNotEmpty) {
          setState(() {
            _workPlaceErrors
              ..clear()
              ..addAll({for (final id in invalid) id: 'Укажите место'});
          });
          await _showWorkPlaceError();
          return false;
        }
        setState(() => _isSaving = true);
        final saved = await context.read<AppProvider>().saveDayMarks(
          _selectedDate,
          {for (final c in changes) c.employee.id!: c.record},
        );
        if (!mounted) return false;
        setState(() => _isSaving = false);
        if (saved) {
          widget.onSaved();
        } else {
          await _showNotSaved();
        }
        return saved;
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted || date == _selectedDate) return;
    if (!await _resolveChanges() || !mounted) return;
    setState(() => _selectedDate = date);
    await _loadDay();
    await _loadRatesAtDate();
  }

  /// Закрыть окно крестиком, Esc или щелчком мимо.
  Future<void> _close() async {
    if (_isSaving) return;
    if (!await _resolveChanges() || !mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showNotSaved() {
    final locked = context.read<AppProvider>().isMonthLocked(
      _selectedDate.year,
      _selectedDate.month,
    );
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Не сохранено'),
        content: Text(
          locked
              ? PeriodLockedException(
                  _selectedDate.year,
                  _selectedDate.month,
                ).message
              : 'Не удалось сохранить отметки. Попробуйте ещё раз.',
        ),
        actions: [
          AppButton(
            label: 'OK',
            isText: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkPlaceError() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ошибка'),
      content: const Text(
        'Для сотрудников с рабочим днём необходимо указать место работы. Ошибочные строки выделены.',
      ),
      actions: [
        AppButton(
          label: 'OK',
          isText: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Future<void> _loadRatesAtDate() async {
    final provider = context.read<AppProvider>();
    final next = <String, EmployeeRate?>{};
    for (final emp in _employees) {
      final id = emp.id;
      if (id == null) continue;
      next[id] = await provider.getEmployeeRateAtDate(id, _selectedDate);
    }
    if (!mounted) return;
    setState(() {
      _ratesAtDate
        ..clear()
        ..addAll(next);
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _allSelected = value ?? false;
      for (var key in _selected.keys) {
        _selected[key] = _allSelected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // С несохранёнными изменениями окно не закрывается молча: Esc, щелчок
    // мимо и крестик идут через вопрос о сохранении.
    return PopScope(
      canPop: !_isSaving && _changes().isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_calendar),
          const SizedBox(width: 8),
          const Expanded(child: Text('Быстрый ввод за день')),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Закрыть',
            onPressed: _close,
          ),
        ],
      ),
      content: SizedBox(
        width: 780,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Дата'),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy').format(_selectedDate),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(),
                  Expanded(
                    child: _employees.isEmpty
                        ? const Center(child: Text('Нет активных сотрудников'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 640,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      color: Colors.grey[200],
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _allSelected,
                                            onChanged: _toggleSelectAll,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 20),
                                          const SizedBox(
                                            width: 30,
                                            child: Text(
                                              '№',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 150,
                                            child: Text(
                                              'ФИО',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 110,
                                            child: Text(
                                              'Тип дня',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 70,
                                            child: Text(
                                              'Дней',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 180,
                                            child: Text(
                                              'Место / ставка',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ..._employees.asMap().entries.map((entry) {
                                      final index = entry.key + 1;
                                      final employee = entry.value;
                                      final id = employee.id!;
                                      final isSelected = _selected[id] ?? false;
                                      final dayType = _dayTypes[id]!;
                                      final dayCount = _dayCounts[id]!;
                                      final workPlace = _workPlaces[id];
                                      final hasError = _workPlaceErrors
                                          .containsKey(id);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                            ),
                                          ),
                                          color: hasError
                                              ? StatusColors.of(
                                                  context,
                                                ).errorBackground
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selected[id] =
                                                      value ?? false;
                                                  _allSelected = _selected
                                                      .values
                                                      .every((v) => v);
                                                  if (value == true) {
                                                    _workPlaceErrors.remove(id);
                                                  }
                                                });
                                              },
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            const SizedBox(width: 20),
                                            SizedBox(
                                              width: 30,
                                              child: Text(
                                                '$index',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                StringUtils.getShortName(
                                                  employee.fullName,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Тип дня
                                            SizedBox(
                                              width: 110,
                                              child: DropdownButton<String>(
                                                key: ValueKey('type-$id'),
                                                value: dayType,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                items: _dayTypeOptions.map((e) {
                                                  final idx = _dayTypeOptions
                                                      .indexOf(e);
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: e,
                                                    child: Text(
                                                      _dayTypeLabels[idx],
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: isSelected
                                                    ? (value) {
                                                        setState(() {
                                                          _dayTypes[id] =
                                                              value!;
                                                          _workPlaceErrors
                                                              .remove(id);
                                                          if (value == 'work') {
                                                            if (!_dayCountOptions
                                                                .contains(
                                                                  _dayCounts[id],
                                                                )) {
                                                              _dayCounts[id] =
                                                                  1.0;
                                                            }
                                                          } else {
                                                            _dayCounts[id] =
                                                                1.0;
                                                            _workPlaces[id] =
                                                                null;
                                                          }
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Дней
                                            SizedBox(
                                              width: 70,
                                              child: dayType == 'work'
                                                  ? DropdownButton<double>(
                                                      key: ValueKey('days-$id'),
                                                      value: dayCount,
                                                      isExpanded: true,
                                                      underline:
                                                          const SizedBox(),
                                                      items: _dayCountOptions.map((
                                                        d,
                                                      ) {
                                                        return DropdownMenuItem<
                                                          double
                                                        >(
                                                          value: d,
                                                          child: Text(
                                                            d == 0.5
                                                                ? '0.5'
                                                                : '1',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: isSelected
                                                          ? (value) {
                                                              setState(() {
                                                                _dayCounts[id] =
                                                                    value!;
                                                              });
                                                            }
                                                          : null,
                                                    )
                                                  : const Text(
                                                      '1',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Место
                                            SizedBox(
                                              width: 180,
                                              child: dayType == 'work'
                                                  ? DropdownButton<String?>(
                                                      key: ValueKey(
                                                        'place-$id',
                                                      ),
                                                      value: workPlace,
                                                      isExpanded: true,
                                                      underline:
                                                          const SizedBox(),
                                                      hint: const Text(
                                                        '—',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      items: [
                                                        const DropdownMenuItem<
                                                          String?
                                                        >(
                                                          value: null,
                                                          child: Text(
                                                            '—',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        ..._workPlaceOptions.map((
                                                          e,
                                                        ) {
                                                          final rate =
                                                              _ratesAtDate[id];
                                                          return DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: e,
                                                            child: Text(
                                                              StringUtils.workPlaceLabel(
                                                                e,
                                                                withRates: !context
                                                                    .read<
                                                                      AppProvider
                                                                    >()
                                                                    .operatorMode,
                                                                baseRate:
                                                                    rate?.baseRate ??
                                                                    employee
                                                                        .baseRate,
                                                                fieldRate:
                                                                    rate?.fieldRate ??
                                                                    employee
                                                                        .fieldRate,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                      onChanged: isSelected
                                                          ? (value) {
                                                              setState(() {
                                                                _workPlaces[id] =
                                                                    value;
                                                                if (value !=
                                                                    null) {
                                                                  _workPlaceErrors
                                                                      .remove(
                                                                        id,
                                                                      );
                                                                }
                                                              });
                                                            }
                                                          : null,
                                                    )
                                                  : const Text(
                                                      '—',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        AppButton(
          label: 'Отмена',
          isText: true,
          width: 100,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: _isSaving ? 'Сохранение...' : 'Сохранить',
          width: 100,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _workPlaceErrors.clear();
    });

    final provider = context.read<AppProvider>();
    final existingRecords = await provider.getTimesheetForDate(_selectedDate);

    List<Map<String, dynamic>> newEntries = [];
    List<Employee> selectedEmployees = [];
    bool hasError = false;

    for (var emp in _employees) {
      final id = emp.id!;
      if (_selected[id] == true) {
        final dayType = _dayTypes[id]!;
        final days = _dayCounts[id]!;
        final workPlace = _workPlaces[id];

        if (timesheetMarkProblem(
              dayType: dayType,
              days: days,
              workPlace: workPlace,
            ) !=
            null) {
          hasError = true;
          setState(() {
            _workPlaceErrors[id] = 'Укажите место';
          });
          continue;
        }

        double finalDays = (dayType == 'work') ? days : 1.0;

        TimesheetRecord? existing;
        for (var r in existingRecords) {
          if (r.employeeId == id) {
            existing = r;
            break;
          }
        }

        newEntries.add({
          'employee': emp,
          'dayType': dayType,
          'days': finalDays,
          'workPlace': (dayType == 'work') ? workPlace : null,
          'existing': existing,
        });
        selectedEmployees.add(emp);
      }
    }

    if (hasError) {
      if (!mounted) return;
      await _showWorkPlaceError();
      return;
    }

    if (selectedEmployees.isEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Выберите хотя бы одного сотрудника.'),
          actions: [
            AppButton(
              label: 'OK',
              isText: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final conflicts = newEntries.where((e) => e['existing'] != null).toList();
    if (conflicts.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('У следующих сотрудников уже есть записи за этот день:');
      for (var c in conflicts) {
        final emp = c['employee'] as Employee;
        final existing = c['existing'] as TimesheetRecord;
        buffer.writeln('• ${emp.fullName}:');
        buffer.writeln('  Тип: ${_getDayTypeName(existing.dayType)}');
        if (existing.dayType == 'work') {
          buffer.writeln('  Дней: ${existing.days.toStringAsFixed(1)}');
          buffer.writeln(
            '  Место: ${existing.workPlace == 'base'
                ? 'База'
                : existing.workPlace == 'field'
                ? 'Поле'
                : '—'}',
          );
        }
        if (existing.notes != null && existing.notes!.isNotEmpty) {
          buffer.writeln('  Примечания: ${existing.notes}');
        }
      }
      buffer.writeln('\nПерезаписать существующие записи?');

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Внимание!'),
          content: SingleChildScrollView(child: Text(buffer.toString())),
          actions: [
            AppButton(
              label: 'Отмена',
              isText: true,
              onPressed: () => Navigator.pop(context, false),
            ),
            AppButton(
              label: 'Перезаписать',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    List<TimesheetRecord> recordsToSave = [];
    for (var entry in newEntries) {
      final emp = entry['employee'] as Employee;
      final dayType = entry['dayType'] as String;
      final days = entry['days'] as double;
      final workPlace = entry['workPlace'] as String?;
      recordsToSave.add(
        TimesheetRecord(
          employeeId: emp.id!,
          date: _selectedDate,
          dayType: dayType,
          days: days,
          workPlace: workPlace,
        ),
      );
    }

    setState(() => _isSaving = true);
    try {
      await provider.saveDailyTimesheet(recordsToSave, _selectedDate);
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        setState(() => _isSaving = false);
        return;
      }
      setState(() => _isSaving = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка сохранения'),
          content: Text('Не удалось сохранить записи:\n$e'),
          actions: [
            AppButton(
              label: 'OK',
              isText: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  String _getDayTypeName(String type) {
    switch (type) {
      case 'work':
        return 'Работа';
      case 'sick':
        return 'Больничный';
      case 'vacation':
        return 'Отпуск';
      case 'dayoff':
        return 'Выходной';
      default:
        return type;
    }
  }
}
