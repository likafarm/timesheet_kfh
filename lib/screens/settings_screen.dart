import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  CompanySettings? _localSettings;
  bool _hasChanges = false;

  // Сохраняем ссылку на провайдера для использования в dispose
  late AppProvider _provider;

  // Контроллеры для текстовых полей
  late final TextEditingController _companyNameController;
  late final TextEditingController _directorNameController;
  late final TextEditingController _innController;
  late final TextEditingController _ogrnController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _legalAddressController;
  late final TextEditingController _defaultWorkDayHoursController;
  late final TextEditingController _overtimeMultiplierController;
  late final TextEditingController _nightShiftMultiplierController;

  // FocusNode для числовых полей
  final _defaultHoursFocus = FocusNode();
  final _overtimeFocus = FocusNode();
  final _nightShiftFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Сохраняем ссылку на провайдера
    _provider = context.read<AppProvider>();

    // Создаём контроллеры с пустыми строками
    _companyNameController = TextEditingController();
    _directorNameController = TextEditingController();
    _innController = TextEditingController();
    _ogrnController = TextEditingController();
    _phoneController = TextEditingController();
    _bankAccountController = TextEditingController();
    _bankNameController = TextEditingController();
    _legalAddressController = TextEditingController();
    _defaultWorkDayHoursController = TextEditingController(text: '8.0');
    _overtimeMultiplierController = TextEditingController(text: '1.5');
    _nightShiftMultiplierController = TextEditingController(text: '1.2');

    // Настройка числовых полей
    _setupNumberField(_defaultWorkDayHoursController, _defaultHoursFocus);
    _setupNumberField(_overtimeMultiplierController, _overtimeFocus);
    _setupNumberField(_nightShiftMultiplierController, _nightShiftFocus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Используем сохранённого провайдера
      _provider.loadCompanySettings();
      _provider.addListener(_onProviderChanged);
    });
  }

  void _setupNumberField(
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    controller.addListener(() {
      final text = controller.text;
      if (text.contains(',')) {
        controller.text = text.replaceAll(',', '.');
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    });

    focusNode.addListener(() {
      if (!mounted) return;
      if (!focusNode.hasFocus) {
        final raw = controller.text
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll(',', '.');
        if (raw.isNotEmpty) {
          final value = double.tryParse(raw);
          if (value != null) {
            final formatter = NumberFormat('#,##0.00', 'ru');
            controller.text = formatter.format(value);
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        }
      } else {
        final raw = controller.text
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll(',', '.');
        if (raw.isNotEmpty) {
          final value = double.tryParse(raw);
          if (value != null) {
            controller.text = value.toString();
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        }
      }
    });
  }

  void _onProviderChanged() {
    final settings = _provider.companySettings;
    if (settings != null && settings != _localSettings) {
      setState(() {
        _localSettings = settings;
        _updateControllersFromSettings(settings);
      });
    }
  }

  void _updateControllersFromSettings(CompanySettings settings) {
    _companyNameController.text = settings.companyName;
    _directorNameController.text = settings.directorName ?? '';
    _innController.text = settings.inn ?? '';
    _ogrnController.text = settings.ogrn ?? '';
    _phoneController.text = settings.phone ?? '';
    _bankAccountController.text = settings.bankAccount ?? '';
    _bankNameController.text = settings.bankName ?? '';
    _legalAddressController.text = settings.legalAddress ?? '';
    _defaultWorkDayHoursController.text = settings.defaultWorkDayHours
        .toString();
    _overtimeMultiplierController.text = settings.overtimeMultiplier.toString();
    _nightShiftMultiplierController.text = settings.nightShiftMultiplier
        .toString();

    // Форматируем числовые поля
    _formatControllerText(_defaultWorkDayHoursController);
    _formatControllerText(_overtimeMultiplierController);
    _formatControllerText(_nightShiftMultiplierController);
  }

  void _formatControllerText(TextEditingController controller) {
    final raw = controller.text
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(',', '.');
    if (raw.isNotEmpty) {
      final value = double.tryParse(raw);
      if (value != null) {
        final formatter = NumberFormat('#,##0.00', 'ru');
        controller.text = formatter.format(value);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    // Отписываемся от провайдера, используя сохранённую ссылку
    _provider.removeListener(_onProviderChanged);

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
    _defaultHoursFocus.dispose();
    _overtimeFocus.dispose();
    _nightShiftFocus.dispose();
    super.dispose();
  }

  void _updateLocalSettings(CompanySettings newSettings) {
    setState(() {
      _localSettings = newSettings;
      _hasChanges = true;
    });
  }

  void _saveSettings() {
    if (_localSettings != null && _hasChanges) {
      _provider.updateCompanySettings(_localSettings!);
      setState(() {
        _hasChanges = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Настройки сохранены')));
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
          // Если настройки ещё не загружены, показываем индикатор
          if (provider.isLoading && _localSettings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = _localSettings ?? provider.companySettings;
          if (settings == null) {
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
                      controller: _companyNameController,
                      label: 'Название КФХ',
                      icon: Icons.business,
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(companyName: v),
                      ),
                    ),
                    _buildTextField(
                      controller: _directorNameController,
                      label: 'ФИО руководителя',
                      icon: Icons.person_outline,
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(directorName: v),
                      ),
                    ),
                    _buildTextField(
                      controller: _innController,
                      label: 'ИНН',
                      icon: Icons.numbers,
                      onChanged: (v) =>
                          _updateLocalSettings(settings.copyWith(inn: v)),
                    ),
                    _buildTextField(
                      controller: _ogrnController,
                      label: 'ОГРН',
                      icon: Icons.numbers,
                      onChanged: (v) =>
                          _updateLocalSettings(settings.copyWith(ogrn: v)),
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Телефон',
                      icon: Icons.phone,
                      onChanged: (v) =>
                          _updateLocalSettings(settings.copyWith(phone: v)),
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
                      controller: _bankAccountController,
                      label: 'Расчётный счёт',
                      icon: Icons.account_balance,
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(bankAccount: v),
                      ),
                    ),
                    _buildTextField(
                      controller: _bankNameController,
                      label: 'Банк',
                      icon: Icons.account_balance_wallet,
                      onChanged: (v) =>
                          _updateLocalSettings(settings.copyWith(bankName: v)),
                    ),
                  ],
                ),
              ),

              // === Юридический адрес ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Юридический адрес'),
              _SettingsCard(
                child: _buildTextField(
                  controller: _legalAddressController,
                  label: 'Адрес',
                  icon: Icons.location_on,
                  maxLines: 2,
                  onChanged: (v) =>
                      _updateLocalSettings(settings.copyWith(legalAddress: v)),
                ),
              ),

              // === Параметры расчёта ===
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Параметры расчёта'),
              _SettingsCard(
                child: Column(
                  children: [
                    _buildNumberField(
                      controller: _defaultWorkDayHoursController,
                      focusNode: _defaultHoursFocus,
                      label: 'Норма часов в день',
                      icon: Icons.access_time,
                      suffix: 'ч',
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(defaultWorkDayHours: v),
                      ),
                    ),
                    _buildNumberField(
                      controller: _overtimeMultiplierController,
                      focusNode: _overtimeFocus,
                      label: 'Коэффициент переработки',
                      icon: Icons.timer,
                      suffix: 'x',
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(overtimeMultiplier: v),
                      ),
                    ),
                    _buildNumberField(
                      controller: _nightShiftMultiplierController,
                      focusNode: _nightShiftFocus,
                      label: 'Коэффициент ночных',
                      icon: Icons.nights_stay,
                      suffix: 'x',
                      onChanged: (v) => _updateLocalSettings(
                        settings.copyWith(nightShiftMultiplier: v),
                      ),
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
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixText: suffix,
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*$')),
        ],
        onChanged: (v) {
          final raw = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
          final parsed = double.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
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
