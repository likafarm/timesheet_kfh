import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';

import 'api_client.dart';
import 'failures.dart';
import 'session.dart';
import 'sync_engine.dart';
import 'sync_transport.dart';

/// Что делать при первом входе этой базы на сервер.
enum BootstrapKind {
  /// Сервер пуст, здесь есть данные — выгрузить базу (`/admin/import`).
  upload,

  /// И там, и здесь данные одного хозяйства (есть общие записи) —
  /// привязать: отправить своё, принять серверное, при расхождении
  /// побеждает более поздняя правка.
  link,

  /// Здесь данных нет — принять всё с сервера.
  download,

  /// Пусто и там, и здесь — просто начать синхронизацию.
  fresh,

  /// Данные есть и там, и здесь, но ни одной общей записи — это разные
  /// базы, смешивать нельзя.
  foreign,
}

/// Итог анализа: что будет сделано и можно ли.
class BootstrapPlan {
  final BootstrapKind kind;

  /// Записей здесь и на сервере (все таблицы, с удалёнными; без строки
  /// настроек хозяйства — она есть всегда).
  final int localRows;
  final int serverRows;

  /// Общих записей (по uuid).
  final int commonRows;

  /// Почему нельзя (null — можно).
  final String? refusal;

  const BootstrapPlan({
    required this.kind,
    required this.localRows,
    required this.serverRows,
    required this.commonRows,
    this.refusal,
  });

  bool get allowed => refusal == null;

  int get onlyLocal => localRows - commonRows;
  int get onlyServer => serverRows - commonRows;

  /// Что произойдёт — для окна подтверждения.
  String get description => switch (kind) {
    BootstrapKind.upload =>
      'Сервер пуст. База этого компьютера ($localRows записей) будет '
          'выгружена на сервер; сервер сверит каждую запись и расчёт ЗП '
          'за каждый месяц.',
    BootstrapKind.link =>
      'На сервере уже есть данные этого хозяйства: общих записей — '
          '$commonRows. Только на этом компьютере — $onlyLocal (уйдут на '
          'сервер), только на сервере — $onlyServer (придут сюда). Если '
          'одна запись изменена и там, и здесь, останется более поздняя '
          'правка, уступившая попадёт в журнал синхронизации.',
    BootstrapKind.download =>
      'На этом компьютере данных нет — с сервера будут приняты '
          '$serverRows записей.',
    BootstrapKind.fresh =>
      'Данных нет ни на сервере, ни здесь — синхронизация начнётся с нуля.',
    BootstrapKind.foreign =>
      'На сервере ($serverRows записей) и на этом компьютере ($localRows) '
          'разные базы — нет ни одной общей записи.',
  };
}

/// Первый вход базы на сервер (шаг 3.3): анализ без изменений, затем —
/// после резервной копии — выгрузка, привязка или приём.
///
/// Привязка к серверу хранится в базе (`sync_state`, адрес сервера): пока
/// база не привязана к [server], обычную синхронизацию запускать нельзя.
class SyncBootstrap {
  final LocalSyncStore store;
  final KfhApiClient api;
  final SyncTransport transport;
  final SyncEngine engine;

  /// Адрес сервера — им база помечается после привязки.
  final String server;

  /// Сколько ждать ответа на импорт (сервер сверяет всё в одной транзакции).
  final Duration importTimeout;

  SyncBootstrap({
    required this.store,
    required this.api,
    required this.transport,
    required this.engine,
    required this.server,
    this.importTimeout = const Duration(minutes: 5),
  });

  /// База уже привязана к этому серверу — первый вход не нужен.
  Future<bool> isLinked() async => await store.linkedServer() == server;

  /// Смотрит, что есть здесь и на сервере. Ничего не меняет.
  Future<BootstrapPlan> analyze(SessionUser user) async {
    final local = _withoutSettings(await store.localKeys());
    final remote = _withoutSettings(await _serverKeys());
    final localRows = _count(local), serverRows = _count(remote);
    var common = 0;
    for (final MapEntry(key: table, value: uuids) in local.entries) {
      common += uuids.intersection(remote[table] ?? const {}).length;
    }

    BootstrapPlan plan(BootstrapKind kind, {String? refusal}) => BootstrapPlan(
      kind: kind,
      localRows: localRows,
      serverRows: serverRows,
      commonRows: common,
      refusal: refusal,
    );

    if (!user.canUseDesktop) {
      return plan(
        BootstrapKind.fresh,
        refusal:
            'Роль «${user.roleTitle}» пока не работает в программе для '
            'Windows — нужна учётная запись администратора или бухгалтера.',
      );
    }
    if (serverRows == 0 && localRows == 0) return plan(BootstrapKind.fresh);
    if (serverRows == 0) {
      return plan(
        BootstrapKind.upload,
        refusal: user.isAdmin
            ? null
            : 'Сервер пуст. Выгрузить на него базу может только '
                  'администратор.',
      );
    }
    if (localRows == 0) return plan(BootstrapKind.download);
    if (common > 0) return plan(BootstrapKind.link);
    return plan(
      BootstrapKind.foreign,
      refusal:
          'На сервере и на этом компьютере разные базы (нет ни одной '
          'общей записи). Смешивать их нельзя: обратитесь к администратору.',
    );
  }

  /// Выполняет план. [backup] — резервная копия базы; без неё ничего не
  /// начинается. После успеха база привязана к серверу.
  Future<SyncReport> execute(
    BootstrapPlan plan, {
    required Future<void> Function() backup,
  }) async {
    if (!plan.allowed) throw StateError(plan.refusal!);
    await backup();

    // Отметки «отправлено» относятся к прежнему серверу (или к прерванной
    // попытке) — для этого сервера всё снова неотправленное.
    if (await store.linkedServer() != server) await store.forgetServer();

    switch (plan.kind) {
      case BootstrapKind.upload:
        final export = await buildSyncExport(store.db);
        await api.postJson(
          '/admin/import',
          export.toJson(),
          timeout: importTimeout,
        );
      case BootstrapKind.download:
        await store.markAllSynced();
      case BootstrapKind.link:
      case BootstrapKind.fresh:
        break;
      case BootstrapKind.foreign:
        throw StateError('разные базы');
    }
    // После импорта отправка — сплошь duplicate (сервер уже всё знает), а
    // приём с нуля — те же записи: так проверяется, что обе стороны сошлись.
    final report = await engine.run(linking: true);
    await store.setLinkedServer(server);
    return report;
  }

  /// Все записи сервера (uuid по таблицам) — постранично, без записи в базу.
  Future<Map<String, Set<String>>> _serverKeys() async {
    final keys = {for (final t in syncTables) t.name: <String>{}};
    var cursor = SyncCursor.start;
    while (true) {
      final page = await transport.pull(cursor, limit: 1000);
      for (final c in page.changes) {
        keys[c.table]?.add(c.uuid);
      }
      if (!page.hasMore) return keys;
      if (page.cursor == cursor.seq) {
        throw ServerFailure('pull не продвигается');
      }
      cursor = SyncCursor(page.cursor, page.epoch);
    }
  }

  static Map<String, Set<String>> _withoutSettings(
    Map<String, Set<String>> keys,
  ) => {
    for (final e in keys.entries)
      if (e.key != 'company_settings') e.key: e.value,
  };

  static int _count(Map<String, Set<String>> keys) =>
      keys.values.fold(0, (sum, s) => sum + s.length);
}
