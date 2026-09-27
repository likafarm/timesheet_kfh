import 'dart:async';
import 'dart:collection';

/// Пул в `mysql_client_plus` не годится: после ошибки запроса он
/// возвращает в свободные уже закрытое соединение (после перезапуска MySQL
/// сервер больше не оживает), а `withConnection` при исключении соединение
/// не отдаёт (пул постепенно кончается). Поэтому пул свой — небольшой.
///
/// Пул обобщён по типу соединения, чтобы его можно было проверить без
/// MySQL.
class ConnectionPool<C> {
  final Future<C> Function() _open;
  final bool Function(C) _isAlive;
  final Future<void> Function(C) _close;
  final int maxConnections;

  /// Сколько ждать свободного соединения, когда заняты все.
  final Duration acquireTimeout;

  final _idle = <C>[];
  final _waiters = Queue<Completer<void>>();

  /// Все соединения пула: свободные, занятые и открываемые сейчас.
  int _count = 0;
  bool _closed = false;

  ConnectionPool({
    required this._open,
    required this._isAlive,
    required this._close,
    required this.maxConnections,
    this.acquireTimeout = const Duration(seconds: 10),
  }) {
    if (maxConnections < 1) {
      throw ArgumentError.value(maxConnections, 'maxConnections', 'меньше 1');
    }
  }

  /// Число открытых соединений (для тестов и журнала).
  int get size => _count;

  /// Выполняет [action] на соединении пула и всегда возвращает соединение
  /// (закрытое — выбрасывается, взамен при надобности откроется новое).
  Future<T> withConnection<T>(Future<T> Function(C connection) action) async {
    final connection = await _acquire();
    try {
      return await action(connection);
    } finally {
      _release(connection);
    }
  }

  /// Закрывает все свободные соединения; занятые закроются при возврате.
  /// Ждущие соединения получают ошибку.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
    final idle = List.of(_idle);
    _idle.clear();
    _count -= idle.length;
    for (final connection in idle) {
      await _closeQuietly(connection);
    }
  }

  Future<C> _acquire() async {
    final deadline = DateTime.now().add(acquireTimeout);
    while (true) {
      if (_closed) throw StateError('Пул соединений закрыт');

      while (_idle.isNotEmpty) {
        final connection = _idle.removeLast();
        if (_isAlive(connection)) return connection;
        _count--;
        unawaited(_closeQuietly(connection));
      }

      if (_count < maxConnections) {
        _count++;
        try {
          return await _open();
        } catch (_) {
          _count--;
          _wakeOne();
          rethrow;
        }
      }

      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) throw _timeout();
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future.timeout(left);
      } on TimeoutException {
        _waiters.remove(waiter);
        throw _timeout();
      }
    }
  }

  void _release(C connection) {
    if (_closed || !_isAlive(connection)) {
      _count--;
      unawaited(_closeQuietly(connection));
    } else {
      _idle.add(connection);
    }
    _wakeOne();
  }

  /// Будит одного ждущего: он заново попробует взять или открыть соединение.
  void _wakeOne() {
    if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
  }

  Future<void> _closeQuietly(C connection) async {
    try {
      await _close(connection);
    } catch (_) {
      // Соединение уже мертво — закрывать нечего.
    }
  }

  TimeoutException _timeout() => TimeoutException(
      'Нет свободного соединения с базой за ${acquireTimeout.inSeconds} с');
}
