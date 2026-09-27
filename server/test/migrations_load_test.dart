import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('kfh_migrations_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void file(String name, String content) =>
      File('${dir.path}/$name').writeAsStringSync(content);

  test('читаются по порядку номеров, прочие файлы пропускаются', () {
    file('0002_second.sql', 'SELECT 2;');
    file('0001_first.sql', 'SELECT 1;');
    file('README.md', 'не миграция');
    final migrations = loadMigrations(dir);
    expect(migrations.map((m) => m.toString()),
        ['0001_first', '0002_second']);
    expect(migrations.first.statements, ['SELECT 1']);
  });

  test('пропуск номера — ошибка', () {
    file('0001_a.sql', 'SELECT 1;');
    file('0003_c.sql', 'SELECT 3;');
    expect(() => loadMigrations(dir), throwsA(isA<MigrationException>()));
  });

  test('повтор номера — ошибка', () {
    file('0001_a.sql', 'SELECT 1;');
    file('0001_b.sql', 'SELECT 2;');
    expect(() => loadMigrations(dir), throwsA(isA<MigrationException>()));
  });

  test('имя не по образцу — ошибка', () {
    for (final name in ['1_a.sql', '0001-a.sql', '0001_Big.sql', 'x.sql']) {
      final d = Directory.systemTemp.createTempSync('kfh_migrations_');
      addTearDown(() => d.deleteSync(recursive: true));
      File('${d.path}/$name').writeAsStringSync('SELECT 1;');
      expect(() => loadMigrations(d), throwsA(isA<MigrationException>()),
          reason: name);
    }
  });

  test('файл без команд — ошибка', () {
    file('0001_empty.sql', '-- только комментарий\n');
    expect(() => loadMigrations(dir), throwsA(isA<MigrationException>()));
  });

  test('нет папки — ошибка', () {
    expect(() => loadMigrations(Directory('${dir.path}/nope')),
        throwsA(isA<MigrationException>()));
  });

  test('сумма не зависит от CRLF/LF', () {
    expect(Migration(1, 'a', 'SELECT 1;\r\nSELECT 2;\r\n').checksum,
        Migration(1, 'a', 'SELECT 1;\nSELECT 2;\n').checksum);
    expect(Migration(1, 'a', 'SELECT 1;').checksum,
        isNot(Migration(1, 'a', 'SELECT 2;').checksum));
  });

  test('миграции проекта читаются и разбираются', () {
    final migrations = loadMigrations(Directory('migrations'));
    expect(migrations, isNotEmpty);
    final first = migrations.first;
    expect(first.toString(), '0001_initial');
    final tables = first.statements
        .map((s) => RegExp(r'^CREATE TABLE (\w+)').firstMatch(s)?.group(1))
        .toList();
    expect(tables, everyElement(isNotNull),
        reason: 'в 0001 только CREATE TABLE');
    expect(tables, containsAll(['employees', 'timesheet', 'users',
        'audit_log', 'period_locks', 'change_log', 'refresh_tokens']));
  });
}
