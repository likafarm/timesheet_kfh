// Общие для всех платформ понятия восстановления из копий. Само
// восстановление работает с файлами и есть только в native.dart.

/// Формат файла резервной копии.
enum BackupFormat { v8, v2 }

/// Ключ в `sync_state`: из какой копии и когда восстановлена база.
const restoredFromKey = 'restored_from';

/// Копию нельзя использовать для восстановления.
class RestoreException implements Exception {
  final String message;
  const RestoreException(this.message);

  @override
  String toString() => message;
}
