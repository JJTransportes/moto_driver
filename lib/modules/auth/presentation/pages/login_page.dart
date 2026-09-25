import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/utils/server_error_guard.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/gradient_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  // Bloqueia o botão "Entrar" depois de um erro do backend (credenciais
  // inválidas, etc.) até e-mail ou senha serem editados — evita spammar o
  // botão reenviando as mesmas credenciais rejeitadas.
  final _serverErrorGuard = ServerErrorGuard();

  String get _credentialsSnapshot => '${_emailController.text}|${_passwordController.text}';

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (_serverErrorGuard.isBlocking) {
      _serverErrorGuard.clearIfEdited('credentials', _credentialsSnapshot);
      if (!_serverErrorGuard.isBlocking) {
        _emailError = null;
        _passwordError = null;
      }
    }
    setState(() {});
  }

  bool get _isFormComplete =>
      validators.validateEmailFormat(_emailController.text.trim()) == null &&
      _passwordController.text.isNotEmpty &&
      !_serverErrorGuard.isBlocking;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _emailError = null;
      _passwordError = null;

      if (_emailController.text.trim().isEmpty) {
        _emailError = 'E-mail obrigatório';
        valid = false;
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Senha obrigatória';
        valid = false;
      }
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          Navigator.of(context).pushReplacementNamed('/terms');
        } else if (state is LoginFailure) {
          setState(() {
            _passwordError = state.message;
            _serverErrorGuard.block('credentials', _credentialsSnapshot);
          });
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        // Fallback pro caso do estado já chegar como falha antes do listener
        // rodar (ex.: BlocConsumer com state pré-populado) — o listener é
        // quem cuida do bloqueio anti-spam via _serverErrorGuard.
        final passwordError = _passwordError ?? (state is LoginFailure ? state.message : null);

        return Scaffold(
          body: MotoCanvas(
            child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 36,
              ),
              child: Column(
                spacing: size.height * 0.016,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GradientText(
                    'App Motorista',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLogo(),
                  Column(
                    spacing: 16,
                    children: [
                      AppTextField(
                        label: 'E-mail',
                        hint: 'Informe seu e-mail',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                      ),
                      AppTextField(
                        label: 'Senha',
                        hint: 'Informe sua senha',
                        controller: _passwordController,
                        obscureText: true,
                        errorText: passwordError,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pushNamed('/recovery'),
                          child: Text('Esqueci minha senha', style: GoogleFonts.inter(fontSize: 12, color: context.moto.accent)),
                        ),
                      ),
                      MotoButton(
                        label: 'Entrar',
                        loading: isLoading,
                        onPressed: _isFormComplete ? _submit : null,
                      ),
                      MotoButton(
                        label: 'Criar conta',
                        variant: MotoButtonVariant.glass,
                        onPressed: () => Navigator.of(context).pushNamed('/driver-register/'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    final size = MediaQuery.sizeOf(context);

    return Image.asset(
      'assets/images/moto_driver_logo.png',
      height: size.height * 0.4,
      width: size.width * 0.4,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 224,
        height: 90,
        child: Placeholder(),
      ),
    );
  }
}
