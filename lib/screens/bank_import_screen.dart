// lib/screens/bank_import_screen.dart
//
// «Банки и кассы → Загрузить выписку» (8Б.6): файл выписки СберБизнеса
// (Excel) → кошелёк → строки: уже загруженные, найденные среди введённых
// вручную (им ставится ссылка — дублей не будет) и новые с подсказкой
// статьи и контрагента по прошлым операциям. Новые без статьи не
// записываются, пока статью не выберут. Переводы между своими кошельками
// (внесение наличных, свой ИНН — решение владельца 2026-10-14) пишутся
// переводом: второй кошелёк выбирается кнопками, вид строки можно
// переключить «Доход/Расход ↔ Перевод».

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/finance_provider.dart';
import '../services/xlsx_reader.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';
import '../widgets/common_widgets.dart';
import '../widgets/finance_operation_dialog.dart';

class BankImportScreen extends StatefulWidget {
  /// Выписка уже прочитана (тесты); null — выбрать файл.
  final BankStatement? statement;

  const BankImportScreen({super.key, this.statement});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _Row {
  final BankLineMatch match;
  bool take;
  String? categoryId;

  /// Записать переводом между своими кошельками.
  bool transfer;

  /// Второй кошелёк перевода.
  String? otherAccountId;

  _Row(this.match)
    : transfer = match.transfer,
      otherAccountId = match.otherAccountId,
      categoryId = match.categoryId,
      take =
          match.status == BankLineStatus.fresh &&
          (match.transfer
              ? match.otherAccountId != null
              : !match.own && match.categoryId != null);

  /// Строку можно записать: у перевода есть второй кошелёк, у дохода и
  /// расхода — статья.
  bool get ready => transfer ? otherAccountId != null : categoryId != null;
}

class _BankImportScreenState extends State<BankImportScreen> {
  BankStatement? _statement;
  String? _fileName;
  String? _accountId;
  List<_Row>? _rows;
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statement = widget.statement;
    // ИНН хозяйства — узнать «свои» счета в выписке.
    final app = context.read<AppProvider>();
    if (app.companySettings == null) app.loadCompanySettings();
  }

