// lib/screens/price_catalog_screen.dart
//
// «Прайс-лист → Товары и порядок» (этап 11.1, админ и бухгалтер; доработка
// по просьбе владельца 2026-11-24): группы и товары одним списком по
// порядку прайса. Порядок — перетаскиванием за ручку ≡ (группа переезжает
// вместе с товарами, товар можно перетащить в другую группу); у группы —
// «+ товар», внизу — «Новая группа». Нажатие на товар — правка (название,
// группа, единица, «Не продаётся»). Удалить можно только товар без цен (с
// ценами — скрыть: история остаётся) и пустую группу.

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/price_list_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';

class PriceCatalogScreen extends StatelessWidget {
  const PriceCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceListProvider>();
    final entries = p.catalog;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Товары и порядок')),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ReorderableListView.builder(
            // Ручка ≡ — и мышью, и пальцем сразу, без долгого нажатия.
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 32),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                entries.isEmpty
                    ? 'Начните с группы — например, «Говядина охлаждённая».'
                    : 'Порядок — как в печати: перетащите строку за ≡. Группа '
                          'переезжает вместе с товарами, товар можно перетащить '
                          'в другую группу. Нажмите на товар, чтобы изменить его.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showGroupDialog(context, p),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Новая группа'),
                ),
              ),
            ),
            itemCount: entries.length,
            onReorderItem: p.reorder,
            itemBuilder: (context, i) => switch (entries[i]) {
              CatalogGroupEntry(:final group) => _GroupTile(
                key: ValueKey('g:${group.id}'),
                p: p,
                group: group,
                index: i,
              ),
              CatalogProductEntry(:final product) => _ProductTile(
                key: ValueKey('p:${product.id}'),
                p: p,
                product: product,
                index: i,
              ),
            },
          ),
        ),
      ),
    );
  }
}

Widget _handle(int index) => ReorderableDragStartListener(
  index: index,
  child: const MouseRegion(
    cursor: SystemMouseCursors.grab,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Icon(Icons.drag_handle),
    ),
  ),
);

class _GroupTile extends StatelessWidget {
  final PriceListProvider p;
  final ProductGroup group;
  final int index;
  const _GroupTile({
    super.key,
    required this.p,
    required this.group,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Tooltip(message: 'Перетащить группу', child: _handle(index)),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showProductDialog(context, p, groupId: group.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Товар'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия с группой',
              onSelected: (a) async {
                switch (a) {
                  case 'rename':
                    await showGroupDialog(context, p, group: group);
                  case 'delete':
                    await p.deleteGroup(group.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                PopupMenuItem(value: 'delete', child: Text('Удалить группу')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final PriceListProvider p;
  final Product product;
  final int index;
  const _ProductTile({
    super.key,
    required this.p,
    required this.product,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 24, right: 8),
        leading: Tooltip(message: 'Перетащить товар', child: _handle(index)),
        title: Text(
          product.name,
          style: product.hidden ? TextStyle(color: muted) : null,
        ),
        subtitle: Text(
          [
            product.unit.title,
            if (product.hidden) 'не продаётся',
            ?product.notes,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => showProductDialog(context, p, product: product),
      ),
    );
  }
}

/// Окно группы: новая или переименование [group].
Future<void> showGroupDialog(
  BuildContext context,
  PriceListProvider p, {
  ProductGroup? group,
}) async {
  final name = TextEditingController(text: group?.name ?? '');
  final saved = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(group == null ? 'Новая группа' : 'Группа'),
      content: TextField(
        controller: name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Название (например, «Субпродукты говяжьи»)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  if (saved != true) return;
  await p.saveGroup(
    group?.copyWith(name: name.text.trim()) ??
        ProductGroup(
          id: p.newId(),
          name: name.text.trim(),
          sortOrder: p.groups.length,
        ),
  );
}

/// Окно товара: новый (в группе [groupId]) или правка [product]. У нового —
/// первая цена и дата, с которой она действует.
Future<void> showProductDialog(
  BuildContext context,
  PriceListProvider p, {
  Product? product,
  String? groupId,
}) => showAppDialog<void>(
  context: context,
  builder: (_) => ChangeNotifierProvider.value(
    value: p,
    child: _ProductDialog(
      product: product,
      groupId: groupId ?? product?.groupId ?? p.groups.first.id,
    ),
  ),
);

class _ProductDialog extends StatefulWidget {
  final Product? product;
  final String groupId;
  const _ProductDialog({this.product, required this.groupId});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _notes = TextEditingController(text: widget.product?.notes ?? '');
  final _price = TextEditingController();
  late String _group = widget.groupId;
  late ProductUnit _unit = widget.product?.unit ?? ProductUnit.kg;
  late bool _hidden = widget.product?.hidden ?? false;
  DateTime _from = calendarDay(DateTime.now());
  String? _problem;

  bool get _isNew => widget.product == null;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = context.read<PriceListProvider>();
    int? first;
    if (_isNew && _price.text.trim().isNotEmpty) {
      first = parseRub(_price.text.trim());
      if (first == null || first <= 0) {
        setState(() => _problem = 'Цена — число больше нуля');
        return;
      }
    }
    final notes = _notes.text.trim();
    final siblings = productsOfGroup(p.products, _group);
    final product =
        widget.product?.copyWith(
          groupId: _group,
          name: _name.text.trim(),
          unit: _unit,
          hidden: _hidden,
          notes: () => notes.isEmpty ? null : notes,
          sortOrder: _group == widget.product!.groupId ? null : siblings.length,
        ) ??
        Product(
          id: p.newId(),
          groupId: _group,
          name: _name.text.trim(),
          unit: _unit,
          sortOrder: siblings.length,
          hidden: _hidden,
          notes: notes.isEmpty ? null : notes,
        );
    final ok = await p.saveProduct(
      product,
      firstPrice: first,
      priceFrom: _from,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _problem = p.lastProblem);
    }
  }

  Future<void> _delete() async {
    final p = context.read<PriceListProvider>();
    final ok = await p.deleteProduct(widget.product!.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _problem = p.lastProblem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceListProvider>();
    final theme = Theme.of(context);
    return AppDialog(
      title: Text(_isNew ? 'Новый товар' : 'Товар'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Наименование',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Группа',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final g in p.groups)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (v) => setState(() => _group = v ?? _group),
            ),
            const SizedBox(height: 12),
            ChoiceGroup<ProductUnit>(
              label: 'Единица',
              value: _unit,
              options: [
                for (final u in ProductUnit.values)
                  ChoiceOption(u, u.title, theme.colorScheme.primary),
              ],
              onChanged: (u) => setState(() => _unit = u),
            ),
            if (_isNew) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Цена, ₽ за ${_unit.title}',
                        helperText: 'Можно позже — в новой редакции',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      'с ${_from.day.toString().padLeft(2, '0')}.'
                      '${_from.month.toString().padLeft(2, '0')}.${_from.year}',
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _from,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                      );
                      if (d != null) setState(() => _from = calendarDay(d));
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Примечание (не печатается)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Не продаётся'),
              subtitle: const Text(
                'Не печатается и не попадает в новую редакцию; история цен '
                'остаётся',
              ),
              value: _hidden,
              onChanged: (v) => setState(() => _hidden = v),
            ),
            if (_problem != null)
              Text(_problem!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton(onPressed: _delete, child: const Text('Удалить')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
