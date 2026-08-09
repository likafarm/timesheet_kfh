import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Экран управления видами работ
class WorkTypesScreen extends StatefulWidget {
  const WorkTypesScreen({super.key});

  @override
  State<WorkTypesScreen> createState() => _WorkTypesScreenState();
}

class _WorkTypesScreenState extends State<WorkTypesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadWorkTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Виды работ'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(context),
            tooltip: 'Добавить вид работы',
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
                    onPressed: () => provider.loadWorkTypes(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (provider.workTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет видов работ',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить первый вид работы'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.workTypes.length,
            itemBuilder: (context, index) {
              final workType = provider.workTypes[index];
              return _WorkTypeCard(
                workType: workType,
                onEdit: () => _showFormDialog(context, workType: workType),
                onDelete: () => _confirmDelete(context, workType),
              );
            },
          );
        },
      ),
    );
  }

  void _showFormDialog(BuildContext context, {WorkType? workType}) {
    showDialog(
      context: context,
      builder: (context) => _WorkTypeFormDialog(workType: workType),
    );
  }

  void _confirmDelete(BuildContext context, WorkType workType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление вида работы'),
        content: Text(
          'Удалить "${workType.name}"?\n\n'
          'Записи табеля, использующие этот вид работы, останутся, '
          'но связь будет разорвана (поле станет пустым).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().deleteWorkType(workType.id!);
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

/// Карточка вида работы
class _WorkTypeCard extends StatelessWidget {
  final WorkType workType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkTypeCard({
    required this.workType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _getCategoryIcon(workType.category),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          workType.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Категория: ${workType.categoryName}'),
            if (workType.defaultRateMultiplier != null)
              Text(
                'Множитель: ${workType.defaultRateMultiplier!.toStringAsFixed(2)}x',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (workType.notes != null && workType.notes!.isNotEmpty)
              Text(
                workType.notes!,
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'field':
        return Icons.agriculture;
      case 'animal':
        return Icons.pets;
      case 'repair':
        return Icons.build;
      default:
        return Icons.category;
    }
  }
}

/// Диалог формы вида работы
class _WorkTypeFormDialog extends StatefulWidget {
  final WorkType? workType;

  const _WorkTypeFormDialog({this.workType});

  @override
  State<_WorkTypeFormDialog> createState() => _WorkTypeFormDialogState();
}

class _WorkTypeFormDialogState extends State<_WorkTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _category = 'field';
  final _multiplierController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.workType != null) {
      _nameController.text = widget.workType!.name;
      _category = widget.workType!.category;
      _multiplierController.text =
          widget.workType!.defaultRateMultiplier?.toString() ?? '';
      _notesController.text = widget.workType!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _multiplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workType != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Редактирование вида работы' : 'Новый вид работы',
      ),
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
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isDense: true,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'field',
                        child: Text('Полевые работы'),
                      ),
                      DropdownMenuItem(
                        value: 'animal',
                        child: Text('Животноводство'),
                      ),
                      DropdownMenuItem(value: 'repair', child: Text('Ремонт')),
                      DropdownMenuItem(value: 'other', child: Text('Прочее')),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _multiplierController,
                decoration: const InputDecoration(
                  labelText: 'Множитель ставки',
                  prefixIcon: Icon(Icons.trending_up),
                  hintText: '1.0 (по умолчанию)',
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

    double? multiplier;
    if (_multiplierController.text.trim().isNotEmpty) {
      multiplier = double.parse(
        _multiplierController.text.replaceAll(',', '.'),
      );
    }

    final workType = WorkType(
      id: widget.workType?.id,
      name: _nameController.text.trim(),
      category: _category,
      defaultRateMultiplier: multiplier,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final provider = context.read<AppProvider>();
    if (widget.workType != null) {
      provider.updateWorkType(workType);
    } else {
      provider.addWorkType(workType);
    }

    Navigator.pop(context);
  }
}
