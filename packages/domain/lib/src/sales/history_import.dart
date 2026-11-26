// packages/domain/lib/src/sales/history_import.dart
//
// Перенос истории заказов из «Заказы мяса.xlsx» (этап 11.7, ответ
// владельца 6: всё — покупатели и заказы). Файл только читается.
//
// Лист заказов: строка = позиция; «Номер заказа» `ДДМ-N` (иногда с
// «(i/n)») собирает строки в заказ; «Срок поставки» — день выдачи (число
// дня Excel, диапазон «5-7.06.2025» — с первого дня, «01.11(25.10.2025)» —
// 01.11 того же года); «Заказ» — текст: товар (по правилам и таблице
// соответствий, которую проверяет владелец) и «заказано» («2 кг», «1 шт»,
// «на 1000р»); «Вес» — факт; «Цена итого» — своя сумма, «Цена за кг» — своя
// цена. Лист «Мясо безвозмездно» — заказы «без оплаты» и «себе».
//
// Покупатели склеиваются по телефону, без телефона — по имени; с уже
// заведёнными — так же. Перенесённый заказ помечен строкой Excel
// (`SaleOrder.historyRow`): повторная загрузка его не задваивает, а оплата
// считается полученной до программы (выручка уже в финансах и кассе).
// Прошедшая выдача — заказ «Выдан», строки без веса — «вес не записан».

import '../utils/date_utils.dart';
import 'customers.dart';
import 'orders.dart';
import 'price_list.dart';

/// Строки листа «Мясо безвозмездно» в `historyRow` — с этого числа.
const historyFreeRowBase = 1000000;

/// Группа прайса для товаров из истории, которых нет в прайсе (скрытые).
const historyGroupName = 'Из истории заказов';

/// Товар для позиций, которые не узнались.
const historyOtherProduct = 'Прочее (из истории заказов)';

/// Пометка выдачи, заведённой переносом.
const historyBatchNote = 'Из «Заказы мяса.xlsx»';

/// Строка листа заказов.
class HistoryOrderRow {
  /// Номер строки в Excel (с 1, заголовок — 1).
  final int row;
  final bool paid;
  final DateTime day;
  final DateTime? dayTo;
  final String name;
  final String text;
  final String? number;
  final String? phone;
  final String? address;
  final double? weight;
  final double? total;
  final double? pricePerKg;
  final String? channel;

  const HistoryOrderRow({
    required this.row,
    required this.paid,
    required this.day,
    this.dayTo,
    required this.name,
    required this.text,
    this.number,
    this.phone,
    this.address,
    this.weight,
    this.total,
    this.pricePerKg,
    this.channel,
  });
}

/// Строка листа «Мясо безвозмездно».
class HistoryFreeRow {
  final int row;
  final DateTime day;
  final String who;
  final double? weight;
  final double? price;
  const HistoryFreeRow({
    required this.row,
    required this.day,
    required this.who,
    this.weight,
    this.price,
  });

  /// «Себе» — заказ хозяйства, иначе — «без оплаты».
  bool get own => normText(who) == 'себе';
}

/// Прочитанный файл: строки и пропуски (причина → число строк).
class HistorySource {
  final List<HistoryOrderRow> orders;
  final List<HistoryFreeRow> free;
  final Map<String, int> skipped;
  const HistorySource(this.orders, this.free, this.skipped);
}

class HistoryFormatException implements Exception {
  final String message;
  const HistoryFormatException(this.message);
  @override
  String toString() => message;
}

/// Текст для сравнения: нижний регистр, «ё» → «е», пробелы сжаты.
String normText(String s) =>
    s.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Число из ячейки («2.5», «2,5», «=1.2+0.8»); null — не число.
double? historyNumber(String? v) {
  if (v == null) return null;
  var s = v.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.startsWith('=')) {
    s = s.substring(1);
    if (!RegExp(r'^[0-9.+]+$').hasMatch(s)) return null;
    var sum = 0.0;
    for (final part in s.split('+')) {
      final n = double.tryParse(part);
      if (n == null) return null;
      sum += n;
    }
    return sum;
  }
  return double.tryParse(s);
}

