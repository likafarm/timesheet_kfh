// История ставок сотрудника как последовательность периодов: добавление,
// изменение и удаление ставки с согласованием соседних периодов.
//
// Правила:
// - у сотрудника не бывает двух ставок с одной датой начала;
// - ставки не пересекаются: предыдущая заканчивается накануне следующей;
// - меняются только затронутые соседи, остальные периоды (в том числе в
//   закрытых месяцах) не трогаются;
// - дату окончания задают только у последней ставки (например, при
//   увольнении); у остальных она следует из начала следующей.
//
// Функции ничего не записывают: они возвращают список правок строк
// ([RateChange]) — его проверяют на закрытые месяцы и записывают одной
// транзакцией.

import 'models/employee_rate.dart';
import 'utils/date_utils.dart';

/// Правка одной строки ставок: [before] = null — новая ставка, [after] =
/// null — удаление.
class RateChange {
  final EmployeeRate? before;
  final EmployeeRate? after;

  const RateChange({this.before, this.after});

  bool get isInsert => before == null;
  bool get isDelete => after == null;

  @override
  String toString() => 'RateChange($before -> $after)';
}

/// Правку нельзя выполнить; [message] — для человека.
class RateTimelineException implements Exception {
  final String message;
  const RateTimelineException(this.message);

  @override
  String toString() => message;
}

