import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Токен не принят: подделан, испорчен или просрочен. Причину клиенту
/// не сообщаем — только «войдите заново».
class InvalidTokenException implements Exception {
  final String reason;
  InvalidTokenException(this.reason);

  @override
  String toString() => 'InvalidTokenException: $reason';
}

/// Данные access-токена.
class AccessClaims {
  final String userUuid;
  final DateTime issuedAt;
  final DateTime expiresAt;

  AccessClaims(this.userUuid, this.issuedAt, this.expiresAt);
}

/// Access-токены — JWT HS256 (RFC 7519) с коротким сроком жизни.
///
/// Библиотека не нужна: формат прост, а проверка здесь строже общей —
/// принимается только ровно наш заголовок (никаких `alg: none` и чужих
/// алгоритмов), подпись сравнивается за постоянное время, срок обязателен.
class AccessTokens {
  static const _header = {'alg': 'HS256', 'typ': 'JWT'};
  static const issuer = 'kfh';

  final Hmac _hmac;
  final Duration lifetime;
  final DateTime Function() _now;

  /// [secret] — не короче 32 байт.
  AccessTokens(List<int> secret,
      {this.lifetime = const Duration(minutes: 15), DateTime Function()? now})
      : _hmac = Hmac(sha256, secret),
        _now = now ?? DateTime.now {
    if (secret.length < 32) {
      throw ArgumentError('Секрет токенов короче 32 байт');
    }
  }

  static final _encodedHeader = _b64(utf8.encode(jsonEncode(_header)));

  ({String token, DateTime expiresAt}) issue(String userUuid) {
    final now = _now().toUtc();
    // Время в токене — целые секунды (NumericDate).
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final exp = iat + lifetime.inSeconds;
    final payload = _b64(utf8.encode(jsonEncode(
        {'iss': issuer, 'sub': userUuid, 'iat': iat, 'exp': exp, 'typ': 'access'})));
    final signingInput = '$_encodedHeader.$payload';
    return (
      token: '$signingInput.${_b64(_sign(signingInput))}',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
    );
  }

  AccessClaims verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw InvalidTokenException('не три части');
    if (parts[0] != _encodedHeader) throw InvalidTokenException('заголовок');
    final signature = _unb64(parts[2]);
    if (signature == null ||
        !_constantTimeEquals(signature, _sign('${parts[0]}.${parts[1]}'))) {
      throw InvalidTokenException('подпись');
    }
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(_unb64(parts[1]) ?? const []));
    } on FormatException {
      throw InvalidTokenException('данные');
    }
    if (payload is! Map ||
        payload['iss'] != issuer ||
        payload['typ'] != 'access' ||
        payload['sub'] is! String ||
        payload['iat'] is! int ||
        payload['exp'] is! int) {
      throw InvalidTokenException('поля');
    }
    final now = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (now >= payload['exp']) throw InvalidTokenException('просрочен');
    return AccessClaims(
      payload['sub'],
      DateTime.fromMillisecondsSinceEpoch(payload['iat'] * 1000, isUtc: true),
      DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000, isUtc: true),
    );
  }

  List<int> _sign(String input) => _hmac.convert(ascii.encode(input)).bytes;
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

List<int>? _unb64(String s) {
  if (!RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(s)) return null;
  try {
    return base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
  } on FormatException {
    return null;
  }
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
