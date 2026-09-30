// lib/services/file_saver.dart
//
// Сохранение готового файла (выгрузка в Excel, этап 6.4): в Windows — окно
// «Сохранить как», в браузере — скачивание файла.

export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
