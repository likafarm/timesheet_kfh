import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/users_screen.dart';
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// «Настройки → Пользователи» (11.2, только админ).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;
  late LocalDatabase db;
  late SyncProvider sync;

  Future<void> setUpSync(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = SyncTestServer();
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      sync = SyncProvider(
        database: db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(server.handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: ClientKind.desktop,
        appVersion: () async => '1.22.0',
      );
      await sync.init();
      await sync.signIn('localhost', 'ivan', 'secret-pass');
      await sync.link(await sync.analyzeLink());
    });
    addTearDown(() async {
      sync.dispose();
      await tester.runAsync(db.close);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('новый специалист по продажам, новый пароль, отключение', (
    tester,
  ) async {
    await setUpSync(tester);
    expect(sync.canManageUsers, isTrue);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: sync,
        child: const MaterialApp(home: UsersScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Иван Иванов (это вы)'), findsOneWidget);

    // Новый пользователь: роль по умолчанию — специалист по продажам.
    await tester.tap(find.text('Новый пользователь'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Логин'), 'sales1');
    await tester.enterText(
      find.widgetWithText(TextField, 'ФИО'),
      'Петрова Анна',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Временный пароль'),
      'temp-pass-1',
    );
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    final created = server.users.last;
    expect(created['login'], 'sales1');
    expect(created['role'], 'sales');
    expect(server.passwords['sales1'], 'temp-pass-1');
    expect(find.textContaining('специалист по продажам'), findsWidgets);
    expect(find.textContaining('ждёт смены пароля'), findsOneWidget);

    // Отключить.
    await tester.tap(find.byTooltip('Действия').last);
    await settle(tester);
    await tester.tap(find.text('Отключить'));
    await settle(tester);
    expect(created['is_active'], isFalse);
    expect(find.textContaining('отключён'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('не админ — пункт недоступен', (tester) async {
    await setUpSync(tester);
    await tester.runAsync(sync.signOut);
    server.role = 'accountant';
    await tester.runAsync(
      () => sync.signIn('localhost', 'ivan', 'secret-pass'),
    );
    expect(sync.canManageUsers, isFalse);
  });
}
