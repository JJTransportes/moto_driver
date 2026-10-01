// =====================================================================
// COBALTO LÍQUIDO · v2 — moto_palette.dart
// Papéis de cor via ThemeExtension. Uso: final c = context.moto;
// Duas paletas: [claro] (padrão) e [safira] (dentro de MotoSapphire — o
// widget troca a paleta sozinho, igual ao CSS .mo-sapphire).
// =====================================================================
import 'package:flutter/material.dart';

import 'moto_tokens.dart';

@immutable
class MotoPalette extends ThemeExtension<MotoPalette> {
  const MotoPalette({
    required this.isDark,
    required this.bgBase,
    required this.bgRaised,
    required this.bgSunken,
    required this.canvas,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textLink,
    required this.textOnAccent,
    required this.textOnSignal,
    required this.accent,
    required this.accentBright,
    required this.accentSoft,
    required this.accentLiquid,
    required this.signal,
    required this.signalText,
    required this.signalSoft,
    required this.signalLiquid,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.glass1,
    required this.glass2,
    required this.glass3,
    required this.rim,
    required this.highlight,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.borderFocus,
    required this.shadow,
    required this.scrim,
  });

  final bool isDark;
  final Color bgBase, bgRaised, bgSunken;

  /// Fundo porcelana com aurora (telas sem mapa) — use via MotoCanvas.
  final Gradient canvas;
  final Color textPrimary, textSecondary, textTertiary, textDisabled, textLink, textOnAccent, textOnSignal;
  final Color accent, accentBright, accentSoft;

  /// Cápsula primária: luz de cima, corpo cobalto, base safira.
  final Gradient accentLiquid;

  /// Limão do logo — RESERVADO a "vivo": online, ao vivo, sucesso.
  final Color signal, signalText, signalSoft;
  final Gradient signalLiquid;
  final Color success, successSoft, warning, warningSoft, danger, dangerSoft, info, infoSoft;
  final Color glass1, glass2, glass3;

  /// Borda de luz do vidro (gradiente: forte no topo-esquerda, azul na base).
  final Gradient rim;
  final Color highlight;
  final Color borderSubtle, borderDefault, borderStrong, borderFocus;
  final Color shadow, scrim;

  static const _accentLiquid = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B74FF), Color(0xFF2459F0), MotoRaw.cobalto700],
    stops: [0, .42, 1],
  );
  static const _signalLiquid = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC9EA5C), Color(0xFFA8D22E), Color(0xFF86B116)],
    stops: [0, .5, 1],
  );

  // ------------------------------------------------------------ CLARO
  static const claro = MotoPalette(
    isDark: false,
    bgBase: MotoRaw.porcelana100,
    bgRaised: Color(0xFFFFFFFF),
    bgSunken: MotoRaw.porcelana200,
    canvas: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFFDDE7FF), Color(0xFFF6F8FD), Color(0xFFF1F4FB), Color(0xFFEEF4E4)],
      stops: [0, .35, .75, 1],
    ),
    textPrimary: MotoRaw.tinta900,
    textSecondary: MotoRaw.tinta700,
    textTertiary: MotoRaw.tinta500,
    textDisabled: MotoRaw.tinta300,
    textLink: MotoRaw.cobalto600,
    textOnAccent: Color(0xFFFFFFFF),
    textOnSignal: Color(0xFF1C2A00),
    accent: MotoRaw.cobalto600,
    accentBright: MotoRaw.cobalto500,
    accentSoft: Color(0x1A2F6BFF),
    accentLiquid: _accentLiquid,
    signal: MotoRaw.sinal500,
    signalText: MotoRaw.sinal700,
    signalSoft: Color(0x2495C11F),
    signalLiquid: _signalLiquid,
    success: MotoRaw.sinal700,
    successSoft: Color(0x2695C11F),
    warning: MotoRaw.ambar700,
    warningSoft: Color(0x29F2A93B),
    danger: MotoRaw.coral600,
    dangerSoft: Color(0x17BE2A45),
    info: MotoRaw.cobalto600,
    infoSoft: Color(0x1A2F6BFF),
    glass1: Color(0x57FFFFFF), // 34%
    glass2: Color(0x8FFFFFFF), // 56%
    glass3: Color(0xB3FFFFFF), // 70%
    rim: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0x8CFFFFFF), Color(0x1FFFFFFF), Color(0x599DBBFF)],
      stops: [0, .22, .5, 1],
    ),
    highlight: Color(0xF2FFFFFF),
    borderSubtle: Color(0x12132C86),
    borderDefault: Color(0x1F132C86),
    borderStrong: Color(0x38132C86),
    borderFocus: MotoRaw.cobalto500,
    shadow: Color(0x38132C86),
    scrim: Color(0x520A1633),
  );

  // ------------------------------------------------------------ SAFIRA
  /// Paleta aplicada automaticamente dentro de MotoSapphire.
  static const safira = MotoPalette(
    isDark: true,
    bgBase: MotoRaw.safira900,
    bgRaised: MotoRaw.safira800,
    bgSunken: Color(0x14FFFFFF),
    canvas: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [MotoRaw.cobalto700, MotoRaw.safira800, MotoRaw.safira900],
      stops: [0, .45, 1],
    ),
    textPrimary: Color(0xFFF3F6FF),
    textSecondary: Color(0xFFB7C4E4),
    textTertiary: Color(0xFF9DAED8),
    textDisabled: Color(0xFF6474A0),
    textLink: MotoRaw.cobalto300,
    textOnAccent: Color(0xFFFFFFFF),
    textOnSignal: Color(0xFF1C2A00),
    accent: MotoRaw.cobalto300,
    accentBright: MotoRaw.cobalto400,
    accentSoft: Color(0x299DBBFF),
    accentLiquid: _accentLiquid,
    signal: MotoRaw.sinal400,
    signalText: MotoRaw.sinal400,
    signalSoft: Color(0x29B8E04A),
    signalLiquid: _signalLiquid,
    success: MotoRaw.sinal400,
    successSoft: Color(0x29B8E04A),
    warning: Color(0xFFFFC46B),
    warningSoft: Color(0x29FFC46B),
    danger: MotoRaw.coral400,
    dangerSoft: Color(0x29FF7A8C),
    info: MotoRaw.cobalto300,
    infoSoft: Color(0x299DBBFF),
    glass1: Color(0x12FFFFFF),
    glass2: Color(0x1AFFFFFF),
    glass3: Color(0x24FFFFFF),
    rim: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xB3BED2FF), Color(0x14BED2FF), Color(0x595B8CFF)],
      stops: [0, .4, 1],
    ),
    highlight: Color(0x38FFFFFF),
    borderSubtle: Color(0x29BED2FF),
    borderDefault: Color(0x3DBED2FF),
    borderStrong: Color(0x61BED2FF),
    borderFocus: MotoRaw.cobalto300,
    shadow: Color(0x8C0B1B55),
    scrim: Color(0x520A1633),
  );

  @override
  MotoPalette copyWith() => this; // paleta fixa

  @override
  MotoPalette lerp(MotoPalette? other, double t) => (other == null || t < .5) ? this : other;
}

extension MotoContext on BuildContext {
  /// Atalho: `context.moto.accent`
  MotoPalette get moto => Theme.of(this).extension<MotoPalette>() ?? MotoPalette.claro;
}
