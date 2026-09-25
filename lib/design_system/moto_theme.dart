// =====================================================================
// COBALTO LÍQUIDO · v2 — moto_theme.dart
// O ARQUIVO QUE MAIS ECONOMIZA TEMPO.
//   MaterialApp(theme: MotoTheme.claro())
// Muda sozinho: TextField, ElevatedButton, FilledButton, OutlinedButton,
// TextButton, IconButton, AppBar, Card, BottomSheet, AlertDialog, SnackBar,
// Switch, Checkbox, Radio, Chip, SegmentedButton, ListTile, NavigationBar,
// Progress, DatePicker, Tooltip, Divider e a transição entre telas.
// =====================================================================
import 'package:flutter/material.dart';

import 'moto_motion.dart';
import 'moto_palette.dart';
import 'moto_tokens.dart';

abstract final class MotoTheme {
  /// Tema do app (único).
  static ThemeData claro() => build(MotoPalette.claro);

  /// Usado internamente por MotoSapphire (conteúdo sobre a superfície escura).
  static ThemeData safira() => build(MotoPalette.safira);

  static ThemeData build(MotoPalette c) {
    final scheme = ColorScheme(
      brightness: c.isDark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.textOnAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.textPrimary,
      secondary: c.signal,
      onSecondary: c.textOnSignal,
      tertiary: c.info,
      onTertiary: c.textOnAccent,
      error: c.danger,
      onError: c.textOnAccent,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.bgBase,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.bgRaised,
      surfaceContainerLow: c.glass1,
      surfaceContainer: c.glass2,
      surfaceContainerHigh: c.glass3,
      surfaceContainerHighest: c.bgSunken,
      outline: c.borderDefault,
      outlineVariant: c.borderSubtle,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.bgBase,
      inversePrimary: c.accentBright,
      surfaceTint: Colors.transparent, // M3 tinge superfícies de roxo por padrão — desliga
    );
    final text = _textTheme(c);
    const pill = StadiumBorder();
    final btnText = text.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.16);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      extensions: [c],
      fontFamily: MotoFont.ui,
      textTheme: text,
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      splashFactory: InkRipple.splashFactory,
      splashColor: c.accentSoft,
      highlightColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MotoPageTransitionsBuilder(),
          TargetPlatform.iOS: MotoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: MotoSpace.s2,
        titleTextStyle: text.titleLarge,
      ),

      // Primário: cápsula cobalto. (Gradiente + reflexo + gota = MotoButton.)
      filledButtonTheme: FilledButtonThemeData(style: _primary(c, btnText, pill)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primary(c, btnText, pill)),

      // Secundário: vidro branco com borda fina.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: MotoSpace.s6)),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(btnText),
          backgroundColor: WidgetStatePropertyAll(c.glass2),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textDisabled : c.textPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.focused) || s.contains(WidgetState.hovered)
                  ? c.borderFocus
                  : c.borderDefault,
            ),
          ),
          overlayColor: WidgetStatePropertyAll(c.accentSoft),
          animationDuration: MotoMotion.fast,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          shape: const WidgetStatePropertyAll(pill),
          foregroundColor: WidgetStatePropertyAll(c.textLink),
          textStyle: WidgetStatePropertyAll(btnText.copyWith(fontSize: 15)),
          overlayColor: WidgetStatePropertyAll(c.accentSoft),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(MotoSpace.touchMin)),
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          backgroundColor: WidgetStatePropertyAll(c.glass2),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderSubtle)),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          overlayColor: WidgetStatePropertyAll(c.accentSoft),
        ),
      ),

      // Campos: "vidro afundado" que clareia no foco; label sempre visível.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) || s.contains(WidgetState.error) ? c.bgRaised : c.bgSunken,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: MotoSpace.s4, vertical: 19),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: text.bodyMedium!.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (s) => text.bodyMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.error)
                ? c.danger
                : s.contains(WidgetState.focused)
                ? c.accent
                : c.textSecondary,
          ),
        ),
        hintStyle: text.bodyLarge!.copyWith(color: c.textTertiary),
        helperStyle: text.bodySmall!.copyWith(color: c.textTertiary),
        errorStyle: text.bodySmall!.copyWith(color: c.danger, fontWeight: FontWeight.w500),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? c.accent : c.textTertiary,
        ),
        suffixIconColor: c.textTertiary,
        border: _field(c.borderDefault),
        enabledBorder: _field(c.borderDefault),
        focusedBorder: _field(c.borderFocus, 1.5),
        errorBorder: _field(c.danger),
        focusedErrorBorder: _field(c.danger, 1.5),
        disabledBorder: _field(c.borderSubtle),
      ),

      cardTheme: CardThemeData(
        color: c.bgRaised.withValues(alpha: c.isDark ? .08 : .9),
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: MotoRadius.brLg,
          side: BorderSide(color: c.borderSubtle),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.glass3,
        modalBackgroundColor: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(38, 5),
        shape: const RoundedRectangleBorder(borderRadius: MotoRadius.brSheet),
        modalBarrierColor: c.scrim,
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: MotoRadius.brXl,
          side: BorderSide(color: c.borderSubtle),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.bgRaised,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
        actionTextColor: c.accent,
        insetPadding: const EdgeInsets.fromLTRB(MotoSpace.s4, 0, MotoSpace.s4, MotoSpace.s4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: c.borderSubtle),
        ),
        elevation: 6,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.signal : c.bgSunken),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.borderDefault,
        ),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.bgRaised),
        checkColor: WidgetStatePropertyAll(c.textOnAccent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.glass2,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.borderSubtle),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium!.copyWith(color: c.textSecondary, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: MotoSpace.s3, vertical: 2),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pill),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderSubtle)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.bgRaised : c.bgSunken,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.textPrimary : c.textTertiary,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge!.copyWith(fontSize: 14)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.accent,
        textColor: c.textPrimary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium!.copyWith(color: c.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: MotoSpace.s4, vertical: MotoSpace.s1),
        shape: const RoundedRectangleBorder(borderRadius: MotoRadius.brMd),
        tileColor: c.bgRaised.withValues(alpha: c.isDark ? .06 : .85),
        minVerticalPadding: MotoSpace.s3,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.glass3,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.bgRaised,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall!.copyWith(letterSpacing: 0)),
        elevation: 0,
        height: 72,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accentBright,
        linearTrackColor: c.bgSunken,
        circularTrackColor: c.bgSunken,
        linearMinHeight: 8,
        borderRadius: MotoRadius.brPill,
      ),

      dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: MotoRaw.tinta900, borderRadius: MotoRadius.brSm),
        textStyle: text.bodySmall!.copyWith(color: Colors.white),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: MotoRaw.safira800,
        headerForegroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: MotoRadius.brXl),
      ),
    );
  }

  static ButtonStyle _primary(MotoPalette c, TextStyle t, OutlinedBorder shape) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: MotoSpace.s6)),
    shape: WidgetStatePropertyAll(shape),
    textStyle: WidgetStatePropertyAll(t),
    elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? 0 : 4),
    shadowColor: WidgetStatePropertyAll(c.accent.withValues(alpha: .55)),
    backgroundColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return c.bgSunken;
      if (s.contains(WidgetState.pressed)) return MotoRaw.cobalto700;
      return c.accent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? c.textDisabled : c.textOnAccent,
    ),
    overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .12)),
    animationDuration: MotoMotion.fast,
  );

  static OutlineInputBorder _field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: MotoRadius.brMd,
    borderSide: BorderSide(color: color, width: width),
  );

  static TextTheme _textTheme(MotoPalette c) {
    TextStyle d(double size, double height, double tracking) => TextStyle(
      fontFamily: MotoFont.display,
      fontSize: size,
      height: height,
      letterSpacing: size * tracking,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    );
    TextStyle u(double size, double height, FontWeight w, Color color, [double tracking = 0]) => TextStyle(
      fontFamily: MotoFont.ui,
      fontSize: size,
      height: height,
      fontWeight: w,
      color: color,
      letterSpacing: tracking,
    );

    return TextTheme(
      displayLarge: d(42, 1.02, -0.045), // Display
      displayMedium: d(36, 1.05, -0.042),
      displaySmall: d(32, 1.08, -0.04), // H1
      headlineMedium: d(27, 1.12, -0.035),
      headlineSmall: d(23, 1.18, -0.03), // H2
      titleLarge: d(18, 1.3, -0.03), // título de AppBar
      titleMedium: u(16, 1.3, FontWeight.w600, c.textPrimary, -0.24), // título de item
      titleSmall: u(14, 1.3, FontWeight.w600, c.textPrimary),
      bodyLarge: u(16, 1.5, FontWeight.w400, c.textPrimary, -0.08), // Body
      bodyMedium: u(14, 1.45, FontWeight.w400, c.textSecondary), // Small
      bodySmall: u(12, 1.35, FontWeight.w500, c.textTertiary), // Caption
      labelLarge: u(16, 1, FontWeight.w600, c.textPrimary),
      labelMedium: u(12, 1, FontWeight.w600, c.textSecondary),
      labelSmall: u(11, 1.2, FontWeight.w600, c.textTertiary, 1.76), // Overline (usar .toUpperCase())
    );
  }
}

/// Números (km, min, horários, placa): Sora tabular.
/// `Text('4,8', style: MotoNum.of(context, 22))`
abstract final class MotoNum {
  static TextStyle of(BuildContext context, double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      TextStyle(
        fontFamily: MotoFont.display,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * -0.03,
        height: 1.05,
        color: color ?? context.moto.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
