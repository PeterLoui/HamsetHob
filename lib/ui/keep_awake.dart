import 'package:flutter/widgets.dart';

import '../native/native_bridge.dart';

/// يبقّي الشاشة مفتوحة (من غير قفل تلقائي) طول ما الويدجت ده ظاهر. بيتعدّ، فلو شاشتين اتفتحوا مع بعض
/// (أثناء الانتقال) الشاشة ماتتقفلش غير لما الاتنين يتقفلوا.
class KeepAwake extends StatefulWidget {
  const KeepAwake({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;

  @override
  State<KeepAwake> createState() => _KeepAwakeState();
}

int _holders = 0;

class _KeepAwakeState extends State<KeepAwake> {
  bool _held = false;

  void _sync() {
    if (widget.active == _held) return;
    _held = widget.active;
    _holders += _held ? 1 : -1;
    NativeBridge.keepAwake(_holders > 0);
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(KeepAwake old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    if (_held) {
      _holders -= 1;
      NativeBridge.keepAwake(_holders > 0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
