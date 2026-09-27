import 'dart:convert';
import 'dart:io';

import 'sync_journal.dart';

/// Журнал синхронизации в файле: одна запись — одна строка JSON. Когда файл
/// вырастает больше [maxBytes], он становится `<имя>.1` (прежний `.1`
/// удаляется) — хранится не больше двух файлов.
class FileSyncJournal implements SyncJournal {
  final File file;
  final int maxBytes;

  FileSyncJournal(this.file, {this.maxBytes = 1024 * 1024});

  File get _previous => File('${file.path}.1');

  @override
  Future<void> add(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;
    await file.parent.create(recursive: true);
    if (await file.exists() && await file.length() >= maxBytes) {
      if (await _previous.exists()) await _previous.delete();
      await file.rename(_previous.path);
    }
    final lines = entries.map((e) => '${jsonEncode(e.toJson())}\n').join();
    await file.writeAsString(
      lines,
      mode: FileMode.append,
      encoding: utf8,
      flush: true,
    );
  }

  @override
  Future<List<JournalEntry>> recent({int limit = 200}) async {
    final result = <JournalEntry>[];
    for (final f in [file, _previous]) {
      if (!await f.exists()) continue;
      final lines = await f.readAsLines(encoding: utf8);
      for (final line in lines.reversed) {
        if (result.length >= limit) return result;
        final entry = _parse(line);
        if (entry != null) result.add(entry);
      }
    }
    return result;
  }

  static JournalEntry? _parse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final json = jsonDecode(line);
      return json is Map<String, Object?> ? JournalEntry.fromJson(json) : null;
    } on Object {
      return null; // оборванная строка (сбой питания) — пропускаем
    }
  }
}
