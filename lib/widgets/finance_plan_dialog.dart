// lib/widgets/finance_plan_dialog.dart
//
// Окно плана платёжного календаря (8Б.4): поступление или платёж, сумма,
// первый день, повтор и до какого дня, кошелёк, статья, контрагент, что.
// Новый или изменённый план записывает FinanceProvider.savePlan.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../providers/finance_provider.dart';
import 'adaptive_dialog.dart';
import 'choice_buttons.dart';
import 'common_widgets.dart';
import 'finance_operation_dialog.dart';

/// Новый план ([plan] == null) или правка; true — записано.
Future<bool> showPlanDialog(
  BuildContext context,
  FinanceProvider finance, {
  FinPlan? plan,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (_) => _PlanDialog(finance: finance, plan: plan),
    ) ==
    true;

class _PlanDialog extends StatefulWidget {
  final FinanceProvider finance;
  final FinPlan? plan;

  const _PlanDialog({required this.finance, this.plan});

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  FinanceProvider get fin => widget.finance;

  late OperationType _type = widget.plan?.type ?? OperationType.expense;
  late final _amount = TextEditingController(
    text: widget.plan == null ? '' : formatRub(widget.plan!.amount),
  );
  late final _description = TextEditingController(
    text: widget.plan?.description ?? '',
  );
  late DateTime _start = widget.plan?.startDate ?? calendarDay(DateTime.now());
  late PlanRepeat _repeat = widget.plan?.repeat ?? PlanRepeat.monthly;
  late DateTime? _until = widget.plan?.untilDate;
  late String? _accountId = widget.plan?.accountId;
  late String? _categoryId = widget.plan?.categoryId;
  late String? _counterpartyId = widget.plan?.counterpartyId;
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(DateTime.now().year + 10, 12, 31),
  );

  Future<void> _save() async {
    final amount = parseRub(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _problem = 'Введите сумму');
      return;
    }
    final text = _description.text.trim();
    final plan = FinPlan(
      id: widget.plan?.id ?? fin.newId(),
      type: _type,
      amount: amount,
      startDate: _start,
      repeat: _repeat,
      untilDate: _repeat == PlanRepeat.none ? null : _until,
      accountId: _accountId,
      categoryId: _categoryId,
      counterpartyId: _counterpartyId,
      description: text.isEmpty ? null : text,
      skipped: widget.plan?.skipped ?? const {},
      closed: widget.plan?.closed ?? false,
    );
    setState(() => _saving = true);
    final ok = await fin.savePlan(plan);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _problem = ok ? null : fin.lastProblem;
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('dd.MM.yyyy');
    final wanted = _type == OperationType.income
        ? CategoryType.income
        : CategoryType.expense;
    final categories = [
      for (final c in fin.categories)
        if (c.type == wanted && (!c.hidden || c.id == _categoryId)) c,
    ];
    const gap = SizedBox(height: 14);
    return AppDialog(
      title: Text(widget.plan == null ? 'Новый план' : 'План'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceGroup<OperationType>(
                label: 'Вид',
                options: [
                  ChoiceOption(
                    OperationType.expense,
                    'Платёж',
                    operationTypeColors[OperationType.expense]!,
                  ),
                  ChoiceOption(
                    OperationType.income,
                    'Поступление',
                    operationTypeColors[OperationType.income]!,
                  ),
                ],
                value: _type,
                onChanged: (v) => setState(() {
                  if (v != _type) _categoryId = null;
                  _type = v;
                }),
              ),
              gap,
              TextField(
                controller: _amount,
                autofocus: widget.plan == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Сумма, ₽ *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              gap,
              ChoiceGroup<PlanRepeat>(
                label: 'Повтор',
                options: [
                  for (final r in PlanRepeat.values)
                    ChoiceOption(r, r.title, const Color(0xFF00695C)),
                ],
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
              gap,
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await _pick(_start);
                      if (d != null) setState(() => _start = d);
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _repeat == PlanRepeat.none
                          ? 'День: ${day.format(_start)}'
                          : 'Первый раз: ${day.format(_start)}',
                    ),
                  ),
                  if (_repeat != PlanRepeat.none)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final d = await _pick(_until ?? _start);
                        if (d != null) setState(() => _until = d);
                      },
                      icon: const Icon(Icons.event_busy, size: 18),
                      label: Text(
                        _until == null
                            ? 'Бессрочно'
                            : 'До ${day.format(_until!)}',
                      ),
                    ),
                  if (_repeat != PlanRepeat.none && _until != null)
                    TextButton(
                      onPressed: () => setState(() => _until = null),
                      child: const Text('Бессрочно'),
                    ),
                ],
              ),
              gap,
              AppDropdown<String?>(
                labelText: 'Кошелёк',
                value: _accountId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Не указан'),
                  ),
                  for (final a in fin.accounts)
                    if (!a.closed || a.id == _accountId)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              gap,
              SearchPicker<FinCategory>(
                key: ValueKey('plan-category-$wanted'),
                label: 'Статья',
                icon: Icons.category_outlined,
                items: categories,
                nameOf: (c) => c.name,
                detailOf: fin.groupName,
                selected: categories
                    .where((c) => c.id == _categoryId)
                    .firstOrNull,
                onSelected: (c) => setState(() => _categoryId = c?.id),
              ),
              gap,
              SearchPicker<Counterparty>(
                key: const ValueKey('plan-counterparty'),
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
              ),
              gap,
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Что (аренда земли, кредит, налог…)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 10),
                Text(
                  _problem!,
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
          child: Text(widget.plan == null ? 'Добавить' : 'Сохранить'),
        ),
      ],
    );
  }
}
