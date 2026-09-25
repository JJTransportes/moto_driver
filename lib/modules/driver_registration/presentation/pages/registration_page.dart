import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/core/utils/masks.dart';
import 'package:moto_driver/core/utils/server_error_guard.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';
import 'package:moto_driver/widgets/password_policy_checklist.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _fullNameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _registrationController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnhController = TextEditingController();

  DateTime? _birthdate;

  String? _fullNameError;
  String? _cpfError;
  String? _rgError;
  String? _registrationError;
  String? _birthdateError;
  String? _emailError;
  String? _confirmEmailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _phoneError;
  String? _cnhError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _passwordFocusNode = FocusNode();
  bool _passwordFocused = false;

  // Usa o fallback estático até a política real chegar do backend — o
  // cadastro nunca fica bloqueado esperando o GET (design D4).
  PasswordPolicy _passwordPolicy = const PasswordPolicy.fallback();

  // Bloqueia o botão "Cadastrar" depois de um erro do backend (ex.: e-mail
  // já cadastrado) até o campo responsável ser editado — evita spammar o
  // botão reenviando o mesmo dado rejeitado.
  final _serverErrorGuard = ServerErrorGuard();

  TextEditingController? _controllerFor(String field) => switch (field) {
    'email' => _emailController,
    'cpf' => _cpfController,
    'cnh' => _cnhController,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _fullNameController,
      _cpfController,
      _rgController,
      _registrationController,
      _emailController,
      _confirmEmailController,
      _passwordController,
      _confirmPasswordController,
      _cnhController,
    ]) {
      controller.addListener(_onFieldsChanged);
    }
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
    _loadPasswordPolicy();
  }

  Future<void> _loadPasswordPolicy() async {
    final usecase = Modular.get<IGetPasswordPolicyUsecase>();
    final result = await usecase.call();
    if (!mounted) return;
    result.fold(
      (policy) => setState(() => _passwordPolicy = policy),
      // Usecase é sempre-sucesso (fallback interno); nada a fazer aqui.
      (_) {},
    );
  }

  void _onFieldsChanged() {
    final blockedField = _serverErrorGuard.blockedField;
    if (blockedField != null) {
      _serverErrorGuard.clearIfEdited(
        blockedField,
        _controllerFor(blockedField)!.text,
      );
      if (!_serverErrorGuard.isBlocking) {
        switch (blockedField) {
          case 'email':
            _emailError = null;
            break;
          case 'cpf':
            _cpfError = null;
            break;
          case 'cnh':
            _cnhError = null;
            break;
        }
      }
    }
    setState(() {});
  }

  String? get _liveConfirmEmailError {
    if (_confirmEmailController.text.isEmpty) return null;
    if (_confirmEmailController.text.trim().toLowerCase() !=
        _emailController.text.trim().toLowerCase()) {
      return 'Os e-mails não coincidem';
    }
    return null;
  }

  // Diferente do e-mail, senha não é normalizada (case-sensitive, sem trim) —
  // "Senha1!" e "senha1!" são senhas diferentes de verdade.
  String? get _liveConfirmPasswordError {
    if (_confirmPasswordController.text.isEmpty) return null;
    if (_confirmPasswordController.text != _passwordController.text) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  bool get _isFormComplete =>
      _fullNameController.text.trim().isNotEmpty &&
      _cpfController.text.trim().isNotEmpty &&
      _rgController.text.trim().isNotEmpty &&
      _registrationController.text.trim().isNotEmpty &&
      _birthdate != null &&
      validators.validateEmailFormat(_emailController.text.trim()) == null &&
      _confirmEmailController.text.trim().toLowerCase() ==
          _emailController.text.trim().toLowerCase() &&
      validators.isPasswordValid(_passwordController.text, _passwordPolicy) &&
      _confirmPasswordController.text == _passwordController.text &&
      _cnhController.text.trim().isNotEmpty &&
      !_serverErrorGuard.isBlocking;

  int get _formStep {
    final personalDataReady =
        _fullNameController.text.trim().isNotEmpty &&
        _cpfController.text.length == 14 &&
        _rgController.text.trim().isNotEmpty &&
        _registrationController.text.trim().isNotEmpty &&
        _birthdate != null;
    if (!personalDataReady) return 0;
    return _isFormComplete ? 2 : 1;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _registrationController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cnhController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _fullNameError = null;
      _cpfError = null;
      _rgError = null;
      _registrationError = null;
      _birthdateError = null;
      _emailError = null;
      _confirmEmailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _phoneError = null;
      _cnhError = null;

      if (_fullNameController.text.trim().isEmpty) {
        _fullNameError = 'Campo obrigatório';
        valid = false;
      } else {
        _fullNameError =
            validators.validateMaxLength(
              _fullNameController.text,
              100,
              'Nome completo',
            ) ??
            validators.validateSafeText(
              _fullNameController.text,
              'Nome completo',
            );
        if (_fullNameError != null) valid = false;
      }

      if (_cpfController.text.trim().isEmpty) {
        _cpfError = 'Campo obrigatório';
        valid = false;
      } else {
        _cpfError = validators.validateCpf(_cpfController.text);
        if (_cpfError != null) valid = false;
      }

      if (_rgController.text.trim().isEmpty) {
        _rgError = 'Campo obrigatório';
        valid = false;
      } else {
        _rgError = validators.validateRg(_rgController.text);
        if (_rgError != null) valid = false;
      }

      if (_registrationController.text.trim().isEmpty) {
        _registrationError = 'Campo obrigatório';
        valid = false;
      } else {
        _registrationError = validators.validateAlphanumericFormat(
          _registrationController.text,
          'Matrícula',
          30,
        );
        if (_registrationError != null) valid = false;
      }

      if (_birthdate == null) {
        _birthdateError = 'Campo obrigatório';
        valid = false;
      }

      if (_emailController.text.trim().isEmpty) {
        _emailError = 'Campo obrigatório';
        valid = false;
      } else {
        _emailError =
            validators.validateEmailFormat(_emailController.text.trim()) ??
            validators.validateMaxLength(_emailController.text, 100, 'E-mail');
        if (_emailError != null) valid = false;
      }

      if (_confirmEmailController.text.trim().isEmpty) {
        _confirmEmailError = 'Campo obrigatório';
        valid = false;
      } else if (_confirmEmailController.text.trim().toLowerCase() !=
          _emailController.text.trim().toLowerCase()) {
        _confirmEmailError = 'Os e-mails não coincidem';
        valid = false;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = 'Campo obrigatório';
        valid = false;
      } else if (!validators.isPasswordValid(
        _passwordController.text,
        _passwordPolicy,
      )) {
        _passwordError = 'Senha não atende aos requisitos da política.';
        valid = false;
      }

      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'Campo obrigatório';
        valid = false;
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordError = 'As senhas não coincidem';
        valid = false;
      }

      if (_phoneController.text.trim().isNotEmpty) {
        _phoneError = validators.validatePhone(_phoneController.text);
        if (_phoneError != null) valid = false;
      }

      if (_cnhController.text.trim().isEmpty) {
        _cnhError = 'Campo obrigatório';
        valid = false;
      } else {
        _cnhError = validators.validateCnh(_cnhController.text);
        if (_cnhError != null) valid = false;
      }
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;

    final params = RegisterParams(
      fullName: _fullNameController.text.trim(),
      cpf: _cpfController.text.trim(),
      rg: _rgController.text.trim(),
      registration: _registrationController.text.trim(),
      birthdate: _birthdate!,
      email: _emailController.text.trim(),
      initialPassword: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      cnh: _cnhController.text.trim(),
    );

    context.read<RegisterBloc>().add(RegisterSubmitted(params));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _birthdate = picked;
        _birthdateError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          Navigator.of(context).pushReplacementNamed(
            '/driver-register/confirmation',
          );
        } else if (state is RegisterFailure) {
          setState(() {
            final field = state.field;
            if (field != null) {
              _serverErrorGuard.block(field, _controllerFor(field)!.text);
              switch (field) {
                case 'email':
                  _emailError = state.message;
                  break;
                case 'cpf':
                  _cpfError = state.message;
                  break;
                case 'cnh':
                  _cnhError = state.message;
                  break;
              }
            }
          });
        }
      },
      builder: (context, state) {
        final isLoading = state is RegisterLoading;
        final errorMessage = state is RegisterFailure ? state.message : null;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.moto.accent),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Criar conta',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.moto.accent,
              ),
            ),
          ),
          backgroundColor: context.moto.bgBase,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: MotoSpace.gutter,
                vertical: MotoSpace.s6,
              ),
              child: Column(
                spacing: 16,
                children: [
                  MotoStepper(
                    steps: const ['Seus dados', 'Acesso', 'Revisão'],
                    current: _formStep,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formStep == 0
                          ? 'Dados do motorista'
                          : _formStep == 1
                          ? 'Acesso e credencial'
                          : 'Tudo pronto para enviar',
                      style: const TextStyle(
                        fontFamily: MotoFont.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppTextField(
                    label: 'Nome completo *',
                    hint: 'Informe seu nome completo',
                    controller: _fullNameController,
                    errorText: _fullNameError,
                    maxLength: 100,
                  ),
                  AppTextField(
                    label: 'CPF *',
                    hint: '000.000.000-00',
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    errorText: _cpfError,
                    inputFormatters: [CpfInputFormatter()],
                    maxLength: 14,
                  ),
                  AppTextField(
                    label: 'RG *',
                    hint: 'Somente letras e números (7 a 12 caracteres)',
                    controller: _rgController,
                    keyboardType: TextInputType.text,
                    errorText: _rgError,
                    inputFormatters: [
                      AlphanumericInputFormatter(maxLength: 12),
                    ],
                    maxLength: 12,
                  ),
                  AppTextField(
                    label: 'Matrícula *',
                    hint: 'N° de matrícula (letras e números)',
                    controller: _registrationController,
                    keyboardType: TextInputType.text,
                    errorText: _registrationError,
                    inputFormatters: [
                      AlphanumericInputFormatter(maxLength: 30),
                    ],
                    maxLength: 30,
                  ),
                  AppTextField(
                    label: 'Telefone',
                    hint: '(12) 91234-5678',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    errorText: _phoneError,
                    inputFormatters: [PhoneInputFormatter()],
                    maxLength: 15,
                  ),
                  _buildDateField(context),
                  AppTextField(
                    label: 'E-mail *',
                    hint: 'Informe seu e-mail',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                    maxLength: 100,
                  ),
                  AppTextField(
                    label: 'Confirmar E-mail *',
                    hint: 'Digite novamente seu e-mail',
                    controller: _confirmEmailController,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _confirmEmailError ?? _liveConfirmEmailError,
                    maxLength: 100,
                  ),
                  _buildPasswordField(context),
                  _buildConfirmPasswordField(context),
                  AppTextField(
                    label: 'CNH *',
                    hint: 'Número da CNH',
                    controller: _cnhController,
                    errorText: _cnhError,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 11,
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: context.moto.danger,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  AppButton(
                    label: 'Cadastrar',
                    loading: isLoading,
                    onPressed: _isFormComplete ? _submit : null,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Já tem uma conta? Entrar',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.moto.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data de nascimento *',
          style: GoogleFonts.robotoFlex(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.moto.textSecondary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: MotoSpace.s4,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              borderRadius: MotoRadius.brSm,
              color: context.moto.bgRaised,
              border: Border.all(
                color: _birthdateError != null
                    ? context.moto.danger
                    : context.moto.borderDefault,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthdate != null
                        ? DateFormat('dd/MM/yyyy').format(_birthdate!)
                        : 'DD/MM/AAAA',
                    style: GoogleFonts.robotoFlex(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _birthdate != null
                          ? context.moto.textPrimary
                          : context.moto.textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: context.moto.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_birthdateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _birthdateError!,
              style: TextStyle(color: context.moto.danger, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildObscureField(
          context,
          label: 'Senha *',
          hint: 'Informe sua senha',
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscure: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          errorText: _passwordError,
        ),
        const SizedBox(height: MotoSpace.s2),
        MotoStrengthMeter(controller: _passwordController),
        if (_passwordFocused) ...[
          const SizedBox(height: 8),
          PasswordPolicyChecklist(
            requirements: validators.evaluatePasswordPolicy(
              _passwordController.text,
              _passwordPolicy,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmPasswordField(BuildContext context) {
    return _buildObscureField(
      context,
      label: 'Confirmar Senha *',
      hint: 'Digite novamente a senha',
      controller: _confirmPasswordController,
      obscure: _obscureConfirmPassword,
      onToggleObscure: () =>
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      errorText: _confirmPasswordError ?? _liveConfirmPasswordError,
    );
  }

  /// Campo de senha com toggle de visibilidade — compartilhado entre "Senha"
  /// e "Confirmar Senha" pra não duplicar toda a decoração do TextField.
  Widget _buildObscureField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    FocusNode? focusNode,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.robotoFlex(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.moto.textSecondary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          maxLength: 72,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
          style: GoogleFonts.robotoFlex(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: context.moto.textPrimary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.moto.textTertiary,
              letterSpacing: 0.2,
            ),
            filled: true,
            fillColor: context.moto.bgRaised,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MotoSpace.s4,
              vertical: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: context.moto.textTertiary,
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: context.moto.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: context.moto.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(
                color: context.moto.borderFocus,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: context.moto.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: context.moto.danger, width: 2),
            ),
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}
