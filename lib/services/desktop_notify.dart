// lib/services/desktop_notify.dart
//
// Системное уведомление Windows (6.10: напоминание о табеле и «табель
// внесён»). В браузере и на телефоне — ничего (там свои способы).

export 'desktop_notify_stub.dart'
    if (dart.library.ffi) 'desktop_notify_io.dart';
