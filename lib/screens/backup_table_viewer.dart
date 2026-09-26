// lib/screens/backup_table_viewer.dart

import 'package:flutter/material.dart';
import 'package:kfh_local_db/kfh_local_db.dart'
    show BackupFormat, businessTables;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/cell_format.dart';
import '../widgets/common_widgets.dart';

/// Записи таблицы из копии базы. Из копии текущего формата можно вернуть
/// отмеченные строки (по uuid); копия старого формата — только просмотр.
class BackupTableViewer extends StatefulWidget {
  final String backupPath;
  final String tableName;

  const BackupTableViewer({
    super.key,
    required this.backupPath,
    required this.tableName,
  });

  @override
  State<BackupTableViewer> createState() => _BackupTableViewerState();
}

class _BackupTableViewerState extends State<BackupTableViewer> {
  List<Map<String, dynamic>> _rows = [];
  List<String> _columns = [];
  final Set<String> _selected = {};
  bool _canRestore = false;
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<AppProvider>();
      final data = await provider.backupService.getBackupTableData(
        widget.backupPath,
        widget.tableName,
      );
      final canRestore =
          provider.backupFormat(widget.backupPath) == BackupFormat.v2 &&
          businessTables.contains(widget.tableName);
      if (!mounted) return;
      setState(() {
        _rows = data;
        _columns = data.isEmpty ? [] : data.first.keys.toList();
        _canRestore = canRestore;
        _selected.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggle(String uuid) => setState(() {
    if (!_selected.remove(uuid)) _selected.add(uuid);
  });

  Future<void> _restoreSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановление записей'),
        content: Text(
          'Вернуть ${_selected.length} записей таблицы ${widget.tableName} '
          'в том виде, как они сохранены в копии?\n\n'
          'Запись текущей базы на тот же день табеля (или тот же месяц '
          'расчёта) будет помечена удалённой. Перед восстановлением '
          'программа сохранит копию текущей базы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final count = await context.read<AppProvider>().restoreSelectedRows(
        widget.backupPath,
        widget.tableName,
        _selected.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Восстановлено записей: $count')));
      setState(() => _selected.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Копия, таблица: ${widget.tableName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Colors.red[700])),
                  const SizedBox(height: 16),
                  AppButton(label: 'Повторить', onPressed: _loadData),
                ],
              ),
            )
          : _rows.isEmpty
          ? const Center(child: Text('Таблица пуста'))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      if (_canRestore) ...[
                        Checkbox(
                          value: _selected.length == _rows.length,
                          onChanged: (v) => setState(() {
                            _selected.clear();
                            if (v == true) {
                              _selected.addAll(
                                _rows.map((r) => r['uuid'] as String),
                              );
                            }
                          }),
                        ),
                        const Text(
                          'Выбрать все',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ] else
                        const Text(
                          'Только просмотр: записи возвращаются из копий '
                          'текущего формата',
                          style: TextStyle(color: Colors.grey),
                        ),
                      const Spacer(),
                      Text('Записей: ${_rows.length}'),
                      if (_selected.isNotEmpty)
                        Text(
                          ', выбрано: ${_selected.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        showCheckboxColumn: _canRestore,
                        columns: [
                          for (final col in _columns)
                            DataColumn(
                              label: Text(
                                col,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                        rows: [
                          for (final row in _rows)
                            DataRow(
                              selected:
                                  _canRestore &&
                                  _selected.contains(row['uuid']),
                              onSelectChanged: _canRestore
                                  ? (_) => _toggle(row['uuid'] as String)
                                  : null,
                              cells: [
                                for (final col in _columns)
                                  DataCell(
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                      ),
                                      child: Text(
                                        formatCell(row[col]),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isRestoring ? null : _restoreSelected,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore),
              label: Text(
                _isRestoring
                    ? 'Восстановление...'
                    : 'Восстановить (${_selected.length})',
              ),
            )
          : null,
    );
  }
}
