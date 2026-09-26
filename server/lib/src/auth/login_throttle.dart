/// Защита от подбора паролей: считает неудачные входы по ключу (логин,
/// адрес) в скользящем окне. Хранится в памяти процесса — сервер один,
/// после перезапуска счёт начинается заново, и это приемлемо.
class LoginThrottle {
  final int maxFailures;
  final Duration window;
  final DateTime Function() _now;
  final _failures = <String, List<DateTime>>{};

  LoginThrottle({
    required this.maxFailures,
    this.window = const Duration(minutes: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Через сколько можно пробовать снова; null — можно сейчас.
  Duration? retryAfter(String key) {
    if (!_failures.containsKey(key)) return null;
    final times = _recent(key);
    if (times.length < maxFailures) return null;
    final wait = times[times.length - maxFailures].add(window).difference(_now());
    return wait > Duration.zero ? wait : null;
  }

  void recordFailure(String key) {
    _recent(key).add(_now());
    // Не даём карте расти бесконечно от перебора случайных логинов.
    if (_failures.length > 10000) _prune();
  }

  void reset(String key) => _failures.remove(key);

  /// Сколько ключей сейчас в памяти (для тестов).
  int get trackedKeys => _failures.length;

  List<DateTime> _recent(String key) {
    final cutoff = _now().subtract(window);
    final times = _failures.putIfAbsent(key, () => []);
    times.removeWhere((t) => !t.isAfter(cutoff));
    return times;
  }

  void _prune() {
    final cutoff = _now().subtract(window);
    _failures.removeWhere((_, times) {
      times.removeWhere((t) => !t.isAfter(cutoff));
      return times.isEmpty;
    });
  }
}
