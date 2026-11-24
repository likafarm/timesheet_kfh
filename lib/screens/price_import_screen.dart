// lib/screens/price_import_screen.dart
//
// «Прайс-лист → Загрузить из Excel» (11.1, просьба владельца 2026-11-24):
// файл .xlsx с таблицей «Наименование / Цена / Единица» (как бумажный прайс
// или выгрузка программы) → дата, с которой вводятся цены (из строки
// «вводится с …» или выбранная) → проверка: новые товары и группы, новые
// цены «было → стало», без изменений, что не разобралось → «Записать»
// одной транзакцией. Старые цены остаются в истории.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/price_list_provider.dart';
import '../services/xlsx_reader.dart';

final _date = DateFormat('dd.MM.yyyy');

String _price(int k) => '${formatPrice(k)} ₽';

class PriceImportScreen extends StatefulWidget {
  /// Уже прочитанный прайс (для тестов); null — выбрать файл.
  final ImportedPriceList? initial;
  final String? initialName;

  const PriceImportScreen({super.key, this.initial, this.initialName});

  @override
  State<PriceImportScreen> createState() => _PriceImportScreenState();
}

class _PriceImportScreenState extends State<PriceImportScreen> {
  ImportedPriceList? _file;
  String? _fileName;
  DateTime? _from;
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) _use(initial, widget.initialName ?? 'прайс.xlsx');
  }

  void _use(ImportedPriceList file, String name) {
    _file = file;
    _fileName = name;
    _from = file.validFrom ?? calendarDay(DateTime.now());
    _problem = null;
  }

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Прайс-лист Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final parsed = readPriceList(await file.readAsBytes());
      setState(() => _use(parsed, file.name));
    } on Exception catch (e) {
      setState(() => _problem = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked != null) setState(() => _from = calendarDay(picked));
  }

  Future<void> _save(PriceImportPlan plan) async {
    final p = context.read<PriceListProvider>();
    setState(() => _busy = true);
    final ok = await p.applyImport(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _problem = p.lastProblem);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Прайс загружен: цен записано ${plan.prices.length}, '
          'вводятся с ${_date.format(plan.validFrom)}',
        ),
      ),
    );
    Navigator.of(context).pop(plan.validFrom);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceListProvider>();
    final theme = Theme.of(context);
    final file = _file, from = _from;
    final plan = file == null || from == null ? null : p.planImport(file, from);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузить прайс из Excel'),
        actions: [
          if (plan != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _busy || plan.isEmpty ? null : () => _save(plan),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Записать'),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'Таблица Excel со столбцами «Наименование», «Цена» и '
                '«Единица» (кг, шт, уп, банка): строка только с названием — '
                'группа. Подойдёт бумажный прайс, набранный в Excel, и '
                'выгрузка прайса из программы.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_fileName ?? 'Выбрать файл .xlsx'),
                  ),
                  if (from != null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text('Вводится с ${_date.format(from)}'),
                    ),
                ],
              ),
              if (file != null && file.validFrom == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'В файле нет строки «вводится с …» — проверьте дату.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (plan != null) ..._planView(context, file!, plan),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _planView(
    BuildContext context,
    ImportedPriceList file,
    PriceImportPlan plan,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget chip(String text) => Chip(label: Text(text));
    final widgets = <Widget>[
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('Товаров в файле: ${plan.lines.length}'),
          chip('Новых товаров: ${plan.count(PriceImportAction.newProduct)}'),
          chip('Новых цен: ${plan.count(PriceImportAction.newPrice)}'),
          chip('Без изменений: ${plan.count(PriceImportAction.same)}'),
          if (plan.newGroups > 0) chip('Новых групп: ${plan.newGroups}'),
        ],
      ),
      if (plan.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Все цены уже такие — записывать нечего.'),
        ),
    ];
    String? group;
    for (final l in plan.lines) {
      if (l.groupName != group) {
        group = l.groupName;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              group,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      final change = priceChange(l.before, l.item.price);
      widgets.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.item.name),
          subtitle: Text(switch (l.action) {
            PriceImportAction.newProduct => 'Новый товар',
            PriceImportAction.newPrice =>
              l.before == null
                  ? 'Первая цена'
                  : 'Было ${_price(l.before!)}'
                        '${change == null ? '' : ', ${formatPriceChange(change)}'}',
            PriceImportAction.same => 'Без изменений',
          }, style: TextStyle(color: muted)),
          trailing: Text(
            '${_price(l.item.price)} / ${l.item.unit.title}',
            style: TextStyle(
              fontWeight: l.action == PriceImportAction.same
                  ? FontWeight.normal
                  : FontWeight.w600,
              color: l.action == PriceImportAction.same ? muted : null,
            ),
          ),
        ),
      );
    }
    if (plan.missing.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Нет в файле (цены остаются прежними): '
            '${plan.missing.map((p) => p.name).join(', ')}',
            style: TextStyle(color: muted),
          ),
        ),
      );
    }
    if (file.skipped.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Не разобраны и не загружаются (нет цены или непонятная единица):\n'
            '${file.skipped.join('\n')}',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    return widgets;
  }
}
