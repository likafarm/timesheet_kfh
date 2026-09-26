import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late BackupService service;
  late LocalDatabase db;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_service_test');
    service = BackupService(backupDirectory: p.join(root.path, 'backups'));
    db = LocalDatabase.file(File(p.join(root.path, 'v2.db')));
    await DriftRepositories(db).employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2025, 1, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('ежедневная копия открытой базы — полная и читаемая', () async {
    final path = await service.createBackup(db);
    expect(path, isNotNull);
    expect(p.basename(path!), startsWith('daily_'));
    expect(File('$path.tmp').existsSync(), isFalse);

    final rows = await service.getBackupTableData(path, 'employees');
    expect(rows.single['full_name'], 'Иванов Иван');
    expect(await service.getBackupTableNames(path), contains('sync_state'));
  });

  test('повторная ежедневная копия перезаписывает, месячная — нет', () async {
    final daily = (await service.createBackup(db))!;
    final monthly = (await service.createBackup(db, type: BackupType.monthly))!;
    final monthlyBytes = File(monthly).readAsBytesSync();

    await DriftRepositories(db).employees.add(
      Employee(
        fullName: 'Петров Пётр',
        position: 'Рабочий',
        hireDate: DateTime(2025, 1, 1),
        baseRate: 0,
        fieldRate: 0,
      ),
    );
    await service.createBackup(db);
    await service.createBackup(db, type: BackupType.monthly);

    expect(await service.getBackupTableData(daily, 'employees'), hasLength(2));
    expect(File(monthly).readAsBytesSync(), monthlyBytes);
  });

  test('копия старой базы перед переносом', () async {
    final v8 = File(p.join(root.path, 'kfx_time_tracking.db'))
      ..writeAsStringSync('старая база');
    final copy = await service.backupLegacyDatabase(v8.path);
    expect(p.basename(copy), startsWith('backup_v8_'));
    expect(File(copy).readAsStringSync(), 'старая база');
    final listed = await service.getBackups();
    expect(listed.single.type, BackupType.legacy);
  });
}
