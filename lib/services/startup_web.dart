// lib/services/startup_web.dart
//
// Запуск веб-версии (этап 5): база drift WASM в хранилище браузера (OPFS или
// IndexedDB), без файловых копий; токены и журнал — в хранилище браузера.

import 'dart:async';
import 'dart:js_interop';

import 'package:kfh_local_db/web.dart';
import 'package:web/web.dart' as web;

import 'app_database.dart';
import 'browser_storage.dart';
import 'platform_services.dart';
import 'page_reload.dart';
import 'web_string_storage.dart';
import 'web_tab_lock.dart';

const startupErrorHint =
    'Данные на сервере не затронуты. Причина — ниже. Попробуйте обновить '
    'страницу; если не поможет — откройте программу в Chrome, Edge или '
    'Яндекс Браузере не в режиме инкогнито.';

/// Имя базы в хранилище браузера.
const webDatabaseName = 'kfh_time_tracking';

// Файлы из web/ строго под версии sqlite3 и drift приложения
// (tool/web_assets.ps1). Адреса абсолютные: worker разрешает относительные
// от своего адреса, а не от страницы.
final _sqlite3Uri = Uri.base.resolve('sqlite3.wasm');
final _driftWorkerUri = Uri.base.resolve('drift_worker.js');

/// Запомнить следующий вход после закрытия вкладки (нет отметки
/// «Чужой компьютер»).
bool _rememberNextSignIn = true;

/// Метка в localStorage: вход сделан с отметкой «Чужой компьютер». Если при
/// запуске метка есть, а входа нет (вкладку закрыли, не выйдя), — данные
/// прошлого сеанса стираются до открытия базы.
const _publicSessionKey = 'kfh_public_session';

/// Программа открыта в другой вкладке — [AnotherTabOpen]; [takeOver] —
/// забрать работу у той вкладки.
Future<PlatformServices> startPlatform({bool takeOver = false}) async {
  final tab = await acquireTabLock(steal: takeOver);
  if (tab == null) throw const AnotherTabOpen();
  final local = WebStringStorage.local();
  final session = WebStringStorage.session();
  final journal = StoredSyncJournal(local);
  Future<void> erase() async {
    journal.clear();
    await deleteWebDatabase(
      name: webDatabaseName,
      sqlite3Uri: _sqlite3Uri,
      driftWorkerUri: _driftWorkerUri,
    );
    local.remove(_publicSessionKey);
  }

  if (local.read(_publicSessionKey) != null &&
      !hasBrowserTokens(local) &&
      !hasBrowserTokens(session)) {
    await erase();
  }

  final WebDatabase opened;
  try {
    opened = await openWebDatabase(
      name: webDatabaseName,
      sqlite3Uri: _sqlite3Uri,
      driftWorkerUri: _driftWorkerUri,
    );
    // Первый запрос — здесь: если браузер не запустил обработчик базы
    // (worker), запрос не ответит никогда — лучше сказать об этом.
    await opened.db.deviceId().timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw const DatabaseOpenException(
      'База в браузере не ответила за 30 секунд. Закройте другие вкладки '
      'программы и обновите страницу.',
    );
  } on WebStorageUnavailable catch (e) {
    throw DatabaseOpenException('$e');
  } catch (e) {
    throw DatabaseOpenException('Не удалось открыть базу в браузере:\n$e');
  }
  return PlatformServices(
    database: AppDatabase(opened.db, '$webDatabaseName (${opened.storage})'),
    backups: null,
    tokenStore: (server) => BrowserTokenStore(
      server,
      persistent: local,
      session: session,
      remember: () => _rememberNextSignIn,
    ),
    journal: journal,
    lostToAnotherTab: tab.lost,
    reloadPage: reloadPage,
    eraseLocalData: erase,
    rememberSignIn: (remember) {
      _rememberNextSignIn = remember;
      if (remember) {
        local.remove(_publicSessionKey);
      } else {
        local.write(_publicSessionKey, '1');
      }
    },
    guardPageClose: (hasUnsent) {
      web.window.onbeforeunload = ((web.BeforeUnloadEvent event) {
        if (local.read(_publicSessionKey) != null && hasUnsent()) {
          // Браузер спросит, закрывать ли вкладку: после закрытия «чужой»
          // вход кончится, а неотправленное будет стёрто.
          event.preventDefault();
        }
      }).toJS;
    },
  );
}
