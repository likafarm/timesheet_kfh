import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/main_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// Каркас (шаг 4.3): телефон — нижняя навигация, широкий экран — боковая
/// панель; оператору — только табель, сотрудники и сервер.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() => initializeDateFormatting('ru'));
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'kfh',
      packageName: 'kfh',
      version: '1.3.0',
      buildNumber: '5',
      buildSignature: '',
    ),
  );

  Future<void> pumpMain(
    WidgetTester tester, {
    required Size size,
    required bool operator,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late LocalDatabase db;
    late AppProvider app;
    late SyncProvider sync;
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: operator);
      await app.loadAllData();
      sync = SyncProvider(
        appVersion: () async => '1.3.0',
        database: db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(SyncTestServer().handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: operator ? ClientKind.phone : ClientKind.desktop,
      );
      await sync.init();
    });
    addTearDown(() async {
      sync.dispose();
      app.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  testWidgets('оператор на телефоне: нижняя навигация, четыре раздела', (
    tester,
  ) async {
    await pumpMain(tester, size: const Size(390, 844), operator: true);
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), [
      'День',
      'Табель',
      'Сотрудники',
      'Сервер',
    ]);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Выплаты'), findsNothing);
    final ex = tester.takeException();
    if (ex is FlutterError) debugPrint(ex.toStringDeep());
    expect(ex, isNull);
  });

  testWidgets('Windows 1024×768: боковая панель, все разделы', (tester) async {
    await pumpMain(tester, size: const Size(1024, 768), operator: false);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(6));
    // Первый раздел — сводка (6.8).
    expect(rail.selectedIndex, 0);
    expect(find.text('Долг по зарплате на сегодня'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await tester.tap(find.text('Сотрудники'));
    await tester.pump();
    expect(rail.destinations, hasLength(6));
    expect(tester.takeException(), isNull);
  });
}
