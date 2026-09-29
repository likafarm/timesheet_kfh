// lib/services/platform.dart
//
// Различия платформ в одном месте: где лежат данные программы и какая это
// программа — для Windows (админ, бухгалтер) или для телефона (все роли,
// разделы — по роли, 6.9).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kfh_sync/kfh_sync.dart' show ClientKind;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Для тестов: считать программу запущенной на Android (или нет).
@visibleForTesting
bool? debugIsAndroidOverride;

/// Программа для телефона (Android).
bool get isAndroidApp =>
    debugIsAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

/// Веб-версия (этап 5).
bool get isWebApp => kIsWeb;

/// Какая это программа — для сервера (роли, версии).
ClientKind get platformClientKind => isWebApp
    ? ClientKind.web
    : isAndroidApp
    ? ClientKind.phone
    : ClientKind.desktop;

String? _dataDirectory;

/// Папка данных программы (база, журналы, токены входа):
/// - Windows — `%LOCALAPPDATA%\KFH Time Tracking`; отладочная сборка —
///   отдельная папка, чтобы `flutter run` не смешивал тестовую базу с
///   рабочей;
/// - Android — личная папка программы (другим программам недоступна;
///   у отладочной сборки свой идентификатор пакета, значит и своя папка).
Future<String> appDataDirectory() async {
  final cached = _dataDirectory;
  if (cached != null) return cached;
  final String dir;
  if (Platform.isAndroid) {
    dir = (await getApplicationSupportDirectory()).path;
  } else {
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) {
      throw StateError('Не задана переменная окружения LOCALAPPDATA');
    }
    final name = kDebugMode ? 'KFH Time Tracking (debug)' : 'KFH Time Tracking';
    dir = p.join(base, name);
  }
  return _dataDirectory = dir;
}

/// Папка резервных копий базы:
/// - Windows — `Документы\backups` (отладочная сборка — `backups (debug)`),
///   чтобы копии было легко найти и унести;
/// - Android — `backups` в личной папке программы: у оператора данные
///   хранятся на сервере, копии — только страховка на телефоне.
Future<String> backupsDirectory() async {
  if (Platform.isAndroid) return p.join(await appDataDirectory(), 'backups');
  return p.join(
    (await getApplicationDocumentsDirectory()).path,
    kDebugMode ? 'backups (debug)' : 'backups',
  );
}

/// «на этом компьютере» / «на этом телефоне» — для сообщений.
String get onThisDevice => isWebApp
    ? 'в этом браузере'
    : isAndroidApp
    ? 'на этом телефоне'
    : 'на этом компьютере';

/// «этого компьютера» / «этого телефона» — для сообщений.
String get ofThisDevice => isWebApp
    ? 'этого браузера'
    : isAndroidApp
    ? 'этого телефона'
    : 'этого компьютера';
