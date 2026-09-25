// =====================================================================
// Superfícies: MotoGlass (vidro) · MotoSapphire (joia escura) · MotoCanvas (fundo)
//
//   MotoGlass(level: GlassLevel.sheet, child: ...)      // sobre o mapa: blur real
//   MotoGlass(painted: true, child: ...)                // listas / sem mapa: sem blur
//   MotoSapphire(child: ...)                            // momento importante
//
// REGRA DE PERFORMANCE: BackdropFilter (blur real) só onde há MAPA atrás
// (sheet, barra de rota, FAB) — 1 a 3 por tela. No resto, painted: true.
// =====================================================================
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../moto_palette.dart';
import '../moto_theme.dart';
import '../moto_tokens.dart';

enum GlassLevel { control, card, sheet }

class MotoGlass extends StatelessWidget {
  const MotoGlass({
    super.key,
    required this.child,
    this.level = GlassLevel.card,
    this.borderRadius,
    this.padding,
    this.painted = false,
  });

  final Widget child;
  final GlassLevel level;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// true = sem BackdropFilter (listas longas, telas sem mapa, aparelho fraco).
  final bool painted;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final radius =
        borderRadius ??
        switch (level) {
          GlassLevel.control => MotoRadius.brPill,
          GlassLevel.card => MotoRadius.brLg,
          GlassLevel.sheet => MotoRadius.brSheet,
        };
    final (fill, sigma, blur) = switch (level) {
      GlassLevel.control => (c.glass1, MotoGlassSpec.blur1, 10.0),
      GlassLevel.card => (c.glass2, MotoGlassSpec.blur2, 28.0),
      GlassLevel.sheet => (c.glass3, MotoGlassSpec.blur3, 60.0),
    };
    final base = painted ? Color.alphaBlend(fill, c.bgRaised.withValues(alpha: c.isDark ? .1 : .82)) : fill;

    final surface = CustomPaint(
      foregroundPainter: _RimPainter(radius, c.rim),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: base,
          // reflexo especular (lâmina diagonal)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: const Alignment(.2, .3),
            colors: [
              Color.alphaBlend(c.highlight.withValues(alpha: c.isDark ? .12 : .6), base),
              base,
            ],
          ),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: .10), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: c.shadow, blurRadius: blur, offset: Offset(0, blur / 2.6), spreadRadius: -blur / 2.5),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: painted
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: surface,
              ),
      ),
    );
  }
}

/// Borda de luz de 1px em gradiente (Flutter não tem borda em gradiente nativa).
class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, this.gradient);
  final BorderRadius radius;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.5);
    canvas.drawRRect(
      radius.toRRect(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius || old.gradient != gradient;
}

/// SAFIRA — superfície escura "joia" para momentos importantes
/// (motorista online, cartão do motorista, instrução de rota, KPI principal).
/// Troca o tema do conteúdo: textos, badges e métricas de dentro se adaptam sozinhos.
class MotoSapphire extends StatelessWidget {
  const MotoSapphire({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? MotoRadius.brLg;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(color: Color(0x330B1B55), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x8C132C86), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -16),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: CustomPaint(
          foregroundPainter: _RimPainter(r, MotoPalette.safira.rim),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-.7, -1.1),
                radius: 1.3,
                colors: [Color(0xFF3F6EF0), MotoRaw.safira800, MotoRaw.safira900],
                stops: [0, .5, 1],
              ),
            ),
            child: Theme(
              data: MotoTheme.safira(),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFFF3F6FF)),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fundo porcelana com aurora azul suave (telas sem mapa). Use como body do Scaffold.
class MotoCanvas extends StatelessWidget {
  const MotoCanvas({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: c.canvas),
      child: Stack(
        children: [
          const Positioned(top: -140, right: -120, child: _Blob(color: Color(0x385B8CFF), size: 380)),
          const Positioned(top: 40, left: -160, child: _Blob(color: Color(0x4D9DBBFF), size: 320)),
          const Positioned(bottom: -160, left: -120, child: _Blob(color: Color(0x1FB8E04A), size: 360)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
