import 'package:flutter/material.dart';

import '../data/saint_images.dart';

/// صورة تذكار: بتتحمّل من ويكيميديا (نسخة مصغّرة، وبتتحفظ على الجهاز)، ولو فشلت بيظهر [fallback].
class SaintPhoto extends StatelessWidget {
  const SaintPhoto({super.key, required this.url, required this.fallback, this.alignment = Alignment.center, this.width, this.height});
  final String url;
  final Widget fallback;
  final Alignment alignment;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SaintImages.instance.loadBytes(url),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final bytes = snap.data;
        if (bytes == null) return fallback;
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: width,
          height: height,
          alignment: alignment,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}