/// День выдачи из ячейки: число дня Excel, «5-7.06.2025» (день и день по),
/// «01.11(25.10.2025)»; null — не дата.
(DateTime, DateTime?)? historyDay(String? v) {
  if (v == null) return null;
  final t = v.trim();
  final serial = double.tryParse(t);
  if (serial != null && serial > 20000 && serial < 80000) {
    // День Excel: 1 = 01.01.1900, с ошибкой високосного 1900 года.
    return (DateTime(1899, 12, 30 + serial.floor()), null);
  }
  var m = RegExp(r'^(\d{1,2})-(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(t);
  if (m != null) {
    final y = int.parse(m[4]!), mo = int.parse(m[3]!);
    return (
      DateTime(y, mo, int.parse(m[1]!)),
      DateTime(y, mo, int.parse(m[2]!)),
    );
  }
  m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.?\s*\(.*?(\d{4})\)').firstMatch(t);
  if (m != null) {
    return (
      DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)),
      null,
    );
  }
  m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(t);
  if (m != null) {
    return (
      DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)),
      null,
    );
  }
  return null;
}

int? _col(List<String?> header, List<String> names) {
  for (var i = 0; i < header.length; i++) {
    final h = normText(header[i] ?? '');
    if (names.any((n) => h == n)) return i;
  }
  return null;
}

/// Разобрать листы книги [sheets] (ячейки текстом): лист заказов находится
/// по заголовку «ФИО» + «Заказ» + «Номер заказа», лист «Мясо безвозмездно»
/// — по «Дата» + «получатель».
HistorySource parseHistoryWorkbook(List<List<List<String?>>> sheets) {
  final orders = <HistoryOrderRow>[];
  final free = <HistoryFreeRow>[];
  final skipped = <String, int>{};
  void skip(String why) => skipped[why] = (skipped[why] ?? 0) + 1;
  var found = false;
  for (final rows in sheets) {
    if (rows.isEmpty) continue;
    final header = rows.first;
    final name = _col(header, ['фио']);
    final text = _col(header, ['заказ']);
    final number = _col(header, ['номер заказа']);
    if (name != null && text != null && number != null) {
      found = true;
      final paid = _col(header, ['оплата']);
      final day = _col(header, ['срок поставки', 'дата поставки']);
      final phone = _col(header, ['телефон']);
      final address = _col(header, ['адрес']);
      final weight = _col(header, ['вес']);
      final total = _col(header, ['цена итого', 'сумма']);
      final perKg = _col(header, ['цена за кг']);
      final channel = _col(header, ['вид связи']);
      String? cell(List<String?> r, int? i) {
        if (i == null || i >= r.length) return null;
        final v = r[i]?.trim();
        return v == null || v.isEmpty ? null : v;
      }

      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        final who = cell(r, name), what = cell(r, text);
        if (who == null && what == null) {
          if (r.any((c) => (c ?? '').trim().isNotEmpty)) {
            skip('без имени и заказа');
          }
          continue;
        }
        final d = historyDay(cell(r, day));
        if (d == null) {
          skip('без даты поставки');
          continue;
        }
        orders.add(
          HistoryOrderRow(
            row: i + 1,
            paid: normText(cell(r, paid) ?? '') == 'да',
            day: d.$1,
            dayTo: d.$2,
            name: who ?? 'Без имени',
            text: what ?? '',
            number: cell(r, number),
            phone: cell(r, phone),
            address: cell(r, address),
            weight: historyNumber(cell(r, weight)),
            total: historyNumber(cell(r, total)),
            pricePerKg: historyNumber(cell(r, perKg)),
            channel: cell(r, channel),
          ),
        );
      }
      continue;
    }
    final date = _col(header, ['дата']);
    final who = _col(header, ['получатель']);
    if (date != null && who != null) {
      final weight = _col(header, ['вес']);
      final price = _col(header, ['цена']);
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        String? cell(int? c) =>
            c == null || c >= r.length ? null : r[c]?.trim();
        final w = cell(who);
        final d = historyDay(cell(date));
        if (w == null || w.isEmpty || d == null) continue;
        free.add(
          HistoryFreeRow(
            row: i + 1,
            day: d.$1,
            who: w,
            weight: historyNumber(cell(weight)),
            price: historyNumber(cell(price)),
          ),
        );
      }
    }
  }
  if (!found) {
    throw const HistoryFormatException(
      'В файле нет листа заказов: нужны столбцы «ФИО», «Заказ» и «Номер '
      'заказа»',
    );
  }
  return HistorySource(orders, free, skipped);
}

