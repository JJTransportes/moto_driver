import 'package:flutter/material.dart';
import 'package:moto_driver/design_system/design_system.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const GradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => context.moto.accentLiquid.createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: context.moto.textOnAccent),
      ),
    );
  }
}
