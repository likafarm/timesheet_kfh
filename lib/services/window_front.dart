// lib/services/window_front.dart
//
// Вывести окно программы наверх после обновления (6.5): программу, которую
// запустил тихий установщик, Windows не пускает на передний план сама — окно
// оставалось позади остальных. Установщик запускает её с `--after-update`.

export 'window_front_stub.dart' if (dart.library.ffi) 'window_front_io.dart';
