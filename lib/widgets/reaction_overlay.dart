import 'dart:math';
import 'package:flutter/material.dart';

class FloatingReactionModel {
  final Key key;
  final String emoji;
  final double startX;
  final double swayAmount;
  final double size;

  FloatingReactionModel({
    required this.key,
    required this.emoji,
    required this.startX,
    required this.swayAmount,
    required this.size,
  });
}

class ReactionItemWidget extends StatefulWidget {
  final FloatingReactionModel item;
  final VoidCallback onComplete;

  const ReactionItemWidget({
    super.key,
    required this.item,
    required this.onComplete,
  });

  @override
  State<ReactionItemWidget> createState() => _ReactionItemWidgetState();
}

class _ReactionItemWidgetState extends State<ReactionItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final progressVal = _progress.value;
        final dy = progressVal * 320.0;
        final dx = sin(progressVal * pi * 3.5) * widget.item.swayAmount;
        final opacity = (1.0 - progressVal * 0.9).clamp(0.0, 1.0);
        final scale = 0.7 + (progressVal * 0.6);

        return Positioned(
          bottom: 70 + dy,
          left: (widget.item.startX + dx).clamp(20.0, 360.0),
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  widget.item.emoji,
                  style: TextStyle(fontSize: widget.item.size),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
