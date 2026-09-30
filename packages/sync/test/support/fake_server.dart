import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';

/// Сервер синхронизации в памяти — те же правила, что у `SyncService`
/// (server/lib/src/sync/sync_service.dart): LWW по `updated_at`, повтор =
/// `duplicate`, уникальные ключи среди живых записей, закрытые месяцы,
/// журнал изменений с эпохой.
///
/// Сквозная проверка с настоящим сервером — server/test/client_sync_test.dart.
class FakeSyncServer {
  final _rows = <(String, String), SyncChange>{};
  final _log = <(int, String, String)>[];
  var _seq = 0;
  var epoch = 'epoch-1';

  /// Закрытые месяцы: год * 100 + месяц.
  final lockedMonths = <int>{};

  /// Таблицы, которые запрещено менять (как для роли без прав).
  final forbiddenTables = <String>{};

  /// Сети нет: каждый запрос — [NetworkFailure].
  bool offline = false;

  /// Следующие N запросов — ошибка сети.
  int failNext = 0;

  /// Следующий push применяется, но ответ теряется (обрыв связи).
  bool loseNextPushResponse = false;

  int pushCalls = 0;
  int pullCalls = 0;

  /// Клиент устройства; [deviceId] — как заголовок `X-Device-Id` (id
  /// устройства из локальной базы).
  SyncTransport client(Future<String> Function() deviceId) =>
      _Client(this, deviceId);

  // ------------------------------------------------------------- состояние

  List<SyncChange> rows(String table, {bool live = true}) => [
    for (final r in _rows.values)
      if (r.table == table && (!live || !r.deleted)) r,
  ];

  SyncChange? row(String table, String uuid) => _rows[(table, uuid)];

  /// Правка «от другого клиента» прямо на сервере.
  void put(SyncChange change) {
    _rows[(change.table, change.uuid)] = change;
    _log.add((++_seq, change.table, change.uuid));
  }

  /// Сервер восстановлен из копии: новая эпоха, журнал «с нуля».
  void restoreFromBackup() {
    epoch = 'epoch-${_seq + 1000}';
    _log
      ..clear()
      ..addAll([for (final r in _rows.values) (++_seq, r.table, r.uuid)]);
  }

  void _checkNetwork() {
    if (offline) throw NetworkFailure('offline');
    if (failNext > 0) {
      failNext--;
      throw NetworkFailure('обрыв');
    }
  }

  // ------------------------------------------------------------- push

  List<PushOutcome> push(String deviceId, List<SyncChange> changes) {
    pushCalls++;
    _checkNetwork();
    final results = List<PushOutcome?>.filled(changes.length, null);
    final order = [for (var i = 0; i < changes.length; i++) i]
      ..sort((a, b) {
        final t = syncTableOrder(
          changes[a].table,
        ).compareTo(syncTableOrder(changes[b].table));
        return t != 0 ? t : a.compareTo(b);
      });
    for (final i in order) {
      // Как по сети: разбор и проверка формата.
      final change = SyncChange.fromJson(changes[i].toJson());
      results[i] = _applyOne(deviceId, change);
    }
    if (loseNextPushResponse) {
      loseNextPushResponse = false;
      throw NetworkFailure('ответ потерян');
    }
    return results.cast<PushOutcome>();
  }

  PushOutcome _applyOne(String deviceId, SyncChange c) {
    PushOutcome result(String status, {String? code, String? conflict}) =>
        PushOutcome(
          status,
          changeId: c.changeId,
          uuid: c.uuid,
          code: code,
          conflictUuid: conflict,
        );

    if (forbiddenTables.contains(c.table)) {
      return result('rejected', code: 'forbidden');
    }
    final existing = _rows[(c.table, c.uuid)];
    if (existing != null && !c.updatedAt.isAfter(existing.updatedAt)) {
      final same =
          c.updatedAt == existing.updatedAt &&
          c.deleted == existing.deleted &&
          c.data.keys.every((k) => c.data[k] == existing.data[k]);
      return result(same ? 'duplicate' : 'stale');
    }
    for (final version in [?existing, c]) {
      final month = _month(version);
      if (month != null && lockedMonths.contains(month)) {
        return result('rejected', code: 'period_locked');
      }
    }
    final employee = c.data['employee_uuid'];
    if (employee != null && _rows[('employees', employee)] == null) {
      return result('rejected', code: 'unknown_employee');
    }
    final key = uniqueKeys[c.table];
    if (key != null && !c.deleted) {
      for (final other in rows(c.table)) {
        if (other.uuid != c.uuid &&
            key.every((k) => other.data[k] == c.data[k])) {
          return result(
            'rejected',
            code: 'unique_conflict',
            conflict: other.uuid,
          );
        }
      }
    }
    put(
      SyncChange(
        table: c.table,
        uuid: c.uuid,
        updatedAt: c.updatedAt,
        deleted: c.deleted,
        data: c.data,
        editedBy: deviceId,
      ),
    );
    return result('applied');
  }

  static int? _month(SyncChange c) {
    final day = switch (c.table) {
      'timesheet' => c.data['date'],
      'payments' => c.data['payment_date'],
      _ => null,
    };
    if (day is String) {
      final d = parseDateIso(day);
      return d.year * 100 + d.month;
    }
    if (c.table == 'payroll_results') {
      return (c.data['year'] as int) * 100 + (c.data['month'] as int);
    }
    return null;
  }

  // ------------------------------------------------------------- pull

  PullPage pull(SyncCursor cursor, int limit, [Set<String>? tables]) {
    pullCalls++;
    _checkNetwork();
    final maxSeq = _log.isEmpty ? 0 : _log.last.$1;
    if (cursor.seq > 0 && (cursor.epoch != epoch || cursor.seq > maxSeq)) {
      throw ApiFailure(409, 'resync_required', 'Данные сервера восстановлены');
    }
    final entries = _log.where((e) => e.$1 > cursor.seq).take(limit).toList();
    final lastSeq = <(String, String), int>{
      for (final e in entries)
        if (tables == null || tables.contains(e.$2)) (e.$2, e.$3): e.$1,
    };
    final keys = lastSeq.keys.toList()
      ..sort((a, b) {
        final t = syncTableOrder(a.$1).compareTo(syncTableOrder(b.$1));
        return t != 0 ? t : lastSeq[a]!.compareTo(lastSeq[b]!);
      });
    return PullPage(
      epoch,
      entries.isEmpty ? cursor.seq : entries.last.$1,
      entries.length == limit,
      [for (final k in keys) _rows[k]!],
    );
  }
}

class _Client implements SyncTransport {
  final FakeSyncServer server;
  final Future<String> Function() deviceId;

  _Client(this.server, this.deviceId);

  @override
  Future<List<PushOutcome>> push(List<SyncChange> changes) async =>
      server.push(await deviceId(), changes);

  @override
  Future<PullPage> pull(
    SyncCursor cursor, {
    int limit = 500,
    Set<String>? tables,
  }) async => server.pull(cursor, limit, tables);
}
