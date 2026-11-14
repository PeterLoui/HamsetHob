import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/synaxarium.dart';
import '../data/store.dart';

/// ألوان الواجهة: «مخطوطة» في الوضع الفاتح و«سهرانية» في الداكن.
/// أسطح ثابتة وخطوط رفيعة، والأحمر (أو العسلي) للتاريخ القبطي وأرقام الآيات.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.isDark,
    required this.surface,
    required this.card,
    required this.navBar,
    required this.hairline,
    required this.text,
    required this.textSoft,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.fast,
    required this.saint,
    required this.chip,
    required this.uiFont,
    required this.headingFont,
  });

  final bool isDark;
  final Color surface, card, navBar, hairline;
  final Color text, textSoft, textFaint, accent, onAccent, fast, saint, chip;
  final String uiFont;
  final String headingFont;

  factory AppColors.of(bool dark) => dark ? _vigil : _manuscript;

  /// «مخطوطة»: رقّ فاتح وحبر، والأحمر للتاريخ القبطي وأرقام الآيات.
  static const _manuscript = AppColors(
    isDark: false,
    surface: Color(0xFFF3EEE4),
    card: Color(0xFFFBF8F2),
    navBar: Color(0xFFF3EEE4),
    hairline: Color(0x1F211B14),
    text: Color(0xFF211B14),
    textSoft: Color(0xFF5C5347),
    textFaint: Color(0xFF776E61),
    accent: Color(0xFFA3271B),
    onAccent: Color(0xFFFFFFFF),
    fast: Color(0xFF5B3A82),
    saint: Color(0xFF5C5347),
    chip: Color(0xFFE9E2D4),
    uiFont: 'IBM Plex Sans Arabic',
    headingFont: 'Amiri',
  );

  /// «سهرانية»: خشب غامق وشمع، والعسلي للحاجات الحيّة بس.
  static const _vigil = AppColors(
    isDark: true,
    surface: Color(0xFF14120F),
    card: Color(0xFF1D1A16),
    navBar: Color(0xFF100E0C),
    hairline: Color(0x17EFE7DA),
    text: Color(0xFFEFE7DA),
    textSoft: Color(0xFFADA495),
    textFaint: Color(0xFF8C8477),
    accent: Color(0xFFE2A84B),
    onAccent: Color(0xFF1A140A),
    fast: Color(0xFFB9A3D9),
    saint: Color(0xFFADA495),
    chip: Color(0xFF28241E),
    uiFont: 'Noto Kufi Arabic',
    headingFont: 'Noto Naskh Arabic',
  );

  /// لون الأزرار والحاجات الشغالة (تشغيل، سويتش، زرار أساسي):
  /// حبر في مخطوطة عشان الأحمر يفضل للتاريخ القبطي وأرقام الآيات، وعسلي في سهرانية.
  Color get live => isDark ? accent : text;
  Color get onLive => isDark ? onAccent : surface;

  Color kindColor(Kind k) => switch (k) { Kind.feast => accent, Kind.fast => fast, Kind.saint => saint };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) => t < .5 || other == null ? this : other;
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// خط الآيات: أميري إن كان مفعّلاً.
  TextStyle scripture({double size = 19, Color? color}) {
    final base = TextStyle(fontSize: size, height: 1.8, color: color ?? colors.text);
    return AppSettings.instance.scriptureFont ? GoogleFonts.amiri(textStyle: base) : base;
  }

  /// العناوين الكبيرة: أميري في مخطوطة، ونوتو نسخ في سهرانية.
  TextStyle heading({double size = 26, Color? color}) {
    final c = colors;
    final base = TextStyle(
      fontSize: size,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: color ?? c.text,
    );
    return GoogleFonts.getFont(c.headingFont, textStyle: base);
  }
}

ThemeData buildTheme(AppColors c) {
  final base = c.isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.getTextTheme(c.uiFont, base.textTheme).apply(bodyColor: c.text, displayColor: c.text),
    iconTheme: IconThemeData(color: c.text),
    colorScheme: base.colorScheme.copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      onSurface: c.textSoft,
      surface: c.card,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    extensions: [c],
  );
}
