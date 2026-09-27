import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// База в памяти (тесты на Dart VM).
QueryExecutor memoryExecutor() => NativeDatabase.memory();
