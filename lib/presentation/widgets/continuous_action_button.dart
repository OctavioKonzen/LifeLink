import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContinuousActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onHoldAction;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;

  const ContinuousActionButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.onHoldAction,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ContinuousActionButton> createState() => _ContinuousActionButtonState();
}

class _ContinuousActionButtonState extends State<ContinuousActionButton> {
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      widget.onHoldAction();
      HapticFeedback.selectionClick();
    });
  }

  void _stopTimer() => _timer?.cancel();

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // REMOVIDO o Expanded daqui para não quebrar o layout do veneno.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onTap();
        HapticFeedback.lightImpact();
      },
      onLongPressStart: (_) => _startTimer(),
      onLongPressEnd: (_) => _stopTimer(),
      onLongPressCancel: _stopTimer,
      child: Container(
        alignment: widget.alignment,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}