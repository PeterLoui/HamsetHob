import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'theme.dart';

// مكوّنات الواجهة: أسطح ثابتة بخطوط رفيعة (مخطوطة في الفاتح، سهرانية في الداكن).

/// خلفية الشاشات: لون ثابت.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.colors.surface, child: const SizedBox.expand());
  }
}

/// طبقة فوق المحتوى ورا شريط الحالة: المحتوى اللي بيطلع لفوق بيتغبّش ويختفي
/// تدريجياً بدل ما يدخل تحت الساعة والأيقونات.
class StatusBarFade extends StatelessWidget {
  const StatusBarFade({super.key});

  /// ارتفاع منطقة التلاشي تحت شريط الحالة.
  static const fade = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return const SizedBox.shrink();
    final bg = c.surface;
    final h = top + fade;
    // تغبيش متدرّج: قوي ورا شريط الحالة وبيخف في شريطين تحته
    Widget band(double from, double to, double sigma) => Positioned(
          top: from,
          height: to - from,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: const SizedBox.expand()),
          ),
        );
    return IgnorePointer(
      child: SizedBox(
        height: h,
        child: Stack(children: [
          band(0, top, 12),
          band(top, top + fade * .45, 6),
          band(top + fade * .45, top + fade * .8, 2.5),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: .92), bg.withValues(alpha: .78), bg.withValues(alpha: 0)],
                  stops: [0, top / h, 1],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// بطاقة: كارت ثابت بخط رفيع.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
}

/// زر دائري صغير داخل البطاقات.
class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.onTap, required this.tooltip, this.color, this.size = 40});
  final Widget icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        // الأيقونة لوحدها من غير دايرة، إلا لو الزرار له لون (زي التشغيل)
        color: color ?? Colors.transparent,
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
    final r = BorderRadius.circular(8);
    return Material(
      color: filled ? c.live : c.chip,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: filled ? c.onLive : c.text)),
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
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: onBack,
            tooltip: 'رجوع',
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
class NavTab {
  final String label;
  final Widget icon;
  const NavTab({required this.label, required this.icon});
}

/// ارتفاع الشريط السفلي بدون مساحة النظام.
double bottomBarHeight(BuildContext context) => 64.0;

/// الشريط السفلي: شريط ثابت بخط رفيع فوقه.
class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<NavTab> tabs;
  final ValueChanged<int> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context).bottom;
    // التبويب المفتوح بالحبر (الأحمر للتاريخ القبطي وأرقام الآيات بس)، وفي سهرانية نقطة عسلية تحته.
    final on = c.text;
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
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        activeTrackColor: c.live,
        inactiveTrackColor: c.chip,
        thumbColor: c.live,
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
    return Semantics(
      label: label,
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onLive : c.card),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.live : c.chip),
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
