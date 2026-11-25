// lib/services/batch_pdf.dart
//
// Печать выдачи (этап 11.5): список пакетов (кому, что, фактический вес,
// сумма; пометка, если итог сильно отличается от предварительного),
// этикетки 70 × 50 мм для принтера этикеток, бирки на листе А4 (8 на
// лист) и маршрут доставки (адрес, телефон,
// сумма, графа для отметки).

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/orders_provider.dart';

final _day = DateFormat('dd.MM.yyyy', 'ru');

String _rub(int kopecks) => '${formatPrice(kopecks)} ₽';

String _qty(double v) {
  final s = v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

class BatchPrintLine {
  /// Товар (набор — его название).
  final String product;

  /// Состав набора: «Ребро 1,5, Шея 2»; пусто — не набор.
  final String composition;
  final String ordered;
  final String fact;
  final int? amount;

  /// Не выдана (не хватило) — бирка не нужна.
  final bool missing;

  /// Группа прайса («Говядина охлаждённая»).
  final String group;

  /// Цена за единицу: «1 840 ₽/кг»; пусто — своя сумма или нет цены.
  final String price;

  const BatchPrintLine({
    required this.product,
    required this.ordered,
    required this.fact,
    this.composition = '',
    this.amount,
    this.missing = false,
    this.group = '',
    this.price = '',
  });

  /// Товар с составом — для списка пакетов.
  String get name => composition.isEmpty ? product : '$product ($composition)';
}

class BatchPrintOrder {
  final String label;
  final String customer;
  final String? phone;
  final bool delivery;
  final String? address;
  final String? comment;
  final OrderKind kind;
  final List<BatchPrintLine> lines;
  final double weight;
  final int due;
  final bool complete;

  /// Итог отличается от предварительной суммы сверх допуска: текст
  /// пометки («предварительно было ≈ 2 400 ₽, +25 %»); null — нет.
  final String? warning;

  const BatchPrintOrder({
    required this.label,
    required this.customer,
    required this.delivery,
    required this.kind,
    required this.lines,
    required this.weight,
    required this.due,
    required this.complete,
    this.phone,
    this.address,
    this.comment,
    this.warning,
  });
}

class BatchPrint {
  final String title;
  final List<BatchPrintOrder> orders;

  /// День выдачи, «дд.мм.гггг».
  final String day;

  /// Хозяйство и его телефон — для этикеток (из настроек).
  final String? company;
  final String? phone;

  const BatchPrint({
    required this.title,
    required this.orders,
    this.day = '',
    this.company,
    this.phone,
  });
}

/// Данные для печати выдачи [b] из [p].
BatchPrint batchPrintData(OrdersProvider p, SaleBatch b) {
  final orders = <BatchPrintOrder>[];
  for (final o in p.liveOrdersOf(b.id)) {
    final lines = p.linesOf(o.id);
    final (:top, :parts) = orderLines(lines, o.id);
    final printed = <BatchPrintLine>[];
    var planned = 0;
    var plannedKnown = top.isNotEmpty;
    for (final l in top) {
      final ps = parts[l.id] ?? const <SaleOrderLine>[];
      final product = p.products[l.productId];
      // Предварительно — по заказанному; снятое (не хватило) не в счёт.
      final est = l.state == LineState.missing
          ? 0
          : lineEstimate(
              l.copyWith(state: LineState.open),
              p.products,
              parts: [
                for (final x in ps)
                  if (x.state != LineState.missing)
                    x.copyWith(state: LineState.open, weight: () => null),
              ],
            );
      if (est == null) {
        plannedKnown = false;
      } else {
        planned += est;
      }
      final qty = factQty(l, product, parts: ps);
      final byWeight =
          ps.isNotEmpty || (product?.unit ?? ProductUnit.kg) == ProductUnit.kg;
      final fact = l.state == LineState.missing
          ? 'нет'
          : qty == null
          ? ''
          : '${_qty(qty)} ${byWeight ? 'кг' : product!.unit.title}';
      printed.add(
        BatchPrintLine(
          product: product?.name ?? '?',
          composition: [
            for (final x in ps)
              if (x.state != LineState.missing)
                '${p.products[x.productId]?.name ?? '?'}'
                    '${x.weight == null ? '' : ' ${_qty(x.weight!)}'}',
          ].join(', '),
          missing: l.state == LineState.missing,
          group: p.groupName(product?.groupId) ?? '',
          price: l.pricing == LinePricing.fixed || l.price == null
              ? ''
              : '${_rub(l.price!)}/${ps.isNotEmpty ? 'кг' : product?.unit.title ?? 'кг'}',
          ordered: [
            if (l.orderedQty != null && l.orderedUnit != null)
              l.orderedUnit == OrderedUnit.rub
                  ? 'на ${_rub((l.orderedQty! * 100).round())}'
                  : '${_qty(l.orderedQty!)} ${l.orderedUnit!.title}',
            if ((l.orderedText ?? '').trim().isNotEmpty) l.orderedText!.trim(),
          ].join(', '),
          fact: fact,
          amount: lineAmount(l, p.products, parts: ps),
        ),
      );
    }
    final t = p.totals(o.id);
    String? warning;
    if (t.complete && plannedKnown && planned > 0 && o.kind == OrderKind.sale) {
      final d = (t.fact - planned) / planned;
      if (d.abs() > p.tolerance) {
        warning =
            'предварительно было ≈ ${_rub(planned)}, '
            '${d > 0 ? '+' : '−'}${(d.abs() * 100).round()} %';
      }
    }
    final c = p.customers[o.customerId];
    orders.add(
      BatchPrintOrder(
        label: p.label(o),
        customer: c?.name ?? '?',
        phone: c?.phone == null ? null : formatPhone(c!.phone),
        delivery: o.delivery == Delivery.delivery,
        address: o.address ?? c?.address,
        comment: o.comment,
        kind: o.kind,
        lines: printed,
        weight: t.weight,
        due: o.kind == OrderKind.sale ? t.due : 0,
        complete: t.complete,
        warning: warning,
      ),
    );
  }
  final title = (b.title ?? '').trim();
  final settings = p.companySettings;
  String? opt(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
  return BatchPrint(
    title: 'Выдача ${_day.format(b.day)}${title.isEmpty ? '' : ' · $title'}',
    orders: orders,
    day: _day.format(b.day),
    company: opt(settings?.companyName),
    phone: opt(settings?.phone),
  );
}

Future<pw.ThemeData> _theme(Future<ByteData> Function(String) asset) async =>
    pw.ThemeData.withFont(
      base: pw.Font.ttf(await asset('assets/fonts/Roboto-Regular.ttf')),
      bold: pw.Font.ttf(await asset('assets/fonts/Roboto-Bold.ttf')),
    );

final _bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

String _dueText(BatchPrintOrder o) => o.kind != OrderKind.sale
    ? o.kind.title
    : '${o.complete ? '' : '≈ '}${_rub(o.due)}';

/// Список пакетов: заказ за заказом.
Future<Uint8List> buildBatchPackagesPdf(
  BatchPrint data, {
  required Future<ByteData> Function(String path) asset,
}) async {
  final doc = pw.Document(
    title: '${data.title} — пакеты',
    theme: await _theme(asset),
  );
  const pad = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2);
  pw.Widget cell(String s, {pw.TextStyle? style, bool right = false}) =>
      pw.Padding(
        padding: pad,
        child: pw.Text(
          s,
          style: style ?? const pw.TextStyle(fontSize: 10),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );
  final head = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          '${data.title} — пакеты (${data.orders.length})',
          style: _bold.copyWith(fontSize: 14),
        ),
      ),
      build: (_) => [
        for (final o in data.orders)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    pw.Text(o.label, style: _bold.copyWith(fontSize: 13)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        [o.customer, ?o.phone].join(' · '),
                        style: _bold.copyWith(fontSize: 11),
                      ),
                    ),
                    pw.Text(_dueText(o), style: _bold.copyWith(fontSize: 12)),
                  ],
                ),
                pw.Text(
                  [
                    o.delivery
                        ? 'Доставка${o.address == null ? '' : ': ${o.address}'}'
                        : 'Самовывоз',
                    if ((o.comment ?? '').trim().isNotEmpty) o.comment!.trim(),
                  ].join(' · '),
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 3),
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FlexColumnWidth(2),
                    2: pw.FlexColumnWidth(1.5),
                    3: pw.FlexColumnWidth(1.7),
                  },
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                      width: 0.3,
                      color: PdfColors.grey500,
                    ),
                  ),
                  children: [
                    pw.TableRow(
                      children: [
                        cell('Товар', style: head),
                        cell('Заказано', style: head),
                        cell('Факт', style: head, right: true),
                        cell('Сумма', style: head, right: true),
                      ],
                    ),
                    for (final l in o.lines)
                      pw.TableRow(
                        children: [
                          cell(l.name),
                          cell(l.ordered),
                          cell(l.fact, right: true),
                          cell(
                            l.amount == null ? '' : _rub(l.amount!),
                            right: true,
                          ),
                        ],
                      ),
                  ],
                ),
                if (o.weight > 0 || o.warning != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Row(
                      children: [
                        if (o.warning != null)
                          pw.Expanded(
                            child: pw.Text(
                              '! ${o.warning}',
                              style: _bold.copyWith(
                                fontSize: 9,
                                color: PdfColors.red800,
                              ),
                            ),
                          )
                        else
                          pw.Spacer(),
                        if (o.weight > 0)
                          pw.Text(
                            'Вес: ${_qty(o.weight)} кг',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

/// Бирка на пакет: заказ и одна его строка (набор — целиком, с составом),
/// [index] из [count] пакетов заказа.
class BatchTag {
  final BatchPrintOrder order;
  final BatchPrintLine line;
  final int index;
  final int count;
  const BatchTag(this.order, this.line, this.index, this.count);
}

/// Бирки выдачи: на каждый вид продукции заказа — своя, на набор — одна
/// (с составом); строки, которых не хватило, без бирки.
List<BatchTag> batchTags(BatchPrint data) => [
  for (final o in data.orders)
    for (final (i, l) in [
      for (final l in o.lines)
        if (!l.missing) l,
    ].indexed)
      BatchTag(o, l, i + 1, o.lines.where((x) => !x.missing).length),
];

/// Бирки на пакеты: 8 на лист А4 (2 × 4), крупный номер заказа.
Future<Uint8List> buildBatchTagsPdf(
  BatchPrint data, {
  required Future<ByteData> Function(String path) asset,
}) async {
  final doc = pw.Document(
    title: '${data.title} — бирки',
    theme: await _theme(asset),
  );
  final tags = batchTags(data);
  pw.Widget tag(BatchTag t) {
    final o = t.order;
    final l = t.line;
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.8, style: pw.BorderStyle.dashed),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(o.label, style: _bold.copyWith(fontSize: 26)),
              ),
              if (t.count > 1)
                pw.Text(
                  'пакет ${t.index} из ${t.count}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
          pw.Text(
            [o.customer, ?o.phone].join(' · '),
            style: _bold.copyWith(fontSize: 12),
            maxLines: 1,
          ),
          pw.Text(
            o.delivery ? 'Доставка: ${o.address ?? ''}' : 'Самовывоз',
            style: const pw.TextStyle(fontSize: 9),
            maxLines: 1,
          ),
          pw.SizedBox(height: 6),
          pw.Text(l.product, style: _bold.copyWith(fontSize: 15), maxLines: 2),
          if (l.composition.isNotEmpty)
            pw.Text(
              'состав: ${l.composition}',
              style: const pw.TextStyle(fontSize: 10),
              maxLines: 3,
            ),
          pw.Spacer(),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(l.fact, style: _bold.copyWith(fontSize: 16)),
              ),
              if (o.kind != OrderKind.sale)
                pw.Text(o.kind.title, style: _bold.copyWith(fontSize: 14))
              else if (l.amount != null)
                pw.Text(_rub(l.amount!), style: _bold.copyWith(fontSize: 16)),
            ],
          ),
          if (t.count > 1 && o.kind == OrderKind.sale)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'весь заказ: ${_dueText(o)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  const perPage = 8;
  for (var i = 0; i < tags.length; i += perPage) {
    final chunk = tags.skip(i).take(perPage).toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Column(
          children: [
            for (var r = 0; r < 4; r++)
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < 2; c++)
                      pw.Expanded(
                        child: r * 2 + c < chunk.length
                            ? tag(chunk[r * 2 + c])
                            : pw.SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  if (tags.isEmpty) {
    doc.addPage(pw.Page(build: (_) => pw.Text('Пакетов нет')));
  }
  return doc.save();
}

/// Размер этикетки принтера этикеток (решение владельца 2026-11-25):
/// 70 × 50 мм (ширина × высота), прямая термопечать (Godex G530U через
/// драйвер Windows).
final labelFormat = PdfPageFormat(70 * PdfPageFormat.mm, 50 * PdfPageFormat.mm);

/// Чёрно-белый логотип для термопечати (цветной вышел бы серой рябью).
const labelLogoAsset = 'assets/branding/logo_mono.png';

/// Этикетки на пакеты для принтера этикеток: страница PDF = одна
/// этикетка [labelFormat] — логотип хозяйства, номер заказа и пакет,
/// покупатель, товар (группа, состав набора), дата выдачи, цена за
/// единицу, вес и сумма, телефон хозяйства. Только чёрный: прямая
/// термопечать.
Future<Uint8List> buildBatchLabelsPdf(
  BatchPrint data, {
  required Future<ByteData> Function(String path) asset,
}) async {
  final doc = pw.Document(
    title: '${data.title} — этикетки',
    theme: await _theme(asset),
  );
  pw.MemoryImage? logo;
  try {
    logo = pw.MemoryImage((await asset(labelLogoAsset)).buffer.asUint8List());
  } catch (_) {
    // Логотипа нет — название хозяйства текстом.
  }
  const small = pw.TextStyle(fontSize: 6.5);
  final rule = pw.Container(height: 0.8, color: PdfColors.black);
  final tags = batchTags(data);
  for (final t in tags) {
    final o = t.order;
    final l = t.line;
    doc.addPage(
      pw.Page(
        pageFormat: labelFormat,
        margin: const pw.EdgeInsets.all(2.5 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Шапка: «Ферма ЛИКА» слева, заказ и покупатель справа.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 26 * PdfPageFormat.mm,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Ферма', style: _bold.copyWith(fontSize: 7)),
                      if (logo != null)
                        pw.Image(logo, width: 26 * PdfPageFormat.mm)
                      else
                        pw.Text(
                          data.company ?? 'КФХ',
                          style: _bold.copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        t.count > 1
                            ? '${o.label}  ${t.index}/${t.count}'
                            : o.label,
                        style: _bold.copyWith(fontSize: 15),
                      ),
                      pw.Text(
                        o.customer,
                        style: _bold.copyWith(fontSize: 8),
                        maxLines: 1,
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            rule,
            pw.SizedBox(height: 2),
            // Товар.
            pw.Text(
              l.product,
              style: _bold.copyWith(fontSize: 10.5),
              maxLines: 2,
            ),
            if (l.group.isNotEmpty) pw.Text(l.group, style: small, maxLines: 1),
            if (l.composition.isNotEmpty)
              pw.Text('Состав: ${l.composition}', style: small, maxLines: 2),
            pw.Spacer(),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text('Дата: ${data.day}', style: small)),
                if (l.price.isNotEmpty)
                  pw.Text('Цена: ${l.price}', style: small),
              ],
            ),
            pw.SizedBox(height: 1),
            rule,
            pw.SizedBox(height: 1),
            // Вес и сумма — крупно.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Text(l.fact, style: _bold.copyWith(fontSize: 15)),
                ),
                if (o.kind != OrderKind.sale)
                  pw.Text(o.kind.title, style: _bold.copyWith(fontSize: 11))
                else if (l.amount != null)
                  pw.Text(_rub(l.amount!), style: _bold.copyWith(fontSize: 15)),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    o.delivery ? 'Доставка: ${o.address ?? ''}' : 'Самовывоз',
                    style: small,
                    maxLines: 1,
                  ),
                ),
                if (t.count > 1 && o.kind == OrderKind.sale)
                  pw.Text('весь заказ ${_dueText(o)}', style: small),
              ],
            ),
            if (data.phone != null)
              pw.Text(
                '${data.company ?? ''}  тел. ${data.phone}'.trim(),
                style: const pw.TextStyle(fontSize: 6),
                maxLines: 1,
              ),
          ],
        ),
      ),
    );
  }
  if (tags.isEmpty) {
    doc.addPage(
      pw.Page(pageFormat: labelFormat, build: (_) => pw.Text('Пакетов нет')),
    );
  }
  return doc.save();
}

