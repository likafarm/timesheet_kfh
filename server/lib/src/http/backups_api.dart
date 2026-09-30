import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../database.dart';
import 'auth_api.dart';
import 'middleware.dart';
import 'request_utils.dart';
import 'responses.dart';

/// Ежедневные выгрузки сервера для модуля «Резервные копии» — только
/// администратору.
///
/// - `GET /admin/backups` → `{"backups": [{"name", "size", "created_at"}]}`,
///   новые первыми;
/// - `GET /admin/backups/<имя>` → сам файл (`application/octet-stream`).
///
/// Файлы `kfh-ГГГГММДД-ЧЧММСС.json.gz.age` кладёт `backup.sh` в папку
/// [dir] (`BACKUP_EXPORT_DIR`): снимок всех записей, сжатый и зашифрованный
/// открытым ключом age. Сервер расшифровать их не может — закрытый ключ
/// только у владельца; программа расшифровывает на его ПК. Папка не задана
/// или её нет — пустой список.
class BackupsApi {
  static final _name = RegExp(
      r'^kfh-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.json\.gz\.age$');

  static const _forbidden = ApiException(
      403, 'forbidden', 'Копии сервера — только для администратора');

  final String? dir;
  final MySqlDatabase db;
  final AuthApi auth;

  BackupsApi({required this.dir, required this.db, required this.auth});

  void addRoutes(Router router) {
    router
      ..get('/admin/backups', _list)
      ..get('/admin/backups/<name>', _download);
  }

  /// Момент снимка из имени файла (UTC) или null — имя не наше.
  static DateTime? createdAt(String name) {
    final m = _name.firstMatch(name);
    if (m == null) return null;
    final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime.utc(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  Future<Response> _list(Request request) async {
    final user = await auth.requireUser(request);
    if (user.role != Role.admin) throw _forbidden;
    final folder = dir == null ? null : Directory(dir!);
    final backups = <Map<String, Object?>>[];
    if (folder != null && await folder.exists()) {
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        final created = createdAt(name);
        if (created == null) continue;
        backups.add({
          'name': name,
          'size': await entry.length(),
          'created_at': created.toIso8601String(),
        });
      }
    }
    backups.sort((a, b) =>
        (b['name'] as String).compareTo(a['name'] as String));
    return jsonResponse({'backups': backups});
  }

  Future<Response> _download(Request request, String name) async {
    final user = await auth.requireUser(request);
    if (user.role != Role.admin) throw _forbidden;
    // Имя — только нашего вида: никаких путей.
    if (dir == null || createdAt(name) == null) {
      throw const ApiException.notFound('Такой копии на сервере нет');
    }
    final file = File('$dir/$name');
    if (!await file.exists()) {
      throw const ApiException.notFound('Такой копии на сервере нет');
    }
    final bytes = await file.readAsBytes();
    await writeAudit(db.execute,
        action: 'backup_download',
        userUuid: user.uuid,
        deviceId: deviceIdOf(request),
        requestId: requestIdOf(request),
        entity: 'backup',
        newValue: {'name': name, 'size': bytes.length});
    return Response.ok(bytes, headers: {
      'content-type': 'application/octet-stream',
      'content-length': '${bytes.length}',
    });
  }
}
