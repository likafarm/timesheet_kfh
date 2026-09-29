// lib/widgets/section_navigation.dart
//
// Переход между разделами главного окна (6.8): сводка открывает табель или
// отчёты на нужном месяце. MainScreen выбирает раздел, экран раздела
// забирает запрошенный месяц (takeMonth).

import 'package:flutter/foundation.dart';

enum AppSection {
  home,
  day,
  timesheet,
  employees,
  payments,
  reports,
  sync,
  settings,
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
