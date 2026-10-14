// packages/domain/lib/src/finance/bank_statement.dart
//
// Загрузка выписки банка (этап 8Б.6): разбор выписки СберБизнеса,
// выгруженной в Excel (строки таблицы — уже прочитанные ячейки), поиск уже
// введённых операций и подбор статьи и контрагента по прошлым операциям.
// Операция из выписки помнит строку: source = bank, source_ref = ключ
// строки ([BankLine.key]) — повторная загрузка той же выписки дублей не
// даёт.

import '../utils/date_utils.dart';
import 'catalog.dart';
import 'models.dart';

/// Строка выписки.
class BankLine {
  final DateTime date;

  /// Копейки, больше нуля.
  final int amount;

  /// Поступление на счёт (иначе — списание).
  final bool incoming;
  final String? docNumber;
  final String purpose;
  final String? counterpartyName;
  final String? counterpartyInn;
  final String? counterpartyAccount;

  const BankLine({
    required this.date,
    required this.amount,
    required this.incoming,
    required this.purpose,
    this.docNumber,
    this.counterpartyName,
    this.counterpartyInn,
    this.counterpartyAccount,
  });

  /// Ключ строки для `source_ref`: день, номер документа, сумма, сторона.
  String get key =>
      'bank:${formatDateIso(date)}:${docNumber ?? ''}:$amount:'
      '${incoming ? 'in' : 'out'}';

  OperationType get type =>
      incoming ? OperationType.income : OperationType.expense;
}

class BankStatement {
  /// Свой счёт (из шапки или по строкам); null — не найден.
  final String? account;
  final List<BankLine> lines;

  /// Строки, которые не удалось разобрать: «строка N: причина».
  final List<String> problems;

  const BankStatement({
    this.account,
    required this.lines,
    this.problems = const [],
  });
}

/// Ошибка разбора: файл — не выписка.
class BankStatementException implements Exception {
  final String message;
  const BankStatementException(this.message);
  @override
  String toString() => message;
}

