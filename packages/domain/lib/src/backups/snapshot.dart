// packages/domain/lib/src/backups/snapshot.dart
//
// Модуль «Резервные копии» (шаг 3 «Дальнейших работ»): снимок данных,
// сравнение снимка с тем, что есть сейчас, и план возврата записей.
//
// Любая копия — файл базы этого ПК или ежедневная выгрузка сервера —
// приводится к одному виду: все записи бизнес-таблиц в формате обмена
// ([SyncChange]). Возврат записей — обычные правки: они получают новое
// время изменения и расходятся по устройствам синхронизацией. Закрытые
// месяцы возврат не трогает ([PeriodGuard] — то же правило, что у сервера).

import '../sync/period_guard.dart';
import '../sync/sync_change.dart';
import '../sync/sync_tables.dart';

/// Таблицы, записи которых сравниваются и возвращаются. Сохранённые расчёты
/// ЗП сюда не входят: их пишет только сервер — пересчитает сам после
/// возврата табеля, ставок и выплат.
const restorableTables = <String>[
  'company_settings',
  'employees',
  'employee_rates',
  'timesheet',
  'payments',
  'sick_leave',
  'vacation',
];

/// Уникальные ключи среди живых записей (кроме uuid): у сотрудника одна
/// запись табеля на день.
const _uniqueKeys = <String, List<String>>{
  'timesheet': ['employee_uuid', 'date'],
};

/// Снимок данных: все записи бизнес-таблиц, включая удалённые.
class DataSnapshot {
  final Map<String, Map<String, SyncChange>> _tables = {
    for (final t in syncTables) t.name: {},
  };

  DataSnapshot(Iterable<SyncChange> rows) {
    for (final r in rows) {
      final table = _tables[r.table];
      if (table == null) {
        throw SyncFormatException('неизвестная таблица: ${r.table}');
      }
      table[r.uuid] = r;
    }
  }

  /// Запись (и удалённая) или null.
  SyncChange? row(String table, String uuid) => _tables[table]?[uuid];

  /// Живая (не удалённая) запись или null.
  SyncChange? live(String table, String uuid) {
    final r = row(table, uuid);
    return r == null || r.deleted ? null : r;
  }

  /// Все записи таблицы, включая удалённые.
  Iterable<SyncChange> rows(String table) => _tables[table]?.values ?? const [];

  /// Живые записи таблицы.
  Iterable<SyncChange> liveRows(String table) =>
      rows(table).where((r) => !r.deleted);

  /// Все записи снимка в порядке записи (сначала сотрудники).
  Iterable<SyncChange> get all => [for (final t in syncTables) ...rows(t.name)];

  /// Число живых записей по таблицам.
  Map<String, int> get counts => {
    for (final t in syncTables) t.name: liveRows(t.name).length,
  };
}

/// Выгрузка сервера для модуля копий: снимок всех записей на момент
/// [createdAt]. Файл — JSON, на сервере сжимается и шифруется.
class SnapshotFile {
  static const formatName = 'kfh-snapshot';
  static const formatVersion = 1;

  /// Когда снят (UTC).
  final DateTime createdAt;

  /// Кто снял: `server 0.8.0`.
  final String source;

  final List<SyncChange> rows;

  SnapshotFile({
    required DateTime createdAt,
    required this.source,
    required this.rows,
  }) : createdAt = createdAt.toUtc();

  DataSnapshot get snapshot => DataSnapshot(rows);

  Map<String, Object?> toJson() => {
    'format': formatName,
    'version': formatVersion,
    'created_at': formatSyncTimestamp(createdAt),
    'source': source,
    'rows': [for (final r in rows) r.toJson()],
  };

  /// Разбор и проверка файла; ошибка — [SyncFormatException].
  factory SnapshotFile.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['format'] != formatName) {
      throw SyncFormatException('файл не похож на выгрузку копии сервера');
    }
    if (json['version'] != formatVersion) {
      throw SyncFormatException(
        'выгрузка версии ${json['version']}, программа понимает версию '
        '$formatVersion — обновите программу',
      );
    }
    final rows = json['rows'];
    final source = json['source'];
    if (rows is! List || source is! String) {
      throw SyncFormatException('выгрузка копии повреждена');
    }
    return SnapshotFile(
      createdAt: parseSyncTimestamp(json['created_at']),
      source: source,
      rows: [for (final r in rows) SyncChange.fromJson(r)],
    );
  }
}

/// Что произошло с записью с момента копии.
enum RecordChangeKind {
  /// Записи в копии не было (или она была удалена) — добавлена позже.
  added,

  /// Запись есть и там, и там, но данные отличаются.
  changed,

  /// В копии запись была, сейчас её нет (удалена).
  removed,
}

