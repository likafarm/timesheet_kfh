import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/help/help_content.dart';
import 'package:kfx_time_tracking/help/help_pdf.dart';
import 'package:path/path.dart' as p;

/// Инструкции в PDF (шаг 4.3). Файлы для /download:
///   KFH_HELP_PDF=installer_output flutter test test/help/help_pdf_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['KFH_HELP_PDF'];

  for (final role in HelpRole.values) {
    test('PDF: ${role.title}', () async {
      final bytes = await buildHelpPdf(
        role,
        asset: rootBundle.load,
        version: '1.15.0',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // С картинками файл заметно больше голого текста.
      expect(bytes.length, greaterThan(100 * 1024));
      if (out != null) {
        await File(p.join(out, helpPdfName(role))).writeAsBytes(bytes);
      }
    });
  }
}
