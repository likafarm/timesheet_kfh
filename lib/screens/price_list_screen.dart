// lib/screens/price_list_screen.dart
//
// «Продажи → Прайс-лист» (этап 11.1): прайс на выбранную редакцию по
// группам — цена, единица, изменение к прежней цене. Нажатие на товар —
// история его цен (исправить или удалить ошибочную цену). Печать по образцу
// владельца и Excel — у всех ролей; «Новая редакция» и «Товары и порядок» —
// у администратора и бухгалтера (решение владельца 2026-11-24).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/price_list_provider.dart';
import '../services/excel_export.dart';
import '../services/price_list_pdf.dart';
import '../services/print_service.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/excel_export_action.dart';
import 'price_catalog_screen.dart';
import 'price_edition_screen.dart';
import 'price_import_screen.dart';

final _date = DateFormat('dd.MM.yyyy');

String _price(int k) => '${formatPrice(k)} ₽';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  late final PriceListProvider _prices = PriceListProvider(
    context.read<AppProvider>(),
  )..load();

  /// Выбранная редакция; null — действующая сегодня.
  DateTime? _edition;

  /// «Загрузить из Excel»: после записи — показать загруженную редакцию.
  Future<void> _import() async {
    final from = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _prices,
          child: const PriceImportScreen(),
        ),
      ),
    );
    if (from != null && mounted) setState(() => _edition = from);
  }

  @override
  void dispose() {
    _prices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _prices,
      child: Consumer<PriceListProvider>(
        builder: (context, p, _) {
          final today = calendarDay(DateTime.now());
          final editions = p.editions;
          final current = editionAt(p.prices, today);
          final chosen = editions.contains(_edition) ? _edition : current;
          final view = p.view(chosen ?? today, includeHidden: p.canEdit);
          final printable = p.view(chosen ?? today, onlyPriced: true);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Прайс-лист'),
              actions: [
                IconButton(
                  tooltip: 'Печать / PDF',
                  icon: const Icon(Icons.print_outlined),
                  onPressed: printable.rows.isEmpty
                      ? null
                      : () => PrintService.printPriceList(
                          printable,
                          settings: p.settings,
                        ),
                ),
                IconButton(
                  tooltip: 'Выгрузить в Excel',
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: printable.rows.isEmpty
                      ? null
                      : () => exportToExcel(
                          context,
                          fileName:
                              '${priceListFileName(printable.edition)}.xlsx',
                          build: () async => priceListWorkbook(
                            view: printable,
                            companySettings: p.settings,
                          ),
                        ),
                ),
                if (p.canEdit)
                  IconButton(
                    tooltip: 'Загрузить из Excel',
                    icon: const Icon(Icons.upload_file),
                    onPressed: _import,
                  ),
                if (p.canEdit)
                  _CatalogButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: p,
                          child: const PriceCatalogScreen(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            floatingActionButton: p.canEdit && p.products.isNotEmpty
                ? FloatingActionButton.extended(
                    // Пункты меню живут рядом (IndexedStack) — без общего героя.
                    heroTag: null,
                    onPressed: () async {
                      final from = await Navigator.of(context).push<DateTime>(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: p,
                            child: const PriceEditionScreen(),
                          ),
                        ),
                      );
                      if (from != null && mounted) {
                        setState(() => _edition = from);
                      }
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Новая редакция'),
                  )
                : null,
            body: !p.loaded
                ? const Center(child: CircularProgressIndicator())
                : p.products.isEmpty
                ? _Empty(canEdit: p.canEdit, onImport: _import)
                : Align(
                    alignment: Alignment.topLeft,
                    // На широком экране цена не уезжает от названия.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          _EditionBar(
                            editions: editions,
                            chosen: chosen,
                            current: current,
                            onChanged: (d) => setState(() => _edition = d),
                          ),
                          for (final s in view.sections) ...[
                            _GroupHeader(s.group.name),
                            for (final r in s.rows) _ProductTile(r, chosen),
                          ],
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// «Товары и порядок»: на широком экране — с подписью, на телефоне — значок.
class _CatalogButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CatalogButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const label = 'Товары и порядок';
    if (MediaQuery.sizeOf(context).width < 700) {
      return IconButton(
        tooltip: label,
        icon: const Icon(Icons.reorder),
        onPressed: onPressed,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: const Icon(Icons.reorder),
        label: const Text(label),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onImport;
  const _Empty({required this.canEdit, required this.onImport});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            canEdit
                ? 'Прайс пуст. Загрузите его из Excel или заведите группы и '
                      'товары с ценами — кнопка «Товары и порядок» вверху.'
                : 'Прайс пока не заполнен — его ведут администратор и '
                      'бухгалтер.',
            textAlign: TextAlign.center,
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Загрузить из Excel'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Выбор редакции: «Действующая с …», будущие и прежние.
class _EditionBar extends StatelessWidget {
  final List<DateTime> editions;
  final DateTime? chosen;
  final DateTime? current;
  final ValueChanged<DateTime> onChanged;

  const _EditionBar({
    required this.editions,
    required this.chosen,
    required this.current,
    required this.onChanged,
  });

  String _label(DateTime d) {
    final today = calendarDay(DateTime.now());
    final suffix = d == current
        ? ' — действующая'
        : d.isAfter(today)
        ? ' — будущая'
        : ' — прежняя';
    return 'Вводится с ${_date.format(d)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (editions.isEmpty) {
      return const ListTile(title: Text('Цен ещё нет'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<DateTime>(
        initialValue: chosen,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Редакция прайса',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final d in editions)
            DropdownMenuItem(value: d, child: Text(_label(d))),
        ],
        onChanged: (d) {
          if (d != null) onChanged(d);
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String name;
  const _GroupHeader(this.name);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      name,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _ProductTile extends StatelessWidget {
  final PriceListRow row;
  final DateTime? edition;
  const _ProductTile(this.row, this.edition);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = row.price;
    final change = row.change;
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      title: Text(
        row.product.name,
        style: row.product.hidden ? TextStyle(color: muted) : null,
      ),
      subtitle: row.product.hidden
          ? const Text('Не продаётся — в печать не попадает')
          : price != null && !row.changedInEdition
          ? Text('Цена с ${_date.format(price.validFrom)}')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (change != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                formatPriceChange(change),
                style: TextStyle(
                  color: change > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          Text(
            price == null
                ? 'нет цены'
                : '${_price(price.price)} / ${row.product.unit.title}',
            style: price == null
                ? TextStyle(color: muted)
                : const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      onTap: () => showPriceHistory(context, row.product),
    );
  }
}

/// История цен товара [product]: новые сначала; админ и бухгалтер могут
/// исправить сумму или удалить ошибочную цену.
Future<void> showPriceHistory(BuildContext context, Product product) {
  final p = context.read<PriceListProvider>();
  return showAppDialog<void>(
    context: context,
    builder: (_) =>
        ChangeNotifierProvider.value(value: p, child: _HistoryDialog(product)),
  );
}

class _HistoryDialog extends StatelessWidget {
  final Product product;
  const _HistoryDialog(this.product);

  Future<void> _correct(
    BuildContext context,
    PriceListProvider p,
    ProductPrice price,
  ) async {
    final controller = TextEditingController(text: formatPrice(price.price));
    final value = await showAppDialog<int>(
      context: context,
      builder: (context) => AppDialog(
        title: Text('Цена с ${_date.format(price.validFrom)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Цена, ₽ за ${product.unit.title}',
            border: const OutlineInputBorder(),
            helperText: 'Исправление ошибки: новой редакции не будет',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, parseRub(controller.text)),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value != null) await p.correctPrice(price, value);
  }

  Future<void> _delete(
    BuildContext context,
    PriceListProvider p,
    PriceHistoryEntry e,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить цену?'),
        content: Text(
          'Цена ${_price(e.price.price)} с ${_date.format(e.price.validFrom)} '
          'будет удалена. ${e.previous == null ? 'Других цен у товара нет до '
                    'следующей редакции.' : 'С этого дня снова будет действовать '
                    '${_price(e.previous!.price)}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await p.deletePrice(e.price.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceListProvider>();
    final history = p.history(product.id);
    return AppDialog(
      title: Text(product.name),
      content: SizedBox(
        width: 460,
        child: history.isEmpty
            ? const Text('Цен ещё нет')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${_price(e.price.price)} / ${product.unit.title}'
                        '${e.change == null ? '' : '   ${formatPriceChange(e.change!)}'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        e.until == null
                            ? 'с ${_date.format(e.price.validFrom)}'
                            : 'с ${_date.format(e.price.validFrom)} '
                                  'по ${_date.format(e.until!)}',
                      ),
                      trailing: p.canEdit
                          ? PopupMenuButton<String>(
                              tooltip: 'Действия',
                              onSelected: (a) => a == 'edit'
                                  ? _correct(context, p, e.price)
                                  : _delete(context, p, e),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Исправить цену'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить цену'),
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
