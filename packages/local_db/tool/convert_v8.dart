// Перенос базы v8 в v2 из командной строки — для проверки на копии
// реальной базы:
//   dart run tool/convert_v8.dart <старая.db> <новая_v2.db>
// Старый файл открывается только на чтение.

import 'dart:io';

import 'package:kfh_local_db/native.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Использование: dart run tool/convert_v8.dart <v8.db> <v2.db>',
    );
    exit(64);
  }
  try {
    final report = await convertV8ToV2(
      sourcePath: args[0],
      targetPath: args[1],
    );
    stdout.writeln('Готово: ${args[1]}');
    stdout.writeln(report);
  } on ConversionException catch (e) {
    stderr.writeln('Перенос не выполнен: $e');
    exit(1);
  }
}
