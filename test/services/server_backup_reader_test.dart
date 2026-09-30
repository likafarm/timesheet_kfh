import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/services/server_backup_reader.dart';

/// Выгрузка сервера (test/fixtures/server_snapshot.json.gz.age — вымышленные
/// данные, сжатые и зашифрованные настоящей утилитой age тестовым ключом из
/// packages/sync/test/fixtures/age).
void main() {
  const key = 'packages/sync/test/fixtures/age/key.txt';
  const other = 'packages/sync/test/fixtures/age/other.txt';
  Uint8List fixture() =>
      File('test/fixtures/server_snapshot.json.gz.age').readAsBytesSync();

  test('расшифровка, распаковка и разбор', () async {
    final file = await ServerBackupReader.decode(
      fixture(),
      await ServerBackupReader.loadKey(key),
    );
    expect(file.source, 'server 0.8.0');
    expect(file.createdAt, DateTime.utc(2026, 9, 30, 0, 30));
    final snapshot = file.snapshot;
    expect(
      snapshot.liveRows('employees').single.data['full_name'],
      'Тестов Тест Тестович',
    );
    expect(snapshot.counts['timesheet'], 1);
  });

  test(
    'чужой ключ, нет файла ключа, испорченный файл — понятный отказ',
    () async {
      await expectLater(
        ServerBackupReader.decode(
          fixture(),
          await ServerBackupReader.loadKey(other),
        ),
        throwsA(
          isA<ServerBackupException>().having(
            (e) => e.message,
            'message',
            contains('Ключ не подходит'),
          ),
        ),
      );
      await expectLater(
        ServerBackupReader.loadKey('нет_такого_файла.key'),
        throwsA(
          isA<ServerBackupException>().having(
            (e) => e.message,
            'message',
            contains('Нет файла ключа'),
          ),
        ),
      );
      final broken = fixture();
      broken[broken.length - 5] ^= 1;
      await expectLater(
        ServerBackupReader.decode(
          broken,
          await ServerBackupReader.loadKey(key),
        ),
        throwsA(isA<ServerBackupException>()),
      );
    },
  );
}
