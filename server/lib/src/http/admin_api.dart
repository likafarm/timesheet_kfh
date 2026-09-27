import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../admin/import_service.dart';
import 'auth_api.dart';
import 'middleware.dart';
import 'request_utils.dart';
import 'responses.dart';

/// Служебные действия администратора.
///
/// - `POST /admin/import` — тело: выгрузка `SyncExport` (до 20 МБ) →
///   `{ok, counts, rows, payroll_checks, months, …}`; ошибки: 400
///   `invalid_export`, 409 `not_empty`, 422 `verification_failed` (у всех —
///   `error.details` со списком).
class AdminApi {
  final ImportService importer;
  final AuthApi auth;

  AdminApi(this.importer, this.auth);

  void addRoutes(Router router) {
    router.post('/admin/import', _import);
  }

  Future<Response> _import(Request request) async {
    final user = await auth.requireUser(request);
    final body = await readJsonObject(request, maxBytes: ImportService.maxBytes);
    final report = await importer.import(user, body, requestId: requestIdOf(request));
    return jsonResponse(report);
  }
}