  FinanceProvider get fin => context.read<FinanceProvider>();

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Выписка Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final statement = readBankStatement(await file.readAsBytes());
      setState(() {
        _statement = statement;
        _fileName = file.name;
        _rows = null;
      });
      _match();
    } on Exception catch (e) {
      setState(() => _problem = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _match() {
    final statement = _statement, account = _accountId;
    if (statement == null || account == null) return;
    final inn = context.read<AppProvider>().companySettings?.inn;
    setState(
      () => _rows = [
        for (final m in fin.matchStatement(statement, account, ownInn: inn))
          _Row(m),
      ],
    );
  }

  /// Одна статья для всех новых строк без статьи того же вида.
  Future<void> _chooseForAll(OperationType type) async {
    final rows = [
      for (final r in _rows!)
        if (r.match.status == BankLineStatus.fresh &&
            !r.transfer &&
            r.categoryId == null &&
            r.match.line.type == type)
          r,
    ];
    if (rows.isEmpty) return;
    final picked = await _pickCategory(
      type == OperationType.income ? CategoryType.income : CategoryType.expense,
      '${type == OperationType.income ? 'Поступления' : 'Списания'} без '
      'статьи: ${rows.length}',
      null,
    );
    if (picked == null) return;
    setState(() {
      for (final r in rows) {
        r.categoryId = picked.id;
        if (!r.match.own) r.take = true;
      }
    });
  }

  Future<void> _chooseCategory(_Row row) async {
    final wanted = row.match.line.incoming
        ? CategoryType.income
        : CategoryType.expense;
    final picked = await _pickCategory(
      wanted,
      row.match.line.purpose,
      fin.catalog.categories[row.categoryId],
    );
    if (picked != null) {
      setState(() {
        row.categoryId = picked.id;
        row.take = true;
      });
    }
  }

  Future<FinCategory?> _pickCategory(
    CategoryType wanted,
    String hint,
    FinCategory? initial,
  ) async {
    final items = [
      for (final c in fin.categories)
        if (c.type == wanted && !c.hidden) c,
    ];
    FinCategory? picked = initial;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AppDialog(
          title: const Text('Статья'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SearchPicker<FinCategory>(
                  label: 'Статья',
                  icon: Icons.category_outlined,
                  items: items,
                  nameOf: (c) => c.name,
                  detailOf: fin.groupName,
                  selected: picked,
                  onSelected: (c) => setLocal(() => picked = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: picked == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Выбрать'),
            ),
          ],
        ),
      ),
    );
    return ok == true ? picked : null;
  }

  Future<void> _import() async {
    final rows = _rows!, account = _accountId!;
    final fresh = [
      for (final r in rows)
        if (r.take && r.match.status == BankLineStatus.fresh && r.ready)
          r.transfer
              ? (r.match.line, null, null, r.otherAccountId)
              : (r.match.line, r.categoryId, r.match.counterpartyId, null),
    ];
    final matched = [
      for (final r in rows)
        if (r.match.status == BankLineStatus.matched) r.match,
    ];
    setState(() => _busy = true);
    final written = await fin.importStatement(
      accountId: account,
      fresh: fresh,
      matched: matched,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (written == null) {
      setState(() => _problem = fin.lastProblem);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Записано операций: $written; связано с введёнными: '
          '${matched.length}',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final statement = _statement;
    final rows = _rows;
    final theme = Theme.of(context);
    final accounts = [
      for (final a in f.accounts)
        if (!a.closed &&
            (a.kind == AccountKind.bank ||
                a.kind == AccountKind.card ||
                a.kind == AccountKind.creditCard))
          a,
    ];
    final toWrite = rows == null
        ? 0
        : rows
              .where(
                (r) =>
                    r.take && r.match.status == BankLineStatus.fresh && r.ready,
              )
              .length;
    final noCategory = rows == null
        ? 0
        : rows.where((r) => r.take && !r.ready).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Загрузка выписки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  statement == null ? 'Выбрать файл выписки' : 'Другой файл',
                ),
              ),
              if (_fileName != null) Text(_fileName!),
              SizedBox(
                width: 280,
                child: AppDropdown<String?>(
                  labelText: 'Кошелёк (счёт или карта)',
                  value: _accountId,
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _accountId = v);
                    _match();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Выписка СберБизнеса, выгруженная в Excel (.xlsx). Повторная '
            'загрузка той же выписки дублей не даёт.',
            style: theme.textTheme.bodySmall,
          ),
          if (_problem != null) ...[
            const SizedBox(height: 12),
            Text(_problem!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (statement != null) ...[
            const SizedBox(height: 12),
            Text(
              'Счёт ${statement.account ?? '—'}: строк ${statement.lines.length}'
              '${statement.lines.isEmpty ? '' : ', с ${DateFormat('dd.MM.yyyy').format(statement.lines.first.date)} по ${DateFormat('dd.MM.yyyy').format(statement.lines.last.date)}'}'
              '${statement.problems.isEmpty ? '' : '; не разобрано: ${statement.problems.length}'}',
              style: theme.textTheme.titleSmall,
            ),
          ],
          if (statement != null && _accountId == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Выберите кошелёк, которому принадлежит выписка.'),
            ),
          if (rows != null) ..._summary(theme, rows),
          if (rows != null)
            for (final r in rows)
              if (r.match.status == BankLineStatus.fresh) _tile(theme, r),
        ],
      ),
      bottomNavigationBar: rows == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        noCategory == 0
                            ? 'К записи: $toWrite'
                            : 'К записи: $toWrite; без статьи или '
                                  'кошелька: $noCategory (не запишутся)',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy || toWrite == 0 && !_hasMatched(rows)
                          ? null
                          : _import,
                      child: const Text('Записать'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  bool _hasMatched(List<_Row> rows) =>
      rows.any((r) => r.match.status == BankLineStatus.matched);

  List<Widget> _summary(ThemeData theme, List<_Row> rows) {
    int count(BankLineStatus s) =>
        rows.where((r) => r.match.status == s).length;
    final transfers = rows.where(
      (r) => r.match.status == BankLineStatus.fresh && r.transfer,
    );
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text('Уже загружено: ${count(BankLineStatus.imported)}'),
          Text('Найдено среди введённых: ${count(BankLineStatus.matched)}'),
          Text(
            'Новых: ${count(BankLineStatus.fresh)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (transfers.isNotEmpty)
            Text('из них переводы между своими: ${transfers.length}'),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final type in [OperationType.expense, OperationType.income])
            if (rows.any(
              (r) =>
                  r.match.status == BankLineStatus.fresh &&
                  !r.transfer &&
                  r.categoryId == null &&
                  r.match.line.type == type,
            ))
              TextButton.icon(
                onPressed: () => _chooseForAll(type),
                icon: const Icon(Icons.category_outlined, size: 18),
                label: Text(
                  type == OperationType.income
                      ? 'Одна статья для поступлений без статьи'
                      : 'Одна статья для списаний без статьи',
                ),
              ),
        ],
      ),
      const Divider(height: 24),
    ];
  }

  Widget _tile(ThemeData theme, _Row r) {
    final l = r.match.line;
    final category = fin.catalog.categories[r.categoryId];
    final others = [
      for (final a in fin.accounts)
        if (!a.closed && a.id != _accountId) a,
    ];
    return Card(
      child: CheckboxListTile(
        value: r.take,
        onChanged: (v) => setState(() => r.take = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Expanded(
              child: Text(
                [
                  DateFormat('dd.MM.yyyy').format(l.date),
                  ?l.counterpartyName,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${l.incoming ? '+' : '−'}${formatRub(l.amount)} ₽',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: operationTypeColors[l.type],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.purpose, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceButton(
                  label: l.type.title,
                  color: operationTypeColors[l.type] ?? Colors.grey,
                  selected: !r.transfer,
                  dense: true,
                  onPressed: () => setState(() {
                    r.transfer = false;
                    r.take = !r.match.own && r.categoryId != null;
                  }),
                ),
                ChoiceButton(
                  label: 'Перевод',
                  color:
                      operationTypeColors[OperationType.transfer] ??
                      Colors.grey,
                  selected: r.transfer,
                  dense: true,
                  onPressed: () => setState(() {
                    r.transfer = true;
                    r.take = r.otherAccountId != null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (r.transfer)
              ChoiceGroup<String?>(
                label: l.incoming ? 'Откуда пришли деньги' : 'Куда ушли деньги',
                options: [
                  for (final a in others)
                    ChoiceOption<String?>(
                      a.id,
                      a.name,
                      theme.colorScheme.primary,
                    ),
                ],
                value: r.otherAccountId,
                onChanged: (v) => setState(() {
                  r.otherAccountId = v;
                  r.take = true;
                }),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _chooseCategory(r),
                  icon: Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: category == null ? theme.colorScheme.error : null,
                  ),
                  label: Text(
                    category?.name ?? 'Выбрать статью',
                    style: TextStyle(
                      color: category == null ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ),
            if (r.match.own && !r.transfer)
              Text(
                'Вторая сторона — ваш ИНН: скорее перевод между своими '
                'кошельками',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
