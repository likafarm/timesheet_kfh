import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kfh_domain/kfh_domain.dart' show OperationType;
import 'package:provider/provider.dart';
import 'daily_input_screen.dart';
import 'home_screen.dart';
import 'reminder_screen.dart';
import 'employees_screen.dart';
import 'finance_balances_screen.dart';
import 'finance_catalog_screen.dart';
import 'finance_reports_screen.dart';
import 'finance_screen.dart';
import 'payment_calendar_screen.dart';
import 'periods_screen.dart';
import 'timesheet_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/sync_provider.dart';
import '../services/reminder.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/section_navigation.dart';
import '../widgets/side_menu.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/update_banner.dart';

/// Главный экран: узкий экран (телефон) — нижняя навигация и «Ещё» по
/// группам, широкий — тёмная боковая панель с группами (UI_REQUIREMENTS
/// п. 2.2, 8Б.1). Набор разделов зависит
/// от программы: оператору — только табель, сотрудники и вход на сервер.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Разделы полной программы (администратор, бухгалтер) по группам
  /// (8Б.1, решение владельца 2026-10-08): Главная, Финансы, Зарплата,
  /// Сервис.
  static List<NavigationItem> fullSections() => [
    NavigationItem(
      section: AppSection.home,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Главная',
      screen: const HomeScreen(),
    ),
    NavigationItem(
      section: AppSection.income,
      group: NavGroup.finance,
      icon: Icons.south_west,
      selectedIcon: Icons.south_west,
      label: 'Доходы',
      screen: const FinanceScreen(type: OperationType.income),
    ),
    NavigationItem(
      section: AppSection.expense,
      group: NavGroup.finance,
      icon: Icons.north_east,
      selectedIcon: Icons.north_east,
      label: 'Расходы',
      screen: const FinanceScreen(type: OperationType.expense),
    ),
    NavigationItem(
      section: AppSection.banks,
      group: NavGroup.finance,
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      label: 'Банки и кассы',
      screen: const FinanceBalancesScreen(),
    ),
    NavigationItem(
      section: AppSection.calendar,
      group: NavGroup.finance,
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: 'Платёжный календарь',
      screen: const PaymentCalendarScreen(),
    ),
    NavigationItem(
      section: AppSection.loans,
      group: NavGroup.finance,
      icon: Icons.handshake_outlined,
      selectedIcon: Icons.handshake,
      label: 'Займы',
      screen: const FinanceCatalogScreen.loans(),
    ),
    NavigationItem(
      section: AppSection.financeReports,
      group: NavGroup.finance,
      icon: Icons.insert_chart_outlined,
      selectedIcon: Icons.insert_chart,
      label: 'Отчёты',
      screen: const FinanceReportsScreen(),
    ),
    NavigationItem(
      section: AppSection.financeCatalog,
      group: NavGroup.finance,
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: 'Справочники',
      screen: const FinanceCatalogScreen(),
    ),
    NavigationItem(
      section: AppSection.employees,
      group: NavGroup.payroll,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Сотрудники',
      screen: const EmployeesScreen(),
    ),
    NavigationItem(
      section: AppSection.timesheet,
      group: NavGroup.payroll,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Табель',
      screen: const TimesheetScreen(),
    ),
    NavigationItem(
      section: AppSection.payments,
      group: NavGroup.payroll,
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Выплаты',
      screen: const PaymentsScreen(),
    ),
    NavigationItem(
      section: AppSection.reports,
      group: NavGroup.payroll,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Отчёты по ЗП',
      screen: const ReportsScreen(),
    ),
    NavigationItem(
      section: AppSection.periods,
      group: NavGroup.payroll,
      icon: Icons.lock_outline,
      selectedIcon: Icons.lock,
      label: 'Закрытие месяцев',
      screen: const PeriodsScreen(),
    ),
    NavigationItem(
      section: AppSection.settings,
      group: NavGroup.service,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Настройки',
      screen: const SettingsScreen(),
    ),
  ];

  /// Разделы программы оператора (телефон). 6.10: первый — табель, ввод
  /// за день — кнопкой в его заголовке, как в полной программе. 8.8.4:
  /// «Финансы» — свои расходы и доходы.
  static List<NavigationItem> operatorSections() => [
    NavigationItem(
      section: AppSection.timesheet,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Табель',
      screen: const TimesheetScreen(),
    ),
    NavigationItem(
      section: AppSection.finance,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Финансы',
      screen: const FinanceScreen(),
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
  late final FinanceProvider _finance = FinanceProvider(_app)..load();
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
    _finance.dispose();
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
  /// [_navigationItems]) в порядке кнопок; остальные — в «Ещё» по группам.
  /// У бухгалтера и администратора основной раздел — расходы (решение
  /// владельца 2026-10-08: финансы — первыми): быстрый ввод — там.
  List<int> _bottomItems() {
    if (_navigationItems.length <= 5) {
      return [for (var i = 0; i < _navigationItems.length; i++) i];
    }
    return [
      for (final section in _phonePrimary)
        if (_navigationItems.indexWhere((i) => i.section == section)
            case final i when i >= 0)
          i,
    ];
  }

  static const _phonePrimary = [
    AppSection.expense,
    AppSection.home,
    AppSection.timesheet,
    AppSection.payments,
  ];

  bool _startChosen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Телефон бухгалтера и администратора открывается на «Финансах».
    if (_startChosen) return;
    _startChosen = true;
    if (MediaQuery.sizeOf(context).width < AppTheme.compactWidth &&
        _navigationItems.length > 5) {
      _selectedIndex = _bottomItems().first;
    }
  }

  /// «Ещё»: разделы, не поместившиеся внизу, — по группам меню.
  Future<void> _showMore(List<int> bar) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tiles = <Widget>[];
        NavGroup? group;
        for (final (i, item) in _navigationItems.indexed) {
          if (bar.contains(i)) continue;
          if (item.group != group) {
            group = item.group;
            if (group != null) {
              tiles.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    group.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              );
            }
          }
          tiles.add(
            ListTile(
              dense: true,
              leading: Icon(
                i == _selectedIndex ? item.selectedIcon : item.icon,
              ),
              title: Text(item.label),
              selected: i == _selectedIndex,
              onTap: () => Navigator.pop(context, i),
            ),
          );
        }
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: ListView(shrinkWrap: true, children: tiles),
          ),
        );
      },
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
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _sections),
              // Одна модель финансов на все пункты группы (8Б.1).
              ChangeNotifierProvider.value(value: _finance),
            ],
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
          SideMenu(
            items: _navigationItems,
            selectedIndex: _selectedIndex,
            onSelected: _select,
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
