// lib/services/reminder.dart
//
// Напоминание о табеле (6.10, решения владельца 2026-09-30):
// - каждый день, выходные тоже; оператору — в 19:00, админу — в 19:20,
//   бухгалтеру — нет;
// - в час напоминания программа спрашивает сервер, что внесено за сегодня
//   (`GET /timesheet/day`): внёс кто-то другой — «Табель за сегодня внесён
//   тем-то: …»; не внесено — «заполните табель» (на телефоне — окно на весь
//   экран поверх блокировки, ввод — после разблокировки); всё внёс сам —
//   ничего; нет связи — обычное напоминание;
// - телефон: будильники Android (MainActivity.kt, Reminder.kt), программа
//   может быть закрыта — тогда проверку делает [reminderCheck] без окна;
//   Windows и веб: пока программа открыта — таймер; Windows — уведомление
//   в углу экрана и плашка, веб — плашка.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/sync_provider.dart';
import 'app_keys.dart';
import 'desktop_notify.dart';
import 'file_token_store.dart';
import 'platform.dart';

/// Время напоминания по роли; бухгалтеру (и без входа) — null.
({int hour, int minute})? defaultReminderTime(String? role) => switch (role) {
  'operator' => (hour: 19, minute: 0),
  'admin' => (hour: 19, minute: 20),
  _ => null,
};

/// Настройки напоминания на этом устройстве.
class ReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    this.enabled = true,
    this.hour = 19,
    this.minute = 0,
  });

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Моменты напоминаний на [days] дней вперёд (каждый день), ещё не
/// наступившие; сегодня — нет, если отложено «Сегодня не нужно» ([skipDay]).
List<DateTime> reminderTimes({
  required DateTime now,
  required ReminderSettings settings,
  DateTime? skipDay,
  int days = 30,
}) {
  if (!settings.enabled) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final times = <DateTime>[];
  for (var i = 0; i < days; i++) {
    if (i == 0 && skipDay == today) continue;
    final day = addCalendarDays(today, i);
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      settings.hour,
      settings.minute,
    );
    if (at.isAfter(now)) times.add(at);
  }
  return times;
}

/// Что показать в час напоминания.
enum ReminderKind {
  /// Ничего: всё внёс сам.
  none,

  /// «Заполните табель».
  remind,

  /// «Табель за сегодня внесён тем-то».
  entered,
}

typedef ReminderDecision = ({ReminderKind kind, String title, String text});

/// Решение по табелю дня [day] для пользователя [userUuid]; [day] = null —
/// сервер не ответил.
ReminderDecision decideReminder(TimesheetDayInfo? day, String userUuid) {
  const remind = (
    kind: ReminderKind.remind,
    title: 'Табель за сегодня',
    text: 'Пора отметить, кто сегодня работал',
  );
  if (day == null) return remind;
  final entered = enteredByOthersMessage(day, userUuid);
  if (entered != null) {
    return (
      kind: ReminderKind.entered,
      title: entered.title,
      text: entered.text,
    );
  }
  if (day.filled) return (kind: ReminderKind.none, title: '', text: '');
  return remind;
}

/// Проверка без окна программы (Android, программа закрыта): запускает
/// Reminder.kt в отдельном движке Flutter. Вход и адрес сервера — те, что
/// сохранила программа ([Reminders.reschedule]).
@pragma('vm:entry-point')
Future<void> reminderCheck() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ru.korovatech.kfh/reminder_check');
  ReminderDecision decision;
  try {
    decision = await _headlessDecision();
  } catch (e) {
    debugPrint('Проверка напоминания: $e');
    decision = decideReminder(null, '');
  }
  await channel.invokeMethod<void>('result', {
    'kind': decision.kind.name,
    'title': decision.title,
    'text': decision.text,
  });
}

Future<ReminderDecision> _headlessDecision() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(Reminders._kContext);
  if (raw == null) return decideReminder(null, '');
  final ctx = jsonDecode(raw) as Map<String, Object?>;
  final server = ctx['server'] as String;
  final user = ctx['user'] as String;
  final dataDir = await appDataDirectory();
  final api = KfhApiClient(
    baseUrl: Uri.parse(server),
    deviceId: ctx['device'] as String,
    tokens: FileTokenStore(File(p.join(dataDir, 'sync_auth.json')), server),
    timeout: const Duration(seconds: 15),
  );
  try {
    final now = DateTime.now();
    final day = await api
        .timesheetDay(DateTime(now.year, now.month, now.day))
        .timeout(const Duration(seconds: 20));
    return decideReminder(day, user);
  } on Object {
    return decideReminder(null, user);
  } finally {
    api.close();
  }
}

class Reminders {
  Reminders._();
  static final instance = Reminders._();

  static const _channel = MethodChannel('ru.korovatech.kfh/reminder');
  static const _kEnabled = 'kfh_reminder_on';
  static const _kTime = 'kfh_reminder_time';
  static const _kSkip = 'kfh_reminder_skip';
  static const _kAsked = 'kfh_reminder_asked';
  static const _kContext = 'kfh_reminder_ctx';

  /// Напоминание сработало (телефон) — показать окно ввода.
  final requests = ValueNotifier<int>(0);

  SyncProvider? _sync;
  Timer? _desktopTimer;
  bool _initialized = false;

  /// Открыть табель из плашки (Windows, веб) — задаёт главное окно.
  VoidCallback? onOpenTimesheet;

  bool get _android => isAndroidApp;

  /// Роль вошедшего, которой положено напоминание.
  String? get _role {
    final user = _sync?.user;
    if (user == null || _sync?.phase != SyncPhase.ready) return null;
    return defaultReminderTime(user.role) == null ? null : user.role;
  }

  /// Можно ли настроить напоминание здесь (оператор, админ).
  bool get available => _role != null;

