import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

class SplashScreen extends StatefulWidget {
  final Duration delay;

  const SplashScreen({super.key, this.delay = const Duration(seconds: 2)});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(widget.delay);

    final authStorage = Modular.get<AuthStorage>();
    final authRepository = Modular.get<IAuthRepository>();
    final signOutService = Modular.get<SignOutService>();

    // Check for refresh token (source of truth for session persistence)
    final refreshToken = await authStorage.getRefreshToken();

    if (refreshToken != null) {
      // Try to refresh the access token proactively
      final result = await authRepository.refreshToken(refreshToken);

      result.fold(
        (success) async {
          // Refresh succeeded — save new tokens (rotation)
          await authStorage.saveToken(success.accessToken, success.userId);
          await authStorage.saveRefreshToken(success.refreshToken);

          // RF02: Tentar recuperar OneSignal.login se falhou antes
          NotificationService.tryLateLogin(success.userId);

          // Navigate to terms guard — it will determine final destination
          Modular.to.navigate('/terms');
        },
        (_) {
          // Refresh failed (expired, revoked, or invalid) — clean session
          signOutService.signOut();
        },
      );
      return;
    }

    // No refresh token — try legacy access token (backward compatibility
    // for users upgrading from an older version without refresh tokens)
    final token = await authStorage.getToken();
    if (token != null) {
      Modular.to.navigate('/terms');
    } else {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Image.asset(
          'assets/images/moto_driver_logo.png',
          width: 257,
          height: 103,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 257, height: 103, child: Placeholder()),
        ),
      ),
    );
  }
}
