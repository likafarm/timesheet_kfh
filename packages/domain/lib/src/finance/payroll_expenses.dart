// packages/domain/lib/src/finance/payroll_expenses.dart
//
// Выплаты ЗП из табеля — расход финансов без копий (решение владельца
// 2026-10-07): операции строятся на лету из `payments`, кошелёк — по
// способу выплаты, статья — по должности сотрудника.

import '../models/employee.dart';
import '../models/payment.dart';
import '../utils/date_utils.dart';
import 'models.dart';
import 'money.dart';

/// Соответствия для [payrollExpenses]. Должности сравниваются без регистра
/// и пробелов по краям.
class PayrollFinanceMapping {
  /// Способ выплаты (`cash`, `card`, `transfer`) → id кошелька.
  final Map<String, String> methodAccounts;

  /// Кошелёк, если способ не указан или не сопоставлен.
  final String defaultAccountId;

  /// Должность → id статьи расхода.
  final Map<String, String> positionCategories;

  /// Статья, если должность не сопоставлена.
  final String defaultCategoryId;

  PayrollFinanceMapping({
    required this.methodAccounts,
    required this.defaultAccountId,
    required Map<String, String> positionCategories,
    required this.defaultCategoryId,
  }) : positionCategories = {
         for (final e in positionCategories.entries) _norm(e.key): e.value,
       };

  static String _norm(String position) => position.trim().toLowerCase();

  String accountFor(String? method) =>
      methodAccounts[method] ?? defaultAccountId;

  String categoryFor(String? position) =>
      positionCategories[_norm(position ?? '')] ?? defaultCategoryId;
}

/// Префикс id операций, построенных из выплат: `payroll:<id выплаты>`.
const payrollOperationPrefix = 'payroll:';

/// Выплаты → операции-расходы (источник [OperationSource.payroll]).
/// Направление не задаётся — берётся из статьи. Выплаты без id и с
/// суммой не больше нуля пропускаются.
List<FinOperation> payrollExpenses(
  Iterable<Payment> payments,
  Map<String, Employee> employees,
  PayrollFinanceMapping mapping,
) => [
  for (final p in payments)
    if (p.id != null && toKopecks(p.amount) > 0)
      FinOperation(
        id: '$payrollOperationPrefix${p.id}',
        date: calendarDay(p.paymentDate),
        type: OperationType.expense,
        amount: toKopecks(p.amount),
        accountId: mapping.accountFor(p.paymentMethod),
        categoryId: mapping.categoryFor(employees[p.employeeId]?.position),
        employeeId: p.employeeId,
        description: [
          p.paymentTypeName,
          ?employees[p.employeeId]?.fullName,
        ].join(': '),
        source: OperationSource.payroll,
        sourceRef: p.id,
      ),
];
