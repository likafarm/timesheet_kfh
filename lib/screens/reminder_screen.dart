// lib/screens/reminder_screen.dart
//
// Напоминание о табеле (6.10): окно на весь экран (поверх блокировки) —
// ввод за сегодня прямо здесь или переход в программу; «Через 30 минут»,
// «Сегодня не нужно». Ввод — только после разблокировки телефона (решение
// владельца 2026-09-30). Настройки — «Напоминание о табеле» в меню табеля
// (оператор, админ; правила — lib/services/reminder.dart).

import 'package:flutter/material.dart';

import '../services/reminder.dart';
import '../widgets/adaptive_dialog.dart';
import 'daily_input_screen.dart';

/// Как закрыли окно напоминания.
enum ReminderExit {
  /// Сохранено, отложено или не нужно — вернуть человека к его делам.
  close,

  /// «Открыть программу» — ввод за день в программе.
  openApp,
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with WidgetsBindingObserver {
  final _reminders = Reminders.instance;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLock();
  }

  Future<void> _checkLock() async {
    final locked = await _reminders.isLocked();
    if (mounted && locked != _locked) setState(() => _locked = locked);
  }

  Future<bool> _unlock() async {
    final ok = await _reminders.unlock();
    await _checkLock();
    return ok;
  }

  void _close([ReminderExit exit = ReminderExit.close]) =>
      Navigator.of(context).pop(exit);

  Future<void> _openApp() async {
    if (_locked && !await _unlock()) return;
    if (mounted) _close(ReminderExit.openApp);
  }

  Future<void> _snooze() async {
    await _reminders.snooze();
    if (mounted) _close();
  }

  Future<void> _skip() async {
    await _reminders.skipToday();
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Card(
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Пора отметить, кто сегодня работал',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_locked) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _unlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Разблокировать, чтобы ввести'),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: _openApp,
                  child: const Text('Открыть программу'),
                ),
                TextButton(
                  onPressed: _snooze,
                  child: const Text('Через 30 минут'),
                ),
                TextButton(
                  onPressed: _skip,
                  child: const Text('Сегодня не нужно'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return DailyInputScreen(
      initialDate: DateTime.now(),
      standalone: true,
      title: 'Табель за сегодня',
      header: header,
      inputEnabled: !_locked,
      onSaved: _close,
    );
  }
}

/// «Напоминание о табеле»: включить, время, только рабочие дни,
/// разрешения Android, проверка.
Future<void> showReminderSettings(BuildContext context) => showAppDialog<void>(
  context: context,
  builder: (_) => const _ReminderSettingsDialog(),
);

class _ReminderSettingsDialog extends StatefulWidget {
  const _ReminderSettingsDialog();

  @override
  State<_ReminderSettingsDialog> createState() =>
      _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<_ReminderSettingsDialog>
    with WidgetsBindingObserver {
  final _reminders = Reminders.instance;
  ReminderSettings? _settings;
  ({bool notifications, bool fullScreen})? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Вернулись из настроек Android — разрешения могли измениться.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final settings = await _reminders.settings();
    final status = await _reminders.status();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _status = status;
    });
  }

  Future<void> _save(ReminderSettings s) async {
    setState(() => _settings = s);
    await _reminders.saveSettings(s);
  }

  Future<void> _pickTime() async {
    final s = _settings!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
      helpText: 'Время напоминания',
    );
    if (picked == null) return;
    await _save(
      ReminderSettings(
        enabled: s.enabled,
        hour: picked.hour,
        minute: picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final status = _status;
    final warning = Theme.of(context).colorScheme.error;
    return AppDialog(
      title: const Text('Напоминание о табеле'),
      content: s == null || status == null
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Напоминать заполнить табель'),
                  value: s.enabled,
                  onChanged: (v) => _save(
                    ReminderSettings(
                      enabled: v,
                      hour: s.hour,
                      minute: s.minute,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: s.enabled,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Время'),
                  trailing: Text(
                    s.timeText,
                    style: const TextStyle(fontSize: 18),
                  ),
                  onTap: _pickTime,
                ),
                const Text(
                  'Каждый день, выходные тоже. Если табель уже внёс другой — '
                  'придёт сообщение, кто и что внёс; если всё внесли вы сами — '
                  'напоминания не будет.',
                  style: TextStyle(fontSize: 12),
                ),
                if (!status.notifications) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Уведомления программы выключены — напоминание не придёт.',
                    style: TextStyle(color: warning),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _reminders.requestNotifications();
                      await _load();
                    },
                    child: const Text('Разрешить уведомления'),
                  ),
                ],
                if (!status.fullScreen) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Показ на весь экран не разрешён — будет только '
                    'уведомление вверху экрана.',
                    style: TextStyle(color: warning),
                  ),
                  TextButton(
                    onPressed: _reminders.openFullScreenSettings,
                    child: const Text('Разрешить на весь экран'),
                  ),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: s == null || !s.enabled
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _reminders.snooze(1);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Напоминание придёт примерно через минуту — можно '
                        'заблокировать телефон',
                      ),
                    ),
                  );
                },
          child: const Text('Проверить'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
