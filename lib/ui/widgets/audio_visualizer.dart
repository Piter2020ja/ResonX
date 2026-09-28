import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final int barCount;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.height = 64.0,
    this.barCount = 32,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _targetHeights;
  late List<double> _currentHeights;

  @override
  void initState() {
    super.initState();
    _targetHeights = List.generate(widget.barCount, (_) => 0.1);
    _currentHeights = List.generate(widget.barCount, (_) => 0.1);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    )..addListener(_updateVisuals);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _updateVisuals() {
    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        if (widget.isPlaying) {
          if ((_currentHeights[i] - _targetHeights[i]).abs() < 0.08) {
            _targetHeights[i] = 0.15 + _random.nextDouble() * 0.85;
          }
          _currentHeights[i] += (_targetHeights[i] - _currentHeights[i]) * 0.25;
        } else {
          _currentHeights[i] += (0.05 - _currentHeights[i]) * 0.15;
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      // Nie zatrzymujemy od razu, pozwalamy opaść do zera
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _VisualizerPainter(
          heights: _currentHeights,
          barCount: widget.barCount,
        ),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> heights;
  final int barCount;

  _VisualizerPainter({required this.heights, required this.barCount});

  @override
  void paint(Canvas canvas, Size size) {
    final double totalSpacing = size.width * 0.2;
    final double barSpacing = totalSpacing / (barCount - 1);
    final double barWidth = (size.width - totalSpacing) / barCount;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          ResonXColors.cyberJade,
          ResonXColors.neonCyan,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < barCount; i++) {
      final double barHeight = (heights[i] * size.height).clamp(4.0, size.height);
      final double left = i * (barWidth + barSpacing);
      final double top = size.height - barHeight;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) => true;
}