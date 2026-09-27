// lib/services/startup_io.dart
//
// Запуск программы для Windows и Android: база в файле (с переносом
// старой базы v8), файловые копии, токены — в файле рядом с базой
// (на Windows — под DPAPI), журнал синхронизации — sync.log там же.

import 'dart:io';

import 'package:kfh_sync/file_journal.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:path/path.dart' as p;

import 'backup_service.dart';
import 'database_files.dart';
import 'db_location.dart';
import 'dpapi_token_store.dart';
import 'file_token_store.dart';
import 'platform.dart';
import 'platform_services.dart';

const startupErrorHint =
    'Программа ничего не изменила в ваших данных. Причина — ниже; '
    'подробности записаны в журнал db_location.log в папке данных '
    'программы. Можно закрыть программу и вернуться к предыдущей версии.';

Future<PlatformServices> startPlatform() async {
  final dataDir = await appDataDirectory();
  final backups = BackupService();
  final database = await openAppDatabase(
    dataDir: dataDir,
    legacyDirs: legacyDatabaseDirectories(),
    backupLegacy: backups.backupLegacyDatabase,
    log: logDbLocation,
  );
  return PlatformServices(
    database: database,
    backups: backups,
    tokenStore: (server) => platformTokenStore(dataDir, server),
    journal: FileSyncJournal(File(p.join(dataDir, 'sync.log'))),
  );
}

/// Хранилище токенов этой платформы в папке [dataDirectory].
TokenStore platformTokenStore(String dataDirectory, String server) =>
    isAndroidApp
    ? FileTokenStore(File(p.join(dataDirectory, 'sync_auth.json')), server)
    : DpapiTokenStore(File(p.join(dataDirectory, 'sync_auth.dat')), server);
