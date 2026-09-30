// lib/widgets/update_install.dart
//
// Обновление Windows-версии из программы (этап 6.5): скачать установщик
// (ход загрузки), сверить SHA-256, спросить «установить сейчас?», отправить
// неотправленное, закрыть базу, запустить тихую установку и закрыться.
// Установщик заменяет файлы и открывает программу снова; база в AppData не
// меняется.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/update_download.dart';
import '../services/updater.dart';
import 'adaptive_dialog.dart';

/// Есть ли у версии всё для установки из программы: Windows, адрес и
/// контрольная сумма.
bool canInstallFrom(PlatformVersion v) =>
    canInstallUpdates && v.url != null && v.sha256 != null;

Future<void> installUpdate(BuildContext context, PlatformVersion v) async {
  final bytes = await showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(version: v),
  );
  if (bytes == null || !context.mounted) return;

  final sync = context.read<SyncProvider>();
  final app = context.read<AppProvider>();
  final pending = sync.pending;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      icon: const Icon(Icons.system_update),
      title: Text('Установить версию ${v.latest}?'),
      content: SizedBox(
        width: 440,
        child: Text(
          'Новая версия скачана и проверена. Программа закроется, '
          'установится новая версия и откроется снова — обычно это меньше '
          'минуты. Данные на этом компьютере не меняются.'
          '${pending > 0 ? '\n\nНеотправленных правок: $pending. Перед '
                    'установкой программа попробует отправить их на сервер; '
                    'если связи нет — уйдут после перезапуска.' : ''}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Установить и перезапустить'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Подготовка к установке…')),
        ],
      ),
    ),
  );
  final String path;
  try {
    path = await saveInstaller(_fileName(v), bytes);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось сохранить установщик: $e')),
    );
    return;
  }
  // Неотправленное — на сервер, пока есть возможность (сбой не мешает:
  // правки останутся в базе и уйдут после перезапуска).
  if (sync.pending > 0 && sync.phase == SyncPhase.ready) {
    await sync.syncNow().timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );
  }
  await sync.suspend();
  await app.closeDatabase();
  try {
    await startInstaller(path);
  } catch (e) {
    // База уже закрыта — работать дальше нельзя: объяснить и закрыться.
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Установщик не запустился'),
          content: Text(
            '$e\n\nПрограмма закроется. Откройте её снова и повторите '
            'обновление или установите версию ${v.latest} вручную со '
            'страницы загрузки.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть программу'),
            ),
          ],
        ),
      );
    }
  }
  quitApp();
}

String _fileName(PlatformVersion v) {
  final name = Uri.parse(v.url!).pathSegments.lastOrNull ?? '';
  return name.toLowerCase().endsWith('.exe')
      ? name
      : 'KFH_TimeTracking_Setup_${v.latest}.exe';
}

/// Загрузка с ходом; результат — проверенные байты, null — отмена или
/// ошибка (показана в окне).
class _DownloadDialog extends StatefulWidget {
  final PlatformVersion version;

  const _DownloadDialog({required this.version});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final _client = http.Client();
  int _received = 0;
  int? _total;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _error = null;
      _received = 0;
    });
    try {
      final bytes = await downloadVerified(
        _client,
        Uri.parse(widget.version.url!),
        widget.version.sha256!,
        onProgress: (received, total) {
          if (mounted && !_cancelled) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (mounted && !_cancelled) Navigator.of(context).pop(bytes);
    } on UpdateException catch (e) {
      if (mounted && !_cancelled) setState(() => _error = e.message);
    } catch (e) {
      if (mounted && !_cancelled) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final error = _error;
    return AlertDialog(
      title: Text('Загрузка версии ${widget.version.latest}'),
      content: SizedBox(
        width: 400,
        child: error != null
            ? Text(error)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: total == null || total == 0
                        ? null
                        : _received / total,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    total == null
                        ? 'Получено ${_mb(_received)} МБ'
                        : 'Получено ${_mb(_received)} из ${_mb(total)} МБ',
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            _client.close();
            Navigator.of(context).pop();
          },
          child: Text(error == null ? 'Отмена' : 'Закрыть'),
        ),
        if (error != null)
          FilledButton(onPressed: _download, child: const Text('Повторить')),
      ],
    );
  }
}
