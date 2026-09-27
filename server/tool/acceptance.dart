// Приёмка этапа 2 по HTTP — сценарии из DEVELOPMENT_PLAN.md:
//  1) вход под тремя ролями, запрещённое действие отклоняется понятной ошибкой;
//  2) push/pull: данные одного устройства приходят другому;
//  3) изменение табеля закрытого месяца отклоняется, после открытия — проходит;
//  4) клиент на базе, восстановленной из бэкапа, видит данные (pull с нуля,
//     расчёт ЗП сервера совпадает с сохранённым).
//
// Создаёт тестовых пользователей и записи — поэтому только на локальном
// стенде (копия базы из бэкапа), не на боевом сервере:
//
//   $env:KFH_ACC_URL="http://127.0.0.1:8091"; $env:KFH_ACC_ADMIN_LOGIN="ivan"
//   $env:KFH_ACC_ADMIN_PASSWORD="<пароль, заданный на копии>"
//   dart run tool/acceptance.dart
//
// Необязательно: KFH_ACC_EXPECT_ROWS — сколько записей должен отдать pull с нуля.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart';

late Uri base;
var failures = 0;

void check(bool ok, String what, [Object? details]) {
  stdout.writeln('${ok ? 'OK  ' : 'FAIL'} $what${ok || details == null ? '' : ' — $details'}');
  if (!ok) failures++;
}

class Api {
  final String? token;
  final String device;
  Api(this.token, {this.device = 'acceptance'});

