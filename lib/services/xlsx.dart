// lib/services/xlsx.dart
//
// Минимальная запись файлов Excel (.xlsx) на чистом Dart (этап 6.4): работает
// в Windows, в браузере и на телефоне. Числа пишутся числами (не текстом),
// вид задаёт числовой формат ячейки; итоги — формулами с готовым значением.
// Готовые пакеты не подошли: `excel` понижал archive/pdf/printing/xml.
//
// Файл xlsx — zip из нескольких XML (стандарт ECMA-376). Строки — внутри
// ячеек (inlineStr), без таблицы общих строк; стили собираются из
// используемых [XlsxStyle] без повторов.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Оформление ячейки. Равные по значению стили — один стиль в файле.
class XlsxStyle {
  final bool bold;
  final double fontSize;

  /// Цвет текста / заливки — ARGB (0xFFRRGGBB), null — по умолчанию.
  final int? color;
  final int? fill;

  /// Числовой формат Excel (например `#,##0.00`), null — «Общий».
  final String? numFmt;
  final bool border;

  /// 'left' | 'center' | 'right', null — по умолчанию (текст слева, числа
  /// справа).
  final String? align;
  final bool wrap;

  const XlsxStyle({
    this.bold = false,
    this.fontSize = 10,
    this.color,
    this.fill,
    this.numFmt,
    this.border = false,
    this.align,
    this.wrap = false,
  });

  XlsxStyle copyWith({
    bool? bold,
    double? fontSize,
    int? color,
    int? fill,
    String? numFmt,
    bool? border,
    String? align,
    bool? wrap,
  }) => XlsxStyle(
    bold: bold ?? this.bold,
    fontSize: fontSize ?? this.fontSize,
    color: color ?? this.color,
    fill: fill ?? this.fill,
    numFmt: numFmt ?? this.numFmt,
    border: border ?? this.border,
    align: align ?? this.align,
    wrap: wrap ?? this.wrap,
  );

  Object get _font => (bold, fontSize, color);

  @override
  bool operator ==(Object other) =>
      other is XlsxStyle &&
      other.bold == bold &&
      other.fontSize == fontSize &&
      other.color == color &&
      other.fill == fill &&
      other.numFmt == numFmt &&
      other.border == border &&
      other.align == align &&
      other.wrap == wrap;

  @override
  int get hashCode =>
      Object.hash(bold, fontSize, color, fill, numFmt, border, align, wrap);
}

/// Значение ячейки: текст, число или формула с готовым значением.
sealed class XlsxValue {
  const XlsxValue();
}

class XlsxText extends XlsxValue {
  final String text;
  const XlsxText(this.text);
}

class XlsxNumber extends XlsxValue {
  final num value;
  const XlsxNumber(this.value);
}

/// Формула без «=» (например `SUM(D5:D9)`); [cached] — значение, которое
/// видно сразу, до пересчёта (и программам, которые формулы не считают).
class XlsxFormula extends XlsxValue {
  final String formula;
  final num cached;
  const XlsxFormula(this.formula, this.cached);
}

class XlsxCell {
  final XlsxValue? value;
  final XlsxStyle style;

  const XlsxCell(this.value, [this.style = const XlsxStyle()]);

  const XlsxCell.empty([this.style = const XlsxStyle()]) : value = null;

  XlsxCell.text(String text, [this.style = const XlsxStyle()])
    : value = XlsxText(text);

  XlsxCell.number(num value, [this.style = const XlsxStyle()])
    : value = XlsxNumber(value);
}

/// Лист: строки ячеек сверху вниз (номер строки = индекс + 1).
class XlsxSheet {
  final String name;
  final List<List<XlsxCell>> rows = [];

  /// Ширина столбцов в символах (индекс — номер столбца с 0).
  final Map<int, double> columnWidths = {};

  /// Высота строк в пунктах (индекс строки с 0).
  final Map<int, double> rowHeights = {};

  /// Объединённые области, например `A1:F1`.
  final List<String> merges = [];

  /// Закреплено строк сверху и столбцов слева.
  int frozenRows = 0;
  int frozenColumns = 0;

  /// Альбомная ориентация при печати.
  bool landscape = false;

  XlsxSheet(String name) : name = _sheetName(name);

  /// Добавляет строку, возвращает её номер в Excel (с 1).
  int addRow(List<XlsxCell> cells, {double? height}) {
    rows.add(cells);
    if (height != null) rowHeights[rows.length - 1] = height;
    return rows.length;
  }

