import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'daily_input_screen.dart';
import 'home_screen.dart';
import 'employees_screen.dart';
import 'timesheet_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/section_navigation.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/update_banner.dart';

/// Главный экран: узкий экран (телефон) — нижняя навигация, широкий —
/// тёмная боковая панель (UI_REQUIREMENTS п. 2.2). Набор разделов зависит
/// от программы: оператору — только ввод за день, табель, сотрудники и вход на сервер.
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

  /// Разделы программы оператора (телефон): главный — ввод за день.
  static List<NavigationItem> operatorSections() => [
    NavigationItem(
      section: AppSection.day,
      icon: Icons.edit_calendar_outlined,
      selectedIcon: Icons.edit_calendar,
      label: 'День',
      screen: const DailyInputScreen(),
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
  }

  @override
  void dispose() {
    _sections.removeListener(_openRequested);
    _sections.dispose();
    _app.removeListener(_showNotice);
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
      return Scaffold(
        body: content,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SyncStatusBar(),
            BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _select,
              items: _navigationItems.map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.selectedIcon),
                  label: item.label,
                );
              }).toList(),
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
            selectedLabelTextStyle: const TextStyle(
              color: AppTheme.navigationSelected,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: AppTheme.navigationForeground,
              fontSize: 12,
            ),
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
