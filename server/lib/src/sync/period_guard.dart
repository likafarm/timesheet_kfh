import 'package:kfh_domain/kfh_domain.dart';

/// Закрытые месяцы: изменение, которое меняет что-либо в закрытом месяце,
/// сервер отклоняет.
///
/// «Меняет в месяце» считается по датам записи:
/// - табель — день, выплата — день выплаты, расчёт — его месяц;
/// - больничный и отпуск — от начала до конца;
/// - ставка — от начала до конца (без конца — бессрочно).
///
/// Если у записи поменялись только границы, затронуты лишь дни, которые
/// вошли в период или вышли из него. Поэтому закрытие прежней ставки
/// (end_date = день перед новой) проходит, если новая ставка начинается в
/// открытом месяце, хотя сама прежняя ставка начиналась в закрытом. Любая
/// другая правка (суммы, заметки, удаление) затрагивает весь период записи.
/// Сотрудники и реквизиты к месяцам не привязаны.
class PeriodGuard {
  /// Закрытые месяцы: год * 12 + (месяц - 1).
  final Set<int> lockedMonths;

  PeriodGuard(this.lockedMonths);

  static int monthKey(int year, int month) => year * 12 + month - 1;

  /// Первый закрытый месяц, который задевает переход записи из [before] в
  /// [after] (null — записи не было), в виде (год, месяц); null — не
  /// задевает.
  (int, int)? violation(String table, Map<String, Object?>? before,
      bool beforeDeleted, Map<String, Object?> after, bool afterDeleted) {
    if (lockedMonths.isEmpty) return null;
    final oldRange =
        before == null || beforeDeleted ? null : _range(table, before);
    final newRange = afterDeleted ? null : _range(table, after);
    if (oldRange == null && newRange == null) return null;

    final List<_Days> affected;
    if (oldRange != null &&
        newRange != null &&
        _onlyBoundsChanged(table, before!, after)) {
      affected = _symmetricDifference(oldRange, newRange);
    } else {
      affected = [?oldRange, ?newRange];
    }

    // Проверяем закрытые месяцы по возрастанию — сообщение о самом раннем.
    final months = lockedMonths.toList()..sort();
    for (final key in months) {
      final year = key ~/ 12, month = key % 12 + 1;
      final month_ = _Days(_day(DateTime.utc(year, month, 1)),
          _day(DateTime.utc(year, month + 1, 0)));
      if (affected.any((r) => r.intersects(month_))) return (year, month);
    }
    return null;
  }

  static _Days? _range(String table, Map<String, Object?> data) {
    int day(String column) => _day(DateTime.parse(data[column] as String));
    switch (table) {
      case 'timesheet':
        return _Days(day('date'), day('date'));
      case 'payments':
        return _Days(day('payment_date'), day('payment_date'));
      case 'payroll_results':
        final year = data['year'] as int, month = data['month'] as int;
        return _Days(_day(DateTime.utc(year, month, 1)),
            _day(DateTime.utc(year, month + 1, 0)));
      case 'employee_rates':
        return _Days(day('start_date'),
            data['end_date'] == null ? _infinity : day('end_date'));
      case 'sick_leave':
      case 'vacation':
        return _Days(day('start_date'), day('end_date'));
      default:
        return null;
    }
  }

  static const _bounds = <String, Set<String>>{
    'employee_rates': {'start_date', 'end_date'},
    'sick_leave': {'start_date', 'end_date'},
    'vacation': {'start_date', 'end_date'},
  };

  static bool _onlyBoundsChanged(
      String table, Map<String, Object?> before, Map<String, Object?> after) {
    final bounds = _bounds[table];
    if (bounds == null) return false;
    final columns = syncTableByName(table)!.columnNames;
    return columns.every((c) => bounds.contains(c) || before[c] == after[c]);
  }
}

const _infinity = 1 << 40;

int _day(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// Отрезок дней [from, to] включительно.
class _Days {
  final int from;
  final int to;

  const _Days(this.from, this.to);

  bool intersects(_Days other) => from <= other.to && other.from <= to;
}

/// Дни, которые входят ровно в один из отрезков: (a \ b) ∪ (b \ a).
List<_Days> _symmetricDifference(_Days a, _Days b) =>
    [..._subtract(a, b), ..._subtract(b, a)];

/// Дни [x], не входящие в [y]: ноль, один или два куска.
List<_Days> _subtract(_Days x, _Days y) {
  if (!x.intersects(y)) return [x];
  return [
    if (x.from < y.from) _Days(x.from, y.from - 1),
    if (x.to > y.to) _Days(y.to + 1, x.to),
  ];
}
