// lib/services/file_share.dart
//
// Телефон (6.9, решение владельца 2026-09-29): печать PDF и выгрузка в
// Excel — через системное «Поделиться» (почта, мессенджер, диск, печать).

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

const pdfMimeType = 'application/pdf';
const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Отдать файл [name] системному «Поделиться».
Future<void> shareFile(String name, Uint8List bytes, String mimeType) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
      fileNameOverrides: [name],
      title: name,
    ),
  );
}
