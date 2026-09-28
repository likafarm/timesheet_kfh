/// Синхронизация клиента КФХ с сервером: HTTP-клиент API с токенами,
/// движок push/pull поверх локальной базы, журнал конфликтов.
/// Чистый Dart — без Flutter и без dart:io (файловый журнал — в
/// `package:kfh_sync/file_journal.dart`).
library;

export 'src/api_client.dart';
export 'src/backoff.dart';
export 'src/failures.dart';
export 'src/period_snapshots.dart';
export 'src/session.dart';
export 'src/sync_bootstrap.dart';
export 'src/sync_engine.dart';
export 'src/sync_journal.dart';
export 'src/sync_scheduler.dart';
export 'src/sync_transport.dart';
