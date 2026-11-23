import 'package:flutter/material.dart';

import '../core/coptic.dart';
import '../data/updater.dart';
import 'theme.dart';

/// شاشة التحديث: ملاحظات النسخة، تنزيل بشريط تقدّم، وبعدها شاشة التركيب بتاعة النظام.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _UpdateDialog(info: info));

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

    final (body, actions) = switch (_phase) {
      _Phase.ask => (
          null,
          [
            TextButton(onPressed: _later, child: const Text('لاحقاً')),
            FilledButton(onPressed: _go, child: const Text('تحديث الآن')),
          ],
        ),
      _Phase.downloading => (
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            Text('جارٍ التنزيل… ${ar((_progress * 100).round())}٪', style: TextStyle(color: c.text)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null, color: c.live, backgroundColor: c.chip),
          ]),
          [
            TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
          ],
        ),
      _Phase.needsPermission => (
          Text('فتحنا إعدادات «تثبيت التطبيقات من هذا المصدر». اسمح لهمسة حب، وارجع واضغط «تحديث» تاني.',
              style: TextStyle(height: 1.6, color: c.textSoft)),
          [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            FilledButton(onPressed: _go, child: const Text('تحديث')),
          ],
        ),
      _Phase.installing => (
          Text('ظهرت شاشة التركيب. وافق عليها وهيتحدّث التطبيق ويتفتح من جديد.', style: TextStyle(height: 1.6, color: c.textSoft)),
          [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        ),
      _Phase.failed => (
          Text('تعذّر التحديث. تأكد من الاتصال بالإنترنت وحاول تاني.', style: TextStyle(height: 1.6, color: c.saint)),
          [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            FilledButton(onPressed: _go, child: const Text('إعادة المحاولة')),
          ],
        ),
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('نسخة جديدة متاحة'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('همسة حب ${ar(u.version)}$mb', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              if (u.prerelease)
                Text('نسخة تجريبية من فرع قيد التطوير', style: TextStyle(fontSize: 12, color: c.textFaint)),
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
        actions: actions,
      ),
    );
  }
}
