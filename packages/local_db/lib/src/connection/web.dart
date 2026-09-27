import 'package:drift/wasm.dart';

import '../database.dart';

/// Браузер не даёт хранить базу между запусками (частный режим, запрет
/// хранения данных сайтов): работать в такой базе нельзя — всё пропадёт
/// при закрытии вкладки.
class WebStorageUnavailable implements Exception {
  final String details;
  const WebStorageUnavailable(this.details);

  @override
  String toString() =>
      'Браузер не разрешает этому сайту хранить данные ($details). '
      'Выйдите из режима инкогнито или разрешите сайту хранение данных.';
}

/// Открытая в браузере база.
class WebDatabase {
  final LocalDatabase db;

  /// Где хранится: `opfsLocks`, `opfsShared`, `sharedIndexedDb`,
  /// `unsafeIndexedDb` — для журнала и раздела «Сервер».
  final String storage;

  const WebDatabase(this.db, this.storage);
}

/// Открывает базу [name] в браузере (drift WASM: OPFS или IndexedDB — что
/// лучшее даёт браузер). [sqlite3Uri] и [driftWorkerUri] — файлы из `web/`
/// строго тех версий sqlite3 и drift, что у приложения.
///
/// База в памяти вместо хранилища — [WebStorageUnavailable].
Future<WebDatabase> openWebDatabase({
  required String name,
  required Uri sqlite3Uri,
  required Uri driftWorkerUri,
  DateTime Function()? clock,
}) async {
  final result = await WasmDatabase.open(
    databaseName: name,
    sqlite3Uri: sqlite3Uri,
    driftWorkerUri: driftWorkerUri,
  );
  final chosen = result.chosenImplementation;
  if (chosen == WasmStorageImplementation.inMemory) {
    await result.resolvedExecutor.close();
    throw WebStorageUnavailable(
      result.missingFeatures.map((f) => f.name).join(', '),
    );
  }
  return WebDatabase(
    LocalDatabase(result.resolvedExecutor, clock: clock),
    chosen.name,
  );
}

/// Стирает базу [name] во всех хранилищах браузера. База должна быть
/// закрыта.
Future<void> deleteWebDatabase({
  required String name,
  required Uri sqlite3Uri,
  required Uri driftWorkerUri,
}) async {
  final probe = await WasmDatabase.probe(
    sqlite3Uri: sqlite3Uri,
    driftWorkerUri: driftWorkerUri,
    databaseName: name,
  );
  for (final existing in probe.existingDatabases) {
    if (existing.$2 == name) await probe.deleteDatabase(existing);
  }
}
