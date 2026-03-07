import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  int _failureCount = 0;
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAndAuthenticate();
  }

  Future<void> _checkAndAuthenticate() async {
    // Check if device supports biometrics
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      canCheckBiometrics = false;
    }

    if (!canCheckBiometrics) {
      // No biometric support — go straight to login
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    // Check if there are enrolled biometrics
    final availableBiometrics = await _auth.getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() { _isAuthenticating = true; _error = null; });

    try {
      final l10n = AppLocalizations.of(context);
      final authenticated = await _auth.authenticate(
        localizedReason: l10n.biometricPrompt,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // Check if we have a valid token stored
        final client = ref.read(apiClientProvider);
        final token = await client.getToken();
        if (token != null && mounted) {
          context.go(AppRoutes.home);
        } else if (mounted) {
          // Token expired or missing — need full login
          context.go(AppRoutes.login);
        }
      } else {
        _failureCount++;
        if (_failureCount >= 3 && mounted) {
          context.go(AppRoutes.login);
          return;
        }
        setState(() => _error = AppLocalizations.of(context).loginError);
      }
    } on PlatformException catch (e) {
      _failureCount++;
      if (_failureCount >= 3 && mounted) {
        context.go(AppRoutes.login);
        return;
      }
      setState(() => _error = e.message ?? AppLocalizations.of(context).errorOccurred);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  l10n.appName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.biometricPrompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  icon: _isAuthenticating
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fingerprint),
                  label: Text(l10n.biometricPrompt),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(l10n.loginButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
