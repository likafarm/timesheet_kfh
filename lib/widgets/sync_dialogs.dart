// lib/widgets/sync_dialogs.dart
//
// Диалоги синхронизации: вход на сервер, смена пароля, первый вход базы.

import 'package:flutter/material.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../services/platform.dart';
import 'adaptive_dialog.dart';

/// Вход и всё, что после него нужно: смена выданного пароля, первый вход
/// базы на сервер.
Future<void> startSignIn(BuildContext context) async {
  final signedIn = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const SignInDialog(),
  );
  if (signedIn == true && context.mounted) await continueSyncSetup(context);
}

/// Довести настройку до конца: сменить пароль, если требуется, и выполнить
/// первый вход базы.
Future<void> continueSyncSetup(BuildContext context) async {
  final sync = context.read<SyncProvider>();
  if (sync.phase == SyncPhase.passwordChange) {
    final changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(forced: true),
    );
    if (changed != true || !context.mounted) return;
  }
  if (sync.phase == SyncPhase.needsLink && context.mounted) {
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LinkDialog(),
    );
  }
}

/// Выход с сервера. В веб-версии выход стирает базу браузера — сначала
/// окно с предупреждением (и о неотправленных правках, если они есть).
Future<void> confirmSignOut(BuildContext context) async {
  final sync = context.read<SyncProvider>();
  if (!sync.erasesOnSignOut) {
    await sync.signOut();
    return;
  }
  final pending = sync.pending;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: const Text('Выйти?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Данные программы будут стёрты из этого браузера. На сервере '
              'они остаются — после входа придут снова.',
            ),
            if (pending > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Не отправлено на сервер: $pending. Эти правки будут '
                'потеряны. Чтобы их сохранить, отмените выход и '
                'синхронизируйте, когда будет связь.',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(pending > 0 ? 'Выйти и стереть' : 'Выйти'),
        ),
      ],
    ),
  );
  if (ok == true) await sync.signOut();
}

/// Текст ошибки под полями формы.
class _ErrorText extends StatelessWidget {
  final String? text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

// ---------------------------------------------------------------- вход

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showServer = false;
  bool _remoteConfirmed = false;
  bool _publicComputer = false;
  String? _error;

