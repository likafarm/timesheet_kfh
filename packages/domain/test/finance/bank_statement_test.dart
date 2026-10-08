import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

const own = '40802810122240005969\n860323863100\nГЛАВА КФХ ЛОПАТИН И. И.';

void main() {
  group('разбор выписки СберБизнеса', () {
    test('выгрузка 2025: заголовок в одной строке, даты числами Excel', () {
      final s = parseSberStatement([
        [
          'Дата проводки',
          'Дебет',
          'Кредит',
          'Сумма по дебету',
          'Сумма по кредиту',
          '№ документа',
          'ВО',
          'Банк (БИК и наименование)',
          'Назначение платежа',
        ],
        [
          // 01.01.2025 16:07 — число дня Excel.
          '45658.67164',
          own,
          '30301810322246004000\n7707083893\nКАЛУЖСКОЕ ОТДЕЛЕНИЕ ПАО СБЕРБАНК',
          '1999.97',
          null,
          '515481',
          '17',
          'БИК 042908612',
          'Покупка PURCHASE_CB в ТУ RNAZS 23 по карте MC 5479 за 2025-01-01.',
        ],
        [
          '2025-01-05 01:17:54',
          '30233810067170117000\n7707083893\nПАО СБЕРБАНК',
          own,
          null,
          '9 975,22',
          '720913',
          '01',
          '',
          'Зачисление средств по операциям эквайринга',
        ],
        ['Итого', null, null, '1999.97', '9975.22'],
      ]);
      expect(s.account, '40802810122240005969');
      expect(s.lines, hasLength(2));
      final buy = s.lines.first;
      expect(buy.date, DateTime(2025, 1, 1));
      expect(buy.amount, 199997);
      expect(buy.incoming, isFalse);
      expect(buy.counterpartyInn, '7707083893');
      expect(buy.counterpartyName, 'КАЛУЖСКОЕ ОТДЕЛЕНИЕ ПАО СБЕРБАНК');
      expect(buy.key, 'bank:2025-01-01:515481:199997:out');
      final income = s.lines.last;
      expect(income.incoming, isTrue);
      expect(income.amount, 997522);
    });

    test('выгрузка 2022: «Счет» с подзаголовками «Дебет»/«Кредит»', () {
      final s = parseSberStatement([
        ['ВЫПИСКА ОПЕРАЦИЙ ПО ЛИЦЕВОМУ СЧЕТУ', null, '40802810122240005969'],
        [
          'Дата проводки',
          'Счет',
          null,
          'Сумма по дебету',
          'Сумма по кредиту',
          '№ документа',
          'ВО',
          'Банк (БИК и наименование)',
          'Назначение платежа',
        ],
        [null, 'Дебет', 'Кредит'],
        [
          '2022-01-03 21:51:45',
          own,
          '40702810602180040156\n4029030252\nПАО "Калужская сбытовая компания"',
          '3208.75',
          '',
          '1',
          '01',
          '',
          'Оплата за электроэнергию',
        ],
      ]);
      expect(s.lines.single.counterpartyInn, '4029030252');
      expect(
        s.lines.single.counterpartyName,
        'ПАО "Калужская сбытовая компания"',
      );
      expect(s.lines.single.amount, 320875);
    });

    test('не выписка — понятная ошибка', () {
      expect(
        () => parseSberStatement([
          ['Касса', 'Сумма'],
        ]),
        throwsA(isA<BankStatementException>()),
      );
    });
  });

  test('магазин из покупки по карте', () {
    expect(
      cardMerchant('Покупка PURCHASE_CB в ТУ RNAZS 23 по карте MC 5479 за …'),
      'rnazs 23',
    );
    expect(cardMerchant('Оплата за электроэнергию'), isNull);
  });

  group('сопоставление с операциями', () {
    final catalog = FinanceCatalog(
      counterparties: const [
        Counterparty(id: 'ksk', name: 'Калужская сбытовая', inn: '4029030252'),
      ],
    );
    BankLine line(
      DateTime d,
      int amount, {
      bool incoming = false,
      String? inn,
      String? doc,
      String purpose = '',
    }) => BankLine(
      date: d,
      amount: amount,
      incoming: incoming,
      docNumber: doc,
      purpose: purpose,
      counterpartyInn: inn,
    );
    FinOperation op(
      String id,
      DateTime d,
      int amount, {
      String? ref,
      String? counterparty,
      String? category,
      String? description,
    }) => FinOperation(
      id: id,
      date: d,
      type: OperationType.expense,
      amount: amount,
      accountId: 'bank',
      sourceRef: ref,
      counterpartyId: counterparty,
      categoryId: category,
      description: description,
    );

    test('уже загружено, найдено вручную, новое с подсказкой', () {
      final loaded = line(DateTime(2025, 2, 1), 100, doc: '1');
      final manual = line(DateTime(2025, 2, 3), 500, doc: '2');
      final power = line(
        DateTime(2025, 2, 4),
        320875,
        inn: '4029030252',
        doc: '3',
      );
      final fuel = line(
        DateTime(2025, 2, 5),
        150000,
        inn: '7707083893',
        doc: '4',
        purpose: 'Покупка в ТУ RNAZS 23 по карте MC',
      );
      final mine = line(
        DateTime(2025, 2, 6),
        700000,
        inn: '860323863100',
        doc: '5',
      );
      final matches = matchBankLines(
        lines: [loaded, manual, power, fuel, mine],
        accountId: 'bank',
        operations: [
          op('o1', DateTime(2025, 2, 1), 100, ref: loaded.key),
          op('o2', DateTime(2025, 2, 1), 500),
          op(
            'o3',
            DateTime(2025, 1, 4),
            300000,
            counterparty: 'ksk',
            category: 'power',
          ),
          op(
            'o4',
            DateTime(2025, 1, 10),
            90000,
            category: 'fuel',
            description: 'Покупка PURCHASE_CB в ТУ RNAZS 23 по карте MC',
          ),
        ],
        catalog: catalog,
        ownInn: '860323863100',
      );
      expect(
        [for (final m in matches) m.status],
        [
          BankLineStatus.imported,
          BankLineStatus.matched,
          BankLineStatus.fresh,
          BankLineStatus.fresh,
          BankLineStatus.fresh,
        ],
      );
      expect(matches[1].operation?.id, 'o2');
      expect(matches[2].counterpartyId, 'ksk');
      expect(matches[2].categoryId, 'power');
      expect(matches[3].categoryId, 'fuel', reason: 'тот же магазин');
      expect(matches[3].counterpartyId, isNull, reason: 'банк — посредник');
      expect(matches[4].own, isTrue);
    });

    test('операция из строки помнит ключ', () {
      final l = line(DateTime(2025, 2, 4), 320875, doc: '3', purpose: 'Свет');
      final o = bankOperation(
        id: 'x',
        line: l,
        accountId: 'bank',
        categoryId: 'power',
      );
      expect(o.source, OperationSource.bank);
      expect(o.sourceRef, l.key);
      expect(o.type, OperationType.expense);
      expect(o.description, 'Свет');
    });
  });

  test('подсказка по смыслу назначения — по прошлой загрузке', () {
    expect(
      purposeSignature('Плата за пакет услуг Только для ИП за 05.01.2025'),
      'плата пакет услуг',
    );
    final prior = FinOperation(
      id: 'p',
      date: DateTime(2025, 1, 4),
      type: OperationType.expense,
      amount: 79000,
      accountId: 'bank',
      categoryId: 'fees',
      description: 'Плата за пакет услуг Только для ИП за 05.01.2025',
      source: OperationSource.bank,
      sourceRef: 'bank:2025-01-04:1:79000:out',
    );
    final m = matchBankLines(
      lines: [
        BankLine(
          date: DateTime(2025, 2, 4),
          amount: 79000,
          incoming: false,
          docNumber: '2',
          purpose: 'Плата за пакет услуг Только для ИП за 05.02.2025',
          counterpartyInn: '7707083893',
        ),
      ],
      accountId: 'bank',
      operations: [prior],
      catalog: FinanceCatalog(),
    ).single;
    expect(m.status, BankLineStatus.fresh);
    expect(m.categoryId, 'fees');
  });
}
