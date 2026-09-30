// lib/widgets/update_banner.dart
//
// Полоса над содержимым (шаг 4.8): программа старее минимальной версии
// сервера — обновиться обязательно (синхронизация на паузе); есть версия
// новее — можно обновиться. Windows — «Установить»: программа сама скачает
// и поставит новую версию (6.5); телефон — ссылка со страницы загрузки;
// веб — перезагрузка страницы.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/sync_provider.dart';
import '../services/page_reload.dart';
import '../services/platform.dart';
import 'update_install.dart';

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
    // Веб-версию обновляет перезагрузка страницы.
    final text = isWebApp
        ? required
              ? 'Вышла новая версия программы — ${v.latest} (открыта '
                    '${sync.appVersion}). Обновите страницу: до этого данные '
                    'не уходят на сервер, но всё введённое сохраняется.'
              : 'Вышла новая версия программы — ${v.latest}. Обновите '
                    'страницу, когда будет удобно.'
        : required
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
              if (isWebApp)
                TextButton(
                  onPressed: reloadPage,
                  child: const Text('Обновить страницу'),
                )
              else if (canInstallFrom(v))
                FilledButton.tonal(
                  onPressed: () => installUpdate(context, v),
                  child: const Text('Установить'),
                )
              else if (url != null)
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
