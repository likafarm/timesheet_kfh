import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfx_time_tracking/services/excel_export.dart';
import 'package:kfx_time_tracking/services/xlsx_reader.dart';

/// Действующий прайс владельца (утверждён 01.03.2026, 28 позиций).
const ownerPriceList = <(String, List<(String, int, ProductUnit)>)>[
  (
    'Говядина охлаждённая',
    [
      ('Вырезка', 1840, ProductUnit.kg),
      ('Говядина бескостная (мякоть)', 1150, ProductUnit.kg),
      ('Говядина охлаждённая (набор)', 920, ProductUnit.kg),
      ('Голяшка (бульонка)', 560, ProductUnit.kg),
      ('Грудина', 630, ProductUnit.kg),
      ('Лопатка', 920, ProductUnit.kg),
      ('Пашина', 460, ProductUnit.kg),
      ('Ребро', 575, ProductUnit.kg),
      ('Филейные края (уголки)', 840, ProductUnit.kg),
      ('Шея на кости', 920, ProductUnit.kg),
    ],
  ),
  (
    'Субпродукты говяжьи',
    [
      ('Вымя', 400, ProductUnit.kg),
      ('Голова', 1000, ProductUnit.pcs),
      ('Жир', 60, ProductUnit.kg),
      ('Копыта', 290, ProductUnit.kg),
      ('Кости', 60, ProductUnit.kg),
      ('Кость суповая', 200, ProductUnit.kg),
      ('Лёгкое', 230, ProductUnit.kg),
      ('Мясо рубщика', 450, ProductUnit.kg),
      ('Обрезь (не жирная)', 400, ProductUnit.kg),
      ('Печень', 520, ProductUnit.kg),
      ('Почки', 345, ProductUnit.kg),
      ('Рубец, книжка', 170, ProductUnit.kg),
      ('Сердце', 520, ProductUnit.kg),
      ('Суставы для холодца', 230, ProductUnit.kg),
      ('Хвост', 400, ProductUnit.kg),
      ('Щёки', 1840, ProductUnit.kg),
      ('Язык', 1150, ProductUnit.kg),
      ('Яйца бычьи', 400, ProductUnit.kg),
    ],
  ),
];

/// Загрузка прайса из Excel (11.1): выгрузка программы читается обратно
/// без потерь. Файл прайса владельца для загрузки:
/// `KFH_PRICE_OUT=<папка> flutter test test/services/price_import_test.dart`.
void main() {
  test('прайс от 01.03.2026: выгрузка → загрузка, 28 цен на месте', () {
    final groups = <ProductGroup>[];
    final products = <Product>[];
    final prices = <ProductPrice>[];
    for (final (gi, (name, items)) in ownerPriceList.indexed) {
      groups.add(ProductGroup(id: 'g$gi', name: name, sortOrder: gi));
      for (final (i, (product, rub, unit)) in items.indexed) {
        final id = 'p$gi-$i';
        products.add(
          Product(
            id: id,
            groupId: 'g$gi',
            name: product,
            unit: unit,
            sortOrder: i,
          ),
        );
        prices.add(
          ProductPrice(
            id: 'x$gi-$i',
            productId: id,
            validFrom: DateTime(2026, 3, 1),
            price: rub * 100,
          ),
        );
      }
    }
    final view = buildPriceList(
      groups: groups,
      products: products,
      prices: prices,
      day: DateTime(2026, 3, 1),
      onlyPriced: true,
    );
    final bytes = Uint8List.fromList(priceListWorkbook(view: view).encode());
    final out = Platform.environment['KFH_PRICE_OUT'];
    if (out != null) {
      File('$out/Прайс-лист с 01.03.2026.xlsx').writeAsBytesSync(bytes);
    }

    final read = readPriceList(bytes);
    expect(read.validFrom, DateTime(2026, 3, 1));
    expect(read.skipped, isEmpty);
    expect(read.groups.map((g) => g.name), [
      for (final (name, _) in ownerPriceList) name,
    ]);
    expect(read.productCount, 28);
    final got = {
      for (final g in read.groups)
        for (final p in g.products) p.name: (p.price, p.unit),
    };
    for (final (_, items) in ownerPriceList) {
      for (final (name, rub, unit) in items) {
        expect(got[name], (rub * 100, unit), reason: name);
      }
    }

    // В пустую программу: всё новое; повторно — без изменений.
    var n = 0;
    final plan = planPriceImport(
      file: read,
      validFrom: read.validFrom!,
      groups: const [],
      products: const [],
      prices: const [],
      newId: () => 'n${++n}',
    );
    expect(plan.groups.length, 2);
    expect(plan.products.length, 28);
    expect(plan.prices.length, 28);
    final again = planPriceImport(
      file: read,
      validFrom: read.validFrom!,
      groups: groups,
      products: products,
      prices: prices,
      newId: () => 'n${++n}',
    );
    expect(again.isEmpty, isTrue);
    expect(again.count(PriceImportAction.same), 28);
  });
}
