import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/coptic.dart';
import '../../core/synaxarium.dart';
import '../../data/katameros.dart';
import '../../data/net.dart' show normalizeArabic;
import '../../data/saint_images.dart';
import '../glass.dart';
import '../theme.dart';

/// شريط التاريخ: اليوم السابق/التالي.
class DateSwitcher extends StatelessWidget {
  const DateSwitcher({super.key, required this.date, required this.onChange});
  final DateTime date;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final coptic = CopticDate.fromGregorian(date);
    return GlassPanel(
      radius: 26,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        RoundAction(
          icon: Icon(Icons.chevron_right, color: c.text),
          onTap: () => onChange(date.subtract(const Duration(days: 1))),
          tooltip: 'اليوم السابق',
          size: 44,
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(date.year - 3),
                lastDate: DateTime(date.year + 3),
                helpText: 'اختر اليوم',
              );
              if (picked != null) onChange(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                Text(coptic.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                Text('${weekdayName(date)} ${gregorianLabel(date)}', style: TextStyle(fontSize: 12, color: c.textSoft)),
              ]),
            ),
          ),
        ),
        RoundAction(
          icon: Icon(Icons.chevron_left, color: c.text),
          onTap: () => onChange(date.add(const Duration(days: 1))),
          tooltip: 'اليوم التالي',
          size: 44,
        ),
      ]),
    );
  }
}

/// قراءات القطمارس اليومية.
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key, required this.today, required this.onOpenSynaxarium});
  final DateTime today;
  final ValueChanged<DateTime> onOpenSynaxarium;

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  late DateTime _date = widget.today;
  late Future<DayReadings> _future = KatamerosRepository.instance.day(_date);
  final _open = <String>{};

  @override
  void didUpdateWidget(ReadingsScreen old) {
    super.didUpdateWidget(old);
    // اليوم اتغيّر وهو واقف على «النهارده»: ننقله لليوم الجديد
    if (dateOnly(old.today) != dateOnly(widget.today) && dateOnly(_date) == dateOnly(old.today)) _setDate(widget.today);
  }

  void _setDate(DateTime d) => setState(() {
        _date = d;
        _future = KatamerosRepository.instance.day(d);
        _open.clear();
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 24),
      children: [
        const ScreenHeader('القراءات', subtitle: 'القطمارس اليومي'),
        DateSwitcher(date: _date, onChange: _setDate),
        const SizedBox(height: 16),
        FutureBuilder<DayReadings>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Column(children: [
                Text('تعذّر تحميل القراءات، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
                const SizedBox(height: 12),
                AppChip(label: 'إعادة المحاولة', onTap: () => _setDate(_date)),
              ]);
            }
            final r = snap.data;
            if (r == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in r.sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(s.title, style: context.heading(size: 20)),
                ),
                for (final g in s.groups) ...[
                  if (g.isSynaxarium) _synaxariumLink(g) else _groupCard('${s.title}/${g.title}', g),
                  const SizedBox(height: 10),
                ],
              ],
            ]);
          },
        ),
      ],
    );
  }

  Widget _groupCard(String id, ReadingGroup g) {
    final c = context.colors;
    final open = _open.contains(id);
    final refs = g.readings.expand((r) => r.passages).map((p) => '${p.book} ${ar(p.ref)}').join(' ، ');
    return GlassPanel(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => open ? _open.remove(id) : _open.add(id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                  if (refs.isNotEmpty) Text(refs, style: TextStyle(fontSize: 12, color: c.textSoft)),
                ]),
              ),
              Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.textSoft),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (g.introduction != null) _faint(g.introduction!),
              for (final r in g.readings) ...[
                if (r.introduction != null) _faint(r.introduction!),
                for (final p in r.passages) ...[
                  Text('${p.book} ${ar(p.ref)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                  const SizedBox(height: 4),
                  Text(p.text, style: context.scripture(size: 18)),
                  const SizedBox(height: 12),
                ],
                if (r.conclusion != null) _faint(r.conclusion!),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _faint(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 13, height: 1.6, color: context.colors.textFaint)),
      );

  Widget _synaxariumLink(ReadingGroup g) {
    final c = context.colors;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () => widget.onOpenSynaxarium(_date),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('السنكسار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            Text(g.readings.map((r) => r.title).whereType<String>().join(' • '),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSoft)),
          ]),
        ),
        const SizedBox(width: 8),
        Pill('اقرأ السير  ‹', onTap: () => widget.onOpenSynaxarium(_date)),
      ]),
    );
  }
}

/// سير قديسي اليوم كاملة.
class SynaxariumScreen extends StatefulWidget {
  const SynaxariumScreen({super.key, required this.start, required this.onBack, this.onBrowse});
  final DateTime start;
  final VoidCallback onBack;
  final VoidCallback? onBrowse;

  @override
  State<SynaxariumScreen> createState() => _SynaxariumScreenState();
}

