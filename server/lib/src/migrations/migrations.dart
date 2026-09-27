import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../database.dart';
import '../logger.dart';
import '../sql.dart';
import 'sql_split.dart';

/// Ошибка миграций: сервер с ней не стартует.
class MigrationException implements Exception {
  final String message;
  MigrationException(this.message);

  @override
  String toString() => 'Ошибка миграций: $message';
}

/// Файл миграции `NNNN_имя.sql`.
class Migration {
  final int version;
  final String name;
  final String sql;

  Migration(this.version, this.name, String sql)
      // Git на Windows отдаёт файлы с CRLF, на VPS — с LF: сумма и команды
      // не должны от этого зависеть.
      : sql = sql.replaceAll('\r\n', '\n');

  /// sha256 текста — ловит правку уже применённой миграции.
  String get checksum => sha256.convert(utf8.encode(sql)).toString();

  List<String> get statements => splitSqlStatements(sql);

  @override
  String toString() => '${version.toString().padLeft(4, '0')}_$name';
}

final _fileName = RegExp(r'^(\d{4})_([a-z0-9_]+)\.sql$');

/// Читает миграции из папки. Номера — подряд с 1, без пропусков и
/// повторов; другие `.sql`-файлы — ошибка (скорее всего опечатка в имени).
List<Migration> loadMigrations(Directory dir) {
  if (!dir.existsSync()) {
    throw MigrationException('нет папки миграций ${dir.path}');
  }
  final migrations = <Migration>[];
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final fileName = entity.uri.pathSegments.last;
    if (!fileName.endsWith('.sql')) continue;
    final match = _fileName.firstMatch(fileName);
    if (match == null) {
      throw MigrationException('имя файла $fileName не по образцу '
          'NNNN_имя.sql (имя — латиница в нижнем регистре, цифры, _)');
    }
    final migration = Migration(int.parse(match.group(1)!), match.group(2)!,
        entity.readAsStringSync());
    if (migration.statements.isEmpty) {
      throw MigrationException('в $fileName нет ни одной команды');
    }
    migrations.add(migration);
  }
  migrations.sort((a, b) => a.version.compareTo(b.version));
  for (var i = 0; i < migrations.length; i++) {
    if (migrations[i].version != i + 1) {
      throw MigrationException('номера миграций должны идти подряд с 0001, '
          'а после ${i == 0 ? 'начала' : migrations[i - 1]} идёт '
          '${migrations[i]}');
    }
  }
  return migrations;
}

/// Применённая миграция (строка `schema_migrations`).
class AppliedMigration {
  final int version;
  final String name;
  final String checksum;
  final DateTime appliedAt;

  AppliedMigration(this.version, this.name, this.checksum, this.appliedAt);
}

/// Состояние базы относительно файлов миграций.
class MigrationStatus {
  final List<AppliedMigration> applied;
  final List<Migration> pending;

  /// Расхождения, при которых работать нельзя: применённая миграция
  /// изменена или её файла нет (база новее программы).
  final List<String> problems;

  MigrationStatus(this.applied, this.pending, this.problems);

  bool get isUpToDate => pending.isEmpty && problems.isEmpty;
}

/// Применяет миграции к MySQL.
///
/// Все действия — на одном соединении под именованной блокировкой MySQL:
/// два экземпляра сервера не будут мигрировать одновременно.
///
/// DDL в MySQL не откатывается: если команда упала посреди миграции, база
/// остаётся частично изменённой, миграция не отмечается применённой. Выход
/// — восстановление из копии, сделанной перед миграцией.
class MigrationRunner {
  static const lockName = 'kfh_migrations';
  static const lockTimeoutSeconds = 30;

  final MySqlDatabase db;
  final Logger logger;

  MigrationRunner(this.db, this.logger);

  Future<MigrationStatus> status(List<Migration> migrations) =>
      db.pool.withConnection((conn) => _locked(conn, () async {
            await _ensureTable(conn);
            return _status(conn, migrations);
          }));

  /// Применяет недостающие миграции; возвращает применённые сейчас.
  Future<List<Migration>> migrate(List<Migration> migrations) =>
      db.pool.withConnection((conn) => _locked(conn, () async {
            await _ensureTable(conn);
            final status = await _status(conn, migrations);
            if (status.problems.isNotEmpty) {
              throw MigrationException(status.problems.join('; '));
            }
            for (final migration in status.pending) {
              await _apply(conn, migration);
            }
            return status.pending;
          }));

  Future<void> _apply(MySQLConnection conn, Migration migration) async {
    logger.info('миграция: начало', {'migration': migration.toString()});
    final statements = migration.statements;
    for (var i = 0; i < statements.length; i++) {
      try {
        await conn.execute(statements[i]);
      } catch (e) {
        throw MigrationException('$migration: команда ${i + 1} из '
            '${statements.length} не выполнена: $e. База могла остаться '
            'частично изменённой — восстановите её из копии перед миграцией');
      }
    }
    await conn.execute(
      'INSERT INTO schema_migrations (version, name, checksum, applied_at) '
      'VALUES (:version, :name, :checksum, UTC_TIMESTAMP(6))',
      {
        'version': migration.version,
        'name': migration.name,
        'checksum': migration.checksum,
      },
    );
    logger.info('миграция: применена', {
      'migration': migration.toString(),
      'statements': statements.length,
    });
  }

  Future<MigrationStatus> _status(
      MySQLConnection conn, List<Migration> migrations) async {
    final result = await conn.execute('SELECT version, name, checksum, '
        'applied_at FROM schema_migrations ORDER BY version');
    final applied = [
      for (final row in result.rows)
        AppliedMigration(
          row.intOf('version'),
          row.textOf('name'),
          row.textOf('checksum'),
          DateTime.parse('${row.textOf('applied_at')}Z'),
        ),
    ];
    final byVersion = {for (final m in migrations) m.version: m};
    final problems = <String>[];
    for (final a in applied) {
      final file = byVersion[a.version];
      if (file == null) {
        problems.add('в базе применена миграция ${a.version} (${a.name}), '
            'которой нет в программе — база новее программы');
      } else if (file.name != a.name || file.checksum != a.checksum) {
        problems.add('миграция $file изменена после применения — '
            'правки делаются новой миграцией');
      }
    }
    final appliedVersions = {for (final a in applied) a.version};
    final pending = [
      for (final m in migrations)
        if (!appliedVersions.contains(m.version)) m,
    ];
    if (pending.isNotEmpty &&
        applied.isNotEmpty &&
        pending.first.version < applied.last.version) {
      problems.add('миграция ${pending.first} не применена, а более '
          'поздние — применены');
    }
    return MigrationStatus(applied, pending, problems);
  }

  Future<void> _ensureTable(MySQLConnection conn) async {
    await conn.execute('CREATE TABLE IF NOT EXISTS schema_migrations ('
        'version INT NOT NULL PRIMARY KEY, '
        'name VARCHAR(255) NOT NULL, '
        'checksum CHAR(64) CHARACTER SET ascii NOT NULL, '
        'applied_at DATETIME(6) NOT NULL)');
  }

  Future<T> _locked<T>(MySQLConnection conn, Future<T> Function() action) async {
    final result = await conn.execute(
        'SELECT GET_LOCK(:name, :timeout) AS got',
        {'name': lockName, 'timeout': lockTimeoutSeconds});
    if (result.rows.single.text('got') != '1') {
      throw MigrationException('миграции уже выполняет другой процесс '
          '(ждали $lockTimeoutSeconds с)');
    }
    try {
      return await action();
    } finally {
      await conn.execute('SELECT RELEASE_LOCK(:name)', {'name': lockName});
    }
  }
}
