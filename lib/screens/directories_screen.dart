import 'package:flutter/material.dart';
import 'work_types_screen.dart';
import 'work_sites_screen.dart';
import 'machinery_screen.dart';

/// Экран управления справочниками (аналог экрана выплат)
/// Слева — список справочников, справа — содержимое выбранного
class DirectoriesScreen extends StatefulWidget {
  const DirectoriesScreen({super.key});

  @override
  State<DirectoriesScreen> createState() => _DirectoriesScreenState();
}

class _DirectoriesScreenState extends State<DirectoriesScreen> {
  int _selectedIndex = 0;

  final List<DirectoryItem> _directories = [
    DirectoryItem(
      icon: Icons.category,
      label: 'Виды работ',
      screen: const WorkTypesScreen(),
    ),
    DirectoryItem(
      icon: Icons.agriculture,
      label: 'Участки',
      screen: const WorkSitesScreen(),
    ),
    DirectoryItem(
      icon: Icons.precision_manufacturing,
      label: 'Техника',
      screen: const MachineryScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Справочники'), centerTitle: false),
      body: Row(
        children: [
          // Список справочников слева
          SizedBox(
            width: 260,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Справочники',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _directories.length,
                      itemBuilder: (context, index) {
                        final item = _directories[index];
                        final isSelected = index == _selectedIndex;

                        return ListTile(
                          selected: isSelected,
                          dense: true,
                          leading: Icon(
                            item.icon,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Содержимое выбранного справочника
          Expanded(child: _directories[_selectedIndex].screen),
        ],
      ),
    );
  }
}

/// Модель пункта справочника
class DirectoryItem {
  final IconData icon;
  final String label;
  final Widget screen;

  const DirectoryItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
