import 'package:kfh_domain/kfh_domain.dart';

import '../auth/users.dart';
import '../payroll/payroll_calculator.dart';
import '../sql.dart';

/// Остаток сотрудника за месяц по сохранённым расчётам (как считает
/// сервер): на начало, начислено, выплачено; на конец = начало + начислено
/// − выплачено (он же остаток на начало следующего месяца).
class EmployeeMonthBalance {
  final String employeeUuid;
  final String fullName;
  final double starting;
  final double accrued;
  final double paid;

  const EmployeeMonthBalance(this.employeeUuid, this.fullName,
      {required this.starting, required this.accrued, required this.paid});

  double get closing => starting + accrued - paid;

  Map<String, Object?> toJson() => {
        'employee_uuid': employeeUuid,
        'full_name': fullName,
        'starting': _round(starting),
        'accrued': _round(accrued),
        'paid': _round(paid),
        'closing': _round(closing),
      };

  factory EmployeeMonthBalance.fromJson(Map<String, Object?> json) =>
      EmployeeMonthBalance(
        json['employee_uuid'] as String,
        json['full_name'] as String,
        starting: (json['starting'] as num).toDouble(),
        accrued: (json['accrued'] as num).toDouble(),
        paid: (json['paid'] as num).toDouble(),
      );

  /// Отличается от [other] больше чем на полкопейки.
  bool differsFrom(EmployeeMonthBalance? other) {
    if (other == null) return !isZero;
    bool diff(double a, double b) => (a - b).abs() >= balanceEpsilon;
    return diff(starting, other.starting) ||
        diff(accrued, other.accrued) ||
        diff(paid, other.paid);
  }

  bool get isZero =>
      starting.abs() < balanceEpsilon &&
      accrued.abs() < balanceEpsilon &&
      paid.abs() < balanceEpsilon;

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

/// Остатки по месяцам: ключ [PeriodGuard.monthKey] → сотрудник → остаток.
typedef BalanceTable = Map<int, Map<String, EmployeeMonthBalance>>;

/// Остатки по сохранённым расчётам с месяца [from] по [to] включительно
/// (ключи [PeriodGuard.monthKey]). В месяц входят сотрудники с ненулевым
/// остатком, начислением или выплатой либо с сохранённым расчётом.
Future<BalanceTable> balanceTable(
    SqlExecutor sql, PayrollCalculator payroll, int from, int to) async {
  final names = {
    for (final row in (await sql('SELECT uuid, full_name FROM employees')).rows)
      row.textOf('uuid'): row.textOf('full_name'),
  };
  final accrued = <(String, int), double>{};
  final saved = <(String, int)>{};
  final results = await sql(
      'SELECT employee_uuid, year, month, total_salary FROM payroll_results '
      'WHERE deleted = 0 AND year * 12 + month - 1 BETWEEN :from AND :to',
      {'from': from, 'to': to});
  for (final row in results.rows) {
    final key = (
      row.textOf('employee_uuid'),
      PeriodGuard.monthKey(row.intOf('year'), row.intOf('month')),
    );
    saved.add(key);
    accrued[key] = (accrued[key] ?? 0) + double.parse(row.textOf('total_salary'));
  }
  final paid = <(String, int), double>{};
  final payments = await sql(
      'SELECT employee_uuid, payment_date, amount FROM payments '
      'WHERE deleted = 0 AND payment_date BETWEEN :from AND :to',
      {
        'from': formatDateIso(DateTime(from ~/ 12, from % 12 + 1, 1)),
        'to': formatDateIso(DateTime(to ~/ 12, to % 12 + 2, 0)),
      });
  for (final row in payments.rows) {
    final d = parseDateIso(row.textOf('payment_date'));
    final key = (row.textOf('employee_uuid'), PeriodGuard.monthKey(d.year, d.month));
    paid[key] = (paid[key] ?? 0) + double.parse(row.textOf('amount'));
  }

  var starting = await payroll.startingBalances(sql, from ~/ 12, from % 12 + 1);
  final table = <int, Map<String, EmployeeMonthBalance>>{};
  for (var key = from; key <= to; key++) {
    final ids = {
      ...starting.keys,
      for (final k in accrued.keys) if (k.$2 == key) k.$1,
      for (final k in paid.keys) if (k.$2 == key) k.$1,
    };
    final month = <String, EmployeeMonthBalance>{};
    final next = <String, double>{};
    for (final id in ids) {
      final b = EmployeeMonthBalance(id, names[id] ?? id,
          starting: starting[id] ?? 0,
          accrued: accrued[(id, key)] ?? 0,
          paid: paid[(id, key)] ?? 0);
      next[id] = b.closing;
      if (!b.isZero || saved.contains((id, key))) month[id] = b;
    }
    table[key] = month;
    starting = next;
  }
  return table;
}

List<Map<String, Object?>> balanceTableJson(BalanceTable table) => [
      for (final key in table.keys.toList()..sort())
        {
          'year': key ~/ 12,
          'month': key % 12 + 1,
          'employees': [
            for (final b in _byName(table[key]!.values)) b.toJson(),
          ],
        },
    ];

/// Что изменит пересчёт: по месяцам — сотрудники, у которых остаток на
/// начало, начисление или выплаты станут другими, «было» и «станет».
List<Map<String, Object?>> balanceChangesJson(
        BalanceTable before, BalanceTable after) =>
    [
      for (final key in {...before.keys, ...after.keys}.toList()..sort())
        if (_changes(before[key] ?? const {}, after[key] ?? const {})
            case final changed when changed.isNotEmpty)
          {
            'year': key ~/ 12,
            'month': key % 12 + 1,
            'employees': changed,
          },
    ];

List<Map<String, Object?>> _changes(Map<String, EmployeeMonthBalance> before,
    Map<String, EmployeeMonthBalance> after) {
  final ids = {...before.keys, ...after.keys};
  final rows = <(String, Map<String, Object?>)>[];
  for (final id in ids) {
    final b = before[id], a = after[id];
    if (a == null ? b == null || b.isZero : !a.differsFrom(b)) continue;
    final name = (a ?? b)!.fullName;
    rows.add((
      name,
      {
        'employee_uuid': id,
        'full_name': name,
        'before': (b ?? EmployeeMonthBalance(id, name, starting: 0, accrued: 0, paid: 0))
            .toJson(),
        'after': (a ?? EmployeeMonthBalance(id, name, starting: 0, accrued: 0, paid: 0))
            .toJson(),
      }
    ));
  }
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  return [for (final r in rows) r.$2];
}

List<EmployeeMonthBalance> _byName(Iterable<EmployeeMonthBalance> items) =>
    items.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
