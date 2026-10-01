// =====================================================================
// Feedback e espera — nada de spinner cinza.
//   MotoSonar            "Buscando motorista" (radar + ondas + orbe)
//   MotoSuccessCheck     "Viagem concluída" (orbe limão + check + gotas)
//   MotoCountdownRing    aceitar corrida em N segundos
//   MotoSwipeToConfirm   "Deslize para finalizar" (motorista)
//   MotoSkeleton         carregando listas
// =====================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../moto_palette.dart';
import '../moto_tokens.dart';

// ------------------------------------------------------------------ ORBE
/// Esfera de vidro (base do sonar e de estados vazios).
class MotoOrb extends StatelessWidget {
  const MotoOrb({super.key, required this.icon, this.size = 78});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.3, -.6),
          radius: .9,
          colors: [Colors.white, Color(0xBFFFFFFF), Color(0xF2E2EAFB)],
          stops: [0, .45, 1],
        ),
        border: Border.all(color: c.borderSubtle),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 36, offset: const Offset(0, 18), spreadRadius: -14)],
      ),
      child: Icon(icon, color: c.accent, size: size * .41),
    );
  }
}

// ------------------------------------------------------------------ SONAR
class MotoSonar extends StatefulWidget {
  const MotoSonar({super.key, this.size = 188, this.icon = Icons.directions_car_rounded});
  final double size;
  final IconData icon;

  @override
  State<MotoSonar> createState() => _MotoSonarState();
}

class _MotoSonarState extends State<MotoSonar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return Semantics(
      label: 'Procurando motorista',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size.square(widget.size), painter: _SonarPainter(_c.value, c)),
              Transform.scale(
                scale: 1 + .05 * math.sin(_c.value * math.pi * 2),
                child: MotoOrb(icon: widget.icon, size: widget.size * .41),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SonarPainter extends CustomPainter {
  _SonarPainter(this.t, this.c);
  final double t;
  final MotoPalette c;

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    final r = s.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r - .5, ring..color = c.accentBright.withValues(alpha: .2));
    canvas.drawCircle(center, r * .6, ring..color = c.accentBright.withValues(alpha: .12));
    // radar: setor que gira (cobalto → limão na ponta)
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [
          c.accentBright.withValues(alpha: 0),
          c.accentBright.withValues(alpha: 0),
          c.accentBright.withValues(alpha: .22),
          c.signal.withValues(alpha: .6),
          c.signal.withValues(alpha: 0),
        ],
        stops: const [0, .55, .88, .995, 1],
        transform: GradientRotation(t * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, sweep);
    // ondas saindo do orbe
    for (final d in [0.0, .5]) {
      final k = MotoMotion.easeOut.transform((t + d) % 1);
      canvas.drawCircle(
        center,
        r * (.3 + .7 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.accentBright.withValues(alpha: .35 * (1 - k)),
      );
    }
  }

  @override
  bool shouldRepaint(_SonarPainter old) => old.t != t;
}

// ---------------------------------------------------------- SUCCESS CHECK
class MotoSuccessCheck extends StatefulWidget {
  const MotoSuccessCheck({super.key, this.size = 88});
  final double size;

  @override
  State<MotoSuccessCheck> createState() => _MotoSuccessCheckState();
}

