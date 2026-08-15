// lib/screens/database_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

/// Экран для просмотра содержимого таблиц базы данных (отладка)
class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  List<String> _tableNames = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTableNames();
  }

  Future<void> _loadTableNames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = context.read<AppProvider>().db;
      final tables = await db.getTableNames();
      if (!mounted) return;
      setState(() {
        _tableNames = tables;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Просмотр базы данных'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTableNames,
            tooltip: 'Обновить',
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
                  Text(
                    'Ошибка загрузки таблиц: $_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  AppButton(label: 'Повторить', onPressed: _loadTableNames),
                ],
              ),
            )
          : _tableNames.isEmpty
          ? const Center(child: Text('Таблицы не найдены'))
          : ListView.builder(
              itemCount: _tableNames.length,
              itemBuilder: (context, index) {
                final tableName = _tableNames[index];
                if (tableName.startsWith('sqlite_')) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text(tableName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TableViewerScreen(tableName: tableName),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Экран просмотра конкретной таблицы с редактированием и удалением
class TableViewerScreen extends StatefulWidget {
  final String tableName;

  const TableViewerScreen({super.key, required this.tableName});

  @override
  State<TableViewerScreen> createState() => _TableViewerScreenState();
}

class _TableViewerScreenState extends State<TableViewerScreen> {
  List<Map<String, dynamic>> _rows = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String? _error;
  int _limit = 100;

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
      final db = context.read<AppProvider>().db;
      final data = await db.getTableData(widget.tableName, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (data.isNotEmpty) {
          _columns = data.first.keys.toList();
        } else {
          _columns = [];
        }
        _rows = data;
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

  Future<void> _loadAll() async {
    setState(() {
      _limit = 1000;
    });
    await _loadData();
  }

  Future<void> _deleteRow(Map<String, dynamic> row, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text(
          'Удалить строку #${index + 1} из таблицы ${widget.tableName}?',
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Удалить',
            onPressed: () => Navigator.pop(context, true),
            color: Colors.red,
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    if (!mounted) return;
    try {
      final db = context.read<AppProvider>().db;
      final id = row['id'];
      if (id == null) {
        throw Exception('Таблица не содержит поля "id" для удаления');
      }
      await db.deleteRow(widget.tableName, id);
      if (!mounted) return;
      setState(() {
        _rows.removeAt(index);
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Строка удалена')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editRow(Map<String, dynamic> row, int index) async {
    final Map<String, TextEditingController> controllers = {};
    for (var col in _columns) {
      if (col == 'id') continue;
      var value = row[col];
      String initialValue = value?.toString() ?? '';
      if (value is DateTime) {
        initialValue = DateFormat('dd.MM.yyyy HH:mm').format(value);
      }
      controllers[col] = TextEditingController(text: initialValue);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактирование строки #${index + 1}'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: entry.key,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Сохранить',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result != true) return;

    final updatedRow = <String, dynamic>{};
    for (var col in _columns) {
      if (col == 'id') {
        updatedRow[col] = row['id'];
        continue;
      }
      final text = controllers[col]!.text.trim();
      if (text.isEmpty) {
        updatedRow[col] = null;
      } else if (row[col] is int) {
        updatedRow[col] = int.tryParse(text);
      } else if (row[col] is double) {
        updatedRow[col] = double.tryParse(text);
      } else if (row[col] is DateTime) {
        try {
          updatedRow[col] = DateTime.parse(text);
        } catch (_) {
          updatedRow[col] = text;
        }
      } else {
        updatedRow[col] = text;
      }
    }

    setState(() => _isLoading = true);
    if (!mounted) return;
    try {
      final db = context.read<AppProvider>().db;
      final id = row['id'];
      if (id == null) {
        throw Exception('Таблица не содержит поля "id" для обновления');
      }
      await db.updateRow(widget.tableName, id, updatedRow);
      if (!mounted) return;
      final newRow = Map<String, dynamic>.from(row);
      for (var col in _columns) {
        if (col != 'id') {
          newRow[col] = updatedRow[col];
        }
      }
      setState(() {
        _rows[index] = newRow;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Строка обновлена')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Таблица: ${widget.tableName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.data_usage),
                        title: const Text('Показать все (до 1000 записей)'),
                        onTap: () {
                          Navigator.pop(context);
                          _loadAll();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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
                  Text(
                    'Ошибка: $_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  AppButton(label: 'Повторить', onPressed: _loadData),
                ],
              ),
            )
          : _rows.isEmpty
          ? const Center(child: Text('Нет данных'))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Записей: ${_rows.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_rows.length >= _limit)
                        const Text(
                          ' (показано не более 100)',
                          style: TextStyle(color: Colors.grey),
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
                          const DataColumn(
                            label: Text(
                              'Действия',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _rows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return DataRow(
                            cells: [
                              ..._columns.map((col) {
                                var value = row[col];
                                String display = value?.toString() ?? 'null';
                                if (value is DateTime) {
                                  display = DateFormat(
                                    'dd.MM.yyyy HH:mm',
                                  ).format(value);
                                }
                                return DataCell(
                                  GestureDetector(
                                    onTap: () => _editRow(row, index),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                      ),
                                      child: Text(
                                        display,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _editRow(row, index),
                                      tooltip: 'Редактировать',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteRow(row, index),
                                      tooltip: 'Удалить',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
