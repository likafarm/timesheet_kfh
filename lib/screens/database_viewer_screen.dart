// lib/screens/database_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show ColumnInfo;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/cell_format.dart';
import '../widgets/common_widgets.dart';

/// Экран просмотра и правки таблиц базы данных
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

/// Просмотр и правка таблицы. Править можно бизнес-таблицы: изменение
/// ставит updated_at и edited_by, удаление — мягкое (строку можно
/// вернуть). Служебные поля синхронизации и служебные таблицы — только
/// чтение.
class TableViewerScreen extends StatefulWidget {
  final String tableName;

  const TableViewerScreen({super.key, required this.tableName});

  @override
  State<TableViewerScreen> createState() => _TableViewerScreenState();
}

class _TableViewerScreenState extends State<TableViewerScreen> {
  List<Map<String, Object?>> _rows = [];
  List<ColumnInfo> _columns = [];
  bool _editable = false;
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
      final provider = context.read<AppProvider>();
      final columns = await provider.getTableColumns(widget.tableName);
      final rows = await provider.getTableData(widget.tableName, limit: _limit);
      if (!mounted) return;
      setState(() {
        _columns = columns;
        _rows = rows;
        _editable = provider.isTableEditable(widget.tableName);
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
    setState(() => _limit = 1000);
    await _loadData();
  }

  bool _isDeleted(Map<String, Object?> row) => row['deleted'] == 1;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleDeleted(Map<String, Object?> row) async {
    final restore = _isDeleted(row);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(restore ? 'Вернуть строку' : 'Удалить строку'),
        content: Text(
          restore
              ? 'Вернуть удалённую строку в таблицу ${widget.tableName}?'
              : 'Пометить строку таблицы ${widget.tableName} удалённой?\n'
                    'Её можно будет вернуть здесь же.',
        ),
        actions: [
          AppButton(
            label: 'Отмена',
            isText: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: restore ? 'Вернуть' : 'Удалить',
            onPressed: () => Navigator.pop(context, true),
            color: restore ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<AppProvider>().setTableRowDeleted(
        widget.tableName,
        row['uuid'] as String,
        !restore,
      );
      if (!mounted) return;
      _showMessage(restore ? 'Строка возвращена' : 'Строка удалена');
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Ошибка: $e');
    }
  }

  Future<void> _editRow(Map<String, Object?> row) async {
    final editable = _columns.where((c) => !c.isSync).toList();
    final controllers = {
      for (final c in editable)
        c.name: TextEditingController(text: cellToInput(row[c.name])),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Правка: ${widget.tableName}'),
        content: SizedBox(
          width: 420,
          height: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in editable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: controllers[c.name],
                      decoration: InputDecoration(
                        labelText: c.name,
                        helperText: c.isDate ? 'дд.мм.гггг' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
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
    if (saved != true || !mounted) {
      for (final c in controllers.values) {
        c.dispose();
      }
      return;
    }

    final changes = <String, Object?>{};
    try {
      for (final c in editable) {
        final value = parseCellInput(c, controllers[c.name]!.text);
        if (value != row[c.name]) changes[c.name] = value;
      }
    } on FormatException catch (e) {
      _showMessage('Ошибка ввода: ${e.message}');
      return;
    } finally {
      for (final c in controllers.values) {
        c.dispose();
      }
    }
    if (changes.isEmpty) {
      _showMessage('Изменений нет');
      return;
    }

    try {
      await context.read<AppProvider>().updateTableRow(
        widget.tableName,
        row['uuid'] as String,
        changes,
      );
      if (!mounted) return;
      _showMessage('Строка сохранена');
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deletedStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey[500],
      decoration: TextDecoration.lineThrough,
    );
    const normalStyle = TextStyle(fontSize: 12);

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
            icon: const Icon(Icons.data_usage),
            onPressed: _loadAll,
            tooltip: 'Показать все (до 1000 записей)',
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
                    children: [
                      Text(
                        'Записей: ${_rows.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_rows.length >= _limit)
                        Text(
                          ' (показано не более $_limit)',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const Spacer(),
                      Text(
                        _editable
                            ? 'Удалённые строки — серые, их можно вернуть'
                            : 'Служебная таблица — только просмотр',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          if (_editable)
                            const DataColumn(
                              label: Text(
                                'Действия',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          for (final c in _columns)
                            DataColumn(
                              label: Text(
                                c.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: c.isSync ? Colors.grey[600] : null,
                                ),
                              ),
                            ),
                        ],
                        rows: [
                          for (final row in _rows)
                            DataRow(
                              cells: [
                                if (_editable)
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          onPressed: _isDeleted(row)
                                              ? null
                                              : () => _editRow(row),
                                          tooltip: 'Изменить',
                                        ),
                                        if (widget.tableName !=
                                            'company_settings')
                                          IconButton(
                                            icon: Icon(
                                              _isDeleted(row)
                                                  ? Icons.restore_from_trash
                                                  : Icons.delete,
                                              size: 18,
                                              color: _isDeleted(row)
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            onPressed: () =>
                                                _toggleDeleted(row),
                                            tooltip: _isDeleted(row)
                                                ? 'Вернуть'
                                                : 'Удалить',
                                          ),
                                      ],
                                    ),
                                  ),
                                for (final c in _columns)
                                  DataCell(
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                      ),
                                      child: Text(
                                        formatCell(row[c.name]),
                                        overflow: TextOverflow.ellipsis,
                                        style: _isDeleted(row)
                                            ? deletedStyle
                                            : normalStyle,
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
    );
  }
}
