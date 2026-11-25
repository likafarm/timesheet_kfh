// lib/screens/weighing_screen.dart
//
// Взвешивание подряд (этап 11.5, удобно на телефоне): строки заказов
// выдачи одна за другой — кому, что заказано, вес (штуки), «Записать» —
// и сразу следующая. Набор взвешивается по частям, общий вес считается
// сам (ход сборки набора — как в окне строки). Отклонение от заказанного
// сверх допуска подсвечивается. «Не хватило» — снять строку с причиной.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/orders_provider.dart';
import 'batches_screen.dart';
import 'order_editor_screen.dart';

/// Открыть взвешивание выдачи [batchId]; [start] — строка, с которой
/// начать (иначе — первая невзвешенная).
Future<void> openWeighing(
  BuildContext context,
  String batchId, {
  String? start,
}) {
  final p = context.read<OrdersProvider>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: WeighingScreen(batchId: batchId, start: start),
      ),
    ),
  );
}

double? _num(String text) {
  final t = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

class WeighingScreen extends StatefulWidget {
  final String batchId;
  final String? start;
  const WeighingScreen({super.key, required this.batchId, this.start});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  String? _current;
  bool _onlyOpen = true;
  bool _busy = false;
  final _weight = TextEditingController();
  final _pieces = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final queue = _queue(context.read<OrdersProvider>());
    final start =
        queue.where((e) => e.line.id == widget.start).firstOrNull ??
        queue.where((e) => !e.done).firstOrNull ??
        queue.firstOrNull;
    _show(start);
  }

  @override
  void dispose() {
    _weight.dispose();
    _pieces.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<BatchEntry> _queue(OrdersProvider p) =>
      weighingQueue(p.entriesOf(widget.batchId));

  void _show(BatchEntry? e) {
    _current = e?.line.id;
    _weight.text = fmtQty(e?.line.weight);
    _pieces.text = e?.line.pieces?.toString() ?? '';
    _weight.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _weight.text.length,
    );
    if (e != null) _focus.requestFocus();
  }

  /// Следующая после [index] строка (только невзвешенные — если включено).
  BatchEntry? _next(List<BatchEntry> queue, int index) {
    for (var i = index + 1; i < queue.length; i++) {
      if (!_onlyOpen || !queue[i].done) return queue[i];
    }
    if (_onlyOpen) {
      // С начала: пропущенные раньше.
      for (var i = 0; i < index && i < queue.length; i++) {
        if (!queue[i].done) return queue[i];
      }
    }
    return null;
  }

  Future<void> _save(OrdersProvider p, BatchEntry e, bool byWeight) async {
    if (_busy) return;
    final weight = byWeight ? _num(_weight.text) : null;
    final pieces = int.tryParse(_pieces.text.trim());
    if (byWeight && _weight.text.trim().isNotEmpty && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вес — числом, например 2,35')),
      );
      return;
    }
    setState(() => _busy = true);
    final ok = await p.weigh(e.line, weight: weight, pieces: pieces);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        final queue = _queue(p);
        final i = queue.indexWhere((x) => x.line.id == e.line.id);
        _show(_next(queue, i));
      }
    });
  }

  Future<void> _missing(OrdersProvider p, BatchEntry e) async {
    final note = await askMissingReason(context, e.line.note);
    if (note == null || !mounted) return;
    final ok = await p.markMissing(e.line, note.isEmpty ? null : note);
    if (!mounted || !ok) return;
    setState(() {
      final queue = _queue(p);
      final i = queue.indexWhere((x) => x.line.id == e.line.id);
      _show(_next(queue, i));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final queue = _queue(p);
    final index = queue.indexWhere((e) => e.line.id == _current);
    final e = index < 0 ? null : queue[index];
    final done = queue.where((x) => x.done).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Взвешено $done из ${queue.length}'),
        actions: [
          Row(
            children: [
              const Text('Только невзвешенные'),
              Switch(
                value: _onlyOpen,
                onChanged: (v) => setState(() => _onlyOpen = v),
              ),
            ],
          ),
        ],
      ),
      body: e == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    queue.isEmpty ? 'Взвешивать нечего' : 'Всё взвешено',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('К выдаче'),
                  ),
                ],
              ),
            )
          : _EntryForm(
              key: ValueKey(e.line.id),
              entry: e,
              position: '${index + 1} из ${queue.length}',
              weight: _weight,
              pieces: _pieces,
              focus: _focus,
              busy: _busy,
              onChanged: () => setState(() {}),
              onSave: (byWeight) => _save(p, e, byWeight),
              onMissing: () => _missing(p, e),
              onBack: index > 0
                  ? () => setState(() => _show(queue[index - 1]))
                  : null,
              onSkip: index < queue.length - 1
                  ? () => setState(() => _show(queue[index + 1]))
                  : null,
            ),
    );
  }
}

