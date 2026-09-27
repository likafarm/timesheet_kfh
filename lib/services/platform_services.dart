// lib/services/platform_services.dart
//
// То, что программа получает от своей платформы при запуске: база,
// резервные копии, хранилище токенов входа, журнал синхронизации.
// Windows и Android — startup_io.dart, браузер — startup_web.dart.

import 'package:kfh_sync/kfh_sync.dart';

import 'app_database.dart';
import 'local_backups.dart';

class PlatformServices {
  final AppDatabase database;

  /// Файловые копии базы; null — их нет (веб-версия).
  final LocalBackups? backups;

  /// Хранилище токенов входа на сервер [server].
  final TokenStore Function(String server) tokenStore;

  final SyncJournal journal;

  /// Стереть данные этой программы на устройстве после выхода с сервера
  /// (базу и журнал); null — не стирать (Windows, Android: база остаётся
  /// рабочей и без входа). База к этому моменту закрыта.
  final Future<void> Function()? eraseLocalData;

  const PlatformServices({
    required this.database,
    required this.backups,
    required this.tokenStore,
    required this.journal,
    this.eraseLocalData,
  });
}
