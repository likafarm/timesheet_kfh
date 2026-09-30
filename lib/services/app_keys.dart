// lib/services/app_keys.dart
//
// Ключи главного окна: окна и сообщения из служб, у которых нет своего
// BuildContext (выдача файла на телефоне, напоминание).

import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
