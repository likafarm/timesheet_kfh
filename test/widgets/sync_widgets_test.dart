import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/sync_screen.dart';
import 'package:kfx_time_tracking/widgets/sync_status_bar.dart';
import 'package:provider/provider.dart';

import '../support/sync_test_server.dart';

/// Интерфейс синхронизации в окне минимального размера (1024×768):
/// строка состояния, вход, первый вход, экран сервера.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;
  late LocalDatabase db;
  late SyncProvider sync;
  late MemorySyncJournal journal;
  late int backups;

  Future<void> setUpSync(
    WidgetTester tester, {
    bool debugBuild = false,
    Size size = const Size(1024, 768),
    ClientKind client = ClientKind.desktop,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = SyncTestServer();
    journal = MemorySyncJournal();
    backups = 0;
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      sync = SyncProvider(
        database: db,
        dataDirectory: '.',
        onDataChanged: () async {},
        backup: () async => backups++,
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(server.handle),
        journal: journal,
        autoSync: false,
        debugBuild: debugBuild,
        client: client,
      );
      await sync.init();
    });
    addTearDown(() async {
      sync.dispose();
      await tester.runAsync(db.close);
    });
  }

  Widget app(Widget home) => ChangeNotifierProvider.value(
    value: sync,
    child: MaterialApp(home: home),
  );

  Widget withBar() => app(
    const Scaffold(
      body: Center(child: Text('Табель')),
      bottomNavigationBar: SyncStatusBar(),
    ),
  );

  /// Дождаться сети и базы (они вне поддельного времени теста).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('без входа: строка состояния и кнопка «Войти»', (tester) async {
    await setUpSync(tester);
    await tester.pumpWidget(withBar());
    expect(find.textContaining('Вход на сервер не выполнен'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('неверный пароль — сообщение в окне входа', (tester) async {
    await setUpSync(tester);
    await tester.pumpWidget(withBar());
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Вход на сервер'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Логин'), 'ivan');
    await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await settle(tester);
    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    expect(sync.phase, SyncPhase.signedOut);
  });

  testWidgets('вход → первый вход → «синхронизировано»', (tester) async {
    await setUpSync(tester);
    await tester.pumpWidget(withBar());
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Логин'), 'ivan');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      'secret-pass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await settle(tester);

    // Окно первого входа: план и кнопка по виду.
    expect(find.text('Первый вход на сервер'), findsOneWidget);
    expect(find.textContaining('Данных нет ни на сервере'), findsOneWidget);
    expect(find.textContaining('резервная копия'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Начать'));
    await settle(tester);
    expect(find.text('Готово: база связана с сервером.'), findsOneWidget);
    expect(backups, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Готово'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Синхронизировано сегодня'), findsOneWidget);
    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('телефон: вход оператора и приём — панелями снизу', (
    tester,
  ) async {
    await setUpSync(
      tester,
      size: const Size(390, 844),
      client: ClientKind.phone,
    );
    server.role = 'operator';
    await tester.pumpWidget(withBar());
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Вход на сервер'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Логин'), 'oper');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      'secret-pass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await settle(tester);

    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Первый вход на сервер'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Принять данные с сервера'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Готово'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Синхронизировано сегодня'), findsOneWidget);
    expect(backups, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('нет связи — предупреждение в строке состояния', (tester) async {
    await setUpSync(tester);
    await tester.runAsync(() async {
      await sync.signIn('localhost', 'ivan', 'secret-pass');
      await sync.link(await sync.analyzeLink());
    });
    server.online = false;
    await tester.pumpWidget(withBar());
    await tester.tap(find.byTooltip('Синхронизировать сейчас'));
    await settle(tester);
    expect(find.text('Синхронизация…'), findsOneWidget);
    // Движок дважды повторяет попытку (паузы 2 и 5 с).
    for (final wait in const [3, 6]) {
      await tester.pump(Duration(seconds: wait));
      await settle(tester);
    }
    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
    // Автоматика в этом тесте выключена — времени повтора нет.
    expect(find.textContaining('повтор в'), findsNothing);
  });

  testWidgets('экран сервера: учётная запись и журнал', (tester) async {
    await setUpSync(tester);
    await tester.runAsync(() async {
      await sync.signIn('localhost', 'ivan', 'secret-pass');
      await sync.link(await sync.analyzeLink());
      await journal.add([
        JournalEntry(
          at: DateTime.utc(2026, 9, 27, 9),
          kind: JournalKind.lost,
          table: 'timesheet',
          uuid: '01900000-0000-7000-8000-00000000000c',
          message:
              'Табель: правка с этого устройства уступила более поздней '
              'правке с сервера',
          local: {'date': '2026-09-01', 'days': 1.0},
          remote: {'date': '2026-09-01', 'days': 0.5},
        ),
      ]);
    });
    await tester.pumpWidget(app(const SyncScreen()));
    await settle(tester);

    expect(find.text('Сервер синхронизации'), findsOneWidget);
    expect(find.text('https://localhost'), findsOneWidget);
    expect(find.textContaining('ivan, администратор'), findsOneWidget);
    expect(find.text('Синхронизировать сейчас'), findsOneWidget);
    expect(find.textContaining('уступила более поздней'), findsOneWidget);

    await tester.tap(find.textContaining('уступила более поздней'));
    await tester.pumpAndSettle();
    expect(find.text('Версия этого компьютера'), findsOneWidget);
    expect(find.text('Версия сервера'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('отладочная сборка: чужой сервер — только с отметкой согласия', (
    tester,
  ) async {
    await setUpSync(tester, debugBuild: true);
    await tester.pumpWidget(withBar());
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing, reason: 'стенд');

    await tester.tap(find.textContaining('Сервер: '));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Адрес сервера'),
      'tab.korovatech.ru',
    );
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Логин'), 'ivan');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      'secret-pass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await settle(tester);
    expect(find.textContaining('Отметьте согласие'), findsOneWidget);
    expect(sync.phase, SyncPhase.signedOut);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await settle(tester);
    expect(sync.server, 'https://tab.korovatech.ru');
    expect(sync.phase, SyncPhase.needsLink);
  });
}
