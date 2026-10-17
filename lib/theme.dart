import 'package:flutter/material.dart';

/// Central place for the app's color palette, type scale and corner radii.
///
/// The visual identity is matched to the RNI Realestate web property: a deep
/// teal brand with a gold accent, slate-grey neutrals, Manrope for every UI
/// string and Playfair Display for display headings. Only color, type and
/// radius come from there -- layout, spacing and component structure are the
/// app's own.
///
/// `vendor_app/lib/theme.dart` is a copy of this file, token for token, so
/// the two halves of the platform read as one product. There is no shared
/// package between the two apps, so the duplication is deliberate rather than
/// an accident -- change a token here and change it there in the same breath,
/// or the apps drift apart a shade at a time.
class AppColors {
  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------

  /// Brand teal. The default accent for buttons, links and selected state.
  static const primary = Color(0xFF087F72);

  /// Deepest teal in the brand ramp. Headers, pressed state, dark surfaces.
  static const primaryDark = Color(0xFF063D35);

  /// Midpoint of the brand ramp, used for the header gradient.
  static const primaryMid = Color(0xFF075E54);

  /// Lightest usable teal -- icon tiles, tinted chips, soft fills.
  static const primaryLight = Color(0xFF009270);

  /// The three stops of the brand header gradient, left to right.
  static const List<Color> brandGradient = [
    Color(0xFF063D35),
    Color(0xFF075E54),
    Color(0xFF087F72),
  ];

  /// Gold accent. Badges, ratings, "premium" flags, divider ornaments.
  static const accent = Color(0xFFF59E0B);
  static const accentDark = Color(0xFFB45309);
  static const accentSoft = Color(0xFFFFFBEB);

  /// Near-black navy used for the primary call-to-action fill.
  static const ink = Color(0xFF0B1120);

  // ---------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------

  /// Page background -- slate-50, a touch cooler than plain white.
  static const background = Color(0xFFF8FAFC);
  static const cardBackground = Colors.white;

  /// Secondary surface for wells, inactive chips and table stripes.
  static const surfaceAlt = Color(0xFFF1F5F9);

  /// Hairline borders and dividers.
  static const border = Color(0xFFE2E8F0);

  // ---------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------

  static const textDark = Color(0xFF0F172A);
  static const textBody = Color(0xFF334155);
  static const textGrey = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // ---------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0E7490);

  /// Tinted backgrounds cycled through for category icon tiles. Kept in the
  /// brand's own green/teal/gold family rather than the old pastel mix.
  static const List<Color> categoryPalette = [
    Color(0xFFECFDF5), // emerald tint
    Color(0xFFF0FDFA), // teal tint
    Color(0xFFFFFBEB), // gold tint
    Color(0xFFF1F5F9), // slate tint
    Color(0xFFEFFDF6), // mint tint
    Color(0xFFFEFCE8), // sand tint
  ];
}

/// The corner radii used across the app, matched to the reference site's
/// scale: 6/8 for small controls, 12 for buttons and inputs, 16 for cards,
/// 24 for sheets and 999 for pills.
class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static final BorderRadius xsAll = BorderRadius.circular(xs);
  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius xlAll = BorderRadius.circular(xl);
  static final BorderRadius pillAll = BorderRadius.circular(pill);

  /// Top-only rounding for bottom sheets and stuck panels.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// The two brand typefaces.
class AppFonts {
  const AppFonts._();

  /// Every UI and body string.
  static const String sans = 'Manrope';

  /// Display headings only -- section titles, hero lines, price figures.
  static const String display = 'Playfair Display';
}

/// Display heading style, Playfair Display with the reference site's tight
/// tracking. Use for section titles, not for body copy.
TextStyle displayHeading({
  double size = 24,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.textDark,
  double? height,
}) {
  return TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: -size * 0.025,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD5F2EC),
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentSoft,
    onSecondaryContainer: AppColors.accentDark,
    tertiary: AppColors.ink,
    onTertiary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.cardBackground,
    onSurface: AppColors.textDark,
    surfaceContainerHighest: AppColors.surfaceAlt,
    onSurfaceVariant: AppColors.textGrey,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.sans,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: scheme,
    primaryColor: AppColors.primary,
    dividerColor: AppColors.border,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: -0.3,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textGrey),
      prefixIconColor: AppColors.textGrey,
      suffixIconColor: AppColors.textGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textBody,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        color: AppColors.textBody,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        color: Colors.white,
      ),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      selectedLabelStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textGrey,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
      labelStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceAlt,
      circularTrackColor: AppColors.surfaceAlt,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.border,
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: AppColors.textMuted, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textMuted,
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textGrey,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 13,
        color: AppColors.textGrey,
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.textBody),

    // Display sizes use Playfair; everything else is Manrope.
    textTheme: TextTheme(
      displayLarge: displayHeading(size: 40, weight: FontWeight.w800),
      displayMedium: displayHeading(size: 34, weight: FontWeight.w800),
      displaySmall: displayHeading(size: 28, weight: FontWeight.w700),
      headlineLarge: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textDark,
        letterSpacing: -0.7,
      ),
      headlineMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textDark,
        letterSpacing: -0.6,
      ),
      headlineSmall: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: -0.4,
      ),
      titleLarge: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: -0.3,
      ),
      titleMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: -0.2,
      ),
      titleSmall: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      bodyLarge: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 16,
        height: 1.5,
        color: AppColors.textBody,
      ),
      bodyMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        height: 1.5,
        color: AppColors.textBody,
      ),
      bodySmall: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12,
        height: 1.45,
        color: AppColors.textGrey,
      ),
      labelLarge: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      labelMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textGrey,
      ),
      labelSmall: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    ),
  );
}
