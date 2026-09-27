// Файлы базы для браузера (web/sqlite3.wasm, web/drift_worker.js) должны
// соответствовать закреплённым версиям sqlite3 и drift: при обновлении
// пакетов их пересобирает tool/web_assets.ps1.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _lockedVersion(String package) {
  final lock = File('pubspec.lock').readAsStringSync().replaceAll('\r', '');
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n|      .*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock);
  if (match == null) fail('Нет пакета $package в pubspec.lock');
  return match.group(1)!;
}

void main() {
  test('drift_worker.js собран той же версией drift', () {
    final built = File(
      'tool/web/drift_worker.version',
    ).readAsStringSync().trim();
    expect(
      built,
      _lockedVersion('drift'),
      reason: 'Пересоберите: .\\tool\\web_assets.ps1',
    );
    expect(File('web/drift_worker.js').existsSync(), isTrue);
  });

  test('sqlite3.wasm — из релиза той же версии sqlite3', () {
    final version = _lockedVersion('sqlite3');
    final script = File('tool/web_assets.ps1').readAsStringSync();
    final expected = RegExp(
      "'${RegExp.escape(version)}' = '([0-9a-f]{64})'",
    ).firstMatch(script)?.group(1);
    expect(
      expected,
      isNotNull,
      reason: 'Нет контрольной суммы для sqlite3 $version в web_assets.ps1',
    );
    final actual = sha256
        .convert(File('web/sqlite3.wasm').readAsBytesSync())
        .toString();
    expect(
      actual,
      expected,
      reason: 'Пересоберите: .\\tool\\web_assets.ps1',
    );
  });
}
