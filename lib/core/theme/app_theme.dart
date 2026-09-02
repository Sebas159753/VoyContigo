import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema visual de VoyContigo, alineado al manual de marca:
///  - Paleta monocromática morada: #422c6d · #7659af · #9b85cb · #d0bef4
///  - Tipografía: Fjalla One (títulos), Oswald (subtítulos), Public Sans (párrafo)
class AppTheme {
  // ---------------------------------------------------------------------------
  // Paleta de marca (manual "Voy Contigo")
  // ---------------------------------------------------------------------------
  static const Color purpleDarkest = Color(0xFF422c6d); // color principal
  static const Color purpleDark = Color(0xFF7659af);
  static const Color purpleMedium = Color(0xFF9b85cb);
  static const Color purpleLightest = Color(0xFFd0bef4);

  // Neutros
  static const Color pureWhite = Colors.white;
  static const Color pureBlack = Color(0xFF15121C); // negro con un matiz morado
  static const Color ink = Color(0xFF1F1B29); // texto principal
  static const Color inkMuted = Color(0xFF6B6577); // texto secundario
  static const Color subtleGray = Color(0xFFF5F3FA); // superficie suave (tinte morado)
  static const Color outline = Color(0xFFE6E1F0);
  static const Color standardRed = Color(0xFFE23D4B);
  static const Color successGreen = Color(0xFF2E9E6B);

  // Tokens semánticos
  static const Color primaryNeonColor = purpleDarkest;
  static const Color darkBackground = pureWhite;
  static const Color cardColor = pureWhite;
  static const Color secondaryColor = pureBlack;
  static const Color errorColor = standardRed;
  static const Color highlightColor = subtleGray;

  // Aliases heredados (mantienen compatibilidad con pantallas existentes).
  // Nota: pese al nombre, ambos son morados de marca.
  static const Color tommyNavy = purpleDarkest;
  static const Color tommyRed = purpleDark;
  static const Color driverNavy = purpleMedium;

  /// Color primario según el rol activo en el tablero.
  static Color primaryForMode(String mode) =>
      mode == 'conductor' ? purpleDark : purpleDarkest;

  // ---------------------------------------------------------------------------
  // Helpers tipográficos de marca — fuente única de verdad.
  // Reemplazan a los GoogleFonts.inter(...) dispersos por la app.
  // ---------------------------------------------------------------------------

