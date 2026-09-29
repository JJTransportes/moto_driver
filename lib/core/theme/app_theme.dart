import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF3A55BD);
  static const gradientStart = Color(0xFF54ABF2);
  static const gradientEnd = Color(0xFF3A55BD);
  static const white = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFBBBBBB);

  /// Verde de item cumprido no checklist "estilo gov.br" (política de
  /// senha) — item começa neutro e vira verde ao ser satisfeito.
  static const success = Color(0xFF2E7D32);
}

class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      textTheme: GoogleFonts.robotoFlexTextTheme(),
      useMaterial3: true,
    );
  }
}
