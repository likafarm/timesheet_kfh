import 'package:kfh_domain/kfh_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_service.dart';
import '../auth/permissions.dart';
import '../auth/users.dart';
import '../database.dart';
import '../payroll/payroll_calculator.dart';
import '../periods/period_service.dart';
import '../sync/sync_rows.dart';
import 'auth_api.dart';
import 'middleware.dart';
import 'request_utils.dart';
import 'responses.dart';

/// Закрытые месяцы, расчёт ЗП и чтение данных (для веба и отчётов).
///
/// - `GET /periods/locks` — все; `POST /periods/locks` `{year, month, note?}`,
///   `DELETE /periods/locks/<year>/<month>` — бухгалтер и админ;
/// - `GET /payroll?year=&month=` — сохранённые расчёты и входящие остатки;
/// - `GET /payroll/calculation?year=&month=` — свежий расчёт рядом с
///   сохранённым (`up_to_date`), без записи;
/// - `POST /payroll/calculate` `{year, month}` — посчитать и сохранить;
/// - `GET /employees?active_on=`, `GET /timesheet?year=&month=&employee_uuid=`,
///   `GET /rates?employee_uuid=`, `GET /payments?from=&to=&employee_uuid=`,
///   `GET /settings`.
///
/// Права на чтение — как у синхронизации (`readableTables`): оператор видит
/// сотрудников (без ставок) и табель; расчёт — бухгалтер и админ.
class DataApi {
  final MySqlDatabase db;
  final AuthApi auth;
  final PeriodService periods;
  final PayrollCalculator payroll;
  final _rows = const SyncRows();

  DataApi({
    required this.db,
    required this.auth,
    required this.periods,
    required this.payroll,
  });

  void addRoutes(Router router) {
    router
      ..get('/periods/locks', _locks)
      ..post('/periods/locks', _lock)
      ..delete('/periods/locks/<year>/<month>', _unlock)
      ..get('/payroll', _payroll)
      ..get('/payroll/calculation', _calculation)
      ..post('/payroll/calculate', _calculate)
      ..get('/employees', _employees)
      ..get('/timesheet', _timesheet)
      ..get('/rates', _rates)
      ..get('/payments', _payments)
      ..get('/settings', _settings);
  }

  // ------------------------------------------------------------- месяцы

  Future<Response> _locks(Request request) async {
    await auth.requireUser(request);
    final locks = await periods.list();
    return jsonResponse({'locks': [for (final l in locks) l.toJson()]});
  }

  Future<Response> _lock(Request request) async {
    final user = await auth.requireUser(request);
    final body = await readJsonObject(request);
    final lock = await periods.lock(user, body['year'], body['month'], body['note'],
        requestId: requestIdOf(request), deviceId: deviceIdOf(request));
    return jsonResponse(lock.toJson(), status: 201);
  }

  Future<Response> _unlock(Request request, String year, String month) async {
    final user = await auth.requireUser(request);
    await periods.unlock(user, year, month,
        requestId: requestIdOf(request), deviceId: deviceIdOf(request));
    return Response(204);
  }

  // -------------------------------------------------------------- расчёт

  Future<Response> _payroll(Request request) async {
    final user = await _accountant(request);
    final (year, month) = _yearMonth(request);
    final saved = await _rows.live(db.execute, _t('payroll_results'),
        where: 'year = :y AND month = :m',
        params: {'y': year, 'm': month},
        orderBy: 'employee_uuid');
    final balances = await payroll.startingBalances(db.execute, year, month);
    return jsonResponse({
      'year': year,
      'month': month,
      'results': [for (final r in saved) _json(user, r)],
      'starting_balances': balances,
    });
  }

  Future<Response> _calculation(Request request) async {
    await _accountant(request);
    final (year, month) = _yearMonth(request);
    final results = await payroll.calculate(db.execute, year, month);
    return jsonResponse({
      'year': year,
      'month': month,
      'employees': [for (final r in results) r.toJson()],
    });
  }

  Future<Response> _calculate(Request request) async {
    final user = await _accountant(request);
    final body = await readJsonObject(request);
    final year = body['year'], month = body['month'];
    if (year is! int || month is! int) {
      throw const ApiException(400, 'validation', 'Нужны год и месяц — целые числа');
    }
    final done = await payroll.save(user, year, month,
        requestId: requestIdOf(request));
    return jsonResponse({
      'year': year,
      'month': month,
      'saved': done.saved,
      'unchanged': done.unchanged,
      'employees': [for (final r in done.results) r.toJson()],
    });
  }

  // -------------------------------------------------------------- чтение

