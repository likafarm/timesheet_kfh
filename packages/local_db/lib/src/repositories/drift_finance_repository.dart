// Финансы на drift: строки таблиц ↔ модели kfh_domain. Запросы — в
// FinanceDao, здесь только преобразование.

import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';

class DriftFinanceRepository implements FinanceRepository {
  final LocalDatabase _db;
  DriftFinanceRepository(this._db);

  // --- Направления --------------------------------------------------------

  @override
  Future<List<FinDirection>> directions() async => [
    for (final r in await _db.financeDao.allDirections())
      FinDirection(
        id: r.uuid,
        name: r.name,
        overhead: r.overhead,
        sortOrder: r.sortOrder,
      ),
  ];

  @override
  Future<void> saveDirection(FinDirection d) => _db.financeDao.saveRow(
    _db.finDirections,
    d.id,
    (now, editor, isNew) => FinDirectionsCompanion(
      uuid: Value(d.id),
      name: Value(d.name),
      overhead: Value(d.overhead),
      sortOrder: Value(d.sortOrder),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  // --- Ключи распределения ------------------------------------------------

  /// Доли — JSON с ключами по алфавиту: одинаковые доли — одинаковая
  /// строка.
  static String encodeShares(Map<String, int> shares) =>
      jsonEncode(SplayTreeMap<String, int>.of(shares));

  static Map<String, int> decodeShares(String json) => {
    for (final e in (jsonDecode(json) as Map<String, dynamic>).entries)
      e.key: (e.value as num).toInt(),
  };

  @override
  Future<List<AllocationKey>> allocationKeys() async {
    final periods = await _db.financeDao.allPeriods();
    return [
      for (final k in await _db.financeDao.allKeys())
        AllocationKey(
          id: k.uuid,
          name: k.name,
          periods: [
            for (final p in periods)
              if (p.keyUuid == k.uuid)
                AllocationPeriod(
                  validFrom: parseDateIso(p.validFrom),
                  shares: decodeShares(p.shares),
                ),
          ],
        ),
    ];
  }

  /// Ключ и его версии одной транзакцией: версия с той же датой
  /// начала сохраняет свой uuid, лишние версии удаляются.
  @override
  Future<void> saveAllocationKey(AllocationKey key) =>
      _db.transaction(() async {
        await _db.financeDao.saveRow(
          _db.finAllocationKeys,
          key.id,
          (now, editor, isNew) => FinAllocationKeysCompanion(
            uuid: Value(key.id),
            name: Value(key.name),
            deleted: const Value(false),
            updatedAt: Value(now),
            editedBy: Value(editor),
          ),
        );
        final existing = {
          for (final p in await _db.financeDao.allPeriods())
            if (p.keyUuid == key.id) p.validFrom: p,
        };
        final wanted = <String>{};
        for (final period in key.periods) {
          final from = formatDateIso(period.validFrom);
          wanted.add(from);
          final shares = encodeShares(period.shares);
          final old = existing[from];
          if (old != null && old.shares == shares) continue;
          final uuid = old?.uuid ?? newUuid();
          await _db.financeDao.saveRow(
            _db.finAllocationPeriods,
            uuid,
            (now, editor, isNew) => FinAllocationPeriodsCompanion(
              uuid: Value(uuid),
              keyUuid: Value(key.id),
              validFrom: Value(from),
              shares: Value(shares),
              deleted: const Value(false),
              updatedAt: Value(now),
              editedBy: Value(editor),
            ),
          );
        }
        for (final old in existing.values) {
          if (!wanted.contains(old.validFrom)) {
            await _db.financeDao.softDelete(_db.finAllocationPeriods, old.uuid);
          }
        }
      });

  @override
  Future<void> deleteAllocationKey(String id) => _db.transaction(() async {
    for (final p in await _db.financeDao.allPeriods()) {
      if (p.keyUuid == id) {
        await _db.financeDao.softDelete(_db.finAllocationPeriods, p.uuid);
      }
    }
    await _db.financeDao.softDelete(_db.finAllocationKeys, id);
  });

  // --- Кошельки -----------------------------------------------------------

  @override
  Future<List<FinAccount>> accounts() async => [
    for (final r in await _db.financeDao.allAccounts())
      FinAccount(
        id: r.uuid,
        name: r.name,
        kind: AccountKind.fromCode(r.kind),
        openingBalance: r.openingBalance,
        openingDate: parseDateIsoOrNull(r.openingDate),
        employeeId: r.employeeUuid,
        closed: r.closed,
        sortOrder: r.sortOrder,
      ),
  ];

  @override
  Future<void> saveAccount(FinAccount a) => _db.financeDao.saveRow(
    _db.finAccounts,
    a.id,
    (now, editor, isNew) => FinAccountsCompanion(
      uuid: Value(a.id),
      name: Value(a.name),
      kind: Value(a.kind.code),
      openingBalance: Value(a.openingBalance),
      openingDate: Value(formatDateIsoOrNull(a.openingDate)),
      employeeUuid: Value(a.employeeId),
      closed: Value(a.closed),
      sortOrder: Value(a.sortOrder),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteAccount(String id) =>
      _db.financeDao.softDelete(_db.finAccounts, id);

  // --- Имущество ----------------------------------------------------------

  @override
  Future<List<Asset>> assets() async => [
    for (final r in await _db.financeDao.allAssets())
      Asset(
        id: r.uuid,
        name: r.name,
        kind: AssetKind.fromCode(r.kind),
        year: r.year,
        quantity: r.quantity,
        referenceValue: r.referenceValue,
        valuedOn: parseDateIsoOrNull(r.valuedOn),
        directionId: r.directionUuid,
        allocationKeyId: r.allocationKeyUuid,
        cadastralNumber: r.cadastralNumber,
        areaHa: r.areaHa,
        cadastralValue: r.cadastralValue,
        disposedOn: parseDateIsoOrNull(r.disposedOn),
        disposalReason: r.disposalReason,
        notes: r.notes,
      ),
  ];

  @override
  Future<void> saveAsset(Asset a) => _db.financeDao.saveRow(
    _db.finAssets,
    a.id,
    (now, editor, isNew) => FinAssetsCompanion(
      uuid: Value(a.id),
      name: Value(a.name),
      kind: Value(a.kind.code),
      year: Value(a.year),
      quantity: Value(a.quantity),
      referenceValue: Value(a.referenceValue),
      valuedOn: Value(formatDateIsoOrNull(a.valuedOn)),
      directionUuid: Value(a.directionId),
      allocationKeyUuid: Value(a.allocationKeyId),
      cadastralNumber: Value(a.cadastralNumber),
      areaHa: Value(a.areaHa),
      cadastralValue: Value(a.cadastralValue),
      disposedOn: Value(formatDateIsoOrNull(a.disposedOn)),
      disposalReason: Value(a.disposalReason),
      notes: Value(a.notes),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteAsset(String id) =>
      _db.financeDao.softDelete(_db.finAssets, id);

  // --- Группы статей ------------------------------------------------------

  @override
  Future<List<FinCategoryGroup>> categoryGroups() async => [
    for (final r in await _db.financeDao.allCategoryGroups())
      FinCategoryGroup(
        id: r.uuid,
        type: CategoryType.fromCode(r.type),
        name: r.name,
        sortOrder: r.sortOrder,
        hidden: r.hidden,
      ),
  ];

  @override
  Future<void> saveCategoryGroup(FinCategoryGroup g) async {
    final dao = _db.financeDao;
    await _db.transaction(() async {
      final before = await dao.categoryGroupByUuid(g.id);
      await dao.saveRow(
        _db.finCategoryGroups,
        g.id,
        (now, editor, isNew) => FinCategoryGroupsCompanion(
          uuid: Value(g.id),
          type: Value(g.type.code),
          name: Value(g.name),
          sortOrder: Value(g.sortOrder),
          hidden: Value(g.hidden),
          deleted: const Value(false),
          updatedAt: Value(now),
          editedBy: Value(editor),
        ),
      );
      if (before == null || before.name == g.name) return;
      // Переименование: название-копия у статей группы (программы 1.18
      // видят группу только им); статьи 1.18 заодно получают ссылку.
      for (final c in await dao.categoriesOfGroup(
        g.id,
        before.type,
        before.name,
      )) {
        await dao.saveRow(
          _db.finCategories,
          c.uuid,
          (now, editor, isNew) => FinCategoriesCompanion(
            uuid: Value(c.uuid),
            groupUuid: Value(g.id),
            groupName: Value(g.name),
            updatedAt: Value(now),
            editedBy: Value(editor),
          ),
        );
      }
    });
  }

  @override
  Future<void> deleteCategoryGroup(String id) =>
      _db.financeDao.softDelete(_db.finCategoryGroups, id);

  // --- Статьи -------------------------------------------------------------

  @override
  Future<List<FinCategory>> categories() async => [
    for (final r in await _db.financeDao.allCategories())
      FinCategory(
        id: r.uuid,
        type: CategoryType.fromCode(r.type),
        groupId: r.groupUuid,
        group: r.groupName,
        name: r.name,
        directionId: r.directionUuid,
        allocationKeyId: r.allocationKeyUuid,
        kind: CategoryKind.fromCode(r.kind),
        inTaxBook: r.inTaxBook,
        hidden: r.hidden,
        sortOrder: r.sortOrder,
      ),
  ];

  @override
  Future<void> saveCategory(FinCategory c) => _db.financeDao.saveRow(
    _db.finCategories,
    c.id,
    (now, editor, isNew) => FinCategoriesCompanion(
      uuid: Value(c.id),
      type: Value(c.type.code),
      groupUuid: Value(c.groupId),
      groupName: Value(c.group),
      name: Value(c.name),
      directionUuid: Value(c.directionId),
      allocationKeyUuid: Value(c.allocationKeyId),
      kind: Value(c.kind.code),
      inTaxBook: Value(c.inTaxBook),
      hidden: Value(c.hidden),
      sortOrder: Value(c.sortOrder),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteCategory(String id) =>
      _db.financeDao.softDelete(_db.finCategories, id);

  // --- Контрагенты --------------------------------------------------------

  @override
  Future<List<Counterparty>> counterparties() async => [
    for (final r in await _db.financeDao.allCounterparties())
      Counterparty(
        id: r.uuid,
        name: r.name,
        kind: CounterpartyKind.fromCode(r.kind),
        inn: r.inn,
        phone: r.phone,
        employeeId: r.employeeUuid,
        notes: r.notes,
      ),
  ];

  @override
  Future<void> saveCounterparty(Counterparty c) => _db.financeDao.saveRow(
    _db.counterparties,
    c.id,
    (now, editor, isNew) => CounterpartiesCompanion(
      uuid: Value(c.id),
      name: Value(c.name),
      kind: Value(c.kind.code),
      inn: Value(c.inn),
      phone: Value(c.phone),
      employeeUuid: Value(c.employeeId),
      notes: Value(c.notes),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteCounterparty(String id) =>
      _db.financeDao.softDelete(_db.counterparties, id);

  // --- Долги --------------------------------------------------------------

  @override
  Future<List<FinDebt>> debts() async => [
    for (final r in await _db.financeDao.allDebts())
      FinDebt(
        id: r.uuid,
        counterpartyId: r.counterpartyUuid,
        kind: DebtKind.fromCode(r.kind),
        openingBalance: r.openingBalance,
        openingDate: parseDateIsoOrNull(r.openingDate),
        closed: r.closed,
        notes: r.notes,
      ),
  ];

  @override
  Future<void> saveDebt(FinDebt d) => _db.financeDao.saveRow(
    _db.finDebts,
    d.id,
    (now, editor, isNew) => FinDebtsCompanion(
      uuid: Value(d.id),
      counterpartyUuid: Value(d.counterpartyId),
      kind: Value(d.kind.code),
      openingBalance: Value(d.openingBalance),
      openingDate: Value(formatDateIsoOrNull(d.openingDate)),
      closed: Value(d.closed),
      notes: Value(d.notes),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  @override
  Future<void> deleteDebt(String id) =>
      _db.financeDao.softDelete(_db.finDebts, id);

  // --- Операции -----------------------------------------------------------

  static FinOperation _operation(FinOperationRow r) => FinOperation(
    id: r.uuid,
    date: parseDateIso(r.date),
    type: OperationType.fromCode(r.type),
    amount: r.amount,
    accountId: r.accountUuid,
    toAccountId: r.toAccountUuid,
    categoryId: r.categoryUuid,
    directionId: r.directionUuid,
    allocationKeyId: r.allocationKeyUuid,
    assetId: r.assetUuid,
    season: r.season,
    counterpartyId: r.counterpartyUuid,
    employeeId: r.employeeUuid,
    debtId: r.debtUuid,
    debtMove: r.debtMove == null ? null : DebtMove.fromCode(r.debtMove!),
    description: r.description,
    quantity: r.quantity,
    unit: r.unit,
    tag: r.tag,
    notes: r.notes,
    source: OperationSource.fromCode(r.source),
    sourceRef: r.sourceRef,
    createdBy: r.createdBy,
  );

  Future<void> _saveOperation(FinOperation o) => _db.financeDao.saveRow(
    _db.finOperations,
    o.id,
    (now, editor, isNew) => FinOperationsCompanion(
      uuid: Value(o.id),
      date: Value(formatDateIso(o.date)),
      type: Value(o.type.code),
      amount: Value(o.amount),
      accountUuid: Value(o.accountId),
      toAccountUuid: Value(o.toAccountId),
      categoryUuid: Value(o.categoryId),
      directionUuid: Value(o.directionId),
      allocationKeyUuid: Value(o.allocationKeyId),
      assetUuid: Value(o.assetId),
      season: Value(o.season),
      counterpartyUuid: Value(o.counterpartyId),
      employeeUuid: Value(o.employeeId),
      debtUuid: Value(o.debtId),
      debtMove: Value(o.debtMove?.code),
      description: Value(o.description),
      quantity: Value(o.quantity),
      unit: Value(o.unit),
      tag: Value(o.tag),
      notes: Value(o.notes),
      source: Value(o.source.code),
      sourceRef: Value(o.sourceRef),
      // Автор и время создания — только при добавлении.
      createdBy: isNew ? Value(o.createdBy) : const Value.absent(),
      createdAt: isNew ? Value(_db.nowLocalIso()) : const Value.absent(),
      deleted: const Value(false),
      updatedAt: Value(now),
      editedBy: Value(editor),
    ),
  );

  /// Новая операция; запись с таким id уже есть (даже удалённая) —
  /// [StateError].
  @override
  Future<void> addOperation(FinOperation o) => _db.transaction(() async {
    if (await _db.financeDao.exists(_db.finOperations, o.id)) {
      throw StateError('Операция ${o.id} уже есть');
    }
    await _saveOperation(o);
  });

  /// Изменить существующую операцию; нет такой — [StateError].
  @override
  Future<void> updateOperation(FinOperation o) => _db.transaction(() async {
    if (await _db.financeDao.operationByUuid(o.id) == null) {
      throw StateError('Нет операции ${o.id}');
    }
    await _saveOperation(o);
  });

  @override
  Future<void> deleteOperation(String id) =>
      _db.financeDao.softDelete(_db.finOperations, id);

  @override
  Future<FinOperation?> operation(String id) async {
    final row = await _db.financeDao.operationByUuid(id);
    return row == null ? null : _operation(row);
  }

  @override
  Future<List<FinOperation>> operations({
    DateTime? from,
    DateTime? to,
    String? accountId,
    int? season,
  }) async => [
    for (final r in await _db.financeDao.operationsList(
      from: from,
      to: to,
      accountUuid: accountId,
      season: season,
    ))
      _operation(r),
  ];

  // --- Соответствия выплат ЗП ---------------------------------------------

  static const _method = 'method';
  static const _position = 'position';
  static const _defaultAccount = 'default_account';
  static const _defaultCategory = 'default_category';

  @override
  Future<PayrollFinanceMapping?> payrollMapping() async {
    final rows = await _db.financeDao.allPayrollMapping();
    String? one(String kind) {
      for (final r in rows) {
        if (r.kind == kind) return r.targetUuid;
      }
      return null;
    }

    final account = one(_defaultAccount), category = one(_defaultCategory);
    if (account == null || category == null) return null;
    return PayrollFinanceMapping(
      methodAccounts: {
        for (final r in rows)
          if (r.kind == _method) r.value: r.targetUuid,
      },
      defaultAccountId: account,
      positionCategories: {
        for (final r in rows)
          if (r.kind == _position) r.value: r.targetUuid,
      },
      defaultCategoryId: category,
    );
  }

  /// Строка на соответствие; неизменные не трогаются, лишние удаляются.
  @override
  Future<void> savePayrollMapping(
    PayrollFinanceMapping m,
  ) => _db.transaction(() async {
    final wanted = <(String, String), String>{
      for (final e in m.methodAccounts.entries) (_method, e.key): e.value,
      for (final e in m.positionCategories.entries) (_position, e.key): e.value,
      (_defaultAccount, ''): m.defaultAccountId,
      (_defaultCategory, ''): m.defaultCategoryId,
    };
    final existing = {
      for (final r in await _db.financeDao.allPayrollMapping())
        (r.kind, r.value): r,
    };
    for (final MapEntry(key: (kind, value), value: target) in wanted.entries) {
      final old = existing[(kind, value)];
      if (old != null && old.targetUuid == target) continue;
      final uuid = old?.uuid ?? newUuid();
      await _db.financeDao.saveRow(
        _db.finPayrollMapping,
        uuid,
        (now, editor, isNew) => FinPayrollMappingCompanion(
          uuid: Value(uuid),
          kind: Value(kind),
          value: Value(value),
          targetUuid: Value(target),
          deleted: const Value(false),
          updatedAt: Value(now),
          editedBy: Value(editor),
        ),
      );
    }
    for (final MapEntry(key: k, value: old) in existing.entries) {
      if (!wanted.containsKey(k)) {
        await _db.financeDao.softDelete(_db.finPayrollMapping, old.uuid);
      }
    }
  });
}
