// lib/screens/settings_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:kfh_domain/kfh_domain.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../services/platform.dart';
import 'about_screen.dart';
import 'audit_screen.dart';
import 'periods_screen.dart';
import 'sync_screen.dart';
import 'database_viewer_screen.dart';
import 'backups_screen.dart';
import 'help_screen.dart';

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
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCompanySettings();
    });
  }

  void _updateControllers(CompanySettings? settings) {
    if (settings == null) return;
    _companyNameController.text = settings.companyName;
    _directorNameController.text = settings.directorName ?? '';
    _innController.text = settings.inn ?? '';
    _ogrnController.text = settings.ogrn ?? '';
    _phoneController.text = settings.phone ?? '';
    _bankAccountController.text = settings.bankAccount ?? '';
    _bankNameController.text = settings.bankName ?? '';
    _legalAddressController.text = settings.legalAddress ?? '';
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    final current = provider.companySettings;
    if (current == null) return;
    // Поля присваиваются напрямую, а не через copyWith: пустая строка
    // тоже значение (поле очищено).
    final settings = CompanySettings(
      id: current.id,
      companyName: _companyNameController.text.trim(),
      directorName: _directorNameController.text.trim(),
      inn: _innController.text.trim(),
      ogrn: _ogrnController.text.trim(),
      phone: _phoneController.text.trim(),
      bankAccount: _bankAccountController.text.trim(),
      bankName: _bankNameController.text.trim(),
      legalAddress: _legalAddressController.text.trim(),
      defaultWorkDayHours: current.defaultWorkDayHours,
      overtimeMultiplier: current.overtimeMultiplier,
      nightShiftMultiplier: current.nightShiftMultiplier,
    );
    await provider.updateCompanySettings(settings);
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
                        // Модуль «Резервные копии» — только Windows и только
                        // админ (решение владельца 2026-09-30). В веб-версии
                        // и на телефоне копий нет: база там — копия данных
                        // сервера. Автоматические копии при запуске
                        // делаются у всех.
                        if (context.read<AppProvider>().hasLocalBackups &&
                            !isAndroidApp &&
                            context.watch<SyncProvider>().canUseBackups) ...[
                          ListTile(
                            leading: const Icon(Icons.backup),
                            title: const Text('Резервные копии'),
                            subtitle: const Text(
                              'Копии этого компьютера и сервера: посмотреть, '
                              'сравнить, вернуть записи',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BackupsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        if (kDebugMode && !isAndroidApp) ...[
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
                        ],

                        // Закрытие месяцев — бухгалтер и админ (6.2).
                        if (context.watch<SyncProvider>().canLockMonths) ...[
                          ListTile(
                            leading: const Icon(Icons.lock_clock),
                            title: const Text('Закрытие месяцев'),
                            subtitle: const Text(
                              'Зафиксировать расчёт и запретить правки',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PeriodsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],

                        // Журнал действий — только админ (6.7).
                        if (context.watch<SyncProvider>().canReadAudit) ...[
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Журнал действий'),
                            subtitle: const Text('Кто, когда и что изменил'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuditScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],

                        // Сервер синхронизации
                        ListTile(
                          leading: const Icon(Icons.cloud_sync),
                          title: const Text('Сервер синхронизации'),
                          subtitle: Text(
                            context.watch<SyncProvider>().user == null
                                ? 'Вход не выполнен'
                                : 'Вход: ${context.watch<SyncProvider>().user!.login}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SyncScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Справка'),
                          subtitle: const Text(
                            'Как работать с программой — по вашей роли',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // О программе
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('О программе'),
                          subtitle: Text('Версия $_version'),
                          onTap: () => openAbout(
                            context,
                            version: _version,
                            databasePath: context
                                .read<AppProvider>()
                                .databasePath,
                          ),
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
