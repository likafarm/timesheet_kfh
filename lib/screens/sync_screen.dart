// lib/screens/sync_screen.dart
//
// Сервер синхронизации: вход, состояние, «синхронизировать сейчас»,
// отклонённые сервером правки и журнал конфликтов.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show RejectedChange;
import 'package:kfh_sync/kfh_sync.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../widgets/sync_dialogs.dart';
import '../widgets/sync_status_bar.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<JournalEntry> _journal = const [];
  List<RejectedChange> _rejected = const [];
  DateTime? _loadedFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = context.read<SyncProvider>();
    final journal = await sync.journal.recent(limit: 300);
    final rejected = await sync.rejectedChanges();
    if (!mounted) return;
    setState(() {
      _journal = journal;
      _rejected = rejected;
      _loadedFor = sync.lastSyncAt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    // После очередной синхронизации журнал мог пополниться.
    if (sync.lastSyncAt != _loadedFor && !sync.isSyncing) {
      _loadedFor = sync.lastSyncAt;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Сервер синхронизации')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AccountCard(sync: sync, onChanged: _load),
          const SizedBox(height: 16),
          if (_rejected.isNotEmpty) ...[
            _RejectedCard(rejected: _rejected, sync: sync, onRetry: _load),
            const SizedBox(height: 16),
          ],
          _JournalCard(entries: _journal),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- вход

class _AccountCard extends StatelessWidget {
  final SyncProvider sync;
  final Future<void> Function() onChanged;

  const _AccountCard({required this.sync, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final user = sync.user;
    final rows = <(String, String)>[
      ('Сервер', sync.server),
      if (user != null)
        (
          'Пользователь',
          '${user.fullName.isEmpty ? user.login : user.fullName} '
              '(${user.login}, ${user.roleTitle})',
        ),
      (
        'Состояние',
        switch (sync.phase) {
          SyncPhase.starting => '…',
          SyncPhase.signedOut => 'вход не выполнен',
          SyncPhase.passwordChange => 'нужно сменить пароль',
          SyncPhase.needsLink => 'база ещё не связана с сервером',
          SyncPhase.ready =>
            sync.isSyncing
                ? 'идёт синхронизация'
                : sync.problem ?? 'связь в порядке',
        },
      ),
      if (sync.lastSyncAt != null)
        ('Последняя синхронизация', SyncStatusBar.when(sync.lastSyncAt!)),
      if (sync.phase == SyncPhase.ready) ('Не отправлено', '${sync.pending}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: SelectableText(value)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sync.phase == SyncPhase.ready)
                  FilledButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () async {
                            await sync.syncNow();
                            await onChanged();
                          },
                    icon: const Icon(Icons.sync),
                    label: const Text('Синхронизировать сейчас'),
                  ),
                if (sync.phase == SyncPhase.signedOut)
                  FilledButton.icon(
                    onPressed: () => startSignIn(context),
                    icon: const Icon(Icons.login),
                    label: const Text('Войти'),
                  ),
                if (sync.phase == SyncPhase.passwordChange ||
                    sync.phase == SyncPhase.needsLink)
                  FilledButton.icon(
                    onPressed: () => continueSyncSetup(context),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Продолжить настройку'),
                  ),
                if (user != null && sync.phase == SyncPhase.ready)
                  OutlinedButton.icon(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => const ChangePasswordDialog(),
                    ),
                    icon: const Icon(Icons.password),
                    label: const Text('Сменить пароль'),
                  ),
                if (user != null)
                  OutlinedButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () async {
                            await sync.signOut();
                            if (context.mounted) await startSignIn(context);
                          },
                    icon: const Icon(Icons.switch_account),
                    label: const Text('Сменить пользователя'),
                  ),
                if (user != null)
                  OutlinedButton.icon(
                    onPressed: sync.isSyncing ? null : () => sync.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Выйти'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- отказы

class _RejectedCard extends StatelessWidget {
  final List<RejectedChange> rejected;
  final SyncProvider sync;
  final Future<void> Function() onRetry;

  const _RejectedCard({
    required this.rejected,
    required this.sync,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Не принято сервером: ${rejected.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Эти правки остаются на этом компьютере и повторно не '
              'отправляются, пока их не изменят. Если причина устранена '
              '(например, месяц открыт) — отправьте их ещё раз.',
            ),
            const SizedBox(height: 8),
            for (final r in rejected.take(50))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block, color: Color(0xFFB26A00)),
                title: Text('${tableTitle(r.table)}: ${r.message}'),
                subtitle: Text(
                  'Попыток: ${r.attempts}, первая — '
                  '${SyncStatusBar.when(r.since.toLocal())}',
                ),
              ),
            if (sync.phase == SyncPhase.ready)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: sync.isSyncing
                      ? null
                      : () async {
                          await sync.syncNow(retryRejected: true);
                          await onRetry();
                        },
                  icon: const Icon(Icons.replay),
                  label: const Text('Отправить ещё раз'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- журнал

class _JournalCard extends StatelessWidget {
  final List<JournalEntry> entries;

  const _JournalCard({required this.entries});

  static IconData _icon(JournalKind kind) => switch (kind) {
    JournalKind.lost => Icons.merge_type,
    JournalKind.lostUnique => Icons.content_copy,
    JournalKind.rejected => Icons.block,
    JournalKind.resync => Icons.restart_alt,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Журнал синхронизации',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Конфликты правок и отказы сервера. Обычная синхронизация сюда '
              'не пишется.',
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Записей нет.'),
              ),
            for (final e in entries)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Icon(_icon(e.kind)),
                title: Text(e.message),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy HH:mm:ss').format(e.at.toLocal()),
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.only(left: 56, bottom: 8),
                children: [
                  if (e.local != null)
                    _Snapshot(title: 'Версия этого компьютера', data: e.local!),
                  if (e.remote != null)
                    _Snapshot(title: 'Версия сервера', data: e.remote!),
                  if (e.local == null && e.remote == null)
                    const Text('Подробностей нет.'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Snapshot extends StatelessWidget {
  final String title;
  final Map<String, Object?> data;

  const _Snapshot({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
