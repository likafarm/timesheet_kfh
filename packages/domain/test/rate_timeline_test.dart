import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

EmployeeRate _r(
  String id,
  DateTime start, {
  DateTime? end,
  double base = 1000,
  double field = 1500,
}) => EmployeeRate(
  id: id,
  employeeId: 'e1',
  baseRate: base,
  fieldRate: field,
  startDate: start,
  endDate: end,
);

/// Применяет правки к копии истории (как это сделает репозиторий).
List<EmployeeRate> _apply(List<EmployeeRate> history, List<RateChange> ch) {
  final result = [...history];
  var n = 0;
  for (final c in ch) {
    if (c.isInsert) {
      result.add(c.after!.copyWith(id: 'new${n++}'));
    } else {
      result.removeWhere((r) => r.id == c.before!.id);
      if (!c.isDelete) result.add(c.after!);
    }
  }
  result.sort((a, b) => a.startDate.compareTo(b.startDate));
  return result;
}

String _show(List<EmployeeRate> rates) => rates
    .map(
      (r) =>
          '${formatDateIso(r.startDate)}..${formatDateIsoOrNull(r.endDate) ?? '∞'}'
          ' ${r.baseRate.toStringAsFixed(0)}',
    )
    .join(' | ');

void main() {
  final history = [
    _r('a', DateTime(2026, 1, 1), end: DateTime(2026, 4, 30)),
    _r('b', DateTime(2026, 5, 1), base: 2000),
  ];

  group('добавление', () {
    test('новая последняя ставка закрывает действующую', () {
      final ch = planAddRate(
        history,
        _r('', DateTime(2026, 9, 1), base: 3000).copyWith(id: null),
      );
      expect(
        _show(_apply(history, ch)),
        '2026-01-01..2026-04-30 1000 | 2026-05-01..2026-08-31 2000 | '
        '2026-09-01..∞ 3000',
      );
      // Первая ставка не тронута.
      expect(ch.any((c) => c.before?.id == 'a'), isFalse);
    });

    test('ставка между двумя — до начала следующей', () {
      final ch = planAddRate(
        history,
        EmployeeRate(
          employeeId: 'e1',
          baseRate: 1500,
          fieldRate: 1500,
          startDate: DateTime(2026, 3, 1),
        ),
      );
      expect(
        _show(_apply(history, ch)),
        '2026-01-01..2026-02-28 1000 | 2026-03-01..2026-04-30 1500 | '
        '2026-05-01..∞ 2000',
      );
    });

    test('ставка раньше первой — до начала первой', () {
      final ch = planAddRate(
        history,
        EmployeeRate(
          employeeId: 'e1',
          baseRate: 500,
          fieldRate: 500,
          startDate: DateTime(2025, 12, 1),
        ),
      );
      expect(
        _show(_apply(history, ch)).split(' | ').first,
        '2025-12-01..2025-12-31 500',
      );
    });

    test(
      'последняя была закрыта (увольнение) — новая закрыта той же датой',
      () {
        final closed = [
          _r('a', DateTime(2026, 1, 1), end: DateTime(2026, 8, 31)),
        ];
        final ch = planAddRate(
          closed,
          EmployeeRate(
            employeeId: 'e1',
            baseRate: 2000,
            fieldRate: 2000,
            startDate: DateTime(2026, 6, 1),
          ),
        );
        expect(
          _show(_apply(closed, ch)),
          '2026-01-01..2026-05-31 1000 | 2026-06-01..2026-08-31 2000',
        );
      },
    );

    test('окончание у ставки перед следующей — отказ', () {
      expect(
        () => planAddRate(
          history,
          EmployeeRate(
            employeeId: 'e1',
            baseRate: 1,
            fieldRate: 1,
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 3, 31),
          ),
        ),
        throwsA(isA<RateTimelineException>()),
      );
    });

    test('та же дата начала — отказ', () {
      expect(
        () => planAddRate(
          history,
          EmployeeRate(
            employeeId: 'e1',
            baseRate: 1,
            fieldRate: 1,
            startDate: DateTime(2026, 5, 1),
          ),
        ),
        throwsA(isA<RateTimelineException>()),
      );
    });

    test('отрицательная ставка — отказ', () {
      expect(
        () => planAddRate(
          history,
          EmployeeRate(
            employeeId: 'e1',
            baseRate: -1,
            fieldRate: 1,
            startDate: DateTime(2026, 9, 1),
          ),
        ),
        throwsA(isA<RateTimelineException>()),
      );
    });
  });

  group('изменение', () {
    test('только суммы — одна правка', () {
      final ch = planUpdateRate(history, history[1].copyWith(baseRate: 2100));
      expect(ch, hasLength(1));
      expect(ch.single.after!.baseRate, 2100);
      expect(ch.single.after!.endDate, isNull);
    });

    test('сдвиг начала — предыдущая сдвигается следом', () {
      final ch = planUpdateRate(
        history,
        history[1].copyWith(startDate: DateTime(2026, 6, 1)),
      );
      expect(
        _show(_apply(history, ch)),
        '2026-01-01..2026-05-31 1000 | 2026-06-01..∞ 2000',
      );
    });

    test('начало не может перескочить соседа', () {
      expect(
        () => planUpdateRate(
          history,
          history[1].copyWith(startDate: DateTime(2026, 1, 1)),
        ),
        throwsA(isA<RateTimelineException>()),
      );
      expect(
        () => planUpdateRate(
          history,
          history[0].copyWith(startDate: DateTime(2026, 5, 1)),
        ),
        throwsA(isA<RateTimelineException>()),
      );
    });

    test('окончание — только у последней ставки', () {
      expect(
        () => planUpdateRate(
          history,
          history[0].copyWith(endDate: DateTime(2026, 3, 31)),
        ),
        throwsA(isA<RateTimelineException>()),
      );
      final ch = planUpdateRate(
        history,
        history[1].copyWith(endDate: DateTime(2026, 12, 31)),
      );
      expect(ch.single.after!.endDate, DateTime(2026, 12, 31));
      // И снять окончание можно.
      final closed = _apply(history, ch);
      final reopened = planUpdateRate(
        closed,
        EmployeeRate(
          id: 'b',
          employeeId: 'e1',
          baseRate: 2000,
          fieldRate: 1500,
          startDate: DateTime(2026, 5, 1),
        ),
      );
      expect(reopened.single.after!.endDate, isNull);
    });

    test('без изменений — пусто', () {
      expect(planUpdateRate(history, history[1]), isEmpty);
    });
  });

  group('удаление', () {
    test('последняя — её период переходит к предыдущей', () {
      final ch = planDeleteRate(history, 'b');
      expect(_show(_apply(history, ch)), '2026-01-01..∞ 1000');
    });

    test('первая — дни до следующей остаются без ставки', () {
      final ch = planDeleteRate(history, 'a');
      expect(ch, hasLength(1));
      expect(_show(_apply(history, ch)), '2026-05-01..∞ 2000');
    });

    test('средняя — предыдущая дотягивается до следующей', () {
      final three = [
        ...history.take(1),
        _r('b', DateTime(2026, 5, 1), end: DateTime(2026, 8, 31), base: 2000),
        _r('c', DateTime(2026, 9, 1), base: 3000),
      ];
      expect(
        _show(_apply(three, planDeleteRate(three, 'b'))),
        '2026-01-01..2026-08-31 1000 | 2026-09-01..∞ 3000',
      );
    });
  });

  test('ставка на день', () {
    expect(rateOn(history, DateTime(2026, 4, 30))?.id, 'a');
    expect(rateOn(history, DateTime(2026, 5, 1))?.id, 'b');
    expect(rateOn(history, DateTime(2025, 12, 31)), isNull);
  });
}
