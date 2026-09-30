import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'file_share.dart';

/// Типы файлов для окна «Сохранить как».
const _excel = XTypeGroup(
  label: 'Книга Excel',
  extensions: ['xlsx'],
  mimeTypes: [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ],
  uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
);

/// Спрашивает, куда сохранить, и записывает файл. Возвращает путь или null,
/// если человек передумал. На телефоне (6.9) — «Поделиться», null.
Future<String?> saveExcelFile(String suggestedName, Uint8List bytes) async {
  if (Platform.isAndroid) {
    await deliverFile(suggestedName, bytes, xlsxMimeType);
    return null;
  }
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [_excel],
    confirmButtonText: 'Сохранить',
  );
  if (location == null) return null;
  var path = location.path;
  if (!path.toLowerCase().endsWith('.xlsx')) path = '$path.xlsx';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

/// Сохранённый файл можно открыть из программы (сообщение «Открыть»).
const canOpenSavedFile = true;
