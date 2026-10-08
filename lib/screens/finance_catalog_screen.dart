// lib/screens/finance_catalog_screen.dart
//
// Справочники финансов и займы (8.5.4): кошельки и займы с остатками,
// статьи (по группам) и группы статей, контрагенты, имущество, направления
// и ключ распределения.
// Удалить можно только неиспользуемую запись — кошелёк закрывают, статью
// скрывают.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';
import '../widgets/common_widgets.dart';
import '../widgets/finance_operation_dialog.dart';

class FinanceCatalogScreen extends StatelessWidget {
  const FinanceCatalogScreen({super.key});

  static const tabs = [
    'Кошельки',
    'Займы',
    'Статьи',
    'Группы статей',
    'Контрагенты',
    'Имущество',
    'Направления',
  ];

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProvider>();
    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Справочники финансов'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final t in tabs) Tab(text: t)],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Добавить',
            onPressed: () =>
                _add(context, fin, DefaultTabController.of(context).index),
            child: const Icon(Icons.add),
          ),
          body: TabBarView(
            children: [
              _AccountsTab(fin),
              _DebtsTab(fin),
              _CategoriesTab(fin),
              _GroupsTab(fin),
              _CounterpartiesTab(fin),
              _AssetsTab(fin),
              _DirectionsTab(fin),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _add(
    BuildContext context,
    FinanceProvider fin,
    int tab,
  ) => switch (tab) {
    0 => editAccount(context, fin),
    1 => editDebt(context, fin),
    2 => editCategory(context, fin),
    3 => editCategoryGroup(context, fin),
    4 => editCounterparty(context, fin),
    5 => editAsset(context, fin),
    _ => editDirection(context, fin),
  };
}

String _rub(int kop) => '${formatRub(kop)} ₽';
String _day(DateTime? d) =>
    d == null ? '—' : DateFormat('dd.MM.yyyy').format(d);

Widget _list(List<Widget> tiles, {String empty = 'Пусто'}) => tiles.isEmpty
    ? Center(child: Text(empty))
    : ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => tiles[i],
      );

class _AccountsTab extends StatelessWidget {
  final FinanceProvider fin;
  const _AccountsTab(this.fin);

  @override
  Widget build(BuildContext context) {
    final balances = fin.accountBalancesAt();
    return _list([
      for (final a in fin.accounts)
        ListTile(
          leading: Icon(
            a.closed ? Icons.lock_outline : Icons.account_balance_wallet,
          ),
          title: Text(a.name),
          subtitle: Text(
            [
              a.kind.title,
              if (a.openingDate != null)
                'начало ${_day(a.openingDate)}: ${_rub(a.openingBalance)}',
              if (a.closed) 'закрыт',
            ].join(' · '),
          ),
          trailing: Text(
            _rub(balances[a.id] ?? 0),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => editAccount(context, fin, a),
        ),
    ]);
  }
}

class _DebtsTab extends StatelessWidget {
  final FinanceProvider fin;
  const _DebtsTab(this.fin);

  @override
  Widget build(BuildContext context) {
    final balances = fin.debtBalancesAt();
    return _list([
      for (final d in fin.debts)
        ListTile(
          leading: Icon(
            d.kind == DebtKind.received ? Icons.call_received : Icons.call_made,
          ),
          title: Text(fin.counterpartyName(d.counterpartyId)),
          subtitle: Text(
            [
              d.kind.title,
              if (d.openingDate != null)
                'на ${_day(d.openingDate)}: ${_rub(d.openingBalance)}',
              if (d.closed) 'закрыт',
            ].join(' · '),
          ),
          trailing: Text(
            _rub(balances[d.id] ?? 0),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => editDebt(context, fin, d),
        ),
    ], empty: 'Займов нет');
  }
}

class _CategoriesTab extends StatelessWidget {
  final FinanceProvider fin;
  const _CategoriesTab(this.fin);

