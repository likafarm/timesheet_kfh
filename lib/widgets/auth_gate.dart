// lib/widgets/auth_gate.dart
//
// Без входа программа не запускается (решение владельца 2026-09-27, все
// платформы): первым открывается вход, затем — смена выданного пароля и
// первый вход базы на сервер; только после этого — сама программа. Вход,
// сохранённый ранее, действует и без сети (программа работает офлайн); если
// сервер его отверг (сеанс истёк, пароль сброшен) — снова вход.

import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../services/platform.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'sync_dialogs.dart';

/// Закрыть программу (отказ от входа).
Future<void> quitApp() async {
  if (isAndroidApp) {
    await SystemNavigator.pop();
  } else {
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  }
}

class AuthGate extends StatelessWidget {
  /// Программа — после входа.
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<SyncProvider, SyncPhase>((s) => s.phase);
    return switch (phase) {
      SyncPhase.ready => child,
      SyncPhase.starting => const _Splash(),
      _ => const _SignInScreen(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

/// Экран до входа: сразу открывает окно входа; если человек отказался или
/// вход не довели до конца — «Войти» или «Выйти из программы».
class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  bool _flowRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFlow());
  }

  Future<void> _runFlow() async {
    if (_flowRunning || !mounted) return;
    setState(() => _flowRunning = true);
    try {
      final sync = context.read<SyncProvider>();
      if (sync.phase == SyncPhase.signedOut) {
        await startSignIn(context);
      } else {
        await continueSyncSetup(context);
      }
    } finally {
      if (mounted) setState(() => _flowRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final theme = Theme.of(context);
    final (title, text) = switch (sync.phase) {
      SyncPhase.passwordChange => (
        'Нужно сменить пароль',
        'Пароль выдан администратором — задайте свой, чтобы продолжить.',
      ),
      SyncPhase.needsLink => (
        'Первый вход на сервер',
        'Осталось связать данные $ofThisDevice с сервером.',
      ),
      _ => (
        'Вход в программу',
        'Программа работает только после входа учётной записью, выданной '
            'администратором.',
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.edit_calendar,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(text, textAlign: TextAlign.center),
                  if (sync.problem != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      sync.problem!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _flowRunning ? null : _runFlow,
                    child: Text(
                      sync.phase == SyncPhase.signedOut ? 'Войти' : 'Продолжить',
                    ),
                  ),
                  // Страницу браузера программа не закрывает.
                  if (!isWebApp) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _flowRunning ? null : quitApp,
                      child: const Text('Выйти из программы'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
