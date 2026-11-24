// packages/domain/lib/src/sales/price_import.dart
//
// Загрузка прайс-листа из Excel (этап 11.1, просьба владельца 2026-11-24):
// лист как в бумажном прайсе или в выгрузке программы — строка заголовка
// («Наименование», «Цена», «Единица»), строки-группы (только название) и
// строки товаров (название и цена). Дата редакции — из строки «вводится
// с дд.мм.гггг», если она есть. Товары и группы сопоставляются с
// заведёнными по названию; цены пишутся как новая редакция
// ([planPriceEdition]): меняются только отличающиеся.

import '../finance/money.dart';
import '../utils/date_utils.dart';
import 'price_list.dart';

/// Товар из файла.
class ImportedProduct {
  final String name;
  final int price;
  final ProductUnit unit;

  const ImportedProduct(this.name, this.price, this.unit);
}

/// Группа из файла с товарами по порядку.
class ImportedGroup {
  final String name;
  final List<ImportedProduct> products;

  const ImportedGroup(this.name, this.products);
}

/// Прайс, прочитанный из файла.
class ImportedPriceList {
  /// «вводится с …» из файла; null — в файле нет.
  final DateTime? validFrom;
  final List<ImportedGroup> groups;

  /// Строки, которые не разобрались (для человека).
  final List<String> skipped;

  const ImportedPriceList({
    required this.validFrom,
    required this.groups,
    this.skipped = const [],
  });

  int get productCount => groups.fold(0, (s, g) => s + g.products.length);
}

class PriceImportException implements Exception {
  final String message;
  const PriceImportException(this.message);
  @override
  String toString() => message;
}

/// Название для сравнения: без лишних пробелов, регистра и «ё».
String priceNameKey(String name) => name
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .replaceAll('ё', 'е');

/// Единица из текста ячейки: «кг», «шт», «уп», «банка»; пусто — кг.
ProductUnit? parseProductUnit(String? text) {
  final t = (text ?? '').trim().toLowerCase().replaceAll('.', '');
  if (t.isEmpty || t.startsWith('кг') || t == 'kg') return ProductUnit.kg;
  if (t.startsWith('шт') || t == 'pcs') return ProductUnit.pcs;
  if (t.startsWith('уп')) return ProductUnit.pack;
  if (t.startsWith('бан') || t.startsWith('б/')) return ProductUnit.can;
  return null;
}

/// Цена из ячейки: число Excel («1840», «92.5») или текст («1 840,00 ₽»).
int? parsePriceCell(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return null;
  final asNumber = double.tryParse(t);
  if (asNumber != null) return toKopecks(asNumber);
  return parseRub(
    t.replaceAll(RegExp(r'(руб\.?|р\.)', caseSensitive: false), ''),
  );
}

final _validFromPattern = RegExp(
  r'вводится\s+с\s+(\d{1,2})\.(\d{1,2})\.(\d{4})',
  caseSensitive: false,
);

/// Разбор листа [rows] (ячейки текстом, как их даёт чтение xlsx).
/// Нет заголовка с «Наименование» и «Цена» — [PriceImportException].
ImportedPriceList parsePriceSheet(List<List<String?>> rows) {
  String cell(List<String?> row, int? i) =>
      i == null || i >= row.length ? '' : (row[i] ?? '').trim();

  DateTime? validFrom;
  int? header, nameCol, priceCol, unitCol, numberCol;
  for (final (r, row) in rows.indexed) {
    for (final (c, raw) in row.indexed) {
      final text = (raw ?? '').trim();
      final lower = text.toLowerCase();
      final m = _validFromPattern.firstMatch(text);
      if (m != null && validFrom == null) {
        validFrom = DateTime(
          int.parse(m[3]!),
          int.parse(m[2]!),
          int.parse(m[1]!),
        );
      }
      if (header != null) continue;
      if (lower.startsWith('наименование')) nameCol = c;
      if (lower.startsWith('цена')) priceCol ??= c;
      if (lower.startsWith('единица') || lower == 'ед' || lower == 'ед.') {
        unitCol = c;
      }
      if (lower.startsWith('№')) numberCol = c;
    }
    if (header == null && nameCol != null && priceCol != null) header = r;
    if (header == null) {
      nameCol = priceCol = unitCol = numberCol = null;
    }
  }
  if (header == null || nameCol == null || priceCol == null) {
    throw const PriceImportException(
      'Не найдена строка заголовка: нужны столбцы «Наименование» и «Цена»',
    );
  }

  final groups = <ImportedGroup>[];
  final skipped = <String>[];
  var current = <ImportedProduct>[];
  String? currentName;
  void close() {
    if (currentName != null || current.isNotEmpty) {
      groups.add(ImportedGroup(currentName ?? 'Без группы', current));
    }
  }

  for (final row in rows.skip(header + 1)) {
    // Группа может стоять в любом столбце (в бумажном прайсе — с первого).
    // В столбце «№» пропускается только номер («1.», «12»).
    final texts = [
      for (final (c, v) in row.indexed)
        if ((v ?? '').trim().isNotEmpty &&
            !(c == numberCol && RegExp(r'^\d+\.?$').hasMatch(v!.trim())))
          (c, v!.trim()),
    ];
    if (texts.isEmpty) continue;
    // Подпись («Глава КФХ … ФИО»), итог, отметка выгрузки — конец таблицы.
    if (_isFooter(texts.first.$2)) break;
    final name = cell(row, nameCol);
    final priceText = cell(row, priceCol);
    if (name.isEmpty && priceText.isEmpty) {
      // Строка-группа: один текст, без цены.
      if (texts.length == 1 && double.tryParse(texts.single.$2) == null) {
        final text = texts.single.$2;
        if (_isFooter(text)) break;
        close();
        currentName = text;
        current = [];
      } else {
        skipped.add(texts.map((t) => t.$2).join(' | '));
      }
      continue;
    }
    if (name.isNotEmpty && priceText.isEmpty) {
      if (_isFooter(name)) break;
      if (texts.length == 1) {
        close();
        currentName = name;
        current = [];
      } else {
        skipped.add('$name: нет цены');
      }
      continue;
    }
    final price = parsePriceCell(priceText);
    final unit = parseProductUnit(cell(row, unitCol));
    if (name.isEmpty || price == null || price <= 0 || unit == null) {
      skipped.add(
        [
          name,
          priceText,
          cell(row, unitCol),
        ].where((s) => s.isNotEmpty).join(' | '),
      );
      continue;
    }
    current.add(ImportedProduct(name, price, unit));
  }
  close();
  final result = [
    for (final g in groups)
      if (g.products.isNotEmpty) g,
  ];
  if (result.isEmpty) {
    throw const PriceImportException(
      'В файле не нашлось ни одного товара с ценой',
    );
  }
  return ImportedPriceList(
    validFrom: validFrom,
    groups: result,
    skipped: skipped,
  );
}

