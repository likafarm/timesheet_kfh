import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/services/xlsx.dart';
import 'package:kfx_time_tracking/services/xlsx_reader.dart';

/// Чтение xlsx для загрузки выписки (8Б.6).
///
/// Настоящая выписка (только чтение):
///   KFH_BANK_XLSX=<путь к выписке> flutter test test/services/xlsx_reader_test.dart
void main() {
  test('своя книга: строки, числа, многострочный текст, пропуски', () {
    final book = XlsxWorkbook(title: 't');
    book.addSheet('Лист')
      ..addRow([XlsxCell.text('Дата проводки'), XlsxCell.text('Сумма')])
      ..addRow([
        XlsxCell.number(45658.5),
        const XlsxCell.empty(),
        XlsxCell.text('счёт\n123 & "ООО"'),
      ]);
    final rows = readXlsx(book.encode());
    expect(rows[0], ['Дата проводки', 'Сумма']);
    expect(rows[1][0], '45658.5');
    expect(rows[1][1], isNull);
    expect(rows[1][2], 'счёт\n123 & "ООО"');
  });

  test('не Excel — понятная ошибка', () {
    expect(
      () => readXlsx(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<XlsxReadException>()),
    );
  });

  final real = Platform.environment['KFH_BANK_XLSX'];
  test(
    'настоящая выписка СберБизнеса разбирается',
    () {
      final s = readBankStatement(File(real!).readAsBytesSync());
      // ignore: avoid_print
      print(
        'счёт ${s.account}; строк ${s.lines.length}; '
        'с ${s.lines.first.date} по ${s.lines.last.date}; '
        'поступлений ${s.lines.where((l) => l.incoming).length}; '
        'не разобрано: ${s.problems.length}',
      );
      expect(s.lines, isNotEmpty);
      expect(s.problems, isEmpty);
    },
    skip: real == null ? 'только с KFH_BANK_XLSX' : null,
  );
}
