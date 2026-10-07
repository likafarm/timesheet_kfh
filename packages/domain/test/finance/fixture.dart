// Справочники для тестов финансов — вымышленное хозяйство.

import 'package:kfh_domain/kfh_domain.dart';

const herd = 'dir-herd'; // Животноводство
const crops = 'dir-crops'; // Растениеводство (корма)
const sales = 'dir-sales'; // Реализация
const general = 'dir-general'; // Общехозяйственные

const cash = 'acc-cash';
const bank = 'acc-bank';
const card = 'acc-card';
const credit = 'acc-credit';
const accountable = 'acc-olga';
const closedAccount = 'acc-closed';

const tractors = 'key-tractors';

const fuel = 'cat-fuel'; // ГСМ — по ключу
const meat = 'cat-meat'; // доход, животноводство
const refund = 'cat-refund'; // возвраты
const tractorPurchase = 'cat-tractor'; // капвложение
const film = 'cat-film'; // сетка, плёнка — растениеводство
const workers = 'cat-workers'; // рабочие фермы
const mechanics = 'cat-mechanics'; // механизаторы — по ключу
const noDirection = 'cat-none'; // статья без направления
const adjustIn = 'cat-adjust-in';
const adjustOut = 'cat-adjust-out';

const gazelle = 'asset-gazelle';
const press = 'asset-press';
const oldPress = 'asset-old-press';

const loanTaken = 'debt-taken';
const loanGiven = 'debt-given';

final day = DateTime(2025, 6, 10);

final catalog = FinanceCatalog(
  directions: const [
    FinDirection(id: herd, name: 'Животноводство'),
    FinDirection(id: crops, name: 'Растениеводство (корма)'),
    FinDirection(id: sales, name: 'Реализация'),
    FinDirection(id: general, name: 'Общехозяйственные', overhead: true),
  ],
  keys: [
    AllocationKey(
      id: tractors,
      name: 'Трактора',
      periods: [
        AllocationPeriod(
          validFrom: DateTime(2026, 1, 1),
          shares: const {herd: 70, crops: 30},
        ),
        AllocationPeriod(
          validFrom: DateTime(2025, 1, 1),
          shares: const {herd: 60, crops: 40},
        ),
      ],
    ),
  ],
  accounts: [
    const FinAccount(id: cash, name: 'Касса', kind: AccountKind.cash),
    FinAccount(
      id: bank,
      name: 'Счёт',
      kind: AccountKind.bank,
      openingBalance: 2900301,
      openingDate: DateTime(2025, 1, 1),
    ),
    const FinAccount(id: card, name: 'Карта', kind: AccountKind.card),
    const FinAccount(
      id: credit,
      name: 'Кредитка',
      kind: AccountKind.creditCard,
    ),
    const FinAccount(
      id: accountable,
      name: 'Нал Ольга',
      kind: AccountKind.accountable,
      employeeId: 'emp-olga',
    ),
    const FinAccount(
      id: closedAccount,
      name: 'Старый счёт',
      kind: AccountKind.bank,
      closed: true,
    ),
  ],
  categories: const [
    FinCategory(
      id: fuel,
      type: CategoryType.expense,
      group: '04. Техника и транспорт',
      name: 'ГСМ',
      allocationKeyId: tractors,
    ),
    FinCategory(
      id: meat,
      type: CategoryType.income,
      group: '1. Основная деятельность',
      name: 'Мясо',
      directionId: herd,
    ),
    FinCategory(
      id: refund,
      type: CategoryType.income,
      group: '3. Прочие поступления',
      name: 'Возвраты и переплаты',
      directionId: general,
      kind: CategoryKind.refund,
    ),
    FinCategory(
      id: tractorPurchase,
      type: CategoryType.expense,
      group: '09. Капвложения',
      name: 'Сельхозтехника',
      directionId: herd,
      kind: CategoryKind.capex,
    ),
    FinCategory(
      id: film,
      type: CategoryType.expense,
      group: '02. Корма',
      name: 'Сетка, плёнка, шпагат',
      directionId: crops,
    ),
    FinCategory(
      id: workers,
      type: CategoryType.expense,
      group: '03. Персонал',
      name: 'Рабочие фермы',
      directionId: herd,
    ),
    FinCategory(
      id: mechanics,
      type: CategoryType.expense,
      group: '03. Персонал',
      name: 'Механизаторы',
      allocationKeyId: tractors,
    ),
    FinCategory(
      id: noDirection,
      type: CategoryType.expense,
      group: '08. Управление',
      name: 'Без направления',
    ),
    FinCategory(
      id: adjustIn,
      type: CategoryType.income,
      group: '3. Прочие поступления',
      name: 'Корректировка (излишек)',
      directionId: general,
    ),
    FinCategory(
      id: adjustOut,
      type: CategoryType.expense,
      group: '08. Управление',
      name: 'Корректировка (недостача)',
      directionId: general,
    ),
  ],
  assets: [
    const Asset(
      id: gazelle,
      name: 'Газель',
      kind: AssetKind.vehicle,
      directionId: general,
    ),
    const Asset(
      id: press,
      name: 'Пресс-подборщик',
      kind: AssetKind.equipment,
      directionId: crops,
    ),
    Asset(
      id: oldPress,
      name: 'Пресс ПР-145',
      kind: AssetKind.equipment,
      directionId: crops,
      disposedOn: DateTime(2025, 3, 1),
      disposalReason: 'Продан',
    ),
  ],
  counterparties: const [
    Counterparty(id: 'cp-lender', name: 'Займодавец'),
    Counterparty(id: 'cp-seller', name: 'Продавец быков'),
  ],
  debts: [
    FinDebt(
      id: loanTaken,
      counterpartyId: 'cp-lender',
      kind: DebtKind.received,
      openingBalance: 3500000000,
      openingDate: DateTime(2025, 1, 1),
    ),
    const FinDebt(
      id: loanGiven,
      counterpartyId: 'cp-seller',
      kind: DebtKind.given,
    ),
  ],
);

var _seq = 0;

FinOperation expense(
  String categoryId,
  int amount, {
  String account = cash,
  DateTime? date,
  String? direction,
  String? key,
  String? asset,
  int? season,
}) => FinOperation(
  id: 'op-${++_seq}',
  date: date ?? day,
  type: OperationType.expense,
  amount: amount,
  accountId: account,
  categoryId: categoryId,
  directionId: direction,
  allocationKeyId: key,
  assetId: asset,
  season: season,
);

FinOperation income(
  String categoryId,
  int amount, {
  String account = cash,
  DateTime? date,
}) => FinOperation(
  id: 'op-${++_seq}',
  date: date ?? day,
  type: OperationType.income,
  amount: amount,
  accountId: account,
  categoryId: categoryId,
);

FinOperation transfer(String from, String to, int amount, {DateTime? date}) =>
    FinOperation(
      id: 'op-${++_seq}',
      date: date ?? day,
      type: OperationType.transfer,
      amount: amount,
      accountId: from,
      toAccountId: to,
    );

FinOperation debt(
  String debtId,
  DebtMove move,
  int amount, {
  String account = cash,
  DateTime? date,
}) => FinOperation(
  id: 'op-${++_seq}',
  date: date ?? day,
  type: OperationType.debt,
  amount: amount,
  accountId: account,
  debtId: debtId,
  debtMove: move,
);
