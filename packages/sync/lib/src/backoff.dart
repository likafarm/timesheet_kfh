import 'dart:math';

/// Нарастающая пауза между неудачными попытками: 5 с, 10 с, 20 с … до
/// 5 минут, с разбросом ±20 %, чтобы клиенты не стучались одновременно.
class Backoff {
  final Duration initial;
  final Duration max;
  final Random _random;
  int _failures = 0;

  Backoff({
    this.initial = const Duration(seconds: 5),
    this.max = const Duration(minutes: 5),
    Random? random,
  }) : _random = random ?? Random();

  int get failures => _failures;

  /// Пауза перед следующей попыткой после очередной неудачи.
  Duration next() {
    final factor = 1 << min(_failures, 20);
    _failures++;
    final base = min(initial.inMilliseconds * factor, max.inMilliseconds);
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(
      milliseconds: min((base * jitter).round(), max.inMilliseconds),
    );
  }

  /// Удачная попытка — пауза снова короткая.
  void reset() => _failures = 0;
}
