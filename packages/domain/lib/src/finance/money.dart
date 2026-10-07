// packages/domain/lib/src/finance/money.dart
//
// Деньги в финансах — копейки целым числом (решение владельца 2026-10-07):
// в остатках кошельков за годы ошибки округления `double` копились бы.
// Табель и выплаты пока хранят рубли в `double` — переводятся здесь.

/// Рубли → копейки: до копейки, половина копейки — от нуля
/// (0,005 → 1 коп., −0,005 → −1 коп.). Сначала до миллионной доли рубля,
/// чтобы 1,005 (в двоичном виде 1,00499…) округлялось как написано.
int toKopecks(num rubles) {
  final micro = (rubles * 1000000).round();
  final half = micro >= 0 ? 5000 : -5000;
  return (micro + half) ~/ 10000;
}

/// Копейки → рубли (для старого кода на `double`).
double toRubles(int kopecks) => kopecks / 100;

/// `1 234 567,89` — разряды через неразрывный пробел, копейки через
/// запятую, минус для отрицательных.
String formatRub(int kopecks) {
  final sign = kopecks < 0 ? '−' : '';
  final abs = kopecks.abs();
  final rub = (abs ~/ 100).toString();
  final kop = (abs % 100).toString().padLeft(2, '0');
  final groups = StringBuffer();
  for (var i = 0; i < rub.length; i++) {
    if (i > 0 && (rub.length - i) % 3 == 0) groups.write(' ');
    groups.write(rub[i]);
  }
  return '$sign$groups,$kop';
}

/// Разбор суммы из поля ввода: «1 234,5», «1234.50», «−10» → копейки;
/// null — не сумма. Больше двух знаков после запятой — не сумма.
int? parseRub(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'[\s ₽]'), '')
      .replaceAll('−', '-')
      .replaceAll(',', '.');
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
  final negative = cleaned.startsWith('-');
  final parts = cleaned.replaceFirst('-', '').split('.');
  final kop = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final value = int.parse(parts[0]) * 100 + kop;
  return negative ? -value : value;
}
