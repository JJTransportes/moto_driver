import 'package:flutter/material.dart';
import 'package:moto_driver/design_system/design_system.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MotoButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
    );
  }
}
