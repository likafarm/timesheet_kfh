// lib/services/page_reload.dart
//
// Перезагрузка страницы веб-версии (новая версия программы, возврат из
// другой вкладки). В программах для Windows и телефона — ничего.

export 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
