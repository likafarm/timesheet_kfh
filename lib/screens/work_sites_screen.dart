import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Экран управления участками/полями
class WorkSitesScreen extends StatefulWidget {
  const WorkSitesScreen({super.key});

  @override
  State<WorkSitesScreen> createState() => _WorkSitesScreenState();
}

class _WorkSitesScreenState extends State<WorkSitesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadWorkSites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Участки и поля'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(context),
            tooltip: 'Добавить участок',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadWorkSites(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (provider.workSites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.agriculture_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет участков',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить первый участок'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.workSites.length,
            itemBuilder: (context, index) {
              final site = provider.workSites[index];
              return _WorkSiteCard(
                site: site,
                onEdit: () => _showFormDialog(context, site: site),
                onDelete: () => _confirmDelete(context, site),
              );
            },
          );
        },
      ),
    );
  }

  void _showFormDialog(BuildContext context, {WorkSite? site}) {
    showDialog(
      context: context,
      builder: (context) => _WorkSiteFormDialog(site: site),
    );
  }

  void _confirmDelete(BuildContext context, WorkSite site) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление участка'),
        content: Text(
          'Удалить "${site.name}"?\n\n'
          'Записи табеля, использующие этот участок, останутся, '
          'но связь будет разорвана.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().deleteWorkSite(site.id!);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

/// Карточка участка
class _WorkSiteCard extends StatelessWidget {
  final WorkSite site;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkSiteCard({
    required this.site,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: const Icon(Icons.agriculture, color: Colors.green),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (site.areaHectares != null)
              Text('Площадь: ${site.areaHectares!.toStringAsFixed(2)} га'),
            if (site.cropType != null && site.cropType!.isNotEmpty)
              Text('Культура: ${site.cropType}'),
            if (site.notes != null && site.notes!.isNotEmpty)
              Text(
                site.notes!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог формы участка
class _WorkSiteFormDialog extends StatefulWidget {
  final WorkSite? site;

  const _WorkSiteFormDialog({this.site});

  @override
  State<_WorkSiteFormDialog> createState() => _WorkSiteFormDialogState();
}

class _WorkSiteFormDialogState extends State<_WorkSiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _cropController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.site != null) {
      _nameController.text = widget.site!.name;
      _areaController.text = widget.site!.areaHectares?.toString() ?? '';
      _cropController.text = widget.site!.cropType ?? '';
      _notesController.text = widget.site!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _cropController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.site != null;

    return AlertDialog(
      title: Text(isEditing ? 'Редактирование участка' : 'Новый участок'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Площадь (га)',
                  prefixIcon: Icon(Icons.square_foot),
                  hintText: '0.0',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final raw = v.replaceAll(',', '.');
                    if (double.tryParse(raw) == null) return 'Введите число';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cropController,
                decoration: const InputDecoration(
                  labelText: 'Культура',
                  prefixIcon: Icon(Icons.grass),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Примечания',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    double? area;
    if (_areaController.text.trim().isNotEmpty) {
      area = double.parse(_areaController.text.replaceAll(',', '.'));
    }

    final site = WorkSite(
      id: widget.site?.id,
      name: _nameController.text.trim(),
      areaHectares: area,
      cropType: _cropController.text.trim().isEmpty
          ? null
          : _cropController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final provider = context.read<AppProvider>();
    if (widget.site != null) {
      provider.updateWorkSite(site);
    } else {
      provider.addWorkSite(site);
    }

    Navigator.pop(context);
  }
}
