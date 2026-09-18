import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/core/utils/server_error_guard.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;
import 'package:moto_driver/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/password_reset_state.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/gradient_text.dart';
import 'package:moto_driver/widgets/password_policy_checklist.dart';

/// Tela 2 do reset de senha: define a nova senha usando o `resetToken`
/// recebido da tela 1 (verificação de código). Exibe o checklist dinâmico
/// da política de senha (Trilha B) assim que o campo ganha foco.
class PasswordResetPage extends StatefulWidget {
  /// E-mail opcional (vindo da tela 1) usado apenas para oferecer "pedir
  /// novo código" já com o e-mail em mãos, se o resetToken expirar.
  final String? email;

  const PasswordResetPage({super.key, this.email});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  String? _confirmError;
  bool _passwordFocused = false;

  // Bloqueia o botão "Confirmar" depois de um erro do backend (token
  // inválido/expirado ou senha fora da política) até a senha ser editada —
  // evita spammar o botão reenviando os mesmos dados rejeitados.
  final _serverErrorGuard = ServerErrorGuard();
  String? _serverError;

  // Usa o fallback estático até a política real chegar do backend — a tela
  // nunca fica bloqueada esperando o GET (design D4).
  PasswordPolicy _policy = const PasswordPolicy.fallback();

  @override
  void initState() {
    super.initState();
    for (final controller in [_passwordController, _confirmController]) {
      controller.addListener(_onFieldsChanged);
    }
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final usecase = Modular.get<IGetPasswordPolicyUsecase>();
    final result = await usecase.call();
    if (!mounted) return;
    result.fold(
      (policy) => setState(() => _policy = policy),
      // Usecase é sempre-sucesso (fallback interno); nada a fazer aqui.
      (_) {},
    );
  }

  void _onFieldsChanged() {
    if (_serverErrorGuard.isBlocking) {
      _serverErrorGuard.clearIfEdited('password', _passwordController.text);
      if (!_serverErrorGuard.isBlocking) _serverError = null;
    }
    setState(() {});
  }

  bool get _isFormComplete =>
      validators.isPasswordValid(_passwordController.text, _policy) &&
      _confirmController.text == _passwordController.text &&
      !_serverErrorGuard.isBlocking;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _confirmError = null;

      if (!validators.isPasswordValid(_passwordController.text, _policy)) {
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
      ResetConfirmSubmitted(newPassword: _passwordController.text),
    );
  }

  void _requestNewCode() {
    if (widget.email != null) {
      Modular.to.pushReplacementNamed('/verify-reset-code', arguments: {'email': widget.email});
    } else {
      Navigator.of(context).pushReplacementNamed('/recovery');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordResetBloc, PasswordResetState>(
      listener: (context, state) {
        if (state is PasswordResetError) {
          setState(() {
            _serverError = state.message;
            _serverErrorGuard.block('password', _passwordController.text);
          });
        }
      },
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
                'Defina sua nova senha',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppTextField(
                label: 'Senha',
                hint: 'Defina sua senha',
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: true,
                errorText: _serverError,
              ),
              if (_passwordFocused) ...[
                const SizedBox(height: 8),
                PasswordPolicyChecklist(
                  requirements: validators.evaluatePasswordPolicy(_passwordController.text, _policy),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmar Senha',
                hint: 'Digite novamente a senha',
                controller: _confirmController,
                obscureText: true,
                errorText: _confirmError,
              ),
              // A mensagem de erro já aparece no campo Senha (errorText
              // acima); aqui só sobra a ação extra pra pedir novo código.
              if (error != null && error.canRequestNewCode) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _requestNewCode,
                    child: Text(
                      'Solicitar novo código',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              AppButton(
                label: 'Confirmar',
                loading: isLoading,
                onPressed: _isFormComplete ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
