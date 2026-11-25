import 'package:flutter/material.dart';

import 'glass.dart';
import 'icons.dart';
import 'theme.dart';

/// جولة تعريفية بسيطة: كل شريحة بتعرض شكل الشاشة وشرح في سطرين، مع «تخطي» في أي وقت.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _Slide {
  const _Slide(this.tab, this.title, this.body, this.mock);
  final int? tab; // التبويب اللي بيتنوّر في الشريط
  final String title, body;
  final Widget Function(BuildContext) mock;
}

const _tabs = [
  NavTab(label: 'الرئيسية', icon: AppIconView(AppIcon.home)),
  NavTab(label: 'الكتاب', icon: AppIconView(AppIcon.bible)),
  NavTab(label: 'القراءات', icon: AppIconView(AppIcon.readings)),
  NavTab(label: 'النتيجة', icon: AppIconView(AppIcon.calendar)),
  NavTab(label: 'دراسة', icon: AppIconView(AppIcon.study)),
  NavTab(label: 'المزيد', icon: AppIconView(AppIcon.more)),
];

class _IntroScreenState extends State<IntroScreen> {
  final _page = PageController();
  int _i = 0;

  static Widget _row(BuildContext context, IconData icon, String title, [String? sub]) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(icon, color: c.navGlow, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: c.textFaint)),
          ]),
        ),
      ]),
    );
  }

  static Widget _panel(List<Widget> children) => GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  late final _slides = <_Slide>[
    _Slide(null, 'أهلاً بك في همسة حب', 'كلمة كل يوم، وصلاة، وقراءات، ودراسة للكتاب المقدس، في مكان واحد. هنعرّفك عليه في دقيقة.', (ctx) {
      final c = ctx.colors;
      return Center(child: Icon(Icons.favorite_border_rounded, size: 120, color: c.navGlow));
    }),
    _Slide(0, 'الرئيسية', 'آية اليوم وقول من الآباء، وإنجيل القداس، وتأمل اليوم. وفيها «أنا محتاج…» لما تكون عايز كلمة تناسب حالتك، وحفظ الآيات.', (ctx) {
      final c = ctx.colors;
      return _panel([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('«الرب راعيّ فلا يعوزني شيء»', style: TextStyle(fontSize: 19, height: 1.7, color: c.text)),
        ),
        _row(ctx, Icons.favorite_outline, 'أنا محتاج…', 'قلقان؟ حزين؟ شاكر؟'),
        _row(ctx, Icons.menu_book_outlined, 'إنجيل القداس اليوم'),
        _row(ctx, Icons.bookmark_outline, 'حفظ الآيات', 'ابدأ بآية الأسبوع'),
      ]);
    }),
    _Slide(1, 'الكتاب المقدس', 'اختار السفر والأصحاح. اضغط على أي آية لتظليلها أو مشاركتها أو حفظها، أو فتح تفسيرها بلمسة. وبإصبعين تكبّر الخط.', (ctx) {
      final c = ctx.colors;
      return _panel([
        Text('١ فِي الْبَدْءِ خَلَقَ اللهُ السَّمَاوَاتِ وَالأَرْضَ.', style: TextStyle(fontSize: 17, height: 1.8, color: c.textSoft)),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10)),
          child: Text('٢ وَكَانَتِ الأَرْضُ خَرِبَةً وَخَالِيَةً.', style: TextStyle(fontSize: 17, height: 1.8, color: c.text)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          AppChip(label: 'تفسير الآية', onTap: () {}),
          AppChip(label: 'ظلّل', onTap: () {}),
          AppChip(label: 'احفظها', onTap: () {}),
          AppChip(label: 'شارك', onTap: () {}),
        ]),
        const SizedBox(height: 6),
      ]);
    }),
    _Slide(2, 'القراءات والنتيجة', 'قراءات القداس والمزامير كل يوم، وسنكسار اليوم. وفي «النتيجة» التقويم القبطي والأصوام والأعياد.', (ctx) {
      return _panel([
        _row(ctx, Icons.auto_stories_outlined, 'قراءات اليوم', 'البولس والكاثوليكون والإبركسيس والإنجيل'),
        _row(ctx, Icons.star_outline_rounded, 'سنكسار اليوم', 'سيرة قديس اليوم'),
        _row(ctx, Icons.calendar_month_outlined, 'التقويم القبطي', 'الأصوام والأعياد'),
      ]);
    }),
    _Slide(4, 'دراسة الكتاب', 'تفاسير القمص أنطونيوس فكري ومسابقات البابا شنوده، وخريطة للكتاب تتبع عليها رحلات الآباء والرسل خطوة بخطوة.', (ctx) {
      return _panel([
        _row(ctx, Icons.school_outlined, 'تفسير سفر بسفر', 'مقدمة وتفسير كل أصحاح'),
        _row(ctx, Icons.quiz_outlined, 'مسابقات', 'اختبر معلوماتك'),
        _row(ctx, Icons.map_outlined, 'خريطة الكتاب', 'رحلة إبراهيم وبولس'),
      ]);
    }),
    _Slide(0, 'الصلوات والإذاعة', 'من الرئيسية: الصلوات (الأجبية والقداس)، والتسبحة، وإذاعات قبطية. الصوت بيكمّل والشاشة مقفولة، وتتحكم فيه من الإشعار.', (ctx) {
      return _panel([
        _row(ctx, Icons.local_fire_department_outlined, 'الصلوات', 'الأجبية والقداس والمزامير'),
        _row(ctx, Icons.music_note_outlined, 'تسبحة', 'ألحان وتسبحة نصف الليل'),
        _row(ctx, Icons.podcasts, 'إذاعات', 'بث مباشر وعظات'),
      ]);
    }),
    _Slide(5, 'المزيد', 'المفضلة وخطط قراءة الكتاب، وتغيير المظهر والألوان وحجم الخط، والتذكيرات والتنبيه بالتحديثات. تقدر ترجع للجولة دي من هنا في أي وقت.', (ctx) {
      return _panel([
        _row(ctx, Icons.favorite_border, 'المفضلة'),
        _row(ctx, Icons.event_note_outlined, 'خطط قراءة الكتاب'),
        _row(ctx, Icons.tune, 'الإعدادات', 'المظهر والتذكيرات'),
      ]);
    }),
  ];

  void _next() {
    if (_i >= _slides.length - 1) {
      widget.onDone();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final last = _i == _slides.length - 1;
    return Material(
      color: c.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, pad.top + 12, 24, pad.bottom + 16),
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AnimatedOpacity(
              opacity: last ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: TextButton(onPressed: last ? null : widget.onDone, child: Text('تخطي', style: TextStyle(color: c.textFaint, fontSize: 15))),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _slides.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (context, k) {
                final s = _slides[k];
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 260),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(height: s.tab == null ? 220 : null, child: s.mock(context)),
                      const SizedBox(height: 22),
                      if (s.tab != null)
                        IgnorePointer(
                          child: Directionality(
                            textDirection: Directionality.of(context),
                            child: SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: MediaQuery.sizeOf(context).width - 48, child: BottomNavBar(selectedIndex: s.tab!, tabs: _tabs, onTabSelected: (_) {})))),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(s.title, style: context.heading(size: 26)),
                      const SizedBox(height: 10),
                      Text(s.body, style: TextStyle(fontSize: 15.5, height: 1.8, color: c.textSoft)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (var k = 0; k < _slides.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsetsDirectional.only(end: 6),
                width: k == _i ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(color: k == _i ? c.navGlow : c.hairline, borderRadius: BorderRadius.circular(4)),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: c.navGlow,
                foregroundColor: c.isDark ? const Color(0xFF14120F) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: Text(last ? 'ابدأ' : 'التالي', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}
