import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  const AudioVisualizerWidget({super.key, required this.isPlaying});

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (index) {
              final heightFactor = widget.isPlaying
                  ? math.sin((_controller.value * 2 * math.pi) + (index * 0.3)).abs() * 0.8 + 0.2
                  : 0.1;
              return Container(
                width: 6,
                height: 70 * heightFactor,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}