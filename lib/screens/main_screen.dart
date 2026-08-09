import 'package:flutter/material.dart';
import 'employees_screen.dart';
import 'timesheet_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'directories_screen.dart'; // новый импорт

/// Главный экран приложения с боковой навигацией
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Сотрудники',
      screen: const EmployeesScreen(),
    ),
    NavigationItem(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Табель',
      screen: const TimesheetScreen(),
    ),
    NavigationItem(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Выплаты',
      screen: const PaymentsScreen(),
    ),
    NavigationItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Отчёты',
      screen: const ReportsScreen(),
    ),
    // Справочники теперь один пункт, ведущий на экран со списком справочников
    NavigationItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Справочники',
      screen: const DirectoriesScreen(),
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Настройки',
      screen: const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Боковая навигация
          NavigationRail(
            extended: isWide,
            minExtendedWidth: 200,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isWide
                  ? Row(
                      children: [
                        Icon(
                          Icons.agriculture,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'КФХ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.agriculture,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
            ),
            destinations: _navigationItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              );
            }).toList(),
          ),
          // Разделитель
          const VerticalDivider(thickness: 1, width: 1),
          // Основное содержимое
          Expanded(child: _navigationItems[_selectedIndex].screen),
        ],
      ),
    );
  }
}

/// Модель пункта навигации
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });
}
