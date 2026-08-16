// lib/screens/backup_table_viewer.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

/// Экран для просмотра записей конкретной таблицы из бэкапа с возможностью выбора
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
  final Set<int> _selectedIds = {};
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
      if (!mounted) return;
      setState(() {
        _rows = data;
        if (data.isNotEmpty) {
          _columns = data.first.keys.toList();
        }
        _selectedIds.clear();
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

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(_rows.map((row) => row['id'] as int));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleRow(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не выбрано ни одной записи')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановление записей'),
        content: Text(
          'Восстановить ${_selectedIds.length} записей из таблицы ${widget.tableName}?',
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
    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      // ignore: use_build_context_synchronously
      final provider = context.read<AppProvider>();
      final count = await provider.restoreSelectedRows(
        widget.backupPath,
        widget.tableName,
        _selectedIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Восстановлено $count записей')));
      // Возвращаемся к списку таблиц
      Navigator.pop(context);
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
        title: Text('Таблица: ${widget.tableName}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: _isRestoring ? null : _restoreSelected,
              tooltip: 'Восстановить выбранные',
            ),
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
                      Checkbox(
                        value:
                            _selectedIds.length == _rows.length &&
                            _rows.isNotEmpty,
                        onChanged: _toggleSelectAll,
                      ),
                      const Text(
                        'Выбрать все',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_selectedIds.isNotEmpty)
                        Text(
                          'Выбрано: ${_selectedIds.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: [
                          const DataColumn(
                            label: Text(
                              '',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ..._columns.map((col) {
                            return DataColumn(
                              label: Text(
                                col,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                        ],
                        rows: _rows.map((row) {
                          final id = row['id'] as int;
                          final isSelected = _selectedIds.contains(id);
                          return DataRow(
                            selected: isSelected,
                            onSelectChanged: (_) => _toggleRow(id),
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleRow(id),
                                ),
                              ),
                              ..._columns.map((col) {
                                var value = row[col];
                                String display = value?.toString() ?? 'null';
                                if (value is DateTime) {
                                  display = DateFormat(
                                    'dd.MM.yyyy HH:mm',
                                  ).format(value);
                                }
                                return DataCell(
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 200,
                                    ),
                                    child: Text(
                                      display,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedIds.isNotEmpty
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
                    : 'Восстановить (${_selectedIds.length})',
              ),
            )
          : null,
    );
  }
}
