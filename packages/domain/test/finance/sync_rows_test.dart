import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Финансы в формате обмена: проверки строк (сервер) и закрытые месяцы.
void main() {
  Map<String, Object?> op(Map<String, Object?> changes) => {
    'date': '2026-09-10',
    'type': 'expense',
    'amount': 100,
    'account_uuid': 'a1',
    'to_account_uuid': null,
    'category_uuid': 'c1',
    'direction_uuid': null,
    'allocation_key_uuid': null,
    'debt_uuid': null,
    'debt_move': null,
    ...changes,
  };

  group('operationRowProblem', () {
    test('верные строки', () {
      expect(operationRowProblem(op({})), isNull);
      expect(operationRowProblem(op({'type': 'income'})), isNull);
      expect(
        operationRowProblem(
          op({
            'type': 'transfer',
            'category_uuid': null,
            'to_account_uuid': 'a2',
          }),
        ),
        isNull,
      );
      expect(
        operationRowProblem(
          op({
            'type': 'debt',
            'category_uuid': null,
            'debt_uuid': 'd1',
            'debt_move': 'take',
          }),
        ),
        isNull,
      );
    });

    test('поля не по виду операции', () {
      expect(
        operationRowProblem(op({'category_uuid': null})),
        contains('статья'),
      );
      expect(
        operationRowProblem(op({'to_account_uuid': 'a2'})),
        contains('второго кошелька'),
      );
      expect(operationRowProblem(op({'debt_uuid': 'd1'})), contains('Займ'));
      expect(
        operationRowProblem(
          op({'direction_uuid': 'x', 'allocation_key_uuid': 'k'}),
        ),
        contains('не оба'),
      );
      expect(
        operationRowProblem(
          op({
            'type': 'transfer',
            'category_uuid': null,
            'to_account_uuid': 'a1',
          }),
        ),
        contains('тот же кошелёк'),
      );
      expect(
        operationRowProblem(op({'type': 'transfer', 'to_account_uuid': 'a2'})),
        contains('нет статьи'),
      );
      expect(
        operationRowProblem(
          op({'type': 'debt', 'category_uuid': null, 'debt_uuid': 'd1'}),
        ),
        contains('что сделали'),
      );
      expect(
        operationRowProblem(op({'type': 'gift'})),
        contains('Неизвестный'),
      );
    });
  });

  test('allocationPeriodRowProblem', () {
    String? problem(String shares) =>
        allocationPeriodRowProblem({'shares': shares});
    expect(problem('{"a":60,"b":40}'), isNull);
    expect(problem('{"a":60,"b":30}'), contains('90 %'));
    expect(problem('{"a":110,"b":-10}'), contains('отрицательной'));
    expect(problem('{"a":60.5,"b":39.5}'), contains('целый'));
    expect(problem('{}'), contains('нет долей'));
    expect(problem('[60, 40]'), contains('нет долей'));
    expect(problem('не json'), contains('JSON'));
    expect(financeRowProblem('fin_accounts', {}), isNull);
  });

  test('строка операции проходит разбор формата обмена', () {
    final change = SyncChange.fromJson({
      'table': 'fin_operations',
      'uuid': '01900000-0000-7000-8000-000000000001',
      'updated_at': '2026-10-08T10:00:00.000Z',
      'deleted': false,
      'change_id': 'c1',
      'data': {
        'legacy_id': null,
        ...op({
          'account_uuid': '01900000-0000-7000-8000-000000000002',
          'category_uuid': '01900000-0000-7000-8000-000000000003',
        }),
        'asset_uuid': null,
        'season': 2026,
        'counterparty_uuid': null,
        'employee_uuid': null,
        'description': 'ДТ',
        'quantity': 120.5,
        'unit': 'л',
        'tag': null,
        'notes': null,
        'source': 'manual',
        'source_ref': null,
        'created_by': 'buh',
        'created_at': '2026-10-08T13:00:00.000',
      },
    });
    expect(change.data['amount'], 100);
    expect(
      () => SyncChange.fromJson({
        'table': 'fin_operations',
        'uuid': '01900000-0000-7000-8000-000000000001',
        'updated_at': '2026-10-08T10:00:00.000Z',
        'deleted': false,
        'change_id': 'c1',
        'data': {...change.data, 'amount': 0},
      }),
      throwsA(isA<SyncFormatException>()),
    );
  });

  group('закрытые месяцы', () {
    final guard = PeriodGuard({PeriodGuard.monthKey(2026, 8)});
    Map<String, Object?> account({
      int balance = 0,
      String? date,
      String name = 'Касса',
    }) => {'name': name, 'opening_balance': balance, 'opening_date': date};

    test('операция — по своему дню, прежнему и новому', () {
      expect(
        guard.violation(
          'fin_operations',
          null,
          false,
          op({'date': '2026-08-31'}),
          false,
        ),
        (2026, 8),
      );
      expect(
        guard.violation('fin_operations', null, false, op({}), false),
        isNull,
      );
      expect(
        guard.violation(
          'fin_operations',
          op({'date': '2026-08-15'}),
          false,
          op({}),
          false,
        ),
        (2026, 8),
        reason: 'перенос из закрытого месяца',
      );
    });

    test('начальный остаток — только сам остаток или его дата', () {
      expect(
        guard.violation(
          'fin_accounts',
          null,
          false,
          account(balance: 100, date: '2026-08-01'),
          false,
        ),
        (2026, 8),
      );
      expect(
        guard.violation(
          'fin_accounts',
          null,
          false,
          account(date: '2026-08-01'),
          false,
        ),
        isNull,
        reason: 'нулевой остаток',
      );
      expect(
        guard.violation(
          'fin_accounts',
          null,
          false,
          account(balance: 100),
          false,
        ),
        isNull,
        reason: 'без даты',
      );
      final before = account(balance: 100, date: '2026-08-01');
      expect(
        guard.violation(
          'fin_accounts',
          before,
          false,
          account(balance: 100, date: '2026-08-01', name: 'Касса нал'),
          false,
        ),
        isNull,
        reason: 'переименование',
      );
      expect(
        guard.violation(
          'fin_debts',
          before,
          false,
          account(balance: 200, date: '2026-08-01'),
          false,
        ),
        (2026, 8),
      );
      expect(
        guard.violation('fin_categories', null, false, {'name': 'ГСМ'}, false),
        isNull,
        reason: 'справочники к месяцам не привязаны',
      );
    });
  });
}