String _d(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.'
    '${day.month.toString().padLeft(2, '0')}.${day.year}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dayBefore(DateTime day) => addCalendarDays(calendarDay(day), -1);

List<EmployeeRate> _sorted(List<EmployeeRate> history) =>
    [...history]..sort((a, b) => a.startDate.compareTo(b.startDate));

void _checkAmounts(EmployeeRate rate) {
  if (rate.baseRate < 0 || rate.fieldRate < 0) {
    throw const RateTimelineException('Ставка не может быть отрицательной');
  }
}

void _checkEnd(EmployeeRate rate) {
  final end = rate.endDate;
  if (end != null && end.isBefore(calendarDay(rate.startDate))) {
    throw RateTimelineException(
      'Дата окончания (${_d(end)}) раньше даты начала '
      '(${_d(rate.startDate)})',
    );
  }
}

/// Ставка, действующая на [day]; при пересечении — с более поздним началом.
EmployeeRate? rateOn(List<EmployeeRate> history, DateTime day) {
  final d = calendarDay(day);
  EmployeeRate? found;
  for (final r in _sorted(history)) {
    final end = r.endDate;
    if (!calendarDay(r.startDate).isAfter(d) &&
        (end == null || !calendarDay(end).isBefore(d))) {
      found = r;
    }
  }
  return found;
}

/// Добавить ставку [rate] (без id): предыдущая ставка заканчивается накануне
/// её начала; новая действует до начала следующей (если следующей нет — до
/// конца предыдущей или бессрочно).
List<RateChange> planAddRate(List<EmployeeRate> history, EmployeeRate rate) {
  _checkAmounts(rate);
  final start = calendarDay(rate.startDate);
  final rates = _sorted(history);
  if (rates.any((r) => _sameDay(r.startDate, start))) {
    throw RateTimelineException(
      'Ставка с ${_d(start)} уже есть — измените её или выберите другую дату',
    );
  }
  final previous = rates.where((r) => r.startDate.isBefore(start)).lastOrNull;
  final next = rates.where((r) => r.startDate.isAfter(start)).firstOrNull;

  if (next != null && rate.endDate != null) {
    throw RateTimelineException(
      'После ${_d(start)} уже есть ставка (с ${_d(next.startDate)}): новая '
      'будет действовать до неё — дату окончания не указывайте',
    );
  }
  final changes = <RateChange>[];
  DateTime? end;
  if (next != null) {
    end = _dayBefore(next.startDate);
  } else if (rate.endDate != null) {
    end = calendarDay(rate.endDate!);
  } else if (previous?.endDate != null && !previous!.endDate!.isBefore(start)) {
    // Последняя ставка была закрыта (например, при увольнении) — новая
    // закрывается той же датой.
    end = previous.endDate;
  }
  if (previous != null) {
    final prevEnd = previous.endDate;
    if (prevEnd == null || !prevEnd.isBefore(start)) {
      changes.add(
        RateChange(
          before: previous,
          after: previous.copyWith(endDate: _dayBefore(start)),
        ),
      );
    }
  }
  final added = EmployeeRate(
    employeeId: rate.employeeId,
    baseRate: rate.baseRate,
    fieldRate: rate.fieldRate,
    startDate: start,
    endDate: end,
  );
  _checkEnd(added);
  changes.add(RateChange(after: added));
  return changes;
}

/// Изменить ставку: суммы — как угодно; дату начала — в пределах между
/// соседними ставками (предыдущая сдвигается следом); дату окончания — только
/// у последней ставки.
List<RateChange> planUpdateRate(
  List<EmployeeRate> history,
  EmployeeRate updated,
) {
  _checkAmounts(updated);
  final rates = _sorted(history);
  final index = rates.indexWhere((r) => r.id == updated.id);
  if (index < 0) {
    throw const RateTimelineException('Ставка не найдена — обновите список');
  }
  final current = rates[index];
  final previous = index > 0 ? rates[index - 1] : null;
  final next = index + 1 < rates.length ? rates[index + 1] : null;
  final start = calendarDay(updated.startDate);

  if (previous != null && !start.isAfter(previous.startDate)) {
    throw RateTimelineException(
      'Дата начала должна быть позже начала предыдущей ставки '
      '(${_d(previous.startDate)})',
    );
  }
  if (next != null && !start.isBefore(next.startDate)) {
    throw RateTimelineException(
      'Дата начала должна быть раньше начала следующей ставки '
      '(${_d(next.startDate)})',
    );
  }
  final end = updated.endDate == null ? null : calendarDay(updated.endDate!);
  if (next != null && !_sameDayOrNull(end, current.endDate)) {
    throw const RateTimelineException(
      'Дату окончания можно задать только у последней ставки: у остальных '
      'она — накануне начала следующей',
    );
  }

  final after = EmployeeRate(
    id: current.id,
    employeeId: current.employeeId,
    baseRate: updated.baseRate,
    fieldRate: updated.fieldRate,
    startDate: start,
    endDate: next != null ? current.endDate : end,
  );
  _checkEnd(after);

  final changes = <RateChange>[];
  if (previous != null && !_sameDay(start, current.startDate)) {
    final prevEnd = previous.endDate;
    // Предыдущая шла вплотную (или теперь пересекается) — сдвигается
    // следом; если между ними был промежуток без ставки, он сохраняется.
    final adjacent =
        prevEnd == null || _sameDay(prevEnd, _dayBefore(current.startDate));
    if (adjacent || !prevEnd.isBefore(start)) {
      changes.add(
        RateChange(
          before: previous,
          after: previous.copyWith(endDate: _dayBefore(start)),
        ),
      );
    }
  }
  if (!_same(current, after)) {
    changes.add(RateChange(before: current, after: after));
  }
  return changes;
}

/// Удалить ставку: её период переходит к предыдущей ставке, если та шла
/// вплотную; у первой ставки период просто освобождается (дни до следующей
/// ставки останутся без ставки).
List<RateChange> planDeleteRate(List<EmployeeRate> history, String rateId) {
  final rates = _sorted(history);
  final index = rates.indexWhere((r) => r.id == rateId);
  if (index < 0) {
    throw const RateTimelineException('Ставка не найдена — обновите список');
  }
  final current = rates[index];
  final previous = index > 0 ? rates[index - 1] : null;
  final changes = <RateChange>[];
  final prevEnd = previous?.endDate;
  if (previous != null &&
      prevEnd != null &&
      _sameDay(prevEnd, _dayBefore(current.startDate))) {
    final extended = EmployeeRate(
      id: previous.id,
      employeeId: previous.employeeId,
      baseRate: previous.baseRate,
      fieldRate: previous.fieldRate,
      startDate: previous.startDate,
      endDate: current.endDate,
    );
    changes.add(RateChange(before: previous, after: extended));
  }
  changes.add(RateChange(before: current));
  return changes;
}

bool _sameDayOrNull(DateTime? a, DateTime? b) =>
    (a == null && b == null) || (a != null && b != null && _sameDay(a, b));

bool _same(EmployeeRate a, EmployeeRate b) =>
    a.baseRate == b.baseRate &&
    a.fieldRate == b.fieldRate &&
    _sameDay(a.startDate, b.startDate) &&
    _sameDayOrNull(a.endDate, b.endDate);
