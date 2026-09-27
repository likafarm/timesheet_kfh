// Выгрузка базы v2 в JSON для разового переноса на сервер (POST
// /admin/import):
//   dart run tool/export_json.dart <база_v2.db> <выгрузка.json>
// База открывается только на чтение — запускать можно и на копии, и на
// рабочей базе (но только когда программа закрыта).

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Использование: dart run tool/export_json.dart <v2.db> <out.json>');
    exit(64);
  }
  final target = File(args[1]);
  if (target.existsSync()) {
    stderr.writeln('Файл ${args[1]} уже есть — не перезаписываю');
    exit(1);
  }
  final db = LocalDatabase(NativeDatabase.opened(
      sqlite3.open(args[0], mode: OpenMode.readOnly)));
  try {
    final export = await buildSyncExport(db);
    target.writeAsStringSync(jsonEncode(export.toJson()));
    stdout.writeln('Выгружено в ${args[1]}:');
    for (final e in export.counts.entries) {
      stdout.writeln('  ${e.key}: ${e.value.$1} (удалённых ${e.value.$2})');
    }
    final months = {for (final c in export.payroll) '${c.month}.${c.year}'};
    stdout.writeln('  контроль расчёта: ${export.payroll.length} '
        '(месяцы: ${months.join(', ')})');
  } on SyncExportException catch (e) {
    stderr.writeln('Выгрузка не прошла проверку:');
    for (final p in e.problems) {
      stderr.writeln('  $p');
    }
    exit(1);
  } finally {
    await db.close();
  }
}
