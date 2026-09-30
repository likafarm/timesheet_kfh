import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kfx_time_tracking/services/update_download.dart';
import 'package:kfx_time_tracking/services/updater_io.dart';

/// Загрузка обновления Windows (6.5): ход загрузки, сверка SHA-256 — файл
/// с другой суммой не принимается.
void main() {
  final url = Uri.parse('https://tab.example/download/Setup_1.7.0.exe');
  final file = Uint8List.fromList(List.generate(300000, (i) => i % 251));
  final sum = sha256Of(file);

  MockClient serve(List<int> body, {int status = 200, int? declaredLength}) =>
      MockClient.streaming((request, _) async {
        expect(request.url, url);
        // Отдаём кусками — как сеть.
        final chunks = [
          for (var i = 0; i < body.length; i += 65536)
            body.sublist(i, i + 65536 > body.length ? body.length : i + 65536),
        ];
        return http.StreamedResponse(
          Stream.fromIterable(chunks),
          status,
          contentLength: declaredLength ?? body.length,
        );
      });

  test('скачивается, ход загрузки растёт, сумма сходится', () async {
    final progress = <(int, int?)>[];
    final bytes = await downloadVerified(
      serve(file),
      url,
      sum.toUpperCase(), // регистр суммы не важен
      onProgress: (r, t) => progress.add((r, t)),
    );
    expect(bytes, file);
    expect(progress.length, greaterThan(1));
    expect(progress.last, (file.length, file.length));
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThan(progress[i - 1].$1));
    }
  });

  test('подменённый файл — отказ', () async {
    final other = Uint8List.fromList(file)..[100] ^= 1;
    await expectLater(
      downloadVerified(serve(other), url, sum),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('контрольной суммой'),
        ),
      ),
    );
  });

  test('сервер не отдал файл, загрузка оборвалась, нет связи', () async {
    await expectLater(
      downloadVerified(serve(const [], status: 404), url, sum),
      throwsA(
        isA<UpdateException>().having((e) => e.message, 'm', contains('404')),
      ),
    );
    await expectLater(
      downloadVerified(
        serve(file.sublist(0, 1000), declaredLength: file.length),
        url,
        sum,
      ),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'm',
          contains('оборвалась'),
        ),
      ),
    );
    final offline = MockClient((_) async => throw http.ClientException('нет'));
    await expectLater(
      downloadVerified(offline, url, sum),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'm',
          contains('Нет связи'),
        ),
      ),
    );
  });

  test('тихая установка: без вопросов, закрыть открытую программу', () {
    expect(
      installerArguments,
      containsAll(['/SILENT', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS']),
    );
    expect(
      installerArguments,
      isNot(contains('/VERYSILENT')),
      reason: 'окно хода установки видно человеку',
    );
  });
}
