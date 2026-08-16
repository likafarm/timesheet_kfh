// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'database_viewer_screen.dart';
import 'backup_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _directorNameController = TextEditingController();
  final _innController = TextEditingController();
  final _ogrnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _legalAddressController = TextEditingController();

  bool _hasChanges = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCompanySettings();
    });
  }

  void _updateControllers(Map<String, dynamic>? settings) {
    if (settings == null) return;
    _companyNameController.text = settings['company_name'] ?? '';
    _directorNameController.text = settings['director_name'] ?? '';
    _innController.text = settings['inn'] ?? '';
    _ogrnController.text = settings['ogrn'] ?? '';
    _phoneController.text = settings['phone'] ?? '';
    _bankAccountController.text = settings['bank_account'] ?? '';
    _bankNameController.text = settings['bank_name'] ?? '';
    _legalAddressController.text = settings['legal_address'] ?? '';
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = {
      'company_name': _companyNameController.text.trim(),
      'director_name': _directorNameController.text.trim(),
      'inn': _innController.text.trim(),
      'ogrn': _ogrnController.text.trim(),
      'phone': _phoneController.text.trim(),
      'bank_account': _bankAccountController.text.trim(),
      'bank_name': _bankNameController.text.trim(),
      'legal_address': _legalAddressController.text.trim(),
    };
    await context.read<AppProvider>().updateCompanySettings(settings);
    setState(() => _hasChanges = false);
    if (!mounted) return; // Используем State.mounted, а не context.mounted
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Настройки сохранены')));
  }

  void _onFieldChanged(String _) {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _directorNameController.dispose();
    _innController.dispose();
    _ogrnController.dispose();
    _phoneController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _legalAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading || provider.companySettings == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Настройки')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!_initialized) {
          _updateControllers(provider.companySettings);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Настройки'),
            centerTitle: false,
            actions: [
              if (_hasChanges)
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Данные КФХ'),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _companyNameController,
                          label: 'Название КФХ *',
                          icon: Icons.business,
                          onChanged: _onFieldChanged,
                          validator: (v) => v?.trim().isEmpty == true
                              ? 'Обязательное поле'
                              : null,
                        ),
                        _buildTextField(
                          controller: _directorNameController,
                          label: 'ФИО руководителя',
                          icon: Icons.person_outline,
                          onChanged: _onFieldChanged,
                        ),
                        _buildTextField(
                          controller: _innController,
                          label: 'ИНН',
                          icon: Icons.numbers,
                          onChanged: _onFieldChanged,
                        ),
                        _buildTextField(
                          controller: _ogrnController,
                          label: 'ОГРН',
                          icon: Icons.numbers,
                          onChanged: _onFieldChanged,
                        ),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Телефон',
                          icon: Icons.phone,
                          onChanged: _onFieldChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle(context, 'Банковские реквизиты'),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _bankAccountController,
                          label: 'Расчётный счёт',
                          icon: Icons.account_balance,
                          onChanged: _onFieldChanged,
                        ),
                        _buildTextField(
                          controller: _bankNameController,
                          label: 'Банк',
                          icon: Icons.account_balance_wallet,
                          onChanged: _onFieldChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle(context, 'Юридический адрес'),
                  _SettingsCard(
                    child: _buildTextField(
                      controller: _legalAddressController,
                      label: 'Адрес',
                      icon: Icons.location_on,
                      maxLines: 2,
                      onChanged: _onFieldChanged,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Система'),
                  _SettingsCard(
                    child: Column(
                      children: [
                        // Резервное копирование
                        ListTile(
                          leading: const Icon(Icons.backup),
                          title: const Text('Резервное копирование'),
                          subtitle: const Text(
                            'Создать копию базы данных сейчас',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final provider = context.read<AppProvider>();
                            final path = await provider.createBackup();
                            if (!context.mounted) return;
                            if (path != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Резервная копия создана'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ошибка создания копии'),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1),

                        // Восстановление
                        ListTile(
                          leading: const Icon(Icons.restore),
                          title: const Text('Восстановление'),
                          subtitle: const Text('Восстановить данные из копии'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BackupListScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // Просмотр базы данных
                        ListTile(
                          leading: const Icon(Icons.storage),
                          title: const Text('Просмотр базы данных'),
                          subtitle: const Text(
                            'Просмотр содержимого таблиц (отладка)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DatabaseViewerScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // Синхронизация с облаком (заглушка)
                        ListTile(
                          leading: const Icon(Icons.cloud_upload),
                          title: const Text('Синхронизация с облаком'),
                          subtitle: const Text('Будет доступно в версии 2.0'),
                          trailing: const Icon(Icons.lock_outline),
                          enabled: false,
                        ),
                        const Divider(height: 1),

                        // О программе
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('О программе'),
                          subtitle: const Text('Версия 1.0.0'),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Учёт рабочего времени КФХ',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Icon(
                                Icons.agriculture,
                                size: 48,
                              ),
                              children: const [
                                Text(
                                  'Программа для ведения табеля учёта рабочего времени, '
                                  'расчёта зарплаты и формирования отчётов в КФХ.',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
