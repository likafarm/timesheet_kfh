// packages/domain/lib/src/finance/plans.dart
//
// Платёжный календарь (этап 8Б.4): плановые поступления и платежи (аренда,
// кредит, налоги, ожидаемая оплата покупателя) — разово или с повтором.
// Оплата плана — обычная операция со ссылкой на план и день
// ([planSourceRef]); пропущенный день — в самом плане. Прогноз остатка
// денег по дням — [paymentForecast].

import '../utils/date_utils.dart';
import 'models.dart';

/// Повтор плана.
enum PlanRepeat {
  none('none', 'Разово', 0),
  monthly('monthly', 'Каждый месяц', 1),
  quarterly('quarterly', 'Раз в квартал', 3),
  yearly('yearly', 'Раз в год', 12);

  const PlanRepeat(this.code, this.title, this.months);
  final String code;
  final String title;

  /// Шаг в месяцах; 0 — без повтора.
  final int months;

  static PlanRepeat fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Плановое поступление ([OperationType.income]) или платёж
/// ([OperationType.expense]).
class FinPlan {
  final String id;
  final OperationType type;
  final int amount;

  /// День первого раза; повтор — в тот же день месяца (31-е в коротком
  /// месяце — последний день).
  final DateTime startDate;
  final PlanRepeat repeat;

  /// Последний день повторов включительно; null — бессрочно.
  final DateTime? untilDate;
  final String? accountId;
  final String? categoryId;
  final String? counterpartyId;
  final String? description;

  /// Дни, которые не нужно платить («Пропустить»).
  final Set<DateTime> skipped;
  final bool closed;

  const FinPlan({
    required this.id,
    required this.type,
    required this.amount,
    required this.startDate,
    this.repeat = PlanRepeat.none,
    this.untilDate,
    this.accountId,
    this.categoryId,
    this.counterpartyId,
    this.description,
    this.skipped = const {},
    this.closed = false,
  });

  FinPlan copyWith({
    OperationType? type,
    int? amount,
    DateTime? startDate,
    PlanRepeat? repeat,
    DateTime? Function()? untilDate,
    String? Function()? accountId,
    String? Function()? categoryId,
    String? Function()? counterpartyId,
    String? Function()? description,
    Set<DateTime>? skipped,
    bool? closed,
  }) => FinPlan(
    id: id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    startDate: startDate ?? this.startDate,
    repeat: repeat ?? this.repeat,
    untilDate: untilDate == null ? this.untilDate : untilDate(),
    accountId: accountId == null ? this.accountId : accountId(),
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    counterpartyId: counterpartyId == null
        ? this.counterpartyId
        : counterpartyId(),
    description: description == null ? this.description : description(),
    skipped: skipped ?? this.skipped,
    closed: closed ?? this.closed,
  );

  /// Дни плана с [from] по [to] включительно (без учёта оплат и пропусков).
  List<DateTime> daysBetween(DateTime from, DateTime to) {
    final f = calendarDay(from), t = calendarDay(to);
    final start = calendarDay(startDate);
    final until = untilDate == null ? null : calendarDay(untilDate!);
    final result = <DateTime>[];
    if (repeat == PlanRepeat.none) {
      if (!start.isBefore(f) && !start.isAfter(t)) result.add(start);
      return result;
    }
    for (var i = 0; ; i++) {
      final m = DateTime(start.year, start.month + i * repeat.months);
      final last = DateTime(m.year, m.month + 1, 0).day;
      final day = DateTime(m.year, m.month, start.day.clamp(1, last));
      if (day.isAfter(t) || (until != null && day.isAfter(until))) break;
      if (!day.isBefore(f)) result.add(day);
    }
    return result;
  }
}

/// Почему план не записать; null — можно.
String? planProblem(FinPlan p) {
  if (p.type != OperationType.income && p.type != OperationType.expense) {
    return 'План — поступление или платёж';
  }
  if (p.amount <= 0) return 'Сумма плана должна быть больше нуля';
  final until = p.untilDate;
  if (until != null && calendarDay(until).isBefore(calendarDay(p.startDate))) {
    return 'Повторять до дня раньше первого платежа';
  }
  return null;
}

/// Ссылка операции на оплаченный день плана (`FinOperation.sourceRef`).
String planSourceRef(String planId, DateTime day) =>
    'plan:$planId:${formatDateIso(calendarDay(day))}';

/// (id плана, день) из ссылки операции; null — операция не из плана.
(String, DateTime)? parsePlanSourceRef(String? ref) {
  if (ref == null || !ref.startsWith('plan:')) return null;
  final rest = ref.substring(5);
  final i = rest.lastIndexOf(':');
  if (i <= 0) return null;
  final day = DateTime.tryParse(rest.substring(i + 1));
  return day == null ? null : (rest.substring(0, i), calendarDay(day));
}

/// Один раз плана.
class PlanOccurrence {
  final FinPlan plan;
  final DateTime day;