  @override
  Widget build(BuildContext context) {
    // По группам справочника (в их порядке); статьи без группы в
    // справочнике (записи старых программ) — по названию группы в конце.
    final byGroup = <String, List<FinCategory>>{};
    final loose = <String, List<FinCategory>>{};
    for (final c in fin.categories) {
      final g = fin.catalog.groupOf(c);
      if (g != null) {
        (byGroup[g.id] ??= []).add(c);
      } else {
        (loose['${c.type.index}|${c.group}'] ??= []).add(c);
      }
    }
    int byName(FinCategory a, FinCategory b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      return o != 0 ? o : a.name.compareTo(b.name);
    }

    final sections = <(String, CategoryType, List<FinCategory>)>[
      for (final type in [CategoryType.expense, CategoryType.income]) ...[
        for (final g in fin.catalog.groupsOf(type))
          if (byGroup[g.id] case final list?)
            (g.name, type, list..sort(byName)),
        for (final e in loose.entries)
          if (e.value.first.type == type)
            (
              '${e.value.first.group} (нет в справочнике)',
              type,
              e.value..sort(byName),
            ),
      ],
    ];
    return _list([
      for (final (title, type, items) in sections) ...[
        _groupHeader(context, title, type),
        for (final c in items) _categoryTile(context, c),
      ],
    ]);
  }

  Widget _groupHeader(BuildContext context, String title, CategoryType type) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$title · ${type == CategoryType.income ? 'доходы' : 'расходы'}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _categoryTile(BuildContext context, FinCategory c) => ListTile(
    leading: Icon(
      c.type == CategoryType.income ? Icons.trending_up : Icons.trending_down,
      color: c.type == CategoryType.income
          ? operationTypeColors[OperationType.income]
          : operationTypeColors[OperationType.expense],
    ),
    title: Text(
      c.name,
      style: c.hidden ? const TextStyle(color: Colors.grey) : null,
    ),
    subtitle: Text(
      [
        _target(fin, c.directionId, c.allocationKeyId),
        if (c.kind != CategoryKind.current) c.kind.title,
        if (c.hidden) 'скрыта',
      ].where((p) => p.isNotEmpty).join(' · '),
    ),
    onTap: () => editCategory(context, fin, c),
  );
}

class _GroupsTab extends StatelessWidget {
  final FinanceProvider fin;
  const _GroupsTab(this.fin);

  @override
  Widget build(BuildContext context) {
    return _list([
      for (final type in [CategoryType.expense, CategoryType.income])
        for (final g in fin.catalog.groupsOf(type))
          ListTile(
            leading: Icon(
              type == CategoryType.income
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: type == CategoryType.income
                  ? operationTypeColors[OperationType.income]
                  : operationTypeColors[OperationType.expense],
            ),
            title: Text(
              g.name,
              style: g.hidden ? const TextStyle(color: Colors.grey) : null,
            ),
            subtitle: Text(
              [
                type == CategoryType.income ? 'доходы' : 'расходы',
                'статей: ${fin.groupUsages(g.id)}',
                'порядок ${g.sortOrder}',
                if (g.hidden) 'скрыта',
              ].join(' · '),
            ),
            onTap: () => editCategoryGroup(context, fin, g),
          ),
    ], empty: 'Групп нет');
  }
}

String _target(FinanceProvider fin, String? directionId, String? keyId) {
  if (directionId != null) {
    return fin.catalog.directions[directionId]?.name ?? '';
  }
  if (keyId != null) return 'ключ «${fin.catalog.keys[keyId]?.name ?? ''}»';
  return '';
}

class _CounterpartiesTab extends StatelessWidget {
  final FinanceProvider fin;
  const _CounterpartiesTab(this.fin);

  @override
  Widget build(BuildContext context) {
    final items = [...fin.counterparties]
      ..sort((a, b) => a.name.compareTo(b.name));
    return _list([
      for (final c in items)
        ListTile(
          title: Text(c.name),
          subtitle: Text(
            [
              c.kind.title,
              ?c.inn,
              ?c.phone,
              if (c.employeeId != null)
                'сотрудник: ${fin.employees[c.employeeId]?.fullName ?? '—'}',
            ].join(' · '),
          ),
          onTap: () => editCounterparty(context, fin, c),
        ),
    ]);
  }
}

class _AssetsTab extends StatelessWidget {
  final FinanceProvider fin;
  const _AssetsTab(this.fin);

