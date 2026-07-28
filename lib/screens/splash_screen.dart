import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
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
          await NotificationService.login(success.userId);

          // Check for active travel and navigate
          final restored = await _checkActiveTravel();
          if (!restored) Modular.to.navigate('/home');
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
      final userId = await authStorage.getUserId();
      if (userId != null) {
        await NotificationService.login(userId);
      }
      final restored = await _checkActiveTravel();
      if (!restored) Modular.to.navigate('/home');
    } else {
      Modular.to.navigate('/login');
    }
  }

  /// Checks if there's an active travel and navigates to it.
  /// Tries GET /api/travels/active first (travel-v2+), falls back to local cache.
  /// Returns true if restored, false if no active travel found.
  Future<bool> _checkActiveTravel() async {
    // Tenta REST primeiro (travel-v2+)
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('${AppConfig.getBaseUrl()}/api/travels/active');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['travelId'] != null) {
          final status = data['status'] as String?;
          if (status == 'Accepted' || status == 'InProgress') {
            Modular.to.pushNamed('/active-travel', arguments: {
              'travelId': data['travelId'] as String,
            });
            return true;
          }
        }
      }
      // Sem viagem ativa via REST — limpa cache local
      await Modular.get<TravelLocalRepository>().clearTravels();
      return false;
    } catch (_) {
      // Fallback: cache local
    }

    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();

    if (active == null || active.status == 'Completed' || active.status == 'Cancelled') {
      return false;
    }

    // Verify travel still exists on backend
    try {
      final dio = Modular.get<Dio>();
      await dio.get('${AppConfig.getBaseUrl()}/api/travels/${active.travelId}');
      if (active.status == 'Accepted' || active.status == 'InProgress') {
        Modular.to.pushNamed('/active-travel', arguments: {'travelId': active.travelId});
        return true;
      }
    } catch (_) {
      // Travel no longer exists
      await travelRepo.clearTravels();
    }
    return false;
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
