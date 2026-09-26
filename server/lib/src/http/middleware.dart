import 'dart:math';

import 'package:shelf/shelf.dart';

import '../logger.dart';
import 'responses.dart';

const requestIdHeader = 'x-request-id';
const _requestIdKey = 'kfh.request_id';

final _random = Random.secure();

/// Id запроса из контекста (его ставит [requestId]).
String? requestIdOf(Request request) =>
    request.context[_requestIdKey] as String?;

/// Id запроса: берётся из заголовка `X-Request-Id` (его может поставить
/// прокси), иначе создаётся. Кладётся в контекст и в ответ.
Middleware requestId() => (inner) => (request) async {
      final incoming = request.headers[requestIdHeader];
      final id = incoming != null && _isSafeId(incoming)
          ? incoming
          : List.generate(8, (_) => _random.nextInt(256))
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
      final response =
          await inner(request.change(context: {_requestIdKey: id}));
      return response.change(headers: {requestIdHeader: id});
    };

/// Чужой id пускаем в журнал, только если он короткий и без мусора.
bool _isSafeId(String id) =>
    id.length <= 64 && RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(id);

/// Журнал запросов: метод, путь (без строки запроса — там могут быть
/// лишние данные), статус, длительность.
Middleware accessLog(Logger logger) => (inner) => (request) async {
      final watch = Stopwatch()..start();
      final response = await inner(request);
      logger.info('request', {
        'request_id': requestIdOf(request),
        'method': request.method,
        'path': '/${request.url.path}',
        'status': response.statusCode,
        'ms': watch.elapsedMilliseconds,
      });
      return response;
    };

/// Единая обработка ошибок: [ApiException] уходит клиенту как есть,
/// любая другая ошибка — 500 без подробностей (подробности — в журнал).
Middleware handleErrors(Logger logger) => (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return e.toResponse();
      } catch (e, st) {
        // HijackException и подобные служебные исключения shelf не ловим.
        if (e is HijackException) rethrow;
        logger.error('unhandled',
            error: e,
            stackTrace: st,
            fields: {'request_id': requestIdOf(request)});
        return errorResponse(500, 'internal', 'Внутренняя ошибка сервера');
      }
    };
