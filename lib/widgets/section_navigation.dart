// lib/widgets/section_navigation.dart
//
// Разделы главного окна, их группы в меню (8Б.1) и переход между ними
// (6.8): сводка открывает табель или отчёты на нужном месяце. MainScreen
// выбирает раздел, экран раздела забирает запрошенный месяц (takeMonth).

import 'package:flutter/material.dart';

enum AppSection {
  home,
  timesheet,
  employees,
  payments,
  reports,
  periods,

  /// Финансы (8Б.1): доходы, расходы — один список операций с отбором по
  /// виду; у оператора — [finance] (свои доходы и расходы).
  income,
  expense,
  finance,
  banks,
  loans,
  financeReports,
  financeCatalog,
  sync,
  settings,
}

/// Группа бокового меню (8Б.1, решение владельца 2026-10-08).
enum NavGroup {
  finance('Финансы'),
  payroll('Зарплата'),
  service('Сервис');

  final String title;
  const NavGroup(this.title);
}

/// Пункт меню главного окна.
class NavigationItem {
  final AppSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  /// Группа меню; null — пункт без группы (Главная, разделы оператора).
  final NavGroup? group;

  NavigationItem({
    required this.section,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
    this.group,
  });
}

class SectionNavigator extends ChangeNotifier {
  AppSection? _requested;
  final _months = <AppSection, DateTime>{};

  /// Раздел, который нужно открыть (MainScreen забирает его — [takeSection]).
  AppSection? takeSection() {
    final s = _requested;
    _requested = null;
    return s;
  }

  /// Месяц, запрошенный для раздела [section] (показывается один раз).
  DateTime? takeMonth(AppSection section) => _months.remove(section);

  void open(AppSection section, {DateTime? month}) {
    _requested = section;
    if (month != null) _months[section] = DateTime(month.year, month.month);
    notifyListeners();
  }
}