  /// TÍTULOS — Fjalla One (display / headline / títulos grandes).
  static TextStyle titleFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.fjallaOne(
      fontSize: fontSize,
      // Fjalla One es de un solo peso; mantenemos w400/w700 nominal.
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? ink,
      letterSpacing: letterSpacing ?? -0.2,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  /// SUBTÍTULOS / etiquetas / botones — Oswald (condensada).
  static TextStyle subtitleFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  /// PÁRRAFO / cuerpo — Public Sans.
  static TextStyle bodyFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.publicSans(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  // ---------------------------------------------------------------------------
  // TextTheme de marca
  // ---------------------------------------------------------------------------
  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.publicSansTextTheme();
    return base.copyWith(
      // Títulos → Fjalla One
      displayLarge: titleFont(fontSize: 44, letterSpacing: -1.0, color: ink),
      displayMedium: titleFont(fontSize: 34, letterSpacing: -0.8, color: ink),
      displaySmall: titleFont(fontSize: 28, letterSpacing: -0.5, color: ink),
      headlineMedium: titleFont(fontSize: 24, letterSpacing: -0.5, color: ink),
      headlineSmall: titleFont(fontSize: 20, letterSpacing: -0.3, color: ink),
      titleLarge: titleFont(fontSize: 18, color: ink),
      // Subtítulos / etiquetas → Oswald
      titleMedium: subtitleFont(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      titleSmall: subtitleFont(fontSize: 13, fontWeight: FontWeight.w600, color: inkMuted, letterSpacing: 0.4),
      labelLarge: subtitleFont(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
      labelMedium: subtitleFont(fontSize: 12, fontWeight: FontWeight.w500, color: inkMuted, letterSpacing: 0.3),
      // Cuerpo → Public Sans
      bodyLarge: bodyFont(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
      bodyMedium: bodyFont(fontSize: 14, fontWeight: FontWeight.w400, color: ink),
      bodySmall: bodyFont(fontSize: 12, fontWeight: FontWeight.w400, color: inkMuted),
    );
  }

  // ---------------------------------------------------------------------------
  // ThemeData principal
  // ---------------------------------------------------------------------------
  static ThemeData getTheme(String mode) {
    final Color dynamicPrimary = primaryForMode(mode);
    const Color onPrimary = pureWhite;

    final colorScheme = ColorScheme.light(
      primary: dynamicPrimary,
      onPrimary: onPrimary,
      primaryContainer: purpleLightest,
      onPrimaryContainer: purpleDarkest,
      secondary: purpleMedium,
      onSecondary: pureWhite,
      surface: cardColor,
      onSurface: ink,
      surfaceContainerHighest: subtleGray,
      error: errorColor,
      outline: outline,
    );

    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: pureWhite,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: dynamicPrimary,
      splashColor: dynamicPrimary.withOpacity(0.08),
      highlightColor: dynamicPrimary.withOpacity(0.04),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: pureWhite,
        surfaceTintColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: const IconThemeData(color: ink),
        titleTextStyle: titleFont(fontSize: 18, color: ink),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dynamicPrimary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: dynamicPrimary.withOpacity(0.4),
          disabledForegroundColor: pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: subtitleFont(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dynamicPrimary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: subtitleFont(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dynamicPrimary,
          side: BorderSide(color: dynamicPrimary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: subtitleFont(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dynamicPrimary,
          textStyle: subtitleFont(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dynamicPrimary,
        foregroundColor: pureWhite,
        elevation: 2,
        extendedTextStyle: subtitleFont(fontSize: 15, fontWeight: FontWeight.w600, color: pureWhite),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtleGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dynamicPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: bodyFont(color: inkMuted),
        hintStyle: bodyFont(color: inkMuted),
        prefixIconColor: inkMuted,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: subtleGray,
        selectedColor: dynamicPrimary.withOpacity(0.14),
        checkmarkColor: dynamicPrimary,
        labelStyle: bodyFont(fontSize: 13, color: ink),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? dynamicPrimary : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? dynamicPrimary.withOpacity(0.4) : outline),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? dynamicPrimary : inkMuted),
      ),

      // Pickers de fecha/hora alineados a la marca (antes se forzaban a negro).
      datePickerTheme: DatePickerThemeData(
        backgroundColor: pureWhite,
        headerBackgroundColor: dynamicPrimary,
        headerForegroundColor: pureWhite,
        todayForegroundColor: WidgetStateProperty.all(dynamicPrimary),
        todayBorder: BorderSide(color: dynamicPrimary),
        dayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? pureWhite : ink),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? dynamicPrimary : null),
        yearForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? pureWhite : ink),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? dynamicPrimary : null),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: pureWhite,
        hourMinuteColor: subtleGray,
        hourMinuteTextColor: ink,
        dialHandColor: dynamicPrimary,
        dialBackgroundColor: subtleGray,
        entryModeIconColor: dynamicPrimary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: titleFont(fontSize: 20, color: ink),
        contentTextStyle: bodyFont(fontSize: 14, color: inkMuted),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: bodyFont(fontSize: 14, fontWeight: FontWeight.w500, color: pureWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: dynamicPrimary,
        unselectedLabelColor: inkMuted,
        indicatorColor: dynamicPrimary,
        labelStyle: subtitleFont(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: subtitleFont(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: pureWhite,
        indicatorColor: dynamicPrimary.withOpacity(0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return subtitleFont(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? dynamicPrimary : inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? dynamicPrimary : inkMuted);
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: pureWhite,
        selectedItemColor: dynamicPrimary,
        unselectedItemColor: inkMuted,
        selectedLabelStyle: subtitleFont(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: subtitleFont(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