/// Отличие одной записи: какой она была в копии и какая сейчас.
class RecordChange {
  final String table;
  final String uuid;
  final RecordChangeKind kind;

  /// Запись в копии (null — в копии её не было вовсе).
  final SyncChange? then;

  /// Запись сейчас (null — сейчас её нет вовсе).
  final SyncChange? now;

  /// Поля, которые отличаются (для [RecordChangeKind.changed]).
  final List<String> changedFields;

  const RecordChange({
    required this.table,
    required this.uuid,
    required this.kind,
    required this.then,
    required this.now,
    this.changedFields = const [],
  });

  /// Данные для показа: для добавленной — как сейчас, иначе — как в копии.
  Map<String, Object?> get data =>
      (kind == RecordChangeKind.added ? now : then)!.data;

  /// Сотрудник, к которому относится запись (у записи о самом сотруднике —
  /// он сам; у реквизитов хозяйства — null).
  String? get employeeUuid =>
      table == 'employees' ? uuid : data['employee_uuid'] as String?;

  /// Относится ли запись к месяцу: день табеля, день выплаты, период
  /// ставки, больничного или отпуска — в копии или сейчас. Сотрудники и
  /// реквизиты к месяцам не привязаны.
  bool touchesMonth(int year, int month) {
    final from = _iso(year, month, 1);
    final to = _iso(year, month, DateTime.utc(year, month + 1, 0).day);
    for (final r in [then, now]) {
      if (r == null || r.deleted) continue;
      final period = _period(table, r.data);
      if (period == null) continue;
      final (start, end) = period;
      if (start.compareTo(to) <= 0 &&
          (end == null || end.compareTo(from) >= 0)) {
        return true;
      }
    }
    return false;
  }
}

