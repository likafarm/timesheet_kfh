import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/services/dpapi_token_store.dart';

AuthTokens _tokens(String n) => AuthTokens(
  accessToken: 'access-$n',
  accessExpiresAt: DateTime.utc(2026, 9, 27, 10),
  refreshToken: 'refresh-secret-$n',
  refreshExpiresAt: DateTime.utc(2026, 10, 27),
  user: const SessionUser(
    uuid: '01900000-0000-7000-8000-000000000001',
    login: 'ivan',
    fullName: 'Иван Иванов',
    role: 'admin',
  ),
);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_auth');
    file = File('${dir.path}/sync_auth.dat');
  });
  tearDown(() => dir.delete(recursive: true));

  test('DPAPI: туда и обратно', () {
    final data = Uint8List.fromList([1, 2, 3, 250]);
    final enc = dpapiProtect(data);
    expect(enc, isNot(data));
    expect(dpapiUnprotect(enc), data);
    expect(
      () => dpapiUnprotect(Uint8List.fromList([1, 2, 3])),
      throwsStateError,
    );
  });

  test('токены сохраняются зашифрованными, по серверам', () async {
    final prod = DpapiTokenStore(file, 'https://tab.example.ru');
    final dev = DpapiTokenStore(file, 'http://localhost:8080');
    expect(await prod.read(), isNull);

    await prod.write(_tokens('1'));
    await dev.write(_tokens('2'));
    expect((await prod.read())!.refreshToken, 'refresh-secret-1');
    expect((await dev.read())!.user.fullName, 'Иван Иванов');

    final raw = await file.readAsBytes();
    expect(String.fromCharCodes(raw).contains('refresh-secret'), isFalse);

    await prod.clear();
    expect(await prod.read(), isNull);
    expect((await dev.read())!.accessToken, 'access-2');
    await dev.clear();
    expect(await file.exists(), isFalse);
  });

  test('испорченный файл — как будто входа не было', () async {
    await file.writeAsString('не зашифровано');
    final store = DpapiTokenStore(file, 'https://tab.example.ru');
    expect(await store.read(), isNull);
    await store.write(_tokens('3'));
    expect((await store.read())!.accessToken, 'access-3');
  });
}
