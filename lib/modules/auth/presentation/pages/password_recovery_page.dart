import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_recovery_state.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/gradient_text.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _emailController = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    setState(() => _emailError = email.isEmpty ? 'E-mail obrigatório' : null);
    if (_emailError != null) return;

    context.read<PasswordRecoveryBloc>().add(RequestCodeSubmitted(email));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (state is PasswordRecoverySent) {
          return _buildSent(state.email);
        }
        return _buildForm(state);
      },
    );
  }

  Widget _buildSent(String email) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, color: AppColors.primary, size: 64),
              const SizedBox(height: 24),
              Text(
                'Se o e-mail estiver cadastrado, você receberá um código de verificação em instantes.',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Já tenho o código',
                onPressed: () => Modular.to.pushNamed('/reset-password', arguments: {'email': email}),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                child: Text('Voltar ao login', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(PasswordRecoveryState state) {
    final isLoading = state is PasswordRecoveryLoading;
    final errorMessage = state is PasswordRecoveryError ? state.message : null;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                'Recupere sua senha',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 72),
              Text(
                'Informe o e-mail da sua conta. Enviaremos um código de verificação para que você redefina sua senha.',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: 'E-mail',
                hint: 'Informe seu e-mail',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              AppButton(
                label: 'Enviar',
                loading: isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
