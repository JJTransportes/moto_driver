import 'package:flutter/material.dart';
import 'package:moto_driver/core/utils/masks.dart';
import 'package:moto_driver/core/utils/validators.dart' as validators;

class ProfileForm extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;

  /// Enquanto false, todos os campos ficam somente leitura (view mode).
  /// Quando true, nome/e-mail/confirmar e-mail/telefone ficam editáveis.
  final bool isEditing;

  /// Chamado a cada alteração de campo, para o widget pai reavaliar [isValid].
  final VoidCallback? onChanged;

  const ProfileForm({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
    required this.isEditing,
    this.onChanged,
  });

  @override
  ProfileFormState createState() => ProfileFormState();
}

class ProfileFormState extends State<ProfileForm> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _confirmEmailController;
  late TextEditingController _phoneController;

  String? _nameError;
  String? _emailError;
  String? _confirmEmailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(
      text: widget.isEditing ? widget.initialEmail : _maskEmail(widget.initialEmail),
    );
    _confirmEmailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(
      text: widget.isEditing ? _formatPhone(widget.initialPhone) : _maskPhone(widget.initialPhone),
    );

    for (final controller in [_nameController, _emailController, _confirmEmailController, _phoneController]) {
      controller.addListener(_onFieldsChanged);
    }
  }

  void _onFieldsChanged() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isEditing && widget.isEditing) {
      // Entrando em modo de edição: reseta os campos para os valores reais.
      _nameController.text = widget.initialName;
      _emailController.text = widget.initialEmail;
      _confirmEmailController.text = widget.initialEmail;
      _phoneController.text = _formatPhone(widget.initialPhone);
      _nameError = null;
      _emailError = null;
      _confirmEmailError = null;
      _phoneError = null;
    } else if (!widget.isEditing) {
      // View mode (saiu da edição ou os dados carregados mudaram): mostra
      // e-mail/telefone mascarados, nunca o valor completo.
      _nameController.text = widget.initialName;
      _emailController.text = _maskEmail(widget.initialEmail);
      _confirmEmailController.text = widget.initialEmail;
      _phoneController.text = _maskPhone(widget.initialPhone);
    }
  }

  /// Mostra só o primeiro caractere do usuário: `i***@dominio.com`.
  String _maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    return '${email.substring(0, 1)}***${email.substring(atIndex)}';
  }

  /// Mantém DDD e os últimos 4 dígitos visíveis, mascara o resto: `(11) ****-5678`.
  String _maskPhone(String raw) {
    final digits = unmaskDigits(raw);
    if (digits.isEmpty) return '';
    final capped = digits.length > 11 ? digits.substring(0, 11) : digits;
    if (capped.length <= 2) return '($capped';

    final ddd = capped.substring(0, 2);
    final rest = capped.substring(2);
    if (rest.isEmpty) return '($ddd)';

    final splitAt = rest.length > 8 ? 5 : 4;
    final part1 = rest.length > splitAt ? rest.substring(0, splitAt) : rest;
    final part2 = rest.length > splitAt ? rest.substring(splitAt) : '';

    var formatted = '($ddd) ${'*' * part1.length}';
    if (part2.isNotEmpty) formatted += '-$part2';
    return formatted;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    if (raw.isEmpty) return raw;
    return PhoneInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: raw),
    ).text;
  }

  String? get _liveConfirmEmailError {
    if (_confirmEmailController.text.isEmpty) return null;
    if (_confirmEmailController.text.trim().toLowerCase() != _emailController.text.trim().toLowerCase()) {
      return 'Os e-mails não coincidem';
    }
    return null;
  }

  /// Telefone é opcional: sem erro se vazio, valida formato só se preenchido.
  String? get _phoneErrorIfAny =>
      _phoneController.text.trim().isEmpty ? null : validators.validatePhone(_phoneController.text);

  /// Valida ao tentar salvar; retorna true se tudo estiver ok.
  bool validate() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'Nome é obrigatório' : null;
      _emailError = validators.validateEmailFormat(_emailController.text.trim());
      _confirmEmailError = _confirmEmailController.text.trim().isEmpty
          ? 'Campo obrigatório'
          : _liveConfirmEmailError;
      _phoneError = _phoneErrorIfAny;
    });
    return _nameError == null && _emailError == null && _confirmEmailError == null && _phoneError == null;
  }

  /// Estado ao vivo (sem tocar nas mensagens de erro exibidas) usado para
  /// habilitar/desabilitar o botão Salvar enquanto o usuário digita.
  bool get isValid {
    if (!widget.isEditing) return false;
    return _nameController.text.trim().isNotEmpty &&
        validators.validateEmailFormat(_emailController.text.trim()) == null &&
        _confirmEmailController.text.trim().toLowerCase() == _emailController.text.trim().toLowerCase() &&
        _phoneErrorIfAny == null;
  }

  bool get emailChanged => _emailController.text.trim().toLowerCase() != widget.initialEmail.trim().toLowerCase();

  String get name => _nameController.text.trim();
  String get email => _emailController.text.trim();
  String get phone => unmaskDigits(_phoneController.text);

  @override
  Widget build(BuildContext context) {
    final editing = widget.isEditing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          enabled: editing,
          decoration: InputDecoration(
            labelText: 'Nome',
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
            errorText: _nameError,
            filled: !editing,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          enabled: editing,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail',
            prefixIcon: const Icon(Icons.email),
            border: const OutlineInputBorder(),
            errorText: _emailError,
            filled: !editing,
            fillColor: Colors.grey.shade100,
          ),
        ),
        if (editing) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _confirmEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Confirmar e-mail',
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(),
              errorText: _confirmEmailError ?? _liveConfirmEmailError,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          enabled: editing,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
          decoration: InputDecoration(
            labelText: 'Telefone (opcional)',
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
            hintText: '(12) 91234-5678',
            errorText: _phoneError,
            filled: !editing,
            fillColor: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }
}
