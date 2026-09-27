import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/utils/server_error_guard.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_event.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/verify_reset_code_state.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/gradient_text.dart';

/// Tela 1 do reset de senha: usuário digita o código recebido por e-mail.
/// Em caso de sucesso, navega para a tela 2 (`/reset-password`) levando o
/// `resetToken` de uso único.
class VerifyResetCodePage extends StatefulWidget {
  final String email;

  const VerifyResetCodePage({super.key, required this.email});

  @override
  State<VerifyResetCodePage> createState() => _VerifyResetCodePageState();
}

class _VerifyResetCodePageState extends State<VerifyResetCodePage> {
  final _codeController = TextEditingController();
  String? _codeError;

  // Bloqueia o botão "Confirmar" depois de um erro do backend (código
  // inválido/expirado/já usado) até o código ser editado — evita spammar
  // o botão reenviando o mesmo código rejeitado.
  final _serverErrorGuard = ServerErrorGuard();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (_serverErrorGuard.isBlocking) {
      _serverErrorGuard.clearIfEdited('code', _codeController.text);
      if (!_serverErrorGuard.isBlocking) _codeError = null;
    }
    setState(() {});
  }

  bool get _isFormComplete =>
      _codeController.text.trim().isNotEmpty && !_serverErrorGuard.isBlocking;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _codeError = null;
      if (_codeController.text.trim().isEmpty) {
        _codeError = 'Código obrigatório';
        valid = false;
      }
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<VerifyResetCodeBloc>().add(VerifyCodeSubmitted(_codeController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VerifyResetCodeBloc, VerifyResetCodeState>(
      listener: (context, state) {
        if (state is VerifyCodeSuccess) {
          Modular.to.pushNamed(
            '/reset-password',
            arguments: {'resetToken': state.resetToken, 'email': widget.email},
          );
        } else if (state is VerifyCodeError) {
          setState(() {
            _codeError = state.message;
            _serverErrorGuard.block('code', _codeController.text);
          });
        }
      },
      builder: (context, state) => _buildForm(state),
    );
  }

  Widget _buildForm(VerifyResetCodeState state) {
    final isLoading = state is VerifyCodeSubmitting;
    final error = state is VerifyCodeError ? state : null;

    return Scaffold(
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
                'Informe o código de verificação enviado para ${widget.email}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.moto.textPrimary),
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
              // A mensagem de erro já aparece no campo (errorText acima);
              // aqui só sobra a ação extra para o caso "esgotou tentativas".
              if (error != null && error.exhausted) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/recovery'),
                    child: Text(
                      'Solicitar novo código',
                      style: GoogleFonts.inter(fontSize: 12, color: context.moto.accent),
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
