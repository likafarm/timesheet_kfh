// lib/screens/price_edition_screen.dart
//
// «Прайс-лист → Новая редакция» (этап 11.1): дата, с которой вводятся
// цены, и таблица всех продающихся товаров с ценами на эту дату — нужные
// меняются прямо в таблице. Записываются только изменённые цены, одной
// транзакцией; цена, уже начавшаяся в этот день, исправляется. Старые цены
// остаются — это история.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/price_list_provider.dart';

final _date = DateFormat('dd.MM.yyyy');

class PriceEditionScreen extends StatefulWidget {
  const PriceEditionScreen({super.key});

  @override
  State<PriceEditionScreen> createState() => _PriceEditionScreenState();
}

class _PriceEditionScreenState extends State<PriceEditionScreen> {
  late DateTime _from = addCalendarDays(calendarDay(DateTime.now()), 1);
  final _fields = <String, TextEditingController>{};
  String? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Поля — цены на [_from]; уже введённое сохраняется при смене даты.
  void _fill({bool keepTyped = false}) {
    final p = context.read<PriceListProvider>();
    for (final product in p.products) {
      if (product.hidden) continue;
      final price = priceAt(p.prices, product.id, _from);
      final text = price == null ? '' : formatPrice(price.price);
      final field = _fields[product.id];
      if (field == null) {
        _fields[product.id] = TextEditingController(text: text);
      } else if (!keepTyped) {
        field.text = text;
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _from = calendarDay(picked);
      _fill();
    });
  }

  Future<void> _save() async {
    final p = context.read<PriceListProvider>();
    final prices = <String, int>{};
    for (final MapEntry(key: id, value: field) in _fields.entries) {
      final text = field.text.trim();
      if (text.isEmpty) continue;
      final value = parseRub(text);
      if (value == null || value <= 0) {
        setState(
          () => _problem =
              '«${p.product(id)?.name ?? ''}»: цена — число больше нуля',
        );
        return;
      }
      prices[id] = value;
    }
    setState(() {
      _problem = null;
      _saving = true;
    });
    final saved = await p.saveEdition(_from, prices);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      setState(() => _problem = p.lastProblem);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Записано цен: $saved, вводятся с ${_date.format(_from)}',
        ),
      ),
    );
    Navigator.of(context).pop(_from);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceListProvider>();
    final theme = Theme.of(context);
    // Товар мог появиться после открытия (синхронизация) — поле для него.
    _fill(keepTyped: true);
    final view = p.view(_from);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая редакция прайса'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text('Вводится с ${_date.format(_from)}'),
                  ),
                  Text(
                    'Меняйте только нужные цены — остальные останутся прежними.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              for (final s in view.sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Text(
                    s.group.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final r in s.rows) _PriceRow(r, _fields[r.product.id]!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final PriceListRow row;
  final TextEditingController field;
  const _PriceRow(this.row, this.field);

  @override
  Widget build(BuildContext context) {
    final current = row.price;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.product.name),
                Text(
                  current == null
                      ? 'Цены ещё нет'
                      : 'Сейчас ${formatPrice(current.price)} ₽ с '
                            '${_date.format(current.validFrom)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: ValueListenableBuilder(
              valueListenable: field,
              builder: (context, value, _) {
                final typed = parseRub(value.text.trim());
                final change = current == null || typed == null
                    ? null
                    : priceChange(current.price, typed);
                return TextField(
                  controller: field,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixText: '₽/${row.product.unit.title}',
                    helperText: change == null || change == 0
                        ? null
                        : formatPriceChange(change),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
