// Расшифровка файлов age (https://age-encryption.org/v1) закрытым ключом
// X25519 — для модуля «Резервные копии»: сервер отдаёт ежедневные выгрузки
// зашифрованными, а ключ есть только на ПК владельца.
//
// Только расшифровка и только получатель X25519 (ключ `AGE-SECRET-KEY-1…`):
// так шифрует `backup.sh`. Формат файла:
//
//   age-encryption.org/v1
//   -> X25519 <разовый открытый ключ>
//   <ключ файла, зашифрованный общим секретом>
//   --- <HMAC заголовка>
//   <16 байт соли><данные блоками по 64 КиБ, ChaCha20-Poly1305>

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Файл не расшифрован: не тот ключ, файл повреждён или не age.
class AgeException implements Exception {
  final String message;
  const AgeException(this.message);

  @override
  String toString() => message;
}

/// Закрытый ключ age (X25519).
class AgeIdentity {
  final Uint8List _secret;

  AgeIdentity._(this._secret);

  /// Ключ из текста файла ключа (`age-keygen`): строка `AGE-SECRET-KEY-1…`,
  /// строки с `#` и пустые пропускаются.
  factory AgeIdentity.parse(String keyFile) {
    for (final raw in const LineSplitter().convert(keyFile)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (!line.toUpperCase().startsWith('AGE-SECRET-KEY-1')) {
        throw const AgeException('В файле ключа нет ключа age');
      }
      final (hrp, data) = _bech32Decode(line);
      if (hrp != 'age-secret-key-' || data.length != 32) {
        throw const AgeException('Ключ age повреждён');
      }
      return AgeIdentity._(data);
    }
    throw const AgeException('В файле ключа нет ключа age');
  }
}

const _chunkSize = 64 * 1024;
const _tagSize = 16;

/// Расшифровывает файл age [file] ключом [identity].
Future<Uint8List> ageDecrypt(Uint8List file, AgeIdentity identity) async {
  final header = _Header.parse(file);
  final fileKey = await _unwrapFileKey(header, identity);

  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final macKey = await hkdf.deriveKey(
    secretKey: SecretKey(fileKey),
    nonce: const [],
    info: utf8.encode('header'),
  );
  final mac = await Hmac.sha256().calculateMac(
    header.macInput,
    secretKey: macKey,
  );
  if (!_equal(mac.bytes, header.mac)) {
    throw const AgeException('Файл копии повреждён (заголовок не сходится)');
  }

  final payload = Uint8List.sublistView(file, header.payloadStart);
  if (payload.length < 16 + _tagSize) {
    throw const AgeException('Файл копии оборван');
  }
  final payloadKey = await hkdf.deriveKey(
    secretKey: SecretKey(fileKey),
    nonce: Uint8List.sublistView(payload, 0, 16),
    info: utf8.encode('payload'),
  );

  final cipher = Chacha20.poly1305Aead();
  final out = BytesBuilder(copy: false);
  final body = Uint8List.sublistView(payload, 16);
  const step = _chunkSize + _tagSize;
  for (var offset = 0, counter = 0; offset < body.length; counter++) {
    final end = offset + step < body.length ? offset + step : body.length;
    final last = end == body.length;
    if (end - offset < _tagSize || (end - offset == _tagSize && counter > 0)) {
      throw const AgeException('Файл копии оборван');
    }
    // Номер блока (11 байт, старшие вперёд) и признак последнего блока.
    final nonce = Uint8List(12);
    for (var i = 10, n = counter; i >= 0 && n > 0; i--, n >>= 8) {
      nonce[i] = n & 0xff;
    }
    nonce[11] = last ? 1 : 0;
    try {
      out.add(
        await cipher.decrypt(
          SecretBox(
            Uint8List.sublistView(body, offset, end - _tagSize),
            nonce: nonce,
            mac: Mac(Uint8List.sublistView(body, end - _tagSize, end)),
          ),
          secretKey: payloadKey,
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const AgeException('Файл копии повреждён или оборван');
    }
    offset = end;
  }
  return out.takeBytes();
}

Future<List<int>> _unwrapFileKey(_Header header, AgeIdentity identity) async {
  final x25519 = X25519();
  final keyPair = await x25519.newKeyPairFromSeed(identity._secret);
  final public = (await keyPair.extractPublicKey()).bytes;
  final cipher = Chacha20.poly1305Aead();
  for (final stanza in header.recipients) {
    if (stanza.share.length != 32 || stanza.body.length != 16 + _tagSize) {
      continue;
    }
    final shared = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(stanza.share, type: KeyPairType.x25519),
    );
    final wrapKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: [...stanza.share, ...public],
      info: utf8.encode('age-encryption.org/v1/X25519'),
    );
    try {
      return await cipher.decrypt(
        SecretBox(
          stanza.body.sublist(0, 16),
          nonce: Uint8List(12),
          mac: Mac(stanza.body.sublist(16)),
        ),
        secretKey: wrapKey,
      );
    } on SecretBoxAuthenticationError {
      // Зашифровано для другого получателя — пробуем следующего.
    }
  }
  throw const AgeException(
    'Ключ не подходит: копия зашифрована для другого ключа',
  );
}

