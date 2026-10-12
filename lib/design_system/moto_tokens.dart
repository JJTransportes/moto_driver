// =====================================================================
// COBALTO LÍQUIDO · v2 "Porcelana" — moto_tokens.dart
// Espelho 1:1 de 2-web/tokens.css. Mudou lá, muda aqui.
// Nenhuma tela usa Color(0x...) direto: sempre context.moto.<papel>.
// =====================================================================
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Paleta bruta. Nas telas use os papéis de [MotoPalette] (context.moto).
abstract final class MotoRaw {
  static const porcelana50 = Color(0xFFFBFCFE);
  static const porcelana100 = Color(0xFFF4F7FC); // fundo
  static const porcelana200 = Color(0xFFEAF0FA);
  static const porcelana300 = Color(0xFFDCE5F5);
  static const tinta900 = Color(0xFF0A1633); // texto principal
  static const tinta700 = Color(0xFF34425F);
  static const tinta500 = Color(0xFF5A6784);
  static const tinta300 = Color(0xFFA2ADC4);
  static const cobalto300 = Color(0xFF9DBBFF);
  static const cobalto400 = Color(0xFF5B8CFF);
  static const cobalto500 = Color(0xFF2F6BFF);
  static const cobalto600 = Color(0xFF1F4FE0);
  static const cobalto700 = Color(0xFF1A3FB8);
  static const safira800 = Color(0xFF132C86);
  static const safira900 = Color(0xFF0B1B55);
  static const marcaAzul = Color(0xFF2B4A9B);
  static const sinal300 = Color(0xFFD6F07A);
  static const sinal400 = Color(0xFFB8E04A);
  static const sinal500 = Color(0xFF95C11F); // limão do logo
  static const sinal700 = Color(0xFF4A6E00); // limão legível em texto
  static const ambar500 = Color(0xFFF2A93B);
  static const ambar700 = Color(0xFF945800);
  static const coral400 = Color(0xFFFF7A8C);
  static const coral600 = Color(0xFFBE2A45);
}

/// Espaço — grid de 4.
abstract final class MotoSpace {
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 20, s6 = 24;
  static const double s8 = 32, s10 = 40, s12 = 48, s16 = 64;
  static const double gutter = 20; // margem lateral das telas
  static const double touchMin = 48; // alvo mínimo de toque
}

/// Raio — concêntrico (interno = externo − padding).
abstract final class MotoRadius {
  static const double xs = 8, sm = 12, md = 18, lg = 26, xl = 34, pill = 999;
  static const brXs = BorderRadius.all(Radius.circular(xs));
  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
  static const brXl = BorderRadius.all(Radius.circular(xl));
  static const brPill = BorderRadius.all(Radius.circular(pill));
  static const brSheet = BorderRadius.vertical(top: Radius.circular(xl));
}

/// Movimento. Mesmos valores do CSS.
abstract final class MotoMotion {
  static const instant = Duration(milliseconds: 90); // afundar ao tocar
  static const fast = Duration(milliseconds: 180); // cor, ícone
  static const base = Duration(milliseconds: 280); // troca de estado
  static const slow = Duration(milliseconds: 460); // sheet, tela, pílula
  static const liquid = Duration(milliseconds: 720); // sucesso, revelar
  static const stagger = Duration(milliseconds: 50); // atraso entre itens

  static const easeOut = Cubic(0.22, 1, 0.36, 1); // entrada
  static const easeIn = Cubic(0.55, 0, 0.75, 0.06); // saída
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
  static const spring = Cubic(0.34, 1.56, 0.64, 1); // encaixe com leve rebote
  static const Curve liquidCurve = ElasticOutCurve(0.9); // "gelatina" ao soltar

  static const pressScale = 0.965;
}

/// Tipografia. Famílias declaradas no pubspec.yaml (ver 3-flutter/README.md).
abstract final class MotoFont {
  static const display = 'Sora'; // títulos e números
  static const ui = 'PlusJakartaSans'; // interface e texto
}

/// VIDRO LÍQUIDO (estilo iOS) — mesmos controles do CSS (--lg-*).
/// Mude aqui para deixar TODOS os MotoButton mais ou menos transparentes,
/// ou passe `glassOpacity` / `tintOpacity` / `frost` num botão específico.
abstract final class MotoLiquid {
  /// Branco do vidro claro: 0 = invisível · .16 padrão (iOS) · .4 leitoso.
  static const double opacity = .16;

  /// Tinta do vidro azul/limão/fumê. Mínimo .78 para o texto branco passar AA.
  static const double tintOpacity = .82;

  /// Desfoque do fundo (sigma): 0–4 transparente como iOS · 10+ fosco.
  static const double frost = 3;
}

/// Sigma do blur do vidro (mais baixo que o CSS: BackdropFilter é caro no Android).
abstract final class MotoGlassSpec {
  static const double blur1 = 7, blur2 = 11, blur3 = 17;
}
