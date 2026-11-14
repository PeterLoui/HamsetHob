import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/coptic.dart' show ar;
import '../../data/tasbeha.dart';
import '../glass.dart';
import '../theme.dart';

EdgeInsets _pagePadding(BuildContext context) {
  final pad = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 32);
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, required this.onTap, this.leading, this.badge});
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? leading;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: c.textFaint)),
            ]),
          ),
          if (badge != null) ...[
            Text(badge!, style: TextStyle(fontSize: 12, color: c.accent)),
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

Widget _groupLabel(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: Text(text, style: TextStyle(fontSize: 13, color: context.colors.textFaint)),
    );

/// تبويب «تسبحة»: جواه تسبحة كيهك متقسمة على أيام الأسبوع، وبرمون الميلاد.
class TasbehaScreen extends StatelessWidget {
  const TasbehaScreen({super.key, required this.onBack, required this.onOpenDay});
  final VoidCallback onBack;
  final ValueChanged<TasbehaDay> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateTime.now().weekday % 7; // الأحد = ٠
    return FutureBuilder<TasbehaBook>(
      future: TasbehaRepository.instance.kiahk(),
      builder: (context, snap) {
        final book = snap.data;
        return ListView(
          padding: _pagePadding(context),
          children: [
            ScreenHeader('تسبحة', subtitle: 'تسبحة نصف الليل', onBack: onBack),
            if (book == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else ...[
              _groupLabel(context, book.title),
              Text(
                'لكل يوم إبصاليته وثيئوطوكيته، وقبلهم قوموا يا بني النور والهوسات والمجمع وذكصولوجيات كيهك. بتتقري من غير نت',
                style: TextStyle(fontSize: 13, height: 1.6, color: c.textSoft),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < book.days.length; i++)
                _Row(
                  title: book.days[i].name,
                  subtitle: book.days[i].subtitle,
                  badge: i == today ? 'اليوم' : null,
                  onTap: () => onOpenDay(book.days[i]),
                ),
              const SizedBox(height: 16),
              Text(book.source, style: TextStyle(fontSize: 11, color: c.textFaint)),
            ],
          ],
        );
      },
    );
  }
}

/// فهرس اليوم: الأجزاء بالترتيب، وكل قطعة بتفتح في القارئ.
class TasbehaDayScreen extends StatelessWidget {
  const TasbehaDayScreen({super.key, required this.day, required this.onBack, required this.onOpenPiece});
  final TasbehaDay day;
  final VoidCallback onBack;
  final ValueChanged<int> onOpenPiece;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    var n = 0;
    for (final s in day.sections) {
      rows.add(_groupLabel(context, s.title));
      for (final p in s.pieces) {
        final i = n++;
        rows.add(_Row(
          leading: SizedBox(
            width: 28,
            child: Text(ar(i + 1), style: TextStyle(fontSize: 13, color: c.textFaint, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          title: p.title,
          onTap: () => onOpenPiece(i),
        ));
      }
    }
    return ListView(
      padding: _pagePadding(context),
      children: [
        ScreenHeader(day.name, subtitle: 'تسبحة كيهك · ${day.subtitle}', onBack: onBack),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppChip(label: 'ابدأ من الأول', onTap: () => onOpenPiece(0)),
        ),
        ...rows,
      ],
    );
  }
}

/// قراءة التسبحة قطعة قطعة: السحب أو الزرارين أو الشريط، والقبطي المعرّب تحت كل ربع لو مفعّل.
class TasbehaReaderScreen extends StatefulWidget {
  const TasbehaReaderScreen({super.key, required this.day, required this.index, required this.onBack});
  final TasbehaDay day;
  final int index;
  final VoidCallback onBack;

  @override
  State<TasbehaReaderScreen> createState() => _TasbehaReaderScreenState();
}

class _TasbehaReaderScreenState extends State<TasbehaReaderScreen> {
  static const _copticKey = 'tasbeha_show_coptic';
  static bool? _showCoptic;
  late final List<TasbehaPiece> _pieces = widget.day.pieces;
  late final _pages = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void initState() {
    super.initState();
    if (_showCoptic == null) {
      SharedPreferences.getInstance().then((p) {
        if (mounted) setState(() => _showCoptic = p.getBool(_copticKey) ?? true);
      });
    }
  }

  void _toggleCoptic() {
    final v = !(_showCoptic ?? true);
    setState(() => _showCoptic = v);
    SharedPreferences.getInstance().then((p) => p.setBool(_copticKey, v));
  }

  void _go(int step) {
    final next = _i + step;
    if (next < 0 || next >= _pieces.length) return;
    _pages.animateToPage(next, duration: const Duration(milliseconds: 320), curve: const Cubic(0.22, 1, 0.36, 1));
  }

  String _sectionOf(int i) {
    var n = 0;
    for (final s in widget.day.sections) {
      n += s.pieces.length;
      if (i < n) return s.title;
    }
    return '';
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    const side = 24.0;
    final count = _pieces.length;
    final coptic = _showCoptic ?? true;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 8),
      child: Column(children: [
        ScreenHeader(
          _sectionOf(_i),
          subtitle: '${widget.day.name} · ${ar(_i + 1)} من ${ar(count)}',
          onBack: widget.onBack,
          trailing: AppChip(label: 'القبطي', selected: coptic, onTap: _toggleCoptic),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) {
              final p = _pieces[i];
              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(p.title, style: context.heading(size: 21))),
                  for (final l in p.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: l.rubric
                          ? Text(l.arabic, style: TextStyle(fontSize: 13, height: 1.7, fontWeight: FontWeight.w500, color: c.accent))
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.arabic, style: context.scripture(size: 19)),
                              if (coptic && l.coptic != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(l.coptic!, style: TextStyle(fontSize: 14, height: 1.7, color: c.textFaint)),
                                ),
                            ]),
                    ),
                  if (i == count - 1) Text('النص: st-takla.org', style: TextStyle(fontSize: 11, color: c.textFaint)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          AppIconButton(icon: Icon(Icons.chevron_right, color: _i > 0 ? c.text : c.textFaint), label: 'السابق', onTap: () => _go(-1)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AppSlider(
                value: count > 1 ? _i / (count - 1) : 0,
                onChanged: (v) => _pages.jumpToPage((v * (count - 1)).round()),
              ),
            ),
          ),
          AppIconButton(icon: Icon(Icons.chevron_left, color: _i < count - 1 ? c.text : c.textFaint), label: 'التالي', onTap: () => _go(1)),
        ]),
      ]),
    );
  }
}
