// lib/services/web_string_storage.dart
//
// localStorage и sessionStorage браузера как [StringStorage].

import 'package:web/web.dart' as web;

import 'browser_storage.dart';

class WebStringStorage implements StringStorage {
  final web.Storage storage;

  WebStringStorage(this.storage);

  WebStringStorage.local() : this(web.window.localStorage);
  WebStringStorage.session() : this(web.window.sessionStorage);

  @override
  String? read(String key) => storage.getItem(key);

  @override
  void write(String key, String value) => storage.setItem(key, value);

  @override
  void remove(String key) => storage.removeItem(key);
}
