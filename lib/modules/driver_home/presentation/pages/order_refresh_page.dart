import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/auth/domain/repositories/i_auth_repository.dart';

/// Página de passagem do fluxo de push: renova o token exibindo apenas um
/// estado de loading e, após sucesso, navega para a página de pedidos
/// (`/order-alert`) substituindo a si mesma (nunca permanece na pilha).
///
/// Falha de refresh / ausência de refresh token → `signOut()` (limpa a sessão
/// e navega para `/login`).
class OrderRefreshPage extends StatefulWidget {
  final String? orderId;

  const OrderRefreshPage({super.key, this.orderId});

  @override
  State<OrderRefreshPage> createState() => _OrderRefreshPageState();
}

class _OrderRefreshPageState extends State<OrderRefreshPage> {
  @override
  void initState() {
    super.initState();
    _refreshAndOpen();
  }

  Future<void> _refreshAndOpen() async {
    final authStorage = Modular.get<AuthStorage>();
    final authRepository = Modular.get<IAuthRepository>();
    final signOutService = Modular.get<SignOutService>();

    final refreshToken = await authStorage.getRefreshToken();
    if (refreshToken == null) {
      await signOutService.signOut();
      return;
    }

    final result = await authRepository.refreshToken(refreshToken);
    result.fold(
      (success) async {
        await authStorage.saveToken(success.accessToken, success.userId);
        await authStorage.saveRefreshToken(success.refreshToken);
        if (!mounted) return;
        Modular.to.pushReplacementNamed('/order-alert',
            arguments: {'orderId': widget.orderId});
      },
      (_) async {
        await signOutService.signOut();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
