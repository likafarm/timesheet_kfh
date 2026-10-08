// Приёмка загрузки выписки (8Б.6) на реальных данных — только чтение:
//   KFH_BANK_XLSX=<выписка.xlsx> KFH_ACCEPTANCE_DB=<копия v2.db> \
//   KFH_BANK_ACCOUNT=<название кошелька> \
//   flutter test test/acceptance/bank_statement_real_test.dart
// Печатает, сколько строк уже есть в учёте, сколько новых и у скольких
// подобрана статья. Операций не пишет; схему КОПИИ при открытии обновляет.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/services/xlsx_reader.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final xlsx = Platform.environment['KFH_BANK_XLSX'];
  final dbPath = Platform.environment['KFH_ACCEPTANCE_DB'];
  final accountName = Platform.environment['KFH_BANK_ACCOUNT'];
  test(
    'выписка против учёта',
    () async {
      final statement = readBankStatement(File(xlsx!).readAsBytesSync());
      // Только КОПИЯ: при открытии схема обновляется.
      final db = LocalDatabase(NativeDatabase(File(dbPath!)));
      try {
        final repos = DriftRepositories(db);
        final f = repos.finance;
        final accounts = await f.accounts();
        final account = accounts.firstWhere(
          (a) => a.name == accountName,
          orElse: () => throw StateError(
            'нет кошелька «$accountName»; есть: '
            '${accounts.map((a) => a.name).join(', ')}',
          ),
        );
        final catalog = FinanceCatalog(
          accounts: accounts,
          categories: await f.categories(),
          groups: await f.categoryGroups(),
          counterparties: await f.counterparties(),
          directions: await f.directions(),
        );
        final settings = await repos.settings.get();
        final matches = matchBankLines(
          lines: statement.lines,
          accountId: account.id,
          operations: await f.operations(),
          catalog: catalog,
          ownInn: settings.inn,
        );
        int count(BankLineStatus s) =>
            matches.where((m) => m.status == s).length;
        final fresh = matches.where((m) => m.status == BankLineStatus.fresh);
        // ignore: avoid_print
        print(
          'строк ${matches.length}: уже загружено '
          '${count(BankLineStatus.imported)}, найдено среди введённых '
          '${count(BankLineStatus.matched)}, новых ${fresh.length} '
          '(со статьёй-подсказкой ${fresh.where((m) => m.categoryId != null).length}, '
          'свои счета ${fresh.where((m) => m.own).length})',
        );
      } finally {
        await db.close();
      }
    },
    skip: xlsx == null || dbPath == null || accountName == null
        ? 'только с KFH_BANK_XLSX, KFH_ACCEPTANCE_DB, KFH_BANK_ACCOUNT'
        : null,
  );
}
