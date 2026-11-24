import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

SessionUser _user(String role) =>
    SessionUser(uuid: 'u', login: role, fullName: role, role: role);

/// Какие роли где работают (11.2: специалист по продажам — везде).
void main() {
  test('продавец входит на телефоне, в Windows и в вебе', () {
    final sales = _user('sales');
    expect(sales.isSales, isTrue);
    expect(sales.isFull, isFalse);
    for (final client in ClientKind.values) {
      expect(sales.canUseOn(client), isTrue, reason: '$client');
    }
    expect(sales.roleTitle, 'специалист по продажам');
  });

  test('оператор — только на телефоне', () {
    final operator = _user('operator');
    expect(operator.canUseOn(ClientKind.phone), isTrue);
    expect(operator.canUseOn(ClientKind.desktop), isFalse);
    expect(operator.refusalOn(ClientKind.web), contains('Оператор'));
  });

  test('неизвестная роль (программа старше сервера) — нигде', () {
    final future = _user('stockman');
    for (final client in ClientKind.values) {
      expect(future.canUseOn(client), isFalse);
      expect(future.refusalOn(client), contains('обновите программу'));
    }
  });
}
