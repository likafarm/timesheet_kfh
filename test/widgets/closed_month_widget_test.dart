import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/closed_month.dart';
import 'package:provider/provider.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;

  Future<void> setUpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'));
      await LocalSyncStore(db).saveLockedMonths([(2026, 8)]);
      await app.loadLockedMonths();
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  Widget page(Widget child) => ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('отметка «закрыт» — только у закрытого месяца', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      page(
        const Column(
          children: [
            ClosedMonthBadge(year: 2026, month: 8),
            ClosedMonthBadge(year: 2026, month: 9),
          ],
        ),
      ),
    );
    expect(find.text('закрыт'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('попытка правки в закрытом месяце — объяснение', (tester) async {
    await setUpApp(tester);
    bool? result;
    await tester.pumpWidget(
      page(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () async =>
                    result = await ensureMonthOpen(context, 2026, 8),
                child: const Text('август'),
              ),
              TextButton(
                onPressed: () async =>
                    result = await ensureMonthOpen(context, 2026, 9),
                child: const Text('сентябрь'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('сентябрь'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('август'));
    await tester.pumpAndSettle();
    expect(find.text('Месяц 08.2026 закрыт'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
