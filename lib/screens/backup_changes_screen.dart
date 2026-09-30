// lib/screens/backup_changes_screen.dart
//
// «Что изменилось с тех пор» (модуль «Резервные копии», 3.7): копия против
// того, что есть сейчас, с отбором по сотруднику и месяцу. Отдельные записи
// или всю базу можно вернуть к состоянию копии — обычными правками (уходят
// на сервер и на все устройства, видны в журнале действий), с предпросмотром
// и копией текущего состояния перед возвратом. Закрытые месяцы не трогаются.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show RestoreException;
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/backup_change_format.dart';

final _moment = DateFormat('dd.MM.yyyy HH:mm');

String _monthTitle((int, int) m) {
  final text = DateFormat('LLLL yyyy', 'ru').format(DateTime(m.$1, m.$2));
  return text[0].toUpperCase() + text.substring(1);
}

class BackupChangesScreen extends StatefulWidget {
  final String title;
  final DateTime takenAt;
  final DataSnapshot snapshot;

  const BackupChangesScreen({
    super.key,
    required this.title,
    required this.takenAt,
    required this.snapshot,
  });

  @override
  State<BackupChangesScreen> createState() => _BackupChangesScreenState();
}

class _BackupChangesScreenState extends State<BackupChangesScreen> {
  DataSnapshot? _now;
  List<RecordChange> _all = const [];
  Map<String, String> _names = const {};
  String? _error;
  bool _busy = false;

  String? _employee;
  (int, int)? _month;
  final _selected = <String>{};

  static String _id(RecordChange c) => '${c.table}/${c.uuid}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = await context.read<AppProvider>().currentSnapshot();
      if (!mounted) return;
      final all = diffSnapshots(widget.snapshot, now);
      setState(() {
        _now = now;
        _all = all;
        _names = employeeNames(widget.snapshot, now);
        _selected.removeWhere((id) => !all.any((c) => _id(c) == id));
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Текущие данные не прочитаны: $e');
    }
  }

  /// Месяцы, которых касаются отличия, — по убыванию.
  List<(int, int)> get _months {
    final keys = <int>{};
    for (final c in _all) {
      for (final r in [c.then, c.now]) {
        if (r == null || r.deleted) continue;
        for (final field in const ['date', 'payment_date', 'start_date']) {
          final v = r.data[field];
          final d = v is String ? DateTime.tryParse(v) : null;
          if (d != null) keys.add(PeriodGuard.monthKey(d.year, d.month));
        }
      }
    }
    return [
      for (final k in keys.toList()..sort((a, b) => b.compareTo(a)))
        (k ~/ 12, k % 12 + 1),
    ];
  }

  List<RecordChange> get _visible => [
    for (final c in _all)
      if ((_employee == null || c.employeeUuid == _employee) &&
          (_month == null || c.touchesMonth(_month!.$1, _month!.$2)))
        c,
  ];

  // --------------------------------------------------------------- возврат

