import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/coptic.dart' show ar;
import '../../data/tasbeha.dart';
import '../../native/native_bridge.dart';
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

Widget _loading() => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));

/// تبويب «تسبحة»: اختصار لتسبحة الليلة ولآخر مكان، وتحتهم التسبحة السنوية والكيهكية.
class TasbehaScreen extends StatefulWidget {
  const TasbehaScreen({super.key, required this.onBack, required this.onOpenBook, required this.onRead});
  final VoidCallback onBack;
  final ValueChanged<TasbehaBook> onOpenBook;
  final void Function(TasbehaBook book, TasbehaDay day, int index) onRead;

  @override
  State<TasbehaScreen> createState() => _TasbehaScreenState();
}

class _TasbehaScreenState extends State<TasbehaScreen> {
  final _library = TasbehaRepository.instance.load();
  final _last = TasbehaRepository.instance.last();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<TasbehaLibrary>(
      future: _library,
      builder: (context, snap) {
        final lib = snap.data;
        return ListView(
          padding: _pagePadding(context),
          children: [
            ScreenHeader('تسبحة', subtitle: 'تسبحة نصف الليل', onBack: widget.onBack),
            if (lib == null)
              _loading()
            else ...[
              Builder(builder: (context) {
                final (book, day) = lib.tonight(DateTime.now());
                return GlassPanel(
                  radius: 14,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  onTap: () => widget.onRead(book, day, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('تسبحة الليلة', style: TextStyle(fontSize: 12, color: c.textFaint)),
                        const SizedBox(height: 2),
                        Text(day.name, style: context.heading(size: 20)),
                        Text('${book.title} · ${day.subtitle}', style: TextStyle(fontSize: 12, color: c.textSoft)),
                      ]),
                    ),
                    Text('ابدأ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
                    Icon(Icons.chevron_left, color: c.text, size: 20),
                  ]),
                );
              }),
              FutureBuilder<TasbehaPosition?>(
                future: _last,
                builder: (context, s) {
                  final p = s.data;
                  if (p == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _Row(
                      title: 'كمّل من حيث وقفت',
                      subtitle: '${p.day.name} · ${p.day.pieces[p.index].title}',
                      onTap: () => widget.onRead(p.book, p.day, p.index),
                    ),
                  );
                },
              ),
              for (final b in lib.books) ...[
                _groupLabel(context, b.title),
                _Row(title: b.title, subtitle: b.subtitle, onTap: () => widget.onOpenBook(b)),
              ],
              const SizedBox(height: 16),
              Text(lib.source, style: TextStyle(fontSize: 11, color: c.textFaint)),
            ],
          ],
        );
      },
    );
  }
}

/// أيام التسبحة (السنوية أو الكيهكية)، ويوم النهارده عليه علامة.
class TasbehaBookScreen extends StatelessWidget {
  const TasbehaBookScreen({super.key, required this.book, required this.onBack, required this.onOpenDay});
  final TasbehaBook book;
  final VoidCallback onBack;
  final ValueChanged<TasbehaDay> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday % 7; // الأحد = ٠
    return ListView(
      padding: _pagePadding(context),
      children: [
        ScreenHeader(book.title, subtitle: book.subtitle, onBack: onBack),
        for (var i = 0; i < book.days.length; i++)
          _Row(
            title: book.days[i].name,
            subtitle: book.days[i].subtitle,
            badge: i == today ? 'اليوم' : null,
            onTap: () => onOpenDay(book.days[i]),
          ),
      ],
    );
  }
}

/// فهرس اليوم: الأجزاء بالترتيب، وكل قطعة بتفتح في القارئ.
class TasbehaDayScreen extends StatelessWidget {
  const TasbehaDayScreen({super.key, required this.book, required this.day, required this.onBack, required this.onOpenPiece});
  final TasbehaBook book;
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
        ScreenHeader(day.name, subtitle: '${book.title} · ${day.subtitle}', onBack: onBack),
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
/// زرار الفهرس (أو السحب من حافة الشاشة) بيفتح لوح من الجنب فيه كل الأيام والألحان.
/// الشاشة ماتطفيش طول ما القارئ مفتوح، وحجم الخط بيتحفظ.
class TasbehaReaderScreen extends StatefulWidget {
  const TasbehaReaderScreen({super.key, required this.book, required this.day, required this.index, required this.onBack});
  final TasbehaBook book;
  final TasbehaDay day;
  final int index;
  final VoidCallback onBack;

