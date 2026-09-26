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
      final tables = await context.read<AppProvider>().getTableNames();
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

/// Просмотр таблицы (только чтение). Правка строк по uuid с отметкой
/// updated_at — этап 1, шаг 1.6.
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
      final data = await context.read<AppProvider>().getTableData(
        widget.tableName,
        limit: _limit,
      );
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
                        ],
                        rows: _rows.map((row) {
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
    );
  }
}
