// lib/widgets/adaptive_dialog.dart
//
// Окна форм (шаг 4.5): на широком экране — обычное окно по центру, на
// телефоне — панель снизу экрана (до кнопок дотягивается большой палец,
// клавиатура не закрывает поля).

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Открыть форму [builder]: телефон — панель снизу, иначе — окно.
/// [barrierDismissible] = false — закрыть только кнопками формы.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (MediaQuery.sizeOf(context).width >= AppTheme.compactWidth) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: barrierDismissible,
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    builder: (context) => _SheetScope(child: builder(context)),
  );
}

/// Форма открыта панелью снизу.
class _SheetScope extends InheritedWidget {
  const _SheetScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetScope>() != null;

  @override
  bool updateShouldNotify(_SheetScope oldWidget) => false;
}

/// Форма: заголовок, содержимое, кнопки. Внутри [showAppDialog] на
/// телефоне — панель снизу, иначе — [AlertDialog].
class AppDialog extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  const AppDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (!_SheetScope.of(context)) {
      return AlertDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
      );
    }
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(child: icon!),
              const SizedBox(height: 8),
            ],
            if (title != null)
              DefaultTextStyle(
                style: theme.textTheme.titleLarge!,
                child: title!,
              ),
            const SizedBox(height: 12),
            if (content != null)
              Flexible(child: SingleChildScrollView(child: content!)),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
