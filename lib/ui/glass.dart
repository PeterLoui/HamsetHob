import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'theme.dart';

/// إعدادات الزجاج السائل المشتركة في التطبيق كله (مستوحاة من Magic OS 11).
const glassSettings = LiquidGlassSettings(
  thickness: 26,
  blur: 9,
  glassColor: Color(0x24FFFFFF),
  lightIntensity: .65,
  saturation: 1.6,
  refractiveIndex: 1.25,
  chromaticAberration: .012,
);

/// نسخة أكثر ضبابية للبطاقات التي تحمل نصوصاً طويلة.
const frostedSettings = LiquidGlassSettings(
  thickness: 22,
  blur: 16,
  glassColor: Color(0x30FFFFFF),
  lightIntensity: .55,
  saturation: 1.4,
  refractiveIndex: 1.2,
);

/// خلفية متدرجة بفقاعات لونية ناعمة تتلون بالموسم الكنسي — هي ما ينكسر خلف الزجاج.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget blob(Alignment a, double size, Color color) => Align(
          alignment: a,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c.wallpaper),
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.decal),
        child: Stack(children: [
          blob(const Alignment(1.1, -0.9), 340, c.blobs[0]),
          blob(const Alignment(-1.2, -0.3), 380, c.blobs[1]),
          blob(const Alignment(0.8, 0.35), 320, c.blobs[2]),
          blob(const Alignment(-0.8, 1.1), 400, c.blobs[3]),
        ]),
      ),
    );
  }
}

/// سطح زجاجي (GlassContainer من الحزمة) بزوايا Superellipse.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.height,
    this.ownLayer = false,
    this.settings,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? height;
  final bool ownLayer;
  final LiquidGlassSettings? settings;

  @override
  Widget build(BuildContext context) {
    Widget panel = GlassContainer(
      useOwnLayer: ownLayer,
      settings: settings ?? (ownLayer ? glassSettings : null),
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      height: height,
      padding: padding,
      child: child,
    );
    if (onTap != null) {
      panel = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: panel);
    }
    return panel;
  }
}

/// زر دائري صغير داخل البطاقات (ليس زجاجاً، لأن الحزمة تمنع الزجاج داخل الزجاج).
class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.onTap, required this.tooltip, this.color, this.size = 40});
  final Widget icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: color ?? c.chip,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// حبة نصية صغيرة (زر ثانوي داخل البطاقات).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.onTap, this.filled = false});
  final String text;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: filled ? c.accent : c.chip,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: filled ? const Color(0xFF2A1446) : c.text)),
        ),
      ),
    );
  }
}

/// رأس الشاشات: عنوان + عنوان فرعي + زر رجوع اختياري.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.subtitle, this.onBack, this.trailing});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(children: [
        if (onBack != null) ...[
          GlassIconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: onBack!,
            semanticLabel: 'رجوع',
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.text)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, color: c.textSoft)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// تبويب في الشريط السفلي.
class LiquidGlassTab {
  final String label;
  final Widget icon;
  const LiquidGlassTab({required this.label, required this.icon});
}

/// الشريط السفلي بالزجاج السائل (GlassTabBar.bottom = GlassBottomBar في الإصدارات الأحدث).
class LiquidGlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<LiquidGlassTab> tabs;
  final ValueChanged<int> onTabSelected;
  final double opacity;

  const LiquidGlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: opacity,
      child: GlassTabBar.bottom(
        selectedIndex: selectedIndex,
        selectedIconColor: Theme.of(context).colorScheme.primary,
        unselectedIconColor: Theme.of(context).colorScheme.onSurface,
        selectedLabelColor: c.text,
        unselectedLabelColor: c.textSoft,
        settings: glassSettings,
        indicatorColor: Colors.white.withValues(alpha: 0.1),
        onTabSelected: onTabSelected,
        tabs: tabs.map((t) => GlassTab(label: t.label, icon: t.icon)).toList(),
      ),
    );
  }
}
