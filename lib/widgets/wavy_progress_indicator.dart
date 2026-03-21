import 'dart:math';
import 'package:flutter/material.dart';

class WavyCircularProgressIndicator extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const WavyCircularProgressIndicator({
    super.key,
    this.size = 48,
    this.strokeWidth = 5.5,
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
      duration: const Duration(milliseconds: 2000),
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

    final double radius = size.width / 2.3;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // M3 Expressive Style:
    // A single wavy line that rotates.
    // The "wave" is created by varying the radius slightly based on the angle.
    final Path path = Path();
    const int segments = 120;
    
    // We'll draw an arc of about 280 degrees to look like a progress indicator
    const double arcAngle = 1.6 * pi; 
    final double startAngle = animationValue * 2 * pi;

    for (int i = 0; i <= segments; i++) {
        final double currentAngle = startAngle + (i / segments) * arcAngle;
        
        // Wave frequency: 7 cycles per circle
        // Wave amplitude: 2.5 pixels
        final double wave = sin(currentAngle * 7 - animationValue * 4 * pi) * 2.5;
        final double r = radius + wave;
        
        final double x = center.dx + r * cos(currentAngle);
        final double y = center.dy + r * sin(currentAngle);
        
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
