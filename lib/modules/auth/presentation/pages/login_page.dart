import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/brand/i_brand_cache_service.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_driver/widgets/app_button.dart';
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
  String? _brandImagePath;

  @override
  void initState() {
    super.initState();
    _loadBrandImage();
  }

  Future<void> _loadBrandImage() async {
    final path = await Modular.get<IBrandCacheService>().getBrandImagePath();
    if (mounted) {
      setState(() {
        _brandImagePath = path;
      });
    }
  }

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
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        final errorMessage = state is LoginFailure ? state.message : null;

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 36,
              ),
              child: Column(
                spacing: size.height * 0.1,
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
                  _buildBrandImage(),
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
                        errorText: _passwordError,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pushNamed('/recovery'),
                          child: Text('Esqueci minha senha', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
                        ),
                      ),
                      if (errorMessage != null) ...[
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                      ],
                  AppButton(
                    label: 'Entrar',
                    loading: isLoading,
                    onPressed: _submit,
                  ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandImage() {
    if (_brandImagePath != null) {
      return Image.file(
        File(_brandImagePath!),
        width: 224,
        height: 90,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildDefaultLogo(),
      );
    }
    return _buildDefaultLogo();
  }

  Widget _buildDefaultLogo() {
    return Image.asset(
      'assets/images/logo.jpeg',
      width: 224,
      height: 90,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 224,
        height: 90,
        child: Placeholder(),
      ),
    );
  }
}
