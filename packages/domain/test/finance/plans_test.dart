import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  final rent = FinPlan(
    id: 'rent',
    type: OperationType.expense,
    amount: 1000000,
    startDate: DateTime(2026, 1, 31),
    repeat: PlanRepeat.monthly,
    untilDate: DateTime(2026, 6, 30),
  );

  group('дни плана', () {
    test('каждый месяц: 31-е в коротком месяце — последний день', () {
      expect(rent.daysBetween(DateTime(2026, 1, 1), DateTime(2026, 4, 30)), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('до дня окончания включительно, с начала отбора', () {
      // Июньский раз — 30.06 (31-го нет), это и день окончания.
      expect(rent.daysBetween(DateTime(2026, 5, 1), DateTime(2027, 1, 1)), [
        DateTime(2026, 5, 31),
        DateTime(2026, 6, 30),
      ]);
    });

    test('раз в квартал и разово', () {
      final tax = FinPlan(
        id: 'tax',
        type: OperationType.expense,
        amount: 5000,
        startDate: DateTime(2026, 1, 25),
        repeat: PlanRepeat.quarterly,
      );
      expect(tax.daysBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), [
        DateTime(2026, 1, 25),
        DateTime(2026, 4, 25),
        DateTime(2026, 7, 25),
        DateTime(2026, 10, 25),
      ]);
      final once = FinPlan(
        id: 'once',
        type: OperationType.income,
        amount: 5000,
        startDate: DateTime(2026, 3, 3),
      );
      expect(once.daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), [
        DateTime(2026, 3, 3),
      ]);
      expect(once.daysBetween(DateTime(2026, 4, 1), DateTime(2026, 4, 30)), []);
    });
  });

  test('ссылка оплаты: туда и обратно', () {
    final ref = planSourceRef('0190-abc', DateTime(2026, 2, 28));
    expect(ref, 'plan:0190-abc:2026-02-28');
    expect(parsePlanSourceRef(ref), ('0190-abc', DateTime(2026, 2, 28)));
    expect(parsePlanSourceRef('bank:1'), isNull);
    expect(parsePlanSourceRef(null), isNull);
  });

  test('оплаченные, пропущенные и закрытые разы', () {
    final plan = rent.copyWith(skipped: {DateTime(2026, 3, 31)});
    final paid = FinOperation(
      id: 'op',
      date: DateTime(2026, 2, 27),
      type: OperationType.expense,
      amount: 1000000,
      accountId: 'cash',
      sourceRef: planSourceRef('rent', DateTime(2026, 2, 28)),
    );
    final list = planOccurrences(
      plans: [plan],
      operations: [paid],
      from: DateTime(2026, 2, 1),
      to: DateTime(2026, 4, 30),
    );
    expect(
      [for (final o in list) (o.day.month, o.open)],
      [(2, false), (3, false), (4, true)],
    );
    expect(list.first.payment?.id, 'op');
    expect(list[1].skipped, isTrue);

    final closed = planOccurrences(
      plans: [plan.copyWith(closed: true)],
      operations: [paid],
      from: DateTime(2026, 2, 1),
      to: DateTime(2026, 4, 30),
    );
    expect(closed.map((o) => o.day.month), [2], reason: 'только оплаченный');
  });

  test('прогноз: просроченное — сегодня, первый день нехватки', () {
    final income = FinPlan(
      id: 'meat',
      type: OperationType.income,
      amount: 3000000,
      startDate: DateTime(2026, 4, 20),
    );
    final occurrences = planOccurrences(
      plans: [rent, income],
      operations: const [],
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 5, 31),
    );
    final forecast = paymentForecast(
      today: DateTime(2026, 4, 10),
      money: 500000,
      occurrences: occurrences,
    );
    expect(
      [for (final d in forecast) (d.day, d.balance)],
      [
        // 31.03 просрочен — переносится на сегодня.
        (DateTime(2026, 4, 10), -500000),
        (DateTime(2026, 4, 20), 2500000),
        (DateTime(2026, 4, 30), 1500000),
        (DateTime(2026, 5, 31), 500000),
      ],
    );
    expect(firstShortfall(forecast)?.day, DateTime(2026, 4, 10));
  });

  test('проверка плана', () {
    expect(planProblem(rent), isNull);
    expect(planProblem(rent.copyWith(amount: 0)), contains('больше нуля'));
    expect(
      planProblem(rent.copyWith(untilDate: () => DateTime(2025, 12, 31))),
      contains('раньше'),
    );
    expect(
      planProblem(rent.copyWith(type: OperationType.transfer)),
      contains('поступление или платёж'),
    );
  });
}
