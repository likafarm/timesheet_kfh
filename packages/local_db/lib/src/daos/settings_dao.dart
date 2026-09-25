import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [CompanySettings])
class SettingsDao extends DatabaseAccessor<LocalDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<CompanySettingsRow?> getSettings() => (select(
    companySettings,
  )..where((t) => t.uuid.equals(companySettingsUuid))).getSingleOrNull();

  /// Обновляет настройки; ключ и служебные поля из [changes] игнорируются.
  Future<int> updateSettings(CompanySettingsCompanion changes) async {
    final editor = await db.deviceId();
    return (update(
      companySettings,
    )..where((t) => t.uuid.equals(companySettingsUuid))).write(
      changes.copyWith(
        uuid: const Value.absent(),
        legacyId: const Value.absent(),
        deleted: const Value.absent(),
        remoteUpdatedAt: const Value.absent(),
        updatedAt: Value(db.nowUtc()),
        editedBy: Value(editor),
      ),
    );
  }
}
