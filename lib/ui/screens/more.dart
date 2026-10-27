import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/coptic.dart';
import '../../data/bible.dart';
import '../../data/store.dart';
import '../../native/native_bridge.dart';
import '../glass.dart';
import '../theme.dart';
import 'home.dart' show VerseActions;

/// المزيد: المفضلة والإعدادات وتحميل الكتاب المقدس.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.onOpenFavorites, required this.onSettingsChanged});
  final VoidCallback onOpenFavorites;
  final VoidCallback onSettingsChanged;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final settings = AppSettings.instance;
  bool? _offline;
  double? _progress;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    BibleRepository.instance.isOffline().then((v) {
      if (mounted) setState(() => _offline = v);
    });
  }

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _downloadError = null;
    });
    try {
      await BibleRepository.instance.downloadOffline((p) {
        if (mounted) setState(() => _progress = p);
      });
      _offline = await BibleRepository.instance.isOffline();
    } catch (e) {
      _downloadError = 'تعذّر التحميل، حاول مرة أخرى';
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.morningMinutes ~/ 60, minute: settings.morningMinutes % 60),
    );
    if (t == null) return;
    settings.morningMinutes = t.hour * 60 + t.minute;
    NativeBridge.scheduleMorning(settings.morningEnabled, settings.morningMinutes);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = settings.morningMinutes ~/ 60, m = settings.morningMinutes % 60;
    final time = '${ar(h % 12 == 0 ? 12 : h % 12)}:${ar(m.toString().padLeft(2, '0'))} ${h < 12 ? 'صباحاً' : 'مساءً'}';

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 24),
        children: [
          const ScreenHeader('المزيد'),
          _group(null, [
            _item('♡  المفضلة', '${ar(Favorites.instance.items.length)} آية محفوظة', widget.onOpenFavorites),
          ]),
          _label('المظهر'),
          GlassSegmentedControl(
            segments: [for (final t in ThemeChoice.values) GlassSegment(label: t.label)],
            selectedIndex: settings.theme.index,
            onSegmentSelected: (i) {
              settings.theme = ThemeChoice.values[i];
              widget.onSettingsChanged();
            },
          ),
          const SizedBox(height: 10),
          _toggle('ألوان المواسم الكنسية', 'بنفسجي في الأصوام وذهبي في الأعياد', settings.seasonalColors, (v) {
            settings.seasonalColors = v;
            widget.onSettingsChanged();
          }),
          _toggle('خط أميري للآيات', 'خط عربي جميل للنصوص المقدسة', settings.scriptureFont, (v) => settings.scriptureFont = v),
          _label('الإشعارات'),
          _toggle('رسالة الصباح', 'إشعار يومي برسالة اليوم', settings.morningEnabled, (v) {
            settings.morningEnabled = v;
            NativeBridge.scheduleMorning(v, settings.morningMinutes);
          }),
          if (settings.morningEnabled) _group(null, [_item('وقت الإشعار', time, _pickTime)]),
          _toggle('شاشة القفل', 'التاريخ القبطي ورسالة اليوم في إشعار هادئ', settings.lockNotification, (v) {
            settings.lockNotification = v;
            widget.onSettingsChanged();
          }),
          _label('الكتاب المقدس بدون إنترنت'),
          _group(null, [
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('جارٍ التحميل… ${ar((_progress! * 100).round())}٪', style: TextStyle(color: c.text)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress, color: c.accent, backgroundColor: c.chip),
                ]),
              )
            else if (_offline == true)
              _item('الكتاب محمّل على الجهاز ✓', 'اضغط لحذفه وتوفير المساحة', () async {
                await BibleRepository.instance.deleteOffline();
                setState(() => _offline = false);
              })
            else
              _item(_downloadError ?? 'تحميل الكتاب كاملاً', 'حوالي ٢٫٤ ميجا • يتيح القراءة والبحث بدون إنترنت', _download),
          ]),
          const SizedBox(height: 16),
          Text(
            'النصوص: ترجمة فاندايك (bolls.life) • القطمارس والسنكسار: katameros.app • العظات: popeshenouda.org.eg • الصور: ويكيبيديا',
            style: TextStyle(fontSize: 11, height: 1.6, color: c.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.accent)),
      );

  Widget _group(String? title, List<Widget> children) => GlassPanel(
        radius: 26,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      );

  Widget _item(String title, String subtitle, VoidCallback onTap) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textSoft),
        ]),
      ),
    );
  }

  /// مفتاح زجاجي — خارج أي بطاقة زجاجية كما توصي الحزمة.
  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
          ]),
        ),
        GlassSwitch(value: value, onChanged: onChanged, activeColor: c.accent, semanticLabel: title),
      ]),
    );
  }
}

/// الآيات المحفوظة.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onOpenChapter, required this.onBack});
  final ValueChanged<VerseRef> onOpenChapter;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final items = Favorites.instance.items;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 32),
          children: [
            ScreenHeader('المفضلة', subtitle: 'الآيات التي حفظتها', onBack: onBack),
            if (items.isEmpty)
              Text('لم تحفظ آيات بعد. اضغط ♡ بجوار رسالة اليوم أو على أي آية في الإصحاح.',
                  style: TextStyle(height: 1.6, color: c.textSoft)),
            for (final f in items) ...[
              GlassPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                onTap: () => onOpenChapter(f.ref),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('«${f.text}»', style: context.scripture(size: 18)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text(f.ref.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent))),
                    VerseActions(ref: f.ref, text: f.text, showCopy: true),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
