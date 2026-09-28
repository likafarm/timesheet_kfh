// lib/screens/employee_rate_history_screen.dart
//
// История ставок сотрудника и управление ею: добавить ставку с любой даты,
// изменить (суммы, начало, окончание последней), удалить. Соседние периоды
// согласуются сами (kfh_domain, rate_timeline.dart); правки, задевающие
// закрытый месяц, не записываются — с объяснением.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_dialog.dart';

final _day = DateFormat('dd.MM.yyyy');
final _money = NumberFormat('#,##0.00', 'ru');

String _period(EmployeeRate r) =>
    'с ${_day.format(r.startDate)}'
    '${r.endDate == null ? ' — бессрочно' : ' по ${_day.format(r.endDate!)}'}';

class EmployeeRateHistoryScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeRateHistoryScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeRateHistoryScreen> createState() =>
      _EmployeeRateHistoryScreenState();
}

class _EmployeeRateHistoryScreenState extends State<EmployeeRateHistoryScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().loadEmployeeRates(
        employeeId: widget.employeeId,
      );
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Ставки этого сотрудника, по дате начала.
  List<EmployeeRate> _rates(AppProvider provider) =>
      provider.employeeRates
          .where((r) => r.employeeId == widget.employeeId)
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  Future<void> _edit({EmployeeRate? rate, required bool isLast}) async {
    final saved = await showAppDialog<bool>(
      context: context,
      builder: (_) => _RateFormDialog(
        employeeId: widget.employeeId,
        rate: rate,
        canSetEnd: rate == null || isLast,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rate == null ? 'Ставка добавлена' : 'Ставка изменена'),
        ),
      );
    }
  }

  Future<void> _delete(EmployeeRate rate, List<EmployeeRate> rates) async {
    final index = rates.indexOf(rate);
    final previous = index > 0 ? rates[index - 1] : null;
    final next = index + 1 < rates.length ? rates[index + 1] : null;
    final adjacent =
        previous?.endDate != null &&
        addCalendarDays(calendarDay(rate.startDate), -1) ==
            calendarDay(previous!.endDate!);
    final String consequence;
    if (adjacent) {
      consequence =
          'Её период перейдёт к предыдущей ставке (база '
          '${_money.format(previous.baseRate)} ₽, поле '
          '${_money.format(previous.fieldRate)} ₽).';
    } else if (next != null) {
      consequence =
          'Дни с ${_day.format(rate.startDate)} по '
          '${_day.format(addCalendarDays(calendarDay(next.startDate), -1))} '
          'останутся без ставки и не будут оплачиваться.';
    } else {
      consequence =
          'Дни с ${_day.format(rate.startDate)} останутся без ставки и не '
          'будут оплачиваться.';
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: const Text('Удалить ставку?'),
        content: SizedBox(
          width: 400,
          child: Text(
            'База ${_money.format(rate.baseRate)} ₽, поле '
            '${_money.format(rate.fieldRate)} ₽, ${_period(rate)}.\n\n'
            '$consequence Расчёты ЗП за затронутые месяцы нужно будет '
            'пересчитать.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final problem = await context.read<AppProvider>().deleteRate(rate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(problem ?? 'Ставка удалена'),
        duration: Duration(seconds: problem == null ? 3 : 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final rates = _rates(provider);
    final current = rateOn(rates, DateTime.now());
    final today = calendarDay(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ставки: ${widget.employeeName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(isLast: false),
              icon: const Icon(Icons.add),
              label: const Text('Добавить ставку'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Ошибка: $_error',
                style: TextStyle(color: scheme.error),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Действует сегодня',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (current == null)
                          Text(
                            'Ставки нет — рабочие дни без ставки не '
                            'оплачиваются.',
                            style: TextStyle(color: scheme.error),
                          )
                        else
                          Text(
                            'База ${_money.format(current.baseRate)} ₽/день · '
                            'поле ${_money.format(current.fieldRate)} ₽/день',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Новая ставка с какой-то даты закрывает предыдущую '
                    'накануне. Ставки, действующие в закрытом месяце, не '
                    'меняются — добавьте новую с нужной даты.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (rates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Ставок пока нет')),
                  ),
                // Новые сверху.
                for (final rate in rates.reversed)
                  Card(
                    child: ListTile(
                      onTap: () =>
                          _edit(rate: rate, isLast: rate == rates.last),
                      leading: CircleAvatar(
                        backgroundColor: rate == current
                            ? status.positive.withValues(alpha: 0.18)
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          rate == current
                              ? Icons.check
                              : rate.startDate.isAfter(today)
                              ? Icons.schedule
                              : Icons.history,
                          size: 20,
                          color: rate == current
                              ? status.positive
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        'База ${_money.format(rate.baseRate)} ₽ · '
                        'поле ${_money.format(rate.fieldRate)} ₽',
                      ),
                      subtitle: Text(
                        [
                          _period(rate),
                          if (rate == current) 'действует сейчас',
                          if (rate.startDate.isAfter(today)) 'будущая',
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Действия',
                        onSelected: (action) => action == 'edit'
                            ? _edit(rate: rate, isLast: rate == rates.last)
                            : _delete(rate, rates),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Изменить')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Добавление ([rate] = null) или изменение ставки.
class _RateFormDialog extends StatefulWidget {
  final String employeeId;
  final EmployeeRate? rate;

  /// Можно задать дату окончания: новая или последняя ставка (у остальных
  /// окончание — накануне следующей).
  final bool canSetEnd;

  const _RateFormDialog({
    required this.employeeId,
    required this.rate,
    required this.canSetEnd,
  });

  @override
  State<_RateFormDialog> createState() => _RateFormDialogState();
}

class _RateFormDialogState extends State<_RateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _base;
  late final TextEditingController _field;
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    final r = widget.rate;
    String amount(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    _base = TextEditingController(text: r == null ? '' : amount(r.baseRate));
    _field = TextEditingController(text: r == null ? '' : amount(r.fieldRate));
    _start = r?.startDate ?? calendarDay(DateTime.now());
    _end = r?.endDate;
  }

  @override
  void dispose() {
    _base.dispose();
    _field.dispose();
    super.dispose();
  }

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.'));

  String? _validateAmount(String? v) {
    final value = _parse(v ?? '');
    if (value == null) return 'Введите сумму';
    if (value < 0) return 'Не меньше нуля';
    return null;
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _problem = null;
    });
    final provider = context.read<AppProvider>();
    final edited = EmployeeRate(
      id: widget.rate?.id,
      employeeId: widget.employeeId,
      baseRate: _parse(_base.text)!,
      fieldRate: _parse(_field.text)!,
      startDate: _start,
      endDate: _end,
    );
    final problem = widget.rate == null
        ? await provider.addRate(edited)
        : await provider.updateRate(edited);
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _problem = problem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppDialog(
      title: Text(widget.rate == null ? 'Новая ставка' : 'Изменить ставку'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Действует с'),
                  subtitle: Text(_day.format(_start)),
                  onTap: _saving
                      ? null
                      : () async {
                          final d = await _pick(_start);
                          if (d != null) setState(() => _start = d);
                        },
                ),
                if (widget.canSetEnd)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy),
                    title: const Text('Действует по'),
                    subtitle: Text(
                      _end == null
                          ? widget.rate == null
                                ? 'до следующей ставки или бессрочно'
                                : 'бессрочно'
                          : _day.format(_end!),
                    ),
                    onTap: _saving
                        ? null
                        : () async {
                            final d = await _pick(_end ?? _start);
                            if (d != null) setState(() => _end = d);
                          },
                    trailing: _end == null
                        ? null
                        : IconButton(
                            tooltip: 'Бессрочно',
                            icon: const Icon(Icons.clear),
                            onPressed: _saving
                                ? null
                                : () => setState(() => _end = null),
                          ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _base,
                  enabled: !_saving,
                  autofocus: widget.rate == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'База, ₽/день',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _field,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Поле, ₽/день',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateAmount,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 12),
                  Text(_problem!, style: TextStyle(color: scheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.rate == null ? 'Добавить' : 'Сохранить'),
        ),
      ],
    );
  }
}
