// =====================================================================
// Peças de viagem
//   MotoRoute      origem → destino
//   MotoMetrics    4,8 km · 8 min · 17:18
//   MotoAvatar     iniciais/foto + ponto online
//   MotoPlate      placa Mercosul estilizada
//   MotoTile       ícone em "pastilha" de porcelana
//   MotoSearchBar  "Pra onde vamos?" (home do passageiro)
// =====================================================================
import 'package:flutter/material.dart';

import '../moto_palette.dart';
import '../moto_theme.dart';
import '../moto_tokens.dart';
import 'moto_status.dart';

typedef Stop = (String title, String subtitle);

class MotoRoute extends StatelessWidget {
  const MotoRoute({super.key, required this.from, required this.to});
  final Stop from, to;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final t = Theme.of(context).textTheme;
    Widget stop(Stop s) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.$1, style: t.titleMedium),
        const SizedBox(height: 2),
        Text(s.$2, style: t.bodyMedium!.copyWith(color: c.textTertiary)),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.bgBase,
                    border: Border.all(color: c.isDark ? MotoRaw.cobalto300 : c.accentBright, width: 3.5),
                    boxShadow: [BoxShadow(color: c.accentSoft, spreadRadius: 4)],
                  ),
                ),
                Expanded(
                  child: CustomPaint(size: const Size(2, double.infinity), painter: _Dashed(c.borderStrong)),
                ),
                Transform.rotate(
                  angle: .785,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: c.signalLiquid,
                      borderRadius: BorderRadius.circular(3.5),
                      boxShadow: [BoxShadow(color: c.signalSoft, spreadRadius: 3)],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
          const SizedBox(width: MotoSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stop(from),
                const SizedBox(height: MotoSpace.s4),
                stop(to),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dashed extends CustomPainter {
  _Dashed(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (double y = 5; y < s.height - 5; y += 8) {
      canvas.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}

/// (valor, unidade, legenda)
typedef Metric = (String value, String unit, String caption);

class MotoMetrics extends StatelessWidget {
  const MotoMetrics({super.key, required this.items});
  final List<Metric> items;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x0FFFFFFF) : const Color(0x09132C86),
        borderRadius: MotoRadius.brMd,
        border: Border.all(color: c.borderSubtle),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: c.borderSubtle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MotoSpace.s4, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: items[i].$1, style: MotoNum.of(context, 22)),
                            if (items[i].$2.isNotEmpty)
                              TextSpan(
                                text: ' ${items[i].$2}',
                                style: TextStyle(
                                  fontFamily: MotoFont.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: c.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(items[i].$3, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MotoAvatar extends StatelessWidget {
  const MotoAvatar({super.key, required this.initials, this.size = 48, this.online = false, this.image});
  final String initials;
  final double size;
  final bool online;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final ring = size >= 96 ? 5.0 : 3.0;
    final dot = size >= 96 ? 22.0 : 14.0;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MotoRaw.cobalto400, MotoRaw.cobalto500, MotoRaw.safira900],
                stops: [0, .35, 1],
              ),
              image: switch (image) {
                final i? => DecorationImage(image: i, fit: BoxFit.cover),
                null => null,
              },
              boxShadow: [
                BoxShadow(color: c.isDark ? const Color(0x24FFFFFF) : Colors.white, spreadRadius: ring),
                if (!c.isDark) BoxShadow(color: c.borderDefault, spreadRadius: ring + 1),
                BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6),
              ],
            ),
            alignment: Alignment.center,
            child: image == null
                ? Text(
                    initials,
                    style: TextStyle(
                      fontFamily: MotoFont.display,
                      fontWeight: FontWeight.w600,
                      fontSize: size * .34,
                      letterSpacing: size * -.01,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          if (online)
            Positioned(
              right: size >= 96 ? 4 : -1,
              bottom: size >= 96 ? 4 : -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  gradient: c.signalLiquid,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.isDark ? MotoRaw.safira800 : Colors.white, width: size >= 96 ? 4 : 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placa Mercosul estilizada — é o que o passageiro procura na rua.
class MotoPlate extends StatelessWidget {
  const MotoPlate(this.plate, {super.key});
  final String plate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFEEF2FA)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x1F132C86)),
      boxShadow: const [BoxShadow(color: Color(0x40132C86), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'BRASIL',
          style: TextStyle(
            fontFamily: MotoFont.ui,
            fontSize: 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: MotoRaw.cobalto600,
          ),
        ),
        const SizedBox(height: 3),
        Text(plate, style: MotoNum.of(context, 15, color: MotoRaw.tinta900).copyWith(letterSpacing: .9)),
      ],
    ),
  );
}

/// Ícone em "pastilha" de porcelana (listas, cabeçalhos de card).
class MotoTile extends StatelessWidget {
  const MotoTile({super.key, required this.icon, this.tone = MotoTone.info, this.accent = false, this.size = 46});
  final IconData icon;
  final MotoTone tone;

  /// true = pastilha cobalto líquida (ícone branco).
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    final (fg, top, bottom) = accent
        ? (Colors.white, const Color(0xFF3B74FF), MotoRaw.cobalto700)
        : c.isDark
        ? (MotoRaw.cobalto300, const Color(0x1FFFFFFF), const Color(0x0FFFFFFF))
        : switch (tone) {
            MotoTone.success => (c.success, const Color(0xFFFCFFF3), const Color(0xFFE9F4CC)),
            MotoTone.danger => (c.danger, const Color(0xFFFFF8F9), const Color(0xFFFCE3E7)),
            MotoTone.warning => (c.warning, const Color(0xFFFFFBF3), const Color(0xFFFCEFD6)),
            _ => (c.accent, Colors.white, const Color(0xFFE7EEFC)),
          };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        border: Border.all(color: fg.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: .5), blurRadius: 8, offset: const Offset(0, 3), spreadRadius: -4),
        ],
      ),
      child: Icon(icon, color: fg, size: size * .48),
    );
  }
}

/// Busca "Pra onde vamos?" — cápsula branca com orbe cobalto.
class MotoSearchBar extends StatelessWidget {
  const MotoSearchBar({super.key, required this.title, this.hint, this.trailing, required this.onTap});
  final String title;
  final String? hint;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.moto;
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: c.borderSubtle)),
        elevation: 6,
        shadowColor: c.shadow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: c.accentLiquid),
                  child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 17)),
                      if (hint != null) ...[
                        const SizedBox(height: 3),
                        Text(hint!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                // ignore: use_null_aware_elements (mantém compatível com Dart < 3.8)
                if (trailing case final t?) t,
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
