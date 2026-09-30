import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Программа умеет сама поставить обновление — только Windows.
bool get canInstallUpdates => Platform.isWindows;

/// Кладёт установщик во временную папку `kfh_update` (прежние оттуда
/// удаляются). Возвращает путь.
Future<String> saveInstaller(String fileName, Uint8List bytes) async {
  final dir = Directory(p.join(Directory.systemTemp.path, 'kfh_update'));
  if (await dir.exists()) {
    await for (final f in dir.list()) {
      try {
        await f.delete(recursive: true);
      } catch (_) {
        // Занят (например, прежний установщик ещё работает) — не мешает.
      }
    }
  } else {
    await dir.create(recursive: true);
  }
  final file = File(p.join(dir.path, p.basename(fileName)));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Параметры тихой установки Inno Setup: окно хода установки без вопросов;
/// программу, если она ещё не закрылась, установщик закроет сам; после
/// установки он её запустит (installer.iss: `Check: WizardSilent`).
const installerArguments = [
  '/SILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/CLOSEAPPLICATIONS',
  '/SP-',
];

/// Запускает установщик отдельно от программы: он продолжит работу после
/// её закрытия.
Future<void> startInstaller(String path) async {
  await Process.start(
    path,
    installerArguments,
    mode: ProcessStartMode.detached,
  );
}

/// Закрыть программу (после запуска установщика).
Never quitApp() => exit(0);
