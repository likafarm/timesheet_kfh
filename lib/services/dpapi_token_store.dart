// lib/services/dpapi_token_store.dart
//
// Токены входа на сервер — в файле рядом с базой, зашифрованном DPAPI
// Windows (CryptProtectData) под учётной записью пользователя: другой
// пользователь Windows или другой компьютер файл не расшифрует.
// Отладочная сборка хранит данные в своей папке — её вход отдельный.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:win32/win32.dart';

/// Без окон и подсказок DPAPI.
const _cryptprotectUiForbidden = 0x1;

/// Дополнительный ключ: файл расшифровывает только эта программа.
final _entropy = utf8.encode('kfh-sync-tokens-v1');

Uint8List _dpapi(Uint8List input, {required bool protect}) => using((arena) {
  Pointer<CRYPT_INTEGER_BLOB> blob(List<int> bytes) {
    final data = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    data.asTypedList(bytes.length).setAll(0, bytes);
    return arena<CRYPT_INTEGER_BLOB>()
      ..ref.cbData = bytes.length
      ..ref.pbData = data;
  }

  final inBlob = blob(input);
  final entropy = blob(_entropy);
  final out = arena<CRYPT_INTEGER_BLOB>();
  final result = protect
      ? CryptProtectData(
          inBlob,
          null,
          entropy,
          null,
          _cryptprotectUiForbidden,
          out,
        )
      : CryptUnprotectData(
          inBlob,
          null,
          entropy,
          null,
          _cryptprotectUiForbidden,
          out,
        );
  if (!result.value) {
    throw StateError('DPAPI: ошибка ${result.error}');
  }
  try {
    return Uint8List.fromList(out.ref.pbData.asTypedList(out.ref.cbData));
  } finally {
    LocalFree(HLOCAL(out.ref.pbData));
  }
});

/// Зашифровать для текущего пользователя Windows.
Uint8List dpapiProtect(Uint8List data) => _dpapi(data, protect: true);

/// Расшифровать; ошибка — [StateError].
Uint8List dpapiUnprotect(Uint8List data) => _dpapi(data, protect: false);

/// Токены одного сервера в общем файле `{сервер: токены}`.
class DpapiTokenStore implements TokenStore {
  final File file;
  final String server;

  DpapiTokenStore(this.file, this.server);

  Future<Map<String, Object?>> _readAll() async {
    if (!await file.exists()) return {};
    try {
      final plain = dpapiUnprotect(await file.readAsBytes());
      final json = jsonDecode(utf8.decode(plain));
      return json is Map<String, Object?> ? json : {};
    } on Object {
      // Файл испорчен или зашифрован другим пользователем — как будто
      // входа не было.
      return {};
    }
  }

  Future<void> _writeAll(Map<String, Object?> all) async {
    if (all.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final encrypted = dpapiProtect(utf8.encode(jsonEncode(all)));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(encrypted, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<AuthTokens?> read() async {
    final raw = (await _readAll())[server];
    if (raw is! Map<String, Object?>) return null;
    try {
      return AuthTokens.fromJson(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final all = await _readAll();
    all[server] = tokens.toJson();
    await _writeAll(all);
  }

  @override
  Future<void> clear() async {
    final all = await _readAll();
    if (all.remove(server) != null) await _writeAll(all);
  }
}