  Future<void> _restore(List<RecordChange> changes, {required bool all}) async {
    final now = _now;
    if (now == null || changes.isEmpty) return;
    final plan = planRestore(
      changes,
      now: now,
      lockedMonths: context.read<AppProvider>().lockedMonths,
    );
    final ok = await _preview(plan, all: all);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final safety = await context.read<AppProvider>().restoreFromSnapshot(
        plan.edits,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'Возвращено записей: ${plan.edits.length}. Правки уйдут на сервер '
            'при синхронизации. Копия до возврата: '
            '${safety.split(RegExp(r'[\\/]')).last}',
          ),
        ),
      );
      _selected.clear();
    } on RestoreException catch (e) {
      if (mounted) await _message('Возврат не выполнен', e.message);
    } catch (e) {
      if (mounted) {
        await _message('Возврат не выполнен', 'Ничего не изменено: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<bool?> _preview(RestorePlan plan, {required bool all}) {
    final theme = Theme.of(context);
    final warning = StatusColors.of(context).warningText;
    final byKey = {for (final c in _all) _id(c): c};
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          all
              ? 'Вернуть всю базу на ${_moment.format(widget.takenAt)}?'
              : 'Вернуть выбранные записи?',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.isEmpty
                      ? 'Возвращать нечего.'
                      : 'Изменится записей: ${plan.edits.length}. Это обычные '
                            'правки: они уйдут на сервер и на все устройства и '
                            'будут видны в журнале действий. Перед возвратом '
                            'программа сохранит копию текущего состояния. '
                            'Расчёты ЗП сервер пересчитает сам.',
                ),
                const SizedBox(height: 12),
                for (final e in plan.edits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${recordKindLabels[e.table]}: '
                                '${recordSubject(e.table, byKey['${e.table}/${e.uuid}']?.data ?? e.data, _names)}\n',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: restoreEditLabel(e),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (plan.skipped.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Не будет тронуто: ${plan.skipped.length}',
                    style: TextStyle(
                      color: warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final s in plan.skipped)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${recordKindLabels[s.change.table]}: '
                        '${recordSubject(s.change.table, s.change.data, _names)}'
                        ' — ${s.reason}',
                        style: TextStyle(color: warning),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          if (!plan.isEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Вернуть'),
            ),
        ],
      ),
    );
  }

  Future<void> _message(String title, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------ экран

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    final chosen = [
      for (final c in _all)
        if (_selected.contains(_id(c))) c,
    ];
    final employees = _names.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Scaffold(
      appBar: AppBar(
        title: Text('Что изменилось с ${_moment.format(widget.takenAt)}'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _now == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String?>(
                        value: _employee,
                        hint: const Text('Все сотрудники'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Все сотрудники'),
                          ),
                          for (final e in employees)
                            DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) => setState(() => _employee = v),
                      ),
                      DropdownButton<(int, int)?>(
                        value: _month,
                        hint: const Text('Все месяцы'),
                        items: [
                          const DropdownMenuItem<(int, int)?>(
                            value: null,
                            child: Text('Все месяцы'),
                          ),
                          for (final m in _months)
                            DropdownMenuItem<(int, int)?>(
                              value: m,
                              child: Text(_monthTitle(m)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _month = v),
                      ),
                      Text(
                        'Отличий: ${visible.length}'
                        '${visible.length == _all.length ? '' : ' из ${_all.length}'}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _all.isEmpty
                      ? const Center(
                          child: Text('С момента копии ничего не изменилось'),
                        )
                      : visible.isEmpty
                      ? const Center(child: Text('По этому отбору отличий нет'))
                      : ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ChangeTile(
                            change: visible[i],
                            names: _names,
                            selected: _selected.contains(_id(visible[i])),
                            enabled: !_busy,
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selected.add(_id(visible[i]));
                              } else {
                                _selected.remove(_id(visible[i]));
                              }
                            }),
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy || visible.isEmpty
                            ? null
                            : () => setState(() {
                                final ids = visible.map(_id);
                                if (ids.every(_selected.contains)) {
                                  _selected.removeAll(ids);
                                } else {
                                  _selected.addAll(ids);
                                }
                              }),
                        child: const Text('Выбрать всё по отбору'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || _all.isEmpty
                            ? null
                            : () => _restore(_all, all: true),
                        icon: const Icon(Icons.history),
                        label: const Text('Вернуть всю базу на дату копии…'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy || chosen.isEmpty
                            ? null
                            : () => _restore(chosen, all: false),
                        icon: const Icon(Icons.undo),
                        label: Text('Вернуть выбранные (${chosen.length})…'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final RecordChange change;
  final Map<String, String> names;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ChangeTile({
    required this.change,
    required this.names,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final fields = changeFields(change);
    final color = switch (change.kind) {
      RecordChangeKind.added => Colors.green.shade700,
      RecordChangeKind.changed => StatusColors.of(context).warningText,
      RecordChangeKind.removed => theme.colorScheme.error,
    };
    return CheckboxListTile(
      value: selected,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        '${recordKindLabels[change.table]}: '
        '${recordSubject(change.table, change.data, names)}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            changeKindLabel(change.kind),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          for (final f in fields)
            Text(
              change.kind == RecordChangeKind.changed
                  ? '${f.label}: в копии ${f.before ?? '—'} → сейчас ${f.after ?? '—'}'
                  : '${f.label}: ${f.after ?? f.before ?? '—'}',
              style: TextStyle(color: muted),
            ),
          if (fields.isEmpty && change.kind == RecordChangeKind.changed)
            Text('Изменены служебные поля', style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}
