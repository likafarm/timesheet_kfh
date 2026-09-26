import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<LocalDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(
      syncState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) => into(
    syncState,
  ).insertOnConflictUpdate(SyncStateCompanion.insert(key: key, value: value));
}
