// lib/services/startup_web.dart
//
// Запуск веб-версии (этап 5): база drift WASM в хранилище браузера (OPFS или
// IndexedDB), без файловых копий; токены и журнал — в хранилище браузера.

import 'package:kfh_local_db/web.dart';

import 'app_database.dart';
import 'browser_storage.dart';
import 'platform_services.dart';
import 'web_string_storage.dart';

const startupErrorHint =
    'Данные на сервере не затронуты. Причина — ниже. Попробуйте обновить '
    'страницу; если не поможет — откройте программу в Chrome, Edge или '
    'Яндекс Браузере не в режиме инкогнито.';

/// Имя базы в хранилище браузера.
const webDatabaseName = 'kfh_time_tracking';

// Файлы из web/ строго под версии sqlite3 и drift приложения
// (tool/web_assets.ps1). Относительно адреса страницы (/app/).
final _sqlite3Uri = Uri.parse('sqlite3.wasm');
final _driftWorkerUri = Uri.parse('drift_worker.js');

/// Запомнить следующий вход после закрытия вкладки (нет отметки
/// «Чужой компьютер»).
bool rememberNextSignIn = true;

Future<PlatformServices> startPlatform() async {
  final WebDatabase opened;
  try {
    opened = await openWebDatabase(
      name: webDatabaseName,
      sqlite3Uri: _sqlite3Uri,
      driftWorkerUri: _driftWorkerUri,
    );
  } on WebStorageUnavailable catch (e) {
    throw DatabaseOpenException('$e');
  } catch (e) {
    throw DatabaseOpenException('Не удалось открыть базу в браузере:\n$e');
  }
  final local = WebStringStorage.local();
  final session = WebStringStorage.session();
  final journal = StoredSyncJournal(local);
  return PlatformServices(
    database: AppDatabase(opened.db, '$webDatabaseName (${opened.storage})'),
    backups: null,
    tokenStore: (server) => BrowserTokenStore(
      server,
      persistent: local,
      session: session,
      remember: () => rememberNextSignIn,
    ),
    journal: journal,
    eraseLocalData: () async {
      journal.clear();
      await deleteWebDatabase(
        name: webDatabaseName,
        sqlite3Uri: _sqlite3Uri,
        driftWorkerUri: _driftWorkerUri,
      );
    },
  );
}
