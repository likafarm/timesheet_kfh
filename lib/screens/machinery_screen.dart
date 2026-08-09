import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Экран управления техникой
class MachineryScreen extends StatefulWidget {
  const MachineryScreen({super.key});

  @override
  State<MachineryScreen> createState() => _MachineryScreenState();
}

class _MachineryScreenState extends State<MachineryScreen> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadMachinery();
    });
  }

  void _toggleFilter() {
    setState(() {
      _showAll = !_showAll;
      context.read<AppProvider>().loadMachinery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Техника и оборудование'),
        centerTitle: false,
        actions: [
          Row(
            children: [
              const Text('Только активная'),
              Switch(value: !_showAll, onChanged: (_) => _toggleFilter()),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(context),
            tooltip: 'Добавить технику',
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
                    onPressed: () => provider.loadMachinery(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final displayList = _showAll
              ? provider.machinery
              : provider.machinery.where((m) => m.isActive).toList();

          if (displayList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showAll ? 'Нет техники' : 'Нет активной техники',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить технику'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final item = displayList[index];
              return _MachineryCard(
                machinery: item,
                onEdit: () => _showFormDialog(context, machinery: item),
                onDelete: () => _confirmDelete(context, item),
                onToggle: () => _toggleActive(context, item),
              );
            },
          );
        },
      ),
    );
  }

  void _showFormDialog(BuildContext context, {Machinery? machinery}) {
    showDialog(
      context: context,
      builder: (context) => _MachineryFormDialog(machinery: machinery),
    );
  }

  void _confirmDelete(BuildContext context, Machinery machinery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление техники'),
        content: Text(
          'Удалить "${machinery.name}"?\n\n'
          'Записи табеля, использующие эту технику, останутся, '
          'но связь будет разорвана.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().deleteMachinery(machinery.id!);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _toggleActive(BuildContext context, Machinery machinery) {
    final updated = machinery.copyWith(isActive: !machinery.isActive);
    context.read<AppProvider>().updateMachinery(updated);
  }
}

/// Карточка техники
class _MachineryCard extends StatelessWidget {
  final Machinery machinery;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _MachineryCard({
    required this.machinery,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: machinery.isActive
              ? Colors.blue[100]
              : Colors.grey[300],
          child: Icon(
            _getTypeIcon(machinery.type),
            color: machinery.isActive ? Colors.blue : Colors.grey[600],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                machinery.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: machinery.isActive
                      ? null
                      : TextDecoration.lineThrough,
                  color: machinery.isActive ? null : Colors.grey,
                ),
              ),
            ),
            if (!machinery.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Неактивна',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип: ${machinery.typeName}'),
            if (machinery.registrationNumber != null &&
                machinery.registrationNumber!.isNotEmpty)
              Text('Госномер: ${machinery.registrationNumber}'),
            if (machinery.fuelConsumptionPerHour != null)
              Text(
                'Расход топлива: ${machinery.fuelConsumptionPerHour!.toStringAsFixed(2)} л/ч',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (machinery.notes != null && machinery.notes!.isNotEmpty)
              Text(
                machinery.notes!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'toggle') onToggle();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(
                machinery.isActive ? 'Деактивировать' : 'Активировать',
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'tractor':
        return Icons.agriculture; // Вместо Icons.tractor
      case 'combine':
        return Icons.agriculture;
      case 'truck':
        return Icons.local_shipping;
      case 'implement':
        return Icons.handyman;
      default:
        return Icons.precision_manufacturing;
    }
  }
}

/// Диалог формы техники
class _MachineryFormDialog extends StatefulWidget {
  final Machinery? machinery;

  const _MachineryFormDialog({this.machinery});

  @override
  State<_MachineryFormDialog> createState() => _MachineryFormDialogState();
}

class _MachineryFormDialogState extends State<_MachineryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _type = 'tractor';
  final _regNumberController = TextEditingController();
  final _fuelController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.machinery != null) {
      _nameController.text = widget.machinery!.name;
      _type = widget.machinery!.type;
      _regNumberController.text = widget.machinery!.registrationNumber ?? '';
      _fuelController.text =
          widget.machinery!.fuelConsumptionPerHour?.toString() ?? '';
      _notesController.text = widget.machinery!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regNumberController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.machinery != null;

    return AlertDialog(
      title: Text(isEditing ? 'Редактирование техники' : 'Новая техника'),
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
                  labelText: 'Тип',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isDense: true,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'tractor',
                        child: Text('Трактор'),
                      ),
                      DropdownMenuItem(
                        value: 'combine',
                        child: Text('Комбайн'),
                      ),
                      DropdownMenuItem(value: 'truck', child: Text('Грузовик')),
                      DropdownMenuItem(
                        value: 'implement',
                        child: Text('Орудие/прицеп'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regNumberController,
                decoration: const InputDecoration(
                  labelText: 'Госномер',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fuelController,
                decoration: const InputDecoration(
                  labelText: 'Расход топлива (л/ч)',
                  prefixIcon: Icon(Icons.local_gas_station),
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

    double? fuel;
    if (_fuelController.text.trim().isNotEmpty) {
      fuel = double.parse(_fuelController.text.replaceAll(',', '.'));
    }

    final machinery = Machinery(
      id: widget.machinery?.id,
      name: _nameController.text.trim(),
      type: _type,
      registrationNumber: _regNumberController.text.trim().isEmpty
          ? null
          : _regNumberController.text.trim(),
      fuelConsumptionPerHour: fuel,
      isActive: widget.machinery?.isActive ?? true,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final provider = context.read<AppProvider>();
    if (widget.machinery != null) {
      provider.updateMachinery(machinery);
    } else {
      provider.addMachinery(machinery);
    }

    Navigator.pop(context);
  }
}