  Future<(int, dynamic)> call(String method, String path, [Object? body]) async {
    final request = http.Request(method, base.resolve(path))
      ..headers.addAll({
        'content-type': 'application/json; charset=utf-8',
        'x-device-id': device,
        if (token != null) 'authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send());
    final text = utf8.decode(response.bodyBytes);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }
}

String? errorCode(dynamic json) {
  if (json is! Map) return null;
  final error = json['error'];
  return error is Map ? error['code'] as String? : null;
}

Future<String> login(String login, String password) async {
  final (s, j) = await Api(null).call(
      'POST', '/auth/login', {'login': login, 'password': password});
  if (s != 200) throw StateError('вход $login: $s $j');
  return j['access_token'] as String;
}

/// Pull до конца; возвращает (курсор, эпоха, изменения).
Future<(int, String, List<Map<String, dynamic>>)> pullAll(Api api,
    {int cursor = 0, String? epoch}) async {
  final changes = <Map<String, dynamic>>[];
  while (true) {
    final query = 'cursor=$cursor${epoch == null ? '' : '&epoch=$epoch'}&limit=1000';
    final (s, j) = await api.call('GET', '/sync/pull?$query');
    if (s != 200) throw StateError('pull: $s $j');
    changes.addAll((j['changes'] as List).cast<Map<String, dynamic>>());
    cursor = j['cursor'] as int;
    epoch = j['epoch'] as String;
    if (j['has_more'] != true) return (cursor, epoch, changes);
  }
}

Future<void> main() async {
  final env = Platform.environment;
  base = Uri.parse(env['KFH_ACC_URL'] ?? 'http://127.0.0.1:8091');
  if (!{'127.0.0.1', 'localhost'}.contains(base.host)) {
    stderr.writeln('Приёмка пишет тестовые данные — только локальный стенд, не ${base.host}');
    exit(2);
  }
  final adminLogin = env['KFH_ACC_ADMIN_LOGIN'] ?? 'ivan';
  final adminPassword = env['KFH_ACC_ADMIN_PASSWORD'] ??
      (throw StateError('нет KFH_ACC_ADMIN_PASSWORD'));
  final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  // uuid записей приёмки: узнаваемое начало, уникальный хвост (hex).
  final tail = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
  String testUuid(int n) => '01999999-0000-7000-800$n-${tail.substring(tail.length - 12)}';

  // ------------------------------------------------ 1. роли
  stdout.writeln('\n== 1. Вход под тремя ролями и права');
  final (bs, bj) = await Api(null)
      .call('POST', '/auth/login', {'login': adminLogin, 'password': 'wrong-password-x'});
  check(bs == 401 && errorCode(bj) == 'invalid_credentials',
      'неверный пароль → 401 invalid_credentials', '$bs $bj');

  final admin = Api(await login(adminLogin, adminPassword));
  var (s, j) = await admin.call('GET', '/auth/me');
  check(s == 200 && j['role'] == 'admin', 'админ вошёл, /auth/me', '$s $j');

  final tokens = <String, String>{};
  for (final role in ['accountant', 'operator']) {
    final userLogin = 'acc_${role}_$suffix';
    (s, j) = await admin.call('POST', '/users', {
      'login': userLogin,
      'full_name': 'Приёмка $role',
      'role': role,
      'password': 'temp-pass-$suffix',
    });
    check(s == 201, 'админ создал пользователя $role', '$s $j');
    final temp = Api(await login(userLogin, 'temp-pass-$suffix'));
    (s, j) = await temp.call('GET', '/employees');
    check(s == 403 && errorCode(j) == 'password_change_required',
        '$role с паролем от админа: сначала смена пароля (403 password_change_required)',
        '$s $j');
    (s, j) = await temp.call('POST', '/auth/change-password',
        {'old_password': 'temp-pass-$suffix', 'new_password': 'real-pass-$suffix'});
    check(s == 200, '$role сменил пароль', '$s $j');
    tokens[role] = await login(userLogin, 'real-pass-$suffix');
    check(true, '$role вошёл с новым паролем');
  }
  final accountant = Api(tokens['accountant'], device: 'acc-pc-$suffix');
  final operator = Api(tokens['operator'], device: 'acc-tablet-$suffix');

  (s, j) = await operator.call('GET', '/employees?active_on=2026-10-01');
  final employees = (j['employees'] as List).cast<Map<String, dynamic>>();
  check(s == 200 && employees.isNotEmpty, 'оператор видит сотрудников (${employees.length})', '$s');
  check(employees.every((e) => e['base_rate'] == 0 && e['field_rate'] == 0),
      'оператору ставки приходят нулями');

  for (final (who, api, method, path, body) in [
    ('оператор', operator, 'GET', '/users', null),
    ('оператор', operator, 'POST', '/payroll/calculate', {'year': 2026, 'month': 9}),
    ('оператор', operator, 'GET', '/payments', null),
    ('бухгалтер', accountant, 'GET', '/users', null),
    ('бухгалтер', accountant, 'POST', '/users',
        {'login': 'x_$suffix', 'full_name': 'X', 'role': 'admin', 'password': 'p-$suffix-1'}),
  ]) {
    (s, j) = await api.call(method, path, body);
    check(s == 403 && errorCode(j) == 'forbidden' && (j['error']['message'] as String).isNotEmpty,
        '$who: $method $path → 403 forbidden «${j?['error']?['message']}»', '$s $j');
  }

  // Оператор не может записать выплату через синхронизацию.
  final emp = employees.first;
  final empUuid = emp['uuid'] as String;
  (s, j) = await operator.call('POST', '/sync/push', {
    'changes': [
      SyncChange(
        table: 'payments',
        uuid: testUuid(0),
        updatedAt: DateTime.now().toUtc(),
        deleted: false,
        changeId: 'op-payment',
        data: {
          'legacy_id': null,
          'employee_uuid': empUuid,
          'payment_date': '2026-10-05',
          'amount': 100.0,
          'payment_type': 'advance',
          'period_start': null,
          'period_end': null,
          'payment_method': 'cash',
          'document_number': null,
          'notes': 'приёмка',
          'created_at': '2026-10-05T10:00:00',
        },
      ).toJson()
    ]
  });
  final opPay = (j['results'] as List).first as Map;
  check(opPay['status'] == 'rejected' && opPay['code'] == 'forbidden',
      'оператор: push выплаты → rejected forbidden', opPay);

  // ------------------------------------------------ 2. push/pull
  stdout.writeln('\n== 2. Push/pull между устройствами');
  var (accCursor, accEpoch, _) = await pullAll(accountant);
  // Свободный день: 10.2026, которого нет в табеле сотрудника.
  (s, j) = await accountant.call(
      'GET', '/timesheet?year=2026&month=10&employee_uuid=$empUuid');
  final busy = {for (final r in (j['timesheet'] as List)) r['date']};
  final date = [for (var d = 1; d <= 31; d++) '2026-10-${d.toString().padLeft(2, '0')}']
      .firstWhere((d) => !busy.contains(d));
  final dayUuid = testUuid(1);

  Map<String, Object?> day(String notes, {double days = 1}) => SyncChange(
        table: 'timesheet',
        uuid: dayUuid,
        updatedAt: DateTime.now().toUtc(),
        deleted: false,
        changeId: 'day-$notes',
        data: {
          'legacy_id': null,
          'employee_uuid': empUuid,
          'date': date,
          'day_type': 'work',
          'days': days,
          'work_place': 'field',
          'notes': notes,
          'created_at': '${date}T08:00:00',
        },
      ).toJson();

  (s, j) = await operator.call('POST', '/sync/push', {'changes': [day('с планшета «поле»')]});
  final pushed = (j['results'] as List).first as Map;
  check(s == 200 && pushed['status'] == 'applied', 'оператор (планшет) записал день $date', '$s $j');

  var (c2, _, got) = await pullAll(accountant, cursor: accCursor, epoch: accEpoch);
  var mine = got.where((c) => c['uuid'] == dayUuid).toList();
  check(mine.length == 1 && mine.single['data']['notes'] == 'с планшета «поле»' &&
          mine.single['data']['date'] == date,
      'бухгалтер (ПК) получил день pull’ом, поля совпадают', got);
  accCursor = c2;

  await Future<void>.delayed(const Duration(milliseconds: 5));
  (s, j) = await accountant.call('POST', '/sync/push', {'changes': [day('исправлено на ПК', days: 0.5)]});
  check((j['results'] as List).first['status'] == 'applied', 'бухгалтер исправил день', j);
  final (_, _, opGot) = await pullAll(operator);
  mine = opGot.where((c) => c['uuid'] == dayUuid).toList();
  check(mine.length == 1 && mine.single['data']['notes'] == 'исправлено на ПК' &&
          mine.single['data']['days'] == 0.5,
      'оператор получил исправление обратно', mine);

  (s, j) = await operator.call('POST', '/sync/push', {'changes': [mine.single]});
  check((j['results'] as List).first['status'] == 'duplicate',
      'повторная отправка той же версии → duplicate', j);

  // ------------------------------------------------ 3. закрытый месяц
  stdout.writeln('\n== 3. Закрытый месяц');
  (s, j) = await operator.call('POST', '/periods/locks', {'year': 2026, 'month': 10});
  check(s == 403, 'оператор не может закрыть месяц (403)', '$s $j');
  (s, j) = await accountant.call(
      'POST', '/periods/locks', {'year': 2026, 'month': 10, 'note': 'приёмка'});
  check(s == 201, 'бухгалтер закрыл 10.2026', '$s $j');
  await Future<void>.delayed(const Duration(milliseconds: 5));
  (s, j) = await operator.call('POST', '/sync/push', {'changes': [day('в закрытом месяце')]});
  final locked = (j['results'] as List).first as Map;
  check(locked['status'] == 'rejected' && locked['code'] == 'period_locked',
      'правка табеля закрытого месяца → rejected period_locked «${locked['message']}»', locked);
  (s, j) = await accountant.call('DELETE', '/periods/locks/2026/10');
  check(s == 204, 'бухгалтер открыл 10.2026', '$s $j');
  await Future<void>.delayed(const Duration(milliseconds: 5));
  (s, j) = await operator.call('POST', '/sync/push', {'changes': [day('после открытия')]});
  check((j['results'] as List).first['status'] == 'applied',
      'после открытия правка проходит', j);
  // Прибрать за собой: день приёмки удаляется (мягко).
  await Future<void>.delayed(const Duration(milliseconds: 5));
  final removal = day('после открытия')..['deleted'] = true;
  (s, j) = await accountant.call('POST', '/sync/push', {'changes': [removal]});
  check((j['results'] as List).first['status'] == 'applied', 'день приёмки удалён', j);

  // ------------------------------------------------ 4. данные из бэкапа
  stdout.writeln('\n== 4. Клиент видит данные восстановленной базы');
  final (_, _, all) = await pullAll(Api(tokens['accountant'], device: 'fresh-$suffix'));
  final original = all.where((c) => !(c['uuid'] as String).startsWith('01999999-')).length;
  final byTable = <String, int>{};
  for (final c in all) {
    byTable[c['table'] as String] = (byTable[c['table']] ?? 0) + 1;
  }
  final expected = int.tryParse(env['KFH_ACC_EXPECT_ROWS'] ?? '');
  check(expected == null || original == expected,
      'pull с нуля: $original записей из базы ($byTable)', 'ожидалось $expected');
  for (final month in [7, 8, 9]) {
    (s, j) = await accountant.call('GET', '/payroll/calculation?year=2026&month=$month');
    final list = (j['employees'] as List).cast<Map<String, dynamic>>();
    // Сохранённые пустые строки от расчётов до 2026-09-26 допустимы: отчёт
    // их скрывает, пересчёт месяца удалит.
    final (_, report) = await accountant.call('GET', '/payroll?year=2026&month=$month');
    final inReport = {for (final r in report['results'] as List) r['employee_uuid']};
    final needed = list.where((e) => e['needed'] == true).toList();
    final stale = [
      for (final e in list)
        if (e['needed'] == true ? e['up_to_date'] != true : inReport.contains(e['employee_uuid']))
          e['full_name'],
    ];
    final leftovers = list.length - needed.length;
    check(s == 200 && needed.isNotEmpty && stale.isEmpty,
        'расчёт ЗП сервера за ${month.toString().padLeft(2, '0')}.2026 совпадает с сохранённым '
        '(${needed.length} сотр.${leftovers > 0 ? '; пустых старых строк, скрытых из отчёта: $leftovers' : ''})',
        stale);
  }

  stdout.writeln(failures == 0 ? '\nПРИЁМКА ПРОЙДЕНА' : '\nНЕ ПРОЙДЕНО: $failures');
  exit(failures == 0 ? 0 : 1);
}
