// lib/screens/customers_screen.dart
//
// «Продажи → Покупатели» (этап 11.3): список с поиском по имени, нику,
// адресу и цифрам телефона; карточка — имя, телефон, как связаться
// (мессенджер и ник), адрес, примечание. Одинаковый телефон у двух
// покупателей — подсказка в окне. Заказы и долг покупателя появятся в
// карточке в 11.4–11.6.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/customers_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomersProvider _customers = CustomersProvider(
    context.read<AppProvider>(),
  )..load();
  final _query = TextEditingController();

  @override
  void dispose() {
    _customers.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _customers,
      child: Consumer<CustomersProvider>(
        builder: (context, p, _) {
          final list = p.search(_query.text);
          return Scaffold(
            appBar: AppBar(title: Text('Покупатели (${p.customers.length})')),
            floatingActionButton: p.canEdit
                ? FloatingActionButton.extended(
                    // Пункты меню живут рядом (IndexedStack) — без общего героя.
                    heroTag: null,
                    onPressed: () => showCustomerDialog(context, p),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Покупатель'),
                  )
                : null,
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _query,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Имя, ник, адрес или цифры телефона',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: _query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Очистить',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _query.clear()),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: !p.loaded
                          ? const Center(child: CircularProgressIndicator())
                          : list.isEmpty
                          ? Center(
                              child: Text(
                                p.customers.isEmpty
                                    ? 'Покупателей пока нет'
                                    : 'Никого не нашлось',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: list.length,
                              itemBuilder: (context, i) => _CustomerTile(
                                list[i],
                                onTap: () => showCustomerDialog(
                                  context,
                                  p,
                                  customer: list[i],
                                ),
                              ),
                            ),
                    ),
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

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  const _CustomerTile(this.customer, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final phone = formatPhone(c.phone);
    final how = [?c.channel?.short, ?c.contact].join(' ');
    final theme = Theme.of(context);
    final balance = context.watch<CustomersProvider>().balances[c.id];
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(c.name)),
          if (balance != null && balance.debt > 0)
            Text(
              'долг ${formatPrice(balance.debt)} ₽',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (balance != null && balance.advance > 0)
            Text(
              'аванс ${formatPrice(balance.advance)} ₽',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      subtitle: Text(
        [
          if (phone.isNotEmpty) phone,
          if (how.isNotEmpty) how,
          ?c.address,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: phone.isEmpty
          ? null
          : IconButton(
              tooltip: 'Скопировать телефон',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Скопировано: $phone')));
              },
            ),
      onTap: onTap,
    );
  }
}

/// Карточка покупателя: новый или правка [customer].
Future<void> showCustomerDialog(
  BuildContext context,
  CustomersProvider p, {
  Customer? customer,
}) => showAppDialog<void>(
  context: context,
  builder: (_) => ChangeNotifierProvider.value(
    value: p,
    child: _CustomerDialog(customer: customer),
  ),
);

class _CustomerDialog extends StatefulWidget {
  final Customer? customer;
  const _CustomerDialog({this.customer});

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late final Customer? _c = widget.customer;
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _phone = TextEditingController(text: _c?.phone ?? '');
  late final _contact = TextEditingController(text: _c?.contact ?? '');
  late final _address = TextEditingController(text: _c?.address ?? '');
  late final _notes = TextEditingController(text: _c?.notes ?? '');
  late CustomerChannel? _channel = _c?.channel;
  String? _problem;

  @override
  void dispose() {
    for (final c in [_name, _phone, _contact, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final p = context.read<CustomersProvider>();
    final customer = Customer(
      id: _c?.id ?? p.newId(),
      name: _name.text.trim(),
      phone: _opt(_phone),
      address: _opt(_address),
      channel: _channel,
      contact: _opt(_contact),
      notes: _opt(_notes),
      counterpartyId: _c?.counterpartyId,
    );
    final ok = await p.save(customer);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _problem = p.lastProblem);
    }
  }

  Future<void> _delete() async {
    final p = context.read<CustomersProvider>();
    final sure = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Удалить покупателя?'),
        content: Text('${_c!.name} пропадёт из списка.'),
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
    if (sure != true || !mounted) return;
    if (await p.delete(_c!.id) && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomersProvider>();
    final theme = Theme.of(context);
    final twin = p.samePhone(_phone.text, exceptId: _c?.id);
    return AppDialog(
      title: Text(_c == null ? 'Новый покупатель' : 'Покупатель'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: _c == null,
              readOnly: !p.canEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              readOnly: !p.canEdit,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Телефон',
                border: const OutlineInputBorder(),
                helperText: twin == null
                    ? null
                    : 'Такой телефон уже у покупателя «${twin.name}»',
                helperStyle: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
            ChoiceGroup<CustomerChannel?>(
              label: 'Как связаться',
              value: _channel,
              options: [
                for (final ch in CustomerChannel.values)
                  ChoiceOption(ch, ch.title, theme.colorScheme.primary),
              ],
              onChanged: p.canEdit
                  ? (ch) =>
                        setState(() => _channel = ch == _channel ? null : ch)
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              readOnly: !p.canEdit,
              decoration: const InputDecoration(
                labelText: 'Имя или ник в мессенджере',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              readOnly: !p.canEdit,
              decoration: const InputDecoration(
                labelText: 'Адрес доставки',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              readOnly: !p.canEdit,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                border: OutlineInputBorder(),
              ),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _problem!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_c != null && p.canEdit)
          TextButton(onPressed: _delete, child: const Text('Удалить')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        if (p.canEdit)
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
