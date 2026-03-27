import 'package:flutter/material.dart';

class AnimatedUpdateIcon extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedUpdateIcon({
    super.key,
    required this.color,
    this.size = 26,
  });

  @override
  State<AnimatedUpdateIcon> createState() => _AnimatedUpdateIconState();
}

class _AnimatedUpdateIconState extends State<AnimatedUpdateIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yOffset;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _yOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -10.0, end: 4.0).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(4.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.1).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_controller);

    // Start the animation only after all fields are initialized
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base tray (Bracket shape [_]) with glow
          Positioned(
            bottom: widget.size * 0.15,
            child: Container(
              width: widget.size * 0.85,
              height: widget.size * 0.35,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: widget.color, width: 2.5),
                  left: BorderSide(color: widget.color, width: 2.5),
                  right: BorderSide(color: widget.color, width: 2.5),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Moving and Scaling Arrow
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: (widget.size * 0.1) + _yOffset.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: widget.color,
                      size: widget.size * 0.9,
                      shadows: [
                        Shadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
