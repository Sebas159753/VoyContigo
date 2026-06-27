import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Minimalist Palette
  static const Color pureWhite = Colors.white;
  static const Color pureBlack = Color(0xFF111111);
  static const Color electricBlue = Color(0xFF0057FF);
  static const Color subtleGray = Color(0xFFF7F7F7);
  static const Color standardRed = Color(0xFFFF3B30);

  static const Color primaryNeonColor = electricBlue; 
  static const Color darkBackground = pureWhite;   
  static const Color cardColor = pureWhite;        
  static const Color secondaryColor = pureBlack;   
  static const Color errorColor = standardRed;       
  static const Color highlightColor = subtleGray;   

  // Legacy aliases to prevent compilation errors in hardcoded screens
  static const Color tommyNavy = pureBlack;
  static const Color tommyRed = electricBlue;

  static const Color driverNavy = Color(0xFF00174F);

  static ThemeData getTheme(String mode) {
    final bool isPassenger = mode == 'pasajero';
    final Color dynamicPrimary = isPassenger ? electricBlue : driverNavy;
    final Color dynamicSecondary = isPassenger ? pureBlack : pureBlack;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.light( 
        primary: dynamicPrimary,
        secondary: dynamicSecondary,
        surface: cardColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: pureBlack, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w800, color: pureBlack, letterSpacing: -0.5),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: pureBlack),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: pureBlack),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, color: pureBlack),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.black54),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: pureBlack),
        titleTextStyle: GoogleFonts.inter(
          color: pureBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dynamicPrimary,
          foregroundColor: pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dynamicPrimary,
        foregroundColor: pureWhite,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtleGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dynamicPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIconColor: Colors.black54,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureWhite,
        indicatorColor: Colors.black12,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: pureBlack,
            );
          }
          return GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: pureWhite,
        selectedItemColor: dynamicPrimary,
        unselectedItemColor: Colors.black38,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
    );
  }
}
