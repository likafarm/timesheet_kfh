// lib/services/xlsx_reader.dart
//
// Чтение таблицы из файла Excel (.xlsx) для загрузки выписки банка (8Б.6):
// ячейки первого (или указанного) листа текстом. Чистый Dart поверх
// `archive`, без разбора стилей: числа — как записаны (даты — числом дня
// Excel), строки — общие (sharedStrings), в ячейке и формульные.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kfh_domain/kfh_domain.dart';

class XlsxReadException implements Exception {
  final String message;
  const XlsxReadException(this.message);
  @override
  String toString() => message;
}

/// Число листов книги.
int xlsxSheetCount(Uint8List bytes) {
  try {
    final wb = ZipDecoder().decodeBytes(bytes).findFile('xl/workbook.xml');
    if (wb == null) return 0;
    return RegExp(
      r'<sheet\s',
    ).allMatches(utf8.decode(wb.content as List<int>)).length;
  } catch (_) {
    throw const XlsxReadException('Файл — не таблица Excel (.xlsx)');
  }
}

/// Ячейки листа по строкам (пустые — null). [sheet] — номер листа с 0.
List<List<String?>> readXlsx(Uint8List bytes, {int sheet = 0}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const XlsxReadException('Файл — не таблица Excel (.xlsx)');
  }
  String? text(String name) {
    final f = archive.findFile(name);
    return f == null ? null : utf8.decode(f.content as List<int>);
  }

  final shared = <String>[];
  final sst = text('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(sst)) {
      shared.add(_runs(si[1]!));
    }
  }
  // Лист по порядку из workbook.xml → путь из связей.
  final workbook = text('xl/workbook.xml') ?? '';
  final rels = text('xl/_rels/workbook.xml.rels') ?? '';
  final ids = [
    for (final m in RegExp(
      r'<sheet\b[^>]*?r:id="([^"]+)"',
    ).allMatches(workbook))
      m[1]!,
  ];
  String? path;
  if (sheet < ids.length) {
    final target = RegExp(
      'Id="${RegExp.escape(ids[sheet])}"[^>]*?Target="([^"]+)"|'
      'Target="([^"]+)"[^>]*?Id="${RegExp.escape(ids[sheet])}"',
    ).firstMatch(rels);
    final t = target?[1] ?? target?[2];
    if (t != null) path = t.startsWith('/') ? t.substring(1) : 'xl/$t';
  }
  final xml = text(path ?? 'xl/worksheets/sheet${sheet + 1}.xml');
  if (xml == null) throw const XlsxReadException('В файле нет листа');

  final rows = <List<String?>>[];
  for (final row in RegExp(
    r'<row\b([^>]*)>(.*?)</row>',
    dotAll: true,
  ).allMatches(xml)) {
    final number = int.tryParse(
      RegExp(r'\br="(\d+)"').firstMatch(row[1]!)?[1] ?? '',
    );
    final index = (number ?? rows.length + 1) - 1;
    while (rows.length < index) {
      rows.add(const []);
    }
    final cells = <String?>[];
    for (final c in RegExp(
      r'<c\b([^>]*?)(?:/>|>(.*?)</c>)',
      dotAll: true,
    ).allMatches(row[2]!)) {
      final attrs = c[1]!;
      final ref = RegExp(r'\br="([A-Z]+)\d+"').firstMatch(attrs)?[1];
      final col = ref == null ? cells.length : _column(ref);
      while (cells.length < col) {
        cells.add(null);
      }
      final type = RegExp(r'\bt="(\w+)"').firstMatch(attrs)?[1];
      final body = c[2] ?? '';
      final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(body)?[1];
      final String? value = switch (type) {
        's' => v == null ? null : shared.elementAtOrNull(int.parse(v)),
        'inlineStr' => _runs(body),
        _ => v == null ? null : _unescape(v),
      };
      cells.add(value);
    }
    rows.add(cells);
  }
  return rows;
}

/// Текст элемента `<si>`/`<is>`: все `<t>` подряд.
String _runs(String xml) => [
  for (final t in RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(xml))
    _unescape(t[1]!),
].join();

int _column(String letters) {
  var n = 0;
  for (final ch in letters.codeUnits) {
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}

String _unescape(String s) => s
    .replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
    )
    .replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m[1]!)),
    )
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Выписка банка из файла Excel: первый лист, где нашлась выписка
/// СберБизнеса (в выгрузке бывают и сводные листы).
BankStatement readBankStatement(Uint8List bytes) {
  final sheets = xlsxSheetCount(bytes);
  BankStatementException? last;
  for (var i = 0; i < (sheets == 0 ? 1 : sheets); i++) {
    try {
      return parseSberStatement(readXlsx(bytes, sheet: i));
    } on BankStatementException catch (e) {
      last = e;
    }
  }
  throw last ??
      const BankStatementException('В файле не нашлось выписки СберБизнеса');
}
