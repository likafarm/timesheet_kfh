import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Браузер скачивает файл в папку загрузок. Возвращает имя файла.
Future<String?> saveExcelFile(String suggestedName, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = suggestedName
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Скачивание уже началось — ссылку можно освободить чуть позже.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return suggestedName;
}

/// В браузере файл открывают из загрузок.
const canOpenSavedFile = false;