  /// Отладочная сборка и адрес не на этом компьютере — нужно согласие.
  bool get _needsRemoteConfirm {
    final sync = context.read<SyncProvider>();
    if (!sync.debugBuild) return false;
    try {
      return !SyncProvider.isLocalServer(
        SyncProvider.normalizeServer(_server.text),
      );
    } on SyncUserException {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncProvider>();
    _server = TextEditingController(text: sync.server);
    _login.text = sync.user?.login ?? '';
  }

  @override
  void dispose() {
    _server.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_needsRemoteConfirm && !_remoteConfirmed) {
      setState(() {
        _showServer = true;
        _error = 'Отметьте согласие на вход с отладочной сборки.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SyncProvider>().signIn(
        _server.text,
        _login.text,
        _password.text,
        allowRemoteInDebug: _remoteConfirmed,
        publicComputer: _publicComputer,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SyncUserException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.read<SyncProvider>();
    return AppDialog(
      title: const Text('Вход на сервер'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          // В окне 1024×768 с отметкой согласия и ошибкой — прокрутка.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAndroidApp
                      ? 'Войдите своей учётной записью: данные придут с '
                            'сервера, введённое уйдёт на сервер само, когда '
                            'будет связь. Если телефоном до вас пользовался '
                            'человек с другой ролью, данные телефона будут '
                            'приняты с сервера заново.'
                      : isWebApp
                      ? 'Войдите учётной записью администратора или '
                            'бухгалтера. Данные придут с сервера и хранятся '
                            'в этом браузере до выхода.'
                      : 'Войдите учётной записью администратора или '
                            'бухгалтера. Без входа программа не запускается; '
                            'вход сохраняется, и дальше программа работает '
                            'и без связи с сервером.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _login,
                  autofocus: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Укажите логин' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v ?? '').isEmpty ? 'Укажите пароль' : null,
                ),
                if (sync.offersPublicComputer)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _publicComputer,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _publicComputer = v ?? false),
                    title: const Text('Чужой компьютер'),
                    subtitle: const Text(
                      'Вход — до закрытия вкладки; при выходе или следующем '
                      'открытии данные будут стёрты из браузера.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                if (!sync.canChangeServer)
                  const SizedBox.shrink()
                else if (_showServer)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextFormField(
                      controller: _server,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Адрес сервера',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        try {
                          SyncProvider.normalizeServer(v ?? '');
                          return null;
                        } on SyncUserException catch (e) {
                          return e.message;
                        }
                      },
                    ),
                  )
                else
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showServer = true),
                    child: Text('Сервер: ${_server.text}'),
                  ),
                if (_needsRemoteConfirm)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _remoteConfirmed,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _remoteConfirmed = v ?? false),
                    title: const Text(
                      'Это отладочная сборка (своя база «KFH Time Tracking '
                      '(debug)»). Понимаю, что вхожу на сервер не на этом '
                      'компьютере — только для проверки, под отдельной учёткой.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                _ErrorText(_error),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Войти'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- пароль

class ChangePasswordDialog extends StatefulWidget {
  /// Пароль выдан администратором — без смены работать нельзя.
  final bool forced;

  const ChangePasswordDialog({super.key, this.forced = false});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SyncProvider>().changePassword(_old.text, _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } on SyncUserException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration field(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return AppDialog(
      title: const Text('Смена пароля'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          // В окне 1024×768 с отметкой согласия и ошибкой — прокрутка.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.forced)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Пароль выдан администратором — задайте свой. Новый '
                      'пароль — не короче 8 символов.',
                    ),
                  ),
                TextFormField(
                  controller: _old,
                  autofocus: true,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: field(
                    widget.forced ? 'Выданный пароль' : 'Текущий пароль',
                  ),
                  validator: (v) => (v ?? '').isEmpty ? 'Укажите пароль' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _new,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: field('Новый пароль'),
                  validator: (v) => (v ?? '').length < 8
                      ? 'Не короче 8 символов'
                      : v == _old.text
                      ? 'Новый пароль совпадает с прежним'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _repeat,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: field('Новый пароль ещё раз'),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _new.text ? 'Пароли не совпадают' : null,
                ),
                _ErrorText(_error),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Сменить'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- первый вход

enum _LinkStep { analyzing, plan, running, done, failed }

/// Первый вход базы на сервер: сравнение, подтверждение, выполнение.
class LinkDialog extends StatefulWidget {
  const LinkDialog({super.key});

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  _LinkStep _step = _LinkStep.analyzing;
  BootstrapPlan? _plan;
  SyncReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _step = _LinkStep.analyzing;
      _error = null;
    });
    try {
      final plan = await context.read<SyncProvider>().analyzeLink();
      if (mounted) {
        setState(() {
          _plan = plan;
          _step = _LinkStep.plan;
        });
      }
    } on SyncUserException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _step = _LinkStep.failed;
        });
      }
    }
  }

  Future<void> _run() async {
    setState(() => _step = _LinkStep.running);
    try {
      final report = await context.read<SyncProvider>().link(_plan!);
      if (mounted) {
        setState(() {
          _report = report;
          _step = _LinkStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is SyncUserException
              ? e.message
              : isWebApp
              ? 'Не удалось: $e. Данные на сервере не затронуты — '
                    'попробуйте ещё раз.'
              : 'Не удалось: $e. Данные $ofThisDevice не пострадали — '
                    'перед началом сделана резервная копия.';
          _step = _LinkStep.failed;
        });
      }
    }
  }

  static String _action(BootstrapKind kind) => switch (kind) {
    BootstrapKind.upload => 'Выгрузить базу на сервер',
    BootstrapKind.link => 'Связать с сервером',
    BootstrapKind.download => 'Принять данные с сервера',
    BootstrapKind.fresh || BootstrapKind.foreign => 'Начать',
  };

  Widget _progress(String text) => Row(
    children: [
      const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      const SizedBox(width: 16),
      Expanded(child: Text(text)),
    ],
  );

  Widget _content(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    switch (_step) {
      case _LinkStep.analyzing:
        return _progress('Сравниваю данные $ofThisDevice и сервера…');
      case _LinkStep.running:
        return _progress(
          isWebApp
              ? 'Приём данных с сервера. Не закрывайте вкладку…'
              : 'Резервная копия базы, затем обмен с сервером. Не закрывайте '
                    'программу…',
        );
      case _LinkStep.plan:
        final plan = _plan!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Веб-версия только принимает данные в пустую базу браузера,
            // резервной копии перед этим нет — копировать нечего.
            Text(
              isWebApp && plan.kind == BootstrapKind.download
                  ? 'С сервера будут приняты записей: ${plan.serverRows}. '
                        'Они хранятся в этом браузере до выхода.'
                  : plan.description,
            ),
            const SizedBox(height: 12),
            if (plan.allowed && isWebApp)
              const SizedBox.shrink()
            else if (plan.allowed)
              const Text(
                'Перед началом будет сделана резервная копия базы (папка '
                'резервных копий, имя backup_before_sync_…).',
                style: TextStyle(fontSize: 13),
              )
            else
              Text(plan.refusal!, style: TextStyle(color: error)),
          ],
        );
      case _LinkStep.done:
        final r = _report!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Готово: база связана с сервером.'),
            const SizedBox(height: 8),
            Text(
              'Отправлено на сервер: ${r.pushed}, уже было на сервере: '
              '${r.duplicates}, получено с сервера: ${r.received}.',
            ),
            if (r.lost > 0 || r.rejected > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Записей, где победила версия сервера: ${r.lost}; не принято '
                  'сервером: ${r.rejected}. Подробности — в журнале '
                  'синхронизации (Настройки › Сервер).',
                ),
              ),
          ],
        );
      case _LinkStep.failed:
        return Text(_error ?? 'Ошибка', style: TextStyle(color: error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _step == _LinkStep.analyzing || _step == _LinkStep.running;
    final plan = _plan;
    return AppDialog(
      title: const Text('Первый вход на сервер'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: _content(context)),
      ),
      actions: [
        if (!busy && _step != _LinkStep.done)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        if (_step == _LinkStep.failed)
          FilledButton(
            // После сбоя — сравнить заново: часть данных могла уже уйти.
            onPressed: _analyze,
            child: const Text('Повторить'),
          ),
        if (_step == _LinkStep.plan && plan!.allowed)
          FilledButton(onPressed: _run, child: Text(_action(plan.kind))),
        if (_step == _LinkStep.done)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Готово'),
          ),
      ],
    );
  }
}