/// Маршрут доставки: заказы с доставкой по адресу.
Future<Uint8List> buildBatchRoutePdf(
  BatchPrint data, {
  required Future<ByteData> Function(String path) asset,
}) async {
  final doc = pw.Document(
    title: '${data.title} — доставка',
    theme: await _theme(asset),
  );
  final list = [
    for (final o in data.orders)
      if (o.delivery) o,
  ]..sort((a, b) => (a.address ?? '').compareTo(b.address ?? ''));
  const pad = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4);
  pw.Widget cell(String s, {pw.TextStyle? style}) => pw.Padding(
    padding: pad,
    child: pw.Text(s, style: style ?? const pw.TextStyle(fontSize: 10)),
  );
  final total = list.fold<int>(0, (s, o) => s + o.due);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          '${data.title} — доставка (${list.length})',
          style: _bold.copyWith(fontSize: 14),
        ),
      ),
      build: (_) => [
        if (list.isEmpty)
          pw.Text('Заказов с доставкой нет')
        else
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(2.2),
              3: pw.FlexColumnWidth(3.5),
              4: pw.FlexColumnWidth(1.6),
              5: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                children: [
                  for (final h in [
                    '№',
                    'Заказ',
                    'Покупатель',
                    'Адрес',
                    'К оплате',
                    'Отметка',
                  ])
                    cell(h, style: _bold.copyWith(fontSize: 10)),
                ],
              ),
              for (final (i, o) in list.indexed)
                pw.TableRow(
                  children: [
                    cell('${i + 1}'),
                    cell(o.label),
                    cell([o.customer, ?o.phone].join('\n')),
                    cell(
                      [
                        o.address ?? '',
                        if ((o.comment ?? '').trim().isNotEmpty)
                          o.comment!.trim(),
                      ].join('\n'),
                    ),
                    cell(_dueText(o)),
                    cell(''),
                  ],
                ),
            ],
          ),
        if (list.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Итого к получению: ${_rub(total)}',
              style: _bold.copyWith(fontSize: 11),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}