bool _isFooter(String text) {
  final t = text.toLowerCase();
  return t.startsWith('глава') ||
      t.startsWith('итого') ||
      t.startsWith('выгружено') ||
      t.startsWith('директор');
}

// ------------------------------------------------------------- план записи

/// Что станет с товаром файла.
enum PriceImportAction {
  /// Нового товара ещё нет — заводится с этой ценой.
  newProduct,

  /// Цена с даты редакции — новая или исправленная.
  newPrice,

  /// Цена та же — ничего не пишется.
  same,
}

class PriceImportLine {
  final ImportedProduct item;
  final String groupName;
  final PriceImportAction action;

  /// Цена до даты редакции (для «было → стало»); null — не было.
  final int? before;

  const PriceImportLine(this.item, this.groupName, this.action, this.before);
}

/// План загрузки: что завести и что записать одной транзакцией.
class PriceImportPlan {
  final DateTime validFrom;
  final List<PriceImportLine> lines;
  final List<ProductGroup> groups;
  final List<Product> products;
  final List<ProductPrice> prices;

  /// Товары программы, которых в файле нет (их цены не меняются).
  final List<Product> missing;

  const PriceImportPlan({
    required this.validFrom,
    required this.lines,
    required this.groups,
    required this.products,
    required this.prices,
    required this.missing,
  });

  bool get isEmpty => groups.isEmpty && products.isEmpty && prices.isEmpty;
  int count(PriceImportAction a) => lines.where((l) => l.action == a).length;
  int get newGroups => groups.length;
}

/// План загрузки [file] с даты [validFrom] поверх заведённого прайса.
/// Группа и товар ищутся по названию (без регистра, «ё» = «е»); найденный
/// товар, отмеченный «Не продаётся», снова становится продающимся;
/// единица и группа товара берутся из файла.
PriceImportPlan planPriceImport({
  required ImportedPriceList file,
  required DateTime validFrom,
  required List<ProductGroup> groups,
  required List<Product> products,
  required List<ProductPrice> prices,
  required String Function() newId,
}) {
  final day = calendarDay(validFrom);
  final groupByName = {for (final g in groups) priceNameKey(g.name): g};
  final productByName = {for (final p in products) priceNameKey(p.name): p};
  final newGroups = <ProductGroup>[];
  final savedProducts = <Product>[];
  final newPrices = <String, int>{};
  final lines = <PriceImportLine>[];
  final seen = <String>{};
  var groupOrder = groups.length;

  for (final g in file.groups) {
    var group = groupByName[priceNameKey(g.name)];
    if (group == null) {
      group = ProductGroup(id: newId(), name: g.name, sortOrder: groupOrder++);
      groupByName[priceNameKey(g.name)] = group;
      newGroups.add(group);
    }
    for (final (i, item) in g.products.indexed) {
      final key = priceNameKey(item.name);
      if (!seen.add(key)) continue; // повтор в файле — первый
      final existing = productByName[key];
      final product = existing == null
          ? Product(
              id: newId(),
              groupId: group.id,
              name: item.name,
              unit: item.unit,
              sortOrder: i,
            )
          : existing.copyWith(
              groupId: group.id,
              unit: item.unit,
              sortOrder: i,
              hidden: false,
            );
      if (existing == null ||
          existing.groupId != product.groupId ||
          existing.unit != product.unit ||
          existing.sortOrder != product.sortOrder ||
          existing.hidden) {
        savedProducts.add(product);
      }
      final before = existing == null
          ? null
          : priceAt(prices, existing.id, day)?.price;
      newPrices[product.id] = item.price;
      lines.add(
        PriceImportLine(
          item,
          group.name,
          existing == null
              ? PriceImportAction.newProduct
              : before == item.price
              ? PriceImportAction.same
              : PriceImportAction.newPrice,
          before,
        ),
      );
    }
  }
  final priceChanges = planPriceEdition(
    prices: prices,
    from: day,
    newPrices: newPrices,
    newId: newId,
  );
  return PriceImportPlan(
    validFrom: day,
    lines: lines,
    groups: newGroups,
    products: savedProducts,
    prices: priceChanges,
    missing: [
      for (final p in products)
        if (!p.hidden && !seen.contains(priceNameKey(p.name))) p,
    ],
  );
}
