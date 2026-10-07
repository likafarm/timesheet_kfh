// packages/domain/lib/src/finance/models.dart
//
// Модели финансов (этап 8, управленческий учёт). Суммы — копейки (`int`),
// id — uuid-строки, дни — местная полночь (как во всём домене). У каждого
// перечисления — код для базы и формата обмена (`code`/`fromCode`).

/// Вид кошелька.
enum AccountKind {
  cash('cash', 'Наличные'),
  bank('bank', 'Расчётный счёт'),
  card('card', 'Карта'),
  creditCard('credit_card', 'Кредитная карта'),
  accountable('accountable', 'Подотчёт');

  const AccountKind(this.code, this.title);
  final String code;
  final String title;

  static AccountKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Кошелёк: где лежат деньги. Начальный остаток — на [openingDate]
/// (null — с самого начала). Кредитная карта может уйти в минус — это долг
/// банку. Подотчёт — деньги хозяйства на руках у человека ([employeeId]).
class FinAccount {
  final String id;
  final String name;
  final AccountKind kind;
  final int openingBalance;
  final DateTime? openingDate;
  final String? employeeId;
  final bool closed;
  final int sortOrder;

  const FinAccount({
    required this.id,
    required this.name,
    required this.kind,
    this.openingBalance = 0,
    this.openingDate,
    this.employeeId,
    this.closed = false,
    this.sortOrder = 0,
  });
}

/// Направление: на что пошли деньги (Животноводство, Растениеводство
/// (корма), Реализация, Общехозяйственные). [overhead] — накладные.
class FinDirection {
  final String id;
  final String name;
  final bool overhead;
  final int sortOrder;

  const FinDirection({
    required this.id,
    required this.name,
    this.overhead = false,
    this.sortOrder = 0,
  });
}

/// Доли ключа, действующие с [validFrom]: id направления → процент
/// (целые, в сумме 100).
class AllocationPeriod {
  final DateTime validFrom;
  final Map<String, int> shares;

  const AllocationPeriod({required this.validFrom, required this.shares});
}

/// Ключ распределения («Трактора»): расход делится по направлениям в
/// долях. Доли меняются с новой даты — прежние операции считаются по
/// прежним долям.
class AllocationKey {
  final String id;
  final String name;
  final List<AllocationPeriod> periods;

  const AllocationKey({
    required this.id,
    required this.name,
    required this.periods,
  });
}

/// Вид имущества.
enum AssetKind {
  building('building', 'Постройка'),
  machinery('machinery', 'Техника'),
  equipment('equipment', 'Оборудование'),
  vehicle('vehicle', 'Автомобиль'),
  land('land', 'Земля'),
  other('other', 'Прочее');

  const AssetKind(this.code, this.title);
  final String code;
  final String title;

