import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moto_driver/design_system/design_system.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final FocusNode? focusNode;
  final IconData? icon;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLength,
    this.focusNode,
    this.icon,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: MotoFont.ui,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: MotoSpace.s2),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
          style: TextStyle(
            fontFamily: MotoFont.ui,
            fontSize: 16,
            color: c.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontFamily: MotoFont.ui,
              fontSize: 16,
              color: c.textTertiary,
            ),
            prefixIcon: widget.icon != null
                ? Icon(widget.icon, color: c.textTertiary, size: 20)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MotoSpace.s4,
              vertical: 18,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      color: c.textTertiary,
                      size: 20,
                    ),
                    splashRadius: 20,
                    tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            filled: true,
            fillColor: c.bgRaised,
            border: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: c.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: c.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: c.borderFocus, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: c.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: MotoRadius.brSm,
              borderSide: BorderSide(color: c.danger, width: 1.5),
            ),
            errorText: widget.errorText,
          ),
        ),
      ],
    );
  }
}
