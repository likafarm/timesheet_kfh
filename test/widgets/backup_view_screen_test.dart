import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfx_time_tracking/screens/backup_view_screen.dart';

/// Просмотр копии человеческим языком (3.6).
void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  // Разделитель разрядов в ru — неразрывный пробел.
  String rub(num v) => '${NumberFormat('#,##0.00', 'ru').format(v)} ₽';

  const ivan = '01900000-0000-7000-8000-00000000e001';
  const petr = '01900000-0000-7000-8000-00000000e002';
  var n = 0;
  String id() => '01900000-0000-7000-8000-${(++n).toString().padLeft(12, '0')}';
  final at = DateTime.utc(2026, 9, 29, 10);

  SyncChange row(String table, Map<String, Object?> data, {String? uuid}) =>
      SyncChange(
        table: table,
        uuid: uuid ?? id(),
        updatedAt: at,
        deleted: false,
        data: {'legacy_id': null, ...data},
      );

  SyncChange employee(String uuid, String name, {String? dismissed}) =>
      row('employees', {
        'full_name': name,
        'position': 'Рабочий',
        'hire_date': '2025-03-01',
        'dismissal_date': dismissed,
        'base_rate': 1000.0,
        'field_rate': 1500.0,
      }, uuid: uuid);

  SyncChange day(
    String emp,
    String date, {
    String type = 'work',
    double days = 1,
    String? place,
  }) => row('timesheet', {
    'employee_uuid': emp,
    'date': date,
    'day_type': type,
    'days': days,
    'work_place': place,
    'notes': null,
    'created_at': '2026-09-01T10:00:00.000',
  });

  SyncChange payment(String emp, String date, double amount) =>
      row('payments', {
        'employee_uuid': emp,
        'payment_date': date,
        'amount': amount,
        'payment_type': 'advance',
        'period_start': null,
        'period_end': null,
        'payment_method': 'cash',
        'document_number': null,
        'notes': 'под расписку',
        'created_at': '2026-09-01T10:00:00.000',
      });

  final snapshot = DataSnapshot([
    row('company_settings', {
      'company_name': 'КФХ «Тестовое»',
      'director_name': 'Тестов Т. Т.',
      'inn': '123456789012',
      'ogrn': null,
      'bank_account': null,
      'bank_name': null,
      'legal_address': null,
      'phone': null,
      'default_work_day_hours': 8.0,
      'overtime_multiplier': 1.5,
      'night_shift_multiplier': 1.2,
    }),
    employee(ivan, 'Иванов Иван'),
    employee(petr, 'Петров Пётр', dismissed: '2026-09-20'),
    row('employee_rates', {
      'employee_uuid': ivan,
      'base_rate': 1000.0,
      'field_rate': 1500.0,
      'start_date': '2025-03-01',
      'end_date': null,
    }),
    day(ivan, '2026-09-01', place: 'base'),
    day(ivan, '2026-09-02', place: 'field', days: 0.5),
    day(petr, '2026-09-03', type: 'sick'),
    day(ivan, '2026-08-10', place: 'field'),
    payment(ivan, '2026-09-10', 5000),
    payment(petr, '2026-09-15', 2500),
    row('payroll_results', {
      'employee_uuid': ivan,
      'year': 2026,
      'month': 9,
      'base_days': 1.0,
      'field_days': 0.5,
      'sick_days': 0.0,
      'vacation_days': 0.0,
      'total_salary': 1750.0,
      'base_rate_used': 1000.0,
      'field_rate_used': 1500.0,
      'calculated_at': '2026-09-29T10:00:00.000',
      'status': 'calculated',
      'skipped_work_days': 0,
    }),
  ]);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BackupViewScreen(
          title: 'Ежедневная · 29.09.2026',
          takenAt: DateTime(2026, 9, 29, 13),
          source: BackupSource.local,
          snapshot: snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Tab, name));
    await tester.pumpAndSettle();
  }

  testWidgets('обзор и сотрудники', (tester) async {
    await pump(tester);
    expect(
      find.text('Копия этого компьютера на 29.09.2026 13:00'),
      findsOneWidget,
    );
    await tab(tester, 'Сотрудники');
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('20.09.2026'), findsOneWidget);
    expect(find.text(rub(1500)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('табель сеткой: последний месяц, переход к прошлому', (
    tester,
  ) async {
    await pump(tester);
    await tab(tester, 'Табель');
    expect(find.text('Сентябрь 2026'), findsOneWidget);
    expect(find.text('Б'), findsOneWidget);
    expect(find.text('½П'), findsOneWidget);
    expect(find.text('Бл'), findsOneWidget);
    await tester.tap(find.byTooltip('Предыдущий месяц'));
    await tester.pumpAndSettle();
    expect(find.text('Август 2026'), findsOneWidget);
    expect(find.text('П'), findsOneWidget);
    expect(find.text('Бл'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('выплаты, ставки, расчёты, реквизиты', (tester) async {
    await pump(tester);
    await tab(tester, 'Выплаты');
    expect(find.text('Всего выплачено: ${rub(7500)}'), findsOneWidget);
    expect(find.text('Аванс'), findsNWidgets(2));
    expect(find.text('Наличные'), findsNWidgets(2));

    await tab(tester, 'Ставки');
    expect(find.text('бессрочно'), findsOneWidget);

    await tab(tester, 'Расчёты');
    expect(find.text('Всего начислено: ${rub(1750)}'), findsOneWidget);

    await tab(tester, 'Реквизиты');
    expect(find.text('КФХ «Тестовое»'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
