// lib/screens/about_screen.dart
//
// «О программе» (6.10): на телефоне — страница на весь экран, как
// «Лицензии»; внизу в одну строку «Лицензии» и «Закрыть». На широком
// экране — обычное окно.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _appName = 'Учёт рабочего времени КФХ';

List<Widget> _aboutText(String databasePath) => [
  const Text(
    'Программа для ведения табеля учёта рабочего времени, расчёта зарплаты '
    'и формирования отчётов в КФХ.',
  ),
  const SizedBox(height: 12),
  const Text('Правообладатель: Иван Лопатин.\nКонтакты: iilopatin@ya.ru'),
  const SizedBox(height: 12),
  SelectableText('База данных:\n$databasePath'),
];

void openAbout(
  BuildContext context, {
  required String version,
  required String databasePath,
}) {
  if (MediaQuery.sizeOf(context).width >= AppTheme.compactWidth) {
    showAboutDialog(
      context: context,
      applicationName: _appName,
      applicationVersion: version,
      applicationIcon: const Icon(Icons.agriculture, size: 48),
      children: _aboutText(databasePath),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AboutScreen(version: version, databasePath: databasePath),
    ),
  );
}

class AboutScreen extends StatelessWidget {
  final String version;
  final String databasePath;

  const AboutScreen({
    super.key,
    required this.version,
    required this.databasePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('О программе'), centerTitle: false),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    Icons.agriculture,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'Версия $version',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ..._aboutText(databasePath),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: _appName,
                        applicationVersion: version,
                      ),
                      child: const Text('Лицензии'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
