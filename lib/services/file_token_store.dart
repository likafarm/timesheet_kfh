// lib/services/file_token_store.dart
//
// Токены входа на сервер — в файле `{сервер: токены}` в папке данных
// программы. На Windows файл шифруется DPAPI ([DpapiTokenStore]); на
// Android — личная папка программы: другим программам она недоступна, в
// резервную копию Android не попадает (`allowBackup=false`).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kfh_sync/kfh_sync.dart';
import 'package:path/path.dart' as p;

import 'dpapi_token_store.dart';
import 'platform.dart';

/// Токены одного сервера в общем файле.
class FileTokenStore implements TokenStore {
  final File file;
  final String server;

  /// Шифрование содержимого файла (по умолчанию — без шифрования).
  final Uint8List Function(Uint8List plain) protect;

  /// Расшифровка; ошибка — файл считается пустым.
  final Uint8List Function(Uint8List data) unprotect;

  FileTokenStore(
    this.file,
    this.server, {
    this.protect = _same,
    this.unprotect = _same,
  });

  static Uint8List _same(Uint8List data) => data;

  Future<Map<String, Object?>> _readAll() async {
    if (!await file.exists()) return {};
    try {
      final plain = unprotect(await file.readAsBytes());
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
    final data = protect(utf8.encode(jsonEncode(all)));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(data, flush: true);
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

/// Хранилище токенов этой платформы в папке [dataDirectory].
TokenStore platformTokenStore(String dataDirectory, String server) =>
    isAndroidApp
    ? FileTokenStore(File(p.join(dataDirectory, 'sync_auth.json')), server)
    : DpapiTokenStore(File(p.join(dataDirectory, 'sync_auth.dat')), server);