  @override
  Widget build(BuildContext context) {
    final items = [...fin.assets]..sort((a, b) => a.name.compareTo(b.name));
    return _list([
      for (final a in items)
        ListTile(
          title: Text(
            a.name,
            style: a.disposedOn != null
                ? const TextStyle(color: Colors.grey)
                : null,
          ),
          subtitle: Text(
            [
              a.kind.title,
              if (a.year != null) '${a.year} г.',
              if (a.quantity != 1) '${a.quantity} шт.',
              _target(fin, a.directionId, a.allocationKeyId),
              if (a.disposedOn != null) 'выбыло ${_day(a.disposedOn)}',
            ].where((p) => p.isNotEmpty).join(' · '),
          ),
          trailing: a.referenceValue == null
              ? null
              : Text(_rub(a.referenceValue!)),
          onTap: () => editAsset(context, fin, a),
        ),
    ]);
  }
}

class _DirectionsTab extends StatelessWidget {
  final FinanceProvider fin;
  const _DirectionsTab(this.fin);

  @override
  Widget build(BuildContext context) {
    String shares(AllocationPeriod p) => [
      for (final MapEntry(key: id, value: share) in p.shares.entries)
        '${fin.catalog.directions[id]?.name ?? '—'} $share %',
    ].join(', ');
    return _list([
      for (final d in fin.directions)
        ListTile(
          leading: const Icon(Icons.call_split),
          title: Text(d.name),
          subtitle: d.overhead ? const Text('Накладные') : null,
          onTap: () => editDirection(context, fin, d),
        ),
      for (final k in fin.allocationKeys)
        ListTile(
          leading: const Icon(Icons.pie_chart_outline),
          title: Text('Ключ «${k.name}»'),
          subtitle: Text(
            [
              for (final p in [
                ...k.periods,
              ]..sort((a, b) => b.validFrom.compareTo(a.validFrom)))
                'с ${_day(p.validFrom)}: ${shares(p)}',
            ].join('\n'),
          ),
          onTap: () => editKey(context, fin, k),
        ),
    ]);
  }
}

// ----------------------------------------------------------- окна правки

/// Общее окно правки справочника: поля, «Удалить» (если запись есть),
/// «Сохранить». [save] возвращает true, если записано.
class _EditDialog extends StatefulWidget {
  final String title;
  final List<Widget> Function(StateSetter setState) fields;
  final Future<bool> Function() save;
  final Future<bool> Function()? delete;
  final FinanceProvider fin;

