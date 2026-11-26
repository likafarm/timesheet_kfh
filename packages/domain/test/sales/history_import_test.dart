import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Перенос истории из «Заказы мяса.xlsx» (11.7): разбор листов, товары по
/// правилам и выбору владельца, склейка покупателей, заказы и повтор.
void main() {
  const header = [
    'Оплата',
    'Выполнен',
    'Срок поставки',
    'ФИО',
    'Заказ',
    'Номер заказа',
    'Телефон',
    'Адрес',
    'Вес',
    'Цена итого',
    'Цена за кг',
    'Вид связи',
  ];
  // 45780 — 03.05.2025 (день Excel; номер заказа 305 — 3 мая).
  final sheet = <List<String?>>[
    header,
    [
      'да',
      'да',
      '45780',
      'Ольга',
      'вырезка, 2 кг',
      '305-1',
      '89001234567',
      'Юхнов',
      '2.2',
      null,
      null,
      'тг @olga',
    ],
    [
      'да',
      'да',
      '45780',
      'Ольга К.',
      'язык свежий 1 шт',
      '305-1 (2/2)',
      '+7 900 123-45-67',
      null,
      null,
      null,
      null,
      null,
    ],
    [
      'нет',
      null,
      '45780',
      'Пётр',
      'гречневая каша',
      '305-2',
      null,
      null,
      null,
      '500',
      null,
      'НАПОМНИТЬ ЗАБРАТЬ!',
    ],
    [
      null,
      null,
      '5-7.06.2025',
      'Нина',
      'набор на 3000р',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
    [
      null,
      null,
      null,
      'Без даты',
      'печень',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
    [],
  ];
  final free = <List<String?>>[
    ['Дата', 'получатель', 'Вес', 'Цена', 'Сумма'],
    ['45885', 'Себе', '3.7', '500', '1850'],
    ['45885', 'Храм', '4.2', '1000', '4200'],
  ];

  const tenderloin = Product(id: 'vyr', groupId: 'g', name: 'Вырезка');
  const tongue = Product(
    id: 'tongue',
    groupId: 'g',
    name: 'Язык',
    unit: ProductUnit.pcs,
  );
  final prices = [
    ProductPrice(
      id: 'p1',
      productId: 'vyr',
      validFrom: DateTime(2025, 1, 1),
      price: 184000,
    ),
  ];

  var n = 0;
  String id() => 'id${n++}';

  HistoryImportPlan plan({
    List<Customer> customers = const [],
    List<SaleOrder> orders = const [],
    List<SaleBatch> batches = const [],
    Map<String, String> overrides = const {},
  }) => planHistoryImport(
    parseHistoryWorkbook([sheet, free]),
    groups: const [ProductGroup(id: 'g', name: 'Говядина')],
    products: const [tenderloin, tongue],
    prices: prices,
    customers: customers,
    batches: batches,
    orders: orders,
    overrides: overrides,
    today: DateTime(2026, 11, 27),
    newId: id,
  );

  test('числа, даты и «заказано» из ячеек', () {
    expect(historyNumber('2,5'), 2.5);
    expect(historyNumber('=1.2+0.8'), closeTo(2.0, 1e-9));
    expect(historyNumber('кг'), isNull);
    expect(historyDay('45780')!.$1, DateTime(2025, 5, 3));
    expect(historyDay('5-7.06.2025'), (
      DateTime(2025, 6, 5),
      DateTime(2025, 6, 7),
    ));
    expect(historyDay('01.11(25.10.2025)')!.$1, DateTime(2025, 11, 1));
    expect(historyDay('завтра'), isNull);
    expect(historyOrdered('пашина, 2 кг'), (2.0, OrderedUnit.kg));
    expect(historyOrdered('на 1000р'), (1000.0, OrderedUnit.rub));
    expect(historyOrdered('кусок побольше'), isNull);
    expect(historyPhone('89001234567'), '+79001234567');
    expect(historyPhone('12'), isNull);
    expect(historyChannel('тг @olga').channel, CustomerChannel.telegram);
    expect(historyChannel('тг @olga').contact, '@olga');
    expect(historyChannel('НАПОМНИТЬ!').comment, 'НАПОМНИТЬ!');
  });

  test('без листа заказов — понятный отказ', () {
    expect(
      () => parseHistoryWorkbook([free]),
      throwsA(isA<HistoryFormatException>()),
    );
  });

  test('разбор: строки, пропуски, лист «Мясо безвозмездно»', () {
    final src = parseHistoryWorkbook([sheet, free]);
    expect(src.orders.length, 4);
    expect(src.orders.first.row, 2);
    expect(src.skipped, {'без даты поставки': 1});
    expect(src.free.length, 2);
    expect(src.free.first.own, isTrue);
  });

  test('план: заказы по номеру, покупатель по телефону, товары', () {
    final p = plan();
    // 305-1 (две строки), 305-2, заказ Нины, «себе» и «храм».
    expect(p.orders.length, 5);
    final o1 = p.orders.firstWhere((o) => o.$1.number == 1 && o.$2.length == 2);
    expect(o1.$1.historyRow, 2);
    expect(o1.$1.status, OrderStatus.issued, reason: 'выдача прошла');
    final vyr = o1.$2.first;
    expect(vyr.productId, 'vyr');
    expect(vyr.orderedQty, 2);
    expect(vyr.weight, 2.2);
    expect(vyr.price, 184000, reason: 'цена прайса на день выдачи');
    final tongueLine = o1.$2.last;
    expect(tongueLine.productId, 'tongue');
    expect(tongueLine.note, 'вес не записан');
    expect(tongueLine.state, LineState.assembled);
    // Ольга и «Ольга К.» — один покупатель по телефону.
    final olga = p.customers.firstWhere((c) => c.names.contains('Ольга'));
    expect(olga.names, {'Ольга', 'Ольга К.'});
    expect(
      p.newCustomers.firstWhere((c) => c.name == 'Ольга').channel,
      CustomerChannel.telegram,
    );
    // Каша — не узнана: «Прочее», заведено скрытым в группе истории.
    final kasha = p.texts.firstWhere((t) => t.text == 'гречневая каша');
    expect(kasha.productId, isNull);
    expect(p.newGroups.single.name, historyGroupName);
    expect(
      p.newProducts.map((x) => x.name),
      containsAll([historyOtherProduct, 'Говядина охлаждённая (набор)']),
    );
    expect(p.newProducts.every((x) => x.hidden), isTrue);
    // «Цена итого» — своя сумма; «Вид связи» без канала — комментарий.
    final o2 = p.orders.firstWhere((o) => o.$1.number == 2);
    expect(o2.$2.single.pricing, LinePricing.fixed);
    expect(o2.$2.single.fixedAmount, 50000);
    expect(o2.$1.comment, 'НАПОМНИТЬ ЗАБРАТЬ!');
    expect(p.notPaidRows, 2, reason: '«нет» и пустая «Оплата»');
    // Диапазон дней — выдача с первого дня; без номера — следующий.
    final nina = p.newBatches.firstWhere((b) => b.day == DateTime(2025, 6, 5));
    expect(nina.dayTo, DateTime(2025, 6, 7));
    expect(nina.notes, historyBatchNote);
    // «Мясо безвозмездно»: себе и без оплаты.
    final kinds = {for (final o in p.orders) o.$1.kind};
    expect(kinds, containsAll([OrderKind.own, OrderKind.free]));
    expect(
      p.orders.where((o) => o.$1.kind == OrderKind.own).single.$1.historyRow,
      historyFreeRowBase + 2,
    );
  });

  test('выбор владельца сильнее правил', () {
    final p = plan(overrides: {'гречневая каша': 'vyr'});
    final kasha = p.texts.firstWhere((t) => t.text == 'гречневая каша');
    expect(kasha.productId, 'vyr');
    expect(kasha.manual, isTrue);
  });

  test('с заведёнными: покупатель по телефону, повтор не задваивает', () {
    const olga = Customer(id: 'c-olga', name: 'Ольга', phone: '+79001234567');
    final first = plan(customers: const [olga]);
    expect(first.newCustomers.any((c) => c.name == 'Ольга'), isFalse);
    expect(
      first.updatedCustomers.single.address,
      'Юхнов',
      reason: 'дописано пустое поле',
    );
    expect(
      first.orders.firstWhere((o) => o.$2.length == 2).$1.customerId,
      'c-olga',
    );
    // Второй раз — всё уже перенесено.
    final again = plan(
      customers: [olga, ...first.newCustomers],
      batches: first.newBatches,
      orders: [for (final o in first.orders) o.$1],
    );
    expect(again.orders, isEmpty);
    expect(again.alreadyImported, first.orders.length);
    expect(again.newBatches, isEmpty);
  });

  test('оплата перенесённого заказа — до программы, не долг', () {
    const o = SaleOrder(
      id: 'o',
      batchId: 'b',
      customerId: 'c',
      number: 1,
      status: OrderStatus.issued,
      historyRow: 5,
    );
    const totals = OrderTotals(
      fact: 100000,
      estimate: 100000,
      complete: true,
      unknown: 0,
      weight: 1,
    );
    expect(orderPayment(o, totals, const []).state, PaymentState.history);
    expect(customerBalance([o], (_) => totals, const {}).debt, 0);
  });
}
