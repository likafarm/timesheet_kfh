// lib/providers/sync_provider.dart
//
// Синхронизация с сервером для интерфейса: вход, первый вход базы
// (выгрузка / привязка / приём), запуск синхронизации, состояние для
// строки статуса. Сама логика — в пакете kfh_sync.

import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, Variable;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart' show PlatformVersion;
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/platform.dart';

/// Где находится программа по отношению к серверу.
enum SyncPhase {
  /// Состояние ещё читается.
  starting,

  /// Вход не выполнен: программа работает только с этой базой.
  signedOut,

  /// Вход выполнен, но нужно сменить выданный администратором пароль.
  passwordChange,

  /// Вход выполнен, база ещё не привязана к серверу — нужен первый вход
  /// (выгрузка, привязка или приём).
  needsLink,

  /// Всё готово — синхронизация работает.
  ready,
}

/// Ошибка, которую нужно показать человеку как есть.
class SyncUserException implements Exception {
  final String message;
  const SyncUserException(this.message);

  @override
  String toString() => message;
}

class SyncProvider extends ChangeNotifier {
  /// Сервер по умолчанию. Отладочная сборка — только локальный стенд
  /// (`docker-compose.dev.yml`), чтобы `flutter run` не трогал рабочий.
  ///
  /// Эмулятор Android видит компьютер разработчика по адресу 10.0.2.2.
  /// Веб-версия работает только со своим сервером — тем, с которого
  /// открыта страница (API на том же адресе, этап 5).
  static String get defaultServer => kIsWeb && !kDebugMode
      ? Uri.base.origin
      : !kDebugMode
      ? 'https://tab.korovatech.ru'
      : isAndroidApp
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  /// Ключ времени последней удачной синхронизации в `sync_state`.
  static const lastSyncKey = 'sync_last_at';

  /// Ключ в `sync_state`: база восстановлена из копии, следующая удачная
  /// синхронизация — повторная сверка с сервером (как при привязке).
  static const relinkKey = 'sync_relink';

