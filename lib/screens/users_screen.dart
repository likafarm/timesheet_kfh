// lib/screens/users_screen.dart
//
// «Настройки → Пользователи» (11.2, только администратор, нужна связь с
// сервером): учётные записи сервера — новый пользователь с временным
// паролем (при первом входе его нужно сменить), роль, ФИО, «отключить»,
// новый временный пароль. Роли: администратор, бухгалтер, оператор,
// специалист по продажам. Последнего действующего администратора сервер
// отключить или понизить не даст.

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart' show allRoles, roleTitle;
import 'package:kfh_sync/kfh_sync.dart' show SessionUser;
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/choice_buttons.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<SessionUser>? _users;
  String? _problem;

  SyncProvider get _sync => context.read<SyncProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _sync.serverUsers();
      users.sort((a, b) {
        final byActive = (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0);
        return byActive != 0 ? byActive : a.fullName.compareTo(b.fullName);
      });
      if (mounted) {
        setState(() {
          _users = users;
          _problem = null;
        });
      }
    } on SyncUserException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  /// Выполнить запрос к серверу; ошибка — внизу экрана.
  Future<bool> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      await _load();
      return true;
    } on SyncUserException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }

  Future<void> _create() async {
    final result = await showAppDialog<_UserForm>(
      context: context,
      builder: (_) => const _UserDialog(),
    );
    if (result == null) return;
    await _run(
      () => _sync.createServerUser(
        login: result.login,
        fullName: result.fullName,
        role: result.role,
        password: result.password!,
      ),
      'Пользователь ${result.login} создан. Сообщите ему логин и временный '
      'пароль — при первом входе пароль нужно сменить.',
    );
  }

  Future<void> _edit(SessionUser user) async {
    final result = await showAppDialog<_UserForm>(
      context: context,
      builder: (_) => _UserDialog(user: user),
    );
    if (result == null) return;
    await _run(
      () => _sync.updateServerUser(
        user.uuid,
        fullName: result.fullName == user.fullName ? null : result.fullName,
        role: result.role == user.role ? null : result.role,
      ),
      'Сохранено',
    );
  }

  Future<void> _toggle(SessionUser user) => _run(
    () => _sync.updateServerUser(user.uuid, isActive: !user.isActive),
    user.isActive
        ? '${user.login} отключён: войти больше не сможет'
        : '${user.login} снова может входить',
  );

  Future<void> _resetPassword(SessionUser user) async {
    final password = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: Text('Новый пароль для ${user.login}'),
        content: TextField(
          controller: password,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Временный пароль',
            helperText:
                'Все входы пользователя завершатся; при входе '
                'пароль нужно будет сменить',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Задать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _sync.resetServerPassword(user.uuid, password.text),
      'Пароль ${user.login} изменён',
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final me = context.watch<SyncProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Новый пользователь'),
      ),
      body: _problem != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_problem!, textAlign: TextAlign.center),
              ),
            )
          : users == null
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final u in users)
                      _UserTile(
                        user: u,
                        isMe: u.uuid == me?.uuid,
                        onEdit: () => _edit(u),
                        onToggle: () => _toggle(u),
                        onReset: () => _resetPassword(u),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final SessionUser user;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const _UserTile({
    required this.user,
    required this.isMe,
    required this.onEdit,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(
        user.isActive ? Icons.person_outline : Icons.person_off_outlined,
        color: user.isActive ? null : muted,
      ),
      title: Text(
        '${user.fullName}${isMe ? ' (это вы)' : ''}',
        style: user.isActive ? null : TextStyle(color: muted),
      ),
      subtitle: Text(
        [
          user.login,
          user.roleTitle,
          if (!user.isActive) 'отключён',
          if (user.mustChangePassword) 'ждёт смены пароля',
        ].join(' · '),
      ),
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        tooltip: 'Действия',
        onSelected: (a) => switch (a) {
          'edit' => onEdit(),
          'reset' => onReset(),
          _ => onToggle(),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('ФИО и роль')),
          const PopupMenuItem(value: 'reset', child: Text('Новый пароль')),
          if (!isMe)
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.isActive ? 'Отключить' : 'Включить'),
            ),
        ],
      ),
    );
  }
}

/// Данные окна пользователя.
class _UserForm {
  final String login;
  final String fullName;
  final String role;

  /// Временный пароль — только у нового.
  final String? password;

  const _UserForm(this.login, this.fullName, this.role, this.password);
}

class _UserDialog extends StatefulWidget {
  /// null — новый пользователь.
  final SessionUser? user;
  const _UserDialog({this.user});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final _login = TextEditingController(text: widget.user?.login ?? '');
  late final _name = TextEditingController(text: widget.user?.fullName ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'sales';
  String? _problem;

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    _login.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final login = _login.text.trim(), name = _name.text.trim();
    if (_isNew && login.isEmpty) {
      setState(() => _problem = 'Укажите логин');
      return;
    }
    if (name.isEmpty) {
      setState(() => _problem = 'Укажите ФИО');
      return;
    }
    if (_isNew && _password.text.isEmpty) {
      setState(() => _problem = 'Укажите временный пароль');
      return;
    }
    Navigator.pop(
      context,
      _UserForm(login, name, _role, _isNew ? _password.text : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog(
      title: Text(_isNew ? 'Новый пользователь' : widget.user!.login),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isNew) ...[
              TextField(
                controller: _login,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  helperText: 'Латиница, цифры, точка, дефис, _',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'ФИО',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ChoiceGroup<String>(
              label: 'Роль',
              value: _role,
              options: [
                for (final r in allRoles)
                  ChoiceOption(r, roleTitle(r), theme.colorScheme.primary),
              ],
              onChanged: (r) => setState(() => _role = r),
            ),
            if (_isNew) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(
                  labelText: 'Временный пароль',
                  helperText: 'При первом входе пароль нужно сменить',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _problem!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
