import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/customers_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:provider/provider.dart';

/// «Продажи → Покупатели» (11.3): поиск, новый покупатель, подсказка о
/// повторе телефона, правка.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('поиск, новый покупатель, повтор телефона', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false)
        ..salesMode = true;
      await DriftRepositories(db).customers.saveCustomer(
        const Customer(
          id: 'c1',
          name: 'Ольга РЧТ',
          phone: '89166831854',
          channel: CustomerChannel.telegram,
          contact: 'Баба Яга',
          address: 'Юхнов',
        ),
      );
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: CustomersScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Покупатели (1)'), findsOneWidget);
    expect(find.textContaining('+7 916 683-18-54'), findsOneWidget);
    expect(find.textContaining('ТГ Баба Яга'), findsOneWidget);

    // Поиск по цифрам телефона и по нику.
    await tester.enterText(find.byType(TextField).first, '1854');
    await settle(tester);
    expect(find.text('Ольга РЧТ'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'нет такого');
    await settle(tester);
    expect(find.text('Никого не нашлось'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester);

    // Новый покупатель с тем же телефоном — подсказка, но сохранить можно.
    await tester.tap(find.text('Покупатель'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Имя'), 'Ольга');
    await tester.enterText(
      find.widgetWithText(TextField, 'Телефон'),
      '+7 (916) 683-18-54',
    );
    await tester.pump();
    expect(find.textContaining('уже у покупателя «Ольга РЧТ»'), findsOneWidget);
    await tester.tap(find.text('WhatsApp'));
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    expect(find.text('Покупатели (2)'), findsOneWidget);
    final saved = await tester.runAsync(
      () => DriftRepositories(db).customers.customers(),
    );
    final olga = saved!.firstWhere((c) => c.name == 'Ольга');
    expect(olga.channel, CustomerChannel.whatsapp);

    // Без имени — не сохраняется.
    await tester.tap(find.text('Покупатель'));
    await settle(tester);
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    expect(find.text('Не сохранено: Укажите имя покупателя'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
