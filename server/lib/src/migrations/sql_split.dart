/// Делит текст SQL-файла на отдельные команды по `;`: драйвер выполняет
/// по одной команде за вызов.
///
/// Учитывает строки в `'…'`, `"…"` и `` `…` `` (с экранированием `\` и
/// удвоением кавычки), комментарии `-- …`, `# …` и `/* … */`. Комментарии
/// из результата убираются. `DELIMITER` и тела процедур/триггеров не
/// поддерживаются — в миграциях их нет.
List<String> splitSqlStatements(String sql) {
  final statements = <String>[];
  final current = StringBuffer();
  var i = 0;

  void flush() {
    final statement = current.toString().trim();
    if (statement.isNotEmpty) statements.add(statement);
    current.clear();
  }

  while (i < sql.length) {
    final c = sql[i];
    final next = i + 1 < sql.length ? sql[i + 1] : '';

    // Комментарий до конца строки: `-- ` (MySQL требует пробел после
    // двух минусов) или `#`.
    if ((c == '-' && next == '-' && _isSpaceOrEnd(sql, i + 2)) || c == '#') {
      while (i < sql.length && sql[i] != '\n') {
        i++;
      }
      continue;
    }

    if (c == '/' && next == '*') {
      final end = sql.indexOf('*/', i + 2);
      if (end < 0) throw FormatException('Незакрытый комментарий /*', sql, i);
      i = end + 2;
      current.write(' ');
      continue;
    }

    if (c == "'" || c == '"' || c == '`') {
      final start = i;
      current.write(c);
      i++;
      while (true) {
        if (i >= sql.length) {
          throw FormatException('Незакрытая кавычка $c', sql, start);
        }
        final ch = sql[i];
        if (ch == r'\' && c != '`' && i + 1 < sql.length) {
          current
            ..write(ch)
            ..write(sql[i + 1]);
          i += 2;
          continue;
        }
        current.write(ch);
        i++;
        if (ch == c) {
          // Удвоенная кавычка внутри строки — это сама кавычка.
          if (i < sql.length && sql[i] == c) {
            current.write(c);
            i++;
            continue;
          }
          break;
        }
      }
      continue;
    }

    if (c == ';') {
      flush();
      i++;
      continue;
    }

    current.write(c);
    i++;
  }
  flush();
  return statements;
}

bool _isSpaceOrEnd(String s, int i) =>
    i >= s.length || s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r';
