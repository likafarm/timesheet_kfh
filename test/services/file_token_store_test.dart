import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/services/dpapi_token_store.dart';
import 'package:kfx_time_tracking/services/file_token_store.dart';
import 'package:kfx_time_tracking/services/platform.dart';
import 'package:path/path.dart' as p;

AuthTokens _tokens(String n) => AuthTokens(
  accessToken: 'access-$n',
  accessExpiresAt: DateTime.utc(2026, 9, 27, 10),
  refreshToken: 'refresh-$n',
  refreshExpiresAt: DateTime.utc(2026, 10, 27),
  user: const SessionUser(
    uuid: '01900000-0000-7000-8000-000000000002',
    login: 'oper',
    fullName: 'Пётр Петров',
    role: 'operator',
  ),
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_auth');
  });
  tearDown(() async {
    debugIsAndroidOverride = null;
    await dir.delete(recursive: true);
  });

  test('без шифрования: токены по серверам, пустой файл удаляется', () async {
    final file = File(p.join(dir.path, 'sync_auth.json'));
    final a = FileTokenStore(file, 'https://a.ru');
    final b = FileTokenStore(file, 'https://b.ru');
    await a.write(_tokens('1'));
    await b.write(_tokens('2'));
    expect((await a.read())!.refreshToken, 'refresh-1');
    expect((await b.read())!.user.role, 'operator');
    await a.clear();
    expect(await a.read(), isNull);
    await b.clear();
    expect(await file.exists(), isFalse);
  });

  test('хранилище платформы: Android — личный файл, Windows — DPAPI', () {
    debugIsAndroidOverride = true;
    final android = platformTokenStore(dir.path, 'https://a.ru');
    expect(android, isA<FileTokenStore>());
    expect(android, isNot(isA<DpapiTokenStore>()));
    expect(p.basename((android as FileTokenStore).file.path), 'sync_auth.json');

    debugIsAndroidOverride = false;
    final windows = platformTokenStore(dir.path, 'https://a.ru');
    expect(windows, isA<DpapiTokenStore>());
    expect(p.basename((windows as FileTokenStore).file.path), 'sync_auth.dat');
  });
}