  @override
  State<TasbehaReaderScreen> createState() => _TasbehaReaderScreenState();
}

class _TasbehaReaderScreenState extends State<TasbehaReaderScreen> {
  static const _copticKey = 'tasbeha_show_coptic';
  static const _scaleKey = 'tasbeha_scale';
  static bool? _showCoptic;
  static double _scale = 1;
  String? _scrub; // اسم اللحن اللي هتوصله وأنت بتسحب الشريط
  Timer? _scrubTimer;
  double _edgeDrag = 0;
  late TasbehaBook _book = widget.book;
  late TasbehaDay _day = widget.day;
  late List<TasbehaPiece> _pieces = _day.pieces;
  late PageController _pages = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void initState() {
    super.initState();
    TasbehaRepository.instance.saveLast(_book, _day, _i);
    NativeBridge.keepScreenOn(true);
    if (_showCoptic == null) {
      SharedPreferences.getInstance().then((p) {
        if (mounted) {
          setState(() {
            _showCoptic = p.getBool(_copticKey) ?? true;
            _scale = p.getDouble(_scaleKey) ?? 1;
          });
        }
      });
    }
  }

  void _setScale(double v) {
    final next = (v * 20).round() / 20; // خطوات ٥٪
    setState(() => _scale = next.clamp(.85, 1.6));
    SharedPreferences.getInstance().then((p) => p.setDouble(_scaleKey, _scale));
  }

  void _scrubTo(double v) {
    final count = _pieces.length;
    final i = (v * (count - 1)).round();
    _pages.jumpToPage(i);
    _scrubTimer?.cancel();
    setState(() => _scrub = '${_day.sectionOf(i)} · ${_pieces[i].title}');
    _scrubTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _scrub = null);
    });
  }

  /// خيارات القراءة: حجم الخط والقبطي المعرّب.
  void _openOptions() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void change(VoidCallback f) {
            f();
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('خيارات القراءة', style: context.heading(size: 20)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('حجم الخط', style: TextStyle(fontSize: 15, color: c.text))),
                  AppIconButton(
                    icon: Text('أ-', style: TextStyle(fontSize: 15, color: c.text)),
                    label: 'تصغير الخط',
                    onTap: () => change(() => _setScale(_scale - .1)),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text('${ar((_scale * 100).round())}٪',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textSoft)),
                  ),
                  AppIconButton(
                    icon: Text('أ+', style: TextStyle(fontSize: 19, color: c.text)),
                    label: 'تكبير الخط',
                    onTap: () => change(() => _setScale(_scale + .1)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('السلام لك يا مريم الحمامة الحسنة', style: context.scripture(size: 19 * _scale)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('القبطي المعرّب', style: TextStyle(fontSize: 15, color: c.text)),
                      Text('تحت كل ربع بخط أصغر', style: TextStyle(fontSize: 12, color: c.textFaint)),
                    ]),
                  ),
                  AppSwitch(value: _showCoptic ?? true, label: 'القبطي المعرّب', onChanged: (_) => change(_toggleCoptic)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
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

  /// قفزة من الفهرس الجانبي: لنفس اليوم بيقلب للصفحة، وليوم تاني بيبدّل اليوم كله.
  void _jump(TasbehaBook book, TasbehaDay day, int index) {
    if (identical(day, _day)) {
      _pages.jumpToPage(index);
      return;
    }
    final old = _pages;
    setState(() {
      _book = book;
      _day = day;
      _pieces = day.pieces;
      _i = index;
      _pages = PageController(initialPage: index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    TasbehaRepository.instance.saveLast(book, day, index);
  }

  Future<void> _openIndex() async {
    final lib = await TasbehaRepository.instance.load();
    if (!mounted) return;
    await showTasbehaIndex(context, library: lib, book: _book, day: _day, index: _i, onPick: _jump);
  }

  @override
  void dispose() {
    NativeBridge.keepScreenOn(false);
    _scrubTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final count = _pieces.length;
    final coptic = _showCoptic ?? true;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(fit: StackFit.expand, children: [
      Padding(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 8),
      child: Column(children: [
        ScreenHeader(
          _day.sectionOf(_i),
          subtitle: '${_day.name} · ${ar(_i + 1)} من ${ar(count)}',
          onBack: widget.onBack,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: Icon(Icons.text_fields, color: c.text),
              tooltip: 'خيارات القراءة',
              onPressed: _openOptions,
            ),
            IconButton(
              icon: Icon(Icons.format_list_bulleted, color: c.text),
              tooltip: 'كل الألحان',
              onPressed: _openIndex,
            ),
          ]),
        ),
        Expanded(
          child: PageView.builder(
            key: ValueKey('${_book.id}/${_day.id}'),
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) {
              setState(() => _i = i);
              TasbehaRepository.instance.saveLast(_book, _day, i);
            },
            itemBuilder: (context, i) {
              final p = _pieces[i];
              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(p.title, style: context.heading(size: 21 * _scale))),
                  for (final l in p.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: l.rubric
                          ? Text(l.arabic, style: TextStyle(fontSize: 13 * _scale, height: 1.7, fontWeight: FontWeight.w500, color: c.accent))
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.arabic, style: context.scripture(size: 19 * _scale)),
                              if (coptic && l.coptic != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(l.coptic!, style: TextStyle(fontSize: 14 * _scale, height: 1.7, color: c.textFaint)),
                                ),
                            ]),
                    ),
                  if (i == count - 1) Text('النص: st-takla.org', style: TextStyle(fontSize: 11, color: c.textFaint)),
                ],
              );
            },
          ),
        ),
        // وأنت بتسحب الشريط: اسم اللحن اللي هتوصله
        AnimatedOpacity(
          opacity: _scrub == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(8)),
            child: Text(_scrub ?? ' ',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.surface)),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          AppIconButton(icon: Icon(Icons.chevron_right, color: _i > 0 ? c.text : c.textFaint), label: 'السابق', onTap: () => _go(-1)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AppSlider(
                value: count > 1 ? _i / (count - 1) : 0,
                onChanged: count > 1 ? _scrubTo : (_) {},
              ),
            ),
          ),
          AppIconButton(icon: Icon(Icons.chevron_left, color: _i < count - 1 ? c.text : c.textFaint), label: 'التالي', onTap: () => _go(1)),
        ]),
      ]),
      ),
      // السحب من حافة الشاشة (ناحية البداية) لجوه بيفتح الفهرس الجانبي
      PositionedDirectional(
        start: 0,
        top: pad.top + 80,
        bottom: 120,
        width: 22,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _edgeDrag = 0,
          onHorizontalDragUpdate: (d) => _edgeDrag += rtl ? -d.delta.dx : d.delta.dx,
          onHorizontalDragEnd: (_) {
            if (_edgeDrag > 36) _openIndex();
          },
        ),
      ),
    ]);
  }
}

