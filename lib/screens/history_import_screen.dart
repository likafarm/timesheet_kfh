// lib/screens/history_import_screen.dart
//
// «Заказы → Перенести историю из Excel» (этап 11.7): файл «Заказы
// мяса.xlsx» (только читается) → проверка перед записью: сколько будет
// покупателей, выдач, заказов и строк; какие тексты «Заказа» к какому
// товару отнесены (не узнанные — в «Прочее»; товар можно выбрать самому);
// какие покупатели склеены по телефону и совпали с уже заведёнными →
// «Перенести» одной транзакцией. Повторная загрузка того же файла уже
// перенесённых заказов не задваивает.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/orders_provider.dart';
import '../services/xlsx_reader.dart';
import '../widgets/adaptive_dialog.dart';

/// Открыть перенос истории (с тем же OrdersProvider).
Future<void> openHistoryImport(BuildContext context) {
  final p = context.read<OrdersProvider>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: const HistoryImportScreen(),
      ),
    ),
  );
}

class HistoryImportScreen extends StatefulWidget {
  /// Уже прочитанный файл (для тестов); null — выбрать файл.
  final HistorySource? initial;
  const HistoryImportScreen({super.key, this.initial});

  @override
  State<HistoryImportScreen> createState() => _HistoryImportScreenState();
}