  static AssetKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Имущество хозяйства. Стоимость — справочная (решение владельца
/// 2026-10-08): покупка — расход целиком, износа нет. У техники и
/// оборудования — направление или ключ: по ним раскладываются ГСМ,
/// запчасти и ремонт, привязанные к машине.
class Asset {
  final String id;
  final String name;
  final AssetKind kind;
  final int? year;
  final int quantity;
  final int? referenceValue;
  final DateTime? valuedOn;
  final String? directionId;
  final String? allocationKeyId;
  final String? cadastralNumber;
  final double? areaHa;
  final int? cadastralValue;
  final DateTime? disposedOn;
  final String? disposalReason;
  final String? notes;

  const Asset({
    required this.id,
    required this.name,
    required this.kind,
    this.year,
    this.quantity = 1,
    this.referenceValue,
    this.valuedOn,
    this.directionId,
    this.allocationKeyId,
    this.cadastralNumber,
    this.areaHa,
    this.cadastralValue,
    this.disposedOn,
    this.disposalReason,
    this.notes,
  });

  /// Выбыло (продано, списано) к дню [day] включительно.
  bool disposedBy(DateTime day) =>
      disposedOn != null && !disposedOn!.isAfter(day);
}

/// Доход или расход.
enum CategoryType {
  income('income', 'Доход'),
  expense('expense', 'Расход');

  const CategoryType(this.code, this.title);
  final String code;
  final String title;

  static CategoryType fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Вид статьи: текущий; капвложение (покупка имущества — в отчёте отдельно);
/// возврат (переплаты, авансы — не выручка).
enum CategoryKind {
  current('current', 'Текущая'),
  capex('capex', 'Капвложение'),
  refund('refund', 'Возврат');

  const CategoryKind(this.code, this.title);
  final String code;
  final String title;

  static CategoryKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Статья: что купили или за что получили. Каждая статья — один раз;
/// «на что пошло» — направление (по умолчанию — у статьи).
class FinCategory {
  final String id;
  final CategoryType type;
  final String group;
  final String name;
  final String? directionId;
  final String? allocationKeyId;
  final CategoryKind kind;
  final bool inTaxBook;
  final bool hidden;
  final int sortOrder;

  const FinCategory({
    required this.id,
    required this.type,
    required this.group,
    required this.name,
    this.directionId,
    this.allocationKeyId,
    this.kind = CategoryKind.current,
    this.inTaxBook = true,
    this.hidden = false,
    this.sortOrder = 0,
  });
}

/// Вид контрагента.
enum CounterpartyKind {
  buyer('buyer', 'Покупатель'),
  supplier('supplier', 'Поставщик'),
  person('person', 'Человек'),
  bank('bank', 'Банк'),
  other('other', 'Прочее');

  const CounterpartyKind(this.code, this.title);
  final String code;
  final String title;

  static CounterpartyKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Покупатель, поставщик, человек. Работник — ссылка на сотрудника табеля.
class Counterparty {
  final String id;
  final String name;
  final CounterpartyKind kind;
  final String? inn;
  final String? phone;
  final String? employeeId;
  final String? notes;

  const Counterparty({
    required this.id,
    required this.name,
    this.kind = CounterpartyKind.other,
    this.inn,
    this.phone,
    this.employeeId,
    this.notes,
  });
}

/// Займ получен (хозяйство должно) или выдан (должны хозяйству).
enum DebtKind {
  received('received', 'Займ получен'),
  given('given', 'Займ выдан');

  const DebtKind(this.code, this.title);
  final String code;
  final String title;

  static DebtKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Долг: займ с контрагентом. Остаток — сколько осталось вернуть
/// (хозяйству или хозяйством — по [kind]).
class FinDebt {
  final String id;
  final String counterpartyId;
  final DebtKind kind;
  final int openingBalance;
  final DateTime? openingDate;
  final bool closed;
  final String? notes;

  const FinDebt({
    required this.id,
    required this.counterpartyId,
    required this.kind,
    this.openingBalance = 0,
    this.openingDate,
    this.closed = false,
    this.notes,
  });
}

/// Вид операции. Займы и переводы — не доход и не расход.
enum OperationType {
  income('income', 'Доход'),
  expense('expense', 'Расход'),
  transfer('transfer', 'Перевод'),
  debt('debt', 'Займ');

  const OperationType(this.code, this.title);
  final String code;
  final String title;

  static OperationType fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Движение по займу. Получен: [take] — взяли (деньги пришли, долг вырос),
/// [repay] — вернули (ушли, уменьшился). Выдан: [lend] — дали (ушли,
/// вырос), [collect] — нам вернули (пришли, уменьшился).
enum DebtMove {
  take('take', 'Получили займ', DebtKind.received, 1),
  repay('repay', 'Вернули займ', DebtKind.received, -1),
  lend('lend', 'Выдали займ', DebtKind.given, -1),
  collect('collect', 'Нам вернули займ', DebtKind.given, 1);

  const DebtMove(this.code, this.title, this.debtKind, this.cashSign);
  final String code;
  final String title;

  /// Какому виду долга подходит.
  final DebtKind debtKind;

  /// +1 — деньги пришли в кошелёк, −1 — ушли.
  final int cashSign;

  /// +1 — долг вырос, −1 — уменьшился.
  int get debtSign => this == take || this == lend ? 1 : -1;

  static DebtMove fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Откуда операция.
enum OperationSource {
  manual('manual'),
  imported('import'),
  payroll('payroll'),
  bank('bank'),
  evotor('evotor');

  const OperationSource(this.code);
  final String code;

  static OperationSource fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// Операция: движение денег. [amount] — всегда больше нуля, направление
/// движения — по [type] (и [debtMove]). «На что пошло» — [directionId], или
/// [allocationKeyId], или [assetId] (направление/ключ машины), иначе — по
/// статье. [season] — год урожая (материалы и затраты растениеводства).
class FinOperation {
  final String id;
  final DateTime date;
  final OperationType type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? directionId;
  final String? allocationKeyId;
  final String? assetId;
  final int? season;
  final String? counterpartyId;
  final String? employeeId;
  final String? debtId;
  final DebtMove? debtMove;
  final String? description;
  final double? quantity;
  final String? unit;
  final String? tag;
  final String? notes;
  final OperationSource source;
  final String? sourceRef;
  final String? createdBy;

  const FinOperation({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.directionId,
    this.allocationKeyId,
    this.assetId,
    this.season,
    this.counterpartyId,
    this.employeeId,
    this.debtId,
    this.debtMove,
    this.description,
    this.quantity,
    this.unit,
    this.tag,
    this.notes,
    this.source = OperationSource.manual,
    this.sourceRef,
    this.createdBy,
  });

  /// Сезон урожая: указанный, иначе — год операции.
  int get effectiveSeason => season ?? date.year;

  FinOperation copyWith({
    String? id,
    DateTime? date,
    OperationType? type,
    int? amount,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? directionId,
    String? allocationKeyId,
    String? assetId,
    int? season,
    String? counterpartyId,
    String? employeeId,
    String? debtId,
    DebtMove? debtMove,
    String? description,
    double? quantity,
    String? unit,
    String? tag,
    String? notes,
    OperationSource? source,
    String? sourceRef,
    String? createdBy,
  }) => FinOperation(
    id: id ?? this.id,
    date: date ?? this.date,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId ?? this.toAccountId,
    categoryId: categoryId ?? this.categoryId,
    directionId: directionId ?? this.directionId,
    allocationKeyId: allocationKeyId ?? this.allocationKeyId,
    assetId: assetId ?? this.assetId,
    season: season ?? this.season,
    counterpartyId: counterpartyId ?? this.counterpartyId,
    employeeId: employeeId ?? this.employeeId,
    debtId: debtId ?? this.debtId,
    debtMove: debtMove ?? this.debtMove,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    tag: tag ?? this.tag,
    notes: notes ?? this.notes,
    source: source ?? this.source,
    sourceRef: sourceRef ?? this.sourceRef,
    createdBy: createdBy ?? this.createdBy,
  );

  @override
  String toString() =>
      'FinOperation($id, ${type.code}, $amount коп., ${date.toIso8601String()})';
}
