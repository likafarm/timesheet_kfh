// packages/domain/lib/src/sync/roles.dart
//
// Роли пользователей сервера и их права на таблицы синхронизации — одно
// правило для сервера (приём и выдача) и программы (что догружать при
// смене роли на устройстве, что показывать).
//
// - админ — всё;
// - бухгалтер — все данные (пользователи и открытие закрытых месяцев —
//   только админ, это проверяет сервер отдельно);
// - оператор — табель и просмотр сотрудников (без ставок), свои расходы и
//   доходы и справочники для них (8.8.4), просмотр прайс-листа (11.1);
// - специалист по продажам (этап 11.2, решение владельца 2026-11-24) —
//   прайс-лист и реквизиты хозяйства (для печати) только на чтение,
//   покупатели, заказы и выдачи (11.3–11.5) — чтение и запись; в финансах
//   (11.6) — справочники для оплаты и оплаты заказов, пишет свои оплаты
//   по заказам и новых контрагентов. Оператор покупателей (телефоны,
//   адреса) не получает.

import '../finance/operator_rules.dart';
import '../sales/payments.dart';
import '../sales/price_list.dart' show priceListTables;
import 'sync_tables.dart';

/// Коды ролей, как их хранит и отдаёт сервер.
const roleAdmin = 'admin';
const roleAccountant = 'accountant';
const roleOperator = 'operator';
const roleSales = 'sales';

const allRoles = [roleAdmin, roleAccountant, roleOperator, roleSales];

/// Роль видит и правит все данные (админ или бухгалтер).
bool isFullRole(String role) => role == roleAdmin || role == roleAccountant;

/// Название роли для человека.
String roleTitle(String role) => switch (role) {
  roleAdmin => 'администратор',
  roleAccountant => 'бухгалтер',
  roleOperator => 'оператор',
  roleSales => 'специалист по продажам',
  _ => role,
};

final _allTables = {for (final t in syncTables) t.name};

/// Таблицы, которые роль получает с сервера.
Set<String> roleReadableTables(String role) => switch (role) {
  roleAdmin || roleAccountant => _allTables,
  roleOperator => {
    'employees',
    'timesheet',
    ...operatorFinanceReadable,
    ...priceListTables,
  },
  roleSales => {
    'company_settings',
    ...priceListTables,
    ...salesRoleTables,
    ...salesFinanceReadable,
  },
  _ => const {},
};

/// Таблицы продаж, которые ведёт специалист по продажам (11.3–11.5).
const salesRoleTables = {
  'customers',
  'sale_batches',
  'sale_orders',
  'sale_order_lines',
};

/// Таблицы, которые роль может записать.
Set<String> roleWritableTables(String role) => switch (role) {
  roleAdmin || roleAccountant => _allTables,
  roleOperator => {'timesheet', ...operatorFinanceWritable},
  roleSales => {...salesRoleTables, ...salesFinanceWritable},
  _ => const {},
};

/// Поля, которых роль не видит: при выдаче заменяются нулём (пустые —
/// пустотой). Оператору ставки сотрудников, остатки кошельков и стоимость
/// имущества не нужны.
Set<String> roleHiddenColumns(String role, String table) => switch (role) {
  roleOperator =>
    table == 'employees'
        ? const {'base_rate', 'field_rate'}
        : operatorFinanceHidden[table] ?? const {},
  roleSales => salesFinanceHidden[table] ?? const {},
  _ => const {},
};

/// Таблицы, которые роль получает не целиком: со скрытыми полями
/// ([roleHiddenColumns]) или только часть записей (оператору — только его
/// операции финансов). Роль, которой они нужны полностью, после такой роли
/// на том же устройстве принимает их заново ([tablesToRefetch]).
Set<String> roleLimitedTables(String role) => switch (role) {
  roleOperator => {
    'employees',
    ...operatorFinanceHidden.keys,
    'fin_operations',
  },
  roleSales => {...salesFinanceHidden.keys, 'fin_operations'},
  _ => const {},
};

/// Что принять с сервера заново, когда на устройстве после роли [from]
/// работает роль [to]: таблицы, которых [from] не получала, и те, что она
/// получала не целиком.
Set<String> tablesToRefetch({required String from, required String to}) {
  final wanted = isFullRole(to)
      ? {for (final t in syncTables) t.name}
      : roleReadableTables(to);
  final had = isFullRole(from)
      ? {for (final t in syncTables) t.name}
      : roleReadableTables(from);
  return {
    ...wanted.difference(had),
    ...wanted.intersection(roleLimitedTables(from)),
  };
}
