import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_state.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/gradient_text.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _codeError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _codeError = null;
      _passwordError = null;
      _confirmError = null;

      if (_codeController.text.trim().isEmpty) {
        _codeError = 'Código obrigatório';
        valid = false;
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Senha obrigatória';
        valid = false;
      }
      if (_confirmController.text != _passwordController.text) {
        _confirmError = 'As senhas não coincidem';
        valid = false;
      }
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<PasswordResetBloc>().add(
      ResetConfirmSubmitted(
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordResetBloc, PasswordResetState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (state is PasswordResetSuccess) {
          return _buildSuccess();
        }
        return _buildForm(state);
      },
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
              const SizedBox(height: 24),
              Text(
                'Senha redefinida com sucesso! Faça login novamente.',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Fazer login',
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(PasswordResetState state) {
    final isLoading = state is PasswordResetSubmitting;
    final error = state is PasswordResetError ? state : null;

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
                'Informe o código de verificação abaixo e redefina sua senha',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: 'Código de verificação',
                hint: 'Informe o código de verificação',
                controller: _codeController,
                keyboardType: TextInputType.number,
                errorText: _codeError,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Senha',
                hint: 'Defina sua senha',
                controller: _passwordController,
                obscureText: true,
                errorText: _passwordError,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmar Senha',
                hint: 'Digite novamente a senha',
                controller: _confirmController,
                obscureText: true,
                errorText: _confirmError,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error.message,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                if (error.codeConsumed) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/recovery'),
                      child: Text(
                        'Solicitar novo código',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              AppButton(
                label: 'Confirmar',
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