class _MotoSuccessCheckState extends State<MotoSuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150))
    ..forward();
  late final Animation<double> _pop = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .55, curve: MotoMotion.spring),
  );
  late final Animation<double> _draw = CurvedAnimation(
    parent: _c,
    curve: const Interval(.25, .75, curve: MotoMotion.easeOut),
  );
  late final Animation<double> _burst = CurvedAnimation(
    parent: _c,
    curve: const Interval(.2, 1, curve: MotoMotion.easeOut),
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final s = widget.size;
    return Semantics(
      label: 'Concluído',
      child: SizedBox.square(
        dimension: s * 1.9,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(s * 1.9),
                painter: _BurstPainter(_burst.value, c.signal, c.accentBright, s),
              ),
              Transform.scale(
                scale: .5 + .5 * _pop.value,
                child: Opacity(
                  opacity: _pop.value.clamp(0, 1),
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: c.signalLiquid,
                      boxShadow: [
                        BoxShadow(color: c.signalSoft, spreadRadius: 8),
                        const BoxShadow(
                          color: Color(0xA65A8200),
                          blurRadius: 40,
                          offset: Offset(0, 20),
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: _CheckPainter(_draw.value, c.textOnSignal)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.a, this.b, this.core);
  final double t, core;
  final Color a, b;

  @override
  void paint(Canvas canvas, Size s) {
    if (t <= 0 || t >= 1) return;
    final center = s.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4;
      final dist = core * .5 + core * .7 * t;
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      canvas.drawCircle(
        pos,
        (i.isEven ? 4.0 : 3.0) * (1 - t * .3),
        Paint()..color = (i.isEven ? a : b).withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .29, s.height * .52)
      ..lineTo(s.width * .43, s.height * .66)
      ..lineTo(s.width * .72, s.height * .35);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

// --------------------------------------------------------- COUNTDOWN RING
/// Anel que drena (limão → cobalto). Chama [onTimeout] no zero.
class MotoCountdownRing extends StatefulWidget {
  const MotoCountdownRing({super.key, this.seconds = 15, this.onTimeout, this.size = 68});
  final int seconds;
  final VoidCallback? onTimeout;
  final double size;

  @override
  State<MotoCountdownRing> createState() => _MotoCountdownRingState();
}

class _MotoCountdownRingState extends State<MotoCountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: Duration(seconds: widget.seconds),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onTimeout?.call();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final left = (widget.seconds * (1 - _c.value)).ceil();
          return Semantics(
            label: '$left segundos para aceitar',
            child: CustomPaint(
              painter: _RingPainter(
                1 - _c.value,
                c.signal,
                c.accentBright,
                c.isDark ? const Color(0x1FFFFFFF) : MotoRaw.porcelana300,
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.isDark ? const Color(0x14FFFFFF) : Colors.white,
                    boxShadow: c.isDark
                        ? null
                        : [BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 2), spreadRadius: -2)],
                  ),
                  child: Center(
                    child: Text(
                      '$left',
                      style: TextStyle(
                        fontFamily: MotoFont.display,
                        fontSize: widget.size * .29,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.a, this.b, this.track);
  final double progress;
  final Color a, b, track;

  @override
  void paint(Canvas canvas, Size s) {
    final r = (Offset.zero & s).deflate(3);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    p.shader = SweepGradient(colors: [a, b, a], transform: const GradientRotation(-math.pi / 2)).createShader(r);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ------------------------------------------------------ SWIPE TO CONFIRM
/// Motorista: iniciar/finalizar viagem sem toque acidental.
class MotoSwipeToConfirm extends StatefulWidget {
  const MotoSwipeToConfirm({super.key, required this.label, required this.onConfirmed});
  final String label;
  final VoidCallback onConfirmed;

  @override
  State<MotoSwipeToConfirm> createState() => _MotoSwipeToConfirmState();
}

class _MotoSwipeToConfirmState extends State<MotoSwipeToConfirm> with SingleTickerProviderStateMixin {
  static const _h = 66.0, _knob = 56.0;
  double _x = 0;
  bool _dragging = false;
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return LayoutBuilder(
      builder: (context, box) {
        final max = box.maxWidth - _knob - 10;
        final p = max <= 0 ? 0.0 : _x / max;
        final dur = _dragging ? Duration.zero : MotoMotion.slow;
        return Semantics(
          button: true,
          label: widget.label,
          onTap: widget.onConfirmed, // leitor de tela: toque duplo confirma
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0x0FFFFFFF) : MotoRaw.porcelana200,
              borderRadius: MotoRadius.brPill,
              border: Border.all(color: c.borderSubtle),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedContainer(
                  duration: dur,
                  curve: MotoMotion.spring,
                  width: _x + _knob + 10,
                  decoration: BoxDecoration(
                    borderRadius: MotoRadius.brPill,
                    gradient: LinearGradient(colors: [c.signal.withValues(alpha: 0), c.signal.withValues(alpha: .3)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Center(
                    child: Opacity(
                      opacity: (1 - p * 1.4).clamp(0, 1),
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (context, child) => ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => LinearGradient(
                            colors: [c.textTertiary, c.textPrimary, c.textTertiary],
                            begin: Alignment(-3 + 6 * _shine.value, 0),
                            end: Alignment(-1 + 6 * _shine.value, 0),
                          ).createShader(r),
                          child: child,
                        ),
                        child: Text(
                          widget.label,
                          style: const TextStyle(fontFamily: MotoFont.ui, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: dur,
                  curve: MotoMotion.spring,
                  left: 5 + _x,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: (d) => setState(() => _x = (_x + d.delta.dx).clamp(0, max)),
                    onHorizontalDragEnd: (_) {
                      final done = _x > max * .85;
                      setState(() {
                        _dragging = false;
                        _x = done ? max : 0;
                      });
                      if (done) {
                        HapticFeedback.heavyImpact();
                        widget.onConfirmed();
                      }
                    },
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: BoxDecoration(
                        gradient: c.signalLiquid,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: c.signalSoft, spreadRadius: 5),
                          const BoxShadow(
                            color: Color(0x8C78AA0A),
                            blurRadius: 22,
                            offset: Offset(0, 8),
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: Icon(Icons.chevron_right_rounded, color: c.textOnSignal, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- SKELETON
class MotoSkeleton extends StatefulWidget {
  const MotoSkeleton({super.key, this.width, this.height = 14, this.radius = MotoRadius.xs});
  final double? width;
  final double height;
  final double radius;

  @override
  State<MotoSkeleton> createState() => _MotoSkeletonState();
}

class _MotoSkeletonState extends State<MotoSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-2 + 4 * _c.value, 0),
          end: Alignment(-1 + 4 * _c.value, 0),
          colors: const [MotoRaw.porcelana200, Colors.white, MotoRaw.porcelana200],
        ),
      ),
    ),
  );
}
