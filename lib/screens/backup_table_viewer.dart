// lib/screens/backup_table_viewer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

/// Просмотр записей таблицы из копии базы (только чтение).
/// Выборочное восстановление записей переделывается под формат v2
/// (этап 1, шаг 1.6).
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
  bool _isLoading = true;
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
        _columns = data.isEmpty ? [] : data.first.keys.toList();
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
        title: Text('Таблица: ${widget.tableName}'),
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
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    for (final col in _columns)
                      DataColumn(
                        label: Text(
                          col,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                  rows: [
                    for (final row in _rows)
                      DataRow(
                        cells: [
                          for (final col in _columns)
                            DataCell(
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Text(
                                  row[col]?.toString() ?? 'null',
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
    );
  }
}
