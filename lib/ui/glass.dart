import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'theme.dart';

// كل مكوّن هنا بيرسم زجاج في التصميم القديم، وسطح ثابت بخط رفيع
// في تصميم مخطوطة/سهرانية (context.colors.classic).

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

/// خلفية الشاشات: لون ثابت في مخطوطة/سهرانية، وتدرج بفقاعات لونية في الزجاج.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (c.classic) return ColoredBox(color: c.surface, child: const SizedBox.expand());
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

/// بطاقة: زجاج (GlassContainer) أو كارت ثابت بخط رفيع.
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
    final c = context.colors;
    if (c.classic) {
      // كروت 12 إلى 16 بدل 22 إلى 32
      final r = BorderRadius.circular(radius.clamp(8, 16).toDouble());
      return Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: c.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: height, child: Padding(padding: padding, child: child)),
        ),
      );
    }
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
        // في مخطوطة/سهرانية الأيقونة لوحدها من غير دايرة، إلا لو الزرار له لون (زي التشغيل)
        color: color ?? (c.classic ? Colors.transparent : c.chip),
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

/// زر نصي صغير (ثانوي داخل البطاقات).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.onTap, this.filled = false});
  final String text;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.circular(c.classic ? 8 : 99);
    return Material(
      color: filled ? c.accent : c.chip,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: c.classic ? FontWeight.w500 : FontWeight.w600,
                  color: filled ? c.onAccent : c.text)),
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
          c.classic
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: c.text),
                  onPressed: onBack,
                  tooltip: 'رجوع',
                )
              : GlassIconButton(
                  icon: Icon(Icons.arrow_back, color: c.text),
                  onPressed: onBack!,
                  semanticLabel: 'رجوع',
                ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.heading(size: 26)),
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

/// ارتفاع الشريط السفلي بدون مساحة النظام.
double bottomBarHeight(BuildContext context) => context.colors.classic ? 64.0 : 92.0;

/// الشريط السفلي: زجاج سائل عائم، أو شريط ثابت بخط رفيع فوقه.
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
    if (c.classic) {
      final safe = MediaQuery.paddingOf(context).bottom;
      // مخطوطة: التبويب المفتوح بالأحمر. سهرانية: أوف وايت ونقطة عسلية تحته.
      final on = c.isDark ? c.text : c.accent;
      return Container(
        height: 64 + safe,
        padding: EdgeInsets.only(bottom: safe),
        decoration: BoxDecoration(color: c.navBar, border: Border(top: BorderSide(color: c.hairline))),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selectedIndex,
                button: true,
                child: InkResponse(
                  onTap: () => onTabSelected(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconTheme(
                      data: IconThemeData(color: i == selectedIndex ? on : c.textFaint, size: 22),
                      child: tabs[i].icon,
                    ),
                    const SizedBox(height: 2),
                    Text(tabs[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == selectedIndex ? FontWeight.w500 : FontWeight.w400,
                          color: i == selectedIndex ? on : c.textFaint,
                        )),
                    if (c.isDark)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == selectedIndex ? c.accent : Colors.transparent,
                        ),
                      ),
                  ]),
                ),
              ),
            ),
        ]),
      );
    }
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

/// اختيار من عدة خيارات (العهد القديم/الجديد، ميلادي/قبطي، المظهر).
class AppSegmented extends StatelessWidget {
  const AppSegmented({super.key, required this.labels, required this.selectedIndex, required this.onSelected});
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) {
      return GlassSegmentedControl(
        segments: [for (final l in labels) GlassSegment(label: l)],
        selectedIndex: selectedIndex,
        onSegmentSelected: onSelected,
      );
    }
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == selectedIndex,
              button: true,
              child: Material(
                color: i == selectedIndex ? (c.isDark ? const Color(0xFF3A342B) : c.card) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => onSelected(i),
                  child: Center(
                    child: Text(labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == selectedIndex ? FontWeight.w500 : FontWeight.w400,
                          color: i == selectedIndex ? c.text : c.textSoft,
                        )),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// خانة البحث.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({super.key, required this.placeholder, required this.onChanged});
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) {
      return GlassSearchBar(
        placeholder: placeholder,
        onChanged: onChanged,
        height: 48,
        textStyle: TextStyle(color: c.text, fontSize: 15),
        placeholderStyle: TextStyle(color: c.textFaint, fontSize: 15),
      );
    }
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hairline));
    return SizedBox(
      height: 48,
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(color: c.text, fontSize: 15),
        cursorColor: c.accent,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: c.textFaint, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: c.textFaint, size: 20),
          filled: true,
          fillColor: c.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: c.textFaint)),
        ),
      ),
    );
  }
}

/// شريحة اختيار (أقسام العظات، إعادة المحاولة).
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.onTap, this.selected = false});
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) {
      return GlassChip(label: label, selected: selected, selectedColor: c.accent, onTap: onTap);
    }
    final r = BorderRadius.circular(8);
    return Material(
      color: selected ? c.text : c.card,
      shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: selected ? c.text : c.hairline)),
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? c.surface : c.text)),
        ),
      ),
    );
  }
}

/// شريط تقدّم العظة.
class AppSlider extends StatelessWidget {
  const AppSlider({super.key, required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) return GlassSlider(value: value, onChanged: onChanged, activeColor: c.accent);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.chip,
        thumbColor: c.accent,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

/// مفتاح تشغيل/إيقاف في الإعدادات.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) return GlassSwitch(value: value, onChanged: onChanged, activeColor: c.accent, semanticLabel: label);
    return Semantics(
      label: label,
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.card),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.chip),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// زرار أيقونة (الإصحاح السابق/التالي).
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.label, required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.classic) {
      return GlassButton(
        icon: icon,
        label: label,
        onTap: onTap,
        width: 64,
        height: 48,
        shape: const LiquidRoundedSuperellipse(borderRadius: 24),
        useOwnLayer: true,
        settings: glassSettings,
      );
    }
    final r = BorderRadius.circular(10);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: c.hairline)),
        child: InkWell(borderRadius: r, onTap: onTap, child: SizedBox(width: 64, height: 48, child: Center(child: icon))),
      ),
    );
  }
}
