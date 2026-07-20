import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_driver/widgets/app_button.dart';
import 'package:moto_driver/widgets/app_text_field.dart';

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
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnhController = TextEditingController();

  DateTime? _birthdate;

  String? _fullNameError;
  String? _cpfError;
  String? _rgError;
  String? _birthdateError;
  String? _emailError;
  String? _passwordError;
  String? _phoneError;
  String? _cnhError;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _registrationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _cnhController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _fullNameError = null;
      _cpfError = null;
      _rgError = null;
      _birthdateError = null;
      _emailError = null;
      _passwordError = null;
      _phoneError = null;
      _cnhError = null;

      if (_fullNameController.text.trim().isEmpty) {
        _fullNameError = 'Campo obrigatório';
        valid = false;
      }
      if (_cpfController.text.trim().isEmpty) {
        _cpfError = 'Campo obrigatório';
        valid = false;
      }
      if (_rgController.text.trim().isEmpty) {
        _rgError = 'Campo obrigatório';
        valid = false;
      }
      if (_birthdate == null) {
        _birthdateError = 'Campo obrigatório';
        valid = false;
      }
      if (_emailController.text.trim().isEmpty) {
        _emailError = 'Campo obrigatório';
        valid = false;
      } else if (!_emailController.text.trim().contains('@')) {
        _emailError = 'E-mail inválido';
        valid = false;
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = 'Campo obrigatório';
        valid = false;
      }
      final phoneDigits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (phoneDigits.isNotEmpty && phoneDigits.length < 10) {
        _phoneError = 'Telefone inválido';
        valid = false;
      }
      if (_cnhController.text.trim().isEmpty) {
        _cnhError = 'Campo obrigatório';
        valid = false;
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
      registration: _registrationController.text.trim().isEmpty ? null : _registrationController.text.trim(),
      birthdate: _birthdate!,
      email: _emailController.text.trim(),
      initialPassword: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
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
        }
      },
      builder: (context, state) {
        final isLoading = state is RegisterLoading;
        final errorMessage = state is RegisterFailure ? state.message : null;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            surfaceTintColor: AppColors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Criar conta',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              child: Column(
                spacing: 16,
                children: [
                  AppTextField(
                    label: 'Nome completo',
                    hint: 'Informe seu nome completo',
                    controller: _fullNameController,
                    errorText: _fullNameError,
                  ),
                  AppTextField(
                    label: 'CPF',
                    hint: '000.000.000-00',
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    errorText: _cpfError,
                  ),
                  AppTextField(
                    label: 'RG',
                    hint: '00.000.000-0',
                    controller: _rgController,
                    errorText: _rgError,
                  ),
                  AppTextField(
                    label: 'Matrícula',
                    hint: 'N° de matrícula',
                    controller: _registrationController,
                    keyboardType: TextInputType.number,
                  ),
                  AppTextField(
                    label: 'Telefone',
                    hint: '(12) 91234-5678',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    errorText: _phoneError,
                  ),
                  _buildDateField(),
                  AppTextField(
                    label: 'E-mail',
                    hint: 'Informe seu e-mail',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  _buildPasswordField(),
                  AppTextField(
                    label: 'CNH',
                    hint: 'Número da CNH',
                    controller: _cnhController,
                    errorText: _cnhError,
                    keyboardType: TextInputType.number,
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  AppButton(
                    label: 'Cadastrar',
                    loading: isLoading,
                    onPressed: _submit,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Já tem uma conta? Entrar',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primary,
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data de nascimento',
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _birthdateError != null ? Colors.red : AppColors.primary,
              ),
            ),
            child: Text(
              _birthdate != null ? DateFormat('dd/MM/yyyy').format(_birthdate!) : 'Selecione a data',
              style: GoogleFonts.robotoFlex(
                fontSize: 10,
                fontWeight: FontWeight.w300,
                color: _birthdate != null ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        if (_birthdateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _birthdateError!,
              style: const TextStyle(color: Colors.red, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Senha',
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Informe sua senha',
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: AppColors.primary.withValues(alpha: 0.5),
              letterSpacing: 0.2,
            ),
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _passwordError,
          ),
        ),
      ],
    );
  }
}
