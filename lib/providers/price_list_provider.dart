// lib/providers/price_list_provider.dart
//
// Прайс-лист (этап 11.1): группы, товары и цены с даты поверх базы
// [AppProvider]. Правят админ и бухгалтер, оператор только смотрит и
// печатает (решение владельца 2026-11-24; то же правило проверяет сервер).
// Нарушение — сообщение внизу окна и false.

import 'package:flutter/foundation.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show newUuid;

import 'app_provider.dart';

class PriceListProvider extends ChangeNotifier {
  PriceListProvider(this._app) : _seenVersion = _app.dataVersion {
    _app.addListener(_onApp);
  }

  final AppProvider _app;
  int _seenVersion;

  PriceListRepository get _repo => _app.repos.priceList;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<ProductGroup> _groups = const [];
  List<Product> _products = const [];
  List<ProductPrice> _prices = const [];

  /// Группы по порядку.
  List<ProductGroup> get groups => _groups;
  List<Product> get products => _products;
  List<ProductPrice> get prices => _prices;

  /// Даты редакций, новые сначала.
  List<DateTime> get editions => priceEditions(_prices);

  /// Прайс правят админ и бухгалтер.
  bool get canEdit => !_app.operatorMode;

  CompanySettings? get settings => _app.companySettings;

  String newId() => newUuid();

  void _onApp() {
    if (_app.dataVersion != _seenVersion) {
      _seenVersion = _app.dataVersion;
      if (_loaded) load();
    }
  }

  @override
  void dispose() {
    _app.removeListener(_onApp);
    super.dispose();
  }

  Future<void> load() async {
    _groups = sortedGroups(await _repo.groups());
    _products = await _repo.products();
    _prices = await _repo.prices();
    _loaded = true;
    notifyListeners();
  }

  Product? product(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Прайс на день [day] (см. [buildPriceList]).
  PriceListView view(
    DateTime day, {
    bool includeHidden = false,
    bool onlyPriced = false,
  }) => buildPriceList(
    groups: _groups,
    products: _products,
    prices: _prices,
    day: day,
    includeHidden: includeHidden,
    onlyPriced: onlyPriced,
  );

  List<PriceHistoryEntry> history(String productId) =>
      priceHistory(_prices, productId);

  // ----------------------------------------------------------- правка

  /// Почему последняя правка не записана (для окна правки); null — записана.
  String? get lastProblem => _lastProblem;
  String? _lastProblem;

  bool _fail(String message) {
    _lastProblem = message;
    _app.showNotice(message);
    return false;
  }

  bool _allowed() {
    _lastProblem = null;
    return canEdit ||
        _fail(
          'Прайс-лист правят администратор и бухгалтер — здесь только '
          'просмотр и печать.',
        );
  }

  Future<bool> _write(Future<void> Function() action) async {
    try {
      await action();
    } on DuplicateEntryException catch (e) {
      return _fail('Не сохранено: ${e.message}');
    } on StateError catch (e) {
      return _fail('Не сохранено: ${e.message}');
    } catch (e) {
      return _fail('Не сохранено: $e');
    }
    await load();
    return true;
  }

  Future<bool> saveGroup(ProductGroup g) async {
    if (!_allowed()) return false;
    final problem = productGroupProblem(g);
    if (problem != null) return _fail('Не сохранено: $problem');
    return _write(() => _repo.saveGroup(g));
  }

  Future<bool> deleteGroup(String id) async {
    if (!_allowed()) return false;
    return _write(() => _repo.deleteGroup(id));
  }

  /// Записать товар; [firstPrice] — цена с [priceFrom] для нового товара.
  Future<bool> saveProduct(
    Product p, {
    int? firstPrice,
    DateTime? priceFrom,
  }) async {
    if (!_allowed()) return false;
    final problem = productProblem(p);
    if (problem != null) return _fail('Не сохранено: $problem');
    ProductPrice? price;
    if (firstPrice != null) {
      price = ProductPrice(
        id: newId(),
        productId: p.id,
        validFrom: calendarDay(priceFrom ?? DateTime.now()),
        price: firstPrice,
      );
      final priceProblem = productPriceProblem(price);
      if (priceProblem != null) return _fail('Не сохранено: $priceProblem');
    }
    return _write(() async {
      await _repo.saveProduct(p);
      if (price != null) await _repo.savePrices([price]);
    });
  }

  Future<bool> deleteProduct(String id) async {
    if (!_allowed()) return false;
    return _write(() => _repo.deleteProduct(id));
  }

  /// Поменять местами соседей по порядку: [items] — список в нынешнем
  /// порядке, [index] переезжает на [index] + [delta].
  Future<bool> moveProduct(List<Product> items, int index, int delta) async {
    if (!_allowed()) return false;
    final target = index + delta;
    if (target < 0 || target >= items.length) return false;
    final order = [...items];
    final moved = order.removeAt(index);
    order.insert(target, moved);
    return _write(() async {
      for (final (i, p) in order.indexed) {
        if (p.sortOrder != i) await _repo.saveProduct(p.copyWith(sortOrder: i));
      }
    });
  }

  Future<bool> moveGroup(int index, int delta) async {
    if (!_allowed()) return false;
    final target = index + delta;
    if (target < 0 || target >= _groups.length) return false;
    final order = [..._groups];
    final moved = order.removeAt(index);
    order.insert(target, moved);
    return _write(() async {
      for (final (i, g) in order.indexed) {
        if (g.sortOrder != i) await _repo.saveGroup(g.copyWith(sortOrder: i));
      }
    });
  }

  /// Новая редакция с [from]: [newPrices] — id товара → копейки. Пишутся
  /// только изменённые цены, одной транзакцией. Возвращает число
  /// записанных цен или null — не записано.
  Future<int?> saveEdition(DateTime from, Map<String, int> newPrices) async {
    if (!_allowed()) return null;
    for (final price in newPrices.values) {
      if (price <= 0) {
        _fail('Не сохранено: цена должна быть больше нуля');
        return null;
      }
      if (price > maxProductPrice) {
        _fail('Не сохранено: слишком большая цена');
        return null;
      }
    }
    final changes = planPriceEdition(
      prices: _prices,
      from: from,
      newPrices: newPrices,
      newId: newId,
    );
    if (changes.isEmpty) {
      _fail('Цены не изменились — записывать нечего');
      return null;
    }
    final ok = await _write(() => _repo.savePrices(changes));
    return ok ? changes.length : null;
  }

  /// Исправить цену [price] (сумму) — без новой редакции.
  Future<bool> correctPrice(ProductPrice price, int kopecks) async {
    if (!_allowed()) return false;
    final fixed = price.copyWith(price: kopecks);
    final problem = productPriceProblem(fixed);
    if (problem != null) return _fail('Не сохранено: $problem');
    return _write(() => _repo.savePrices([fixed]));
  }

  /// Удалить ошибочную цену: снова действует прежняя.
  Future<bool> deletePrice(String id) async {
    if (!_allowed()) return false;
    return _write(() => _repo.deletePrice(id));
  }
}