class _EntryForm extends StatelessWidget {
  final BatchEntry entry;
  final String position;
  final TextEditingController weight;
  final TextEditingController pieces;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onChanged;
  final void Function(bool byWeight) onSave;
  final VoidCallback onMissing;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const _EntryForm({
    super.key,
    required this.entry,
    required this.position,
    required this.weight,
    required this.pieces,
    required this.focus,
    required this.busy,
    required this.onChanged,
    required this.onSave,
    required this.onMissing,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final theme = Theme.of(context);
    final l = entry.line;
    final o = entry.order;
    final customer = p.customers[o.customerId];
    final product = p.products[l.productId];
    final byWeight = (product?.unit ?? ProductUnit.kg) == ProductUnit.kg;
    final ordered = orderedText(l);
    final w = _num(weight.text);
    final pcs = int.tryParse(pieces.text.trim());
    final preview = l.copyWith(
      weight: () => byWeight ? w : null,
      pieces: () => pcs,
      state: LineState.assembled,
    );

    // Набор: ход сборки с весом этой части.
    SetProgress? progress;
    final parent = entry.parent;
    if (parent != null) {
      final parts = [
        for (final x in p.linesOf(o.id))
          if (x.parentId == parent.id) x.id == l.id ? preview : x,
      ];
      progress = setProgress(parent, parts, p.products);
    }
    final dev = parent == null && byWeight
        ? weightDeviation(preview)
        : progress?.deviation;
    final off = dev != null && dev.abs() > p.tolerance;
    final amount = parent == null && (w != null || pcs != null)
        ? lineAmount(preview, p.products)
        : null;

    final address = o.delivery == Delivery.delivery
        ? (o.address ?? customer?.address)
        : null;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(position, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              '${p.label(o)} · ${customer?.name ?? '?'}',
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              [
                o.delivery.title,
                ?address,
                if (o.kind != OrderKind.sale) o.kind.title,
                if ((o.comment ?? '').trim().isNotEmpty) o.comment!.trim(),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text(
              product?.name ?? 'Товар не найден',
              style: theme.textTheme.titleLarge,
            ),
            if (parent != null)
              Text(
                'часть набора «${p.products[parent.productId]?.name ?? '?'}»',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text(
              'заказано: ${ordered.isEmpty ? '—' : ordered}',
              style: theme.textTheme.titleMedium,
            ),
            if (l.state == LineState.missing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Снята${(l.note ?? '').isEmpty ? '' : ': ${l.note}'}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (byWeight)
                  Expanded(
                    child: TextField(
                      controller: weight,
                      focusNode: focus,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: theme.textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        labelText: 'Вес',
                        suffixText: 'кг',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => onChanged(),
                      onSubmitted: (_) => onSave(byWeight),
                    ),
                  ),
                if (byWeight) const SizedBox(width: 12),
                SizedBox(
                  width: byWeight ? 120 : 200,
                  child: TextField(
                    controller: pieces,
                    focusNode: byWeight ? null : focus,
                    autofocus: !byWeight,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: byWeight ? null : theme.textTheme.headlineMedium,
                    decoration: InputDecoration(
                      labelText: byWeight ? 'Штук' : 'Количество',
                      suffixText: byWeight ? null : product?.unit.title,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                    onSubmitted: (_) => onSave(byWeight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (progress != null)
              Text(
                setProgressText(progress),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: off ? theme.colorScheme.error : null,
                ),
              )
            else if (dev != null)
              Text(
                dev >= 0
                    ? 'Больше заказанного на ${(dev * 100).round()} %'
                    : 'Меньше заказанного на ${(-dev * 100).round()} %',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: off ? theme.colorScheme.error : null,
                ),
              ),
            if (amount != null)
              Text('Сумма: ${rub(amount)}', style: theme.textTheme.titleSmall),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : () => onSave(byWeight),
              icon: const Icon(Icons.check),
              label: const Text('Записать и дальше'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onMissing,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Не хватило'),
                ),
                OutlinedButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Пропустить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
