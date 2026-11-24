// packages/domain/lib/src/sales/price_list.dart
//
// Прайс-лист (этап 11.1, решения владельца 2026-11-24): товары по группам и
// цены с даты начала. Цена действует с [ProductPrice.validFrom] до начала
// следующей цены того же товара (как ставки сотрудников). Редакция прайса —
// все цены, начавшиеся в один день («вводится с 01.03.2026»): отдельной
// записи у неё нет. Старые цены не переписываются — это и есть история.
// Деньги — копейки целым числом (как в финансах).

import '../finance/money.dart';
import '../utils/date_utils.dart';

/// Таблицы прайс-листа: читают все роли, пишут админ и бухгалтер
/// (решение владельца 2026-11-24).
const priceListTables = {'product_groups', 'products', 'product_prices'};

/// Единица продажи.
enum ProductUnit {
  kg('kg', 'кг'),
  pcs('pcs', 'шт'),
  pack('pack', 'уп'),
  can('can', 'банка');

  const ProductUnit(this.code, this.title);
  final String code;
  final String title;

  static ProductUnit fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => kg);
}

/// Группа прайса («Говядина охлаждённая», «Субпродукты говяжьи»).
class ProductGroup {
  final String id;
  final String name;
  final int sortOrder;

  const ProductGroup({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  ProductGroup copyWith({String? name, int? sortOrder}) => ProductGroup(
    id: id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// Товар прайса.
class Product {
  final String id;
  final String groupId;
  final String name;
  final ProductUnit unit;
  final int sortOrder;

  /// Не продаётся: в печать и в новую редакцию не попадает, история цен
  /// остаётся.
  final bool hidden;
  final String? notes;

  const Product({
    required this.id,
    required this.groupId,
    required this.name,
    this.unit = ProductUnit.kg,
    this.sortOrder = 0,
    this.hidden = false,
    this.notes,
  });

  Product copyWith({
    String? groupId,
    String? name,
    ProductUnit? unit,
    int? sortOrder,
    bool? hidden,
    String? Function()? notes,
  }) => Product(
    id: id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    sortOrder: sortOrder ?? this.sortOrder,
    hidden: hidden ?? this.hidden,
    notes: notes == null ? this.notes : notes(),
  );
}

/// Цена товара с дня [validFrom] (копейки за единицу товара).
class ProductPrice {
  final String id;
  final String productId;
  final DateTime validFrom;
  final int price;

  const ProductPrice({
    required this.id,
    required this.productId,
    required this.validFrom,
    required this.price,
  });

  ProductPrice copyWith({int? price}) => ProductPrice(
    id: id,
    productId: productId,
    validFrom: validFrom,
    price: price ?? this.price,
  );
}

// ---------------------------------------------------------------- проверки

/// Наибольшая цена (копейки): 10 млн рублей за единицу — заведомо опечатка.
const maxProductPrice = 1000000000;

/// Почему группу не записать; null — можно.
String? productGroupProblem(ProductGroup g) =>
    g.name.trim().isEmpty ? 'Укажите название группы' : null;

/// Почему товар не записать; null — можно.
String? productProblem(Product p) {
  if (p.name.trim().isEmpty) return 'Укажите название товара';
  if (p.groupId.isEmpty) return 'Выберите группу товара';
  return null;
}

/// Почему цену не записать; null — можно.
String? productPriceProblem(ProductPrice p) {
  if (p.price <= 0) return 'Цена должна быть больше нуля';
  if (p.price > maxProductPrice) return 'Слишком большая цена';
  return null;
}

/// Проверка строки прайса при приёме (сервер): то же, что окна программы.
String? salesRowProblem(
  String table,
  Map<String, Object?> data,
) => switch (table) {
  'product_groups' =>
    '${data['name'] ?? ''}'.trim().isEmpty ? 'Укажите название группы' : null,
  'products' =>
    '${data['name'] ?? ''}'.trim().isEmpty ? 'Укажите название товара' : null,
  _ => null,
};

// ------------------------------------------------------------- цены и даты

/// Цены товара [productId], по дате начала (старые сначала).
List<ProductPrice> pricesOf(Iterable<ProductPrice> prices, String productId) =>
    [
      for (final p in prices)
        if (p.productId == productId) p,
    ]..sort((a, b) => a.validFrom.compareTo(b.validFrom));

/// Цена товара [productId], действующая в день [day]; null — цены ещё нет.
ProductPrice? priceAt(
  Iterable<ProductPrice> prices,
  String productId,
  DateTime day,
) {
  final d = calendarDay(day);
  ProductPrice? result;
  for (final p in prices) {
    if (p.productId != productId) continue;
    final from = calendarDay(p.validFrom);
    if (from.isAfter(d)) continue;
    if (result == null || from.isAfter(calendarDay(result.validFrom))) {
      result = p;
    }
  }
  return result;
}

/// Цена, действовавшая до [price] (у того же товара); null — [price] первая.
ProductPrice? previousPrice(Iterable<ProductPrice> prices, ProductPrice price) {
  final before = addCalendarDays(calendarDay(price.validFrom), -1);
  return priceAt(prices, price.productId, before);
}

/// Даты редакций прайса — дни, с которых начинались цены; новые сначала.
List<DateTime> priceEditions(Iterable<ProductPrice> prices) =>
    {for (final p in prices) calendarDay(p.validFrom)}.toList()
      ..sort((a, b) => b.compareTo(a));

/// Редакция, действующая в день [day] (последняя начавшаяся не позже);
/// null — до первой редакции.
DateTime? editionAt(Iterable<ProductPrice> prices, DateTime day) {
  final d = calendarDay(day);
  for (final e in priceEditions(prices)) {
    if (!e.isAfter(d)) return e;
  }
  return null;
}

/// Изменение цены в процентах (0.1 — плюс 10 %); null — прежней цены нет.
double? priceChange(int? before, int after) =>
    before == null || before == 0 ? null : (after - before) / before;

// ------------------------------------------------------------------ прайс

/// Строка прайса на дату.
class PriceListRow {
  final Product product;

  /// Действующая цена; null — у товара ещё нет цены.
  final ProductPrice? price;

  /// Цена, действовавшая до [price]; null — [price] первая.
  final ProductPrice? previous;

  /// Цена введена именно в этой редакции.
  final bool changedInEdition;

  const PriceListRow({
    required this.product,
    this.price,
    this.previous,
    this.changedInEdition = false,
  });

  /// Изменение к прежней цене (только если она менялась в этой редакции).
  double? get change => changedInEdition && price != null
      ? priceChange(previous?.price, price!.price)
      : null;
}

/// Группа прайса со строками.
class PriceListSection {
  final ProductGroup group;
  final List<PriceListRow> rows;

  const PriceListSection(this.group, this.rows);
}

/// Прайс на день [day]: группы и товары по порядку, цены на этот день.
/// [edition] — дата действующей редакции (для «вводится с …»).
class PriceListView {
  final DateTime day;
  final DateTime? edition;
  final List<PriceListSection> sections;

  const PriceListView({
    required this.day,
    required this.edition,
    required this.sections,
  });

  /// Строки всех групп подряд.
  Iterable<PriceListRow> get rows => sections.expand((s) => s.rows);
}

int _byOrder(int aOrder, String aName, int bOrder, String bName) {
  final byOrder = aOrder.compareTo(bOrder);
  return byOrder != 0 ? byOrder : aName.compareTo(bName);
}

/// Группы по порядку.
List<ProductGroup> sortedGroups(Iterable<ProductGroup> groups) =>
    groups.toList()
      ..sort((a, b) => _byOrder(a.sortOrder, a.name, b.sortOrder, b.name));

/// Товары группы [groupId] по порядку.
List<Product> productsOfGroup(Iterable<Product> products, String groupId) => [
  for (final p in products)
    if (p.groupId == groupId) p,
]..sort((a, b) => _byOrder(a.sortOrder, a.name, b.sortOrder, b.name));

/// Прайс на день [day]. Без [includeHidden] — только продающиеся товары
/// (как в печати); [onlyPriced] — только товары с ценой на этот день.
/// Пустые группы не показываются.
PriceListView buildPriceList({
  required Iterable<ProductGroup> groups,
  required Iterable<Product> products,
  required Iterable<ProductPrice> prices,
  required DateTime day,
  bool includeHidden = false,
  bool onlyPriced = false,
}) {
  final edition = editionAt(prices, day);
  final sections = <PriceListSection>[];
  for (final g in sortedGroups(groups)) {
    final rows = <PriceListRow>[];
    for (final p in productsOfGroup(products, g.id)) {
      if (p.hidden && !includeHidden) continue;
      final price = priceAt(prices, p.id, day);
      if (price == null && onlyPriced) continue;
      rows.add(
        PriceListRow(
          product: p,
          price: price,
          previous: price == null ? null : previousPrice(prices, price),
          changedInEdition:
              price != null &&
              edition != null &&
              calendarDay(price.validFrom) == edition,
        ),
      );
    }
    if (rows.isNotEmpty) sections.add(PriceListSection(g, rows));
  }
  return PriceListView(
    day: calendarDay(day),
    edition: edition,
    sections: sections,
  );
}

// ------------------------------------------------------ новая редакция

/// Правки цен для редакции с [from]: по каждому товару из [newPrices]
/// (id товара → копейки) — новая цена с [from], исправление цены, уже
/// начавшейся в [from], или ничего, если цена на [from] та же.
/// [newId] — id новых записей. Список пуст — менять нечего.
List<ProductPrice> planPriceEdition({
  required Iterable<ProductPrice> prices,
  required DateTime from,
  required Map<String, int> newPrices,
  required String Function() newId,
}) {
  final day = calendarDay(from);
  final result = <ProductPrice>[];
  for (final MapEntry(key: productId, value: price) in newPrices.entries) {
    final current = priceAt(prices, productId, day);
    if (current != null && current.price == price) continue;
    if (current != null && calendarDay(current.validFrom) == day) {
      result.add(current.copyWith(price: price));
    } else {
      result.add(
        ProductPrice(
          id: newId(),
          productId: productId,
          validFrom: day,
          price: price,
        ),
      );
    }
  }
  return result;
}

/// Запись истории цены товара.
class PriceHistoryEntry {
  final ProductPrice price;
  final ProductPrice? previous;

  /// День, по который цена действовала; null — действует до сих пор.
  final DateTime? until;

  const PriceHistoryEntry(this.price, this.previous, this.until);

  double? get change => priceChange(previous?.price, price.price);
}

/// История цен товара [productId]: новые сначала.
List<PriceHistoryEntry> priceHistory(
  Iterable<ProductPrice> prices,
  String productId,
) {
  final list = pricesOf(prices, productId);
  return [
    for (var i = list.length - 1; i >= 0; i--)
      PriceHistoryEntry(
        list[i],
        i > 0 ? list[i - 1] : null,
        i + 1 < list.length
            ? addCalendarDays(calendarDay(list[i + 1].validFrom), -1)
            : null,
      ),
  ];
}

/// «+10 %», «−5,3 %»: изменение цены для человека.
String formatPriceChange(double change) {
  final percent = change * 100;
  final rounded = (percent * 10).round() / 10;
  if (rounded == 0) return '0 %';
  final sign = rounded > 0 ? '+' : '−';
  final abs = rounded.abs();
  final text = abs == abs.roundToDouble()
      ? abs.toStringAsFixed(0)
      : abs.toStringAsFixed(1).replaceAll('.', ',');
  return '$sign$text %';
}

/// Цена прайса без копеек, если их нет: «1 840», «92,50».
String formatPrice(int kopecks) {
  final text = formatRub(kopecks);
  return text.endsWith(',00') ? text.substring(0, text.length - 3) : text;
}

// ------------------------------------------------------- порядок в прайсе

/// Строка списка «Товары и порядок»: заголовок группы или товар.
sealed class CatalogEntry {
  const CatalogEntry();
  String get id;
}

class CatalogGroupEntry extends CatalogEntry {
  final ProductGroup group;
  const CatalogGroupEntry(this.group);
  @override
  String get id => 'g:${group.id}';
}

class CatalogProductEntry extends CatalogEntry {
  final Product product;
  const CatalogProductEntry(this.product);
  @override
  String get id => 'p:${product.id}';
}

/// Группы и их товары одним списком — по порядку прайса.
List<CatalogEntry> catalogEntries(
  Iterable<ProductGroup> groups,
  Iterable<Product> products,
) => [
  for (final g in sortedGroups(groups)) ...[
    CatalogGroupEntry(g),
    for (final p in productsOfGroup(products, g.id)) CatalogProductEntry(p),
  ],
];

/// Перетаскивание строки [oldIndex] на место [newIndex] (как
/// `onReorderItem` у `ReorderableListView`: место — после удаления строки
/// из списка). Группа
/// переезжает вместе с товарами; товар попадает в группу, под заголовком
/// которой оказался (выше всех заголовков — в первую группу). Возвращает
/// только изменившиеся группы и товары (новый порядок и группа).
({List<ProductGroup> groups, List<Product> products}) reorderCatalog({
  required List<ProductGroup> groups,
  required List<Product> products,
  required int oldIndex,
  required int newIndex,
}) {
  final entries = catalogEntries(groups, products);
  if (oldIndex < 0 || oldIndex >= entries.length) {
    return (groups: const [], products: const []);
  }
  final target = newIndex.clamp(0, entries.length - 1);
  final moved = entries.removeAt(oldIndex);
  entries.insert(target, moved);

  final changedGroups = <ProductGroup>[];
  final changedProducts = <Product>[];
  if (moved is CatalogGroupEntry) {
    // Новый порядок групп — по заголовкам; товары остаются в своих.
    final order = [
      for (final e in entries)
        if (e is CatalogGroupEntry) e.group,
    ];
    for (final (i, g) in order.indexed) {
      if (g.sortOrder != i) changedGroups.add(g.copyWith(sortOrder: i));
    }
    return (groups: changedGroups, products: changedProducts);
  }
  final heads = entries.whereType<CatalogGroupEntry>();
  if (heads.isEmpty) return (groups: changedGroups, products: changedProducts);
  final firstGroup = heads.first.group;
  String groupId = firstGroup.id;
  final order = <String, int>{};
  // Товары выше первого заголовка — в начало первой группы.
  for (final e in entries) {
    if (e is CatalogGroupEntry) {
      groupId = e.group.id;
      continue;
    }
    final p = (e as CatalogProductEntry).product;
    final index = order[groupId] = (order[groupId] ?? -1) + 1;
    if (p.groupId != groupId || p.sortOrder != index) {
      changedProducts.add(p.copyWith(groupId: groupId, sortOrder: index));
    }
  }
  return (groups: changedGroups, products: changedProducts);
}