class _SynaxariumScreenState extends State<SynaxariumScreen> {
  late DateTime _date = widget.start;
  late Future<DayReadings> _future = KatamerosRepository.instance.day(_date);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        ScreenHeader(
          'السنكسار',
          subtitle: 'سير القديسين وتذكاراتهم',
          onBack: widget.onBack,
          trailing: widget.onBrowse == null
              ? null
              : IconButton(icon: Icon(Icons.search, color: c.text), tooltip: 'الأعياد والقديسين', onPressed: widget.onBrowse),
        ),
        DateSwitcher(
          date: _date,
          onChange: (d) => setState(() {
            _date = d;
            _future = KatamerosRepository.instance.day(d);
          }),
        ),
        const SizedBox(height: 16),
        FutureBuilder<DayReadings>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return Text('تعذّر تحميل السنكسار، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft));
            final stories = snap.data?.synaxarium;
            if (stories == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            if (stories.isEmpty) return Text('لا يوجد سنكسار لهذا اليوم', style: TextStyle(color: c.textSoft));
            // التذكار الأساسي لليوم ليه صورة متراجعة (ويكيميديا)، والباقي بيتدوّر عليه في صفحة اليوم على st-takla
            final local = Synaxarium.forDate(_date);
            return Column(children: [
              for (final (i, s) in stories.indexed) ...[
                GlassPanel(
                  radius: 26,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SaintFrame(
                      key: ValueKey('${dateOnly(_date)}|${s.title}'),
                      wiki: i == 0 && !local.generic ? local.wiki : null,
                      name: s.title,
                      date: _date,
                      fallbackCross: i == 0,
                    ),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(s.title, style: context.heading(size: 18))),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '${s.title}\n\n${s.text}'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السيرة')));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.copy_rounded, size: 20, color: c.textFaint)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(s.text, style: context.scripture(size: 17)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

/// فهرس الأعياد والقديسين: بحث وتصفّح، ولمسة تفتح سنكسار يوم التذكار.
class SynaxariumBrowseScreen extends StatefulWidget {
  const SynaxariumBrowseScreen({super.key, required this.today, required this.onBack, required this.onOpenDate});
  final DateTime today;
  final VoidCallback onBack;
  final ValueChanged<DateTime> onOpenDate;

  @override
  State<SynaxariumBrowseScreen> createState() => _SynaxariumBrowseScreenState();
}

class _SynaxariumBrowseScreenState extends State<SynaxariumBrowseScreen> {
  late final List<SynaxEntry> _all = Synaxarium.browse(widget.today);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = normalizeArabic(_q.trim());
    final list = q.length < 2
        ? _all
        : _all.where((e) => normalizeArabic('${e.commemoration.title} ${e.commemoration.detail}').contains(q)).toList();
    final rows = <Widget>[];
    var month = 0;
    for (final e in list) {
      if (e.copticMonth != month) {
        month = e.copticMonth;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Text(copticMonths[month - 1], style: TextStyle(fontSize: 13, color: c.textFaint)),
        ));
      }
      final com = e.commemoration;
      rows.add(InkWell(
        onTap: () => widget.onOpenDate(e.date),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Text('${ar(e.copticDay)} ${copticMonths[e.copticMonth - 1]}',
                  style: TextStyle(fontSize: 11, color: c.accent)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(com.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
                Text(com.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textFaint)),
              ]),
            ),
            Icon(Icons.chevron_left, color: c.textFaint, size: 18),
          ]),
        ),
      ));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        ScreenHeader('الأعياد والقديسين', subtitle: 'اختر تذكاراً لتقرأ سيرته', onBack: widget.onBack),
        AppSearchBar(placeholder: 'ابحث عن قديس أو عيد', onChanged: (v) => setState(() => _q = v)),
        if (list.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('مافيش نتيجة لـ «$_q»', style: TextStyle(fontSize: 14, color: c.textSoft)))
        else
          ...rows,
      ],
    );
  }
}

/// صورة القديس جوه إطار مزدوج زي أيقونات حامل الأيقونات: إطار خارجي بلون التذكار وخط رفيع جوه.
/// الصورة من نفس مصادر الرئيسية (SaintImages)، ولو مالقيناش صورة مؤكدة: الصليب القبطي للتذكار الأول، ولا حاجة للباقي.
class SaintFrame extends StatelessWidget {
  const SaintFrame({super.key, required this.wiki, required this.name, required this.date, this.fallbackCross = false});
  final String? wiki;
  final String name;
  final DateTime date;
  final bool fallbackCross;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<String?>(
      future: SaintImages.instance.imageUrl(wiki, name, date),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return fallbackCross ? _frame(c, null, loading: true) : const SizedBox.shrink();
        }
        final url = snap.data;
        if (url == null && !fallbackCross) return const SizedBox.shrink();
        return _frame(c, url);
      },
    );
  }

  Widget _frame(AppColors c, String? url, {bool loading = false}) {
    const w = 196.0, h = 252.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Container(
          width: w,
          height: h,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.navGlow.withValues(alpha: .55), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? .35 : .08), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.hairline),
              color: c.surface,
            ),
            child: loading
                ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.textFaint)))
                : url == null
                    ? _cross()
                    : LayoutBuilder(
                        builder: (context, box) => CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          alignment: SaintImages.focus(wiki, box.maxWidth, box.maxHeight),
                          fadeInDuration: const Duration(milliseconds: 300),
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => _cross(),
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _cross() => Padding(
        padding: const EdgeInsets.all(28),
        child: Opacity(opacity: .3, child: Image.asset('assets/coptic_cross.png', fit: BoxFit.contain)),
      );
}
