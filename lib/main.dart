import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/main_screen.dart';
import 'services/platform.dart';
import 'services/startup.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);

  final PlatformServices platform;
  try {
    platform = await startPlatform();
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
    );
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
  }

  @override
  void dispose() {
    _sync.dispose();
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _app),
        ChangeNotifierProvider.value(value: _sync),
      ],
      child: MaterialApp(
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
