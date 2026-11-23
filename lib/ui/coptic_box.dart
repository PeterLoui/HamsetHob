import 'package:flutter/material.dart';

import 'theme.dart';

/// القبطي المعرّب (بحروف عربية) في مربع منفصل تحت النص العربي.
///
/// بخط أصغر ولون مختلف وخط جانبي وكلمة «قبطي»، عشان القارئ ما يخلطش بينه وبين العربي.
class CopticBox extends StatelessWidget {
  const CopticBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.readingScale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: c.chip.withValues(alpha: .6),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 3, color: c.accent.withValues(alpha: .75)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('قبطي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accent)),
                  const SizedBox(height: 4),
                  Text(text, style: TextStyle(fontSize: 15.5 * s, height: 1.9, color: c.textSoft)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
