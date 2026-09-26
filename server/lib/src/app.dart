import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'database.dart';
import 'http/middleware.dart';
import 'http/responses.dart';
import 'logger.dart';
import 'version.dart';

/// Сколько ждать ответа MySQL в `/health`.
const healthDbTimeout = Duration(seconds: 3);

/// Собирает обработчик всех запросов API.
Handler buildHandler({required Database db, required Logger logger}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', (Request request) => _health(request, db, logger));

  return const Pipeline()
      .addMiddleware(requestId())
      .addMiddleware(accessLog(logger))
      .addMiddleware(handleErrors(logger))
      .addHandler(router.call);
}

Response _notFound(Request request) =>
    errorResponse(404, 'not_found', 'Нет такого адреса API');

/// Живость сервера и связь с MySQL. 200 — всё в порядке, 503 — база
/// не отвечает (причина — только в журнал).
Future<Response> _health(Request request, Database db, Logger logger) async {
  var dbOk = true;
  try {
    await db.ping().timeout(healthDbTimeout);
  } catch (e) {
    dbOk = false;
    logger.warning('health: база не отвечает',
        {'request_id': requestIdOf(request), 'error': e.toString()});
  }
  return jsonResponse({
    'status': dbOk ? 'ok' : 'unavailable',
    'version': serverVersion,
    'db': dbOk ? 'ok' : 'error',
  }, status: dbOk ? 200 : 503);
}
