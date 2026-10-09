import 'package:flutter/material.dart';
import 'package:moto_driver/design_system/design_system.dart';

/// Proximidade do motorista ao embarque (viagem em `Accepted`). O backend manda
/// `None`, `Nearby` ou `Arrived`; qualquer outro valor vira [none].
enum PickupProximity {
  none,
  nearby,
  arrived;

  static PickupProximity parse(String? value) => switch (value) {
    'Nearby' => PickupProximity.nearby,
    'Arrived' => PickupProximity.arrived,
    _ => PickupProximity.none,
  };
}

/// Indicação no card da viagem ativa: o passageiro foi avisado da aproximação
/// ([PickupProximity.nearby]) ou o motorista chegou ao embarque
/// ([PickupProximity.arrived]). Não ocupa espaço quando não há alerta.
class PickupProximityBanner extends StatelessWidget {
  const PickupProximityBanner({super.key, required this.proximity});

  final PickupProximity proximity;

  @override
  Widget build(BuildContext context) {
    final (text, icon, color) = switch (proximity) {
      PickupProximity.none => (null, null, null),
      PickupProximity.nearby => (
        'Passageiro avisado: você está próximo',
        Icons.near_me,
        context.moto.accent,
      ),
      PickupProximity.arrived => (
        'Você chegou ao ponto de embarque',
        Icons.place,
        context.moto.success,
      ),
    };

    if (text == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.moto.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
