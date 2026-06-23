import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/brand/i_brand_cache_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/auth_local_repository.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/theme/app_theme.dart';

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
    Future.microtask(() async {
      await _downloadBrandImage();
    });
    
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(widget.delay);
    if (!mounted) return;

    // Try local DB cache first
    final authLocal = Modular.get<AuthLocalRepository>();
    final localAuth = await authLocal.getAuth();

    if (localAuth != null && localAuth.accessToken.isNotEmpty) {
      if (!mounted) return;
      final restored = await _checkActiveTravel();
      if (!mounted) return;
      if (!restored) Modular.to.navigate('/home');
      return;
    }

    // Fallback to secure storage
    final storage = AuthStorage();
    final token = await storage.getToken();

    if (!mounted) return;
    if (token != null) {
      final restored = await _checkActiveTravel();
      if (!mounted) return;
      if (!restored) Modular.to.navigate('/home');
    } else {
      Modular.to.navigate('/login');
    }
  }

  /// Initiates brand image download (non-blocking).
  Future<void> _downloadBrandImage() async {
    await Modular.get<IBrandCacheService>().getBrandImagePath();
  }

  /// Checks if there's an active travel in local storage and navigates to it.
  /// Returns true if restored, false if no active travel found.
  Future<bool> _checkActiveTravel() async {
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
          'assets/images/logo.jpeg',
          width: 257,
          height: 103,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 257, height: 103, child: Placeholder()),
        ),
      ),
    );
  }
}
