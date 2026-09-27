// lib/screens/backup_list_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show BackupFormat;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/backup_service.dart';
import 'backup_table_viewer.dart';

class BackupListScreen extends StatefulWidget {
  const BackupListScreen({super.key});

  @override
  State<BackupListScreen> createState() => _BackupListScreenState();
}

class _BackupListScreenState extends State<BackupListScreen> {
  List<BackupInfo> _backups = [];
  bool _isLoading = true;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      final backups = await provider.getBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки бэкапов: $e')));
    }
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    if (_isRestoring) return;
    final provider = context.read<AppProvider>();
    final format = provider.backupFormat(backup.path);
    if (format == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл не похож на копию базы программы или повреждён'),
        ),
      );
      return;
    }
    final isV2 = format == BackupFormat.v2;

    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановление из копии'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isV2
                    ? 'Копия текущего формата.'
                    : 'Копия старого формата (до перехода на новую базу): '
                          'восстанавливается только целиком, с переносом '
                          'в новый формат и сверкой.',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.restore_page),
                title: const Text('Вся база данных'),
                subtitle: const Text('Заменит все данные текущей базы'),
                onTap: () => Navigator.pop(context, 1),
              ),
              ListTile(
                enabled: isV2,
                leading: const Icon(Icons.table_chart),
                title: const Text('Выборочные таблицы или записи'),
                subtitle: Text(
                  isV2
                      ? 'Вернуть отдельные таблицы или строки'
                      : 'Только для копий текущего формата',
                ),
                onTap: () => Navigator.pop(context, 2),
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Только просмотреть'),
                onTap: () => Navigator.pop(context, 3),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 0) return;

    if (choice == 1) {
      await _restoreFull(backup);
    } else if (choice == 2) {
      await _restoreTables(backup);
    } else if (choice == 3) {
      await _viewTables(backup);
    }
  }

  Future<void> _restoreFull(BackupInfo backup) async {
    final provider = context.read<AppProvider>();
    final confirm = await _showConfirmDialog(
      title: 'Восстановление всей базы',
      content:
          'Заменить текущую базу данных копией от '
          '${_formatBackupTitle(backup)}?\n\n'
          'Перед заменой программа сохранит копию текущей базы '
          '(backup_before_restore_…), её можно будет восстановить обратно.'
          '${_syncNote(full: true)}',
    );
    if (!confirm || !mounted) return;

    setState(() => _isRestoring = true);
    final success = await provider.restoreFullBackup(backup.path);
    if (!mounted) return;
    setState(() => _isRestoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'База данных восстановлена. Данные перезагружены.'
              : provider.error ?? 'Ошибка восстановления базы данных',
        ),
      ),
    );
    await _loadBackups();
  }

  Future<void> _restoreTables(BackupInfo backup) async {
    final provider = context.read<AppProvider>();
    List<String> tables;
    try {
      tables = provider.restorableTables(backup.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка чтения копии: $e')));
      return;
    }

    final selected = await _showTableSelectionDialog(tables, backup);
    if (selected == null || selected.isEmpty || !mounted) return;

    final confirm = await _showConfirmDialog(
      title: 'Восстановление таблиц',
      content:
          'Таблицы (${selected.join(', ')}) станут такими, как в копии: '
          'строки копии вернутся, строки, которых в копии нет, будут '
          'помечены удалёнными.\n\n'
          'Перед этим программа сохранит копию текущей базы.'
          '${_syncNote(full: false)}',
    );
    if (!confirm || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final count = await provider.restoreTables(backup.path, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Восстановлено записей: $count (таблиц: ${selected.length})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
    await _loadBackups();
  }

  Future<void> _viewTables(BackupInfo backup) async {
    final provider = context.read<AppProvider>();
    List<String> tables;
    try {
      tables = await provider.backupService.getBackupTableNames(backup.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка чтения копии: $e')));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Таблицы копии'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ListView(
            children: [
              for (final table in tables)
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text(table),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _openTable(backup, table);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _openTable(BackupInfo backup, String table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BackupTableViewer(backupPath: backup.path, tableName: table),
      ),
    );
  }

  /// Выбор таблиц; у каждой — просмотр записей (там же можно вернуть
  /// отдельные строки).
  Future<List<String>?> _showTableSelectionDialog(
    List<String> tables,
    BackupInfo backup,
  ) async {
    final selected = {for (final t in tables) t: false};
    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Выберите таблицы'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Чтобы вернуть отдельные записи, откройте таблицу '
                    '(значок глаза) и отметьте нужные строки.',
                  ),
                ),
                for (final table in tables)
                  CheckboxListTile(
                    title: Text(table),
                    value: selected[table],
                    onChanged: (val) =>
                        setStateDialog(() => selected[table] = val ?? false),
                    secondary: IconButton(
                      icon: const Icon(Icons.visibility),
                      tooltip: 'Просмотреть записи',
                      onPressed: () {
                        Navigator.pop(context);
                        _openTable(backup, table);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                selected.entries
                    .where((e) => e.value)
                    .map((e) => e.key)
                    .toList(),
              ),
              child: const Text('Восстановить выбранные'),
            ),
          ],
        ),
      ),
    );
  }

  /// Предупреждение о сервере синхронизации (пусто, если база не связана).
  String _syncNote({required bool full}) {
    final note = context.read<SyncProvider>().restoreWarning(full: full);
    return note == null ? '' : '\n\n$note';
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    String confirmLabel = 'Восстановить',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final provider = context.read<AppProvider>();

    final confirm = await _showConfirmDialog(
      title: 'Удаление бэкапа',
      content: 'Удалить бэкап от ${_formatBackupTitle(backup)}?',
      confirmLabel: 'Удалить',
    );
    if (!confirm) return;

    try {
      await provider.deleteBackup(backup.path);
      await _loadBackups();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Бэкап удалён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  /// Человекочитаемый заголовок копии в зависимости от типа.
  String _formatBackupTitle(BackupInfo backup) {
    switch (backup.type) {
      case BackupType.daily:
        return DateFormat('dd.MM.yyyy').format(backup.created);
      case BackupType.monthly:
        final monthName = DateFormat('LLLL yyyy', 'ru').format(backup.created);
        return monthName.substring(0, 1).toUpperCase() + monthName.substring(1);
      case BackupType.legacy:
        return DateFormat('dd.MM.yyyy HH:mm').format(backup.created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Резервные копии'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBackups),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backups.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.backup, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Нет резервных копий'),
                  SizedBox(height: 8),
                  Text(
                    'Бэкапы создаются автоматически при запуске приложения',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _buildBackupList(),
    );
  }

  Widget _buildBackupList() {
    final daily = _backups.where((b) => b.type == BackupType.daily).toList();
    final monthly = _backups
        .where((b) => b.type == BackupType.monthly)
        .toList();
    final legacy = _backups.where((b) => b.type == BackupType.legacy).toList();

    return ListView(
      children: [
        // ── Ежедневные ──────────────────────────────────────────
        _buildSectionHeader(
          Icons.today,
          'Ежедневные копии',
          'Последние ${daily.length} из 5',
        ),
        if (daily.isEmpty)
          const _EmptySection(text: 'Нет ежедневных копий')
        else
          ...daily.map((b) => _buildBackupTile(b)),

        const SizedBox(height: 8),

        // ── Ежемесячные ─────────────────────────────────────────
        _buildSectionHeader(
          Icons.calendar_month,
          'Ежемесячные копии',
          'Хранятся без ограничений',
        ),
        if (monthly.isEmpty)
          const _EmptySection(
            text:
                'Нет ежемесячных копий.\nСоздаются автоматически 1-го числа каждого месяца.',
          )
        else
          ...monthly.map((b) => _buildBackupTile(b)),

        // ── Прочие (legacy) ─────────────────────────────────────
        if (legacy.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader(
            Icons.archive,
            'Прочие копии',
            'Созданы вручную ранее',
          ),
          ...legacy.map((b) => _buildBackupTile(b)),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTile(BackupInfo backup) {
    final title = _formatBackupTitle(backup);
    final subtitle = 'Размер: ${_formatFileSize(backup.path)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: Icon(
          backup.type == BackupType.monthly
              ? Icons.calendar_month
              : backup.type == BackupType.daily
              ? Icons.today
              : Icons.backup,
          color: backup.type == BackupType.monthly ? Colors.blue : Colors.green,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: _isRestoring ? null : () => _restoreBackup(backup),
              tooltip: 'Восстановить',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isRestoring ? null : () => _deleteBackup(backup),
              tooltip: 'Удалить',
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(String path) {
    try {
      final file = File(path);
      final size = file.statSync().size;
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }
}

class _EmptySection extends StatelessWidget {
  final String text;

  const _EmptySection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}
