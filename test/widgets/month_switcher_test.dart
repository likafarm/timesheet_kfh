import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/screens/timesheet_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/widgets/month_switcher.dart';
import 'package:provider/provider.dart';

/// Переключатель месяца в строке заголовка табеля (как в отчётах): на
/// широком окне — справа от заголовка, на телефоне — вместо заголовка, в
/// самом тесном случае (360 px, бухгалтер с печатью, месяц закрыт) строка
/// не переполняется.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('ru'));

  late LocalDatabase db;
  late AppProvider app;
  final now = DateTime.now();

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = LocalDatabase.memory();
      app = AppProvider(AppDatabase(db, ':memory:'));
      await DriftRepositories(db).employees.add(
        Employee(
          fullName: 'Иванов Иван Иванович',
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          baseRate: 0,
          fieldRate: 0,
        ),
      );
      await LocalSyncStore(db).saveLockedMonths([(now.year, now.month)]);
      await app.loadAllData();
    });
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: TimesheetScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Finder inAppBar(Finder f) =>
      find.descendant(of: find.byType(AppBar), matching: f);

  testWidgets('широкое окно: заголовок слева, месяц справа, как в отчётах', (
    tester,
  ) async {
    await open(tester, const Size(1280, 760));
    expect(tester.takeException(), isNull);
    expect(inAppBar(find.text('Табель учёта времени')), findsOneWidget);
    expect(inAppBar(find.byType(MonthSwitcher)), findsOneWidget);
    expect(inAppBar(find.text('закрыт')), findsOneWidget);
    // Порядок: заголовок, ‹ месяц ›, «текущий месяц», печать, ввод за день.
    double x(String tooltip) => tester.getCenter(find.byTooltip(tooltip)).dx;
    expect(
      tester.getCenter(find.text('Табель учёта времени')).dx,
      lessThan(x('Предыдущий месяц')),
    );
    expect(x('Предыдущий месяц'), lessThan(x('Следующий месяц')));
    expect(x('Следующий месяц'), lessThan(x('Текущий месяц')));
    expect(x('Текущий месяц'), lessThan(x('Печать табеля')));
    expect(x('Печать табеля'), lessThan(x('Ввод за день')));
    // Отдельной полосы месяца под заголовком больше нет.
    expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
  });

  testWidgets('чуть шире телефона (640 px) — без переполнения', (tester) async {
    await open(tester, const Size(640, 760));
    expect(tester.takeException(), isNull);
    expect(inAppBar(find.byType(MonthSwitcher)), findsOneWidget);
    expect(find.byTooltip('Ввод за день'), findsOneWidget);
  });

  testWidgets('телефон 360 px: месяц вместо заголовка, всё помещается', (
    tester,
  ) async {
    await open(tester, const Size(360, 740));
    expect(tester.takeException(), isNull, reason: 'нет переполнения');
    expect(find.text('Табель учёта времени'), findsNothing);
    for (final t in [
      'Предыдущий месяц',
      'Следующий месяц',
      'Текущий месяц',
      'Печать табеля',
      'Ввод за день',
    ]) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
    // Закрытый месяц на телефоне — только значок замка.
    expect(find.text('закрыт'), findsNothing);
    expect(inAppBar(find.byIcon(Icons.lock_outline)), findsOneWidget);

    // Переключение месяцев работает.
    await tester.tap(find.byTooltip('Следующий месяц'));
    await tester.pump();
    expect(inAppBar(find.byIcon(Icons.lock_outline)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
