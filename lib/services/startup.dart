// lib/services/startup.dart
//
// Запуск на своей платформе: `startPlatform()` открывает базу и собирает
// [PlatformServices]; `startupErrorHint` — что сказать, если база не
// открылась.

export 'platform_services.dart';
export 'startup_io.dart' if (dart.library.js_interop) 'startup_web.dart';
