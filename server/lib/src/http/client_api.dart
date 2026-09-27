import 'dart:convert';
import 'dart:io';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../logger.dart';
import 'responses.dart';

/// Версии программ (шаг 4.8):
/// - `GET /client/version` — без входа (программе нужно знать, что пора
///   обновиться, ещё до входа): `{"platforms": {"android": {"latest",
///   "min", "url", "sha256"}, "windows": {...}}}`.
///
/// Список — файл JSON ([versionsFile], `CLIENT_VERSIONS_FILE`), его пишет
/// выкладка APK рядом с самим APK; читается на каждый запрос, поэтому новая
/// версия видна без перезапуска сервера. Файла нет — пустой список
/// (обновлений не требуется).
class ClientApi {
  final String? versionsFile;
  final Logger logger;

  ClientApi({required this.versionsFile, required this.logger});

  void addRoutes(Router router) {
    router.get('/client/version', _version);
  }

  Future<Response> _version(Request request) async {
    return jsonResponse((await read()).toJson());
  }

  /// Список версий из файла. Испорченный файл — ошибка сервера (500) и
  /// запись в журнал: молча отдать «обновлений нет» нельзя.
  Future<ClientVersions> read() async {
    final path = versionsFile;
    if (path == null) return ClientVersions.empty;
    final file = File(path);
    if (!await file.exists()) return ClientVersions.empty;
    try {
      return ClientVersions.fromJson(jsonDecode(await file.readAsString()));
    } on Object catch (e) {
      logger.error('client/version: неверный файл версий',
          error: e, fields: {'file': path});
      throw const ApiException(
          500, 'client_versions', 'Список версий программ на сервере испорчен');
    }
  }
}
