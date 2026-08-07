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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCompanySettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), centerTitle: false),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = provider.companySettings;
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
                      label: 'Название КФХ',
                      value: settings.companyName,
                      icon: Icons.business,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(companyName: v)),
                    ),
                    _buildTextField(
                      label: 'ФИО руководителя',
                      value: settings.directorName,
                      icon: Icons.person_outline,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(directorName: v)),
                    ),
                    _buildTextField(
                      label: 'ИНН',
                      value: settings.inn,
                      icon: Icons.numbers,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(inn: v)),
                    ),
                    _buildTextField(
                      label: 'ОГРН',
                      value: settings.ogrn,
                      icon: Icons.numbers,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(ogrn: v)),
                    ),
                    _buildTextField(
                      label: 'Телефон',
                      value: settings.phone,
                      icon: Icons.phone,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(phone: v)),
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
                      value: settings.bankAccount,
                      icon: Icons.account_balance,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(bankAccount: v)),
                    ),
                    _buildTextField(
                      label: 'Банк',
                      value: settings.bankName,
                      icon: Icons.account_balance_wallet,
                      onChanged: (v) =>
                          _updateSettings(settings.copyWith(bankName: v)),
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
                  value: settings.legalAddress,
                  icon: Icons.location_on,
                  maxLines: 2,
                  onChanged: (v) =>
                      _updateSettings(settings.copyWith(legalAddress: v)),
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
                      value: settings.defaultWorkDayHours,
                      icon: Icons.access_time,
                      suffix: 'ч',
                      onChanged: (v) => _updateSettings(
                        settings.copyWith(defaultWorkDayHours: v),
                      ),
                    ),
                    _buildNumberField(
                      label: 'Коэффициент переработки',
                      value: settings.overtimeMultiplier,
                      icon: Icons.timer,
                      suffix: 'x',
                      onChanged: (v) => _updateSettings(
                        settings.copyWith(overtimeMultiplier: v),
                      ),
                    ),
                    _buildNumberField(
                      label: 'Коэффициент ночных',
                      value: settings.nightShiftMultiplier,
                      icon: Icons.nights_stay,
                      suffix: 'x',
                      onChanged: (v) => _updateSettings(
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
    required String? value,
    required IconData icon,
    int maxLines = 1,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: TextEditingController(text: value ?? ''),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        maxLines: maxLines,
        onChanged: (v) => onChanged(v.isEmpty ? null : v),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required IconData icon,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: TextEditingController(text: value.toString()),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixText: suffix,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  void _updateSettings(CompanySettings settings) {
    // Отложенное сохранение — можно добавить debounce
    context.read<AppProvider>().updateCompanySettings(settings);
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
