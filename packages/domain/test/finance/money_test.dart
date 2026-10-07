import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  group('toKopecks', () {
    test('целые и копейки', () {
      expect(toKopecks(0), 0);
      expect(toKopecks(1), 100);
      expect(toKopecks(1234.56), 123456);
      expect(toKopecks(4466.21), 446621);
    });

    test('половина копейки — от нуля, как написано', () {
      expect(toKopecks(0.005), 1);
      expect(toKopecks(1.005), 101); // в двоичном виде 1,00499…
      expect(toKopecks(2.675), 268);
      expect(toKopecks(-0.005), -1);
      expect(toKopecks(0.0049), 0);
    });

    test('дробные суммы из Excel (цена × вес)', () {
      expect(toKopecks(1299.7 * 370), 48088900);
      expect(toKopecks(389910), 38991000);
    });
  });

  test('formatRub: разряды, копейки, минус', () {
    expect(formatRub(0), '0,00');
    expect(formatRub(5), '0,05');
    expect(formatRub(123456), '1 234,56');
    expect(formatRub(350000000000), '3 500 000 000,00');
    expect(formatRub(-100), '−1,00');
  });

  test('parseRub: ввод человека', () {
    expect(parseRub('1 234,5'), 123450);
    expect(parseRub('1234.50'), 123450);
    expect(parseRub('1 000 ₽'), 100000);
    expect(parseRub('−10'), -1000);
    expect(parseRub('0,01'), 1);
    expect(parseRub(''), isNull);
    expect(parseRub('1,234'), isNull);
    expect(parseRub('abc'), isNull);
  });

  test('toRubles — обратно в рубли', () {
    expect(toRubles(123456), 1234.56);
  });
}
