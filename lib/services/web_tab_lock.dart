// lib/services/web_tab_lock.dart
//
// Веб-версия работает в одной вкладке браузера (Web Locks): иначе две
// вкладки синхронизировали бы одно и то же, а при хранении базы в IndexedDB
// без общего обработчика — перезаписывали бы правки друг друга. Вторая
// вкладка предлагает «работать здесь» и забирает блокировку у первой; та
// закрывает базу и показывает, что программа открыта в другой вкладке.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _lockName = 'kfh-time-tracking-tab';

/// Блокировка вкладки у этой страницы.
class TabLock {
  /// Завершается, когда блокировку забрала другая вкладка.
  final Future<void> lost;

  const TabLock(this.lost);
}

/// Берёт блокировку вкладки; null — программа открыта в другой вкладке.
/// [steal] — забрать у другой вкладки.
///
/// Браузер без Web Locks — блокировки нет (вкладки не согласуются).
Future<TabLock?> acquireTabLock({bool steal = false}) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('locks')) {
    return TabLock(Completer<void>().future);
  }

  final granted = Completer<bool>();
  final lost = Completer<void>();
  // Пока обещание не выполнено, блокировка держится — то есть всё время
  // жизни страницы.
  final hold = Completer<JSAny?>();
  JSPromise<JSAny?>? onGranted(web.Lock? lock) {
    if (lock == null) {
      granted.complete(false);
      return null;
    }
    granted.complete(true);
    return hold.future.toJS;
  }

  final request = navigator.locks.request(
    _lockName,
    steal ? web.LockOptions(steal: true) : web.LockOptions(ifAvailable: true),
    onGranted.toJS,
  );
  request.toDart.then(
    (_) {},
    onError: (Object _) {
      // Блокировку забрали (AbortError) — эта вкладка больше не работает.
      if (!granted.isCompleted) granted.complete(false);
      if (!lost.isCompleted) lost.complete();
    },
  );
  return await granted.future ? TabLock(lost.future) : null;
}

/// Перезагрузить страницу.
void reloadPage() => web.window.location.reload();
