import 'dart:typed_data';

/// Программа умеет сама поставить обновление.
bool get canInstallUpdates => false;

Future<String> saveInstaller(String fileName, Uint8List bytes) =>
    throw UnsupportedError('Установка обновлений — только в Windows');

Future<void> startInstaller(String path) =>
    throw UnsupportedError('Установка обновлений — только в Windows');

Never quitApp() => throw UnsupportedError('Только в Windows');