  const _EditDialog({
    required this.title,
    required this.fields,
    required this.save,
    required this.fin,
    this.delete,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  String? _problem;
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = ok ? null : widget.fin.lastProblem;
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final delete = widget.delete;
    return AppDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields(setState)) ...[f, gap],
              if (_problem case final p?)
                Text(
                  p,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (delete != null)
          TextButton(
            onPressed: _busy ? null : () => _run(delete),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _run(widget.save),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController c,
  String label, {
  TextInputType? keyboard,
  String? hint,
}) => TextField(
  controller: c,
  keyboardType: keyboard,
  decoration: InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
    isDense: true,
  ),
);

Widget _dateField(
  BuildContext context,
  String label,
  DateTime? value,
  ValueChanged<DateTime?> onChanged,
) => InkWell(
  onTap: () async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  },
  child: InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: value == null
          ? const Icon(Icons.calendar_today, size: 18)
          : IconButton(
              tooltip: 'Очистить',
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => onChanged(null),
            ),
    ),
    child: Text(value == null ? '—' : _day(value)),
  ),
);

/// Куда относить: направление, ключ или ничего ([allowNone]).
class _TargetValue {
  final String? directionId;
  final String? keyId;
  const _TargetValue([this.directionId, this.keyId]);
  @override
  bool operator ==(Object other) =>
      other is _TargetValue &&
      other.directionId == directionId &&
      other.keyId == keyId;
  @override
  int get hashCode => Object.hash(directionId, keyId);
}

Widget _targetChoice(
  FinanceProvider fin,
  _TargetValue value,
  ValueChanged<_TargetValue> onChanged, {
  required String noneLabel,
}) => ChoiceGroup<_TargetValue>(
  label: 'Направление',
  options: [
    ChoiceOption(const _TargetValue(), noneLabel, const Color(0xFF757575)),
    for (final d in fin.directions)
      ChoiceOption(_TargetValue(d.id), d.name, const Color(0xFF5D4037)),
    for (final k in fin.allocationKeys)
      ChoiceOption(
        _TargetValue(null, k.id),
        'Ключ «${k.name}»',
        const Color(0xFFB26A00),
      ),
  ],
  value: value,
  onChanged: onChanged,
);

int? _kopecks(TextEditingController c) =>
    c.text.trim().isEmpty ? 0 : parseRub(c.text);

String? _text(TextEditingController c) =>
    c.text.trim().isEmpty ? null : c.text.trim();

Future<void> editAccount(
  BuildContext context,
  FinanceProvider fin, [
  FinAccount? a,
]) async {
  final name = TextEditingController(text: a?.name ?? '');
  final opening = TextEditingController(
    text: a == null || a.openingBalance == 0 ? '' : formatRub(a.openingBalance),
  );
  var kind = a?.kind ?? AccountKind.cash;
  DateTime? openingDate = a?.openingDate;
  var closed = a?.closed ?? false;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: a == null ? 'Новый кошелёк' : 'Кошелёк',
      fields: (setState) => [
        _field(name, 'Название *'),
        ChoiceGroup<AccountKind>(
          label: 'Вид',
          options: [
            for (final k in AccountKind.values)
              ChoiceOption(k, k.title, const Color(0xFF00695C)),
          ],
          value: kind,
          onChanged: (v) => setState(() => kind = v),
        ),
        Row(
          children: [
            Expanded(
              child: _field(
                opening,
                'Начальный остаток, ₽',
                keyboard: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField(
                context,
                'На начало дня',
                openingDate,
                (v) => setState(() => openingDate = v),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Закрыт (не предлагать в новых операциях)'),
          value: closed,
          onChanged: (v) => setState(() => closed = v),
        ),
      ],
      save: () async {
        final balance = _kopecks(opening);
        if (balance == null) {
          return fin.reject('Начальный остаток — не сумма');
        }
        return fin.saveAccount(
          FinAccount(
            id: a?.id ?? fin.newId(),
            name: name.text.trim(),
            kind: kind,
            openingBalance: balance,
            openingDate: openingDate,
            employeeId: a?.employeeId,
            closed: closed,
            sortOrder: a?.sortOrder ?? fin.accounts.length,
          ),
          before: a,
        );
      },
      delete: a == null
          ? null
          : () => fin.deleteCatalogItem('fin_accounts', a.id),
    ),
  );
}

Future<void> editDebt(
  BuildContext context,
  FinanceProvider fin, [
  FinDebt? d,
]) async {
  final opening = TextEditingController(
    text: d == null || d.openingBalance == 0 ? '' : formatRub(d.openingBalance),
  );
  final notes = TextEditingController(text: d?.notes ?? '');
  var kind = d?.kind ?? DebtKind.received;
  DateTime? openingDate = d?.openingDate;
  var closed = d?.closed ?? false;
  String? counterpartyId = d?.counterpartyId;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: d == null ? 'Новый займ' : 'Займ',
      fields: (setState) => [
        SearchPicker<Counterparty>(
          label: 'Контрагент *',
          icon: Icons.person_outline,
          items: fin.counterparties,
          nameOf: (c) => c.name,
          selected: fin.catalog.counterparties[counterpartyId],
          onSelected: (c) => setState(() => counterpartyId = c?.id),
          onCreate: (name) async {
            final c = Counterparty(
              id: fin.newId(),
              name: name,
              kind: CounterpartyKind.person,
            );
            return await fin.saveCounterparty(c) ? c : null;
          },
        ),
        ChoiceGroup<DebtKind>(
          label: 'Вид',
          options: [
            for (final k in DebtKind.values)
              ChoiceOption(k, k.title, const Color(0xFF6A1B9A)),
          ],
          value: kind,
          onChanged: (v) => setState(() => kind = v),
        ),
        Row(
          children: [
            Expanded(
              child: _field(
                opening,
                'Остаток на дату, ₽',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField(
                context,
                'Дата остатка',
                openingDate,
                (v) => setState(() => openingDate = v),
              ),
            ),
          ],
        ),
        _field(notes, 'Примечание'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Закрыт'),
          value: closed,
          onChanged: (v) => setState(() => closed = v),
        ),
      ],
      save: () async {
        final balance = _kopecks(opening);
        if (balance == null) return fin.reject('Остаток — не сумма');
        return fin.saveDebt(
          FinDebt(
            id: d?.id ?? fin.newId(),
            counterpartyId: counterpartyId ?? '',
            kind: kind,
            openingBalance: balance,
            openingDate: openingDate,
            closed: closed,
            notes: _text(notes),
          ),
          before: d,
        );
      },
      delete: d == null ? null : () => fin.deleteCatalogItem('fin_debts', d.id),
    ),
  );
}

Future<void> editCategory(
  BuildContext context,
  FinanceProvider fin, [
  FinCategory? c,
]) async {
  final name = TextEditingController(text: c?.name ?? '');
  var type = c?.type ?? CategoryType.expense;
  var groupId = c == null ? null : fin.catalog.groupOf(c)?.id;
  var kind = c?.kind ?? CategoryKind.current;
  var target = _TargetValue(c?.directionId, c?.allocationKeyId);
  var tax = c?.inTaxBook ?? true;
  var hidden = c?.hidden ?? false;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: c == null ? 'Новая статья' : 'Статья',
      fields: (setState) => [
        ChoiceGroup<CategoryType>(
          label: 'Тип',
          options: [
            ChoiceOption(
              CategoryType.expense,
              'Расход',
              operationTypeColors[OperationType.expense]!,
            ),
            ChoiceOption(
              CategoryType.income,
              'Доход',
              operationTypeColors[OperationType.income]!,
            ),
          ],
          value: type,
          onChanged: (v) => setState(() {
            type = v;
            if (fin.catalog.groups[groupId]?.type != v) groupId = null;
          }),
        ),
        _field(name, 'Название *'),
        AppDropdown<String?>(
          labelText: 'Группа *',
          value: groupId,
          items: [
            for (final g in fin.catalog.groupsOf(type))
              if (!g.hidden || g.id == groupId)
                DropdownMenuItem(value: g.id, child: Text(g.name)),
            const DropdownMenuItem(
              value: _newGroup,
              child: Text('+ Новая группа…'),
            ),
          ],
          onChanged: (v) async {
            if (v != _newGroup) {
              setState(() => groupId = v);
              return;
            }
            final created = await editCategoryGroup(context, fin, null, type);
            setState(() => groupId = created?.id ?? groupId);
          },
        ),
        _targetChoice(
          fin,
          target,
          (v) => setState(() => target = v),
          noneLabel: 'Не задано',
        ),
        ChoiceGroup<CategoryKind>(
          label: 'Вид',
          options: [
            for (final k in CategoryKind.values)
              ChoiceOption(k, k.title, const Color(0xFF455A64)),
          ],
          value: kind,
          onChanged: (v) => setState(() => kind = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('В налоговую книгу'),
          value: tax,
          onChanged: (v) => setState(() => tax = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Скрыта (не предлагать в новых операциях)'),
          value: hidden,
          onChanged: (v) => setState(() => hidden = v),
        ),
      ],
      save: () => fin.saveCategory(
        FinCategory(
          id: c?.id ?? fin.newId(),
          type: type,
          groupId: groupId,
          group: fin.catalog.groups[groupId]?.name ?? '',
          name: name.text.trim(),
          directionId: target.directionId,
          allocationKeyId: target.keyId,
          kind: kind,
          inTaxBook: tax,
          hidden: hidden,
          sortOrder: c?.sortOrder ?? fin.categories.length,
        ),
      ),
      delete: c == null
          ? null
          : () => fin.deleteCatalogItem('fin_categories', c.id),
    ),
  );
}

/// Пункт «Новая группа…» в списке групп окна статьи.
const _newGroup = '\u0000new';

/// Окно группы статей; [type] — вид новой группы. Возвращает записанную
/// группу (null — не записано или удалено).
Future<FinCategoryGroup?> editCategoryGroup(
  BuildContext context,
  FinanceProvider fin, [
  FinCategoryGroup? g,
  CategoryType? type,
]) async {
  final name = TextEditingController(text: g?.name ?? '');
  var kind = g?.type ?? type ?? CategoryType.expense;
  final order = TextEditingController(
    text: '${g?.sortOrder ?? fin.catalog.groupsOf(kind).length + 1}',
  );
  var hidden = g?.hidden ?? false;
  final used = g == null ? 0 : fin.groupUsages(g.id);
  FinCategoryGroup? saved;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: g == null ? 'Новая группа статей' : 'Группа статей',
      fields: (setState) => [
        if (used == 0)
          ChoiceGroup<CategoryType>(
            label: 'Для статей',
            options: [
              ChoiceOption(
                CategoryType.expense,
                'Расход',
                operationTypeColors[OperationType.expense]!,
              ),
              ChoiceOption(
                CategoryType.income,
                'Доход',
                operationTypeColors[OperationType.income]!,
              ),
            ],
            value: kind,
            onChanged: (v) => setState(() => kind = v),
          )
        else
          Text(
            '${kind == CategoryType.income ? 'Доходы' : 'Расходы'} · '
            'статей в группе: $used. Новое название перейдёт во все.',
          ),
        _field(name, 'Название *', hint: 'например, «04. Техника»'),
        _field(
          order,
          'Порядок в списках',
          keyboard: TextInputType.number,
          hint: 'меньше — выше',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Скрыта (не предлагать для новых статей)'),
          value: hidden,
          onChanged: (v) => setState(() => hidden = v),
        ),
      ],
      save: () async {
        final sortOrder = int.tryParse(order.text.trim());
        if (sortOrder == null) return fin.reject('Порядок — целое число');
        final group = FinCategoryGroup(
          id: g?.id ?? fin.newId(),
          type: kind,
          name: name.text.trim(),
          sortOrder: sortOrder,
          hidden: hidden,
        );
        final ok = await fin.saveCategoryGroup(group, before: g);
        if (ok) saved = group;
        return ok;
      },
      delete: g == null
          ? null
          : () => fin.deleteCatalogItem('fin_category_groups', g.id),
    ),
  );
  return saved;
}

