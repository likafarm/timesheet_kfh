// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_dao.dart';

// ignore_for_file: type=lint
mixin _$SettingsDaoMixin on DatabaseAccessor<LocalDatabase> {
  $CompanySettingsTable get companySettings => attachedDatabase.companySettings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$CompanySettingsTableTableManager get companySettings =>
      $$CompanySettingsTableTableManager(
        _db.attachedDatabase,
        _db.companySettings,
      );
}
