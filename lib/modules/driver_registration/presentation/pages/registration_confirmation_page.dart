import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/widgets/app_button.dart';

class ConfirmationPage extends StatelessWidget {
  const ConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 24,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: context.moto.accent,
                ),
                Text(
                  'Cadastro enviado com sucesso!\nAguardando aprovação do administrador.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.moto.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Voltar para o login',
                  onPressed: () {
                    Modular.to.navigate('/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
