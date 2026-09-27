import 'dart:convert';

import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// Ответ JSON с данными.
Response jsonResponse(Object? body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

/// Ошибка API, которую клиент должен увидеть как есть: код для программы
/// и сообщение для человека (по-русски).
///
/// Тело ответа: `{"error": {"code": "...", "message": "..."}}`.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiException(this.status, this.code, this.message);

  const ApiException.notFound([String message = 'Не найдено'])
      : this(404, 'not_found', message);

  const ApiException.badRequest(String message)
      : this(400, 'bad_request', message);

  Response toResponse() => errorResponse(status, code, message);

  @override
  String toString() => 'ApiException($status, $code): $message';
}

Response errorResponse(int status, String code, String message) =>
    jsonResponse({
      'error': {'code': code, 'message': message},
    }, status: status);
