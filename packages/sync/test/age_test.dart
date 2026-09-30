import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

/// Расшифровка age: файлы в fixtures/age зашифрованы настоящей утилитой age
/// 1.2.1 тестовым ключом key.txt.
void main() {
  Uint8List fixture(String name) =>
      File('test/fixtures/age/$name').readAsBytesSync();
  AgeIdentity key(String name) =>
      AgeIdentity.parse(File('test/fixtures/age/$name').readAsStringSync());

  test('короткий файл', () async {
    final text = await ageDecrypt(fixture('small.age'), key('key.txt'));
    expect(utf8.decode(text), 'привет, age\n');
  });

  test('несколько блоков, ровно один блок, пустой файл', () async {
    final big = await ageDecrypt(fixture('big.age'), key('key.txt'));
    expect(big, [for (var i = 0; i < 150000; i++) i % 251]);
    final chunk = await ageDecrypt(fixture('chunk.age'), key('key.txt'));
    expect(chunk, [for (var i = 0; i < 65536; i++) i % 7]);
    expect(await ageDecrypt(fixture('empty.age'), key('key.txt')), isEmpty);
  });

  test('чужой ключ — понятный отказ', () async {
    await expectLater(
      ageDecrypt(fixture('small.age'), key('other.txt')),
      throwsA(
        isA<AgeException>().having(
          (e) => e.message,
          'message',
          contains('Ключ не подходит'),
        ),
      ),
    );
  });

  test('испорченный или оборванный файл — отказ', () async {
    final bytes = fixture('big.age');
    final damaged = Uint8List.fromList(bytes)..[bytes.length - 100] ^= 1;
    await expectLater(
      ageDecrypt(damaged, key('key.txt')),
      throwsA(isA<AgeException>()),
    );
    // Обрезан ровно по границе блока — без последнего блока.
    final cut = Uint8List.sublistView(bytes, 0, bytes.length - 18912);
    await expectLater(
      ageDecrypt(cut, key('key.txt')),
      throwsA(isA<AgeException>()),
    );
    final header = Uint8List.fromList(bytes)..[30] ^= 1;
    await expectLater(
      ageDecrypt(header, key('key.txt')),
      throwsA(isA<AgeException>()),
    );
    await expectLater(
      ageDecrypt(Uint8List.fromList('не age'.codeUnits), key('key.txt')),
      throwsA(isA<AgeException>()),
    );
  });

  test('файл ключа: комментарии, чужой текст, испорченная строка', () {
    expect(
      () => AgeIdentity.parse('# только комментарий\n'),
      throwsA(isA<AgeException>()),
    );
    expect(() => AgeIdentity.parse('age1abc\n'), throwsA(isA<AgeException>()));
    final good = File(
      'test/fixtures/age/key.txt',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('AGE-SECRET-KEY-1'));
    final broken = good.replaceRange(good.length - 1, null, 'Q');
    expect(
      () => AgeIdentity.parse(broken == good ? '${good}Q' : broken),
      throwsA(isA<AgeException>()),
    );
  });
}