  void _init() {
    if (!_android || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'reminder':
          requests.value++;
        // Программа открыта — проверку делает она (тот же вход).
        case 'check':
          final d = await _decide();
          return {'kind': d.kind.name, 'title': d.title, 'text': d.text};
      }
      return null;
    });
  }

  /// Вызов Android; нет ответа (тесты, сбой) — null.
  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Напоминание: $method — $e');
      return null;
    }
  }

  /// Напоминание открыло программу до того, как её окно было готово.
  Future<bool> takePending() async => await _call<bool>('takePending') ?? false;

  /// Главное окно открыто: переставлять напоминания при смене входа.
  Future<void> attach(SyncProvider sync) async {
    _init();
    _sync?.removeListener(_changed);
    _sync = sync..addListener(_changed);
    await reschedule();
    if (!_android || !available) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kAsked) ?? false)) {
        await prefs.setBool(_kAsked, true);
        await _call<void>('requestNotifications');
      }
    } catch (_) {
      // Нет хранилища (тесты).
    }
  }

  void detach(SyncProvider sync) {
    if (_sync != sync) return;
    sync.removeListener(_changed);
    _sync = null;
    _desktopTimer?.cancel();
  }

  String? _scheduledFor;

  void _changed() {
    // Сменились вход или роль — переставить.
    final key = '${_sync?.user?.uuid}:$_role';
    if (key == _scheduledFor) return;
    reschedule();
  }

  Future<ReminderSettings> settings() async {
    final base = defaultReminderTime(_role) ?? (hour: 19, minute: 0);
    try {
      final prefs = await SharedPreferences.getInstance();
      final time = prefs.getString('${_kTime}_$_role')?.split(':');
      return ReminderSettings(
        enabled: prefs.getBool('${_kEnabled}_$_role') ?? true,
        hour: int.tryParse(time?.first ?? '') ?? base.hour,
        minute: int.tryParse(time?.last ?? '') ?? base.minute,
      );
    } catch (_) {
      return ReminderSettings(hour: base.hour, minute: base.minute);
    }
  }

  Future<void> saveSettings(ReminderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_kEnabled}_$_role', s.enabled);
    await prefs.setString('${_kTime}_$_role', s.timeText);
    await reschedule();
  }

  /// Переставить напоминания по роли и настройкам.
  Future<void> reschedule() async {
    final sync = _sync;
    final role = _role;
    _scheduledFor = '${sync?.user?.uuid}:$role';
    var times = const <DateTime>[];
    if (sync != null && role != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final skip = prefs.getString(_kSkip);
        times = reminderTimes(
          now: DateTime.now(),
          settings: await settings(),
          skipDay: skip == null ? null : parseDateIso(skip),
        );
        if (_android) {
          // Для проверки без окна программы.
          await prefs.setString(
            _kContext,
            jsonEncode({
              'server': sync.server,
              'device': await sync.deviceId(),
              'user': sync.user!.uuid,
            }),
          );
        }
      } catch (e) {
        debugPrint('Напоминания не пересчитаны: $e');
        return;
      }
    }
    if (_android) {
      await _call<void>('schedule', {
        'times': [for (final t in times) t.millisecondsSinceEpoch],
      });
    } else {
      _scheduleDesktop(times.isEmpty ? null : times.first);
    }
  }

  // ---------------------------------------------------- Windows и веб

  void _scheduleDesktop(DateTime? at) {
    _desktopTimer?.cancel();
    if (at == null) return;
    _desktopTimer = Timer(at.difference(DateTime.now()), () async {
      await _showDesktop();
      await reschedule();
    });
  }

  Future<void> _showDesktop() async {
    final d = await _decide();
    if (d.kind == ReminderKind.none) return;
    showDesktopNotification(d.title, d.text);
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: Icon(
          d.kind == ReminderKind.entered ? Icons.task_alt : Icons.alarm,
        ),
        content: Text('${d.title}\n${d.text}'),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              onOpenTimesheet?.call();
            },
            child: const Text('Открыть табель'),
          ),
        ],
      ),
    );
  }

  Future<ReminderDecision> _decide() async {
    final sync = _sync;
    final user = sync?.user;
    if (sync == null || user == null) return decideReminder(null, '');
    final now = DateTime.now();
    return decideReminder(
      await sync.timesheetDay(DateTime(now.year, now.month, now.day)),
      user.uuid,
    );
  }

  // ------------------------------------------------------ окно телефона

  Future<void> snooze([int minutes = 30]) =>
      _call<void>('snooze', {'minutes': minutes});

  /// «Сегодня не нужно».
  Future<void> skipToday() async {
    final now = DateTime.now();
    await (await SharedPreferences.getInstance()).setString(
      _kSkip,
      formatDateIso(DateTime(now.year, now.month, now.day)),
    );
    await reschedule();
  }

  /// Разрешения: уведомления и показ на весь экран.
  Future<({bool notifications, bool fullScreen})> status() async {
    final m = await _call<Map<Object?, Object?>>('status') ?? const {};
    return (
      notifications: m['notifications'] == true,
      fullScreen: m['fullScreen'] == true,
    );
  }

  Future<void> requestNotifications() => _call<void>('requestNotifications');

  Future<void> openFullScreenSettings() =>
      _call<void>('openFullScreenSettings');

  Future<bool> isLocked() async => await _call<bool>('isLocked') ?? false;

  /// Попросить разблокировать телефон; true — разблокирован.
  Future<bool> unlock() async => await _call<bool>('unlock') ?? false;

  /// Окно напоминания закрыто; [leave] — убрать программу, если её открыло
  /// напоминание.
  Future<void> done({bool leave = true}) =>
      _call<void>('done', {'leave': leave});
}
