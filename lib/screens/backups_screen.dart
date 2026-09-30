// lib/screens/backups_screen.dart
//
// Модуль «Резервные копии» (шаг 3 «Дальнейших работ»; Windows, только
// админ — решение владельца 2026-09-30): копии этого компьютера и
// ежедневные копии сервера. Копию можно открыть и посмотреть, сравнить с
// тем, что есть сейчас, и вернуть записи (BackupViewScreen).

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart'
    show BackupFormat, RestoreException;
import 'package:kfh_sync/kfh_sync.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/local_backups.dart';
import '../services/server_backup_reader.dart';
import '../theme/app_theme.dart';
import 'backup_list_screen.dart';
import 'backup_view_screen.dart';

/// Подпись копии этого компьютера по имени файла.
String localBackupKind(BackupInfo b) {
  final name = b.fileName;
  if (name.startsWith('daily_')) return 'Ежедневная';
  if (name.startsWith('monthly_')) return 'Месячная';
  if (name.startsWith('backup_before_rollback_')) {
    return 'Перед возвратом из копии';
  }
  if (name.startsWith('backup_before_restore_')) {
    return 'Перед восстановлением';
  }
  if (name.startsWith('backup_before_sync_')) {
    return 'Перед первым входом на сервер';
  }
  if (name.startsWith('backup_v8_')) return 'Старая база (до 26.09.2026)';
  return 'Копия';
}

/// Подпись копии сервера: ежедневная, воскресная (хранится 8 недель) или
/// за 1-е число (хранится год).
String serverBackupKind(ServerBackup b) {
  final day = b.createdAt;
  if (day.day == 1) return 'Месячная копия сервера';
  if (day.weekday == DateTime.sunday) return 'Недельная копия сервера';
  return 'Копия сервера';
}

String formatBackupSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} КБ';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} МБ';
}

final _moment = DateFormat('dd.MM.yyyy HH:mm');

class BackupsScreen extends StatefulWidget {
  /// Файл ключа копий сервера; null — `%USERPROFILE%\.kfh\backup_age.key`
  /// (другой — для тестов).
  final String? keyPath;

  const BackupsScreen({super.key, this.keyPath});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _LocalEntry {
  final BackupInfo info;
  final int size;

  /// Формат файла; null — файл не читается.
  final BackupFormat? format;

  const _LocalEntry(this.info, this.size, this.format);
}

class _BackupsScreenState extends State<BackupsScreen> {
  /// Ключи на время работы программы (файл → ключ): второй раз не
  /// спрашиваем.
  static final _keys = <String, AgeIdentity>{};

  /// Ключ, выбранный вручную, — до закрытия программы.
  static AgeIdentity? _picked;

  List<_LocalEntry>? _local;
  String? _localError;
  String? _folder;

  List<ServerBackup>? _server;
  String? _serverError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _loadServer();
  }

  LocalBackups get _backups => context.read<AppProvider>().backupService;

