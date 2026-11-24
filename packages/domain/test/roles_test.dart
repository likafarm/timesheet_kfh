import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Роли и права на таблицы (11.2: специалист по продажам).
void main() {
  test('продавец получает прайс и реквизиты, ничего не пишет', () {
    expect(roleReadableTables(roleSales), {
      'company_settings',
      ...priceListTables,
    });
    expect(roleWritableTables(roleSales), isEmpty);
    expect(isFullRole(roleSales), isFalse);
    expect(roleTitle(roleSales), 'специалист по продажам');
  });

  test('оператор видит прайс, но не пишет его', () {
    expect(roleReadableTables(roleOperator), containsAll(priceListTables));
    expect(
      roleWritableTables(roleOperator).intersection(priceListTables),
      isEmpty,
    );
  });

  test('смена роли на устройстве: что принять заново', () {
    // После оператора бухгалтеру — всё, чего не было, и неполные таблицы.
    final afterOperator = tablesToRefetch(
      from: roleOperator,
      to: roleAccountant,
    );
    expect(afterOperator, containsAll(['employee_rates', 'payments']));
    expect(afterOperator, containsAll(['employees', 'fin_operations']));
    expect(afterOperator, isNot(contains('timesheet')));
    // После продавца бухгалтеру — всё, кроме прайса и реквизитов.
    final afterSales = tablesToRefetch(from: roleSales, to: roleAdmin);
    expect(afterSales, contains('timesheet'));
    expect(afterSales.intersection(priceListTables), isEmpty);
    // После бухгалтера продавцу и оператору ничего не нужно.
    expect(tablesToRefetch(from: roleAccountant, to: roleSales), isEmpty);
    expect(tablesToRefetch(from: roleAdmin, to: roleOperator), isEmpty);
    // После оператора продавцу — только реквизиты.
    expect(tablesToRefetch(from: roleOperator, to: roleSales), {
      'company_settings',
    });
  });
}
