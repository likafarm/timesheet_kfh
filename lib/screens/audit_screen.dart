// lib/screens/audit_screen.dart
//
// Журнал действий (6.7, только админ): кто, когда и что изменил — по данным
// сервера (audit_log). Отбор по периоду, сотруднику, пользователю и виду
// записей; записи по дням, новые сверху; у правки — какие поля как
// изменились (прежнее значение зачёркнуто). Нужна связь с сервером.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import '../utils/audit_format.dart';

/// Период отбора: подпись и сколько дней назад (null — всё время).
const _periods = <(String, int?)>[
  ('Сегодня', 0),
  ('7 дней', 7),
  ('30 дней', 30),
  ('90 дней', 90),
  ('Всё время', null),
];

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  int _period = 2; // 30 дней
  String? _employee;
  String? _user;
  String? _kind;
  List<SessionUser> _users = [];
  List<Employee> _employees = [];

  final List<AuditEntry> _entries = [];
  int? _next;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sync = context.read<SyncProvider>();
      final employees = context.read<AppProvider>().employees.toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      setState(() => _employees = employees);
      try {
        final users = await sync.serverUsers();
        if (mounted) setState(() => _users = users);
      } on SyncUserException {
        // Без списка пользователей — только без этого отбора.
      }
      await _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries.clear();
        _next = null;
      }
    });
    final days = _periods[_period].$2;
    final now = DateTime.now();
    final since = days == null
        ? null
        : DateTime(now.year, now.month, now.day - days);
    try {
      final page = await context.read<SyncProvider>().auditLog(
        since: since,
        userUuid: _user,
        employeeUuid: _employee,
        kind: _kind,
        before: reset ? null : _next,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _next = page.nextBefore;
      });
    } on SyncUserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _change(VoidCallback update) {
    setState(update);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Записи по дням (местное время).
    final byDay = <DateTime, List<AuditEntry>>{};
    for (final e in _entries) {
      final t = e.at.toLocal();
      (byDay[DateTime(t.year, t.month, t.day)] ??= []).add(e);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал действий'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_error != null)
                  ListTile(
                    leading: Icon(
                      Icons.cloud_off,
                      color: StatusColors.of(context).warningText,
                    ),
                    title: Text(_error!),
                  ),
                if (!_loading && _error == null && _entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Записей нет')),
                  ),
                for (final MapEntry(key: day, value: entries)
                    in byDay.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      DateFormat('d MMMM yyyy, EEEE', 'ru').format(day),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  for (final e in entries) _EntryTile(entry: e),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_next != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: () => _load(reset: false),
                        child: const Text('Показать ещё'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    Widget box<T>(
      String label,
      T? value,
      List<DropdownMenuItem<T?>> items,
      void Function(T?) onChanged, {
      double width = 200,
    }) => SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items,
        onChanged: onChanged,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          box<int>(
            'Период',
            _period,
            [
              for (final (i, p) in _periods.indexed)
                DropdownMenuItem(value: i, child: Text(p.$1)),
            ],
            (v) => _change(() => _period = v ?? 2),
            width: 140,
          ),
          box<String>(
            'Сотрудник',
            _employee,
            [
              const DropdownMenuItem(value: null, child: Text('Все')),
              for (final e in _employees)
                if (e.id != null)
                  DropdownMenuItem(value: e.id, child: Text(e.fullName)),
            ],
            (v) => _change(() => _employee = v),
            width: 240,
          ),
          box<String>('Кто', _user, [
            const DropdownMenuItem(value: null, child: Text('Все')),
            for (final u in _users)
              DropdownMenuItem(
                value: u.uuid,
                child: Text(u.fullName.isEmpty ? u.login : u.fullName),
              ),
          ], (v) => _change(() => _user = v)),
          box<String>('Что', _kind, [
            const DropdownMenuItem(value: null, child: Text('Всё')),
            for (final MapEntry(:key, :value) in auditKindLabels.entries)
              DropdownMenuItem(value: key, child: Text(value)),
          ], (v) => _change(() => _kind = v)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final AuditEntry entry;

  const _EntryTile({required this.entry});

  static IconData _icon(AuditEntry e) => switch (e.entity) {
    'timesheet' => Icons.calendar_month,
    'payments' => Icons.payments_outlined,
    'employee_rates' => Icons.price_change_outlined,
    'employees' => Icons.person_outline,
    'payroll_results' => Icons.calculate_outlined,
    'company_settings' => Icons.business_outlined,
    'period_locks' => Icons.lock_outline,
    _ => Icons.login,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final view = describeAudit(entry);
    final who = entry.userName ?? entry.userLogin;
    final meta = [
      DateFormat('HH:mm').format(entry.at.toLocal()),
      ?who,
      ?view.subject,
    ].join(' · ');
    return ListTile(
      leading: Icon(
        _icon(entry),
        color: view.warning ? status.warningText : scheme.onSurfaceVariant,
      ),
      title: Text(
        view.title,
        style: TextStyle(color: view.warning ? status.warningText : null),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta),
          for (final c in view.changes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${c.label}: ',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    if (c.before != null)
                      TextSpan(
                        text: c.before,
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (c.before != null && c.after != null)
                      const TextSpan(text: '  '),
                    if (c.after != null)
                      TextSpan(
                        text: c.after,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
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
