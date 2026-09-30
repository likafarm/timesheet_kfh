/// Локальная база КФХ на drift: схема v2, DAO. Чистый Dart — без Flutter.
///
/// Эта библиотека работает на всех платформах. Открыть базу в файле,
/// восстановить из файловых копий и перенести старую базу v8 —
/// `native.dart` (Windows, Android, Dart VM); открыть базу в браузере —
/// `web.dart`.
library;

export 'src/backup_format.dart';
export 'src/daos/employees_dao.dart';
export 'src/daos/payments_dao.dart';
export 'src/daos/payroll_dao.dart';
export 'src/daos/rates_dao.dart';
export 'src/daos/settings_dao.dart';
export 'src/daos/sync_state_dao.dart';
export 'src/daos/timesheet_dao.dart';
export 'src/database.dart';
export 'src/raw_tables.dart';
export 'src/repositories/drift_repositories.dart';
export 'src/schema_info.dart';
export 'src/sync/local_sync_store.dart';
export 'src/sync/snapshot_restore.dart';
export 'src/sync/sync_export_builder.dart';
