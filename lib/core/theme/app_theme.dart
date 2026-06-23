import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF3A55BD);
  static const gradientStart = Color(0xFF54ABF2);
  static const gradientEnd = Color(0xFF3A55BD);
  static const white = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFBBBBBB);
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
