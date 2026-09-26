import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Хэши паролей: Argon2id, строка в формате PHC
/// (`$argon2id$v=19$m=…,t=…,p=1$<соль>$<хэш>`, base64 без `=`).
///
/// Параметры по умолчанию — минимум OWASP (19 МиБ, 2 прохода): ~0,25 с на
/// сервере. Считается в отдельном isolate, чтобы вход не задерживал
/// остальные запросы. Параметры хранятся в строке — их можно поднять, не
/// ломая старые хэши (см. [needsRehash]).
class PasswordHasher {
  final int memoryKiB;
  final int iterations;

  const PasswordHasher({this.memoryKiB = 19456, this.iterations = 2});

  static const minLength = 8;
  static const maxLength = 128;

  /// Причина, по которой пароль не годится, или null.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Пароль должен быть не короче $minLength символов';
    }
    if (password.length > maxLength) {
      return 'Пароль должен быть не длиннее $maxLength символов';
    }
    if (password.trim().isEmpty) return 'Пароль не может состоять из пробелов';
    return null;
  }

  Future<String> hash(String password) {
    final m = memoryKiB, t = iterations;
    return Isolate.run(
        () => PasswordHasher(memoryKiB: m, iterations: t).hashSync(password));
  }

  Future<bool> verify(String password, String encoded) =>
      Isolate.run(() => verifySync(password, encoded));

  String hashSync(String password, {List<int>? salt}) {
    final s = Uint8List.fromList(salt ?? _randomSalt());
    final digest = _derive(password, s, memoryKiB, iterations, 32);
    return '\$argon2id\$v=19\$m=$memoryKiB,t=$iterations,p=1'
        '\$${_b64(s)}\$${_b64(digest)}';
  }

  /// Неверный формат строки — просто `false` (как неверный пароль).
  bool verifySync(String password, String encoded) {
    final parsed = _Phc.tryParse(encoded);
    if (parsed == null) return false;
    final digest = _derive(password, parsed.salt, parsed.memoryKiB,
        parsed.iterations, parsed.hash.length);
    return _constantTimeEquals(digest, parsed.hash);
  }

  /// Хэш сделан со слабее нынешних параметрами — пересчитать при входе.
  bool needsRehash(String encoded) {
    final parsed = _Phc.tryParse(encoded);
    return parsed == null ||
        parsed.memoryKiB < memoryKiB ||
        parsed.iterations < iterations;
  }

  static Uint8List _derive(
      String password, Uint8List salt, int memoryKiB, int iterations, int length) {
    final generator = Argon2BytesGenerator()
      ..init(Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        desiredKeyLength: length,
        iterations: iterations,
        memory: memoryKiB,
        lanes: 1,
        version: Argon2Parameters.ARGON2_VERSION_13,
      ));
    return generator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256));
  }
}

String _b64(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');

Uint8List? _unb64(String s) {
  try {
    return base64.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
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

class _Phc {
  final int memoryKiB;
  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  _Phc(this.memoryKiB, this.iterations, this.salt, this.hash);

  static final _pattern = RegExp(
      r'^\$argon2id\$v=19\$m=(\d{1,7}),t=(\d{1,2}),p=1\$([A-Za-z0-9+/]+)\$([A-Za-z0-9+/]+)$');

  static _Phc? tryParse(String encoded) {
    final m = _pattern.firstMatch(encoded);
    if (m == null) return null;
    final memory = int.parse(m.group(1)!);
    final iterations = int.parse(m.group(2)!);
    final salt = _unb64(m.group(3)!);
    final hash = _unb64(m.group(4)!);
    if (salt == null || hash == null) return null;
    // Защита от строки с непомерными параметрами (отказ в обслуживании).
    if (memory < 8 || memory > 262144 || iterations < 1) return null;
    if (salt.length < 8 || hash.length < 16) return null;
    return _Phc(memory, iterations, salt, hash);
  }
}
