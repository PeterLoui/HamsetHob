import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/synaxarium.dart';
import '../data/store.dart';

/// ألوان الواجهة حسب الوضع (فاتح/داكن) والموسم الكنسي.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.isDark,
    required this.wallpaper,
    required this.blobs,
    required this.text,
    required this.textSoft,
    required this.textFaint,
    required this.accent,
    required this.fast,
    required this.saint,
    required this.chip,
    required this.glassTint,
  });

  final bool isDark;
  final List<Color> wallpaper;
  final List<Color> blobs;
  final Color text, textSoft, textFaint, accent, fast, saint, chip, glassTint;

  factory AppColors.of(bool dark, Season season) {
    final (wall, blobs) = switch ((season, dark)) {
      (Season.ordinary, true) => (
          const [Color(0xFF140B26), Color(0xFF2A1446), Color(0xFF4A1B4F)],
          const [Color(0xAAE0457B), Color(0x995B5BE8), Color(0x88F3A15C), Color(0x777A3FD1)],
        ),
      (Season.fast, true) => (
          const [Color(0xFF0C0A24), Color(0xFF1C1748), Color(0xFF2E1B57)],
          const [Color(0xAA6B4BD8), Color(0x994A6FE0), Color(0x779A62C9), Color(0x775B3FA8)],
        ),
      (Season.feast, true) => (
          const [Color(0xFF1C1208), Color(0xFF3A230F), Color(0xFF4F2A1A)],
          const [Color(0xAAF3B04A), Color(0x99E0705B), Color(0x88FFD98A), Color(0x77C0603F)],
        ),
      (Season.ordinary, false) => (
          const [Color(0xFFFFF1F5), Color(0xFFF6E6FF), Color(0xFFFFE9DD)],
          const [Color(0x99FF8DB3), Color(0x889DA2FF), Color(0x88FFC48A), Color(0x77C59BFF)],
        ),
      (Season.fast, false) => (
          const [Color(0xFFF1EEFF), Color(0xFFE6E8FF), Color(0xFFEFE4FF)],
          const [Color(0x99A88BFF), Color(0x8890A8FF), Color(0x77C7A2F0), Color(0x77A890E8)],
        ),
      (Season.feast, false) => (
          const [Color(0xFFFFF8EA), Color(0xFFFFEFD6), Color(0xFFFFE6DA)],
          const [Color(0x99FFC85C), Color(0x88FF9E85), Color(0x88FFE39E), Color(0x77E89A70)],
        ),
    };
    return dark
        ? AppColors(
            isDark: true,
            wallpaper: wall,
            blobs: blobs,
            text: Colors.white,
            textSoft: const Color(0xD9FFFFFF),
            textFaint: const Color(0xB3FFFFFF),
            accent: const Color(0xFFF3C77A),
            fast: const Color(0xFFB9A7FF),
            saint: const Color(0xFFFFC2DA),
            chip: const Color(0x26FFFFFF),
            glassTint: const Color(0x1FFFFFFF),
          )
        : AppColors(
            isDark: false,
            wallpaper: wall,
            blobs: blobs,
            text: const Color(0xFF2A1638),
            textSoft: const Color(0xD92A1638),
            textFaint: const Color(0xB32A1638),
            accent: const Color(0xFF9A5E12),
            fast: const Color(0xFF5B45C9),
            saint: const Color(0xFFB0306A),
            chip: const Color(0x1A2A1638),
            glassTint: const Color(0x52FFFFFF),
          );
  }

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
}

ThemeData buildTheme(AppColors c) {
  final base = c.isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(bodyColor: c.text, displayColor: c.text),
    iconTheme: IconThemeData(color: c.text),
    colorScheme: base.colorScheme.copyWith(primary: c.accent, onSurface: c.textSoft),
    extensions: [c],
  );
}
