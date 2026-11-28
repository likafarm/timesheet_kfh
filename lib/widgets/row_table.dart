// lib/widgets/row_table.dart
//
// Таблица строками для широкого экрана (продажи, 11.4–11.6): заголовок и
// строки с одинаковыми столбцами — шириной (`width`) или долей (`flex`).
// Строка нажимается (открыть запись), может быть с отступом (часть набора)
// и серой (снята, отменена). На телефоне вместо таблиц — карточки.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Экран достаточно широк для таблицы.
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppTheme.compactWidth;

/// Столбец таблицы: [width] — ровно столько, иначе доля [flex].
class RowCol {
  final String label;
  final double? width;
  final int flex;
  final bool right;
  const RowCol(this.label, {this.width, this.flex = 1, this.right = false});
}

Widget _cell(RowCol col, Widget child) {
  final aligned = Align(
    alignment: col.right ? Alignment.topRight : Alignment.topLeft,
    child: child,
  );
  final padded = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: aligned,
  );
  return col.width != null
      ? SizedBox(width: col.width, child: padded)
      : Expanded(flex: col.flex, child: padded);
}

/// Заголовок таблицы.
class RowTableHeader extends StatelessWidget {
  final List<RowCol> cols;
  final EdgeInsetsGeometry padding;
  const RowTableHeader(
    this.cols, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(10, 12, 10, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          for (final c in cols)
            _cell(
              c,
              Text(
                c.label,
                style: style,
                textAlign: c.right ? TextAlign.right : TextAlign.left,
              ),
            ),
        ],
      ),
    );
  }
}

/// Строка таблицы: ячейки [cells] — по столбцам [cols].
class RowTableRow extends StatelessWidget {
  final List<RowCol> cols;
  final List<Widget> cells;
  final VoidCallback? onTap;

  /// Отступ слева (часть набора внутри набора).
  final double indent;

  /// Фон строки (заголовок группы).
  final Color? color;
  final EdgeInsetsGeometry padding;

  const RowTableRow({
    super.key,
    required this.cols,
    required this.cells,
    this.onTap,
    this.indent = 0,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  }) : assert(cols.length == cells.length);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (indent > 0) SizedBox(width: indent),
          for (var i = 0; i < cols.length; i++) _cell(cols[i], cells[i]),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Текст ячейки: до трёх строк; [muted] — серым и зачёркнутым.
class CellText extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  final Color? color;
  final bool right;
  final int maxLines;
  const CellText(
    this.text, {
    super.key,
    this.bold = false,
    this.muted = false,
    this.color,
    this.right = false,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: bold ? FontWeight.w600 : null,
        color: muted ? theme.colorScheme.onSurfaceVariant : color,
        decoration: muted ? TextDecoration.lineThrough : null,
      ),
    );
  }
}
