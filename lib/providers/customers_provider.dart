// lib/providers/customers_provider.dart
//
// Покупатели (этап 11.3) поверх базы [AppProvider]: список, поиск, правка.
// Ведут специалист по продажам, бухгалтер и админ; оператор покупателей не
// получает (сервер их ему не выдаёт). Нарушение — сообщение внизу окна и
// false.

import 'package:flutter/foundation.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show newUuid;

import 'app_provider.dart';

class CustomersProvider extends ChangeNotifier {
  CustomersProvider(this._app) : _seenVersion = _app.dataVersion {
    _app.addListener(_onApp);
  }

  final AppProvider _app;
  int _seenVersion;

  CustomerRepository get _repo => _app.repos.customers;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<Customer> _customers = const [];
  List<Customer> get customers => _customers;

  /// Покупателей ведут все, кроме оператора.
  bool get canEdit => !_app.operatorMode;

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

  /// Долг или аванс покупателя по всем заказам (11.6).
  Map<String, CustomerBalance> get balances => _balances;
  Map<String, CustomerBalance> _balances = const {};

  Future<void> load() async {
    _customers = searchCustomers(await _repo.customers(), '');
    _balances = await _loadBalances();
    _loaded = true;
    notifyListeners();
  }

  Future<Map<String, CustomerBalance>> _loadBalances() async {
    final repos = _app.repos;
    final orders = await repos.orders.orders();
    if (orders.isEmpty) return const {};
    final products = {
      for (final p in await repos.priceList.products()) p.id: p,
    };
    final linesByOrder = <String, List<SaleOrderLine>>{};
    for (final l in await repos.orders.lines()) {
      (linesByOrder[l.orderId] ??= []).add(l);
    }
    final payments = paymentsByOrder(await repos.finance.operations());
    final byCustomer = <String, List<SaleOrder>>{};
    for (final o in orders) {
      (byCustomer[o.customerId] ??= []).add(o);
    }
    return {
      for (final MapEntry(key: id, value: list) in byCustomer.entries)
        id: customerBalance(
          list,
          (orderId) =>
              orderTotals(linesByOrder[orderId] ?? const [], orderId, products),
          payments,
        ),
    };
  }

  List<Customer> search(String query) => searchCustomers(_customers, query);

  /// Покупатель с тем же телефоном (подсказка в окне); null — нет.
  Customer? samePhone(String? phone, {String? exceptId}) =>
      customerWithPhone(_customers, phone, exceptId: exceptId);

  String? get lastProblem => _lastProblem;
  String? _lastProblem;

  bool _fail(String message) {
    _lastProblem = message;
    _app.showNotice(message);
    return false;
  }

  Future<bool> save(Customer c) async {
    _lastProblem = null;
    if (!canEdit) return _fail('Покупателей ведут продавец и бухгалтер');
    final problem = customerProblem(c);
    if (problem != null) return _fail('Не сохранено: $problem');
    try {
      await _repo.saveCustomer(c);
    } catch (e) {
      return _fail('Не сохранено: $e');
    }
    await load();
    return true;
  }

  Future<bool> delete(String id) async {
    _lastProblem = null;
    if (!canEdit) return _fail('Покупателей ведут продавец и бухгалтер');
    try {
      await _repo.deleteCustomer(id);
    } catch (e) {
      return _fail('Не удалено: $e');
    }
    await load();
    return true;
  }
}
