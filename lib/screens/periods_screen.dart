// lib/screens/periods_screen.dart
//
// Закрытие месяцев (шаг 6.2): месяцы с данными и текущий, у каждого — закрыт
// ли, кем и когда. Закрывают бухгалтер и админ, открывает только админ.
// Нужна связь с сервером: закрытие — действие сервера.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/period_lock_dialogs.dart';

class PeriodsScreen extends StatefulWidget {
  const PeriodsScreen({super.key});

  @override
  State<PeriodsScreen> createState() => _PeriodsScreenState();
}

class _PeriodsScreenState extends State<PeriodsScreen> {
  List<(int, int)> _months = [];

  /// Закрытые месяцы с сервера (ключ — [PeriodGuard.monthKey]); null — не
  /// получены.
  Map<int, PeriodLockInfo>? _locks;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppProvider>();
    final sync = context.read<SyncProvider>();
    Map<int, PeriodLockInfo>? locks;
    String? error;
    try {
      locks = {
        for (final l in await sync.periodLocks())
          PeriodGuard.monthKey(l.year, l.month): l,
      };
    } on SyncUserException catch (e) {
      error = e.message;
    }
    final now = DateTime.now();
    final keys = <int>{
      PeriodGuard.monthKey(now.year, now.month),
      for (final (y, m) in await app.dataMonths()) PeriodGuard.monthKey(y, m),
      ...?locks?.keys,
    };
    // Все месяцы от самого раннего до самого позднего — без пропусков.
    final first = keys.reduce((a, b) => a < b ? a : b);
    final last = keys.reduce((a, b) => a > b ? a : b);
    if (!mounted) return;
    setState(() {
      _months = [for (var k = last; k >= first; k--) (k ~/ 12, k % 12 + 1)];
      _locks = locks;
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Закрытие месяцев'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Закрытый месяц нельзя править ни на одном устройстве, а '
                    'его расчёт зафиксирован. Закрывают бухгалтер и '
                    'администратор, открыть снова может только администратор.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_error != null)
                  ListTile(
                    leading: Icon(
                      Icons.cloud_off,
                      color: StatusColors.of(context).warningText,
                    ),
                    title: Text(_error!),
                    subtitle: const Text(
                      'Показано, что известно с последней синхронизации; '
                      'закрывать и открывать месяцы можно только при связи '
                      'с сервером.',
                    ),
                  ),
                for (final (y, m) in _months)
                  _MonthTile(
                    year: y,
                    month: m,
                    lock: _locks?[PeriodGuard.monthKey(y, m)],
                    locked: _locks != null
                        ? _locks!.containsKey(PeriodGuard.monthKey(y, m))
                        : app.isMonthLocked(y, m),
                    online: _locks != null,
                    canLock: sync.canLockMonths,
                    canUnlock: sync.canUnlockMonths,
                    onChanged: _load,
                  ),
              ],
            ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final int year;
  final int month;
  final PeriodLockInfo? lock;
  final bool locked;
  final bool online;
  final bool canLock;
  final bool canUnlock;
  final Future<void> Function() onChanged;

  const _MonthTile({
    required this.year,
    required this.month,
    required this.lock,
    required this.locked,
    required this.online,
    required this.canLock,
    required this.canUnlock,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lock = this.lock;
    final at = lock?.lockedAt;
    final details = [
      if (lock?.lockedByName != null) lock!.lockedByName!,
      if (at != null) DateFormat('dd.MM.yyyy HH:mm').format(at.toLocal()),
      if (lock?.note != null) '«${lock!.note}»',
    ].join(' · ');

    Widget? action;
    if (online && !locked && canLock) {
      action = OutlinedButton.icon(
        icon: const Icon(Icons.lock_outline, size: 18),
        label: const Text('Закрыть'),
        onPressed: () async {
          if (await closeMonth(context, year, month)) await onChanged();
        },
      );
    } else if (online && locked && canUnlock) {
      action = TextButton.icon(
        icon: const Icon(Icons.lock_open, size: 18),
        label: const Text('Открыть'),
        onPressed: () async {
          if (await openMonth(context, year, month)) await onChanged();
        },
      );
    }

    return ListTile(
      leading: Icon(
        locked ? Icons.lock : Icons.lock_open_outlined,
        color: locked ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(monthTitle(year, month)),
      subtitle: Text(
        locked ? 'Закрыт${details.isEmpty ? '' : ': $details'}' : 'Открыт',
      ),
      trailing: action,
    );
  }
}
