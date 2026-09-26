import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kfh_server/src/auth/access_token.dart';
import 'package:test/test.dart';

void main() {
  final secret = utf8.encode('0123456789abcdef0123456789abcdef');
  var now = DateTime.utc(2026, 9, 26, 10, 0, 0);
  late AccessTokens tokens;

  setUp(() {
    now = DateTime.utc(2026, 9, 26, 10, 0, 0);
    tokens = AccessTokens(secret, now: () => now);
  });

  String b64(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  String signed(String header, String payload, [List<int>? key]) {
    final sig = Hmac(sha256, key ?? secret)
        .convert(ascii.encode('$header.$payload'))
        .bytes;
    return '$header.$payload.${base64Url.encode(sig).replaceAll('=', '')}';
  }

  test('выданный токен проверяется, срок 15 минут', () {
    final issued = tokens.issue('user-1');
    expect(issued.expiresAt, DateTime.utc(2026, 9, 26, 10, 15));
    final claims = tokens.verify(issued.token);
    expect(claims.userUuid, 'user-1');
    expect(claims.issuedAt, now);
  });

  test('совместим с обычным JWT HS256 (проверка вручную)', () {
    final token = tokens.issue('user-1').token;
    final parts = token.split('.');
    expect(jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0])))),
        {'alg': 'HS256', 'typ': 'JWT'});
    expect(signed(parts[0], parts[1]), token);
  });

  test('просроченный — отказ', () {
    final token = tokens.issue('user-1').token;
    now = now.add(const Duration(minutes: 15));
    expect(() => tokens.verify(token), throwsA(isA<InvalidTokenException>()));
  });

  test('подпись чужим ключом — отказ', () {
    final other = AccessTokens(utf8.encode('x' * 32), now: () => now);
    expect(() => tokens.verify(other.issue('user-1').token),
        throwsA(isA<InvalidTokenException>()));
  });

  test('изменённые данные — отказ', () {
    final parts = tokens.issue('user-1').token.split('.');
    final forged = b64({
      'iss': 'kfh', 'sub': 'admin', 'typ': 'access',
      'iat': 1790000000, 'exp': 1990000000,
    });
    expect(() => tokens.verify('${parts[0]}.$forged.${parts[2]}'),
        throwsA(isA<InvalidTokenException>()));
  });

  test('alg: none и чужие алгоритмы — отказ', () {
    final payload = b64({
      'iss': 'kfh', 'sub': 'u', 'typ': 'access',
      'iat': 1790000000, 'exp': 1990000000,
    });
    for (final header in [
      b64({'alg': 'none', 'typ': 'JWT'}),
      b64({'alg': 'HS512', 'typ': 'JWT'}),
      b64({'typ': 'JWT', 'alg': 'HS256'}), // тот же смысл, другая запись
    ]) {
      expect(() => tokens.verify('$header.$payload.'),
          throwsA(isA<InvalidTokenException>()));
      expect(() => tokens.verify(signed(header, payload)),
          throwsA(isA<InvalidTokenException>()));
    }
  });

  test('правильно подписан, но без нужных полей — отказ', () {
    final header = b64({'alg': 'HS256', 'typ': 'JWT'});
    for (final payload in [
      {'iss': 'kfh', 'sub': 'u', 'typ': 'access', 'iat': 1},
      {'iss': 'kfh', 'sub': 'u', 'typ': 'refresh', 'iat': 1, 'exp': 1990000000},
      {'iss': 'other', 'sub': 'u', 'typ': 'access', 'iat': 1, 'exp': 1990000000},
      {'iss': 'kfh', 'sub': 5, 'typ': 'access', 'iat': 1, 'exp': 1990000000},
    ]) {
      expect(() => tokens.verify(signed(header, b64(payload))),
          throwsA(isA<InvalidTokenException>()), reason: '$payload');
    }
  });

  test('мусор — отказ, а не падение', () {
    for (final bad in ['', 'a.b', 'a.b.c.d', '...', 'ЁЁ.ЖЖ.ЗЗ', 'a+/.b.c']) {
      expect(() => tokens.verify(bad), throwsA(isA<InvalidTokenException>()),
          reason: bad);
    }
  });

  test('короткий секрет не принимается', () {
    expect(() => AccessTokens(utf8.encode('short')), throwsArgumentError);
  });
}