Future<void> editCounterparty(
  BuildContext context,
  FinanceProvider fin, [
  Counterparty? c,
]) async {
  final name = TextEditingController(text: c?.name ?? '');
  final inn = TextEditingController(text: c?.inn ?? '');
  final phone = TextEditingController(text: c?.phone ?? '');
  final notes = TextEditingController(text: c?.notes ?? '');
  var kind = c?.kind ?? CounterpartyKind.supplier;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: c == null ? 'Новый контрагент' : 'Контрагент',
      fields: (setState) => [
        _field(name, 'Название *'),
        ChoiceGroup<CounterpartyKind>(
          label: 'Вид',
          options: [
            for (final k in CounterpartyKind.values)
              ChoiceOption(k, k.title, const Color(0xFF37474F)),
          ],
          value: kind,
          onChanged: (v) => setState(() => kind = v),
        ),
        Row(
          children: [
            Expanded(child: _field(inn, 'ИНН')),
            const SizedBox(width: 12),
            Expanded(child: _field(phone, 'Телефон')),
          ],
        ),
        _field(notes, 'Примечание'),
      ],
      save: () => fin.saveCounterparty(
        Counterparty(
          id: c?.id ?? fin.newId(),
          name: name.text.trim(),
          kind: kind,
          inn: _text(inn),
          phone: _text(phone),
          employeeId: c?.employeeId,
          notes: _text(notes),
        ),
      ),
      delete: c == null
          ? null
          : () => fin.deleteCatalogItem('counterparties', c.id),
    ),
  );
}

