// =====================================================================
// MotoButton — cápsula de VIDRO LÍQUIDO.
//
//   MotoButton(label: 'Confirmar viagem', onPressed: ...)                 // vidro cobalto
//   MotoButton(label: 'Criar conta', variant: MotoButtonVariant.glass)   // vidro claro
//   MotoButton(label: 'Entrar', loading: true)                           // 3 gotas
//
// Camadas (iguais ao CSS): fundo borrado e saturado (BackdropFilter) →
// corpo tingido translúcido → reflexo em cima → luz que volta por baixo
// (cáustica) → borda de luz nos dois cantos → gota do toque → texto.
// Toque: afunda 3,5% e volta com "gelatina" (mola elástica) + vibração leve.
// =====================================================================
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../moto_palette.dart';
import '../moto_tokens.dart';

enum MotoButtonVariant { primary, glass, ink, danger, signal }

/// Receita de vidro de cada variante.
class _Glass {
  const _Glass(this.top, this.bottom, this.caustic, this.highlight, this.text, this.glow, {this.edge});
  final Color top, bottom, caustic, text;
  final double highlight; // opacidade do reflexo de cima
  final List<BoxShadow> glow;
  final Color? edge; // linha fina externa
}

class MotoButton extends StatefulWidget {
  const MotoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MotoButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.large = true,
    this.expand = true,
    this.glassOpacity = MotoLiquid.opacity,
    this.tintOpacity = MotoLiquid.tintOpacity,
    this.frost = MotoLiquid.frost,
  });

  final String label;
  final VoidCallback? onPressed;
  final MotoButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool large;
  final bool expand;

  /// Transparência do vidro claro (glass/danger). Padrão: MotoLiquid.opacity.
  final double glassOpacity;

  /// Tinta do vidro colorido (primary/signal/ink). Mínimo .78 com texto branco.
  final double tintOpacity;

  /// Desfoque do fundo (sigma). Padrão: MotoLiquid.frost.
  final double frost;

  @override
  State<MotoButton> createState() => _MotoButtonState();
}

