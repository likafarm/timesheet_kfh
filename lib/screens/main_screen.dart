import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'daily_input_screen.dart';
import 'home_screen.dart';
import 'reminder_screen.dart';
import 'employees_screen.dart';
import 'timesheet_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/reminder.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/section_navigation.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/update_banner.dart';

/// Главный экран: узкий экран (телефон) — нижняя навигация, широкий —
/// тёмная боковая панель (UI_REQUIREMENTS п. 2.2). Набор разделов зависит
/// от программы: оператору — только табель, сотрудники и вход на сервер.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Разделы полной программы (администратор, бухгалтер): первый — сводка.
  static List<NavigationItem> fullSections() => [
    NavigationItem(
      section: AppSection.home,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Главная',
      screen: const HomeScreen(),
    ),
    NavigationItem(
      section: AppSection.timesheet,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Табель',
      screen: const TimesheetScreen(),
    ),
    NavigationItem(
      section: AppSection.employees,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Сотрудники',
      screen: const EmployeesScreen(),
    ),
    NavigationItem(
      section: AppSection.payments,
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Выплаты',
      screen: const PaymentsScreen(),
    ),
    NavigationItem(
      section: AppSection.reports,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Отчёты',
      screen: const ReportsScreen(),
    ),
    NavigationItem(
      section: AppSection.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Настройки',
      screen: const SettingsScreen(),
    ),
  ];

  /// Разделы программы оператора (телефон). 6.10: первый — табель, ввод
  /// за день — кнопкой в его заголовке, как в полной программе.
  static List<NavigationItem> operatorSections() => [
    NavigationItem(
      section: AppSection.timesheet,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Табель',
      screen: const TimesheetScreen(),
    ),
    NavigationItem(
      section: AppSection.employees,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Сотрудники',
      screen: const EmployeesScreen(),
    ),
    NavigationItem(
      section: AppSection.sync,
      icon: Icons.cloud_outlined,
      selectedIcon: Icons.cloud,
      label: 'Сервер',
      screen: const SyncScreen(),
    ),
  ];

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  late final AppProvider _app;
  late final SyncProvider? _sync = context.read<SyncProvider?>();
  late final List<NavigationItem> _navigationItems;
  final _sections = SectionNavigator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _app = context.read<AppProvider>();
    _navigationItems = _app.operatorMode
        ? MainScreen.operatorSections()
        : MainScreen.fullSections();
    _app.addListener(_showNotice);
    _sections.addListener(_openRequested);
    // Напоминание о табеле (6.10): по роли вошедшего; на телефоне окно —
    // по сигналу Android, на Windows и в вебе — плашка с переходом в табель.
    final reminders = Reminders.instance
      ..onOpenTimesheet = () => _sections.open(AppSection.timesheet);
    reminders.requests.addListener(_showReminder);
    if (_sync case final sync?) reminders.attach(sync);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await reminders.takePending()) _showReminder();
    });
  }

  @override
  void dispose() {
    _sections.removeListener(_openRequested);
    _sections.dispose();
    _app.removeListener(_showNotice);
    Reminders.instance.requests.removeListener(_showReminder);
    if (_sync case final sync?) Reminders.instance.detach(sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Сообщение программы (например, «месяц закрыт») — внизу окна.
  void _showNotice() {
    final notice = _app.takeNotice();
    if (notice == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notice), duration: const Duration(seconds: 6)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _createBackup();
    }
  }

  Future<void> _createBackup() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.createBackup();
      debugPrint('Автоматический бэкап создан');
    } catch (e) {
      debugPrint('Автоматический бэкап не удался: $e');
    }
  }

  void _select(int index) => setState(() => _selectedIndex = index);

  bool _reminderOpen = false;

  /// Окно напоминания; «Открыть программу» — ввод за день в программе.
  Future<void> _showReminder() async {
    if (_reminderOpen || !mounted) return;
    _reminderOpen = true;
    final navigator = Navigator.of(context);
    final exit = await navigator.push<ReminderExit>(
      MaterialPageRoute(builder: (_) => const ReminderScreen()),
    );
    _reminderOpen = false;
    final openApp = exit == ReminderExit.openApp;
    await Reminders.instance.done(leave: !openApp);
    if (openApp && mounted) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const DailyInputScreen(standalone: true),
        ),
      );
    }
  }

  Future<bool> _confirmExit() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Выйти из программы?'),
        content: const Text(
          'Всё сохранённое останется на телефоне; неотправленное уйдёт на '
          'сервер при следующем запуске.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Разделы с отдельной кнопкой внизу на телефоне (индексы
  /// [_navigationItems]); остальные — в «Ещё».
  List<int> _bottomItems() {
    if (_navigationItems.length <= 5) {
      return [for (var i = 0; i < _navigationItems.length; i++) i];
    }
    const primary = {
      AppSection.home,
      AppSection.timesheet,
      AppSection.payments,
      AppSection.reports,
    };
    return [
      for (final (i, item) in _navigationItems.indexed)
        if (primary.contains(item.section)) i,
    ];
  }

  /// «Ещё»: разделы, не поместившиеся внизу.
  Future<void> _showMore(List<int> bar) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, item) in _navigationItems.indexed)
              if (!bar.contains(i))
                ListTile(
                  leading: Icon(
                    i == _selectedIndex ? item.selectedIcon : item.icon,
                  ),
                  title: Text(item.label),
                  selected: i == _selectedIndex,
                  onTap: () => Navigator.pop(context, i),
                ),
          ],
        ),
      ),
    );
    if (index != null && mounted) _select(index);
  }

  /// Переход из сводки ([SectionNavigator.open]).
  void _openRequested() {
    final section = _sections.takeSection();
    final index = _navigationItems.indexWhere((i) => i.section == section);
    if (index >= 0) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const UpdateBanner(),
        Expanded(
          child: ChangeNotifierProvider.value(
            value: _sections,
            child: IndexedStack(
              index: _selectedIndex,
              children: _navigationItems.map((item) => item.screen).toList(),
            ),
          ),
        ),
      ],
    );
    final compact = MediaQuery.sizeOf(context).width < AppTheme.compactWidth;
    if (compact) {
      // Больше пяти пунктов внизу не помещаются (подписи обрезаются) —
      // остальные разделы в «Ещё» (6.9).
      final bar = _bottomItems();
      final current = bar.indexOf(_selectedIndex);
      final scaffold = Scaffold(
        body: content,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SyncStatusBar(),
            BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: current >= 0 ? current : bar.length,
              onTap: (i) => i < bar.length ? _select(bar[i]) : _showMore(bar),
              items: [
                for (final i in bar)
                  BottomNavigationBarItem(
                    icon: Icon(_navigationItems[i].icon),
                    activeIcon: Icon(_navigationItems[i].selectedIcon),
                    label: _navigationItems[i].label,
                  ),
                if (bar.length < _navigationItems.length)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.more_horiz),
                    label: 'Ещё',
                  ),
              ],
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              // Активный пункт крупнее (UI_REQUIREMENTS п. 2.1).
              selectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
      // Android (6.10): «Назад» на главном окне — выход только после
      // вопроса.
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        return scaffold;
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && await _confirmExit()) SystemNavigator.pop();
        },
        child: scaffold,
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppTheme.navigationBackground,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            minWidth: 96,
            indicatorColor: AppTheme.primaryColor,
            selectedIconTheme: const IconThemeData(
              color: AppTheme.navigationSelected,
              size: 26,
            ),
            unselectedIconTheme: const IconThemeData(
              color: AppTheme.navigationForeground,
              size: 22,
            ),
            // От стиля темы: иначе у подписей нет шрифта темы (в вебе —
            // Roboto), и они рисуются шрифтом по умолчанию.
            selectedLabelTextStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(
                  color: AppTheme.navigationSelected,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
            unselectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppTheme.navigationForeground, fontSize: 12),
            destinations: _navigationItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              );
            }).toList(),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: content),
                const SyncStatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final AppSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  NavigationItem({
    required this.section,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });
}