Future<void> editAsset(
  BuildContext context,
  FinanceProvider fin, [
  Asset? a,
]) async {
  final name = TextEditingController(text: a?.name ?? '');
  final year = TextEditingController(text: a?.year?.toString() ?? '');
  final quantity = TextEditingController(text: '${a?.quantity ?? 1}');
  final value = TextEditingController(
    text: a?.referenceValue == null ? '' : formatRub(a!.referenceValue!),
  );
  final notes = TextEditingController(text: a?.notes ?? '');
  var kind = a?.kind ?? AssetKind.machinery;
  var target = _TargetValue(a?.directionId, a?.allocationKeyId);
  DateTime? disposed = a?.disposedOn;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: a == null ? 'Новое имущество' : 'Имущество',
      fields: (setState) => [
        _field(name, 'Название *'),
        ChoiceGroup<AssetKind>(
          label: 'Вид',
          options: [
            for (final k in AssetKind.values)
              ChoiceOption(k, k.title, const Color(0xFF4E342E)),
          ],
          value: kind,
          onChanged: (v) => setState(() => kind = v),
        ),
        Row(
          children: [
            Expanded(
              child: _field(year, 'Год', keyboard: TextInputType.number),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                quantity,
                'Количество',
                keyboard: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _field(
                value,
                'Справочная стоимость, ₽',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        _targetChoice(
          fin,
          target,
          (v) => setState(() => target = v),
          noneLabel: 'Не задано',
        ),
        _dateField(
          context,
          'Выбыло (продано, списано)',
          disposed,
          (v) => setState(() => disposed = v),
        ),
        _field(notes, 'Примечание'),
      ],
      save: () async {
        final reference = value.text.trim().isEmpty
            ? null
            : parseRub(value.text);
        if (value.text.trim().isNotEmpty && reference == null) {
          return fin.reject('Стоимость — не сумма');
        }
        return fin.saveAsset(
          Asset(
            id: a?.id ?? fin.newId(),
            name: name.text.trim(),
            kind: kind,
            year: int.tryParse(year.text.trim()),
            quantity: int.tryParse(quantity.text.trim()) ?? 1,
            referenceValue: reference,
            valuedOn: a?.valuedOn,
            directionId: target.directionId,
            allocationKeyId: target.keyId,
            cadastralNumber: a?.cadastralNumber,
            areaHa: a?.areaHa,
            cadastralValue: a?.cadastralValue,
            disposedOn: disposed,
            disposalReason: a?.disposalReason,
            notes: _text(notes),
          ),
        );
      },
      delete: a == null
          ? null
          : () => fin.deleteCatalogItem('fin_assets', a.id),
    ),
  );
}

Future<void> editDirection(
  BuildContext context,
  FinanceProvider fin, [
  FinDirection? d,
]) async {
  final name = TextEditingController(text: d?.name ?? '');
  var overhead = d?.overhead ?? false;
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: d == null ? 'Новое направление' : 'Направление',
      fields: (setState) => [
        _field(name, 'Название *'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Накладные (общехозяйственные)'),
          value: overhead,
          onChanged: (v) => setState(() => overhead = v),
        ),
      ],
      save: () => fin.saveDirection(
        FinDirection(
          id: d?.id ?? fin.newId(),
          name: name.text.trim(),
          overhead: overhead,
          sortOrder: d?.sortOrder ?? fin.directions.length,
        ),
      ),
    ),
  );
}

