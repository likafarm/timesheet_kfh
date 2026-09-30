import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';

import 'api_client.dart';
import 'failures.dart';

/// Итог одного изменения из пачки push (см. `PushResult` сервера).
class PushOutcome {
  final String? changeId;
  final String? uuid;

  /// `applied` | `duplicate` | `stale` | `rejected`.
  final String status;
  final String? code;
  final String? message;
  final String? conflictUuid;

  const PushOutcome(
    this.status, {
    this.changeId,
    this.uuid,
    this.code,
    this.message,
    this.conflictUuid,
  });

  factory PushOutcome.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['status'] is! String) {
      throw ServerFailure('итог push без status');
    }
    return PushOutcome(
      json['status'] as String,
      changeId: json['change_id'] as String?,
      uuid: json['uuid'] as String?,
      code: json['code'] as String?,
      message: json['message'] as String?,
      conflictUuid: json['conflict_uuid'] as String?,
    );
  }
}

/// Страница pull.
class PullPage {
  final String epoch;
  final int cursor;
  final bool hasMore;
  final List<SyncChange> changes;

  const PullPage(this.epoch, this.cursor, this.hasMore, this.changes);
}

/// Обмен с сервером — отдельно от движка, чтобы движок проверялся на
/// поддельном сервере.
abstract class SyncTransport {
  /// Итоги — в порядке [changes].
  Future<List<PushOutcome>> push(List<SyncChange> changes);

  /// Ошибка `ApiFailure` с кодом `resync_required` — курсор устарел
  /// (сервер восстановлен из копии). [tables] — только эти таблицы
  /// (сервер 0.6.0+; старый отдаёт все — это лишь медленнее).
  Future<PullPage> pull(
    SyncCursor cursor, {
    int limit = 500,
    Set<String>? tables,
  });
}

/// Обмен по HTTP через [KfhApiClient].
class HttpSyncTransport implements SyncTransport {
  final KfhApiClient api;

  HttpSyncTransport(this.api);

  @override
  Future<List<PushOutcome>> push(List<SyncChange> changes) async {
    final json = await api.postJson('/sync/push', {
      'changes': [for (final c in changes) c.toJson()],
    });
    final results = json['results'];
    if (results is! List || results.length != changes.length) {
      throw ServerFailure('push вернул не столько итогов, сколько изменений');
    }
    return [for (final r in results) PushOutcome.fromJson(r)];
  }

  @override
  Future<PullPage> pull(
    SyncCursor cursor, {
    int limit = 500,
    Set<String>? tables,
  }) async {
    final json = await api.getJson(
      '/sync/pull',
      query: {
        'cursor': '${cursor.seq}',
        'epoch': ?cursor.epoch,
        'limit': '$limit',
        if (tables != null) 'tables': tables.join(','),
      },
    );
    final epoch = json['epoch'], next = json['cursor'];
    final hasMore = json['has_more'], changes = json['changes'];
    if (epoch is! String ||
        next is! int ||
        hasMore is! bool ||
        changes is! List) {
      throw ServerFailure('pull вернул неполный ответ');
    }
    try {
      return PullPage(epoch, next, hasMore, [
        for (final c in changes) SyncChange.fromJson(c),
      ]);
    } on SyncFormatException catch (e) {
      throw ServerFailure('pull: ${e.message}');
    }
  }
}