/// الفهرس الجانبي: لوح بيطلع من الجنب فيه السنوية والكيهكية وكل الأيام والألحان.
/// اليوم المفتوح متفرد ومكانك عليه علامة، وأي لحن بلمسة واحدة.
Future<void> showTasbehaIndex(
  BuildContext context, {
  required TasbehaLibrary library,
  required TasbehaBook book,
  required TasbehaDay day,
  required int index,
  required void Function(TasbehaBook book, TasbehaDay day, int index) onPick,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق الفهرس',
    barrierColor: Colors.black.withValues(alpha: .35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, __) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: _TasbehaIndex(library: library, book: book, day: day, index: index, onPick: onPick),
    ),
    transitionBuilder: (context, anim, _, child) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return SlideTransition(
        position: Tween(begin: Offset(rtl ? 1 : -1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: const Cubic(0.22, 1, 0.36, 1))),
        child: child,
      );
    },
  );
}

class _TasbehaIndex extends StatefulWidget {
  const _TasbehaIndex({required this.library, required this.book, required this.day, required this.index, required this.onPick});
  final TasbehaLibrary library;
  final TasbehaBook book;
  final TasbehaDay day;
  final int index;
  final void Function(TasbehaBook book, TasbehaDay day, int index) onPick;

  @override
  State<_TasbehaIndex> createState() => _TasbehaIndexState();
}

class _TasbehaIndexState extends State<_TasbehaIndex> {
  late TasbehaBook _book = widget.book;
  late String? _open = widget.day.id;
  final _current = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _current.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .3);
    });
  }

  void _pick(TasbehaDay day, int i) {
    Navigator.of(context).pop();
    widget.onPick(_book, day, i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final width = (MediaQuery.sizeOf(context).width * .86).clamp(0.0, 380.0);
    return Material(
      color: c.surface,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('كل الألحان', style: context.heading(size: 22)),
            const SizedBox(height: 12),
            AppSegmented(
              labels: [for (final b in widget.library.books) b.title.replaceFirst('التسبحة ', '')],
              selectedIndex: widget.library.books.indexOf(_book),
              onSelected: (i) => setState(() {
                _book = widget.library.books[i];
                _open = null;
              }),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: pad.bottom + 24),
                children: [
                  for (final d in _book.days) ..._dayGroup(context, c, d),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _dayGroup(BuildContext context, AppColors c, TasbehaDay d) {
    final open = _open == d.id;
    final here = identical(_book, widget.book) && identical(d, widget.day);
    final out = <Widget>[
      InkWell(
        onTap: () => setState(() => _open = open ? null : d.id),
        child: Container(
          height: 48,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
          child: Row(children: [
            Expanded(
              child: Text(d.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
            ),
            if (here) Text('أنت هنا', style: TextStyle(fontSize: 12, color: c.accent)),
            const SizedBox(width: 6),
            Icon(open ? Icons.expand_less : Icons.expand_more, color: c.textFaint, size: 20),
          ]),
        ),
      ),
    ];
    if (!open) return out;
    var n = 0;
    for (final s in d.sections) {
      out.add(Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, top: 10, bottom: 2),
        child: Text(s.title, style: TextStyle(fontSize: 12, color: c.textFaint)),
      ));
      for (final p in s.pieces) {
        final i = n++;
        final current = here && i == widget.index;
        out.add(InkWell(
          key: current ? _current : null,
          onTap: () => _pick(d, i),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
            decoration: current ? BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(8)) : null,
            child: Text(p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 1.5, color: current ? c.text : c.textSoft, fontWeight: current ? FontWeight.w500 : FontWeight.w400)),
          ),
        ));
      }
    }
    return out;
  }
}
