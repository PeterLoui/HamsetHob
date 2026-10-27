import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'native_bridge.dart';

/// زجاج الويدجتس: أكثر ضبابية (frosted) لأنه يجلس فوق خلفية الشاشة الرئيسية.
const widgetGlassSettings = LiquidGlassSettings(
  thickness: 30,
  blur: 18,
  glassColor: Color(0x38FFFFFF),
  lightIntensity: .8,
  saturation: 1.5,
  refractiveIndex: 1.3,
  chromaticAberration: .015,
);

/// يرسم سطح الويدجت بحزمة liquid_glass_widgets خارج الشاشة (خلف الخلفية)
/// ثم يحفظه صورة PNG شفافة يستخدمها ويدجت أندرويد خلفيةً، فيطابق زجاج التطبيق.
class WidgetGlassCapture extends StatefulWidget {
  const WidgetGlassCapture({super.key});

  @override
  State<WidgetGlassCapture> createState() => _WidgetGlassCaptureState();
}

class _WidgetGlassCaptureState extends State<WidgetGlassCapture> {
  final _verseKey = GlobalKey();
  final _lockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // ننتظر حتى تجهز الـ shaders ويُرسم الإطار
    Timer(const Duration(milliseconds: 1200), _capture);
  }

  Future<void> _capture() async {
    for (final (key, kind) in [(_verseKey, 'verse'), (_lockKey, 'lock')]) {
      final boundary = key.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) continue;
      try {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) await NativeBridge.setWidgetGlass(kind, bytes.buffer.asUint8List());
      } catch (_) {
        // يبقى الويدجت على خلفيته الاحتياطية
      }
    }
  }

  Widget _surface(GlobalKey key, double w, double h) => RepaintBoundary(
        key: key,
        child: SizedBox(
          width: w,
          height: h,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: GlassContainer(
              useOwnLayer: true,
              settings: widgetGlassSettings,
              shape: const LiquidRoundedSuperellipse(borderRadius: 28),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _surface(_verseKey, 340, 170),
          _surface(_lockKey, 340, 200),
        ]),
      );
}
