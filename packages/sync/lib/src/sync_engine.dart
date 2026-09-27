import 'dart:async';

import 'package:kfh_local_db/kfh_local_db.dart';

import 'failures.dart';
import 'sync_journal.dart';
import 'sync_transport.dart';

/// Итог одного прогона синхронизации.
class SyncReport {
  /// Принято сервером (`applied`).
  int pushed = 0;

  /// Сервер уже имел эту версию (повторная отправка).
  int duplicates = 0;

  /// На сервере версия новее — придёт через pull.
  int stale = 0;

  /// Не принято сервером (месяц закрыт, нет прав…) — ждут вмешательства.
  int rejected = 0;

  /// Записано изменений с сервера.
  int received = 0;

  /// Пропущено изменений с сервера: здесь неотправленная правка новее.
  int keptLocal = 0;

  /// Локальных правок уступило серверу (всё — в журнале).
  int lost = 0;

  /// Приём был начат с нуля (эпоха сервера сменилась или база разошлась).
  bool resynced = false;

  /// Неотправленных записей после прогона (вместе с отклонёнными).
  int pendingLeft = 0;

  late DateTime finishedAt;

  /// Что-то изменилось в локальной базе — экранам пора перечитать данные.
  bool get changedLocalData => received > 0 || lost > 0;
}

/// Движок синхронизации: сначала отправляет неотправленное, потом
/// принимает изменения с сервера.
///
/// - `applied`/`duplicate` — запись отмечается отправленной;
/// - `stale` — побеждает сервер: запись остаётся неотправленной, pull
///   принесёт серверную версию и запишет проигрыш в журнал;
/// - `rejected` `unique_conflict` — на сервере уже есть запись на этот день
///   (месяц): побеждает она, локальная мягко удаляется (решение владельца
///   2026-09-27); расчёты ЗП — без журнала, они пересчитываются;
/// - прочие отказы — запись остаётся, в журнал, повторно не уходит, пока её
///   не изменят (или `run(retryRejected: true)`).
///
/// Временные сбои (нет сети, 5xx) повторяются внутри прогона
/// [transientRetries] раз; если не помогло — исключение [SyncFailure], уже
/// сделанное сохранено. Одновременно идёт только один прогон: повторный
/// вызов получает тот же результат.
class SyncEngine {
  final LocalSyncStore store;
  final SyncTransport transport;
  final SyncJournal journal;
  final int pushBatch;
  final int pullLimit;
  final List<Duration> transientRetries;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  Future<SyncReport>? _running;

  SyncEngine({
    required this.store,
    required this.transport,
    SyncJournal? journal,
    this.pushBatch = 500,
    this.pullLimit = 500,
    this.transientRetries = const [Duration(seconds: 2), Duration(seconds: 5)],
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  }) : journal = journal ?? MemorySyncJournal(),
       _sleep = sleep ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  bool get isRunning => _running != null;

  Future<SyncReport> run({bool retryRejected = false}) =>
      _running ??= _run(retryRejected).whenComplete(() => _running = null);

  Future<SyncReport> _run(bool retryRejected) async {
    final report = SyncReport();
    if (retryRejected) await store.clearRejections();
    var resync = await _push(report);
    resync = await _pull(report, resync: resync);
    if (resync) {
      // Разошлись по уникальному ключу во время приёма — ещё раз с нуля.
      await _pull(report, resync: true);
    }
    report.pendingLeft = await store.pendingCount();
    report.finishedAt = _now().toUtc();
    return report;
  }

  // ------------------------------------------------------------- push

