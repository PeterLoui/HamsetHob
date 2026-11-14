import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/bible.dart';
import '../ui/theme.dart';

/// مشاركة الآية كصورة بتصميم المخطوطة، أو نسخها نصاً.
class VerseImage {
  static Future<void> copy(BuildContext context, VerseRef ref, String text) async {
    await Clipboard.setData(ClipboardData(text: '«$text»\n${ref.label}'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
    }
  }

  static Future<void> share(BuildContext context, VerseRef ref, String text) async {
    final colors = context.colors;
    await GoogleFonts.pendingFonts([GoogleFonts.amiri()]);
    final png = await _render(ref, text, colors);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/verse.png');
    await file.writeAsBytes(png);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: '«$text»\n${ref.label}\n— همسة حب',
    ));
  }

  static Future<Uint8List> _render(VerseRef ref, String text, AppColors c) async {
    const w = 1080.0, h = 1350.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));

    // صفحة مخطوطة (أو سهرانية): سطح ثابت، وإطار رفيع مزدوج زي حواشي الكتب
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = c.surface);
    final card = RRect.fromLTRBR(80, 240, w - 80, h - 240, const Radius.circular(24));
    canvas.drawRRect(card, Paint()..color = c.card);
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c.hairline.withValues(alpha: c.hairline.a * 2.2);
    canvas.drawRRect(card, frame);
    canvas.drawRRect(card.deflate(18), frame..strokeWidth = 1.2);

    // النص: يُصغَّر حتى يتسع داخل اللوح
    final maxWidth = card.width - 120;
    var size = 64.0;
    late TextPainter body;
    do {
      body = TextPainter(
        text: TextSpan(text: '«$text»', style: TextStyle(fontSize: size, height: 1.5, color: c.text, fontFamily: GoogleFonts.amiri().fontFamily)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: maxWidth);
      size -= 4;
    } while (body.height > card.height - 260 && size > 30);
    body.paint(canvas, Offset(card.left + 60, card.top + (card.height - body.height) / 2 - 40));

    final refText = TextPainter(
      text: TextSpan(text: ref.label, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w500, color: c.accent)),
      textDirection: TextDirection.rtl,
    )..layout();
    refText.paint(canvas, Offset((w - refText.width) / 2, card.bottom - 130));

    final brand = TextPainter(
      text: TextSpan(text: '♡  همسة حب', style: TextStyle(fontSize: 40, color: c.textSoft)),
      textDirection: TextDirection.rtl,
    )..layout();
    brand.paint(canvas, Offset((w - brand.width) / 2, h - 160));

    final image = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