  Future<void> _loadLocal() async {
    try {
      final backups = _backups;
      final list = await backups.getBackups();
      final entries = [
        for (final b in list)
          _LocalEntry(b, backups.backupSize(b.path), _formatOf(backups, b)),
      ]..sort((a, b) => b.info.takenAt.compareTo(a.info.takenAt));
      final folder = await backups.folderPath();
      if (!mounted) return;
      setState(() {
        _local = entries;
        _folder = folder;
        _localError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = 'Список копий не прочитан: $e');
    }
  }

  static BackupFormat? _formatOf(LocalBackups backups, BackupInfo b) {
    try {
      return backups.detectFormat(b.path);
    } on RestoreException {
      return null;
    }
  }

  Future<void> _loadServer() async {
    final sync = context.read<SyncProvider>();
    if (!sync.canUseBackups) {
      setState(() => _serverError = 'Нужен вход администратора на сервер');
      return;
    }
    setState(() {
      _server = null;
      _serverError = null;
    });
    try {
      final list = await sync.serverBackups();
      if (!mounted) return;
      setState(() => _server = list);
    } on SyncUserException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message);
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final path = await context.read<AppProvider>().createBackup();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Копию создать не удалось' : 'Копия создана',
        ),
      ),
    );
    await _loadLocal();
  }

  Future<void> _delete(_LocalEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить копию?'),
        content: Text(
          '${localBackupKind(entry.info)} от '
          '${_moment.format(entry.info.takenAt)} будет удалена с этого '
          'компьютера. Вернуть её будет нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _backups.deleteBackup(entry.info.path);
    await _loadLocal();
  }

  Future<void> _openLocal(_LocalEntry entry) async {
    final title =
        '${localBackupKind(entry.info)} · ${_moment.format(entry.info.takenAt)}';
    await _openWith(
      title: title,
      takenAt: entry.info.takenAt,
      source: BackupSource.local,
      load: () => _backups.readSnapshot(entry.info.path),
    );
  }

  Future<void> _openServer(ServerBackup backup) async {
    final key = await _ensureKey();
    if (key == null || !mounted) return;
    final sync = context.read<SyncProvider>();
    final taken = backup.createdAt.toLocal();
    await _openWith(
      title: '${serverBackupKind(backup)} · ${_moment.format(taken)}',
      takenAt: taken,
      source: BackupSource.server,
      load: () async {
        final bytes = await sync.downloadServerBackup(backup.name);
        return (await ServerBackupReader.decode(bytes, key)).snapshot;
      },
    );
  }

  Future<void> _openWith({
    required String title,
    required DateTime takenAt,
    required BackupSource source,
    required Future<DataSnapshot> Function() load,
  }) async {
    setState(() => _busy = true);
    DataSnapshot snapshot;
    try {
      snapshot = await load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _showError('Копия не открылась', '$e');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackupViewScreen(
          title: title,
          takenAt: takenAt,
          source: source,
          snapshot: snapshot,
        ),
      ),
    );
    if (mounted) await _loadLocal();
  }

  /// Ключ владельца: сначала из `%USERPROFILE%\.kfh`, иначе — выбрать файл.
  Future<AgeIdentity?> _ensureKey() async {
    final path = widget.keyPath ?? ServerBackupReader.defaultKeyPath();
    final known = path == null ? null : _keys[path];
    if (known != null) return known;
    if (widget.keyPath == null && _picked != null) return _picked;
    String? problem;
    if (path != null) {
      try {
        return _keys[path] = await ServerBackupReader.loadKey(path);
      } on ServerBackupException catch (e) {
        problem = e.message;
      }
    }
    if (!mounted) return null;
    final pick = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Нужен ключ копий'),
        content: Text(
          'Копии сервера зашифрованы, открыть их можно только ключом '
          'владельца (файл backup_age.key).\n\n'
          '${problem ?? 'Папка пользователя не найдена.'}\n\n'
          'Выберите файл ключа — программа запомнит его до закрытия.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выбрать файл…'),
          ),
        ],
      ),
    );
    if (pick != true) return null;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Ключ age', extensions: ['key', 'txt']),
      ],
    );
    if (file == null) return null;
    try {
      return _picked = await ServerBackupReader.loadKey(file.path);
    } on ServerBackupException catch (e) {
      if (mounted) await _showError('Ключ не подошёл', e.message);
      return null;
    }
  }

  Future<void> _showError(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Резервные копии'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Как устроены копии',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupsHelpScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (v) {
              if (v == 'file') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupListScreen()),
                ).then((_) => _loadLocal());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'file',
                child: Text('Заменить базу файлом копии целиком…'),
              ),
            ],
          ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        children: [
          _SectionHeader(
            icon: Icons.computer,
            title: 'Этот компьютер',
            subtitle: _folder,
            actions: [
              TextButton.icon(
                onPressed: () => _backups.openFolder(),
                icon: const Icon(Icons.folder_open),
                label: const Text('Открыть папку'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Создать копию'),
              ),
            ],
          ),
          if (_localError != null)
            _Message(_localError!, error: true)
          else if (_local == null)
            const _Loading()
          else if (_local!.isEmpty)
            const _Message('Копий на этом компьютере пока нет')
          else
            Card(
              child: Column(
                children: [
                  for (final e in _local!)
                    ListTile(
                      leading: Icon(
                        e.format == null
                            ? Icons.error_outline
                            : Icons.inventory_2_outlined,
                        color: e.format == null
                            ? theme.colorScheme.error
                            : null,
                      ),
                      title: Text(localBackupKind(e.info)),
                      subtitle: Text(
                        [
                          _moment.format(e.info.takenAt),
                          formatBackupSize(e.size),
                          if (e.format == BackupFormat.v8) 'старый формат',
                          if (e.format == null) 'файл не читается',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _busy || e.format == null
                                ? null
                                : () => _openLocal(e),
                            child: const Text('Открыть'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Удалить копию',
                            onPressed: _busy ? null : () => _delete(e),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.cloud_outlined,
            title: 'Сервер',
            subtitle: 'Каждую ночь в 03:30 по Москве; зашифрованы вашим ключом',
            actions: [
              TextButton.icon(
                onPressed: _busy ? null : _loadServer,
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
            ],
          ),
          if (_serverError != null)
            _Message(_serverError!, error: true)
          else if (_server == null)
            const _Loading()
          else if (_server!.isEmpty)
            const _Message(
              'На сервере пока нет копий для программы — первая появится '
              'после ночного копирования',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final b in _server!)
                    ListTile(
                      leading: const Icon(Icons.cloud_done_outlined),
                      title: Text(serverBackupKind(b)),
                      subtitle: Text(
                        '${_moment.format(b.createdAt.toLocal())} · '
                        '${formatBackupSize(b.size)}',
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _openServer(b),
                        child: const Text('Открыть'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;

  const _Message(this.text, {this.error = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: error
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Страница «Как устроены копии».
class BackupsHelpScreen extends StatelessWidget {
  const BackupsHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget h(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget p(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Как устроены копии')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            children: [
              h('Копии этого компьютера'),
              p(
                '• При каждом запуске программа сохраняет ежедневную копию '
                'базы (за день — одна, свежая заменяет утреннюю) и первую '
                'копию месяца. Хранятся 5 последних ежедневных; месячные не '
                'удаляются.',
              ),
              p(
                '• Перед рискованными действиями — первым входом на сервер, '
                'восстановлением, возвратом записей из копии — программа '
                'сама делает копию текущего состояния. Такие копии не '
                'удаляются автоматически.',
              ),
              p(
                '• Копии лежат в папке «Документы\\backups»; кнопка «Открыть '
                'папку» покажет её.',
              ),
              h('Копии сервера'),
              p(
                '• Каждую ночь в 03:30 по Москве сервер сохраняет копию всей '
                'базы. Ежедневные хранятся 8 дней, воскресные — 8 недель, '
                'за 1-е число — год. Копии лежат и на сервере, и в облачном '
                'хранилище.',
              ),
              p(
                '• Копии зашифрованы. Открыть их можно только на компьютере '
                'владельца его ключом (файл backup_age.key в папке .kfh '
                'пользователя). На сервере ключа нет — прочитать копии там '
                'нельзя. Ключ нельзя пересылать и выкладывать: у кого ключ, '
                'тот прочитает копии.',
              ),
              h('Что можно сделать с копией'),
              p(
                '• Посмотреть: сотрудники, табель, выплаты, ставки, расчёты, '
                'реквизиты — как они были на момент копии.',
              ),
              p(
                '• Сравнить с тем, что есть сейчас: что добавлено, изменено '
                'и удалено с тех пор, по сотруднику и месяцу.',
              ),
              p(
                '• Вернуть отдельные записи или всю базу на дату копии. '
                'Возврат — это обычные правки: они уходят на сервер и на все '
                'устройства и видны в журнале действий. Закрытые месяцы '
                'возврат не трогает — программа скажет, что пропущено. '
                'Расчёты ЗП сервер пересчитает сам.',
              ),
              p(
                '• Перед возвратом программа показывает, что именно '
                'изменится, и сохраняет копию текущего состояния — возврат '
                'можно отменить, вернув эту копию.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
