import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'window_front_io.dart';

const _iconId = 6010;

/// Ресурс значка программы (windows/runner/resource.h, IDI_APP_ICON).
const _appIconResource = 101;

Timer? _removeIcon;

/// Уведомление в углу экрана: значок программы в области уведомлений со
/// всплывающим сообщением (Windows 10/11 показывает его как обычное
/// уведомление). Значок убирается через минуту. Ошибки не мешают работе.
void showDesktopNotification(String title, String text) {
  if (!Platform.isWindows) return;
  try {
    final hwnd = ownFlutterWindow();
    if (hwnd == null) return;
    using((arena) {
      final data = arena<NOTIFYICONDATA>();
      final module = GetModuleHandle(null).value;
      final icon = LoadIcon(
        HINSTANCE(module),
        PCWSTR(Pointer.fromAddress(_appIconResource)),
      ).value;
      data.ref
        ..cbSize = sizeOf<NOTIFYICONDATA>()
        ..hWnd = hwnd
        ..uID = _iconId
        ..uFlags = NIF_ICON | NIF_TIP | NIF_INFO
        ..hIcon = icon
        ..szTip = 'Табель КФХ'
        ..szInfoTitle = _cut(title, 63)
        ..szInfo = _cut(text, 255)
        ..dwInfoFlags = NIIF_INFO;
      Shell_NotifyIcon(NIM_DELETE, data);
      Shell_NotifyIcon(NIM_ADD, data);
    });
    _removeIcon?.cancel();
    _removeIcon = Timer(const Duration(minutes: 1), () => _remove(hwnd));
  } catch (_) {
    // Нет области уведомлений или другой сбой — останется плашка в окне.
  }
}

void _remove(HWND hwnd) {
  try {
    using((arena) {
      final data = arena<NOTIFYICONDATA>();
      data.ref
        ..cbSize = sizeOf<NOTIFYICONDATA>()
        ..hWnd = hwnd
        ..uID = _iconId;
      Shell_NotifyIcon(NIM_DELETE, data);
    });
  } catch (_) {}
}

String _cut(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';
