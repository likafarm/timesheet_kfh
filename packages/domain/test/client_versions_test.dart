import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  test('сравнение версий: по числам, номер сборки не влияет', () {
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('1.3.0+5', '1.3.0'), 0);
    expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    expect(
      () => compareVersions('1.2', '1.2.0'),
      throwsA(isA<ClientVersionsFormatException>()),
    );
  });

  test('чтение и проверки', () {
    final v = ClientVersions.fromJson({
      'platforms': {
        'android': {
          'latest': '1.3.0',
          'min': '1.3.0',
          'url': 'https://tab.example.ru/download/kfh-1.3.0.apk',
          'sha256': 'abc',
        },
        'windows': {'latest': '1.3.0', 'min': '1.2.0'},
      },
    });
    final android = v.platforms['android']!;
    expect(android.requiresUpdate('1.2.9+4'), isTrue);
    expect(android.requiresUpdate('1.3.0+6'), isFalse);
    expect(v.platforms['windows']!.hasUpdate('1.2.0'), isTrue);
    expect(v.platforms['windows']!.requiresUpdate('1.2.0'), isFalse);
    expect(ClientVersions.fromJson(v.toJson()).toJson(), v.toJson());
  });

  test('ошибки формата', () {
    for (final bad in [
      <String, Object?>{},
      {'platforms': 1},
      {
        'platforms': {
          'android': {'latest': '1.3', 'min': '1.3.0'},
        },
      },
      {
        'platforms': {
          'android': {'latest': '1.3.0', 'min': '1.4.0'},
        },
      },
      {
        'platforms': {
          'android': {'latest': '1.3.0', 'min': '1.3.0', 'url': 5},
        },
      },
    ]) {
      expect(
        () => ClientVersions.fromJson(bad),
        throwsA(isA<ClientVersionsFormatException>()),
        reason: '$bad',
      );
    }
  });
}