// ------------------------------------------------------------ товары

/// Правила узнавания товара по тексту заказа: шаблон → название товара
/// прайса. Первое совпадение побеждает (порядок важен: «набор» раньше
/// частей, «суповая кость» раньше «кости»).
const historyProductRules = <(String, String)>[
  (r'набор', 'Говядина охлаждённая (набор)'),
  (r'вырезк', 'Вырезка'),
  (r'мякот|яблочк', 'Говядина бескостная (мякоть)'),
  (r'голяш|бульонк|мосол', 'Голяшка (бульонка)'),
  (r'грудин', 'Грудина'),
  (r'лопатк', 'Лопатка'),
  (r'пашин', 'Пашина'),
  (r'р[её]бр', 'Ребро'),
  (r'кра[йяе]|уголк', 'Филейные края (уголки)'),
  (r'ше[яи]', 'Шея на кости'),
  (r'вым', 'Вымя'),
  (r'голов', 'Голова'),
  (r'жир', 'Жир'),
  (r'копыт', 'Копыта'),
  (r'суп', 'Кость суповая'),
  (r'сустав|холодц', 'Суставы для холодца'),
  (r'кост|мосл', 'Кости'),
  (r'л[её]к?гк', 'Лёгкое'),
  (r'рубщик', 'Мясо рубщика'),
  (r'обрез', 'Обрезь (не жирная)'),
  (r'печен', 'Печень'),
  (r'почк', 'Почки'),
  (r'рубец|книжк', 'Рубец, книжка'),
  (r'сердц', 'Сердце'),
  (r'хвост', 'Хвост'),
  (r'щ[её]к', 'Щёки'),
  (r'язык', 'Язык'),
  (r'яйц', 'Яйца бычьи'),
  (r'трахе', 'Трахея'),
  (r'диафрагм', 'Диафрагма'),
];

/// Название товара по правилам; null — не узнан.
String? historyRuleProduct(String text) {
  final t = text.toLowerCase();
  for (final (pattern, name) in historyProductRules) {
    if (RegExp(pattern).hasMatch(t)) return name;
  }
  return null;
}

/// «Заказано» из текста: «2 кг», «1,5кг», «3 шт», «на 1000р».
(double, OrderedUnit)? historyOrdered(String text) {
  final t = text.toLowerCase().replaceAll(',', '.');
  var m = RegExp(r'на\s*(\d+)\s*р').firstMatch(t);
  if (m != null) return (double.parse(m[1]!), OrderedUnit.rub);
  m = RegExp(r'(\d+(?:\.\d+)?)\s*(кг|шт)').firstMatch(t);
  if (m != null) {
    return (
      double.parse(m[1]!),
      m[2] == 'кг' ? OrderedUnit.kg : OrderedUnit.pcs,
    );
  }
  return null;
}

const _channels = {
  'тг': CustomerChannel.telegram,
  'wa': CustomerChannel.whatsapp,
  'вк': CustomerChannel.vk,
  'смс': CustomerChannel.sms,
};

