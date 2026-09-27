/// Почему не удалось поговорить с сервером. [message] — для человека.
sealed class SyncFailure implements Exception {
  String get message;

  /// Сбой временный: имеет смысл повторить позже (нет сети, сервер
  /// перезапускается).
  bool get isTransient;

  @override
  String toString() => '$runtimeType: $message';
}

/// Нет связи с сервером: нет сети, сервер недоступен, истекло ожидание.
class NetworkFailure extends SyncFailure {
  final Object? cause;

  NetworkFailure([this.cause]);

  @override
  String get message => 'Нет связи с сервером';

  @override
  bool get isTransient => true;
}

/// Сервер ответил ошибкой без понятного объяснения (5xx, прокси, не JSON).
class ServerFailure extends SyncFailure {
  final int? status;
  final String detail;

  ServerFailure(this.detail, {this.status});

  @override
  String get message => status != null && status! >= 500
      ? 'Сервер временно не отвечает, повторим позже'
      : 'Сервер ответил непонятно: $detail';

  @override
  bool get isTransient => status == null || status! >= 500;
}

/// Сервер отказал с объяснением: `{"error": {"code", "message"}}`.
class ApiFailure extends SyncFailure {
  final int status;
  final String code;
  @override
  final String message;

  /// Подробности (например, список расхождений при импорте).
  final List<String> details;

  ApiFailure(this.status, this.code, this.message, [this.details = const []]);

  /// Нужно войти заново (логином и паролем).
  bool get needsLogin => const {
    'session_expired',
    'token_invalid',
    'user_disabled',
  }.contains(code);

  @override
  bool get isTransient => status == 429;
}

/// На этом устройстве не выполнен вход.
class NotSignedIn extends SyncFailure {
  @override
  String get message => 'Вход на сервер не выполнен';

  @override
  bool get isTransient => false;
}
