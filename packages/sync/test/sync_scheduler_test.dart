import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

/// Попытки: время (от начала, в секундах) и что вернуть.
class _Runs {
  final FakeAsync async;
  final DateTime start;
  final times = <int>[];
  final results = <SyncAttempt>[];
  Duration took = Duration.zero;

  _Runs(this.async, this.start);

  Future<SyncAttempt> call() async {
    times.add(async.getClock(start).now().difference(start).inSeconds);
    if (took > Duration.zero) await Future<void>.delayed(took);
    return results.isEmpty ? SyncAttempt.ok : results.removeAt(0);
  }
}

class _Middle implements Random {
  @override
  double nextDouble() => 0.5; // без разброса
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

void main() {
  final t0 = DateTime(2026, 9, 27, 10);

  SyncScheduler scheduler(FakeAsync async, _Runs runs) => SyncScheduler(
    runs.call,
    backoff: Backoff(random: _Middle()),
    now: async.getClock(t0).now,
  );

  test('при запуске — сразу, дальше раз в 5 минут', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(minutes: 16));
      expect(runs.times, [0, 300, 600, 900]);
      s.stop();
      async.elapse(const Duration(minutes: 10));
      expect(runs.times, hasLength(4));
    });
  });

  test('правки подряд уходят одним прогоном через 5 с после последней', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(seconds: 10));
      s.localChanged(); // 10
      async.elapse(const Duration(seconds: 3));
      s.localChanged(); // 13
      async.elapse(const Duration(seconds: 3));
      s.localChanged(); // 16
      async.elapse(const Duration(seconds: 30));
      expect(runs.times, [0, 21]);
      // Следующая плановая — через 5 минут после последней попытки.
      async.elapse(const Duration(minutes: 5));
      expect(runs.times, [0, 21, 321]);
      s.stop();
    });
  });

  test('нет сети: паузы растут, правки их не ускоряют; сеть вернулась — '
      'обычный режим', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      runs.results.addAll(List.filled(4, SyncAttempt.transient));
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(seconds: 1));
      s.localChanged();
      async.elapse(const Duration(seconds: 100));
      // 0 → +5 → +10 → +20 → +40 (удача).
      expect(runs.times, [0, 5, 15, 35, 75]);
      async.elapse(const Duration(minutes: 5));
      expect(runs.times.last, 375);
      s.stop();
    });
  });

  test('кнопка — сразу и сбрасывает паузу', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      runs.results.addAll(List.filled(3, SyncAttempt.transient));
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(seconds: 20)); // 0, 5, 15
      expect(runs.times, [0, 5, 15]);
      s.runNow(); // 20 — удача
      async.elapse(Duration.zero);
      expect(runs.times, [0, 5, 15, 20]);
      async.elapse(const Duration(minutes: 5));
      expect(runs.times.last, 320);
      s.stop();
    });
  });

  test('нужен вход — расписание стоит до resume', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      runs.results.add(SyncAttempt.blocked);
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(minutes: 30));
      s.localChanged();
      async.elapse(const Duration(minutes: 1));
      expect(runs.times, [0]);
      expect(s.isBlocked, isTrue);
      s.resume();
      async.elapse(Duration.zero);
      expect(runs.times, [0, 1860]);
      s.stop();
    });
  });

  test('правка во время прогона — ещё один прогон после него', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0)..took = const Duration(seconds: 3);
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(seconds: 1));
      s.localChanged(); // прогон идёт
      async.elapse(const Duration(seconds: 20));
      expect(runs.times, [0, 8]); // закончился в 3, ещё через 5 с
      s.stop();
    });
  });

  test('ошибка в самой попытке считается временной', () {
    fakeAsync((async) {
      var calls = 0;
      final s = SyncScheduler(
        () async {
          calls++;
          throw StateError('сбой');
        },
        backoff: Backoff(random: _Middle()),
        now: async.getClock(t0).now,
      )..start();
      async.elapse(const Duration(seconds: 16));
      expect(calls, 3); // 0, 5, 15
      s.stop();
    });
  });

  test('ручной запуск: удача — следующая через 5 минут, сбой — пауза', () {
    fakeAsync((async) {
      final runs = _Runs(async, t0);
      final s = scheduler(async, runs)..start();
      async.elapse(const Duration(seconds: 60));
      s.ranManually(SyncAttempt.ok); // в 60
      async.elapse(const Duration(minutes: 5));
      expect(runs.times, [0, 360]);
      async.elapse(const Duration(seconds: 10)); // 370
      s.ranManually(SyncAttempt.transient);
      async.elapse(const Duration(seconds: 6));
      expect(runs.times, [0, 360, 375]);
      s.stop();
    });
  });
}
