import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

/// Экран настроек КФХ
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  CompanySettings? _localSettings;
  bool _hasChanges = false;
  
  // Контроллеры для полей ввода
  late TextEditingController _companyNameController;
  late TextEditingController _directorNameController;
  late TextEditingController _innController;
  late TextEditingController _ogrnController;
  late TextEditingController _phoneController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankNameController;
  late TextEditingController _legalAddressController;
  late TextEditingController _defaultWorkDayHoursController;
  late TextEditingController _overtimeMultiplierController;
  late TextEditingController _nightShiftMultiplierController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadCompanySettings();
      _initControllers(provider.companySettings);
    });
  }

  void _initControllers(CompanySettings? settings) {
    final s = settings ?? CompanySettings();
    _companyNameController = TextEditingController(text: s.companyName ?? '');
    _directorNameController = TextEditingController(text: s.directorName ?? '');
    _innController = TextEditingController(text: s.inn ?? '');
    _ogrnController = TextEditingController(text: s.ogrn ?? '');
    _phoneController = TextEditingController(text: s.phone ?? '');
    _bankAccountController = TextEditingController(text: s.bankAccount ?? '');
    _bankNameController = TextEditingController(text: s.bankName ?? '');
    _legalAddressController = TextEditingController(text: s.legalAddress ?? '');
    _defaultWorkDayHoursController = TextEditingController(text: s.defaultWorkDayHours.toString());
    _overtimeMultiplierController = TextEditingController(text: s.overtimeMultiplier.toString());
    _nightShiftMultiplierController = TextEditingController(text: s.nightShiftMultiplier.toString());
    
    _setupListeners();
  }

  void _setupListeners() {
    void notifyChange() {
      setState(() {
        _hasChanges = true;
      });
    }

    _companyNameController.addListener(notifyChange);
    _directorNameController.addListener(notifyChange);
    _innController.addListener(notifyChange);
    _ogrnController.addListener(notifyChange);
    _phoneController.addListener(notifyChange);
    _bankAccountController.addListener(notifyChange);
    _bankNameController.addListener(notifyChange);
    _legalAddressController.addListener(notifyChange);
    _defaultWorkDayHoursController.addListener(notifyChange);
    _overtimeMultiplierController.addListener(notifyChange);
    _nightShiftMultiplierController.addListener(notifyChange);
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
    _defaultWorkDayHoursController.dispose();
    _overtimeMultiplierController.dispose();
    _nightShiftMultiplierController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_hasChanges) {
      final updatedSettings = CompanySettings(
        companyName: _companyNameController.text.isEmpty ? null : _companyNameController.text,
        directorName: _directorNameController.text.isEmpty ? null : _directorNameController.text,
        inn: _innController.text.isEmpty ? null : _innController.text,
        ogrn: _ogrnController.text.isEmpty ? null : _ogrnController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        bankAccount: _bankAccountController.text.isEmpty ? null : _bankAccountController.text,
        bankName: _bankNameController.text.isEmpty ? null : _bankNameController.text,
        legalAddress: _legalAddressController.text.isEmpty ? null : _legalAddressController.text,
        defaultWorkDayHours: double.tryParse(_defaultWorkDayHoursController.text) ?? 8.0,
        overtimeMultiplier: double.tryParse(_overtimeMultiplierController.text) ?? 1.5,
        nightShiftMultiplier: double.tryParse(_nightShiftMultiplierController.text) ?? 1.2,
      );
      
      context.read<AppProvider>().updateCompanySettings(updatedSettings);
      setState(() {
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки сохранены')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // Показываем индикатор загрузки только при первоначальной загрузке
          if (provider.isLoading && _companyNameController.text.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = provider.companySettings;
          if (settings == null && _companyNameController.text.isEmpty) {
            return const Center(child: Text('Не удалось загрузить настройки'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === Данные КФХ ===
              _buildSectionTitle(context, 'Данные КФХ'),
              _SettingsCard(
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Название КФХ',
                      controller: _companyNameController,
                      icon: Icons.business,
                    ),
                    _buildTextField(
                      label: 'ФИО руководителя',
                      controller: _directorNameController,
                      icon: Icons.person_outline,
                    ),
                    _buildTextField(
                      label: 'ИНН',
                      controller: _innController,
                      icon: Icons.numbers,
                    ),
                    _buildTextField(
                      label: 'ОГРН',
                      controller: _ogrnController,
                      icon: Icons.numbers,
                    ),
                    _buildTextField(
                      label: 'Телефон',
                      controller: _phoneController,
                      icon: Icons.phone,
                    ),
                  ],
                ),
              ),

              // === Банковские реквизиты ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Банковские реквизиты'),
              _SettingsCard(
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Расчётный счёт',
                      controller: _bankAccountController,
                      icon: Icons.account_balance,
                    ),
                    _buildTextField(
                      label: 'Банк',
                      controller: _bankNameController,
                      icon: Icons.account_balance_wallet,
                    ),
                  ],
                ),
              ),

              // === Юридический адрес ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Юридический адрес'),
              _SettingsCard(
                child: _buildTextField(
                  label: 'Адрес',
                  controller: _legalAddressController,
                  icon: Icons.location_on,
                  maxLines: 2,
                ),
              ),

              // === Параметры расчёта ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Параметры расчёта'),
              _SettingsCard(
                child: Column(
                  children: [
                    _buildNumberField(
                      label: 'Норма часов в день',
                      controller: _defaultWorkDayHoursController,
                      icon: Icons.access_time,
                      suffix: 'ч',
                    ),
                    _buildNumberField(
                      label: 'Коэффициент переработки',
                      controller: _overtimeMultiplierController,
                      icon: Icons.timer,
                      suffix: 'x',
                    ),
                    _buildNumberField(
                      label: 'Коэффициент ночных',
                      controller: _nightShiftMultiplierController,
                      icon: Icons.nights_stay,
                      suffix: 'x',
                    ),
                  ],
                ),
              ),

              // === Системные ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Система'),
              _SettingsCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('Резервное копирование'),
                      subtitle: const Text('Сохранить базу данных в файл'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Восстановление'),
                      subtitle: const Text('Загрузить базу из файла'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload),
                      title: const Text('Синхронизация с облаком'),
                      subtitle: const Text('Будет доступно в версии 2.0'),
                      trailing: const Icon(Icons.lock_outline),
                      enabled: false,
                      onTap: null,
                    ),
                    const Divider(height: 1),
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
                          children: [
                            const Text(
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
          );
        },
      ),
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
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixText: suffix,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  // Этот метод больше не используется, но оставлен для совместимости
  // void _updateSettings(CompanySettings settings) {
  //   context.read<AppProvider>().updateCompanySettings(settings);
  // }
}

/// Карточка настроек
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