  static String _sheetName(String name) {
    final clean = name.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    if (clean.isEmpty) return 'Лист';
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }
}

/// Буквенное имя столбца: 0 → A, 25 → Z, 26 → AA.
String xlsxColumn(int index) {
  var n = index + 1;
  final chars = <int>[];
  while (n > 0) {
    final r = (n - 1) % 26;
    chars.insert(0, 65 + r);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(chars);
}

/// Адрес ячейки: (0, 0) → A1.
String xlsxRef(int column, int row) => '${xlsxColumn(column)}${row + 1}';

class XlsxWorkbook {
  final List<XlsxSheet> sheets = [];
  final String? title;
  final String? author;

  XlsxWorkbook({this.title, this.author});

  XlsxSheet addSheet(String name) {
    final sheet = XlsxSheet(name);
    sheets.add(sheet);
    return sheet;
  }

  /// Содержимое файла .xlsx.
  Uint8List encode() {
    if (sheets.isEmpty) throw StateError('В книге нет листов');
    final styles = _Styles();
    final sheetXml = [for (final s in sheets) _sheetXml(s, styles)];
    final archive = Archive();
    void add(String path, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', _rootRels);
    add('docProps/core.xml', _core());
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels());
    add('xl/styles.xml', styles.xml());
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', sheetXml[i]);
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static const _header =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  String _contentTypes() =>
      '$_header'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '${[for (var i = 1; i <= sheets.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>';

  static const _rootRels =
      '$_header'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';

  String _core() {
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    return '$_header'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '${title == null ? '' : '<dc:title>${_esc(title!)}</dc:title>'}'
        '${author == null ? '' : '<dc:creator>${_esc(author!)}</dc:creator>'}'
        '<dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created>'
        '</cp:coreProperties>';
  }

  String _workbook() =>
      '$_header'
      '<workbook xmlns="$_ns" xmlns:r="$_rNs"><sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>';

  String _workbookRels() =>
      '$_header'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  String _sheetXml(XlsxSheet sheet, _Styles styles) {
    final b = StringBuffer('$_header<worksheet xmlns="$_ns" xmlns:r="$_rNs">');
    b.write('<sheetViews><sheetView workbookViewId="0">');
    if (sheet.frozenRows > 0 || sheet.frozenColumns > 0) {
      final x = sheet.frozenColumns, y = sheet.frozenRows;
      final pane = x > 0 && y > 0
          ? 'bottomRight'
          : y > 0
          ? 'bottomLeft'
          : 'topRight';
      b.write(
        '<pane${x > 0 ? ' xSplit="$x"' : ''}${y > 0 ? ' ySplit="$y"' : ''} '
        'topLeftCell="${xlsxRef(x, y)}" activePane="$pane" state="frozen"/>',
      );
    }
    b.write('</sheetView></sheetViews>');
    b.write('<sheetFormatPr defaultRowHeight="15"/>');
    if (sheet.columnWidths.isNotEmpty) {
      b.write('<cols>');
      for (final e
          in (sheet.columnWidths.entries.toList()
            ..sort((a, c) => a.key.compareTo(c.key)))) {
        b.write(
          '<col min="${e.key + 1}" max="${e.key + 1}" width="${e.value}" '
          'customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < sheet.rows.length; r++) {
      final height = sheet.rowHeights[r];
      b.write(
        '<row r="${r + 1}"'
        '${height == null ? '' : ' ht="$height" customHeight="1"'}>',
      );
      final cells = sheet.rows[r];
      for (var c = 0; c < cells.length; c++) {
        final cell = cells[c];
        final s = styles.index(cell.style);
        final ref = xlsxRef(c, r);
        final style = s == 0 ? '' : ' s="$s"';
        switch (cell.value) {
          case null:
            if (s != 0) b.write('<c r="$ref"$style/>');
          case XlsxText(:final text):
            b.write(
              '<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">'
              '${_esc(text)}</t></is></c>',
            );
          case XlsxNumber(:final value):
            b.write('<c r="$ref"$style><v>${_num(value)}</v></c>');
          case XlsxFormula(:final formula, :final cached):
            b.write(
              '<c r="$ref"$style><f>${_esc(formula)}</f>'
              '<v>${_num(cached)}</v></c>',
            );
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (sheet.merges.isNotEmpty) {
      b.write('<mergeCells count="${sheet.merges.length}">');
      for (final m in sheet.merges) {
        b.write('<mergeCell ref="$m"/>');
      }
      b.write('</mergeCells>');
    }
    b.write(
      '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" '
      'header="0.3" footer="0.3"/>',
    );
    if (sheet.landscape) b.write('<pageSetup orientation="landscape"/>');
    b.write('</worksheet>');
    return b.toString();
  }

  static String _num(num v) {
    if (v is int) return '$v';
    final d = v.toDouble();
    if (d.isNaN || d.isInfinite) return '0';
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    return d.toString();
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // Управляющие символы в XML 1.0 недопустимы.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _argb(int c) => c.toRadixString(16).toUpperCase().padLeft(8, '0');

/// Таблица стилей: шрифты, заливки, рамки, числовые форматы, стили ячеек.
class _Styles {
  final _xfs = <XlsxStyle>[const XlsxStyle()];
  final _fonts = <Object>[const XlsxStyle()._font];
  final _fills = <int?>[null, null]; // 0 — none, 1 — gray125 (обязательные)
  final _numFmts = <String>[];

  int index(XlsxStyle style) {
    final i = _xfs.indexOf(style);
    if (i >= 0) return i;
    _xfs.add(style);
    if (!_fonts.contains(style._font)) _fonts.add(style._font);
    if (style.fill != null && !_fills.contains(style.fill)) {
      _fills.add(style.fill);
    }
    final fmt = style.numFmt;
    if (fmt != null && !_numFmts.contains(fmt)) _numFmts.add(fmt);
    return _xfs.length - 1;
  }

  String xml() {
    final b = StringBuffer(XlsxWorkbook._header);
    b.write('<styleSheet xmlns="${XlsxWorkbook._ns}">');
    if (_numFmts.isNotEmpty) {
      b.write('<numFmts count="${_numFmts.length}">');
      for (var i = 0; i < _numFmts.length; i++) {
        b.write(
          '<numFmt numFmtId="${164 + i}" formatCode="${_esc(_numFmts[i])}"/>',
        );
      }
      b.write('</numFmts>');
    }
    b.write('<fonts count="${_fonts.length}">');
    for (final f in _fonts) {
      final (bool bold, double size, int? color) = f as (bool, double, int?);
      b.write('<font>${bold ? '<b/>' : ''}<sz val="$size"/>');
      if (color != null) b.write('<color rgb="${_argb(color)}"/>');
      b.write(
        '<name val="Arial"/><family val="2"/><charset val="204"/></font>',
      );
    }
    b.write('</fonts>');
    b.write('<fills count="${_fills.length}">');
    b.write('<fill><patternFill patternType="none"/></fill>');
    b.write('<fill><patternFill patternType="gray125"/></fill>');
    for (final c in _fills.skip(2)) {
      b.write(
        '<fill><patternFill patternType="solid"><fgColor rgb="${_argb(c!)}"/>'
        '<bgColor indexed="64"/></patternFill></fill>',
      );
    }
    b.write('</fills>');
    b.write(
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FFBDBDBD"/></left>'
      '<right style="thin"><color rgb="FFBDBDBD"/></right>'
      '<top style="thin"><color rgb="FFBDBDBD"/></top>'
      '<bottom style="thin"><color rgb="FFBDBDBD"/></bottom><diagonal/></border></borders>',
    );
    b.write(
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    );
    b.write('<cellXfs count="${_xfs.length}">');
    for (final s in _xfs) {
      final numFmt = s.numFmt == null ? 0 : 164 + _numFmts.indexOf(s.numFmt!);
      final font = _fonts.indexOf(s._font);
      final fill = s.fill == null ? 0 : _fills.indexOf(s.fill);
      final border = s.border ? 1 : 0;
      b.write(
        '<xf numFmtId="$numFmt" fontId="$font" fillId="$fill" borderId="$border" xfId="0"'
        '${numFmt != 0 ? ' applyNumberFormat="1"' : ''}'
        '${font != 0 ? ' applyFont="1"' : ''}'
        '${fill != 0 ? ' applyFill="1"' : ''}'
        '${border != 0 ? ' applyBorder="1"' : ''}',
      );
      if (s.align != null || s.wrap) {
        b.write(
          ' applyAlignment="1"><alignment'
          '${s.align == null ? '' : ' horizontal="${s.align}"'}'
          ' vertical="center"${s.wrap ? ' wrapText="1"' : ''}/></xf>',
        );
      } else {
        b.write('/>');
      }
    }
    b.write('</cellXfs>');
    b.write(
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>',
    );
    b.write('</styleSheet>');
    return b.toString();
  }
}
