import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_manager.dart';

class TypingDotsIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const TypingDotsIndicator({
    super.key,
    this.color,
    this.size = 3.5,
  });

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final phase = (progress - index * 0.2) % 1.0;
        final wave = sin(phase * 2 * pi);
        final anim = (wave + 1) / 2;
        final scale = 0.75 + (0.55 * anim);
        final opacity = 0.35 + (0.65 * anim);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final c = widget.color ?? theme.accentColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDot(0, c),
        const SizedBox(width: 2.5),
        _buildDot(1, c),
        const SizedBox(width: 2.5),
        _buildDot(2, c),
      ],
    );
  }
}
