import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/coptic.dart';
import '../data/updater.dart';
import 'theme.dart';

/// شاشة التحديث: ملاحظات النسخة، تنزيل بشريط تقدّم، وبعدها شاشة التركيب بتاعة النظام.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (_) => _UpdateDialog(info: info),
    );

enum _Phase { ask, downloading, needsPermission, installing, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.ask;
  double _progress = 0;
  String? _path;
  bool _cancelled = false;

  Future<void> _go() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    try {
      final path = _path ??= await Updater.instance.download(widget.info, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (_cancelled || !mounted) return;
      final r = await Updater.instance.install(path);
      if (!mounted) return;
      setState(() => _phase = switch (r) {
            InstallResult.started => _Phase.installing,
            InstallResult.needsPermission => _Phase.needsPermission,
            InstallResult.failed => _Phase.failed,
          });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  void _later() {
    Updater.instance.dismiss(widget.info.build);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = widget.info;
    final mb = u.size > 0 ? ' • ${ar((u.size / (1024 * 1024)).round())} ميجا' : '';
    final notes = u.notes.length > 700 ? '${u.notes.substring(0, 700)}…' : u.notes;

    // الزرار الرئيسي فوق، والتانوي كلمة مكتوبة تحته (مش زرار)
    final (body, primary, secondary) = switch (_phase) {
      _Phase.ask => (null, ('تحديث الآن', _go), ('لاحقاً', _later)),
      _Phase.downloading => (
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            Text('جارٍ التنزيل… ${ar((_progress * 100).round())}٪', style: TextStyle(color: c.text)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null, color: c.live, backgroundColor: c.text.withValues(alpha: .12)),
          ]),
          null,
          (
            'إلغاء',
            () {
              _cancelled = true;
              Navigator.pop(context);
            }
          ),
        ),
      _Phase.needsPermission => (
          Text('فتحنا إعدادات «تثبيت التطبيقات من هذا المصدر». اسمح لهمسة حب، وارجع واضغط «تحديث» تاني.',
              style: TextStyle(height: 1.6, color: c.textSoft)),
          ('تحديث', _go),
          ('إغلاق', () => Navigator.pop(context)),
        ),
      _Phase.installing => (
          Text('ظهرت شاشة التركيب. وافق عليها وهيتحدّث التطبيق ويتفتح من جديد.', style: TextStyle(height: 1.6, color: c.textSoft)),
          null,
          ('إغلاق', () => Navigator.pop(context)),
        ),
      _Phase.failed => (
          Text('تعذّر التحديث. تأكد من الاتصال بالإنترنت وحاول تاني.', style: TextStyle(height: 1.6, color: c.saint)),
          ('إعادة المحاولة', _go),
          ('إغلاق', () => Navigator.pop(context)),
        ),
    };

    final glow = c.navGlow;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: glow.withValues(alpha: c.isDark ? .22 : .16), blurRadius: 36, spreadRadius: -2)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            // زجاج مصنفر: الخلفية بتتغبّش وفوقها طبقة شفافة بتدرّج خفيف وحافة لامعة
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: c.isDark
                        ? [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .06)]
                        : [Colors.white.withValues(alpha: .78), Colors.white.withValues(alpha: .46)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: c.isDark ? .22 : .7), width: 1),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('نسخة جديدة متاحة', style: context.heading(size: 22)),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('همسة حب ${ar(u.version)}$mb', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                          if (u.prerelease) Text('نسخة تجريبية من فرع قيد التطوير', style: TextStyle(fontSize: 12, color: c.textFaint)),
                          if (_phase == _Phase.ask && notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('الجديد', style: TextStyle(fontSize: 12, color: c.textFaint)),
                            const SizedBox(height: 4),
                            Text(notes, style: TextStyle(fontSize: 13, height: 1.6, color: c.textSoft)),
                          ],
                          if (body != null) body,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (primary != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: glow.withValues(alpha: .35), blurRadius: 18)],
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: glow,
                            foregroundColor: c.isDark ? const Color(0xFF14120F) : Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: primary.$2,
                          child: Text(primary.$1),
                        ),
                      ),
                    // «لاحقاً»: كلمة مكتوبة مش زرار
                    InkWell(
                      onTap: secondary.$2,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: Text(secondary.$1, style: TextStyle(fontSize: 14, color: c.textSoft))),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
