import 'package:drift/drift.dart';

/// В браузере база в памяти не нужна: тесты идут на Dart VM.
QueryExecutor memoryExecutor() =>
    throw UnsupportedError('LocalDatabase.memory() — только на Dart VM');
