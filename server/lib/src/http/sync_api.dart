import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../sync/sync_service.dart';
import 'auth_api.dart';
import 'middleware.dart';
import 'request_utils.dart';
import 'responses.dart';

/// Синхронизация.
///
/// - `POST /sync/push` `{changes: [SyncChange…]}` (до 500, заголовок
///   `X-Device-Id` обязателен) → `{results: [{change_id, uuid, status,
///   code?, message?, conflict_uuid?}]}` в порядке запроса;
/// - `GET /sync/pull?cursor=&epoch=&limit=` → `{epoch, cursor, has_more,
///   changes}`. Первый раз — `cursor=0` без эпохи.
class SyncApi {
  final SyncService sync;
  final AuthApi auth;

  SyncApi(this.sync, this.auth);

  void addRoutes(Router router) {
    router
      ..post('/sync/push', _push)
      ..get('/sync/pull', _pull);
  }

  Future<Response> _push(Request request) async {
    final user = await auth.requireUser(request);
    final deviceId = deviceIdOf(request);
    if (deviceId == null) {
      throw const ApiException(400, 'device_id_required',
          'Нужен заголовок X-Device-Id (латиница, цифры, до 64 символов)');
    }
    // 500 записей по ~1 КБ с запасом.
    final body = await readJsonObject(request, maxBytes: 2 * 1024 * 1024);
    final changes = body['changes'];
    if (changes is! List<Object?>) {
      throw const ApiException.badRequest('Нужно поле changes — список');
    }
    final results = await sync.push(user, deviceId, changes,
        requestId: requestIdOf(request));
    return jsonResponse({'results': [for (final r in results) r.toJson()]});
  }

  Future<Response> _pull(Request request) async {
    final user = await auth.requireUser(request);
    final query = request.url.queryParameters;
    int intParam(String name, int defaultValue) {
      final raw = query[name];
      if (raw == null || raw.isEmpty) return defaultValue;
      return int.tryParse(raw) ??
          (throw ApiException.badRequest('$name — целое число'));
    }

    final result = await sync.pull(user,
        cursor: intParam('cursor', 0),
        epoch: query['epoch'],
        limit: intParam('limit', 500));
    return jsonResponse(result.toJson());
  }
}
