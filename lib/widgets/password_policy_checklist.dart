import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/utils/validators.dart';
import 'package:moto_driver/design_system/design_system.dart';

/// Checklist "estilo gov.br" da política de senha: cada item começa neutro
/// (cinza, sem estado de erro) e vira verde com ✓ quando cumprido. Nunca
/// mostra um ✗ vermelho de erro — é feedback positivo progressivo, não uma
/// lista de erros. Widget dumb: só desenha [requirements] já avaliados,
/// não conhece o texto digitado nem importa nada de `modules/`.
class PasswordPolicyChecklist extends StatelessWidget {
  final List<PasswordRequirement> requirements;

  const PasswordPolicyChecklist({super.key, required this.requirements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final requirement in requirements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  requirement.satisfied ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: requirement.satisfied ? context.moto.success : context.moto.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requirement.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: requirement.satisfied ? context.moto.success : context.moto.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
