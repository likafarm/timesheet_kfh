import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../sync/sync_rows.dart';
import '../version.dart';

/// Снимок всех записей базы (и удалённых) в формате обмена — для модуля
/// «Резервные копии» программы. Читается одной транзакцией: все таблицы —
/// на один момент.
Future<SnapshotFile> exportSnapshot(MySqlDatabase db, {DateTime? now}) =>
    db.transaction((conn) async {
      const rows = SyncRows();
      return SnapshotFile(
        createdAt: (now ?? DateTime.now()).toUtc(),
        source: 'server $serverVersion',
        rows: [
          for (final table in syncTables)
            ...await rows.all(conn.execute, table),
        ],
      );
    });
