// lib/screens/finance_quick_screen.dart
//
// Быстрый ввод расхода или дохода с телефона (8.6): сумма крупно,
// последние статьи и контрагенты — кнопками сверху, кошелёк — последний
// использованный, направление — по статье (поменять можно). Переводы и
// займы — в полном окне («Подробно»). Работает без сети: запись уходит на
// сервер при синхронизации.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../providers/finance_provider.dart';
import '../widgets/choice_buttons.dart';
import '../widgets/finance_operation_dialog.dart';

/// Открыть быстрый ввод; true — операция записана.
Future<bool> openQuickOperation(
  BuildContext context,
  FinanceProvider finance, {
  OperationType type = OperationType.expense,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FinanceQuickScreen(finance: finance, type: type),
      ),
    ) ==
    true;

class FinanceQuickScreen extends StatefulWidget {
  final FinanceProvider finance;

  /// Расход или доход вначале.
  final OperationType type;

  const FinanceQuickScreen({
    super.key,
    required this.finance,
    this.type = OperationType.expense,
  });

  @override
  State<FinanceQuickScreen> createState() => _FinanceQuickScreenState();
}

class _FinanceQuickScreenState extends State<FinanceQuickScreen> {
  FinanceProvider get fin => widget.finance;

  late OperationType _type = widget.type;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _counterpartyId;
  String? _directionId;
  String? _keyId;
  DateTime _date = calendarDay(DateTime.now());
  String? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _accountId = fin.lastAccount(_type);
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setType(OperationType type) => setState(() {
    if (type == _type) return;
    _type = type;
    _categoryId = null;
    _counterpartyId = null;
    _directionId = null;
    _keyId = null;
    _accountId = fin.lastAccount(type);
  });

  int? get _kopecks {
    final v = parseRub(_amount.text);
    return v == null || v <= 0 ? null : v;
  }

