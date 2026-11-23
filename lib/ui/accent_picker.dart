import 'package:flutter/material.dart';

import '../data/store.dart';
import 'theme.dart';

/// لون التظليل في الوضع الفاتح: دوائر ملوّنة، والمختار عليه علامة.
class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = AppSettings.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Text('لون التظليل في الوضع الفاتح', style: TextStyle(fontSize: 13, color: c.textFaint)),
      ),
      Wrap(spacing: 12, runSpacing: 10, children: [
        for (final (i, (name, col)) in AppColors.lightAccents.indexed)
          Semantics(
            button: true,
            selected: settings.lightAccent == i,
            label: name,
            child: GestureDetector(
              onTap: () {
                settings.lightAccent = i;
                onChanged();
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(color: settings.lightAccent == i ? c.text : Colors.transparent, width: 2.5),
                    boxShadow: settings.lightAccent == i ? [BoxShadow(color: col.withValues(alpha: .4), blurRadius: 12)] : null,
                  ),
                  child: settings.lightAccent == i ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                ),
                const SizedBox(height: 4),
                Text(name, style: TextStyle(fontSize: 11, color: settings.lightAccent == i ? c.text : c.textFaint)),
              ]),
            ),
          ),
      ]),
    ]);
  }
}
