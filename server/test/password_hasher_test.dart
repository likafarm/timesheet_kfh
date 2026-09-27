import 'dart:convert';

import 'package:kfh_server/src/auth/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  // Лёгкие параметры, чтобы тесты шли быстро.
  const fast = PasswordHasher(memoryKiB: 1024, iterations: 1);

  test('совпадает с эталонной утилитой argon2 (параметры по умолчанию)', () {
    // echo -n 'password' | argon2 somesalt123456 -id -t 2 -k 19456 -p 1 -l 32 -e
    const reference = r'$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQxMjM0NTY$'
        'XlLhYy891g+T16mYEZ+SMBUYHzIIOD15rQ9B8kJy8C0';
    expect(
        const PasswordHasher()
            .hashSync('password', salt: utf8.encode('somesalt123456')),
        reference);
    expect(const PasswordHasher().verifySync('password', reference), isTrue);
    expect(const PasswordHasher().verifySync('Password', reference), isFalse);
  });

  test('совпадает с эталоном на других параметрах и на UTF-8', () {
    // printf '<пароль>' | argon2 0123456789abcdef -id -t 1 -k 1024 -p 1 -l 32 -e
    final salt = utf8.encode('0123456789abcdef');
    const prefix = r'$argon2id$v=19$m=1024,t=1,p=1$MDEyMzQ1Njc4OWFiY2RlZg$';
    expect(fast.hashSync('password', salt: salt),
        '${prefix}k/CHwIHWN/DMFIpEWqAKaG0QDKyrb3t8OfGqTiLnC3E');
    expect(fast.hashSync('Пароль 🌾', salt: salt),
        '${prefix}OPDHZOel/bv/UYcgxenEuu+V9zD1IuMm786Mox/NYFM');
  });

  test('соль случайная, хэши одного пароля различаются', () {
    final a = fast.hashSync('секрет-пароль');
    final b = fast.hashSync('секрет-пароль');
    expect(a, isNot(b));
    expect(fast.verifySync('секрет-пароль', a), isTrue);
    expect(fast.verifySync('секрет-пароль', b), isTrue);
    expect(fast.verifySync('секрет-парол', a), isFalse);
  });

  test('кириллица и эмодзи', () {
    final h = fast.hashSync('Пароль 🌾 поле');
    expect(fast.verifySync('Пароль 🌾 поле', h), isTrue);
    expect(fast.verifySync('пароль 🌾 поле', h), isFalse);
  });

  test('проверка в isolate', () async {
    final h = await fast.hash('через-isolate');
    expect(await fast.verify('через-isolate', h), isTrue);
    expect(await fast.verify('не-тот', h), isFalse);
  });

  test('испорченная или чужая строка — просто неверный пароль', () {
    for (final bad in [
      '',
      'plain',
      r'$2b$12$abcdefghijklmnopqrstuv', // bcrypt
      r'$argon2i$v=19$m=1024,t=1,p=1$c2FsdHNhbHQ$aGFzaGhhc2hoYXNoaGFzaA',
      r'$argon2id$v=19$m=99999999,t=1,p=1$c2FsdHNhbHQ$aGFzaGhhc2hoYXNoaGFzaA',
      r'$argon2id$v=19$m=1024,t=1,p=4$c2FsdHNhbHQ$aGFzaGhhc2hoYXNoaGFzaA',
    ]) {
      expect(fast.verifySync('x', bad), isFalse, reason: bad);
    }
  });

  test('needsRehash: слабые параметры — да, текущие — нет', () {
    final weak = fast.hashSync('password');
    expect(const PasswordHasher().needsRehash(weak), isTrue);
    expect(fast.needsRehash(weak), isFalse);
    expect(fast.needsRehash('мусор'), isTrue);
  });

  test('требования к паролю', () {
    expect(PasswordHasher.validate('1234567'), isNotNull);
    expect(PasswordHasher.validate('12345678'), isNull);
    expect(PasswordHasher.validate(' ' * 10), isNotNull);
    expect(PasswordHasher.validate('a' * 129), isNotNull);
  });
}
