import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'responses.dart';

/// Тело запроса как JSON-объект. Больше [maxBytes] — 413, не JSON или не
/// объект — 400.
Future<Map<String, Object?>> readJsonObject(Request request,
    {int maxBytes = 64 * 1024}) async {
  final declared = request.contentLength;
  if (declared != null && declared > maxBytes) throw _tooLarge(maxBytes);
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxBytes) throw _tooLarge(maxBytes);
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ApiException.badRequest('Тело запроса — не JSON');
  }
  if (json is! Map<String, Object?>) {
    throw const ApiException.badRequest('Тело запроса должно быть объектом JSON');
  }
  return json;
}

ApiException _tooLarge(int maxBytes) => ApiException(413, 'too_large',
    'Слишком большой запрос (больше ${maxBytes ~/ 1024} КБ)');

/// Строковое поле тела: нет или не строка — 400.
String requireString(Map<String, Object?> body, String name) {
  final value = body[name];
  if (value is! String || value.isEmpty) {
    throw ApiException.badRequest('Не заполнено поле $name');
  }
  return value;
}

/// Токен из `Authorization: Bearer …` или null.
String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  final match = RegExp(r'^Bearer\s+(\S+)$', caseSensitive: false)
      .firstMatch(header.trim());
  return match?.group(1);
}

/// Id устройства клиента (`X-Device-Id`): только короткий и без мусора —
/// он попадает в базу и журнал.
String? deviceIdOf(Request request) {
  final id = request.headers['x-device-id']?.trim();
  if (id == null || id.isEmpty) return null;
  return id.length <= 64 && RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(id)
      ? id
      : null;
}

/// Адрес клиента. За прокси (Caddy) настоящий адрес — последний в
/// `X-Forwarded-For` (его дописал наш прокси; начало заголовка клиент
/// может подделать). Доверять заголовку — только если [trustProxy].
String? clientIp(Request request, {required bool trustProxy}) {
  if (trustProxy) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.trim().isNotEmpty) {
      return forwarded.split(',').last.trim();
    }
  }
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : null;
}
