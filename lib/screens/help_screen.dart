// lib/screens/help_screen.dart
//
// «Справка» (шаг 4 «Дальнейших работ»): инструкция по роли — оператор,
// бухгалтер, администратор. Своя роль открывается сразу, чужую можно
// выбрать (например, администратор смотрит, что видит оператор).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../help/help_content.dart';
import '../providers/sync_provider.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';

/// Роль вошедшего для справки (без входа — бухгалтер).
HelpRole helpRoleOf(SyncProvider? sync) {
  final user = sync?.user;
  if (user == null) return HelpRole.accountant;
  if (user.isAdmin) return HelpRole.admin;
  if (user.isOperator) return HelpRole.operator;
  return HelpRole.accountant;
}

class HelpScreen extends StatefulWidget {
  /// Роль; null — роль вошедшего.
  final HelpRole? role;

  const HelpScreen({super.key, this.role});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late HelpRole _role =
      widget.role ?? helpRoleOf(context.read<SyncProvider?>());

  @override
  Widget build(BuildContext context) {
    final chapters = helpFor(_role);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать / PDF',
            onPressed: () => PrintService.printHelp(_role),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Инструкция для', style: theme.textTheme.titleMedium),
                  SegmentedButton<HelpRole>(
                    segments: [
                      for (final r in HelpRole.values)
                        ButtonSegment(value: r, label: Text(r.title)),
                    ],
                    selected: {_role},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _role = v.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final (i, c) in chapters.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        title: Text(c.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HelpChapterScreen(
                              role: _role,
                              chapters: chapters,
                              index: i,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Один раздел инструкции; внизу — переход к соседним.
class HelpChapterScreen extends StatelessWidget {
  final HelpRole role;
  final List<HelpChapter> chapters;
  final int index;

  const HelpChapterScreen({
    super.key,
    required this.role,
    required this.chapters,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final chapter = chapters[index];
    final theme = Theme.of(context);
    void go(int i) => Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HelpChapterScreen(role: role, chapters: chapters, index: i),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(chapter.title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            children: [
              for (final b in chapter.blocksFor(role)) HelpBlockView(b),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (index > 0)
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () => go(index - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: Text(
                          chapters[index - 1].title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (index < chapters.length - 1)
                    Flexible(
                      child: TextButton(
                        onPressed: () => go(index + 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                chapters[index + 1].title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                'Раздел ${index + 1} из ${chapters.length}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кусок раздела на экране.
class HelpBlockView extends StatelessWidget {
  final HelpBlock block;

  const HelpBlockView(this.block, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.4);
    return switch (block) {
      HelpText(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: body),
      ),
      HelpHeading(:final text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
      HelpList(:final items, :final numbered) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, item) in items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(numbered ? '${i + 1}.' : '•', style: body),
                    ),
                    Expanded(child: Text(item, style: body)),
                  ],
                ),
              ),
          ],
        ),
      ),
      HelpNote(:final text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: body?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      HelpImage(:final asset, :final caption, :final phone) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: phone ? 300 : 860),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Image.asset(
                  asset,
                  // Снимка ещё нет (не сняты) — без картинки.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    };
  }
}
