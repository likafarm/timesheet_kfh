import 'dart:async';

import 'backoff.dart';

/// Чем кончилась попытка синхронизации — от этого зависит следующая.
enum SyncAttempt {
  /// Удалась: следующая — по обычному расписанию.
  ok,

  /// Временный сбой (нет сети, сервер не отвечает): повтор с нарастающей
  /// паузой.
  transient,

  /// Без человека не продолжить (нужен вход, смена пароля…): расписание
  /// останавливается до [SyncScheduler.resume].
  blocked,
}

/// Когда синхронизироваться автоматически (шаг 3.5):
/// - сразу после запуска ([start]);
/// - через [changeDelay] после локальной правки — пачка правок подряд
///   уходит одним прогоном ([localChanged]);
/// - раз в [interval] — принять чужие изменения;
/// - по кнопке ([runNow]) — сразу, пауза после сбоев сбрасывается.
///
/// После временного сбоя следующая попытка — через паузу [Backoff] (5 с,
/// 10 с … до 5 минут); правки в это время попытку не ускоряют — сети всё
/// равно нет. Одновременно идёт только одна попытка; триггер во время
/// попытки даёт ещё одну сразу после неё.
class SyncScheduler {
  final Future<SyncAttempt> Function() _run;
  final Duration interval;
  final Duration changeDelay;
  final Backoff backoff;

  Timer? _timer;
  DateTime? _dueAt;
  bool _running = false;
  bool _again = false;
  bool _started = false;
  bool _blocked = false;
  bool _failing = false;
  final DateTime Function() _now;

  /// Расписание изменилось (например, назначен повтор) — для интерфейса.
  final void Function()? onChanged;

  SyncScheduler(
    this._run, {
    this.interval = const Duration(minutes: 5),
    this.changeDelay = const Duration(seconds: 5),
    Backoff? backoff,
    DateTime Function()? now,
    this.onChanged,
  }) : backoff = backoff ?? Backoff(),
       _now = now ?? DateTime.now;

  bool get isStarted => _started;
  bool get isBlocked => _blocked;

  /// Следующая запланированная попытка (null — нет).
  DateTime? get nextAttemptAt => _dueAt;

  /// Запустить расписание: первая попытка — сразу.
  void start() {
    if (_started) return;
    _started = true;
    _blocked = false;
    _schedule(Duration.zero);
  }

  /// Остановить (выход, база не привязана, закрытие программы).
  void stop() {
    _started = false;
    _cancel();
  }

  /// Причина блокировки устранена (например, выполнен вход) — сразу.
  void resume() {
    _blocked = false;
    if (!_started) {
      start();
    } else {
      _schedule(Duration.zero);
    }
  }

  /// Локальная правка: отправить через [changeDelay] (новые правки
  /// откладывают отправку, пока не наступит пауза).
  void localChanged() {
    if (!_started || _blocked) return;
    if (_running) {
      _again = true;
      return;
    }
    if (_failing) return; // ждём паузы после сбоя
    _schedule(changeDelay, force: true);
  }

  /// Кнопка «Синхронизировать сейчас».
  void runNow() {
    if (!_started) return;
    _blocked = false;
    backoff.reset();
    _failing = false;
    if (_running) {
      _again = true;
      return;
    }
    _schedule(Duration.zero, force: true);
  }

  /// Запланировать попытку через [delay]; уже назначенная раньше остаётся,
  /// если не [force].
  void _schedule(Duration delay, {bool force = false}) {
    if (!_started) return;
    final due = _now().add(delay);
    if (!force && _dueAt != null && _dueAt!.isBefore(due)) return;
    _cancel();
    _dueAt = due;
    _timer = Timer(delay, _fire);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _dueAt = null;
  }

  Future<void> _fire() async {
    _timer = null;
    _dueAt = null;
    if (!_started || _running) return;
    _running = true;
    _again = false;
    SyncAttempt result;
    try {
      result = await _run();
    } catch (_) {
      result = SyncAttempt.transient;
    } finally {
      _running = false;
    }
    _after(result);
  }

  /// Синхронизацию запустили в обход расписания (кнопка, ожидающая
  /// результата): следующая попытка — по её итогу.
  void ranManually(SyncAttempt result) {
    if (_running) return; // итог учтёт идущая попытка
    if (result == SyncAttempt.ok) backoff.reset();
    _after(result);
  }

  void _after(SyncAttempt result) {
    if (!_started) return;
    switch (result) {
      case SyncAttempt.ok:
        backoff.reset();
        _failing = false;
        _blocked = false;
        _schedule(_again ? changeDelay : interval, force: true);
      case SyncAttempt.transient:
        _failing = true;
        _schedule(backoff.next(), force: true);
      case SyncAttempt.blocked:
        _blocked = true;
        _failing = false;
        _cancel();
    }
    _again = false;
    onChanged?.call();
  }

  void dispose() => stop();
}
