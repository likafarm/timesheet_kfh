// lib/services/browser_storage.dart
//
// Хранилище веб-версии поверх строкового «ключ — значение» (localStorage /
// sessionStorage браузера; в тестах — память): токены входа и журнал
// синхронизации. Сам доступ к браузеру — web_string_storage.dart.

import 'dart:convert';

import 'package:kfh_sync/kfh_sync.dart';

/// Строки по ключам.
abstract interface class StringStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
  Iterable<String> keys();
}

/// Строки в памяти — для тестов.
class MemoryStringStorage implements StringStorage {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);

  @override
  Iterable<String> keys() => values.keys;
}

/// Ключи токенов в хранилище: `kfh_auth:<сервер>`.
const browserTokenPrefix = 'kfh_auth:';

/// Есть ли в хранилище вход на какой-нибудь сервер.
bool hasBrowserTokens(StringStorage storage) =>
    storage.keys().any((k) => k.startsWith(browserTokenPrefix));

/// Токены входа веб-версии.
///
/// Вход «на своём компьютере» хранится в [persistent] (localStorage — до
/// выхода или окончания срока refresh-токена), вход «на чужом компьютере» —
/// в [session] (sessionStorage — до закрытия вкладки). Обновлённые токены
/// остаются там же, где были; новый вход — туда, куда велит [remember].
class BrowserTokenStore implements TokenStore {
  final String server;
  final StringStorage persistent;
  final StringStorage session;

  /// Запомнить новый вход после закрытия вкладки.
  final bool Function() remember;

  BrowserTokenStore(
    this.server, {
    required this.persistent,
    required this.session,
    required this.remember,
  });

  String get _key => '$browserTokenPrefix$server';

  @override
  Future<AuthTokens?> read() async {
    final raw = session.read(_key) ?? persistent.read(_key);
    if (raw == null) return null;
    try {
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final json = jsonEncode(tokens.toJson());
    final inSession = session.read(_key) != null;
    final inPersistent = persistent.read(_key) != null;
    final toSession = inSession || (!inPersistent && !remember());
    if (toSession) {
      session.write(_key, json);
      persistent.remove(_key);
    } else {
      persistent.write(_key, json);
      session.remove(_key);
    }
  }

  @override
  Future<void> clear() async {
    session.remove(_key);
    persistent.remove(_key);
  }

  /// Есть ли сохранённый вход (любой срок).
  bool get hasTokens =>
      session.read(_key) != null || persistent.read(_key) != null;
}

/// Журнал синхронизации в одной строке хранилища: не больше [maxEntries]
/// последних записей (старые отбрасываются).
class StoredSyncJournal implements SyncJournal {
  final StringStorage storage;
  final String key;
  final int maxEntries;

  StoredSyncJournal(
    this.storage, {
    this.key = 'kfh_sync_journal',
    this.maxEntries = 300,
  });

  List<Object?> _readAll() {
    final raw = storage.read(key);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw);
      return json is List ? json : [];
    } on Object {
      return [];
    }
  }

  @override
  Future<void> add(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;
    final all = [..._readAll(), for (final e in entries) e.toJson()];
    final kept = all.length > maxEntries
        ? all.sublist(all.length - maxEntries)
        : all;
    storage.write(key, jsonEncode(kept));
  }

  @override
  Future<List<JournalEntry>> recent({int limit = 200}) async {
    final result = <JournalEntry>[];
    for (final json in _readAll().reversed) {
      if (result.length >= limit) break;
      try {
        result.add(JournalEntry.fromJson(json as Map<String, Object?>));
      } on Object {
        // испорченная запись — пропускаем
      }
    }
    return result;
  }

  void clear() => storage.remove(key);
}
