// Импорт финансов из выгрузки Excel на сервер (шаг 8.4).
//
//   cd packages/sync
//   dart run tool/import_finance.dart --json ../../docs/stage-8/private/finance25_import.json \
//     --server https://tab.korovatech.ru --login ivan [--dry-run] \
//     [--compare <сравнение.csv>]
//
// Пароль спрашивается без показа на экране (или KFH_IMPORT_PASSWORD — только
// для стенда). Сначала — проверки без сервера, затем план; запись — только
// после ответа «да». После записи свежий клиент принимает всё с сервера,
// сверяет с выгрузкой поле в поле и сравнивает табель программы с «Табелем
// 25» по месяцам (--compare — то же в CSV для Excel). Повторный запуск
// безопасен.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:http/http.dart' as http;
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';

Future<void> main(List<String> args) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final jsonPath = option('json');
  final server = option('server') ?? 'http://localhost:8080';
  final login = option('login');
  final device = option('device') ?? 'import-finance-25';
  final dryRun = args.contains('--dry-run');
  final comparePath = option('compare');
  if (jsonPath == null || login == null) {
    stderr.writeln(
      'dart run tool/import_finance.dart --json <выгрузка.json> '
      '--server <адрес> --login <админ> [--dry-run]',
    );
    exit(64);
  }

  final data = FinanceImportData.fromJson(
    jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>,
  );
  print(
    'Выгрузка: ${data.operations.length} операций, '
    '${data.accounts.length} кошельков, ${data.categories.length} статей, '
    '${data.assets.length} позиций имущества.',
  );
  final problems = data.problems();
  if (problems.isNotEmpty) {
    stderr.writeln('Выгрузка не прошла проверку — на сервер ничего не ушло:');
    problems.forEach(stderr.writeln);
    exit(1);
  }
  print('Проверка без сервера: правила и итоги Excel сходятся до копейки.');

  var password = Platform.environment['KFH_IMPORT_PASSWORD'];
  if (password == null) {
    stdout.write('Пароль $login на $server: ');
    stdin.echoMode = false;
    password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    stdout.writeln();
  }

  final api = KfhApiClient(
    baseUrl: Uri.parse(server),
    deviceId: device,
    tokens: MemoryTokenStore(),
    client: http.Client(),
  );
  await api.login(login, password);
  final user = await api.currentUser();
  if (user?.role != 'admin') {
    stderr.writeln('Импорт — только под учётной записью админа.');
    exit(1);
  }

  Future<FinanceImporter> client() async {
    final db = LocalDatabase.memory();
    final store = LocalSyncStore(db);
    final importer = FinanceImporter(
      db: db,
      store: store,
      engine: SyncEngine(
        store: store,
        transport: HttpSyncTransport(api),
        journal: MemorySyncJournal(),
      ),
      importDevice: device,
    );
    await importer.download();
    return importer;
  }

  final importer = await client();
  final plan = await importer.plan(data);
  print('\nПлан для $server:\n$plan');
  if (plan.editedElsewhere.isNotEmpty) {
    stderr.writeln('\nПосле импорта эти записи правили не импортом — стоп:');
    for (final (table, uuid, by) in plan.editedElsewhere) {
      stderr.writeln('  $table $uuid (кем: $by)');
    }
    exit(1);
  }
  if (plan.changes == 0) {
    print('\nНа сервере уже всё как в выгрузке — записывать нечего.');
  } else if (dryRun) {
    print('\n--dry-run: на сервер ничего не записано.');
    exit(0);
  } else {
    stdout.write(
      '\nЗаписать ${plan.changes} изменений на $server? '
      'Введите «да» или yes: ',
    );
    // «да» в консоли Windows может прийти в другой кодировке — yes надёжнее.
    final answer = (stdin.readLineSync() ?? '').trim().toLowerCase();
    if (answer != 'да' && answer != 'yes') {
      print('Отменено — ничего не записано.');
      exit(0);
    }
    await importer.run(data);
    print('Записано и принято сервером.');
  }

  final check = await client();
  final differences = await check.verify(data);
  if (differences.isNotEmpty) {
    stderr.writeln('\nПроверка после импорта: на сервере не как в выгрузке:');
    differences.forEach(stderr.writeln);
    exit(1);
  }
  print('\nПроверка свежим клиентом: на сервере всё как в выгрузке.');
  print(await check.summary());
  if (data.accruals.isNotEmpty) {
    final (text, csv) = formatTabelComparison(
      await check.compareWithTabel(data),
    );
    print('\nСравнение с «Табелем 25»:$text');
    if (comparePath != null) {
      // BOM — чтобы Excel открыл кириллицу.
      File(comparePath).writeAsStringSync('﻿$csv');
      print('Сравнение в CSV: $comparePath');
    }
  }
  exit(0);
}