  Future<Response> _employees(Request request) async {
    final user = await _reader(request, 'employees');
    final activeOn = _dateParam(request, 'active_on');
    final rows = await _rows.live(db.execute, _t('employees'),
        where: activeOn == null
            ? '1 = 1'
            : 'hire_date <= :d AND (dismissal_date IS NULL OR dismissal_date >= :d)',
        params: {'d': ?activeOn},
        orderBy: 'full_name, uuid');
    return jsonResponse({'employees': [for (final r in rows) _json(user, r)]});
  }

  Future<Response> _timesheet(Request request) async {
    final user = await _reader(request, 'timesheet');
    final (year, month) = _yearMonth(request);
    final employee = _uuidParam(request, 'employee_uuid');
    final rows = await _rows.live(db.execute, _t('timesheet'),
        where: 'date BETWEEN :from AND :to'
            '${employee == null ? '' : ' AND employee_uuid = :e'}',
        params: {
          'from': formatDateIso(DateTime(year, month, 1)),
          'to': formatDateIso(DateTime(year, month + 1, 0)),
          'e': ?employee,
        },
        orderBy: 'date, employee_uuid');
    return jsonResponse({'timesheet': [for (final r in rows) _json(user, r)]});
  }

  Future<Response> _rates(Request request) async {
    final user = await _reader(request, 'employee_rates');
    final employee = _uuidParam(request, 'employee_uuid');
    final rows = await _rows.live(db.execute, _t('employee_rates'),
        where: employee == null ? '1 = 1' : 'employee_uuid = :e',
        params: {'e': ?employee},
        orderBy: 'employee_uuid, start_date');
    return jsonResponse({'rates': [for (final r in rows) _json(user, r)]});
  }

  Future<Response> _payments(Request request) async {
    final user = await _reader(request, 'payments');
    final from = _dateParam(request, 'from'), to = _dateParam(request, 'to');
    final employee = _uuidParam(request, 'employee_uuid');
    final rows = await _rows.live(db.execute, _t('payments'),
        where: [
          if (from != null) 'payment_date >= :from',
          if (to != null) 'payment_date <= :to',
          if (employee != null) 'employee_uuid = :e',
          '1 = 1',
        ].join(' AND '),
        params: {'from': ?from, 'to': ?to, 'e': ?employee},
        orderBy: 'payment_date, uuid');
    return jsonResponse({'payments': [for (final r in rows) _json(user, r)]});
  }

  Future<Response> _settings(Request request) async {
    final user = await _reader(request, 'company_settings');
    final rows = await _rows.live(db.execute, _t('company_settings'),
        orderBy: 'updated_at DESC');
    return jsonResponse({'settings': rows.isEmpty ? null : _json(user, rows.first)});
  }

  // ---------------------------------------------------------- служебное

  static SyncTable _t(String name) => syncTableByName(name)!;

  Future<User> _accountant(Request request) async {
    final user = await auth.requireUser(request);
    if (user.role == Role.operator) throw forbidden;
    return user;
  }

  Future<User> _reader(Request request, String table) async {
    final user = await auth.requireUser(request);
    if (!readableTables(user.role).contains(table)) throw forbidden;
    return user;
  }

  static Map<String, Object?> _json(User user, SyncChange row) {
    final hidden = hiddenColumns(user.role, row.table);
    return {
      'uuid': row.uuid,
      'updated_at': formatSyncTimestamp(row.updatedAt),
      'edited_by': row.editedBy,
      for (final e in row.data.entries)
        e.key: hidden.contains(e.key) ? 0.0 : e.value,
    };
  }

  static (int, int) _yearMonth(Request request) {
    final q = request.url.queryParameters;
    final year = int.tryParse(q['year'] ?? ''), month = int.tryParse(q['month'] ?? '');
    if (year == null || month == null || year < 1900 || year > 2200 || month < 1 || month > 12) {
      throw const ApiException(400, 'validation', 'Нужны параметры year и month');
    }
    return (year, month);
  }

  static String? _dateParam(Request request, String name) {
    final value = request.url.queryParameters[name];
    if (value == null || value.isEmpty) return null;
    if (!isIsoDay(value)) {
      throw ApiException(400, 'validation', '$name — день в формате гггг-мм-дд');
    }
    return value;
  }

  static String? _uuidParam(Request request, String name) {
    final value = request.url.queryParameters[name];
    if (value == null || value.isEmpty) return null;
    if (!isCanonicalUuid(value)) {
      throw ApiException(400, 'validation', '$name — uuid');
    }
    return value;
  }
}