class _HistoryImportScreenState extends State<HistoryImportScreen> {
  HistorySource? _source;
  String? _fileName;
  final _overrides = <String, String>{};
  HistoryImportPlan? _plan;
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _source = widget.initial;
    if (_source != null) _fileName = 'Заказы мяса.xlsx';
  }

  HistoryImportPlan? _currentPlan(OrdersProvider p) {
    final source = _source;
    if (source == null || !p.loaded) return null;
    return _plan ??= p.planHistory(source, overrides: _overrides);
  }

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Заказы Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final source = readOrderHistory(await file.readAsBytes());
      setState(() {
        _source = source;
        _fileName = file.name;
        _overrides.clear();
        _plan = null;
      });
    } on Exception catch (e) {
      setState(() => _problem = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(OrdersProvider p, HistoryTextMatch m) async {
    final products = p.products.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showAppDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: Text('«${m.text.isEmpty ? 'без текста' : m.text}»'),
        content: SizedBox(
          width: 420,
          height: 420,
          child: ListView(
            children: [
              if (m.manual)
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Как определила программа'),
                  onTap: () => Navigator.pop(context, ''),
                ),
              for (final x in products)
                ListTile(
                  dense: true,
                  title: Text(x.name),
                  subtitle: x.hidden ? const Text('не продаётся') : null,
                  selected: x.id == m.productId,
                  onTap: () => Navigator.pop(context, x.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      if (picked.isEmpty) {
        _overrides.remove(m.text);
      } else {
        _overrides[m.text] = picked;
      }
      _plan = null;
    });
  }

  Future<void> _import(OrdersProvider p, HistoryImportPlan plan) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final ok = await p.importHistory(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _problem = p.lastProblem);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'История перенесена: заказов ${plan.orders.length}, '
          'строк ${plan.lines}, новых покупателей ${plan.newCustomers.length}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final plan = _currentPlan(p);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Перенести историю из Excel'),
        actions: [
          if (plan != null && !plan.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _busy || !p.canImportHistory
                    ? null
                    : () => _import(p, plan),
                icon: const Icon(Icons.download_done),
                label: const Text('Перенести'),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'Файл «Заказы мяса.xlsx» только читается. Перенесённые '
                'заказы оплачены до программы: в финансы они не попадут и '
                'долгами не станут. Прошедшие выдачи — заказы «Выдан».',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _source == null ? 'Выбрать файл' : 'Другой файл',
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_fileName != null) Expanded(child: Text(_fileName!)),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (plan != null) ..._planView(context, p, plan),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _planView(
    BuildContext context,
    OrdersProvider p,
    HistoryImportPlan plan,
  ) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 300, child: Text(label)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
    // Тексты по товару.
    String productName(HistoryTextMatch m) => m.productId != null
        ? p.products[m.productId]?.name ?? '?'
        : m.newProductName ?? historyOtherProduct;
    final byProduct = <String, List<HistoryTextMatch>>{};
    for (final m in plan.texts) {
      (byProduct[productName(m)] ??= []).add(m);
    }
    final productNames = byProduct.keys.toList()
      ..sort((a, b) {
        // «Прочее» и новые (не из прайса) — первыми: их проверить.
        int rank(String n) => n == historyOtherProduct
            ? 0
            : byProduct[n]!.any((m) => m.newProductName != null)
            ? 1
            : 2;
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.compareTo(b);
      });
    final merges = [
      for (final c in plan.customers)
        if (c.names.length > 1) c,
    ];
    final matched = plan.customers.where((c) => c.existingId != null).length;
    return [
      const SizedBox(height: 16),
      Text('Что будет перенесено', style: theme.textTheme.titleLarge),
      const SizedBox(height: 4),
      row('Заказов', '${plan.orders.length}'),
      row('Строк', '${plan.lines}'),
      row('Выдач (новых)', '${plan.newBatches.length}'),
      row('Покупателей новых', '${plan.newCustomers.length}'),
      row('Совпали с уже заведёнными', '$matched'),
      if (plan.updatedCustomers.isNotEmpty)
        row(
          'Заведённым дописаны адрес/телефон',
          '${plan.updatedCustomers.length}',
        ),
      if (plan.newProducts.isNotEmpty)
        row(
          'Товаров не из прайса (скрытые)',
          plan.newProducts.map((x) => x.name).join(', '),
        ),
      if (plan.alreadyImported > 0)
        row('Уже перенесено раньше (пропущено)', '${plan.alreadyImported}'),
      for (final MapEntry(key: why, value: n) in plan.skippedRows.entries)
        row('Строк пропущено: $why', '$n'),
      if (plan.notPaidRows > 0)
        row('Строк без «Оплата: да» (для сведения)', '${plan.notPaidRows}'),
      if (plan.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Переносить нечего — всё из этого файла уже перенесено.',
            style: theme.textTheme.titleSmall,
          ),
        ),
      const SizedBox(height: 16),
      Text('Товары', style: theme.textTheme.titleLarge),
      Text(
        'Нажмите на текст, чтобы отнести его к другому товару.',
        style: theme.textTheme.bodySmall,
      ),
      for (final name in productNames)
        Card(
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            initiallyExpanded: name == historyOtherProduct,
            title: Text(
              name,
              style: TextStyle(
                color: name == historyOtherProduct
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
            subtitle: Text(
              'строк: ${byProduct[name]!.fold<int>(0, (s, m) => s + m.count)}, '
              'разных текстов: ${byProduct[name]!.length}'
              '${byProduct[name]!.any((m) => m.newProductName != null) ? ' · нет в прайсе — будет заведён скрытым' : ''}',
            ),
            children: [
              for (final m in byProduct[name]!)
                ListTile(
                  dense: true,
                  title: Text(m.text.isEmpty ? '(без текста)' : m.text),
                  subtitle: m.manual ? const Text('выбрано вручную') : null,
                  trailing: Text('${m.count}'),
                  onTap: () => _choose(p, m),
                ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      Text('Покупатели', style: theme.textTheme.titleLarge),
      Text(
        merges.isEmpty
            ? 'Под одним телефоном разных имён нет.'
            : 'Один телефон — разные имена: станут одним покупателем '
                  '(имя — первое встретившееся). Поправить можно потом в '
                  '«Покупателях».',
        style: theme.textTheme.bodySmall,
      ),
      for (final c in merges)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.merge_type),
          title: Text(c.names.join(' / ')),
          subtitle: Text(
            [
              formatPhone(c.phone),
              'строк: ${c.rows}',
              if (c.existingId != null) 'уже заведён как «${c.name}»',
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
        ),
    ];
  }
}
