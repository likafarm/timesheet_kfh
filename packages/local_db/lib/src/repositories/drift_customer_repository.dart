// Покупатели на drift (этап 11.3): строки таблицы ↔ модели kfh_domain.

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';

class DriftCustomerRepository implements CustomerRepository {
  final LocalDatabase _db;
  DriftCustomerRepository(this._db);

  static String? _text(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  Future<List<Customer>> customers() async => [
    for (final r in await _db.salesDao.allCustomers())
      Customer(
        id: r.uuid,
        name: r.name,
        phone: r.phone,
        address: r.address,
        channel: CustomerChannel.fromCode(r.channel),
        contact: r.contact,
        notes: r.notes,
        counterpartyId: r.counterpartyUuid,
      ),
  ];

  @override
  Future<void> saveCustomer(Customer c) => _db.salesDao.saveRow(
    _db.customers,
    c.id,
    (now, editor, isNew) => CustomersCompanion(
      uuid: Value(c.id),
      name: Value(c.name.trim()),
      phone: Value(_text(c.phone)),
      address: Value(_text(c.address)),
      channel: Value(c.channel?.code),
      contact: Value(_text(c.contact)),
      notes: Value(_text(c.notes)),
      counterpartyUuid: Value(c.counterpartyId),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteCustomer(String id) =>
      _db.salesDao.softDelete(_db.customers, id);
}
