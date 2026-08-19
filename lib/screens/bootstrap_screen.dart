import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authStorage = Modular.get<AuthStorage>();
    final authRepository = Modular.get<IAuthRepository>();
    final signOutService = Modular.get<SignOutService>();

    final refreshToken = await authStorage.getRefreshToken();

    if (refreshToken != null) {
      final result = await authRepository.refreshToken(refreshToken);

      result.fold(
        (success) async {
          // Refresh succeeded — save new tokens (rotation)
          await authStorage.saveToken(success.accessToken, success.userId);
          await authStorage.saveRefreshToken(success.refreshToken);

          Modular.to.navigate('/terms');
        },
        (_) {
          // Refresh failed (expired, revoked, or invalid) — clean session
          signOutService.signOut();
        },
      );
      return;
    }

    final token = await authStorage.getToken();
    if (token != null) {
      Modular.to.navigate('/terms');
    } else {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Estamos preparando o app.\nPor favor, aguarde',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
