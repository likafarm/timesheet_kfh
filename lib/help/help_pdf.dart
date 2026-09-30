// lib/help/help_pdf.dart
//
// Инструкция в PDF (шаг 4.3 «Дальнейших работ») — из того же текста, что
// справка в программе: печать из справки и файлы для страницы /download.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'help_content.dart';

/// Имя файла инструкции для роли (латиницей — для адреса на /download).
String helpPdfName(HelpRole role) => switch (role) {
  HelpRole.operator => 'instrukciya-operator.pdf',
  HelpRole.accountant => 'instrukciya-buhgalter.pdf',
  HelpRole.admin => 'instrukciya-administrator.pdf',
};

/// PDF инструкции для [role]. [asset] — чтение файла программы (шрифты
/// `assets/fonts`, картинки `assets/help`); картинки, которых нет,
/// пропускаются.
Future<Uint8List> buildHelpPdf(
  HelpRole role, {
  required Future<ByteData> Function(String path) asset,
  required String version,
}) async {
  final regular = pw.Font.ttf(await asset('assets/fonts/Roboto-Regular.ttf'));
  final bold = pw.Font.ttf(await asset('assets/fonts/Roboto-Bold.ttf'));
  final images = <String, pw.MemoryImage>{};
  for (final c in helpFor(role)) {
    for (final b in c.blocksFor(role)) {
      if (b is! HelpImage || images.containsKey(b.name)) continue;
      try {
        images[b.name] = pw.MemoryImage(
          (await asset(b.asset)).buffer.asUint8List(),
        );
      } catch (_) {
        // Снимка нет — без картинки.
      }
    }
  }

  const green = PdfColor.fromInt(0xFF2E7D32);
  const muted = PdfColor.fromInt(0xFF5F6368);
  final body = pw.TextStyle(font: regular, fontSize: 11, lineSpacing: 2);
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final chapters = helpFor(role);
  final doc = pw.Document(
    title: 'Инструкция для ${role.genitive}',
    author: 'КФХ: учёт времени и зарплаты',
    theme: theme,
  );

  // В Roboto программы нет стрелки «→» — в PDF её заменяет «›».
  String t(String text) => text.replaceAll('→', '›');

  pw.Widget block(HelpBlock b) => switch (b) {
    HelpText(:final text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(t(text), style: body),
    ),
    HelpHeading(:final text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
      child: pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 12.5)),
    ),
    HelpList(:final items, :final numbered) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final (i, item) in items.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 18,
                    child: pw.Text(numbered ? '${i + 1}.' : '•', style: body),
                  ),
                  pw.Expanded(child: pw.Text(t(item), style: body)),
                ],
              ),
            ),
        ],
      ),
    ),
    HelpNote(:final text) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE8F0E3),
        border: pw.Border(left: pw.BorderSide(color: green, width: 3)),
      ),
      child: pw.Text(t(text), style: body),
    ),
    HelpImage(:final name, :final caption, :final phone) =>
      images[name] == null
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                children: [
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFCCCCCC),
                        width: 0.5,
                      ),
                    ),
                    child: pw.Image(images[name]!, width: phone ? 170 : 470),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    caption,
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 9,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
  };

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(56),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 120),
          pw.Text(
            'КФХ: учёт рабочего времени и зарплаты',
            style: pw.TextStyle(font: regular, fontSize: 14, color: muted),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Инструкция для ${role.genitive}',
            style: pw.TextStyle(font: bold, fontSize: 28, color: green),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Версия программы $version',
            style: pw.TextStyle(font: regular, fontSize: 11, color: muted),
          ),
          pw.SizedBox(height: 40),
          pw.Text('Содержание', style: pw.TextStyle(font: bold, fontSize: 14)),
          pw.SizedBox(height: 8),
          for (final (i, c) in chapters.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('${i + 1}. ${c.title}', style: body),
            ),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Инструкция для ${role.genitive}',
            style: pw.TextStyle(font: regular, fontSize: 8, color: muted),
          ),
          pw.Text(
            '${context.pageNumber}',
            style: pw.TextStyle(font: regular, fontSize: 8, color: muted),
          ),
        ],
      ),
      build: (_) => [
        for (final (i, c) in chapters.indexed) ...[
          pw.Header(
            level: 1,
            decoration: const pw.BoxDecoration(),
            padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
            child: pw.Text(
              '${i + 1}. ${c.title}',
              style: pw.TextStyle(font: bold, fontSize: 16, color: green),
            ),
          ),
          for (final b in c.blocksFor(role)) block(b),
        ],
      ],
    ),
  );
  return doc.save();
}
