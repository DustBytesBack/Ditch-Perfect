import 'dart:math';
import 'package:flutter/material.dart';

class WavyCircularProgressIndicator extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const WavyCircularProgressIndicator({
    super.key,
    this.size = 36, // Standard size closer to M3
    this.strokeWidth = 4.0, // Standard M3 stroke width
    this.color,
  });

  @override
  State<WavyCircularProgressIndicator> createState() =>
      _WavyCircularProgressIndicatorState();
}

class _WavyCircularProgressIndicatorState
    extends State<WavyCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1333 * 2222 ~/ 1000), // Approximate duration logic
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _WavyProgressPainter(
            animationValue: _controller.value,
            color: color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double strokeWidth;

  // Constants mapping to real Flutter indeterminate curves
  static const double _kMinSweep = 0.05;

  _WavyProgressPainter({
    required this.animationValue,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Standard Indeterminate Logic:
    // We break the 1.0 animationValue into parts just like official flutter logic.
    final double headValue = const Interval(0.0, 0.5, curve: Curves.fastOutSlowIn).transform(animationValue);
    final double tailValue = const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn).transform(animationValue);
    final double stepValue = animationValue;

    // Head and Tail give the arc boundaries.
    // The "sweep" is the distance between them.
    double arcStart = tailValue * 1.5 * pi;
    double arcSweep = (headValue - tailValue) * 1.5 * pi;
    
    // Add rotational offset
    arcStart += (stepValue * 2 * pi);
    
    // Ensure minimum sweep visibility
    if (arcSweep.abs() < _kMinSweep * pi) {
      arcSweep = arcSweep.sign * _kMinSweep * pi;
    }

    final Path path = Path();
    const int segments = 100;

    for (int i = 0; i <= segments; i++) {
      final double progress = i / segments;
      final double angle = arcStart + (progress * arcSweep);
      
      // WAVE LOGIC:
      // Frequency: 8 cycles
      // Amplitude: scaled by stroke width
      final double wave = sin(angle * 8 - (animationValue * 10)) * (strokeWidth * 0.45);
      final double r = radius + wave;

      final double x = center.dx + r * cos(angle);
      final double y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}

