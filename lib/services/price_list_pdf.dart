// lib/services/price_list_pdf.dart
//
// Печать прайс-листа (этап 11.1) — как образец владельца от 01.03.2026:
// логотип и заголовок, «вводится с …», таблица по группам (№, наименование,
// цена, единица), внизу «Глава КФХ ____ ФИО» и дата. Печать и подпись
// ставятся на бумаге.

import 'dart:typed_data';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Логотип хозяйства для печати.
const priceListLogoAsset = 'assets/branding/logo.png';

/// «дд.мм.гггг»
String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Имя файла прайса на дату редакции.
String priceListFileName(DateTime? edition) =>
    edition == null ? 'Прайс-лист' : 'Прайс-лист с ${_day(edition)}';

/// PDF прайса [view]. [asset] — чтение файла программы (шрифты
/// `assets/fonts`, логотип; нет логотипа — без него). [directorName] — ФИО
/// главы КФХ для подписи (из настроек хозяйства).
Future<Uint8List> buildPriceListPdf(
  PriceListView view, {
  required Future<ByteData> Function(String path) asset,
  String? directorName,
  String title = 'ПРАЙС-ЛИСТ',
  String subtitle =
      'на мясо – говядина охлаждённая, субпродукты говяжьи, полуфабрикаты',
}) async {
  final regular = pw.Font.ttf(await asset('assets/fonts/Roboto-Regular.ttf'));
  final bold = pw.Font.ttf(await asset('assets/fonts/Roboto-Bold.ttf'));
  pw.MemoryImage? logo;
  try {
    logo = pw.MemoryImage(
      (await asset(priceListLogoAsset)).buffer.asUint8List(),
    );
  } catch (_) {
    // Логотипа нет — заголовок без него.
  }

  final doc = pw.Document(
    title: priceListFileName(view.edition),
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const border = pw.BorderSide(width: 0.6);
  const pad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3);
  final cell = pw.TextStyle(font: regular, fontSize: 11);
  final head = pw.TextStyle(font: bold, fontSize: 11);
  final groupStyle = pw.TextStyle(font: bold, fontSize: 12);

  pw.Widget text(
    String s, {
    pw.TextStyle? style,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: pad,
    child: pw.Text(s, style: style ?? cell, textAlign: align),
  );

  const widths = {
    0: pw.FixedColumnWidth(42),
    1: pw.FlexColumnWidth(4),
    2: pw.FlexColumnWidth(1.6),
    3: pw.FlexColumnWidth(1.4),
  };
  // Таблица без верхней линии: её даёт строка над ней.
  pw.Widget table(List<pw.TableRow> rows, {bool top = false}) => pw.Table(
    border: pw.TableBorder(
      left: border,
      right: border,
      top: top ? border : pw.BorderSide.none,
      bottom: border,
      horizontalInside: border,
      verticalInside: border,
    ),
    columnWidths: widths,
    children: rows,
  );

  final body = <pw.Widget>[
    table(top: true, [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          text('№\nп\\п', style: head, align: pw.TextAlign.center),
          text(
            'Наименование продукции',
            style: head,
            align: pw.TextAlign.center,
          ),
          text('Цена, руб.', style: head, align: pw.TextAlign.center),
          text('Единица\nизмерения', style: head, align: pw.TextAlign.center),
        ],
      ),
    ]),
  ];
  var n = 0;
  for (final section in view.sections) {
    final rows = <pw.TableRow>[
      for (final r in section.rows)
        if (r.price case final price?)
          pw.TableRow(
            children: [
              text('${++n}.', align: pw.TextAlign.center),
              text(r.product.name),
              text(formatPrice(price.price), align: pw.TextAlign.center),
              text(r.product.unit.title),
            ],
          ),
    ];
    if (rows.isEmpty) continue;
    body
      ..add(
        pw.Container(
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: border, right: border, bottom: border),
          ),
          padding: const pw.EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: pw.Text(section.group.name, style: groupStyle),
        ),
      )
      ..add(table(rows));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 36, 40, 36),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // «Ферма» над знаком «ЛИКА» — как на образце.
                    pw.SizedBox(
                      width: 150,
                      child: logo == null
                          ? null
                          : pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Ферма',
                                  style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 14,
                                    color: const PdfColor.fromInt(0xFF38373C),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Image(logo),
                              ],
                            ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            title,
                            style: pw.TextStyle(font: regular, fontSize: 15),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            subtitle,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: regular, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                if (view.edition != null)
                  pw.Text(
                    'вводится с ${_day(view.edition!)} г.',
                    style: pw.TextStyle(font: regular, fontSize: 12),
                  ),
                pw.SizedBox(height: 4),
              ],
            )
          : pw.SizedBox(),
      build: (context) => [
        ...body,
        // Подпись — сразу под таблицей, как на образце.
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 28),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Глава КФХ', style: cell),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  height: 1,
                  margin: const pw.EdgeInsets.only(bottom: 3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: border),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(directorName ?? '', style: cell),
                  if (view.edition != null)
                    pw.Text('${_day(view.edition!)} г.', style: cell),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
