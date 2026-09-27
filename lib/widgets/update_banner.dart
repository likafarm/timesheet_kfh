// lib/widgets/update_banner.dart
//
// Полоса над содержимым (шаг 4.8): программа старее минимальной версии
// сервера — обновиться обязательно (синхронизация на паузе); есть версия
// новее — можно обновиться. Ссылка — со страницы загрузки на сервере.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/sync_provider.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final v = sync.serverVersion;
    if (v == null || !sync.updateAvailable) return const SizedBox.shrink();
    final required = sync.updateRequired;
    final url = v.url;
    final color = required ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final text = required
        ? 'Нужна новая версия программы — ${v.latest} (у вас '
              '${sync.appVersion}). Пока не обновите, данные не уходят на '
              'сервер, но всё введённое сохраняется.'
        : 'Доступна новая версия программы — ${v.latest}.';
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                required ? Icons.system_update : Icons.info_outline,
                color: required ? const Color(0xFFB26A00) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              if (url != null)
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Скачать'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
