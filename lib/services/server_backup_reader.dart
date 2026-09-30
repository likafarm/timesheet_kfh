// lib/services/server_backup_reader.dart
//
// Копии сервера для модуля «Резервные копии» (шаг 3 «Дальнейших работ»):
// сервер отдаёт ежедневную выгрузку зашифрованной (age), ключ есть только
// на ПК владельца — здесь файл расшифровывается, распаковывается и
// разбирается в снимок данных.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';

/// Ключ не найден, не подходит или файл копии испорчен — текст для человека.
class ServerBackupException implements Exception {
  final String message;
  const ServerBackupException(this.message);

  @override
  String toString() => message;
}

class ServerBackupReader {
  ServerBackupReader._();

  /// Где лежит ключ владельца: `%USERPROFILE%\.kfh\backup_age.key`.
  static String? defaultKeyPath() {
    final home = Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return null;
    return '$home${Platform.pathSeparator}.kfh'
        '${Platform.pathSeparator}backup_age.key';
  }

  /// Ключ из файла [path]. Файла нет или в нём не ключ —
  /// [ServerBackupException].
  static Future<AgeIdentity> loadKey(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ServerBackupException('Нет файла ключа: $path');
    }
    try {
      return AgeIdentity.parse(await file.readAsString());
    } on AgeException catch (e) {
      throw ServerBackupException('$e ($path)');
    } on FileSystemException catch (e) {
      throw ServerBackupException('Файл ключа не читается: ${e.message}');
    }
  }

  /// Расшифровать, распаковать и разобрать выгрузку сервера.
  static Future<SnapshotFile> decode(
    Uint8List encrypted,
    AgeIdentity key,
  ) async {
    final Uint8List packed;
    try {
      packed = await ageDecrypt(encrypted, key);
    } on AgeException catch (e) {
      throw ServerBackupException(e.message);
    }
    try {
      final text = utf8.decode(const GZipDecoder().decodeBytes(packed));
      return SnapshotFile.fromJson(jsonDecode(text));
    } on SyncFormatException catch (e) {
      throw ServerBackupException('Копия сервера не читается: ${e.message}');
    } on FormatException catch (e) {
      // И испорченный JSON, и испорченный gzip (ArchiveException).
      throw ServerBackupException('Копия сервера повреждена: ${e.message}');
    }
  }
}