/// «Вид связи»: канал и ник («тг @olga»), иначе — комментарий заказа
/// («НАПОМНИТЬ ЗАБРАТЬ!»).
({CustomerChannel? channel, String? contact, String? comment}) historyChannel(
  String? text,
) {
  if (text == null || text.trim().isEmpty) {
    return (channel: null, contact: null, comment: null);
  }
  final t = text.trim();
  final first = t.split(RegExp(r'\s+')).first;
  final ch = _channels[first.replaceAll(',', '').toLowerCase()];
  if (ch == null) return (channel: null, contact: null, comment: t);
  final rest = t.substring(first.length).replaceAll(RegExp(r'^[\s,]+'), '');
  return (channel: ch, contact: rest.isEmpty ? null : rest, comment: null);
}

/// Телефон из ячейки: 11 цифр с 7/8 → «+7…»; меньше 5 цифр — нет.
String? historyPhone(String? v) {
  final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length < 5) return null;
  if (d.length == 11 && (d.startsWith('7') || d.startsWith('8'))) {
    return '+7${d.substring(1)}';
  }
  if (d.length == 10) return '+7$d';
  return d;
}

// ------------------------------------------------------------- план

/// Текст позиции из Excel и товар, к которому он отнесён.
class HistoryTextMatch {
  final String text;
  final int count;

  /// Товар прайса; null — «Прочее» (не узнан).
  final String? productId;

  /// Название товара, которого в прайсе нет, — будет заведён скрытым.
  final String? newProductName;

  /// Выбран вручную ([planHistoryImport] `overrides`).
  final bool manual;

  const HistoryTextMatch({
    required this.text,
    required this.count,
    this.productId,
    this.newProductName,
    this.manual = false,
  });
}

/// Покупатель из Excel: под каким ключом склеен, какие имена встретились,
/// с кем из уже заведённых совпал.
class HistoryCustomerMatch {
  final String name;
  final String? phone;
  final Set<String> names;
  final int rows;

  /// Уже заведённый покупатель (по телефону или имени); null — новый.
  final String? existingId;
  const HistoryCustomerMatch({
    required this.name,
    this.phone,
    required this.names,
    required this.rows,
    this.existingId,
  });
}

/// Что запишет перенос.
class HistoryImportPlan {
  final List<ProductGroup> newGroups;
  final List<Product> newProducts;
  final List<Customer> newCustomers;

  /// Уже заведённые покупатели, которым перенос дописывает пустые поля.
  final List<Customer> updatedCustomers;
  final List<SaleBatch> newBatches;
  final List<(SaleOrder, List<SaleOrderLine>)> orders;

  /// Заказы, уже перенесённые раньше (те же строки Excel), — пропущены.
  final int alreadyImported;
  final Map<String, int> skippedRows;

  /// Строки, где в Excel не отмечено «Оплата: да» (для сведения).
  final int notPaidRows;
  final List<HistoryTextMatch> texts;
  final List<HistoryCustomerMatch> customers;

  const HistoryImportPlan({
    required this.newGroups,
    required this.newProducts,
    required this.newCustomers,
    required this.updatedCustomers,
    required this.newBatches,
    required this.orders,
    required this.alreadyImported,
    required this.skippedRows,
    required this.notPaidRows,
    required this.texts,
    required this.customers,
  });

  int get lines => orders.fold(0, (s, o) => s + o.$2.length);
  bool get isEmpty =>
      orders.isEmpty && newCustomers.isEmpty && updatedCustomers.isEmpty;
}

