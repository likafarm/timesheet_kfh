import 'dart:io';
import 'dart:math';

import 'package:kfh_sync/file_journal.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

void main() {
  group('FileSyncJournal', () {
    late Directory dir;

    setUp(
      () async => dir = await Directory.systemTemp.createTemp('kfh_journal'),
    );
    tearDown(() => dir.delete(recursive: true));

    JournalEntry entry(int n) => JournalEntry(
      at: DateTime.utc(2026, 9, 27, 10, n),
      kind: JournalKind.rejected,
      table: 'timesheet',
      uuid: 'u$n',
      code: 'period_locked',
      message: 'Табель: Месяц 08.2026 закрыт — №$n',
      local: {'date': '2026-08-0${n % 9 + 1}', 'days': 1.0},
    );

    test('записи читаются новыми сверху, кириллица цела', () async {
      final journal = FileSyncJournal(File('${dir.path}/sub/sync.log'));
      await journal.add([entry(1), entry(2)]);
      await journal.add([entry(3)]);
      final recent = await journal.recent();
      expect(recent.map((e) => e.uuid), ['u3', 'u2', 'u1']);
      expect(recent.first.message, contains('закрыт'));
      expect(recent.first.local, {'date': '2026-08-04', 'days': 1.0});
      expect(recent.first.at, DateTime.utc(2026, 9, 27, 10, 3));
      expect(await journal.recent(limit: 2), hasLength(2));
    });

    test('большой файл уходит в .1, хранится не больше двух', () async {
      final file = File('${dir.path}/sync.log');
      final journal = FileSyncJournal(file, maxBytes: 600);
      for (var n = 0; n < 12; n++) {
        await journal.add([entry(n)]);
      }
      expect(await File('${file.path}.1').exists(), isTrue);
      expect(await File('${file.path}.2').exists(), isFalse);
      final recent = await journal.recent();
      expect(recent.first.uuid, 'u11');
      expect(recent.length, lessThan(12));
    });

    test('оборванная строка пропускается', () async {
      final file = File('${dir.path}/sync.log');
      final journal = FileSyncJournal(file);
      await journal.add([entry(1)]);
      await file.writeAsString('{"at": "2026-', mode: FileMode.append);
      expect((await journal.recent()).single.uuid, 'u1');
    });

    test('нет файла — пусто', () async {
      expect(
        await FileSyncJournal(File('${dir.path}/none.log')).recent(),
        isEmpty,
      );
    });
  });

  group('Backoff', () {
    test('растёт вдвое до предела, сбрасывается', () {
      final b = Backoff(random: _Fixed(0.5)); // без разброса
      expect(
        [for (var i = 0; i < 8; i++) b.next().inSeconds],
        [5, 10, 20, 40, 80, 160, 300, 300],
      );
      expect(b.failures, 8);
      b.reset();
      expect(b.next(), const Duration(seconds: 5));
    });

    test('разброс ±20 %, но не больше предела', () {
      final low = Backoff(random: _Fixed(0));
      final high = Backoff(random: _Fixed(0.999999));
      expect(low.next(), const Duration(seconds: 4));
      expect(high.next().inMilliseconds, closeTo(6000, 1));
      for (var i = 0; i < 10; i++) {
        expect(high.next() <= const Duration(minutes: 5), isTrue);
      }
    });
  });
}

class _Fixed implements Random {
  final double value;

  _Fixed(this.value);

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}
