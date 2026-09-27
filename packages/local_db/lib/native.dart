/// Локальная база в файле (Windows, Android, Dart VM): открытие файла,
/// восстановление из файловых копий, перенос старой базы v8.
library;

export 'kfh_local_db.dart';
export 'src/backup_restore.dart';
export 'src/connection/native.dart';
export 'src/migration/legacy_v8_schema.dart';
export 'src/migration/v8_converter.dart';
