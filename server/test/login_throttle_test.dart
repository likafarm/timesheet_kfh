import 'package:kfh_server/src/auth/login_throttle.dart';
import 'package:test/test.dart';

void main() {
  var now = DateTime.utc(2026, 9, 26, 10);
  late LoginThrottle throttle;

  setUp(() {
    now = DateTime.utc(2026, 9, 26, 10);
    throttle = LoginThrottle(maxFailures: 3, now: () => now);
  });

  test('после maxFailures неудач — ждать до конца окна от первой из них', () {
    for (var i = 0; i < 2; i++) {
      throttle.recordFailure('a');
      now = now.add(const Duration(minutes: 1));
    }
    expect(throttle.retryAfter('a'), isNull);
    throttle.recordFailure('a'); // 3-я в 10:02, первая была в 10:00
    expect(throttle.retryAfter('a'), const Duration(minutes: 13));
    expect(throttle.retryAfter('b'), isNull, reason: 'другой ключ не задет');
  });

  test('окно скользит: старые неудачи забываются', () {
    for (var i = 0; i < 3; i++) {
      throttle.recordFailure('a');
    }
    now = now.add(const Duration(minutes: 15));
    expect(throttle.retryAfter('a'), isNull);
    throttle.recordFailure('a');
    expect(throttle.retryAfter('a'), isNull);
  });

  test('reset после удачного входа', () {
    for (var i = 0; i < 3; i++) {
      throttle.recordFailure('a');
    }
    throttle.reset('a');
    expect(throttle.retryAfter('a'), isNull);
  });

  test('много разных ключей не копятся бесконечно', () {
    for (var i = 0; i < 10001; i++) {
      throttle.recordFailure('k$i');
    }
    now = now.add(const Duration(minutes: 16));
    throttle.recordFailure('fresh1');
    throttle.recordFailure('fresh2'); // сработает очистка
    expect(throttle.trackedKeys, lessThanOrEqualTo(2));
  });

  test('проверка без неудач не заводит ключ', () {
    for (var i = 0; i < 100; i++) {
      expect(throttle.retryAfter('random$i'), isNull);
    }
    expect(throttle.trackedKeys, 0);
  });
}