class _Stanza {
  final List<int> share;
  final List<int> body;

  const _Stanza(this.share, this.body);
}

class _Header {
  final List<_Stanza> recipients;
  final List<int> mac;

  /// Заголовок до `---` включительно — по нему считается HMAC.
  final List<int> macInput;

  /// С какого байта файла начинаются зашифрованные данные.
  final int payloadStart;

  const _Header(this.recipients, this.mac, this.macInput, this.payloadStart);

  static const _notAge = AgeException('Файл — не копия, зашифрованная age');

  factory _Header.parse(Uint8List file) {
    var pos = 0;
    String? line() {
      final end = file.indexOf(0x0a, pos);
      if (end < 0 || end - pos > 4096) return null;
      final text = latin1.decode(Uint8List.sublistView(file, pos, end));
      pos = end + 1;
      return text;
    }

    if (line() != 'age-encryption.org/v1') throw _notAge;
    final recipients = <_Stanza>[];
    var current = line();
    while (current != null && current.startsWith('-> ')) {
      final args = current.substring(3).split(' ');
      final body = StringBuffer();
      // Тело — строки base64 по 64 знака; последняя короче (бывает пустой).
      String? part;
      do {
        part = line();
        if (part == null) throw _notAge;
        body.write(part);
      } while (part.length == 64);
      if (args.length == 2 && args[0] == 'X25519') {
        recipients.add(_Stanza(_base64(args[1]), _base64(body.toString())));
      }
      current = line();
    }
    if (current == null || !current.startsWith('--- ')) throw _notAge;
    // Начало строки `--- <mac>`: pos уже за её переводом строки.
    final macLineStart = pos - current.length - 1;
    return _Header(
      recipients,
      _base64(current.substring(4)),
      Uint8List.sublistView(file, 0, macLineStart + 3),
      pos,
    );
  }

  static List<int> _base64(String text) {
    try {
      return base64.decode(base64.normalize(text));
    } on FormatException {
      throw _notAge;
    }
  }
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

const _bech32Alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

/// Разбор bech32 (BIP-173): (префикс, данные). Ошибка — [AgeException].
(String, Uint8List) _bech32Decode(String text) {
  const broken = AgeException('Ключ age повреждён');
  final s = text.toLowerCase();
  final split = s.lastIndexOf('1');
  if (split < 1 || s.length - split - 1 < 6) throw broken;
  final hrp = s.substring(0, split);
  final values = <int>[];
  for (final unit in s.substring(split + 1).codeUnits) {
    final v = _bech32Alphabet.indexOf(String.fromCharCode(unit));
    if (v < 0) throw broken;
    values.add(v);
  }
  var check = 1;
  void feed(int v) {
    const generators = [
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    final top = check >> 25;
    check = ((check & 0x1ffffff) << 5) ^ v;
    for (var i = 0; i < 5; i++) {
      if ((top >> i) & 1 == 1) check ^= generators[i];
    }
  }

  for (final c in hrp.codeUnits) {
    feed(c >> 5);
  }
  feed(0);
  for (final c in hrp.codeUnits) {
    feed(c & 31);
  }
  values.forEach(feed);
  if (check != 1) throw broken;

  // Пятёрки бит → байты; хвост из нулевых бит отбрасывается.
  final out = BytesBuilder();
  var acc = 0, bits = 0;
  for (final v in values.sublist(0, values.length - 6)) {
    acc = (acc << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.addByte((acc >> bits) & 0xff);
    }
  }
  if (bits >= 5 || (acc & ((1 << bits) - 1)) != 0) throw broken;
  return (hrp, out.takeBytes());
}
