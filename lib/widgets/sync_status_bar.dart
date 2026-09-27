// lib/widgets/sync_status_bar.dart
//
// Строка состояния синхронизации внизу главного окна: когда синхронизировано,
// сколько не отправлено, понятная ошибка, кнопка «Синхронизировать сейчас».

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../screens/sync_screen.dart';
import 'sync_dialogs.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  static const height = 32.0;

  /// «сегодня в 12:34» / «вчера в 18:02» / «25.09.2026 в 09:15».
  static String when(DateTime at, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat('HH:mm').format(at);
    if (day == DateTime(today.year, today.month, today.day)) {
      return 'сегодня в $time';
    }
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'вчера в $time';
    }
    return '${DateFormat('dd.MM.yyyy').format(at)} в $time';
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const warning = Color(0xFFB26A00);

    IconData icon;
    Color color;
    String text;
    Widget action;

    void openScreen() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncScreen()));

    switch (sync.phase) {
      case SyncPhase.starting:
        return const SizedBox(height: height);
      case SyncPhase.signedOut:
        icon = Icons.cloud_off_outlined;
        color = sync.problem != null ? warning : muted;
        text =
            sync.problem ??
            'Вход на сервер не выполнен — данные только на этом компьютере';
        action = TextButton(
          onPressed: () => startSignIn(context),
          child: const Text('Войти'),
        );
      case SyncPhase.passwordChange:
      case SyncPhase.needsLink:
        icon = Icons.cloud_queue;
        color = warning;
        text = sync.phase == SyncPhase.passwordChange
            ? 'Нужно сменить пароль, выданный администратором'
            : 'Вход выполнен, но база ещё не связана с сервером';
        action = TextButton(
          onPressed: () => continueSyncSetup(context),
          child: const Text('Продолжить'),
        );
      case SyncPhase.ready:
        final parts = <String>[];
        if (sync.isSyncing) {
          icon = Icons.sync;
          color = theme.colorScheme.primary;
          parts.add('Синхронизация…');
        } else if (sync.problem != null) {
          icon = sync.isOffline
              ? Icons.cloud_off_outlined
              : Icons.error_outline;
          color = sync.isOffline ? warning : theme.colorScheme.error;
          parts.add(sync.problem!);
          final next = sync.nextAttemptAt;
          if (next != null) {
            parts.add('повтор в ${DateFormat('HH:mm:ss').format(next)}');
          }
        } else {
          icon = Icons.cloud_done_outlined;
          color = Colors.green.shade700;
          final at = sync.lastSyncAt;
          parts.add(
            at == null
                ? 'Ещё не синхронизировано'
                : 'Синхронизировано ${when(at)}',
          );
        }
        if (sync.pending > 0) parts.add('не отправлено: ${sync.pending}');
        if (sync.rejected > 0) {
          parts.add('не принято сервером: ${sync.rejected}');
          if (!sync.isSyncing && sync.problem == null) color = warning;
        }
        text = parts.join(' · ');
        action = IconButton(
          tooltip: 'Синхронизировать сейчас',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: sync.isSyncing ? null : () => sync.syncNow(),
          icon: const Icon(Icons.sync),
        );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: openScreen,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: text,
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: color),
                    ),
                  ),
                ),
                if (sync.user != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      sync.user!.fullName.isEmpty
                          ? sync.user!.login
                          : sync.user!.fullName,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
