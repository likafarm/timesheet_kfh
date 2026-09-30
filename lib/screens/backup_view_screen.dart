// lib/screens/backup_view_screen.dart
//
// Открытая копия (модуль «Резервные копии», 3.6): что в ней лежит —
// человеческим языком. Сотрудники, табель сеткой по месяцу, выплаты,
// ставки, расчёты ЗП и реквизиты — как они были на момент копии.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../theme/app_theme.dart';
import '../utils/audit_format.dart';
import '../utils/day_draft.dart';

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

final _moment = DateFormat('dd.MM.yyyy HH:mm');
final _rub = NumberFormat('#,##0.00', 'ru');
final _num = NumberFormat('#,##0.##', 'ru');

String _monthTitle((int, int) m) {
  final text = DateFormat('LLLL yyyy', 'ru').format(DateTime(m.$1, m.$2));
  return text[0].toUpperCase() + text.substring(1);
}

/// Отметка дня в клетке — как в табеле программы: рабочий день — доля и
/// место в две строки («1 / поле», «0.5 / база»), Б — больничный,
/// О — отпуск, В — выходной.
String timesheetCellCode(Map<String, Object?> d) {
  final days = (d['days'] as num?)?.toDouble() ?? 1;
  final place = switch (d['work_place']) {
    'base' => 'база',
    'field' => 'поле',
    _ => '—',
  };
  return switch (d['day_type']) {
    'work' => '${days == 0.5 ? '0.5' : '1'}\n$place',
    'sick' => 'Б',
    'vacation' => 'О',
    'dayoff' => 'В',
    _ => '?',
  };
}

class BackupViewScreen extends StatefulWidget {
  final String title;
  final DateTime takenAt;
  final BackupSource source;
  final DataSnapshot snapshot;

  /// Кнопка «Что изменилось с тех пор» (3.7); null — без неё.
  final VoidCallback? onCompare;

  /// Почему копию нельзя сравнить и вернуть по записям (показывается в
  /// обзоре); null — можно.
  final String? compareUnavailable;

  const BackupViewScreen({
    super.key,
    required this.title,
    required this.takenAt,
    required this.source,
    required this.snapshot,
    this.onCompare,
    this.compareUnavailable,
  });

  @override
  State<BackupViewScreen> createState() => _BackupViewScreenState();
}

class _BackupViewScreenState extends State<BackupViewScreen> {
  late final Map<String, String> _names;
  late final List<(int, int)> _months;
  (int, int)? _month;

  DataSnapshot get _s => widget.snapshot;

  @override
  void initState() {
    super.initState();
    _names = {
      for (final e in _s.rows('employees'))
        e.uuid: e.data['full_name'] as String? ?? '—',
    };
    final keys = <int>{
      for (final r in _s.liveRows('timesheet')) _key(r.data['date']),
      for (final r in _s.liveRows('payments')) _key(r.data['payment_date']),
      for (final r in _s.liveRows('payroll_results'))
        PeriodGuard.monthKey(r.data['year'] as int, r.data['month'] as int),
    }..remove(-1);
    _months = [for (final k in keys.toList()..sort()) (k ~/ 12, k % 12 + 1)];
    _month = _months.isEmpty ? null : _months.last;
  }

  static int _key(Object? iso) {
    final d = iso is String ? DateTime.tryParse(iso) : null;
    return d == null ? -1 : PeriodGuard.monthKey(d.year, d.month);
  }

  bool _inMonth(Object? iso) {
    final m = _month;
    return m != null && _key(iso) == PeriodGuard.monthKey(m.$1, m.$2);
  }