/// План переноса [source] поверх уже заведённых данных. [overrides] —
/// выбор владельца: текст позиции (как в Excel) → id товара; [today] —
/// прошедшие выдачи дают заказы «Выдан».
HistoryImportPlan planHistoryImport(
  HistorySource source, {
  required List<ProductGroup> groups,
  required List<Product> products,
  required List<ProductPrice> prices,
  required List<Customer> customers,
  required List<SaleBatch> batches,
  required List<SaleOrder> orders,
  Map<String, String> overrides = const {},
  required DateTime today,
  required String Function() newId,
}) {
  final day0 = calendarDay(today);
  // ---- товары
  final byName = {for (final p in products) normText(p.name): p};
  final newGroups = <ProductGroup>[];
  final newProducts = <Product>[];
  ProductGroup? historyGroup = groups
      .where((g) => normText(g.name) == normText(historyGroupName))
      .firstOrNull;
  Product productNamed(String name) {
    final have = byName[normText(name)];
    if (have != null) return have;
    if (historyGroup == null) {
      historyGroup = ProductGroup(
        id: newId(),
        name: historyGroupName,
        sortOrder:
            groups.fold(0, (m, g) => g.sortOrder > m ? g.sortOrder : m) + 1,
      );
      newGroups.add(historyGroup!);
    }
    final p = Product(
      id: newId(),
      groupId: historyGroup!.id,
      name: name,
      sortOrder: newProducts.length,
      hidden: true,
      notes: 'Заведено при переносе истории заказов',
    );
    newProducts.add(p);
    byName[normText(name)] = p;
    return p;
  }

  final productsById = {for (final p in products) p.id: p};
  final textCounts = <String, int>{};
  for (final r in source.orders) {
    textCounts[r.text] = (textCounts[r.text] ?? 0) + 1;
  }
  final matches = <HistoryTextMatch>[];
  final productOfText = <String, Product>{};
  for (final MapEntry(key: text, value: count) in textCounts.entries) {
    final chosen = overrides[text];
    final rule = historyRuleProduct(text);
    if (chosen != null && productsById.containsKey(chosen)) {
      productOfText[text] = productsById[chosen]!;
      matches.add(
        HistoryTextMatch(
          text: text,
          count: count,
          productId: chosen,
          manual: true,
        ),
      );
    } else if (rule != null) {
      final inPrice = byName[normText(rule)];
      productOfText[text] = productNamed(rule);
      matches.add(
        HistoryTextMatch(
          text: text,
          count: count,
          productId: inPrice?.id,
          newProductName: inPrice == null ? rule : null,
        ),
      );
    } else {
      productOfText[text] = productNamed(historyOtherProduct);
      matches.add(HistoryTextMatch(text: text, count: count));
    }
  }
  matches.sort((a, b) => b.count.compareTo(a.count));

  // ---- покупатели
  final byPhone = <String, Customer>{};
  final byCustomerName = <String, Customer>{};
  for (final c in customers) {
    final d = phoneDigits(c.phone);
    if (d.length >= 10) byPhone[d.substring(d.length - 10)] = c;
    byCustomerName.putIfAbsent(normText(c.name), () => c);
  }
  final keyed = <String, _CustomerDraft>{};
  _CustomerDraft customerFor(
    String name,
    String? phoneCell,
    String? address,
    String? channelCell,
  ) {
    final phone = historyPhone(phoneCell);
    final digits = phoneDigits(phone);
    final key = digits.length >= 10
        ? 'p${digits.substring(digits.length - 10)}'
        : digits.isNotEmpty
        ? 'p$digits'
        : 'n${normText(name)}';
    final ch = historyChannel(channelCell);
    final draft = keyed.putIfAbsent(key, () {
      final existing = digits.length >= 10
          ? byPhone[digits.substring(digits.length - 10)]
          : byCustomerName[normText(name)];
      return _CustomerDraft(existing, newId(), name, phone);
    });
    draft.names.add(name.trim());
    draft.rows++;
    draft.address ??= address?.trim().isEmpty ?? true ? null : address!.trim();
    if (draft.channel == null && ch.channel != null) {
      draft.channel = ch.channel;
      draft.contact = ch.contact;
    }
    return draft;
  }

  // ---- выдачи и заказы
  final batchByDay = {for (final b in batches) calendarDay(b.day): b};
  final newBatches = <SaleBatch>[];
  SaleBatch batchFor(DateTime day, DateTime? dayTo) {
    final d = calendarDay(day);
    final have = batchByDay[d];
    if (have != null) return have;
    final b = SaleBatch(
      id: newId(),
      day: d,
      dayTo: dayTo,
      notes: historyBatchNote,
    );
    batchByDay[d] = b;
    newBatches.add(b);
    return b;
  }

  final imported = {
    for (final o in orders)
      if (o.historyRow != null) o.historyRow!,
  };
  final maxNumber = <String, int>{};
  for (final o in orders) {
    if ((maxNumber[o.batchId] ?? 0) < o.number) maxNumber[o.batchId] = o.number;
  }
  final drafts = <String, _OrderDraft>{};
  var notPaid = 0;
  var alreadyImported = 0;
  final skippedOrders = <String>{};

  for (final r in source.orders) {
    final batch = batchFor(r.day, r.dayTo);
    final customer = customerFor(r.name, r.phone, r.address, r.channel);
    final base = RegExp(r'^\s*(\d+)-(\d+)').firstMatch(r.number ?? '');
    final key =
        '${batch.id}/${base != null ? 'n${base[1]}-${base[2]}' : 'c${customer.id}'}';
    if (skippedOrders.contains(key)) continue;
    var draft = drafts[key];
    if (draft == null) {
      if (imported.contains(r.row)) {
        alreadyImported++;
        skippedOrders.add(key);
        continue;
      }
      final number = base != null
          ? int.parse(base[2]!)
          : (maxNumber[batch.id] ?? 0) + 1;
      if ((maxNumber[batch.id] ?? 0) < number) maxNumber[batch.id] = number;
      draft = drafts[key] = _OrderDraft(
        batch: batch,
        customer: customer,
        row: r.row,
        number: number,
        kind: OrderKind.sale,
      );
    }
    if (!r.paid) notPaid++;
    final comment = historyChannel(r.channel).comment;
    if (comment != null && draft.comment == null) draft.comment = comment;
    draft.rows.add(r);
  }
  for (final r in source.free) {
    final batch = batchFor(r.day, null);
    final customer = customerFor(
      r.own ? 'Себе (хозяйство)' : r.who,
      null,
      null,
      null,
    );
    final key = '${batch.id}/free-${customer.id}';
    if (skippedOrders.contains(key)) continue;
    var draft = drafts[key];
    if (draft == null) {
      final row = historyFreeRowBase + r.row;
      if (imported.contains(row)) {
        alreadyImported++;
        skippedOrders.add(key);
        continue;
      }
      final number = (maxNumber[batch.id] ?? 0) + 1;
      maxNumber[batch.id] = number;
      draft = drafts[key] = _OrderDraft(
        batch: batch,
        customer: customer,
        row: row,
        number: number,
        kind: r.own ? OrderKind.own : OrderKind.free,
      )..comment = 'Из листа «Мясо безвозмездно»';
    }
    draft.free.add(r);
  }

  final planOrders = <(SaleOrder, List<SaleOrderLine>)>[];
  final other = productNamed;
  for (final d in drafts.values) {
    final past = calendarDay(d.batch.day).isBefore(day0);
    final order = SaleOrder(
      id: newId(),
      batchId: d.batch.id,
      customerId: d.customer.id,
      number: d.number,
      kind: d.kind,
      comment: d.comment,
      status: past ? OrderStatus.issued : OrderStatus.accepted,
      historyRow: d.row,
    );
    final lines = <SaleOrderLine>[];
    for (final r in d.rows) {
      final product = productOfText[r.text]!;
      final byWeight = product.unit == ProductUnit.kg;
      final ordered = historyOrdered(r.text);
      var pricing = LinePricing.list;
      int? price, fixed;
      if (r.total != null) {
        pricing = LinePricing.fixed;
        fixed = (r.total! * 100).round();
      } else if (r.pricePerKg != null) {
        pricing = LinePricing.manual;
        price = (r.pricePerKg! * 100).round();
      } else {
        price = priceAt(prices, product.id, d.batch.day)?.price;
      }
      final weight = byWeight ? r.weight : null;
      final pieces = !byWeight && r.weight != null ? r.weight!.round() : null;
      final weighed = weight != null || pieces != null;
      lines.add(
        SaleOrderLine(
          id: newId(),
          orderId: order.id,
          productId: product.id,
          sortOrder: lines.length,
          orderedQty: ordered?.$1,
          orderedUnit: ordered?.$2,
          orderedText: r.text.trim().isEmpty ? null : r.text.trim(),
          weight: weight,
          pieces: pieces,
          pricing: pricing,
          price: price,
          fixedAmount: fixed,
          state: weighed || past ? LineState.assembled : LineState.open,
          note: !weighed && past ? 'вес не записан' : null,
        ),
      );
    }
    for (final r in d.free) {
      lines.add(
        SaleOrderLine(
          id: newId(),
          orderId: order.id,
          productId: other(historyOtherProduct).id,
          sortOrder: lines.length,
          orderedText: 'мясо',
          weight: r.weight,
          pricing: LinePricing.manual,
          price: r.price == null ? 0 : (r.price! * 100).round(),
          state: LineState.assembled,
          note: r.weight == null ? 'вес не записан' : null,
        ),
      );
    }
    planOrders.add((order, lines));
  }
  planOrders.sort((a, b) {
    final c = a.$1.batchId == b.$1.batchId
        ? 0
        : _batchDay(
            newBatches,
            batches,
            a.$1.batchId,
          ).compareTo(_batchDay(newBatches, batches, b.$1.batchId));
    return c != 0 ? c : a.$1.number.compareTo(b.$1.number);
  });

  final newCustomers = <Customer>[];
  final updated = <Customer>[];
  final customerMatches = <HistoryCustomerMatch>[];
  for (final d in keyed.values) {
    customerMatches.add(
      HistoryCustomerMatch(
        name: d.existing?.name ?? d.name,
        phone: d.existing?.phone ?? d.phone,
        names: d.names,
        rows: d.rows,
        existingId: d.existing?.id,
      ),
    );
    final e = d.existing;
    if (e == null) {
      newCustomers.add(
        Customer(
          id: d.id,
          name: d.name.trim(),
          phone: d.phone,
          address: d.address,
          channel: d.channel,
          contact: d.contact,
        ),
      );
    } else if ((e.address == null && d.address != null) ||
        (e.channel == null && d.channel != null) ||
        (e.phone == null && d.phone != null)) {
      updated.add(
        e.copyWith(
          address: () => e.address ?? d.address,
          phone: () => e.phone ?? d.phone,
          channel: () => e.channel ?? d.channel,
          contact: () => e.contact ?? d.contact,
        ),
      );
    }
  }
  customerMatches.sort((a, b) => b.rows.compareTo(a.rows));

  return HistoryImportPlan(
    newGroups: newGroups,
    newProducts: newProducts,
    newCustomers: newCustomers,
    updatedCustomers: updated,
    newBatches: newBatches,
    orders: planOrders,
    alreadyImported: alreadyImported,
    skippedRows: source.skipped,
    notPaidRows: notPaid,
    texts: matches,
    customers: customerMatches,
  );
}

DateTime _batchDay(List<SaleBatch> a, List<SaleBatch> b, String id) {
  for (final x in a) {
    if (x.id == id) return x.day;
  }
  for (final x in b) {
    if (x.id == id) return x.day;
  }
  return DateTime(2000);
}

class _CustomerDraft {
  final Customer? existing;
  final String _newId;
  final String name;
  final String? phone;
  final names = <String>{};
  int rows = 0;
  String? address;
  CustomerChannel? channel;
  String? contact;
  _CustomerDraft(this.existing, this._newId, this.name, this.phone);

  String get id => existing?.id ?? _newId;
}

class _OrderDraft {
  final SaleBatch batch;
  final _CustomerDraft customer;
  final int row;
  final int number;
  final OrderKind kind;
  String? comment;
  final rows = <HistoryOrderRow>[];
  final free = <HistoryFreeRow>[];
  _OrderDraft({
    required this.batch,
    required this.customer,
    required this.row,
    required this.number,
    required this.kind,
  });
}
