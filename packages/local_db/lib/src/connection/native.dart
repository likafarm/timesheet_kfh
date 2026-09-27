import 'dart:io';

import 'package:drift/native.dart';

import '../database.dart';

/// База в файле (Windows, Android); запросы — в фоновом изоляте.
LocalDatabase openLocalDatabaseFile(
  File file, {
  DateTime Function()? clock,
}) => LocalDatabase(NativeDatabase.createInBackground(file), clock: clock);