  /// Возвращает true, если нужен приём с нуля.
  Future<bool> _push(SyncReport report) async {
    var resync = false;
    final attempted = <String>{};
    while (true) {
      final batch = [
        for (final c in await store.pendingChanges(
          limit: attempted.length + pushBatch,
        ))
          if (!attempted.contains(c.uuid)) c,
      ].take(pushBatch).toList();
      if (batch.isEmpty) return resync;
      attempted.addAll(batch.map((c) => c.uuid));

      final outcomes = await _retrying(
        () => transport.push([for (final c in batch) c.change]),
      );
      final entries = <JournalEntry>[];
      for (var i = 0; i < batch.length; i++) {
        final change = batch[i];
        final outcome = outcomes[i];
        switch (outcome.status) {
          case 'applied':
            report.pushed++;
            await store.markPushed(change);
          case 'duplicate':
            report.duplicates++;
            await store.markPushed(change);
          case 'stale':
            report.stale++;
          case 'rejected' when outcome.code == 'unique_conflict':
            report.lost++;
            if (await store.discardLocal(change)) resync = true;
            if (change.table != 'payroll_results') {
              entries.add(
                JournalEntry(
                  at: _now(),
                  kind: JournalKind.lostUnique,
                  table: change.table,
                  uuid: change.uuid,
                  code: outcome.code,
                  message:
                      '${tableTitle(change.table)}: на сервере уже есть '
                      'запись на этот ${change.table == 'timesheet' ? 'день' : 'месяц'}, '
                      'введённая раньше, — запись с этого устройства снята',
                  local: journalSnapshot(change.change),
                  remote: outcome.conflictUuid == null
                      ? null
                      : {'uuid': outcome.conflictUuid},
                ),
              );
            }
          case 'rejected':
            report.rejected++;
            final message = outcome.message ?? 'Сервер не принял изменение';
            await store.markRejected(change, outcome.code ?? '', message);
            entries.add(
              JournalEntry(
                at: _now(),
                kind: JournalKind.rejected,
                table: change.table,
                uuid: change.uuid,
                code: outcome.code,
                message: '${tableTitle(change.table)}: $message',
                local: journalSnapshot(change.change),
              ),
            );
          default:
            throw ServerFailure('неизвестный итог push: ${outcome.status}');
        }
      }
      await journal.add(entries);
    }
  }

  // ------------------------------------------------------------- pull

  /// Принимает все изменения после курсора. Возвращает true, если после
  /// приёма база могла разойтись с сервером.
  Future<bool> _pull(SyncReport report, {required bool resync}) async {
    if (resync) {
      await _startOver(report, 'Локальные данные разошлись с сервером');
    }
    var cursor = await store.cursor();
    var needsResync = false;
    var restarted = false;
    while (true) {
      final PullPage page;
      try {
        final at = cursor;
        page = await _retrying(() => transport.pull(at, limit: pullLimit));
      } on ApiFailure catch (e) {
        if (e.code != 'resync_required' || restarted) rethrow;
        restarted = true;
        await _startOver(report, e.message);
        cursor = SyncCursor.start;
        continue;
      }
      final next = SyncCursor(page.cursor, page.epoch);
      final applied = await store.applyRemote(page.changes, cursor: next);
      cursor = next;
      report.received += applied.applied;
      report.keptLocal += applied.keptLocal;
      report.lost += applied.lost.length;
      needsResync |= applied.needsResync;
      await journal.add([
        for (final lost in applied.lost)
          if (lost.local.table != 'payroll_results') _lostEntry(lost),
      ]);
      if (!page.hasMore) return needsResync;
    }
  }

  Future<void> _startOver(SyncReport report, String reason) async {
    report.resynced = true;
    await store.resetCursor();
    await journal.add([
      JournalEntry(
        at: _now(),
        kind: JournalKind.resync,
        message: '$reason — данные приняты с сервера заново',
      ),
    ]);
  }

  JournalEntry _lostEntry(LostChange lost) {
    final title = tableTitle(lost.local.table);
    return JournalEntry(
      at: _now(),
      kind: lost.reason == LostReason.overwritten
          ? JournalKind.lost
          : JournalKind.lostUnique,
      table: lost.local.table,
      uuid: lost.local.uuid,
      message: lost.reason == LostReason.overwritten
          ? '$title: правка с этого устройства уступила более поздней '
                'правке с сервера'
          : '$title: на сервере уже есть запись на этот '
                '${lost.local.table == 'timesheet' ? 'день' : 'месяц'}, '
                'введённая раньше, — запись с этого устройства снята',
      local: journalSnapshot(lost.local),
      remote: journalSnapshot(lost.remote),
    );
  }

  // ------------------------------------------------------------- повторы

  Future<T> _retrying<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on SyncFailure catch (e) {
        if (!e.isTransient || attempt >= transientRetries.length) rethrow;
        await _sleep(transientRetries[attempt]);
      }
    }
  }
}
