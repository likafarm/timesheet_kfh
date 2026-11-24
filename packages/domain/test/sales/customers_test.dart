import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  test('телефон: цифры и вид', () {
    expect(phoneDigits('8 (910) 915-60-68'), '79109156068');
    expect(phoneDigits('+7 910 9156068'), '79109156068');
    expect(phoneDigits('9109156068'), '79109156068');
    expect(phoneDigits(null), '');
    expect(formatPhone('79109156068'), '+7 910 915-60-68');
    expect(formatPhone('12-34'), '12-34');
  });

  test('проверка: имя обязательно, телефон — хотя бы 5 цифр', () {
    const ok = Customer(id: '1', name: 'Ольга', phone: '+79166831854');
    expect(customerProblem(ok), isNull);
    expect(customerProblem(ok.copyWith(name: ' ')), isNotNull);
    expect(customerProblem(ok.copyWith(phone: () => '12')), isNotNull);
    expect(customerProblem(ok.copyWith(phone: () => null)), isNull);
    expect(salesRowProblem('customers', {'name': ''}), isNotNull);
  });

  test('поиск по имени, нику, адресу и цифрам телефона', () {
    const list = [
      Customer(
        id: '1',
        name: 'Ольга РЧТ',
        contact: 'Баба Яга',
        address: 'Юхнов',
      ),
      Customer(id: '2', name: 'Лариса Певнева', phone: '8 905 537-14-59'),
      Customer(id: '3', name: 'Алик'),
    ];
    expect(searchCustomers(list, '').map((c) => c.id), ['3', '2', '1']);
    expect(searchCustomers(list, 'яга').single.id, '1');
    expect(searchCustomers(list, 'юхн').single.id, '1');
    expect(searchCustomers(list, '1459').single.id, '2');
    expect(
      searchCustomers(list, '14').isEmpty,
      isTrue,
      reason: '2 цифры — мало',
    );
    expect(customerWithPhone(list, '+7 (905) 537 14 59')!.id, '2');
    expect(customerWithPhone(list, '89055371459', exceptId: '2'), isNull);
  });
}
