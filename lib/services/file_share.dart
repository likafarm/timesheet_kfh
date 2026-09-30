// lib/services/file_share.dart
//
// Телефон (6.9, решение владельца 2026-09-29): печать PDF и выгрузка в
// Excel — через системное «Поделиться» (почта, мессенджер, диск, печать).
//
// 6.10: сначала выбор — «Сохранить на телефон» (системное окно выбора
// папки, программа остаётся на экране) или «Отправить…». Мессенджер (MAX,
// Telegram) открывается поверх программы и после отправки сам не
// закрывается — вернуться можно кнопкой «Назад» (проверено по журналу
// Android на телефоне владельца).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/adaptive_dialog.dart';
import 'app_keys.dart';

const pdfMimeType = 'application/pdf';
const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const _files = MethodChannel('ru.korovatech.kfh/files');

enum _Delivery { save, share }

/// Отдать файл [name]: спросить, сохранить на телефон или отправить.
Future<void> deliverFile(String name, Uint8List bytes, String mimeType) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return shareFile(name, bytes, mimeType);
  final choice = await showAppDialog<_Delivery>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_alt),
            title: const Text('Сохранить на телефон'),
            subtitle: const Text('В «Загрузки» или другую папку'),
            onTap: () => Navigator.of(context).pop(_Delivery.save),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share),
            title: const Text('Отправить…'),
            subtitle: const Text(
              'В мессенджер, почту, на диск. После отправки нажмите '
              '«Назад» — вернётесь в программу.',
            ),
            onTap: () => Navigator.of(context).pop(_Delivery.share),
          ),
        ],
      ),
    ),
  );
  switch (choice) {
    case _Delivery.save:
      await _saveToPhone(name, bytes, mimeType);
    case _Delivery.share:
      await shareFile(name, bytes, mimeType);
    case null:
      return;
  }
}

Future<void> _saveToPhone(String name, Uint8List bytes, String mimeType) async {
  final messenger = appMessengerKey.currentState;
  try {
    final uri = await _files.invokeMethod<String>('saveAs', {
      'name': name,
      'mime': mimeType,
      'bytes': bytes,
    });
    if (uri == null) return; // передумали
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Сохранено: $name'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () async {
            final opened = await _files.invokeMethod<bool>('open', {
              'uri': uri,
              'mime': mimeType,
            });
            if (opened != true) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Нет программы, чтобы открыть этот файл'),
                ),
              );
            }
          },
        ),
      ),
    );
  } on PlatformException catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Не удалось сохранить: ${e.message ?? e.code}')),
    );
  }
}

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
