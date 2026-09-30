import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/main_screen.dart';
import 'services/app_keys.dart';
import 'services/platform.dart';
import 'services/startup.dart';
import 'services/window_front.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'widgets/auth_gate.dart';

/// Установщик после тихого обновления запускает программу с этой
/// отметкой (installer.iss): окно нужно вывести наверх — само оно
/// открывается позади остальных.
const afterUpdateArgument = '--after-update';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  if (args.contains(afterUpdateArgument)) {
    // Окно показывается после первого кадра; ещё раз — на случай долгого
    // запуска (перенос или проверка базы).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final ms in const [300, 1500]) {
        Future<void>.delayed(Duration(milliseconds: ms), bringWindowToFront);
      }
    });
  }
  await _start();
}

/// [takeOver] — веб-версия забирает работу у другой вкладки.
Future<void> _start({bool takeOver = false}) async {
  final PlatformServices platform;
  try {
    platform = await startPlatform(takeOver: takeOver);
  } on AnotherTabOpen {
    runApp(
      AnotherTabApp(
        text:
            'Программа уже открыта в другой вкладке этого браузера. Работать '
            'можно только в одной вкладке — иначе правки могут потеряться.',
        onWorkHere: () => _start(takeOver: true),
      ),
    );
    return;
  } catch (e) {
    runApp(StartupErrorApp(message: '$e'));
    return;
  }

  runApp(MyApp(platform: platform));
}

ThemeData get _theme => AppTheme.lightTheme;

const _localizations = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class MyApp extends StatefulWidget {
  final PlatformServices platform;

  const MyApp({super.key, required this.platform});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppProvider _app;
  late final SyncProvider _sync;
  late int _generation;

  /// Веб-версию открыли в другой вкладке — здесь всё остановлено.
  bool _lostToAnotherTab = false;

  @override
  void initState() {
    super.initState();
    final platform = widget.platform;
    _app = AppProvider(platform.database, backupService: platform.backups);
    _sync = SyncProvider(
      database: _app.localDatabase,
      onDataChanged: _app.reloadAfterSync,
      // Веб-версия принимает данные только в пустую базу браузера —
      // копировать перед первым входом нечего.
      backup: _app.hasLocalBackups ? _app.createSyncSafetyBackup : () async {},
      onLocksChanged: _app.loadLockedMonths,
      tokenStore: platform.tokenStore,
      journal: platform.journal,
      rememberSignIn: platform.rememberSignIn,
      eraseAfterSignOut: platform.eraseLocalData == null
          ? null
          : () async {
              // Веб-версия: база браузера стирается, страница начинает
              // с чистого листа.
              await _app.localDatabase.close();
              await platform.eraseLocalData!();
              platform.reloadPage?.call();
            },
    );
    // Разделы программы — по роли вошедшего (6.9): на телефоне оператор
    // видит только табель, бухгалтер и админ — полную программу. Слушатель
    // добавлен раньше экранов — режим меняется до их перестройки.
    _sync.addListener(() {
      final user = _sync.user;
      if (user != null) _app.operatorMode = user.isOperator;
    });
    platform.guardPageClose?.call(() => _sync.pending > 0);
    _app.beforeDatabaseReplaced = _sync.suspend;
    _generation = _app.databaseGeneration;
    // Полное восстановление из копии переоткрывает базу — синхронизация
    // переключается на новую.
    _app.addListener(() {
      if (_app.databaseGeneration != _generation) {
        _app.beforeDatabaseReplaced = _sync.suspend;
        _generation = _app.databaseGeneration;
        _sync.rebind(_app.localDatabase);
      }
    });
    _app.loadAllData().then((_) async {
      await _app.autoBackup();
      await _sync.init();
    });
    platform.lostToAnotherTab?.then((_) async {
      await _sync.suspend();
      await _app.localDatabase.close();
      if (mounted) setState(() => _lostToAnotherTab = true);
    });
  }

  @override
  void dispose() {
    _sync.dispose();
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lostToAnotherTab) {
      return AnotherTabApp(
        text:
            'Программу открыли в другой вкладке браузера — работа '
            'продолжается там. Эта вкладка остановлена, введённое сохранено.',
        onWorkHere: () async => widget.platform.reloadPage?.call(),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _app),
        ChangeNotifierProvider.value(value: _sync),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appMessengerKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru', 'RU'),
        supportedLocales: const [Locale('ru', 'RU')],
        localizationsDelegates: _localizations,
        theme: _theme,
        darkTheme: AppTheme.darkTheme,
        // Без входа программа не запускается (все платформы).
        home: const AuthGate(child: MainScreen()),
      ),
    );
  }
}

/// Веб-версия: программа открыта в другой вкладке браузера.
class AnotherTabApp extends StatelessWidget {
  final String text;
  final Future<void> Function() onWorkHere;

  const AnotherTabApp({
    super.key,
    required this.text,
    required this.onWorkHere,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: _localizations,
      theme: _theme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tab_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(text, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onWorkHere,
                    child: const Text('Работать здесь'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран вместо программы, если база не открылась (например, не удался
/// перенос в новый формат). Данные при этом не меняются.
class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: _localizations,
      theme: _theme,
      home: Scaffold(
        appBar: AppBar(title: const Text(AppConstants.appName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, size: 40, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'База данных не открыта',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(startupErrorHint),
              const SizedBox(height: 16),
              SelectableText(
                message,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: message)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Скопировать текст'),
                  ),
                  // Страницу браузера программа не закрывает.
                  if (!isWebApp) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => SystemNavigator.pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Закрыть программу'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
