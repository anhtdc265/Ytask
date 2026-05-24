import 'package:flutter/material.dart';

@immutable
class YTaskColors extends ThemeExtension<YTaskColors> {
  final Color brand;
  final Color brandDark;
  final Color appBackground;
  final Color authBackground;
  final Color authPanel;
  final Color schedulePanel;
  final Color scheduleCard;
  final Color scheduleCardBorder;
  final Color bottomNav;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color inputFill;
  final Color inputBorder;
  final Color inputHint;
  final Color shadow;
  final Color danger;
  final Color success;
  final Color warning;

  const YTaskColors({
    required this.brand,
    required this.brandDark,
    required this.appBackground,
    required this.authBackground,
    required this.authPanel,
    required this.schedulePanel,
    required this.scheduleCard,
    required this.scheduleCardBorder,
    required this.bottomNav,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.inputFill,
    required this.inputBorder,
    required this.inputHint,
    required this.shadow,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const light = YTaskColors(
    brand: Color(0xFF64DA56),
    brandDark: Color(0xFF10A45C),
    appBackground: Color(0xFFD8F6D2),
    authBackground: Color(0xFFD8F6D2),
    authPanel: Color(0xFFF7F7F7),
    schedulePanel: Color(0xFFF5F1F8),
    scheduleCard: Colors.white,
    scheduleCardBorder: Color(0xFFFFFFFF),
    bottomNav: Colors.white,
    textPrimary: Color(0xFF1F1F1F),
    textSecondary: Color(0xFF5F625F),
    textMuted: Color(0xFF8A8D8A),
    inputFill: Colors.white,
    inputBorder: Color(0xFFE4E4E4),
    inputHint: Color(0xFF9E9E9E),
    shadow: Color(0x1A000000),
    danger: Color(0xFFFF3B30),
    success: Color(0xFF34C759),
    warning: Color(0xFFFFCC00),
  );

  static const dark = YTaskColors(
    brand: Color(0xFF64DA56),
    brandDark: Color(0xFF65E070),
    appBackground: Color(0xFF171D17),
    authBackground: Color(0xFF171D17),
    authPanel: Color(0xFF20251F),
    schedulePanel: Color(0xFF20251F),
    scheduleCard: Color(0xFF2A3029),
    scheduleCardBorder: Color(0xFF3A4438),
    bottomNav: Color(0xFF1D231C),
    textPrimary: Color(0xFFF4F7F2),
    textSecondary: Color(0xFFD2D8D0),
    textMuted: Color(0xFFAEB8AB),
    inputFill: Color(0xFF2A3029),
    inputBorder: Color(0xFF3A4438),
    inputHint: Color(0xFF9AA396),
    shadow: Color(0x99000000),
    danger: Color(0xFFFF6B61),
    success: Color(0xFF55D86A),
    warning: Color(0xFFFFD84A),
  );

  @override
  YTaskColors copyWith({
    Color? brand,
    Color? brandDark,
    Color? appBackground,
    Color? authBackground,
    Color? authPanel,
    Color? schedulePanel,
    Color? scheduleCard,
    Color? scheduleCardBorder,
    Color? bottomNav,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? inputFill,
    Color? inputBorder,
    Color? inputHint,
    Color? shadow,
    Color? danger,
    Color? success,
    Color? warning,
  }) {
    return YTaskColors(
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      appBackground: appBackground ?? this.appBackground,
      authBackground: authBackground ?? this.authBackground,
      authPanel: authPanel ?? this.authPanel,
      schedulePanel: schedulePanel ?? this.schedulePanel,
      scheduleCard: scheduleCard ?? this.scheduleCard,
      scheduleCardBorder: scheduleCardBorder ?? this.scheduleCardBorder,
      bottomNav: bottomNav ?? this.bottomNav,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      inputHint: inputHint ?? this.inputHint,
      shadow: shadow ?? this.shadow,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  YTaskColors lerp(ThemeExtension<YTaskColors>? other, double t) {
    if (other is! YTaskColors) return this;

    return YTaskColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      authBackground: Color.lerp(authBackground, other.authBackground, t)!,
      authPanel: Color.lerp(authPanel, other.authPanel, t)!,
      schedulePanel: Color.lerp(schedulePanel, other.schedulePanel, t)!,
      scheduleCard: Color.lerp(scheduleCard, other.scheduleCard, t)!,
      scheduleCardBorder:
          Color.lerp(scheduleCardBorder, other.scheduleCardBorder, t)!,
      bottomNav: Color.lerp(bottomNav, other.bottomNav, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputHint: Color.lerp(inputHint, other.inputHint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension YTaskThemeX on BuildContext {
  YTaskColors get ytaskColors =>
      Theme.of(this).extension<YTaskColors>() ?? YTaskColors.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  static YTaskColors colors(BuildContext context) => 
      Theme.of(context).extension<YTaskColors>() ?? YTaskColors.light;

  static ThemeData get light => _buildTheme(Brightness.light, YTaskColors.light);
  static ThemeData get dark => _buildTheme(Brightness.dark, YTaskColors.dark);

  static ThemeData _buildTheme(Brightness brightness, YTaskColors colors) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.appBackground,
      primaryColor: colors.brand,
      extensions: <ThemeExtension<dynamic>>[colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.brand,
        onPrimary: Colors.white,
        secondary: colors.brandDark,
        onSecondary: Colors.white,
        error: colors.danger,
        onError: Colors.white,
        surface: colors.authPanel,
        onSurface: colors.textPrimary,
      ),
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.brand,
        selectionColor: colors.brand.withValues(alpha: 0.28),
        selectionHandleColor: colors.brand,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        hintStyle: TextStyle(
          color: colors.inputHint,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: colors.inputHint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.brand, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