  Future<void> _save() async {
    final amount = _kopecks;
    if (amount == null) {
      setState(() => _problem = 'Введите сумму');
      return;
    }
    if (_accountId == null) {
      setState(() => _problem = 'Выберите кошелёк');
      return;
    }
    final description = _description.text.trim();
    final op = FinOperation(
      id: fin.newId(),
      date: _date,
      type: _type,
      amount: amount,
      accountId: _accountId!,
      categoryId: _categoryId,
      directionId: _directionId,
      allocationKeyId: _keyId,
      counterpartyId: _counterpartyId,
      description: description.isEmpty ? null : description,
    );
    setState(() => _saving = true);
    final ok = await fin.saveOperation(op);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _problem = ok ? null : fin.lastProblem;
    });
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _detailed() async {
    final ok = await showOperationDialog(context, fin, type: _type);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  /// Подпись раздела формы.
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _chips<T>(
    List<T> items,
    String Function(T) name,
    bool Function(T) selected,
    ValueChanged<T> onTap,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final item in items)
        ChoiceChip(
          label: Text(name(item)),
          selected: selected(item),
          onSelected: (_) => onTap(item),
        ),
    ],
  );

  String _byCategory() {
    final c = fin.catalog.categories[_categoryId];
    if (c?.directionId case final id?) {
      return 'По статье: ${fin.catalog.directions[id]?.name ?? '—'}';
    }
    if (c?.allocationKeyId case final id?) {
      return 'По статье: ключ «${fin.catalog.keys[id]?.name ?? '—'}»';
    }
    return 'По статье';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = operationTypeColors[_type]!;
    final wanted = _type == OperationType.income
        ? CategoryType.income
        : CategoryType.expense;
    final categories = [
      for (final c in fin.categories)
        if (c.type == wanted && (!c.hidden || c.id == _categoryId)) c,
    ];
    final recentCategories = fin.recentCategories(_type);
    final recentCounterparties = fin.recentCounterparties(
      _type,
      categoryId: _categoryId,
    );
    final amount = _kopecks;
    final directionLabel = _directionId != null
        ? fin.catalog.directions[_directionId]?.name ?? '—'
        : _keyId != null
        ? 'Ключ «${fin.catalog.keys[_keyId]?.name ?? '—'}»'
        : _byCategory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Быстрый ввод'),
        actions: [
          TextButton(onPressed: _detailed, child: const Text('Подробно')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  SegmentedButton<OperationType>(
                    segments: const [
                      ButtonSegment(
                        value: OperationType.expense,
                        label: Text('Расход'),
                        icon: Icon(Icons.remove),
                      ),
                      ButtonSegment(
                        value: OperationType.income,
                        label: Text('Доход'),
                        icon: Icon(Icons.add),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => _setType(s.single),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      suffixText: '₽',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ChoiceGroup<String?>(
                    label: 'Кошелёк',
                    options: [
                      for (final a in fin.accounts)
                        if (!a.closed)
                          ChoiceOption(a.id, a.name, const Color(0xFF00695C)),
                    ],
                    value: _accountId,
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  _label('Статья'),
                  if (recentCategories.isNotEmpty) ...[
                    _chips<FinCategory>(
                      recentCategories,
                      (c) => c.name,
                      (c) => c.id == _categoryId,
                      (c) => setState(() => _categoryId = c.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SearchPicker<FinCategory>(
                    key: ValueKey('quick-category-$wanted'),
                    label: recentCategories.isEmpty
                        ? 'Статья'
                        : 'Другая статья',
                    icon: Icons.search,
                    items: categories,
                    nameOf: (c) => c.name,
                    detailOf: fin.groupName,
                    selected: categories
                        .where((c) => c.id == _categoryId)
                        .firstOrNull,
                    onSelected: (c) => setState(() => _categoryId = c?.id),
                  ),
                  _label('Контрагент (необязательно)'),
                  if (recentCounterparties.isNotEmpty) ...[
                    _chips<Counterparty>(
                      recentCounterparties,
                      (c) => c.name,
                      (c) => c.id == _counterpartyId,
                      (c) => setState(
                        () => _counterpartyId = _counterpartyId == c.id
                            ? null
                            : c.id,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SearchPicker<Counterparty>(
                    key: const ValueKey('quick-counterparty'),
                    label: 'Найти или добавить',
                    icon: Icons.search,
                    items: fin.counterparties,
                    nameOf: (c) => c.name,
                    detailOf: (c) => c.kind.title,
                    selected: fin.catalog.counterparties[_counterpartyId],
                    onSelected: (c) => setState(() => _counterpartyId = c?.id),
                    onCreate: (name) async {
                      final created = Counterparty(
                        id: fin.newId(),
                        name: name,
                        kind: _type == OperationType.income
                            ? CounterpartyKind.buyer
                            : CounterpartyKind.supplier,
                      );
                      return await fin.saveCounterparty(created)
                          ? created
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Что (необязательно)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Направление: $directionLabel'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text(_byCategory()),
                              selected: _directionId == null && _keyId == null,
                              onSelected: (_) => setState(() {
                                _directionId = null;
                                _keyId = null;
                              }),
                            ),
                            for (final d in fin.directions)
                              ChoiceChip(
                                label: Text(d.name),
                                selected: _directionId == d.id,
                                onSelected: (_) => setState(() {
                                  _directionId = d.id;
                                  _keyId = null;
                                }),
                              ),
                            for (final k in fin.allocationKeys)
                              ChoiceChip(
                                label: Text('Ключ «${k.name}»'),
                                selected: _keyId == k.id,
                                onSelected: (_) => setState(() {
                                  _keyId = k.id;
                                  _directionId = null;
                                }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _date == calendarDay(DateTime.now())
                          ? 'Сегодня, ${DateFormat('dd.MM.yyyy').format(_date)}'
                          : DateFormat('dd.MM.yyyy').format(_date),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDate,
                  ),
                  if (_problem case final p?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        p,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    amount == null
                        ? 'Записать ${_type.title.toLowerCase()}'
                        : 'Записать ${_type.title.toLowerCase()} '
                              '${formatRub(amount)} ₽',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