  /// Сервер на этом компьютере (стенд), а не рабочий. Для эмулятора
  /// Android компьютер разработчика — 10.0.2.2.
  static bool isLocalServer(String server) {
    final host = Uri.tryParse(server)?.host ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]' ||
        (isAndroidApp && host == '10.0.2.2');
  }

  SyncProvider({
    required LocalDatabase database,
    required this.onDataChanged,
    required this.backup,
    required this._tokenStore,
    required this.journal,
    this.onLocksChanged,
    this.rememberSignIn,
    this.eraseAfterSignOut,
    http.Client Function()? httpClient,
    this.autoSync = true,
    this.syncInterval = const Duration(minutes: 5),
    this.changeDelay = const Duration(seconds: 5),
    this.debugBuild = kDebugMode,
    ClientKind? client,
    Future<String> Function()? appVersion,
  }) : _appVersion = appVersion ?? _installedVersion,
       client = client ?? platformClientKind,
       _db = database,
       _httpClient = httpClient ?? http.Client.new;

  /// Синхронизация записала изменения с сервера — экранам перечитать данные.
  final Future<void> Function() onDataChanged;

  /// Резервная копия базы перед первым входом; бросает исключение, если
  /// копию сделать не удалось.
  final Future<void> Function() backup;

  /// Список закрытых на сервере месяцев изменился (он в `sync_state`).
  final Future<void> Function()? onLocksChanged;

  final SyncJournal journal;

  /// Веб-версия: запоминать ли следующий вход после закрытия вкладки
  /// (false — отметка «Чужой компьютер»). null — вход помнится всегда.
  final void Function(bool remember)? rememberSignIn;

  /// Веб-версия: после выхода стереть данные браузера (приложение закрывает
  /// базу, стирает её и перезагружает страницу). null — база остаётся
  /// привязанной к серверу (Windows, Android).
  final Future<void> Function()? eraseAfterSignOut;

  /// В окне входа — отметка «Чужой компьютер».
  bool get offersPublicComputer => rememberSignIn != null;

  /// Выход стирает данные этого устройства.
  bool get erasesOnSignOut => eraseAfterSignOut != null;

  /// Адрес сервера можно сменить. Веб-версия работает только с сервером, с
  /// которого открыта страница (кроме отладки: там API на другом порту).
  bool get canChangeServer => client != ClientKind.web || debugBuild;

  /// Вход прекращается вместе со сроком refresh-токена, даже без связи
  /// (веб-версия, этап 5). Программы для Windows и телефона без связи
  /// продолжают работать и узнают об окончании сеанса от сервера.
  bool get _sessionExpiresLocally => client == ClientKind.web;
  Timer? _expiryTimer;

  /// Синхронизироваться самой (шаг 3.5): при запуске, после правок, раз в
  /// 5 минут, с паузами при отсутствии сети. В тестах — выключено.
  final bool autoSync;

  /// Плановая синхронизация — раз в [syncInterval]; правка уходит через
  /// [changeDelay] после последней.
  final Duration syncInterval;
  final Duration changeDelay;
  late final SyncScheduler _scheduler = SyncScheduler(
    _scheduledRun,
    interval: syncInterval,
    changeDelay: changeDelay,
    onChanged: notifyListeners,
  );
  bool _localEdit = false;

  /// Какая это программа: от неё зависит, какие роли могут войти.
  final ClientKind client;

  /// Версия этой программы (`pubspec.yaml`).
  final Future<String> Function() _appVersion;
  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Версии программы на сервере (шаг 4.8); null — ещё не известны.
  PlatformVersion? _serverVersion;
  String? _version;

  /// Версия этой программы (после [init]).
  String? get appVersion => _version;

  /// Версия на сервере для этой платформы (null — сервер не сообщил).
  PlatformVersion? get serverVersion => _serverVersion;

  /// Программа старее минимальной версии сервера: синхронизация на паузе
  /// до обновления (введённое сохраняется здесь и уйдёт после обновления).
  bool get updateRequired {
    final v = _serverVersion, current = _version;
    return v != null && current != null && v.requiresUpdate(current);
  }

  /// На сервере есть версия новее этой.
  bool get updateAvailable {
    final v = _serverVersion, current = _version;
    return v != null && current != null && v.hasUpdate(current);
  }

  String get _platformKey => switch (client) {
    ClientKind.desktop => 'windows',
    ClientKind.phone => 'android',
    ClientKind.web => 'web',
  };

  /// Версии программ — с сервера, без входа. Сбой не мешает: остаётся
  /// прежнее знание (проверка повторится после следующей синхронизации).
  Future<void> checkVersion() async {
    try {
      _version ??= await _appVersion();
      final all = await _api!.clientVersions();
      _serverVersion = all.platforms[_platformKey];
      notifyListeners();
    } catch (e) {
      debugPrint('sync: версии программ не получены: $e');
    }
  }

  /// Отладочная сборка: адрес не на этом компьютере — только с явного
  /// согласия (у неё своя база, но вход — настоящий).
  final bool debugBuild;

  /// Сервер, к которому база была привязана (для повторной сверки после
  /// полного восстановления, когда прежняя база уже закрыта).
  String? _linkedServer;

  /// Идёт замена файла базы — синхронизация не запускается.
  bool _suspended = false;

  final TokenStore Function(String server) _tokenStore;
  final http.Client Function() _httpClient;

  LocalDatabase _db;
  KfhApiClient? _api;
  SyncEngine? _engine;
  StreamSubscription<Set<TableUpdate>>? _updates;
  Timer? _pendingTimer;

  SyncPhase _phase = SyncPhase.starting;
  late String _server = defaultServer;
  SessionUser? _user;
  bool _syncing = false;
  bool _offline = false;
  String? _problem;
  DateTime? _lastSyncAt;
  SyncReport? _lastReport;
  int _pending = 0;
  int _rejected = 0;

  SyncPhase get phase => _phase;
  String get server => _server;
  SessionUser? get user => _user;
  bool get isSyncing => _syncing;

  /// Последняя попытка не дошла до сервера.
  bool get isOffline => _offline;

  /// Последняя ошибка синхронизации (понятным текстом), null — всё хорошо.
  String? get problem => _problem;
  DateTime? get lastSyncAt => _lastSyncAt;
  SyncReport? get lastReport => _lastReport;

  /// База связана с сервером (выполнен первый вход).
  bool get isLinked => _linkedServer != null;

  /// Предупреждение для окон восстановления из копии (null — база не
  /// связана с сервером, предупреждать не о чем).
  String? restoreWarning({required bool full}) {
    if (!isLinked) return null;
    return full
        ? 'Компьютер связан с сервером $_linkedServer. После восстановления '
              'база будет заново сверена с сервером: записи, изменённые на '
              'сервере позже копии, вернутся к серверному виду, а записи из '
              'копии, которых на сервере нет, будут отправлены на сервер.'
        : 'Компьютер связан с сервером: восстановленные записи будут '
              'отправлены на сервер и появятся на других компьютерах.';
  }

  /// Неотправленных записей (вместе с отклонёнными сервером).
  int get pending => _pending;

  /// Из них отклонено сервером — ждут вмешательства.
  int get rejected => _rejected;

  /// Когда следующая автоматическая попытка (null — не назначена).
  DateTime? get nextAttemptAt => autoSync ? _scheduler.nextAttemptAt : null;

  LocalSyncStore get _store => LocalSyncStore(_db);

  // ------------------------------------------------------------- запуск

  /// Читает привязку базы и сохранённый вход.
  Future<void> init() async {
    _watchDatabase();
    _server = await _store.linkedServer() ?? defaultServer;
    final saved = await _db.syncStateDao.getValue(lastSyncKey);
    _lastSyncAt = saved == null ? null : DateTime.tryParse(saved)?.toLocal();
    await _connect(_server);
    _user = await _api!.currentUser();
    if (_user != null && !_user!.canUseOn(client)) {
      // Сохранённый вход роли, которой здесь не место, — забыть.
      await _api!.logout();
      _user = null;
    }
    await _updatePhase();
    await _watchSessionExpiry();
    await refreshPending();
    unawaitedSafe(checkVersion());
  }

  /// База переоткрыта (полное восстановление из копии) — начать заново.
  Future<void> rebind(LocalDatabase database) async {
    if (identical(database, _db)) return;
    _scheduler.stop();
    _db = database;
    _engine = null;
    final linked = _linkedServer;
    if (linked != null) {
      // Восстановленная копия — неизвестно, что из неё знает сервер: всё
      // «не отправлено», курсор с нуля; первая синхронизация сверит базу с
      // сервером как при привязке (решение владельца 2026-09-27: сервер —
      // истина; записи копии, которых на сервере нет, уйдут туда).
      await _store.forgetServer();
      await _store.setLinkedServer(linked);
      await _db.syncStateDao.setValue(relinkKey, '1');
    }
    _suspended = false;
    await init();
  }

  /// Перед заменой файла базы (полное восстановление): дождаться идущего
  /// обмена и остановить автоматику. Возобновляет [rebind].
  Future<void> suspend() async {
    _suspended = true;
    _scheduler.stop();
    while (_syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _connect(String server) async {
    _api?.close();
    _api = KfhApiClient(
      baseUrl: Uri.parse(server),
      deviceId: await _db.deviceId(),
      tokens: _tokenStore(server),
      client: _httpClient(),
    );
    _engine = null;
  }

  Future<void> _updatePhase() async {
    _linkedServer = await _store.linkedServer();
    final user = _user;
    if (user == null) {
      _phase = SyncPhase.signedOut;
    } else if (user.mustChangePassword) {
      _phase = SyncPhase.passwordChange;
    } else if (_linkedServer != _server) {
      _phase = SyncPhase.needsLink;
    } else {
      _phase = SyncPhase.ready;
    }
    if (autoSync) {
      if (_phase != SyncPhase.ready) {
        _scheduler.stop();
      } else if (!_scheduler.isStarted) {
        _scheduler.start(); // первая попытка — сразу
      } else if (_scheduler.isBlocked) {
        _scheduler.resume();
      }
    }
    notifyListeners();
  }

  SyncEngine get _syncEngine => _engine ??= SyncEngine(
    store: _store,
    transport: HttpSyncTransport(_api!),
    journal: journal,
  );

  // ------------------------------------------------------------- вход

  /// Адрес сервера в привычном виде: без «/» в конце, по умолчанию https.
  static String normalizeServer(String input) {
    var s = input.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.contains('://')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      throw const SyncUserException('Адрес сервера указан неверно');
    }
    return s;
  }

  /// Вход логином и паролем. Ошибка — [SyncUserException] с понятным
  /// текстом.
  /// [allowRemoteInDebug] — в отладочной сборке человек подтвердил вход на
  /// сервер не на этом компьютере.
  /// [publicComputer] — веб-версия: не запоминать вход после закрытия
  /// вкладки.
  Future<void> signIn(
    String server,
    String login,
    String password, {
    bool allowRemoteInDebug = false,
    bool publicComputer = false,
  }) async {
    final address = normalizeServer(server);
    if (debugBuild && !isLocalServer(address) && !allowRemoteInDebug) {
      throw const SyncUserException(
        'Это отладочная сборка: подключение к серверу не на этом компьютере '
        'нужно подтвердить отдельно.',
      );
    }
    rememberSignIn?.call(!publicComputer);
    await _connect(address);
    _server = address;
    final SessionUser user;
    try {
      user = await _api!.login(login.trim(), password);
    } on SyncFailure catch (e) {
      throw SyncUserException(_explain(e));
    }
    final refusal = user.refusalOn(client);
    if (refusal != null) {
      await _api!.logout();
      _user = null;
      await _updatePhase();
      throw SyncUserException(refusal);
    }
    _user = user;
    _problem = null;
    _offline = false;
    await _updatePhase();
    await _watchSessionExpiry();
  }

  /// Смена пароля (обязательная после выдачи администратором или по
  /// желанию).
  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      _user = await _api!.changePassword(oldPassword, newPassword);
    } on SyncFailure catch (e) {
      throw SyncUserException(_explain(e));
    }
    await _updatePhase();
  }

  /// Выход: токены удаляются, база остаётся привязанной к серверу —
  /// следующий вход продолжит с того же места. Веб-версия после выхода
  /// стирает базу браузера ([eraseAfterSignOut]): неотправленное теряется,
  /// предупреждает об этом окно выхода.
  Future<void> signOut() async {
    final erase = eraseAfterSignOut;
    if (erase != null) await suspend();
    _expiryTimer?.cancel();
    await _api?.logout();
    _user = null;
    _problem = null;
    _offline = false;
    if (erase != null) {
      await erase();
      return;
    }
    await _updatePhase();
  }

  /// Веб-версия: вход кончается вместе со сроком refresh-токена — тогда
  /// экран входа (данные браузера остаются: тот же вход продолжит с того же
  /// места).
  Future<void> _watchSessionExpiry() async {
    _expiryTimer?.cancel();
    if (!_sessionExpiresLocally || _user == null) return;
    final tokens = await _api?.tokens.read();
    if (tokens == null) return;
    final left = tokens.refreshExpiresAt.difference(DateTime.now().toUtc());
    if (left <= Duration.zero) {
      await _api?.logout();
      _user = null;
      _problem =
          'Срок входа истёк. Войдите снова — до входа данные сохраняются '
          'только $onThisDevice.';
      await _updatePhase();
      return;
    }
    // Таймер браузера не дольше ~24 дней — проверяем не реже раза в сутки.
    const day = Duration(days: 1);
    _expiryTimer = Timer(
      left > day ? day : left,
      () => unawaitedSafe(_watchSessionExpiry()),
    );
  }

  // ------------------------------------------------------------- первый вход

  SyncBootstrap _bootstrap() => SyncBootstrap(
    store: _store,
    api: _api!,
    transport: HttpSyncTransport(_api!),
    engine: _syncEngine,
    server: _server,
    client: client,
  );

  /// Что будет при первом входе этой базы на сервер. Ничего не меняет.
  Future<BootstrapPlan> analyzeLink() async {
    try {
      return await _bootstrap().analyze(_user!);
    } on SyncFailure catch (e) {
      await _afterFailure(e);
      throw SyncUserException(_explain(e));
    }
  }

  /// Выполняет первый вход: копия базы, затем выгрузка / привязка / приём.
  Future<SyncReport> link(BootstrapPlan plan) async {
    _syncing = true;
    notifyListeners();
    try {
      final report = await _bootstrap().execute(plan, backup: backup);
      await _succeeded(report);
      await _updatePhase();
      return report;
    } on SyncFailure catch (e) {
      await _afterFailure(e);
      throw SyncUserException(_explain(e));
    } finally {
      _syncing = false;
      await refreshPending();
    }
  }

  // ------------------------------------------------------------- синхронизация

  /// Синхронизировать сейчас (кнопка). Не бросает: ошибка — в [problem].
  /// [retryRejected] — отправить и отклонённые ранее правки.
  Future<SyncReport?> syncNow({bool retryRejected = false}) async {
    final report = await _runSync(retryRejected: retryRejected);
    if (autoSync) _scheduler.ranManually(_attempt());
    return report;
  }

  /// Попытка по расписанию.
  Future<SyncAttempt> _scheduledRun() async {
    await _runSync();
    return _attempt();
  }

  /// Итог последней попытки для расписания.
  SyncAttempt _attempt() => _phase != SyncPhase.ready || updateRequired
      ? SyncAttempt.blocked
      : _problem != null
      ? SyncAttempt.transient
      : SyncAttempt.ok;

  Future<SyncReport?> _runSync({bool retryRejected = false}) async {
    if (_phase != SyncPhase.ready || _suspended) return null;
    if (updateRequired) {
      _problem =
          'Нужна новая версия программы (${_serverVersion!.latest}): '
          'синхронизация на паузе, введённое сохраняется $onThisDevice.';
      notifyListeners();
      return null;
    }
    _syncing = true;
    notifyListeners();
    try {
      final relink = await _db.syncStateDao.getValue(relinkKey) == '1';
      final report = await _syncEngine.run(
        retryRejected: retryRejected,
        linking: relink,
      );
      if (relink) {
        await _db.customUpdate(
          'DELETE FROM sync_state WHERE key = ?',
          variables: [Variable<String>(relinkKey)],
        );
      }
      await _succeeded(report);
      return report;
    } on SyncFailure catch (e) {
      await _afterFailure(e);
      return null;
    } catch (e) {
      _problem = 'Ошибка синхронизации: $e';
      return null;
    } finally {
      _syncing = false;
      await refreshPending();
    }
  }

  Future<void> _succeeded(SyncReport report) async {
    _lastReport = report;
    _lastSyncAt = report.finishedAt.toLocal();
    _problem = null;
    _offline = false;
    await _db.syncStateDao.setValue(
      lastSyncKey,
      report.finishedAt.toIso8601String(),
    );
    if (report.changedLocalData) await onDataChanged();
    await _refreshLocks();
    // Обмен refresh-токена продлевает вход.
    await _watchSessionExpiry();
    await checkVersion();
  }

  /// Закрытые месяцы — с сервера, после каждой удачной синхронизации. Сбой
  /// не мешает: остаётся прежний список (сервер всё равно не примет правку
  /// в закрытом месяце).
  Future<void> _refreshLocks() async {
    try {
      final months = await _api!.lockedMonths();
      if (await _store.saveLockedMonths(months)) await onLocksChanged?.call();
    } on SyncFailure catch (e) {
      debugPrint('sync: закрытые месяцы не получены: ${e.message}');
    }
  }

  Future<void> _afterFailure(SyncFailure e) async {
    _offline = e is NetworkFailure;
    _problem = _explain(e);
    if (e is ApiFailure) {
      if (e.needsLogin) {
        await _api?.logout();
        _user = null;
        _problem =
            '${e.message}. Войдите снова — до входа данные '
            'сохраняются только $onThisDevice.';
      } else if (e.code == 'password_change_required') {
        final u = _user;
        if (u != null) {
          _user = SessionUser(
            uuid: u.uuid,
            login: u.login,
            fullName: u.fullName,
            role: u.role,
            mustChangePassword: true,
          );
        }
      }
    }
    await _updatePhase();
  }

  String _explain(SyncFailure e) => switch (e) {
    NetworkFailure() => 'Нет связи с сервером $_server',
    ApiFailure(details: final d) when d.isNotEmpty =>
      '${e.message}:\n${d.take(10).join('\n')}',
    _ => e.message,
  };

  // ------------------------------------------------------------- очередь

  /// Пересчитать неотправленное (после правок в базе).
  Future<void> refreshPending() async {
    _pending = await _store.pendingCount();
    _rejected = (await _store.rejectedChanges()).length;
    // Правка человека (не запись самой синхронизации) — отправить вскоре.
    if (_localEdit && _pending > _rejected && autoSync) {
      _scheduler.localChanged();
    }
    _localEdit = false;
    notifyListeners();
  }

  /// Отклонённые сервером правки — для журнала.
  Future<List<RejectedChange>> rejectedChanges() => _store.rejectedChanges();

  void _watchDatabase() {
    _updates?.cancel();
    _updates = _db.tableUpdates().listen((updates) {
      if (!_syncing && updates.any((u) => businessTables.contains(u.table))) {
        _localEdit = true;
      }
      _pendingTimer?.cancel();
      _pendingTimer = Timer(
        const Duration(milliseconds: 400),
        () => unawaitedSafe(refreshPending()),
      );
    });
  }

  static void unawaitedSafe(Future<void> f) =>
      f.catchError((Object e) => debugPrint('sync: $e'));

  @override
  void dispose() {
    _scheduler.stop();
    _expiryTimer?.cancel();
    _updates?.cancel();
    _pendingTimer?.cancel();
    _api?.close();
    super.dispose();
  }
}
