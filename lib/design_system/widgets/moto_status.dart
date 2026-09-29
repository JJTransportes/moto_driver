// =====================================================================
// MotoStatusBadge — ponto + texto (nunca só cor). "Ao vivo" pulsa.
//
//   MotoStatusBadge.trip(TripStatus.emAndamento)
//   MotoStatusBadge(label: 'Fila zerada', tone: MotoTone.success)
// =====================================================================
import 'package:flutter/material.dart';

import '../moto_palette.dart';
import '../moto_tokens.dart';

enum MotoTone { info, success, warning, danger, neutral }

/// Mapeamento ÚNICO de status de viagem → visual (passageiro, motorista e painel).
/// Ajuste os nomes do enum aos do backend e use `TripStatus.values.byName(api.status)`.
enum TripStatus {
  solicitada('Solicitada', MotoTone.info, false),
  aceita('Aceita · aguardando', MotoTone.warning, false),
  emAndamento('Em andamento', MotoTone.success, true),
  concluida('Concluída', MotoTone.success, false),
  cancelada('Cancelada', MotoTone.danger, false);

  const TripStatus(this.label, this.tone, this.live);
  final String label;
  final MotoTone tone;
  final bool live;
}

class MotoStatusBadge extends StatelessWidget {
  const MotoStatusBadge({super.key, required this.label, this.tone = MotoTone.info, this.live = false});

  factory MotoStatusBadge.trip(TripStatus s, {Key? key}) =>
      MotoStatusBadge(key: key, label: s.label, tone: s.tone, live: s.live);

  final String label;
  final MotoTone tone;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final (fg, bg, dot) = switch (tone) {
      MotoTone.info => (c.info, c.infoSoft, c.accentBright),
      MotoTone.success => (c.success, c.successSoft, c.signal),
      MotoTone.warning => (c.warning, c.warningSoft, MotoRaw.ambar500),
      MotoTone.danger => (c.danger, c.dangerSoft, c.danger),
      MotoTone.neutral => (c.textSecondary, c.borderSubtle, c.textTertiary),
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 10, right: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: MotoRadius.brPill,
        border: Border.all(color: fg.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: dot, live: live),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(fontFamily: MotoFont.ui, fontSize: 12, fontWeight: FontWeight.w600, color: fg, height: 1),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.live});
  final Color color;
  final bool live;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.live) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 7,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = MotoMotion.easeOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: widget.color.withValues(alpha: .22), spreadRadius: 3),
              if (widget.live)
                BoxShadow(
                  color: widget.color.withValues(alpha: (1 - t) * .55),
                  spreadRadius: 3 + 5 * t,
                ),
            ],
          ),
        );
      },
    ),
  );
}