String _iso(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')}';

/// Период записи днями ISO (конец null — бессрочно); null — без дат.
(String, String?)? _period(String table, Map<String, Object?> data) {
  String day(String column) => data[column] as String;
  return switch (table) {
    'timesheet' => (day('date'), day('date')),
    'payments' => (day('payment_date'), day('payment_date')),
    'employee_rates' => (day('start_date'), data['end_date'] as String?),
    'sick_leave' || 'vacation' => (day('start_date'), day('end_date')),
    _ => null,
  };
}

/// Что изменилось с момента копии [then] до состояния [now] — по таблицам
/// [tables] в порядке записи, внутри таблицы — по дате записи.
List<RecordChange> diffSnapshots(
  DataSnapshot then,
  DataSnapshot now, {
  List<String> tables = restorableTables,
}) {
  final result = <RecordChange>[];
  for (final table in tables) {
    final columns = syncTableByName(table)!.columnNames.toList();
    final changes = <RecordChange>[];
    final uuids = {
      for (final r in then.rows(table)) r.uuid,
      for (final r in now.rows(table)) r.uuid,
    };
    for (final uuid in uuids) {
      final before = then.row(table, uuid);
      final after = now.row(table, uuid);
      final wasLive = before != null && !before.deleted;
      final isLive = after != null && !after.deleted;
      if (!wasLive && !isLive) continue;
      if (!wasLive) {
        changes.add(
          RecordChange(
            table: table,
            uuid: uuid,
            kind: RecordChangeKind.added,
            then: before,
            now: after,
          ),
        );
      } else if (!isLive) {
        changes.add(
          RecordChange(
            table: table,
            uuid: uuid,
            kind: RecordChangeKind.removed,
            then: before,
            now: after,
          ),
        );
      } else {
        final fields = [
          for (final c in columns)
            if (before.data[c] != after.data[c]) c,
        ];
        if (fields.isEmpty) continue;
        changes.add(
          RecordChange(
            table: table,
            uuid: uuid,
            kind: RecordChangeKind.changed,
            then: before,
            now: after,
            changedFields: fields,
          ),
        );
      }
    }
    changes.sort((a, b) {
      final byDay = _sortKey(a).compareTo(_sortKey(b));
      return byDay != 0 ? byDay : a.uuid.compareTo(b.uuid);
    });
    result.addAll(changes);
  }
  return result;
}

String _sortKey(RecordChange c) => _period(c.table, c.data)?.$1 ?? '';

/// Одна правка возврата: какой запись должна стать.
class RestoreEdit {
  final String table;
  final String uuid;

  /// Данные записи (все колонки таблицы).
  final Map<String, Object?> data;

  /// true — запись помечается удалённой.
  final bool deleted;

  /// Запись сейчас (null — её нет вовсе, будет создана).
  final SyncChange? current;

  /// Правку не выбирали: она нужна, чтобы освободить день табеля для
  /// возвращаемой записи.
  final bool implied;

  const RestoreEdit({
    required this.table,
    required this.uuid,
    required this.data,
    required this.deleted,
    required this.current,
    this.implied = false,
  });
}

/// Отличие, которое возврат не тронет, и почему.
class SkippedRestore {
  final RecordChange change;
  final String reason;

  const SkippedRestore(this.change, this.reason);
}

/// План возврата: правки в порядке применения и то, что пропущено.
class RestorePlan {
  final List<RestoreEdit> edits;
  final List<SkippedRestore> skipped;

  const RestorePlan(this.edits, this.skipped);

  bool get isEmpty => edits.isEmpty;
}

/// План возврата записей [changes] к состоянию копии: добавленные после
/// копии — удалить, изменённые — вернуть прежние данные, удалённые —
/// восстановить. [now] — данные сейчас, [lockedMonths] — закрытые месяцы
/// ([PeriodGuard.monthKey]): правка, задевающая закрытый месяц, пропускается
/// с объяснением.
///
/// Если день табеля возвращаемой записи сейчас занят другой записью, та
/// удаляется ([RestoreEdit.implied]); если её удалить нельзя — возврат
/// записи пропускается.
RestorePlan planRestore(
  Iterable<RecordChange> changes, {
  required DataSnapshot now,
  required Set<int> lockedMonths,
}) {
  final guard = PeriodGuard(lockedMonths);
  final edits = <String, RestoreEdit>{};
  final skipped = <SkippedRestore>[];
  String key(String table, String uuid) => '$table/$uuid';

  String? locked(RestoreEdit e) {
    final hit = guard.violation(
      e.table,
      e.current?.data,
      e.current?.deleted ?? false,
      e.data,
      e.deleted,
    );
    return hit == null ? null : PeriodLockedException(hit.$1, hit.$2).message;
  }

  final selected = changes.toList();
  final restoredEmployees = {
    for (final c in selected)
      if (c.table == 'employees' && c.kind != RecordChangeKind.added) c.uuid,
  };

  for (final c in selected) {
    if (!restorableTables.contains(c.table)) {
      skipped.add(SkippedRestore(c, 'Эти записи ведёт сервер'));
      continue;
    }
    final edit = c.kind == RecordChangeKind.added
        ? RestoreEdit(
            table: c.table,
            uuid: c.uuid,
            data: c.now!.data,
            deleted: true,
            current: c.now,
          )
        : RestoreEdit(
            table: c.table,
            uuid: c.uuid,
            data: c.then!.data,
            deleted: false,
            current: c.now,
          );
    final reason = locked(edit);
    if (reason != null) {
      skipped.add(SkippedRestore(c, reason));
      continue;
    }
    if (!edit.deleted && c.table != 'employees') {
      final employee = edit.data['employee_uuid'] as String?;
      if (employee != null &&
          now.live('employees', employee) == null &&
          !restoredEmployees.contains(employee)) {
        skipped.add(
          SkippedRestore(
            c,
            'Сотрудника этой записи сейчас нет — верните сначала его',
          ),
        );
        continue;
      }
    }
    edits[key(c.table, c.uuid)] = edit;
  }

  // Занятый день табеля: освобождаем его или отказываемся от возврата.
  for (final edit in edits.values.toList()) {
    final unique = _uniqueKeys[edit.table];
    if (unique == null || edit.deleted) continue;
    for (final other in now.liveRows(edit.table)) {
      if (other.uuid == edit.uuid ||
          unique.any((c) => other.data[c] != edit.data[c])) {
        continue;
      }
      final planned = edits[key(edit.table, other.uuid)];
      // Та запись сама удаляется или возвращается на другой день.
      if (planned != null &&
          (planned.deleted ||
              unique.any((c) => planned.data[c] != edit.data[c]))) {
        continue;
      }
      final free = RestoreEdit(
        table: edit.table,
        uuid: other.uuid,
        data: other.data,
        deleted: true,
        current: other,
        implied: true,
      );
      final reason = locked(free);
      if (reason != null || planned != null) {
        edits.remove(key(edit.table, edit.uuid));
        skipped.add(
          SkippedRestore(
            selected.firstWhere(
              (c) => c.table == edit.table && c.uuid == edit.uuid,
            ),
            reason ?? 'Этот день табеля занят другой возвращаемой записью',
          ),
        );
      } else {
        edits[key(edit.table, other.uuid)] = free;
      }
    }
  }

  // Порядок: сначала сотрудники; внутри таблицы удаления раньше записи —
  // день табеля освобождается до того, как его займёт возвращаемая запись.
  final ordered = edits.values.toList()
    ..sort((a, b) {
      final byTable = syncTableOrder(
        a.table,
      ).compareTo(syncTableOrder(b.table));
      if (byTable != 0) return byTable;
      if (a.deleted != b.deleted) return a.deleted ? -1 : 1;
      return a.uuid.compareTo(b.uuid);
    });
  return RestorePlan(ordered, skipped);
}
