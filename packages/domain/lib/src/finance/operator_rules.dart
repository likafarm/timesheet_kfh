// packages/domain/lib/src/finance/operator_rules.dart
//
// Оператор в финансах (вторая очередь этапа 8, решение владельца
// 2026-10-07/08): вносит расходы и доходы, видит и правит только свои
// записи; остатков, отчётов, займов и чужих записей не видит. Те же
// правила проверяют сервер (приём и выдача) и программа.

/// Таблицы финансов, которые получает оператор: справочники для ввода и
/// свои операции. Займов, соответствий ЗП и долей ключей нет.
const operatorFinanceReadable = {
  'fin_directions',
  'fin_allocation_keys',
  'fin_accounts',
  'fin_assets',
  'fin_category_groups',
  'fin_categories',
  'counterparties',
  'fin_operations',
};

/// Таблицы финансов, которые оператор пишет: свои операции и новые
/// контрагенты (заводятся прямо из поля при вводе).
const operatorFinanceWritable = {'fin_operations', 'counterparties'};

/// Поля справочников, которых оператор не видит: начальные остатки
/// кошельков и стоимость имущества.
const operatorFinanceHidden = {
  'fin_accounts': {'opening_balance'},
  'fin_assets': {'reference_value', 'cadastral_value'},
};

/// Операция оператора ему видна: её ввёл он.
bool operatorSeesOperation(String? createdBy, String userUuid) =>
    createdBy == userUuid;

/// Почему оператор [userUuid] не может записать операцию; null — может.
/// [existingCreatedBy] — автор уже записанной операции ([exists] — она
/// есть); [type] и [createdBy] — новой версии (у удаления — прежние).
String? operatorOperationProblem({
  required String userUuid,
  required bool exists,
  String? existingCreatedBy,
  required String type,
  String? createdBy,
}) {
  if (exists && existingCreatedBy != userUuid) {
    return 'Оператор правит только свои операции';
  }
  if (createdBy != userUuid) {
    return 'Операция оператора записывается от его имени';
  }
  if (type != 'income' && type != 'expense') {
    return 'Оператор вносит только расходы и доходы — переводы и займы '
        'ведут бухгалтер и администратор';
  }
  return null;
}
