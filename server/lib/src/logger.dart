import 'dart:convert';
import 'dart:io';

/// Журнал сервера: одна строка JSON на событие (удобно для `docker logs`
/// и `jq`). Время — UTC ISO 8601.
class Logger {
  final void Function(String line) _write;
  final DateTime Function() _now;

  Logger({void Function(String line)? write, DateTime Function()? now})
      : _write = write ?? stdout.writeln,
        _now = now ?? DateTime.now;

  void info(String message, [Map<String, Object?> fields = const {}]) =>
      _log('info', message, fields);

  void warning(String message, [Map<String, Object?> fields = const {}]) =>
      _log('warning', message, fields);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) =>
      _log('error', message, {
        ...fields,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      });

  void _log(String level, String message, Map<String, Object?> fields) {
    _write(jsonEncode({
      'time': _now().toUtc().toIso8601String(),
      'level': level,
      'msg': message,
      ...fields,
    }, toEncodable: (value) => value.toString()));
  }
}
