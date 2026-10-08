// lib/screens/finance_screen.dart
//
// Раздел «Финансы» (этап 8.5): операции месяца таблицей (широкий экран)
// или карточками (телефон), фильтры — списками (решение владельца
// 2026-10-06), итоги по фильтру. Выплаты ЗП — расходами из табеля, только
// чтение. Только администратор и бухгалтер.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/excel_export.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/closed_month.dart';
import '../widgets/common_widgets.dart';
import '../widgets/excel_export_action.dart';
import '../widgets/finance_operation_dialog.dart';
import '../widgets/finance_reconcile_dialog.dart';
import '../widgets/month_switcher.dart';
import 'finance_balances_screen.dart';
import 'finance_catalog_screen.dart';
import 'finance_quick_screen.dart';
import 'finance_report_screen.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => FinanceProvider(context.read<AppProvider>())..load(),
    child: const _FinanceView(),
  );
}

class _FinanceView extends StatefulWidget {
  const _FinanceView();

  @override
  State<_FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<_FinanceView> {
  FinanceFilter _filter = FinanceFilter(
    month: DateTime(DateTime.now().year, DateTime.now().month),
  );

  // Ширины столбцов — как в «Выплатах»: промежутки 8.
  static const _cNo = 40.0;
  static const _cDate = 90.0;
  static const _cType = 80.0;
  static const _cAmount = 120.0;
  static const _cAccount = 130.0;
  static const _cCategory = 190.0;
  static const _cDirection = 150.0;
  static const _cCounterparty = 160.0;
  static const _cWhat = 200.0;
  static const _cActions = 48.0;
  static const _gap = 8.0;
  static const _tableWidth =
      _cNo +
      _cDate +
      _cType +
      _cAmount +
      _cAccount +
      _cCategory +
      _cDirection +
      _cCounterparty +
      _cWhat +
      _cActions +
      9 * _gap +
      32;

  DateTime get _month => _filter.month!;

  void _setMonth(DateTime month) => setState(
    () => _filter = _filter.copyWith(
      month: () => DateTime(month.year, month.month),
    ),
  );

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите месяц и год',
    );
    if (picked != null) _setMonth(picked);
  }

  /// Новая операция: на телефоне без образца — быстрый ввод (8.6), иначе —
  /// полное окно.
  Future<void> _add(FinanceProvider fin, {FinOperation? template}) async {
    final day = calendarDay(DateTime.now());
    if (!await ensureMonthOpen(context, day.year, day.month) || !mounted) {
      return;
    }
    final ok = template == null && MonthSwitcher.isCompact(context)
        ? await openQuickOperation(context, fin)
        : await showOperationDialog(context, fin, template: template);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Записано')));
    }
  }

  Future<void> _edit(FinanceProvider fin, FinOperation op) async {
    if (FinanceProvider.isPayroll(op)) {
      await _payrollInfo(op);
      return;
    }
    if (!await ensureMonthOpen(context, op.date.year, op.date.month) ||
        !mounted) {
      return;
    }
    await showOperationDialog(context, fin, operation: op);
  }

  Future<void> _payrollInfo(FinOperation op) => showAppDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: const Text('Выплата зарплаты'),
      content: const Text(
        'Расход построен из выплаты табеля: кошелёк — по способу выплаты, '
        'статья — по должности. Изменить или удалить её можно в разделе '
        '«Выплаты».',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );

  Future<void> _delete(FinanceProvider fin, FinOperation op) async {
    if (!await ensureMonthOpen(context, op.date.year, op.date.month) ||
        !mounted) {
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить операцию?'),
        content: Text(
          '${DateFormat('dd.MM.yyyy').format(op.date)} · '
          '${op.type.title} · ${formatRub(op.amount)} ₽'
          '${op.description == null ? '' : '\n${op.description}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await fin.deleteOperation(op);
  }

  void _openCatalog(FinanceProvider fin) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: fin,
        child: const FinanceCatalogScreen(),
      ),
    ),
  );

  /// Остатки на конец выбранного месяца (текущего — на сегодня); выбранный
  /// там кошелёк становится отбором.
  Future<void> _openBalances(FinanceProvider fin) async {
    final today = calendarDay(DateTime.now());
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final accountId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: fin,
          child: FinanceBalancesScreen(
            day: monthEnd.isAfter(today) && !_month.isAfter(today)
                ? today
                : monthEnd,
          ),
        ),
      ),
    );
    if (accountId != null && mounted) {
      setState(() => _filter = _filter.copyWith(accountId: () => accountId));
    }
  }

  /// Отчёт по месяцам за год выбранного месяца; нажатая сумма становится
  /// отбором списка.
  Future<void> _openReport(
    FinanceProvider fin, {
    FinanceReportMode mode = FinanceReportMode.category,
  }) async {
    final filter = await openFinanceReport(
      context,
      fin,
      year: _month.year,
      mode: mode,
    );
    if (filter != null && mounted) setState(() => _filter = filter);
  }

  Future<void> _reconcile(FinanceProvider fin) async {
    final ok = await showReconcileDialog(
      context,
      fin,
      accountId: _filter.accountId,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Корректировка записана')));
    }
  }

  /// Список по отбору в Excel — те же строки и итоги, что на экране.
  Future<void> _export(FinanceProvider fin) async {
    final app = context.read<AppProvider>();
    if (app.companySettings == null) await app.loadCompanySettings();
    if (!mounted) return;
    final f = _filter;
    final ops = fin.operations(f);
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final accountId = f.accountId;
    await exportToExcel(
      context,
      fileName: excelFileName('Финансы', _month),
      build: () async => financeWorkbook(
        period: DateFormat('LLLL yyyy', 'ru')
            .format(_month)
            .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
        filters: [
          if (f.type != null) 'вид — ${f.type!.title}',
          if (accountId != null) 'кошелёк — ${fin.accountName(accountId)}',
          if (f.categoryId != null)
            'статья — ${fin.categoryName(f.categoryId)}',
          if (f.directionId != null)
            'направление — ${fin.catalog.directions[f.directionId]?.name ?? '—'}',
          if (f.counterpartyId != null)
            'контрагент — ${fin.counterpartyName(f.counterpartyId)}',
        ],
        rows: [
          for (final op in ops)
            FinanceExportRow(
              date: op.date,
              type: op.type.title,
              amount: op.amount,
              account: fin.accountName(op.accountId),
              what: fin.whatLabel(op),
              direction: fin.directionLabel(op),
              counterparty: fin.counterpartyLabel(op),
              description: op.description ?? '',
              payroll: FinanceProvider.isPayroll(op),
            ),
        ],
        totals: fin.totals(ops),
        balance: accountId == null
            ? null
            : (
                'Остаток «${fin.accountName(accountId)}» на '
                    '${DateFormat('dd.MM.yyyy').format(monthEnd)}',
                fin.accountBalancesAt(monthEnd)[accountId] ?? 0,
              ),
        companySettings: app.companySettings,
      ),
    );
  }

  // ------------------------------------------------------------ фильтры

  Widget _filters(FinanceProvider fin, {required bool compact}) {
    DropdownMenuItem<String?> all() =>
        const DropdownMenuItem<String?>(value: null, child: Text('Все'));
    Widget box(Widget child) =>
        compact ? child : SizedBox(width: 200, child: child);
    final fields = [
      box(
        AppDropdown<OperationType?>(
          labelText: 'Вид',
          value: _filter.type,
          items: [
            const DropdownMenuItem<OperationType?>(
              value: null,
              child: Text('Все'),
            ),
            for (final t in OperationType.values)
              DropdownMenuItem(value: t, child: Text(t.title)),
          ],
          onChanged: (v) =>
              setState(() => _filter = _filter.copyWith(type: () => v)),
        ),
      ),
      box(
        AppDropdown<String?>(
          labelText: 'Кошелёк',
          value: _filter.accountId,
          items: [
            all(),
            for (final a in fin.accounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (v) =>
              setState(() => _filter = _filter.copyWith(accountId: () => v)),
        ),
      ),
      box(
        AppDropdown<String?>(
          labelText: 'Статья',
          value: _filter.categoryId,
          items: [
            all(),
            for (final c in [
              ...fin.categories,
            ]..sort((a, b) => a.name.compareTo(b.name)))
              DropdownMenuItem(
                value: c.id,
                child: Text(
                  '${c.name} (${c.type.title.toLowerCase()})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) =>
              setState(() => _filter = _filter.copyWith(categoryId: () => v)),
        ),
      ),
      box(
        AppDropdown<String?>(
          labelText: 'Направление',
          value: _filter.directionId,
          items: [
            all(),
            for (final d in fin.directions)
              DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) =>
              setState(() => _filter = _filter.copyWith(directionId: () => v)),
        ),
      ),
      box(
        AppDropdown<String?>(
          labelText: 'Контрагент',
          value: _filter.counterpartyId,
          items: [
            all(),
            for (final c in [
              ...fin.counterparties,
            ]..sort((a, b) => a.name.compareTo(b.name)))
              DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(
            () => _filter = _filter.copyWith(counterpartyId: () => v),
          ),
        ),
      ),
      if (_filter.narrowed)
        TextButton.icon(
          onPressed: () =>
              setState(() => _filter = FinanceFilter(month: _filter.month)),
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text('Сбросить'),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: compact
          ? Column(
              children: [
                for (final f in fields)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: f),
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: fields,
            ),
    );
  }

  /// Итоги по отбору и остаток выбранного кошелька на конец месяца.
  Widget _totals(FinanceProvider fin, List<FinOperation> ops) {
    final t = fin.totals(ops);
    final theme = Theme.of(context);
    Widget item(String label, int value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(right: 20, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            '${formatRub(value)} ₽',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    final accountId = _filter.accountId;
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        children: [
          item(
            'Доходы',
            t.income + t.refunds,
            color: operationTypeColors[OperationType.income],
          ),
          item(
            'Расходы',
            t.expense + t.capex,
            color: operationTypeColors[OperationType.expense],
          ),
          if (t.capex != 0) item('в т. ч. капвложения', t.capex),
          item('Итог', t.result),
          if (t.transfers != 0) item('Переводы', t.transfers),
          if (t.debtIn != 0 || t.debtOut != 0)
            item('Займы: пришло / ушло', t.debtIn - t.debtOut),
          if (accountId != null && !fin.operator)
            item(
              'Остаток «${fin.accountName(accountId)}» на '
              '${DateFormat('dd.MM.yyyy').format(monthEnd)}',
              fin.accountBalancesAt(monthEnd)[accountId] ?? 0,
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- строки

  String _signed(FinOperation op) {
    final sign = switch (op.type) {
      OperationType.income => '+',
      OperationType.expense => '−',
      OperationType.transfer => '',
      OperationType.debt => (op.debtMove?.cashSign ?? 0) > 0 ? '+' : '−',
    };
    return '$sign${formatRub(op.amount)}';
  }

  Widget _menu(FinanceProvider fin, FinOperation op) {
    final payroll = FinanceProvider.isPayroll(op);
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => switch (v) {
        'edit' => _edit(fin, op),
        'repeat' => _add(fin, template: op),
        'delete' => _delete(fin, op),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Text(payroll ? 'Откуда эта строка' : 'Изменить'),
        ),
        if (!payroll) ...[
          const PopupMenuItem(
            value: 'repeat',
            child: Text('Повторить операцию'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }

  Widget _header() {
    Widget cell(double w, String t, {TextAlign? align}) => SizedBox(
      width: w,
      child: Text(
        t,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          cell(_cNo, '№'),
          const SizedBox(width: _gap),
          cell(_cDate, 'Дата'),
          const SizedBox(width: _gap),
          cell(_cType, 'Вид'),
          const SizedBox(width: _gap),
          cell(_cAmount, 'Сумма, ₽', align: TextAlign.right),
          const SizedBox(width: _gap),
          cell(_cAccount, 'Кошелёк'),
          const SizedBox(width: _gap),
          cell(_cCategory, 'Статья / куда'),
          const SizedBox(width: _gap),
          cell(_cDirection, 'Направление'),
          const SizedBox(width: _gap),
          cell(_cCounterparty, 'Контрагент'),
          const SizedBox(width: _gap),
          cell(_cWhat, 'Что'),
          const SizedBox(width: _gap),
          cell(_cActions, ''),
        ],
      ),
    );
  }

  Widget _row(FinanceProvider fin, int index, FinOperation op) {
    final payroll = FinanceProvider.isPayroll(op);
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: 12,
      color: payroll ? theme.colorScheme.onSurfaceVariant : null,
      fontStyle: payroll ? FontStyle.italic : null,
    );
    Widget cell(double w, String t, {TextAlign? align, TextStyle? s}) =>
        SizedBox(
          width: w,
          child: Text(
            t,
            style: s ?? style,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
    final what = [?op.description, if (payroll) 'из табеля'].join(' · ');
    return InkWell(
      onLongPress: () => _edit(fin, op),
      onDoubleTap: () => _edit(fin, op),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            cell(_cNo, '$index'),
            const SizedBox(width: _gap),
            cell(_cDate, DateFormat('dd.MM.yyyy').format(op.date)),
            const SizedBox(width: _gap),
            cell(
              _cType,
              op.type.title,
              s: style.copyWith(color: operationTypeColors[op.type]),
            ),
            const SizedBox(width: _gap),
            cell(
              _cAmount,
              _signed(op),
              align: TextAlign.right,
              s: style.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: _gap),
            cell(_cAccount, fin.accountName(op.accountId)),
            const SizedBox(width: _gap),
            cell(_cCategory, fin.whatLabel(op)),
            const SizedBox(width: _gap),
            cell(_cDirection, fin.directionLabel(op)),
            const SizedBox(width: _gap),
            cell(_cCounterparty, fin.counterpartyLabel(op)),
            const SizedBox(width: _gap),
            cell(_cWhat, what),
            const SizedBox(width: _gap),
            SizedBox(width: _cActions, child: _menu(fin, op)),
          ],
        ),
      ),
    );
  }

  Widget _card(FinanceProvider fin, FinOperation op) {
    final details = [
      DateFormat('dd.MM.yyyy').format(op.date),
      fin.accountName(op.accountId),
      if (fin.counterpartyLabel(op) case final c when c.isNotEmpty) c,
    ].join(' · ');
    return ListTile(
      title: Text(fin.whatLabel(op), overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [details, ?op.description].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      // Сумма и меню (изменить, повторить, удалить) — 8.8.4.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_signed(op)} ₽',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: operationTypeColors[op.type],
            ),
          ),
          _menu(fin, op),
        ],
      ),
      onTap: () => _edit(fin, op),
      onLongPress: FinanceProvider.isPayroll(op)
          ? null
          : () => _add(fin, template: op),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    final compact = MonthSwitcher.isCompact(context);
    final ops = fin.loaded ? fin.operations(_filter) : const <FinOperation>[];
    final appBar = monthAppBar(
      context,
      title: fin.operator ? 'Мои расходы и доходы' : 'Финансы',
      switcher: MonthSwitcher(
        month: _month,
        onPrevious: () => _setMonth(DateTime(_month.year, _month.month - 1)),
        onNext: () => _setMonth(DateTime(_month.year, _month.month + 1)),
        onPick: _pickMonth,
        onToday: () => _setMonth(DateTime.now()),
      ),
      actions: [
        if (!compact)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Новая операция',
            onPressed: fin.loaded ? () => _add(fin) : null,
          ),
      ],
      // Оператор (8.8.4): только свои операции — без остатков, отчётов,
      // сверки, выгрузки и справочников.
      menu: [
        if (!fin.operator) ...[
          AppBarMenuItem(
            Icons.account_balance_wallet_outlined,
            'Остатки',
            fin.loaded ? () => _openBalances(fin) : null,
          ),
          AppBarMenuItem(
            Icons.calendar_view_month,
            'По месяцам',
            fin.loaded ? () => _openReport(fin) : null,
          ),
          AppBarMenuItem(
            Icons.agriculture_outlined,
            'Себестоимость кормов',
            fin.loaded
                ? () => _openReport(fin, mode: FinanceReportMode.season)
                : null,
          ),
          AppBarMenuItem(
            Icons.fact_check_outlined,
            'Сверка остатка',
            fin.loaded ? () => _reconcile(fin) : null,
          ),
          AppBarMenuItem(
            Icons.table_view,
            'Выгрузить в Excel',
            fin.loaded ? () => _export(fin) : null,
          ),
          AppBarMenuItem(
            Icons.menu_book_outlined,
            'Справочники и займы',
            fin.loaded ? () => _openCatalog(fin) : null,
          ),
        ],
        AppBarMenuItem(Icons.refresh, 'Обновить', fin.load),
      ],
    );
    if (!fin.loaded) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final empty = Center(
      child: Text(
        _filter.narrowed
            ? 'Нет операций по отбору за этот месяц'
            : 'Нет операций за этот месяц',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
    if (compact) {
      return Scaffold(
        appBar: appBar,
        // Телефон: быстрый ввод — большой кнопкой под пальцем (8.6).
        floatingActionButton: FloatingActionButton.extended(
          tooltip: 'Новая операция',
          onPressed: () => _add(fin),
          icon: const Icon(Icons.add),
          label: const Text('Расход / доход'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            ExpansionTile(
              title: Text(_filter.narrowed ? 'Отбор (задан)' : 'Отбор'),
              children: [_filters(fin, compact: true)],
            ),
            _totals(fin, ops),
            const Divider(height: 1),
            if (ops.isEmpty)
              Padding(padding: const EdgeInsets.all(32), child: empty)
            else
              for (final op in ops) _card(fin, op),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filters(fin, compact: false),
          _totals(fin, ops),
          Expanded(
            child: ops.isEmpty
                ? empty
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _tableWidth,
                      child: Column(
                        children: [
                          _header(),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: ops.length,
                              itemBuilder: (context, i) =>
                                  _row(fin, i + 1, ops[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