  String _name(Object? uuid) => _names[uuid] ?? 'Сотрудник не найден';

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Обзор',
      'Сотрудники',
      'Табель',
      'Выплаты',
      'Ставки',
      'Расчёты',
      'Реквизиты',
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (widget.onCompare != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: widget.onCompare,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Что изменилось с тех пор'),
                ),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
        ),
        body: TabBarView(
          children: [
            _overview(context),
            _employees(context),
            _monthly(context, _timesheet(context)),
            _monthly(context, _payments(context)),
            _rates(context),
            _monthly(context, _payroll(context)),
            _settings(context),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ обзор

  Widget _overview(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _s.counts;
    return _Page(
      children: [
        Text(
          '${widget.source == BackupSource.server ? 'Копия сервера' : 'Копия этого компьютера'}'
          ' на ${_moment.format(widget.takenAt)}',
          style: theme.textTheme.titleMedium,
        ),
        if (widget.compareUnavailable != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.compareUnavailable!,
            style: TextStyle(color: StatusColors.of(context).warningText),
          ),
        ],
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
    );
  }

  // ------------------------------------------------------------- сотрудники

  Widget _employees(BuildContext context) {
    final list = _s.liveRows('employees').toList()
      ..sort((a, b) {
        final byActive = (a.data['dismissal_date'] == null ? 0 : 1).compareTo(
          b.data['dismissal_date'] == null ? 0 : 1,
        );
        if (byActive != 0) return byActive;
        return '${a.data['full_name']}'.compareTo('${b.data['full_name']}');
      });
    if (list.isEmpty) return const _Empty('Сотрудников в копии нет');
    return _Page(
      children: [
        _Table(
          columns: const [
            'ФИО',
            'Должность',
            'Принят',
            'Уволен',
            'Ставка база',
            'Ставка поле',
          ],
          numeric: const {4, 5},
          rows: [
            for (final e in list)
              [
                '${e.data['full_name']}',
                '${e.data['position'] ?? ''}',
                formatRecordValue('hire_date', e.data['hire_date']) ?? '',
                formatRecordValue('dismissal_date', e.data['dismissal_date']) ??
                    '',
                formatRecordValue('base_rate', e.data['base_rate']) ?? '',
                formatRecordValue('field_rate', e.data['field_rate']) ?? '',
              ],
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------- месяц сверху

  Widget _monthly(BuildContext context, Widget body) {
    if (_month == null) {
      return const _Empty('В копии нет табеля, выплат и расчётов');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий месяц',
                icon: const Icon(Icons.chevron_left),
                onPressed: _months.indexOf(_month!) > 0
                    ? () => setState(
                        () => _month = _months[_months.indexOf(_month!) - 1],
                      )
                    : null,
              ),
              DropdownButton<(int, int)>(
                value: _month,
                items: [
                  for (final m in _months.reversed)
                    DropdownMenuItem(value: m, child: Text(_monthTitle(m))),
                ],
                onChanged: (m) => setState(() => _month = m),
              ),
              IconButton(
                tooltip: 'Следующий месяц',
                icon: const Icon(Icons.chevron_right),
                onPressed: _months.indexOf(_month!) < _months.length - 1
                    ? () => setState(
                        () => _month = _months[_months.indexOf(_month!) + 1],
                      )
                    : null,
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  // ------------------------------------------------------------------ табель

  Widget _timesheet(BuildContext context) {
    final month = _month;
    if (month == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final byEmployee = <String, Map<int, Map<String, Object?>>>{};
    for (final r in _s.liveRows('timesheet')) {
      if (!_inMonth(r.data['date'])) continue;
      final day = DateTime.parse(r.data['date'] as String).day;
      (byEmployee[r.data['employee_uuid'] as String] ??= {})[day] = r.data;
    }
    if (byEmployee.isEmpty) return const _Empty('Табеля за этот месяц нет');
    final ids = byEmployee.keys.toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));
    final days = DateTime(month.$1, month.$2 + 1, 0).day;
    const nameWidth = 170.0, cell = 40.0, total = 56.0;
    final weekend = theme.colorScheme.surfaceContainerHighest;
    final border = BorderSide(color: theme.colorScheme.outlineVariant);

    Widget box(
      double width,
      Widget child, {
      Color? color,
      Alignment align = Alignment.center,
    }) => Container(
      width: width,
      height: 36,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border(right: border, bottom: border),
      ),
      child: child,
    );

    bool off(int d) =>
        !ProductionCalendar.isWorkingDay(DateTime(month.$1, month.$2, d));
    final small = theme.textTheme.bodySmall;
    final bold = small?.copyWith(fontWeight: FontWeight.w600);

    double sum(Map<int, Map<String, Object?>> marks, String place) => marks
        .values
        .where((d) => d['day_type'] == 'work' && d['work_place'] == place)
        .fold(0.0, (s, d) => s + ((d['days'] as num?)?.toDouble() ?? 0));

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  box(
                    nameWidth,
                    Text('Сотрудник', style: bold),
                    align: Alignment.centerLeft,
                  ),
                  for (var d = 1; d <= days; d++)
                    box(
                      cell,
                      Text('$d', style: bold),
                      color: off(d) ? weekend : null,
                    ),
                  box(total, Text('База', style: bold)),
                  box(total, Text('Поле', style: bold)),
                ],
              ),
              for (final id in ids)
                Row(
                  children: [
                    box(
                      nameWidth,
                      Text(
                        _name(id),
                        style: small,
                        overflow: TextOverflow.ellipsis,
                      ),
                      align: Alignment.centerLeft,
                    ),
                    for (var d = 1; d <= days; d++)
                      box(
                        cell,
                        byEmployee[id]![d] == null
                            ? const SizedBox.shrink()
                            : Text(
                                timesheetCellCode(byEmployee[id]![d]!),
                                textAlign: TextAlign.center,
                                style: small?.copyWith(
                                  fontSize: 10,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: _markColor(byEmployee[id]![d]!),
                                ),
                              ),
                        color: off(d) ? weekend : null,
                      ),
                    box(
                      total,
                      Text(
                        _num.format(sum(byEmployee[id]!, 'base')),
                        style: small,
                      ),
                    ),
                    box(
                      total,
                      Text(
                        _num.format(sum(byEmployee[id]!, 'field')),
                        style: small,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Рабочий день — доля и место («1 поле», «0.5 база»; «—» — место '
                'не указано), Б — больничный, О — отпуск, В — выходной',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _markColor(Map<String, Object?> d) {
    final record = TimesheetRecord(
      employeeId: '',
      date: DateTime(2000),
      dayType: d['day_type'] as String? ?? 'work',
      days: (d['days'] as num?)?.toDouble() ?? 1,
      workPlace: d['work_place'] as String?,
    );
    return DayMark.of(record)?.color ?? StatusColors.of(context).warningText;
  }

  // ----------------------------------------------------------------- выплаты

  Widget _payments(BuildContext context) {
    final list = [
      for (final r in _s.liveRows('payments'))
        if (_inMonth(r.data['payment_date'])) r.data,
    ]..sort((a, b) => '${a['payment_date']}'.compareTo('${b['payment_date']}'));
    if (list.isEmpty) return const _Empty('Выплат за этот месяц нет');
    final total = list.fold(0.0, (s, p) => s + (p['amount'] as num));
    return _Page(
      children: [
        _Table(
          columns: const [
            'Дата',
            'Сотрудник',
            'Сумма',
            'Вид',
            'Способ',
            'Примечание',
          ],
          numeric: const {2},
          rows: [
            for (final p in list)
              [
                formatRecordValue('payment_date', p['payment_date']) ?? '',
                _name(p['employee_uuid']),
                formatRecordValue('amount', p['amount']) ?? '',
                formatRecordValue('payment_type', p['payment_type']) ?? '',
                formatRecordValue('payment_method', p['payment_method']) ?? '',
                '${p['notes'] ?? ''}',
              ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Всего выплачено: ${_rub.format(total)} ₽',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ ставки

  Widget _rates(BuildContext context) {
    final byEmployee = <String, List<Map<String, Object?>>>{};
    for (final r in _s.liveRows('employee_rates')) {
      (byEmployee[r.data['employee_uuid'] as String] ??= []).add(r.data);
    }
    if (byEmployee.isEmpty) return const _Empty('Ставок в копии нет');
    final ids = byEmployee.keys.toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));
    final theme = Theme.of(context);
    return _Page(
      children: [
        for (final id in ids) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(_name(id), style: theme.textTheme.titleSmall),
          ),
          _Table(
            columns: const ['С', 'По', 'База', 'Поле'],
            numeric: const {2, 3},
            rows: [
              for (final r
                  in byEmployee[id]!..sort(
                    (a, b) =>
                        '${a['start_date']}'.compareTo('${b['start_date']}'),
                  ))
                [
                  formatRecordValue('start_date', r['start_date']) ?? '',
                  formatRecordValue('end_date', r['end_date']) ?? 'бессрочно',
                  formatRecordValue('base_rate', r['base_rate']) ?? '',
                  formatRecordValue('field_rate', r['field_rate']) ?? '',
                ],
            ],
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------------- расчёты

  Widget _payroll(BuildContext context) {
    final month = _month;
    final list =
        [
          for (final r in _s.liveRows('payroll_results'))
            if (month != null &&
                r.data['year'] == month.$1 &&
                r.data['month'] == month.$2)
              r.data,
        ]..sort(
          (a, b) =>
              _name(a['employee_uuid']).compareTo(_name(b['employee_uuid'])),
        );
    if (list.isEmpty) {
      return const _Empty('Сохранённых расчётов за этот месяц в копии нет');
    }
    final total = list.fold(0.0, (s, p) => s + (p['total_salary'] as num));
    String n(Object? v) => v is num ? _num.format(v) : '';
    return _Page(
      children: [
        _Table(
          columns: const [
            'Сотрудник',
            'Дней база',
            'Дней поле',
            'Больничный',
            'Отпуск',
            'Без ставки',
            'Начислено',
          ],
          numeric: const {1, 2, 3, 4, 5, 6},
          rows: [
            for (final p in list)
              [
                _name(p['employee_uuid']),
                n(p['base_days']),
                n(p['field_days']),
                n(p['sick_days']),
                n(p['vacation_days']),
                n(p['skipped_work_days']),
                formatRecordValue('total_salary', p['total_salary']) ?? '',
              ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Всего начислено: ${_rub.format(total)} ₽',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Расчёты, которые сервер сохранил на момент копии.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- реквизиты

  Widget _settings(BuildContext context) {
    final row = _s.liveRows('company_settings').firstOrNull;
    if (row == null) return const _Empty('Реквизитов в копии нет');
    final labels = recordFieldLabels('company_settings');
    return _Page(
      children: [
        Card(
          child: Column(
            children: [
              for (final MapEntry(key: field, value: label) in labels.entries)
                ListTile(
                  dense: true,
                  title: Text(label),
                  subtitle: Text(
                    formatRecordValue(field, row.data[field]) ?? '—',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  final List<Widget> children;

  const _Page({required this.children});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppTheme.defaultPadding),
    children: children,
  );
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// Простая таблица с горизонтальной прокруткой.
class _Table extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final Set<int> numeric;

  const _Table({
    required this.columns,
    required this.rows,
    this.numeric = const {},
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columns: [
          for (final (i, c) in columns.indexed)
            DataColumn(label: Text(c), numeric: numeric.contains(i)),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [for (final v in r) DataCell(Text(v))]),
        ],
      ),
    ),
  );
}
