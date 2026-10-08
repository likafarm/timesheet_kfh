// lib/widgets/finance_operation_dialog.dart
//
// Окно операции финансов (8.5.3): вид, кошелёк и направление — кнопками
// (ChoiceGroup, решение владельца 2026-10-06), статья и контрагент — поле
// с поиском (их десятки), новый контрагент — прямо из поля. Проверки —
// FinanceProvider (правила домена, закрытые месяцы).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../providers/finance_provider.dart';
import 'adaptive_dialog.dart';
import 'choice_buttons.dart';

/// Открыть окно операции: новой ([operation] = null, [template] — образец
/// для «Повторить») или изменения. true — записано.
Future<bool> showOperationDialog(
  BuildContext context,
  FinanceProvider finance, {
  FinOperation? operation,
  FinOperation? template,
  OperationType? type,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (_) => FinanceOperationDialog(
        finance: finance,
        operation: operation,
        template: template,
        type: type,
      ),
    ) ==
    true;

/// Цвета видов операции.
const operationTypeColors = {
  OperationType.expense: Color(0xFFC62828),
  OperationType.income: Color(0xFF2E7D32),
  OperationType.transfer: Color(0xFF1565C0),
  OperationType.debt: Color(0xFF6A1B9A),
};

const _accountColor = Color(0xFF00695C);
const _directionColor = Color(0xFF5D4037);
const _keyColor = Color(0xFFB26A00);
const _neutral = Color(0xFF757575);

class FinanceOperationDialog extends StatefulWidget {
  final FinanceProvider finance;
  final FinOperation? operation;
  final FinOperation? template;

  /// Вид новой операции (по пункту меню «Доходы»/«Расходы»).
  final OperationType? type;

  const FinanceOperationDialog({
    super.key,
    required this.finance,
    this.operation,
    this.template,
    this.type,
  });

  @override
  State<FinanceOperationDialog> createState() => _FinanceOperationDialogState();
}

/// Куда отнести: по статье, направление или ключ.
class _Target {
  final String? directionId;
  final String? keyId;
  const _Target({this.directionId, this.keyId});

  @override
  bool operator ==(Object other) =>
      other is _Target &&
      other.directionId == directionId &&
      other.keyId == keyId;

  @override
  int get hashCode => Object.hash(directionId, keyId);
}

class _FinanceOperationDialogState extends State<FinanceOperationDialog> {
  FinanceProvider get fin => widget.finance;
  FinOperation? get editing => widget.operation;

  late OperationType _type;
  late DateTime _date;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  _Target _target = const _Target();
  String? _assetId;
  String? _counterpartyId;
  String? _debtId;
  DebtMove? _debtMove;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  final _season = TextEditingController();
  final _notes = TextEditingController();
  String? _amountError;
  String? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = editing ?? widget.template;
    _type = source?.type ?? widget.type ?? OperationType.expense;
    _date = editing?.date ?? calendarDay(DateTime.now());
    _accountId =
        source?.accountId ??
        fin.accounts.where((a) => !a.closed).firstOrNull?.id;
    _toAccountId = source?.toAccountId;
    _categoryId = source?.categoryId;
    _target = _Target(
      directionId: source?.directionId,
      keyId: source?.allocationKeyId,
    );
    _assetId = source?.assetId;
    _counterpartyId = source?.counterpartyId;
    _debtId = source?.debtId;
    _debtMove = source?.debtMove;
    if (source != null) {
      _amount.text = formatRub(source.amount);
      _description.text = source.description ?? '';
      _quantity.text = source.quantity == null
          ? ''
          : NumberFormat('0.###', 'ru').format(source.quantity);
      _unit.text = source.unit ?? '';
      _season.text = source.season?.toString() ?? '';
      _notes.text = source.notes ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _amount,
      _description,
      _quantity,
      _unit,
      _season,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasCategory =>
      _type == OperationType.expense || _type == OperationType.income;

  String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final amount = parseRub(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Введите сумму больше нуля');
      return;
    }
    final account = _accountId;
    if (account == null) {
      setState(() => _problem = 'Выберите кошелёк');
      return;
    }
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.').replaceAll(' ', ''),
    );
    final op = FinOperation(
      id: editing?.id ?? fin.newId(),
      date: _date,
      type: _type,
      amount: amount,
      accountId: account,
      toAccountId: _type == OperationType.transfer ? _toAccountId : null,
      categoryId: _hasCategory ? _categoryId : null,
      directionId: _hasCategory ? _target.directionId : null,
      allocationKeyId: _hasCategory ? _target.keyId : null,
      assetId: _type == OperationType.expense ? _assetId : null,
      season: int.tryParse(_season.text.trim()),
      counterpartyId: _type == OperationType.transfer ? null : _counterpartyId,
      employeeId: editing?.employeeId,
      debtId: _type == OperationType.debt ? _debtId : null,
      debtMove: _type == OperationType.debt ? _debtMove : null,
      description: _text(_description),
      quantity: quantity,
      unit: _text(_unit),
      tag: editing?.tag ?? widget.template?.tag,
      notes: _text(_notes),
      source: editing?.source ?? OperationSource.manual,
      sourceRef: editing?.sourceRef,
      createdBy: editing?.createdBy,
    );
    setState(() => _saving = true);
    final ok = await fin.saveOperation(op, before: editing);
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

  List<FinAccount> _accounts(String? keep) => [
    for (final a in fin.accounts)
      if (!a.closed || a.id == keep) a,
  ];

  Widget _accountChoice(String label, String? value, ValueChanged<String> on) =>
      ChoiceGroup<String?>(
        label: label,
        options: [
          for (final a in _accounts(value))
            ChoiceOption(a.id, a.name, _accountColor),
        ],
        value: value,
        onChanged: (v) => on(v!),
      );

  Widget _categoryField() {
    final wanted = _type == OperationType.income
        ? CategoryType.income
        : CategoryType.expense;
    final items = [
      for (final c in fin.categories)
        if (c.type == wanted && (!c.hidden || c.id == _categoryId)) c,
    ];
    return SearchPicker<FinCategory>(
      key: ValueKey('category-$wanted'),
      label: 'Статья *',
      icon: Icons.category_outlined,
      items: items,
      nameOf: (c) => c.name,
      detailOf: fin.groupName,
      selected: items.where((c) => c.id == _categoryId).firstOrNull,
      onSelected: (c) => setState(() => _categoryId = c?.id),
    );
  }

  Widget _targetChoice() {
    final category = fin.catalog.categories[_categoryId];
    String byCategory() {
      if (category?.directionId case final id?) {
        return 'По статье: ${fin.catalog.directions[id]?.name ?? '—'}';
      }
      if (category?.allocationKeyId case final id?) {
        return 'По статье: ключ «${fin.catalog.keys[id]?.name ?? '—'}»';
      }
      return 'По статье';
    }

    return ChoiceGroup<_Target>(
      label: 'Направление',
      options: [
        ChoiceOption(const _Target(), byCategory(), _neutral),
        for (final d in fin.directions)
          ChoiceOption(_Target(directionId: d.id), d.name, _directionColor),
        for (final k in fin.allocationKeys)
          ChoiceOption(_Target(keyId: k.id), 'Ключ «${k.name}»', _keyColor),
      ],
      value: _target,
      onChanged: (v) => setState(() => _target = v),
    );
  }

  Widget _counterpartyField() => SearchPicker<Counterparty>(
    key: const ValueKey('counterparty'),
    label: 'Контрагент',
    icon: Icons.storefront_outlined,
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
      return await fin.saveCounterparty(created) ? created : null;
    },
  );

  Widget _assetField() {
    final items = [
      for (final a in fin.assets)
        if (!a.disposedBy(_date) || a.id == _assetId) a,
    ];
    return SearchPicker<Asset>(
      key: const ValueKey('asset'),
      label: 'Техника, имущество',
      icon: Icons.agriculture_outlined,
      items: items,
      nameOf: (a) => a.name,
      detailOf: (a) => a.kind.title,
      selected: fin.catalog.assets[_assetId],
      onSelected: (a) => setState(() => _assetId = a?.id),
    );
  }

  Widget _debtFields() {
    final debt = fin.catalog.debts[_debtId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceGroup<String?>(
          label: 'Займ *',
          options: [
            for (final d in fin.debts)
              if (!d.closed || d.id == _debtId)
                ChoiceOption(
                  d.id,
                  fin.debtName(d.id),
                  operationTypeColors[OperationType.debt]!,
                ),
          ],
          value: _debtId,
          onChanged: (v) => setState(() {
            _debtId = v;
            final kind = fin.catalog.debts[v]?.kind;
            if (_debtMove?.debtKind != kind) _debtMove = null;
          }),
        ),
        if (debt != null) ...[
          const SizedBox(height: 12),
          ChoiceGroup<DebtMove?>(
            label: 'Что сделали *',
            options: [
              for (final m in DebtMove.values)
                if (m.debtKind == debt.kind)
                  ChoiceOption(
                    m,
                    m.title,
                    m.cashSign > 0
                        ? operationTypeColors[OperationType.income]!
                        : operationTypeColors[OperationType.expense]!,
                  ),
            ],
            value: _debtMove,
            onChanged: (v) => setState(() => _debtMove = v),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = editing == null ? 'Новая операция' : 'Операция';
    const gap = SizedBox(height: 14);
    return AppDialog(
      title: Text(title),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceGroup<OperationType>(
                label: 'Вид',
                options: [
                  for (final t in [
                    OperationType.expense,
                    OperationType.income,
                    // Оператор (8.8.4) вносит только расходы и доходы.
                    if (!fin.operator) ...[
                      OperationType.transfer,
                      OperationType.debt,
                    ],
                  ])
                    ChoiceOption(t, t.title, operationTypeColors[t]!),
                ],
                value: _type,
                onChanged: (v) => setState(() {
                  if (_type != v) _categoryId = null;
                  _type = v;
                }),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      autofocus: editing == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Сумма, ₽ *',
                        prefixIcon: const Icon(Icons.currency_ruble, size: 20),
                        errorText: _amountError,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 170,
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Дата',
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(DateFormat('dd.MM.yyyy').format(_date)),
                      ),
                    ),
                  ),
                ],
              ),
              gap,
              _accountChoice(
                _type == OperationType.transfer ? 'Откуда *' : 'Кошелёк *',
                _accountId,
                (v) => setState(() => _accountId = v),
              ),
              if (_type == OperationType.transfer) ...[
                gap,
                _accountChoice(
                  'Куда *',
                  _toAccountId,
                  (v) => setState(() => _toAccountId = v),
                ),
              ],
              if (_hasCategory) ...[
                gap,
                _categoryField(),
                gap,
                _targetChoice(),
                if (_type == OperationType.expense) ...[gap, _assetField()],
              ],
              if (_type == OperationType.debt) ...[gap, _debtFields()],
              if (_type != OperationType.transfer) ...[
                gap,
                _counterpartyField(),
              ],
              gap,
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Что (товар, услуга)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_hasCategory) ...[
                gap,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Количество',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Ед.',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _season,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Сезон урожая',
                          hintText: 'год',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              gap,
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Примечание',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_problem case final problem?) ...[
                gap,
                Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(editing == null ? 'Добавить' : 'Сохранить'),
        ),
      ],
    );
  }
}

