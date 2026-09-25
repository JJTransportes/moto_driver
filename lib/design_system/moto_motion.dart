// =====================================================================
// COBALTO LÍQUIDO — moto_motion.dart
// Transição de tela, entrada em cascata e escala de toque.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'moto_palette.dart';
import 'moto_tokens.dart';

/// Transição padrão de rota: nova tela sobe 14px e aparece (380ms),
/// tela antiga recua levemente. Já registrada no MotoTheme.
class MotoPageTransitionsBuilder extends PageTransitionsBuilder {
  const MotoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(parent: animation, curve: MotoMotion.easeOut, reverseCurve: MotoMotion.easeIn);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: MotoMotion.easeOut);
    return FadeTransition(
      opacity: inCurve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(inCurve),
        child: ScaleTransition(scale: Tween(begin: 1.0, end: .97).animate(outCurve), child: child),
      ),
    );
  }
}

/// Entrada em cascata: envolva cada item de uma lista/coluna.
/// `MotoEnter(index: i, child: ...)` → atraso de 40ms × i (máx. 6).
class MotoEnter extends StatefulWidget {
  const MotoEnter({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<MotoEnter> createState() => _MotoEnterState();
}

class _MotoEnterState extends State<MotoEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: MotoMotion.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: MotoMotion.easeOut);

  @override
  void initState() {
    super.initState();
    final reduce = SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduce) {
      _c.value = 1;
    } else {
      Future.delayed(MotoMotion.stagger * widget.index.clamp(0, 6), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.translate(offset: Offset(0, 14 * (1 - _a.value)), child: child),
      child: widget.child,
    ),
  );
}

/// Encolhe 3% enquanto pressionado. Envolva qualquer coisa tocável
/// (cards, itens de lista). Os botões do sistema já fazem isso.
class MotoPressable extends StatefulWidget {
  const MotoPressable({super.key, required this.child, this.onTap, this.scale = MotoMotion.pressScale});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<MotoPressable> createState() => _MotoPressableState();
}

class _MotoPressableState extends State<MotoPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: _down ? MotoMotion.instant : MotoMotion.base,
      curve: _down ? Curves.easeOut : MotoMotion.spring,
      child: widget.child,
    ),
  );
}

/// Ponto de origem de um widget na tela — use com [showMotoDialog] para o
/// diálogo "nascer" do botão tocado:
///   showMotoDialog(context, origin: motoOriginOf(buttonContext), builder: ...)
Alignment motoOriginOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  final size = MediaQuery.sizeOf(context);
  if (box == null || !box.hasSize || size.isEmpty) return Alignment.center;
  final c = box.localToGlobal(box.size.center(Offset.zero));
  return Alignment(c.dx / size.width * 2 - 1, c.dy / size.height * 2 - 1);
}

/// Diálogo que cresce a partir de [origin] com mola e volta para lá ao fechar.
Future<T?> showMotoDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Alignment origin = Alignment.center,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Fechar',
    barrierColor: context.moto.scrim,
    transitionDuration: MotoMotion.slow,
    pageBuilder: (ctx, animation, secondary) => SafeArea(child: Center(child: builder(ctx))),
    transitionBuilder: (ctx, a, secondary, child) {
      final curve = CurvedAnimation(parent: a, curve: MotoMotion.spring, reverseCurve: MotoMotion.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: const Interval(0, .6)),
        child: ScaleTransition(scale: Tween(begin: .3, end: 1.0).animate(curve), alignment: origin, child: child),
      );
    },
  );
}

/// Troca de conteúdo com direção (abas, passos): o novo entra pelo lado para
/// onde o usuário foi. Mude [index] a cada troca.
class MotoDirectionalSwitcher extends StatefulWidget {
  const MotoDirectionalSwitcher({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<MotoDirectionalSwitcher> createState() => _MotoDirectionalSwitcherState();
}

class _MotoDirectionalSwitcherState extends State<MotoDirectionalSwitcher> {
  int _dir = 1;

  @override
  void didUpdateWidget(MotoDirectionalSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _dir = widget.index > old.index ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MotoMotion.slow,
    reverseDuration: MotoMotion.fast,
    switchInCurve: MotoMotion.easeOut,
    switchOutCurve: MotoMotion.easeIn,
    transitionBuilder: (child, a) {
      final incoming = child.key == ValueKey(widget.index);
      final dx = (incoming ? .08 : -.08) * _dir;
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a),
          child: child,
        ),
      );
    },
    child: KeyedSubtree(key: ValueKey(widget.index), child: widget.child),
  );
}
