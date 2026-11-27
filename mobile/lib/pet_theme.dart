import 'package:flutter/material.dart';

import 'account_layout.dart';
import 'motion.dart';
import 'welcome.dart';

/// Sistema visual compartido de PetID. Conserva la paleta cálida y amable,
/// pero evita que cada pantalla invente sus propios radios, bordes y botones.
ThemeData petIdTheme() {
  const surfaceEdge = Color(0xFFEFE5E0);
  final colors = ColorScheme.fromSeed(
    seedColor: petOrange,
    brightness: Brightness.light,
    primary: petDarkOrange,
    onPrimary: Colors.white,
    secondary: const Color(0xFF08735F),
    onSecondary: Colors.white,
    surface: petCream,
    onSurface: petInk,
    error: const Color(0xFFB42318),
  );
  final rounded16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: petCream,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: surfaceEdge,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PetPageTransitions(),
        TargetPlatform.iOS: PetPageTransitions(),
      },
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: petInk,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
      titleLarge: TextStyle(color: petInk, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: petInk, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: petInk, height: 1.35),
      bodyMedium: TextStyle(color: accountMuted, height: 1.35),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accountBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accountBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: petDarkOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        backgroundColor: petDarkOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE9DDD6),
        disabledForegroundColor: accountMuted,
        elevation: 0,
        shape: rounded16,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: petDarkOrange,
        backgroundColor: Colors.white,
        side: const BorderSide(color: accountBorder, width: 1.5),
        shape: rounded16,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: petDarkOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: surfaceEdge),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: petCream,
      modalBackgroundColor: petCream,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x850F1718),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: petCream,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFF8A9497),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF12B894)
            : const Color(0xFFE4E0DD),
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: accountMuted,
      collapsedIconColor: accountMuted,
      textColor: petInk,
      collapsedTextColor: petInk,
      tilePadding: EdgeInsets.symmetric(horizontal: 4),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: petDarkOrange,
      textColor: petInk,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