  /// Операция оплаты; null — не оплачено.
  final FinOperation? payment;
  final bool skipped;

  const PlanOccurrence(
    this.plan,
    this.day, {
    this.payment,
    this.skipped = false,
  });

  bool get open => payment == null && !skipped;

  /// Приход — плюс, уход — минус.
  int get signedAmount =>
      plan.type == OperationType.income ? plan.amount : -plan.amount;
}

/// Разы планов с [from] по [to]: оплаченные (операцией со ссылкой) и
/// пропущенные отмечены. Закрытые планы — только оплаченные разы.
List<PlanOccurrence> planOccurrences({
  required Iterable<FinPlan> plans,
  required Iterable<FinOperation> operations,
  required DateTime from,
  required DateTime to,
}) {
  final paid = <String, FinOperation>{};
  for (final op in operations) {
    final ref = parsePlanSourceRef(op.sourceRef);
    if (ref != null) paid[planSourceRef(ref.$1, ref.$2)] = op;
  }
  final result = <PlanOccurrence>[];
  for (final p in plans) {
    final skipped = {for (final d in p.skipped) calendarDay(d)};
    for (final day in p.daysBetween(from, to)) {
      final payment = paid[planSourceRef(p.id, day)];
      if (p.closed && payment == null) continue;
      result.add(
        PlanOccurrence(
          p,
          day,
          payment: payment,
          skipped: skipped.contains(day),
        ),
      );
    }
  }
  result.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    return byDay != 0 ? byDay : a.plan.id.compareTo(b.plan.id);
  });
  return result;
}

/// День прогноза.
class ForecastDay {
  final DateTime day;
  final List<PlanOccurrence> items;

  /// Остаток денег на конец дня.
  final int balance;

  const ForecastDay(this.day, this.items, this.balance);

  int get flow => items.fold(0, (s, o) => s + o.signedAmount);
}

/// Прогноз денег с [today] на [days] дней: [money] — деньги на сегодня
/// (все кошельки); неоплаченные разы планов уменьшают или увеличивают
/// остаток в свой день, просроченные — сегодня. В списке — только дни с
/// платежами (сегодня — всегда).
List<ForecastDay> paymentForecast({
  required DateTime today,
  required int money,
  required List<PlanOccurrence> occurrences,
  int days = 60,
}) {
  final t = calendarDay(today);
  final end = addCalendarDays(t, days);
  final byDay = <DateTime, List<PlanOccurrence>>{};
  for (final o in occurrences) {
    if (!o.open || o.day.isAfter(end)) continue;
    final d = o.day.isBefore(t) ? t : o.day;
    (byDay[d] ??= []).add(o);
  }
  var balance = money;
  final result = <ForecastDay>[];
  for (final d in [t, ...byDay.keys.where((d) => d != t).toList()..sort()]) {
    final items = byDay[d] ?? const <PlanOccurrence>[];
    balance += items.fold(0, (s, o) => s + o.signedAmount);
    result.add(ForecastDay(d, items, balance));
  }
  return result;
}

/// Первый день прогноза, когда денег не хватает; null — хватает.
ForecastDay? firstShortfall(List<ForecastDay> forecast) {
  for (final d in forecast) {
    if (d.balance < 0) return d;
  }
  return null;
}

/// Пропущенные дни плана — в строку базы и обратно (`гггг-мм-дд,…`).
String? encodePlanSkipped(Set<DateTime> days) => days.isEmpty
    ? null
    : ([for (final d in days) formatDateIso(calendarDay(d))]..sort()).join(',');

Set<DateTime> decodePlanSkipped(String? text) => {
  for (final part in (text ?? '').split(','))
    if (DateTime.tryParse(part.trim()) case final d?) calendarDay(d),
};

/// Проверка строки плана при приёме (сервер): повторять до дня не раньше
/// первого раза.
String? planRowProblem(Map<String, Object?> data) {
  final start = DateTime.tryParse('${data['start_date']}');
  final until = data['until_date'] == null
      ? null
      : DateTime.tryParse('${data['until_date']}');
  if (start != null && until != null && until.isBefore(start)) {
    return 'Повторять до дня раньше первого платежа';
  }
  return null;
}
