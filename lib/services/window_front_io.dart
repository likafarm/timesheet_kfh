import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Класс главного окна Flutter (windows/runner/win32_window.cpp).
const _windowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

/// Выводит главное окно этой программы на передний план. Windows разрешает
/// это только потоку, связанному с текущим активным окном, — поэтому поток
/// ненадолго присоединяется к потоку активного окна (AttachThreadInput).
/// Ошибки не страшны: окно просто останется, где было.
void bringWindowToFront() {
  if (!Platform.isWindows) return;
  try {
    final hwnd = ownFlutterWindow();
    if (hwnd == null) return;
    if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
    final foreground = GetForegroundWindow();
    final ours = GetCurrentThreadId();
    final theirs = foreground.address == 0
        ? 0
        : GetWindowThreadProcessId(foreground, null);
    final attach = theirs != 0 && theirs != ours;
    if (attach) AttachThreadInput(ours, theirs, true);
    try {
      // Поверх всех и сразу обратно — окно встаёт наверх, но не «прилипает».
      final flags = SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW;
      SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, flags);
      SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, flags);
      BringWindowToTop(hwnd);
      SetForegroundWindow(hwnd);
    } finally {
      if (attach) AttachThreadInput(ours, theirs, false);
    }
  } catch (_) {
    // Не удалось — не мешает работе.
  }
}

/// Главное окно этой программы: окно класса Flutter с нашим id процесса
/// (null — не нашлось).
HWND? ownFlutterWindow() => using((arena) {
  final pid = GetCurrentProcessId();
  final cls = _windowClass.toPcwstr(allocator: arena);
  final owner = arena<Uint32>();
  HWND? after;
  for (var i = 0; i < 64; i++) {
    final hwnd = FindWindowEx(null, after, cls, null).value;
    if (hwnd.address == 0) return null;
    GetWindowThreadProcessId(hwnd, owner);
    if (owner.value == pid) return hwnd;
    after = hwnd;
  }
  return null;
});