/// Поле выбора из длинного списка с поиском по началу слов и подстроке;
/// пусто — ничего не выбрано. [onCreate] — «Добавить «текст»», если
/// ничего не нашлось.
class SearchPicker<T extends Object> extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final String Function(T) nameOf;
  final String Function(T)? detailOf;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final Future<T?> Function(String name)? onCreate;

  const SearchPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.nameOf,
    required this.selected,
    required this.onSelected,
    this.detailOf,
    this.onCreate,
  });

  @override
  State<SearchPicker<T>> createState() => _SearchPickerState<T>();
}

/// Вариант «добавить новое» в списке поиска.
class _Create {
  final String name;
  const _Create(this.name);
}

class _SearchPickerState<T extends Object> extends State<SearchPicker<T>> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.selected == null ? '' : widget.nameOf(widget.selected!),
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(SearchPicker<T> old) {
    super.didUpdateWidget(old);
    final name = widget.selected == null ? '' : widget.nameOf(widget.selected!);
    if (!_focus.hasFocus && _controller.text != name) _controller.text = name;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Iterable<Object> _options(TextEditingValue value) {
    final query = value.text.trim().toLowerCase().replaceAll('ё', 'е');
    String norm(String s) => s.toLowerCase().replaceAll('ё', 'е');
    final found = [
      for (final item in widget.items)
        if (query.isEmpty || norm(widget.nameOf(item)).contains(query)) item,
    ];
    found.sort((a, b) {
      final sa = norm(widget.nameOf(a)).startsWith(query) ? 0 : 1;
      final sb = norm(widget.nameOf(b)).startsWith(query) ? 0 : 1;
      return sa != sb ? sa - sb : widget.nameOf(a).compareTo(widget.nameOf(b));
    });
    final exact = found.any((i) => norm(widget.nameOf(i)) == query);
    return [
      ...found,
      if (widget.onCreate != null && query.isNotEmpty && !exact)
        _Create(value.text.trim()),
    ];
  }

  Future<void> _picked(Object option) async {
    if (option is _Create) {
      final created = await widget.onCreate!(option.name);
      if (created != null) {
        _controller.text = widget.nameOf(created);
        widget.onSelected(created);
      }
      return;
    }
    widget.onSelected(option as T);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Object>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: _options,
      displayStringForOption: (o) =>
          o is _Create ? o.name : widget.nameOf(o as T),
      onSelected: _picked,
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, size: 20),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    widget.onSelected(null);
                  },
                ),
        ),
        onChanged: (text) {
          // Текст поменяли руками — выбор снят, пока не выберут из списка.
          final selected = widget.selected;
          if (selected != null && widget.nameOf(selected) != text) {
            widget.onSelected(null);
          }
        },
        onSubmitted: (_) => onSubmit(),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 560),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final o = options.elementAt(i);
                if (o is _Create) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.add, size: 20),
                    title: Text('Добавить «${o.name}»'),
                    onTap: () => onSelected(o),
                  );
                }
                final item = o as T;
                return ListTile(
                  dense: true,
                  title: Text(widget.nameOf(item)),
                  subtitle: widget.detailOf == null
                      ? null
                      : Text(widget.detailOf!(item)),
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
