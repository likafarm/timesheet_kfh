import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfx_time_tracking/services/excel_export.dart';
import 'package:kfx_time_tracking/services/price_list_pdf.dart';
import 'package:kfx_time_tracking/services/xlsx.dart';

/// Прайс-лист (11.1): PDF по образцу владельца и книга Excel. Посмотреть
/// файлы глазами: `KFH_PRICE_OUT=<папка> flutter test
/// test/services/price_list_pdf_test.dart`.
void main() {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  // Прайс владельца от 01.03.2026 (часть позиций).
  const meat = ProductGroup(id: 'g1', name: 'Говядина охлаждённая');
  const offal = ProductGroup(
    id: 'g2',
    name: 'Субпродукты говяжьи',
    sortOrder: 1,
  );
  final items = <(String, String, int, ProductUnit)>[
    ('g1', 'Вырезка', 1840, ProductUnit.kg),
    ('g1', 'Говядина бескостная (мякоть)', 1150, ProductUnit.kg),
    ('g1', 'Говядина охлаждённая (набор)', 920, ProductUnit.kg),
    ('g1', 'Голяшка (бульонка)', 560, ProductUnit.kg),
    ('g2', 'Вымя', 400, ProductUnit.kg),
    ('g2', 'Голова', 1000, ProductUnit.pcs),
    ('g2', 'Язык', 1150, ProductUnit.kg),
  ];
  final products = [
    for (final (i, (g, name, _, unit)) in items.indexed)
      Product(id: 'p$i', groupId: g, name: name, unit: unit, sortOrder: i),
  ];
  final prices = [
    for (final (i, (_, _, rub, _)) in items.indexed)
      ProductPrice(
        id: 'x$i',
        productId: 'p$i',
        validFrom: DateTime(2026, 3, 1),
        price: rub * 100,
      ),
    // Прежняя цена вырезки — для столбца «Изменение».
    ProductPrice(
      id: 'old',
      productId: 'p0',
      validFrom: DateTime(2025, 5, 1),
      price: 160000,
    ),
  ];
  final view = buildPriceList(
    groups: [offal, meat],
    products: products,
    prices: prices,
    day: DateTime(2026, 11, 24),
    onlyPriced: true,
  );
  final out = Platform.environment['KFH_PRICE_OUT'];

  test('PDF собирается со шрифтами и логотипом', () async {
    expect(File(priceListLogoAsset).existsSync(), isTrue);
    final bytes = await buildPriceListPdf(
      view,
      asset: asset,
      directorName: 'Лопатин И. И.',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(20000));
    if (out != null) {
      File('$out/price_list.pdf').writeAsBytesSync(bytes);
    }
  });

  test('без логотипа — тоже собирается', () async {
    final bytes = await buildPriceListPdf(
      view,
      asset: (path) =>
          path == priceListLogoAsset ? throw StateError('нет') : asset(path),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('имя файла — по редакции', () {
    expect(priceListFileName(DateTime(2026, 3, 1)), 'Прайс-лист с 01.03.2026');
    expect(priceListFileName(null), 'Прайс-лист');
  });

  test('Excel: группы, цены числами, изменение', () {
    final book = priceListWorkbook(view: view);
    final sheet = book.sheets.single;
    final texts = [
      for (final row in sheet.rows)
        for (final c in row)
          if (c.value case final XlsxText t) t.text,
    ];
    expect(texts, contains('Говядина охлаждённая'));
    expect(texts, contains('Голова'));
    final bytes = book.encode();
    expect(bytes, isNotEmpty);
    if (out != null) File('$out/price_list.xlsx').writeAsBytesSync(bytes);
  });
}