/// Ключ распределения: название и новые доли с даты (прежние версии
/// остаются — операции до этой даты считаются по прежним долям).
Future<void> editKey(
  BuildContext context,
  FinanceProvider fin,
  AllocationKey k,
) async {
  final name = TextEditingController(text: k.name);
  final latest = [...k.periods]
    ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
  final current = latest.isEmpty ? null : latest.last;
  final shares = {
    for (final d in fin.directions)
      d.id: TextEditingController(text: '${current?.shares[d.id] ?? 0}'),
  };
  DateTime from = current?.validFrom ?? calendarDay(DateTime.now());
  await showAppDialog<bool>(
    context: context,
    builder: (context) => _EditDialog(
      fin: fin,
      title: 'Ключ распределения',
      fields: (setState) => [
        _field(name, 'Название *'),
        _dateField(
          context,
          'Доли действуют с',
          from,
          (v) => setState(() => from = v ?? from),
        ),
        for (final d in fin.directions)
          _field(shares[d.id]!, '${d.name}, %', keyboard: TextInputType.number),
      ],
      save: () {
        final period = AllocationPeriod(
          validFrom: calendarDay(from),
          shares: {
            for (final MapEntry(key: id, value: c) in shares.entries)
              if ((int.tryParse(c.text.trim()) ?? 0) != 0)
                id: int.tryParse(c.text.trim()) ?? 0,
          },
        );
        return fin.saveAllocationKey(
          AllocationKey(
            id: k.id,
            name: name.text.trim(),
            periods: [
              for (final p in k.periods)
                if (p.validFrom != period.validFrom) p,
              period,
            ],
          ),
        );
      },
    ),
  );
}