class _MotoButtonState extends State<MotoButton> with TickerProviderStateMixin {
  // afunda rápido; volta com mola elástica ("gelatina")
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: MotoMotion.instant,
    reverseDuration: const Duration(milliseconds: 640),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: MotoMotion.pressScale,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut, reverseCurve: MotoMotion.liquidCurve.flipped));
  // gota de luz que se espalha do toque
  late final AnimationController _drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
  Offset _dropAt = Offset.zero;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void dispose() {
    _press.dispose();
    _drop.dispose();
    super.dispose();
  }

  _Glass _recipe(MotoPalette c) {
    final t = widget.tintOpacity.clamp(0.0, 1.0);
    final tb = (t + .08).clamp(0.0, 1.0);
    final o = widget.glassOpacity.clamp(0.0, 1.0);
    final ot = (o * 1.6).clamp(0.0, 1.0);
    return switch (widget.variant) {
      MotoButtonVariant.primary => _Glass(
        const Color(0xFF2860F8).withValues(alpha: t),
        const Color(0xFF163AC8).withValues(alpha: tb),
        const Color(0x8C96BEFF),
        .34,
        Colors.white,
        const [
          BoxShadow(color: Color(0x1F0B1B55), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x8C1F4FE0), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -10),
        ],
        edge: const Color(0x59132CA0),
      ),
      MotoButtonVariant.glass => _Glass(
        Colors.white.withValues(alpha: ot),
        Colors.white.withValues(alpha: o * .6),
        const Color(0x00FFFFFF),
        .9,
        MotoRaw.tinta900,
        const [
          BoxShadow(color: Color(0x1A0B1B55), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x470B1B55), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -10),
        ],
      ),
      MotoButtonVariant.ink => _Glass(
        const Color(0xFF142248).withValues(alpha: (t - .02).clamp(0.0, 1.0)),
        const Color(0xFF081028).withValues(alpha: tb),
        const Color(0x597896E6),
        .22,
        Colors.white,
        const [BoxShadow(color: Color(0xA60A1633), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -12)],
        edge: const Color(0x80000000),
      ),
      MotoButtonVariant.danger => _Glass(
        Colors.white.withValues(alpha: ot),
        const Color(0xFFFFF0F3).withValues(alpha: o),
        const Color(0x40FF8CA0),
        .9,
        c.danger,
        const [BoxShadow(color: Color(0x4DBE2A45), blurRadius: 22, offset: Offset(0, 10), spreadRadius: -12)],
        edge: const Color(0x2EBE2A45),
      ),
      MotoButtonVariant.signal => _Glass(
        const Color(0xFFBEE448).withValues(alpha: t),
        const Color(0xFF86B612).withValues(alpha: tb),
        const Color(0xB3ECFFAA),
        .5,
        const Color(0xFF1C2A00),
        const [BoxShadow(color: Color(0x9978AA0A), blurRadius: 22, offset: Offset(0, 10), spreadRadius: -10)],
        edge: const Color(0x66507800),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final disabled = widget.onPressed == null;
    final g = disabled
        ? const _Glass(Color(0x80FFFFFF), Color(0x8CEAF0FA), Color(0x00FFFFFF), .9, MotoRaw.tinta300, [])
        : _recipe(c);
    final h = widget.large ? 58.0 : 52.0;

    final content = widget.loading
        ? _Drops(color: g.text == MotoRaw.tinta900 ? c.accent : g.text)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: g.text),
                const SizedBox(width: MotoSpace.s2),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    fontFamily: MotoFont.ui,
                    fontSize: widget.large ? 17 : 16,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.16,
                    color: g.text,
                    shadows: g.text == Colors.white
                        ? const [Shadow(color: Color(0x66081870), blurRadius: 1, offset: Offset(0, 1))]
                        : null,
                  ),
                ),
              ),
            ],
          );

    final glass = ClipRRect(
      borderRadius: MotoRadius.brPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.frost, sigmaY: widget.frost),
        child: CustomPaint(
          foregroundPainter: _RimPainter(disabled ? .5 : 1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // corpo tingido translúcido
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [g.top, g.bottom],
                    ),
                  ),
                ),
              ),
              // cáustica: luz que volta por baixo
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 1.45),
                      radius: 1.1,
                      colors: [g.caustic, g.caustic.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // reflexo em cima
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.35),
                      radius: 1.0,
                      colors: [
                        Colors.white.withValues(alpha: g.highlight),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // espessura: sombra interna na base
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * .45,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: disabled ? 0 : .08),
                      ],
                    ),
                  ),
                ),
              ),
              // gota do toque
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _drop,
                  builder: (context, _) => _drop.isAnimating
                      ? CustomPaint(painter: _DropPainter(_dropAt, _drop.value))
                      : const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MotoSpace.s6),
                child: AnimatedSwitcher(
                  duration: MotoMotion.fast,
                  child: KeyedSubtree(key: ValueKey(widget.loading), child: content),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled
            ? (d) {
                _dropAt = d.localPosition;
                _press.forward();
                _drop.forward(from: 0);
              }
            : null,
        onTapUp: _enabled ? (_) => _press.reverse() : null,
        onTapCancel: () => _press.reverse(),
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed?.call();
              }
            : null,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            height: h,
            width: widget.expand ? double.infinity : null,
            decoration: BoxDecoration(
              borderRadius: MotoRadius.brPill,
              boxShadow: g.glow,
              border: switch (g.edge) {
                final e? => Border.all(color: e, width: .5),
                null => null,
              },
            ),
            child: glass,
          ),
        ),
      ),
    );
  }
}

/// Borda de luz: forte no canto de cima-esquerda e de baixo-direita (lente).
class _RimPainter extends CustomPainter {
  _RimPainter(this.strength);
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .98 * strength),
            Colors.white.withValues(alpha: .22 * strength),
            Colors.white.withValues(alpha: .06 * strength),
            Colors.white.withValues(alpha: .7 * strength),
          ],
          stops: const [0, .32, .58, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.strength != strength;
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.at, this.t);
  final Offset at;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final r = s.longestSide * 1.1 * MotoMotion.easeOut.transform(t);
    if (r <= 0) return;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .5 * (1 - t)),
            Colors.white.withValues(alpha: .16 * (1 - t)),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.t != t;
}

/// Carregando: 3 gotas que sobem em onda (no lugar do spinner).
class _Drops extends StatefulWidget {
  const _Drops({required this.color});
  final Color color;

  @override
  State<_Drops> createState() => _DropsState();
}

class _DropsState extends State<_Drops> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando',
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value - i * .12) % 1.0;
          final lift = t < .4
              ? MotoMotion.easeInOut.transform(t / .4)
              : MotoMotion.easeInOut.transform((1 - (t - .4) / .6).clamp(0, 1));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.translate(
              offset: Offset(0, 1.5 - 3 * lift),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: .55 + .45 * lift),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}
