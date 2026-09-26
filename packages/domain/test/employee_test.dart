import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  final dismissed = Employee(
    id: 'e1',
    fullName: 'Иванов Иван',
    position: 'Рабочий',
    hireDate: DateTime(2025, 1, 1),
    dismissalDate: DateTime(2026, 9, 1),
    baseRate: 1000,
    fieldRate: 1500,
  );

  test('copyWith без clearDismissalDate не снимает увольнение', () {
    expect(
      dismissed.copyWith(position: 'Тракторист').dismissalDate,
      DateTime(2026, 9, 1),
    );
  });

  test('clearDismissalDate снимает увольнение', () {
    final reinstated = dismissed.copyWith(clearDismissalDate: true);
    expect(reinstated.dismissalDate, isNull);
    expect(reinstated.isActive, isTrue);
    expect(reinstated.id, 'e1');
  });
}
