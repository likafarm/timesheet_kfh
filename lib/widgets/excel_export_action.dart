// lib/widgets/excel_export_action.dart
//
// Выгрузка в Excel с экрана (этап 6.4): собрать книгу, сохранить (Windows —
// «Сохранить как», браузер — скачивание) и сообщить, где файл; в Windows —
// кнопка «Открыть».

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/file_saver.dart';
import '../services/xlsx.dart';

Future<void> exportToExcel(
  BuildContext context, {
  required String fileName,
  required Future<XlsxWorkbook> Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = (await build()).encode();
    final saved = await saveExcelFile(fileName, bytes);
    if (saved == null) return; // передумали сохранять
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          canOpenSavedFile ? 'Сохранено: $saved' : 'Файл $saved скачан',
        ),
        action: canOpenSavedFile
            ? SnackBarAction(
                label: 'Открыть',
                onPressed: () => launchUrl(Uri.file(saved)),
              )
            : null,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Не удалось выгрузить в Excel: $e')),
    );
  }
}
