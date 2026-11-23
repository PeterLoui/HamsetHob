import 'dart:async';

import 'package:flutter/material.dart';

import '../core/coptic.dart' show ar;
import '../data/store.dart';
import 'theme.dart';

/// قرص بإصبعين على أي شاشة يكبّر أو يصغّر خط القراءة (نفس مقياس خيارات القراءة، ومتحفوظ).
///
/// - الحساب من المسافة بين الإصبعين، بخطوات ٢٪ وفي حدود ٨٠٪ لـ ١٧٠٪.
/// - أثناء القرص التمرير بيتقفل (عشان الصفحة ماتجريش تحت صوابعك) وبيرجع أول ما ترفع إصبع.
/// - بيظهر رقم النسبة لحظة القرص.
/// الشاشات بتقرا المقياس في كل رسم، فالشِل بيعيد بناء المحتوى مع كل خطوة.
class PinchZoom extends StatefulWidget {
  const PinchZoom({super.key, required this.child});
  final Widget child;

  static const min = 0.8, max = 1.7, step = 0.02;

  /// المقياس الجديد من المسافة الحالية والأصلية بين الإصبعين، بخطوات ثابتة وفي الحدود.
  static double scaleFor(double base, double distance, double startDistance) {
    final v = (base * distance / startDistance).clamp(min, max);
    return (v / step).round() * step;
  }

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  final _pointers = <int, Offset>{};
  double? _startDistance;
  double _startScale = 1;
  bool _pinching = false;
  bool _labelVisible = false;
  Timer? _hide;

  double get _distance {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _hide?.cancel();
      _startDistance = _distance;
      _startScale = AppSettings.instance.readingScale;
      setState(() => _pinching = true);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _startDistance;
    if (_pointers.length < 2 || start == null || start < 24) return;
    final v = PinchZoom.scaleFor(_startScale, _distance, start);
    if ((v - AppSettings.instance.readingScale).abs() > 1e-6) {
      AppSettings.instance.readingScale = v;
    }
    if (!_labelVisible) setState(() => _labelVisible = true);
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinching) {
      _startDistance = null;
      setState(() => _pinching = false);
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _labelVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final percent = (AppSettings.instance.readingScale * 100).round();
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: ScrollConfiguration(
        // أثناء القرص مافيش تمرير
        behavior: ScrollConfiguration.of(context).copyWith(physics: _pinching ? const NeverScrollableScrollPhysics() : null),
        child: Stack(children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 72,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _labelVisible ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Text('حجم الخط ${ar(percent)}٪',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text, decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