String _norm(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// Сумма из ячейки: `1999.97`, `1 999,97`; пусто — null.
int? _amount(String? cell) {
  final t = (cell ?? '').replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return v == null ? null : (v * 100).round();
}

/// День из ячейки: число дня Excel, `гггг-мм-дд…` или `дд.мм.гггг…`.
DateTime? _date(String? cell) {
  final t = (cell ?? '').trim();
  if (t.isEmpty) return null;
  final serial = double.tryParse(t);
  if (serial != null && serial > 20000 && serial < 80000) {
    return addCalendarDays(DateTime(1899, 12, 30), serial.floor());
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
  if (iso != null) {
    return DateTime(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }
  final ru = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})').firstMatch(t);
  if (ru != null) {
    return DateTime(int.parse(ru[3]!), int.parse(ru[2]!), int.parse(ru[1]!));
  }
  return null;
}

/// Сторона проводки: «счёт \n ИНН \n название».
(String?, String?, String?) _party(String? cell) {
  final parts = [
    for (final p in (cell ?? '').split(RegExp(r'[\r\n]+')))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  String? at(int i) => i < parts.length ? parts[i] : null;
  final account = at(0);
  final inn = at(1);
  final isInn = inn != null && RegExp(r'^\d{10}(\d{2})?$').hasMatch(inn);
  return (
    account,
    isInn ? inn : null,
    isInn ? parts.skip(2).join(' ').trim() : parts.skip(1).join(' ').trim(),
  );
}

/// Разбор выписки СберБизнеса (выгрузка в Excel): ищет строку заголовка
/// с «Дата проводки», столбцы — по заголовкам (подзаголовки «Дебет» и
/// «Кредит» — в следующей строке, если над ними «Счет»).
BankStatement parseSberStatement(List<List<String?>> rows) {
  int? headerRow;
  for (var i = 0; i < rows.length && headerRow == null; i++) {
    if (rows[i].any((c) => _norm(c) == 'дата проводки')) headerRow = i;
  }
  if (headerRow == null) {
    throw const BankStatementException(
      'Это не выписка СберБизнеса: нет столбца «Дата проводки»',
    );
  }
  final names = <int, String>{};
  final head = rows[headerRow];
  final sub = headerRow + 1 < rows.length
      ? rows[headerRow + 1]
      : const <String?>[];
  final width = [head.length, sub.length].reduce((a, b) => a > b ? a : b);
  for (var c = 0; c < width; c++) {
    final h = c < head.length ? _norm(head[c]) : '';
    final s = c < sub.length ? _norm(sub[c]) : '';
    if (s == 'дебет' || s == 'кредит') {
      names[c] = s;
    } else if (h.isNotEmpty) {
      names[c] = h;
    }
  }
  int? col(String name) =>
      names.entries.where((e) => e.value.startsWith(name)).firstOrNull?.key;
  final cDate = col('дата проводки');
  final cDebit = col('дебет');
  final cCredit = col('кредит');
  final cOut = col('сумма по дебету');
  final cIn = col('сумма по кредиту');
  final cDoc = col('№ документа');
  final cPurpose = col('назначение платежа');
  if ([cDate, cDebit, cCredit, cOut, cIn, cPurpose].contains(null)) {
    throw const BankStatementException(
      'В выписке нет нужных столбцов (дата, дебет, кредит, суммы, '
      'назначение платежа)',
    );
  }
  String? at(List<String?> row, int? c) =>
      c == null || c >= row.length ? null : row[c];

  final start = sub.any((x) => _norm(x) == 'дебет')
      ? headerRow + 2
      : headerRow + 1;
  final lines = <BankLine>[];
  final problems = <String>[];
  final ownAccounts = <String, int>{};
  for (var i = start; i < rows.length; i++) {
    final row = rows[i];
    final date = _date(at(row, cDate));
    if (date == null) continue; // итоги, пустые строки, подвал
    final out = _amount(at(row, cOut));
    final inc = _amount(at(row, cIn));
    final incoming = (inc ?? 0) > 0;
    final amount = incoming ? inc! : out;
    if (amount == null || amount <= 0) {
      problems.add('строка ${i + 1}: нет суммы');
      continue;
    }
    final own = _party(at(row, incoming ? cCredit : cDebit));
    final other = _party(at(row, incoming ? cDebit : cCredit));
    if (own.$1 != null) ownAccounts[own.$1!] = (ownAccounts[own.$1!] ?? 0) + 1;
    lines.add(
      BankLine(
        date: date,
        amount: amount,
        incoming: incoming,
        docNumber: at(row, cDoc)?.trim(),
        purpose: (at(row, cPurpose) ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        counterpartyAccount: other.$1,
        counterpartyInn: other.$2,
        counterpartyName: (other.$3 ?? '').isEmpty ? null : other.$3,
      ),
    );
  }
  final account = ownAccounts.entries.isEmpty
      ? null
      : (ownAccounts.entries.toList()..sort((a, b) => b.value - a.value))
            .first
            .key;
  return BankStatement(account: account, lines: lines, problems: problems);
}

/// Что делать со строкой выписки.
enum BankLineStatus {
  /// Уже загружена (есть операция с тем же ключом).
  imported,

  /// Найдена введённая вручную операция: те же сумма и вид, ±3 дня.
  matched,

  /// Новая — будет записана.
  fresh,
}

/// Строка выписки с решением и подсказками.
class BankLineMatch {
  final BankLine line;
  final BankLineStatus status;

  /// Найденная операция ([BankLineStatus.imported]/[matched]).
  final FinOperation? operation;

  /// Подсказки для новой операции.
  final String? categoryId;
  final String? counterpartyId;

  /// Контрагент — свой (ИНН хозяйства).
  final bool own;

  /// Похоже на перевод между своими кошельками (свой ИНН или назначение
  /// «зачисление собственных средств», «взнос наличных»…): предлагается
  /// записать переводом, а не доходом или расходом.
  final bool transfer;

  /// Второй кошелёк перевода — подсказка: прошлый такой же перевод этого
  /// кошелька, иначе касса; null — подсказать нечего.
  final String? otherAccountId;

  const BankLineMatch(
    this.line,
    this.status, {
    this.operation,
    this.categoryId,
    this.counterpartyId,
    this.own = false,
    this.transfer = false,
    this.otherAccountId,
  });
}

/// Назначения платежа, которые означают перевод между своими кошельками
/// (решение владельца 2026-10-14: внесение наличных на счёт — перевод
/// «касса → счёт», а не доход). Список дополняется по образцам выписок.
final _transferPurposes = RegExp(
  r'собственных средств|взнос\s+наличн|внесени[еяй]\s+наличн|'
  r'снятие\s+наличн|выдача\s+наличн|перевод\s+между\s+(своими\s+)?счетами',
  caseSensitive: false,
);

/// Строка — перевод между своими кошельками: вторая сторона — свой ИНН
/// [ownInn] или назначение платежа из [_transferPurposes].
bool looksLikeTransfer(BankLine line, {String? ownInn}) =>
    (ownInn != null && line.counterpartyInn == ownInn) ||
    _transferPurposes.hasMatch(line.purpose);

/// Банк-посредник (эквайринг, карты): по его ИНН статью не подобрать —
/// подбирается по магазину из назначения платежа.
const bankInns = {'7707083893'};

/// Магазин из назначения платежа по карте: «… в ТУ RNAZS 23 по карте …» →
/// «rnazs 23»; null — не покупка по карте.
String? cardMerchant(String purpose) {
  final m = RegExp(
    r'\sв\s+(?:ТУ\s+)?(.+?)\s+по карте',
    caseSensitive: false,
  ).firstMatch(purpose);
  return m == null ? null : _norm(m[1]);
}

/// Смысл назначения платежа: первые три слова из букв (без номеров, дат
/// и сумм), в нижнем регистре; пусто — слов нет.
String purposeSignature(String purpose) => RegExp(
  r'[a-zа-яё]{3,}',
).allMatches(purpose.toLowerCase()).take(3).map((m) => m[0]).join(' ');

/// Сопоставление выписки [lines] кошелька [accountId] с операциями
/// [operations]: уже загруженные (по ключу), введённые вручную (та же
/// сумма и вид, ±3 дня, ещё без ссылки на банк — каждая один раз) и новые —
/// с подсказкой статьи и контрагента по прошлым операциям (тот же ИНН или
/// название контрагента; у покупок по карте — тот же магазин).
/// Переводы между своими кошельками ([looksLikeTransfer]) ищутся среди
/// переводов, где этот кошелёк — «куда» (поступление) или «откуда»
/// (списание), в том числе загруженных из выписки другого счёта; новому —
/// подсказка второго кошелька. [ownInn] — ИНН хозяйства.
List<BankLineMatch> matchBankLines({
  required List<BankLine> lines,
  required String accountId,
  required Iterable<FinOperation> operations,
  required FinanceCatalog catalog,
  String? ownInn,
}) {
  final ops = operations.toList();
  final byKey = <String, FinOperation>{
    for (final op in ops)
      if (op.sourceRef?.startsWith('bank:') ?? false) op.sourceRef!: op,
  };
  final used = <String>{};
  final counterpartyByInn = <String, Counterparty>{
    for (final c in catalog.counterparties.values)
      if ((c.inn ?? '').isNotEmpty) c.inn!: c,
  };
  final counterpartyByName = <String, Counterparty>{
    for (final c in catalog.counterparties.values) _norm(c.name): c,
  };
  // Новые сверху: последняя операция с контрагентом — её статья.
  final recent = [...ops]..sort((a, b) => b.date.compareTo(a.date));

  /// Второй кошелёк перевода: прошлый перевод этого кошелька в ту же
  /// сторону с тем же смыслом назначения, иначе любой прошлый в ту же
  /// сторону, иначе открытая касса.
  String? suggestOther(BankLine l) {
    String? other(FinOperation op) =>
        l.incoming ? op.accountId : op.toAccountId;
    bool sameSide(FinOperation op) =>
        op.type == OperationType.transfer &&
        (l.incoming ? op.toAccountId == accountId : op.accountId == accountId);
    final sign = purposeSignature(l.purpose);
    final past =
        recent
            .where(
              (op) =>
                  sameSide(op) &&
                  purposeSignature(op.description ?? '') == sign,
            )
            .firstOrNull ??
        recent.where(sameSide).firstOrNull;
    final found = past == null ? null : other(past);
    if (found != null && catalog.accounts[found]?.closed == false) {
      return found;
    }
    for (final a in catalog.accounts.values) {
      if (a.kind == AccountKind.cash && !a.closed && a.id != accountId) {
        return a.id;
      }
    }
    return null;
  }

  BankLineMatch decide(BankLine l) {
    final done = byKey[l.key];
    if (done != null) {
      return BankLineMatch(l, BankLineStatus.imported, operation: done);
    }
    final candidates =
        [
          for (final op in ops)
            if (op.accountId == accountId &&
                op.type == l.type &&
                op.amount == l.amount &&
                !used.contains(op.id) &&
                !(op.sourceRef?.startsWith('bank:') ?? false) &&
                (calendarDay(op.date).difference(l.date).inDays.abs() <= 3))
              op,
        ]..sort(
          (a, b) => calendarDay(a.date)
              .difference(l.date)
              .inDays
              .abs()
              .compareTo(calendarDay(b.date).difference(l.date).inDays.abs()),
        );
    if (candidates.isNotEmpty) {
      used.add(candidates.first.id);
      return BankLineMatch(
        l,
        BankLineStatus.matched,
        operation: candidates.first,
      );
    }
    // Перевод, уже внесённый вручную или из выписки другого счёта.
    final transfers =
        [
          for (final op in ops)
            if (op.type == OperationType.transfer &&
                op.amount == l.amount &&
                (l.incoming
                    ? op.toAccountId == accountId
                    : op.accountId == accountId) &&
                !used.contains(op.id) &&
                op.sourceRef != l.key &&
                (calendarDay(op.date).difference(l.date).inDays.abs() <= 3))
              op,
        ]..sort(
          (a, b) => calendarDay(a.date)
              .difference(l.date)
              .inDays
              .abs()
              .compareTo(calendarDay(b.date).difference(l.date).inDays.abs()),
        );
    if (transfers.isNotEmpty) {
      used.add(transfers.first.id);
      return BankLineMatch(
        l,
        BankLineStatus.matched,
        operation: transfers.first,
        transfer: true,
      );
    }
    final own = ownInn != null && l.counterpartyInn == ownInn;
    if (looksLikeTransfer(l, ownInn: ownInn)) {
      return BankLineMatch(
        l,
        BankLineStatus.fresh,
        own: own,
        transfer: true,
        otherAccountId: suggestOther(l),
      );
    }
    final viaBank = bankInns.contains(l.counterpartyInn);
    final counterparty = viaBank
        ? null
        : counterpartyByInn[l.counterpartyInn] ??
              counterpartyByName[_norm(l.counterpartyName)];
    String? category;
    if (counterparty != null) {
      category = recent
          .where(
            (op) =>
                op.counterpartyId == counterparty.id &&
                op.type == l.type &&
                op.categoryId != null,
          )
          .firstOrNull
          ?.categoryId;
    }
    final merchant = cardMerchant(l.purpose);
    if (category == null && merchant != null) {
      category = recent
          .where(
            (op) =>
                op.type == l.type &&
                op.categoryId != null &&
                cardMerchant(op.description ?? '') == merchant,
          )
          .firstOrNull
          ?.categoryId;
    }
    // Иначе — тот же смысл назначения платежа (первые слова без цифр):
    // «Плата за пакет услуг…», «Комиссия за…» — после первой загрузки.
    final sign = purposeSignature(l.purpose);
    if (category == null && sign.isNotEmpty) {
      category = recent
          .where(
            (op) =>
                op.type == l.type &&
                op.categoryId != null &&
                op.source == OperationSource.bank &&
                purposeSignature(op.description ?? '') == sign,
          )
          .firstOrNull
          ?.categoryId;
    }
    return BankLineMatch(
      l,
      BankLineStatus.fresh,
      categoryId: category,
      counterpartyId: counterparty?.id,
      own: own,
    );
  }

  return [for (final l in lines) decide(l)];
}

/// Операция из строки выписки: кошелёк [accountId], статья и контрагент —
/// выбранные, описание — назначение платежа (до 500 знаков). С
/// [transferAccountId] — перевод между своими кошельками: поступление —
/// «[transferAccountId] → [accountId]», списание — наоборот; без статьи и
/// контрагента.
FinOperation bankOperation({
  required String id,
  required BankLine line,
  required String accountId,
  String? categoryId,
  String? counterpartyId,
  String? transferAccountId,
  String? createdBy,
}) => FinOperation(
  id: id,
  date: line.date,
  type: transferAccountId != null ? OperationType.transfer : line.type,
  amount: line.amount,
  accountId: transferAccountId != null && line.incoming
      ? transferAccountId
      : accountId,
  toAccountId: transferAccountId == null
      ? null
      : (line.incoming ? accountId : transferAccountId),
  categoryId: transferAccountId != null ? null : categoryId,
  counterpartyId: transferAccountId != null ? null : counterpartyId,
  description: line.purpose.length > 500
      ? line.purpose.substring(0, 500)
      : line.purpose,
  source: OperationSource.bank,
  sourceRef: line.key,
  createdBy: createdBy,
);
