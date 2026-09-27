import 'dart:async';

import 'package:kfh_server/src/pool.dart';
import 'package:test/test.dart';

class FakeConnection {
  final int id;
  bool alive = true;
  bool closed = false;
  FakeConnection(this.id);
}

void main() {
  late List<FakeConnection> opened;
  late Future<FakeConnection> Function() open;

  ConnectionPool<FakeConnection> pool({
    int max = 2,
    Duration timeout = const Duration(seconds: 1),
  }) =>
      ConnectionPool<FakeConnection>(
        open: () => open(),
        isAlive: (c) => c.alive,
        close: (c) async => c.closed = true,
        maxConnections: max,
        acquireTimeout: timeout,
      );

  setUp(() {
    opened = [];
    open = () async {
      final c = FakeConnection(opened.length);
      opened.add(c);
      return c;
    };
  });

  test('свободное соединение используется повторно', () async {
    final p = pool();
    await p.withConnection((c) async {});
    await p.withConnection((c) async {});
    expect(opened, hasLength(1));
    expect(p.size, 1);
  });

  test('соединение возвращается и при ошибке действия', () async {
    final p = pool(max: 1);
    for (var i = 0; i < 5; i++) {
      await expectLater(
          p.withConnection((c) async => throw StateError('сбой')),
          throwsStateError);
    }
    // Если бы соединение не вернулось, здесь было бы ожидание и таймаут.
    expect(await p.withConnection((c) async => c.id), 0);
    expect(opened, hasLength(1));
  });

  test('закрытое после ошибки соединение выбрасывается, открывается новое',
      () async {
    final p = pool(max: 1);
    // База перезапустилась посреди запроса.
    await expectLater(
      p.withConnection((c) async {
        c.alive = false;
        throw StateError('connection closed');
      }),
      throwsStateError,
    );
    expect(opened.first.closed, isTrue);
    expect(p.size, 0);
    expect(await p.withConnection((c) async => c.id), 1);
  });

  test('умершее в простое соединение не выдаётся', () async {
    final p = pool();
    await p.withConnection((c) async {});
    opened.first.alive = false; // MySQL закрыл его по wait_timeout
    expect(await p.withConnection((c) async => c.id), 1);
    expect(p.size, 1);
  });

  test('не больше maxConnections, лишние ждут освобождения', () async {
    final p = pool(max: 2);
    final release = Completer<void>();
    var active = 0;
    var peak = 0;
    Future<void> job() => p.withConnection((c) async {
          active++;
          if (active > peak) peak = active;
          await release.future;
          active--;
        });
    final jobs = [for (var i = 0; i < 5; i++) job()];
    await Future<void>.delayed(Duration.zero);
    expect(peak, 2);
    release.complete();
    await Future.wait(jobs);
    expect(opened, hasLength(2));
  });

  test('все заняты дольше таймаута — TimeoutException', () async {
    final p = pool(max: 1, timeout: const Duration(milliseconds: 50));
    final release = Completer<void>();
    final busy = p.withConnection((c) => release.future);
    await expectLater(
        p.withConnection((c) async {}), throwsA(isA<TimeoutException>()));
    release.complete();
    await busy;
    // После таймаута ждущий не остался в очереди и пул работает.
    await p.withConnection((c) async {});
  });

  test('ошибка открытия не занимает место в пуле', () async {
    final p = pool(max: 1);
    final realOpen = open;
    open = () async => throw StateError('MySQL недоступна');
    await expectLater(p.withConnection((c) async {}), throwsStateError);
    expect(p.size, 0);
    open = realOpen;
    await p.withConnection((c) async {});
  });

  test('ждущий получает место, когда занятое соединение умерло', () async {
    final p = pool(max: 1);
    final release = Completer<void>();
    final first = p.withConnection((c) async {
      await release.future;
      c.alive = false;
    });
    final second = p.withConnection((c) async => c.id);
    await Future<void>.delayed(Duration.zero);
    release.complete();
    await first;
    expect(await second, 1);
  });

  test('close: свободные закрываются, ждущие и новые получают ошибку',
      () async {
    final p = pool(max: 1);
    final release = Completer<void>();
    final busy = p.withConnection((c) => release.future);
    final waiting =
        expectLater(p.withConnection((c) async {}), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await p.close();
    await waiting;
    release.complete();
    await busy;
    expect(opened.single.closed, isTrue); // занятое закрылось при возврате
    await expectLater(p.withConnection((c) async {}), throwsStateError);
    expect(p.size, 0);
  });
}
