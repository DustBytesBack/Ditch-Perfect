import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class SlidableTile extends StatefulWidget {
  final Widget child;
  final Widget? leftAction;
  final Widget? rightAction;
  final double actionWidth;
  final VoidCallback? onLeftAction;
  final VoidCallback? onRightAction;
  final bool enabled;

  const SlidableTile({
    super.key,
    required this.child,
    this.leftAction,
    this.rightAction,
    this.actionWidth = 80.0,
    this.onLeftAction,
    this.onRightAction,
    this.enabled = true,
  });

  @override
  State<SlidableTile> createState() => _SlidableTileState();
}

class _SlidableTileState extends State<SlidableTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.addListener(() {
      setState(() {
        _dragExtent = _controller.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _dragExtent += details.delta.dx;
      
      // Limit dragging if one side is not provided
      if (widget.leftAction == null && _dragExtent > 0) {
        _dragExtent = 0;
      }
      if (widget.rightAction == null && _dragExtent < 0) {
        _dragExtent = 0;
      }
      
      // Resistance beyond double the action width
      if (_dragExtent.abs() > widget.actionWidth * 1.5) {
        final overflow = _dragExtent.abs() - widget.actionWidth * 1.5;
        final resistance = 1.0 / (1.0 + (overflow / 50.0));
        _dragExtent = (_dragExtent.sign) * (widget.actionWidth * 1.5 + overflow * resistance);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    final velocity = details.primaryVelocity ?? 0;
    final threshold = widget.actionWidth * 0.4; // Lowered threshold for easier activation

    if (velocity.abs() > 300) { // More sensitive fling trigger
      // Fling trigger
      if (velocity > 0 && widget.leftAction != null) {
        HapticFeedback.heavyImpact();
        widget.onLeftAction?.call();
      } else if (velocity < 0 && widget.rightAction != null) {
        HapticFeedback.heavyImpact();
        widget.onRightAction?.call();
      }
    } else {
      // Threshold trigger
      if (_dragExtent > threshold && widget.leftAction != null) {
        HapticFeedback.heavyImpact();
        widget.onLeftAction?.call();
      } else if (_dragExtent < -threshold && widget.rightAction != null) {
        HapticFeedback.heavyImpact();
        widget.onRightAction?.call();
      }
    }

    _animateTo(0, velocity); // Always snap back to 0
  }

  void _animateTo(double target, double velocity) {
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 220.0, // Peppier snap
        damping: 18.0, // Less damping for more "life"
      ),
      _dragExtent,
      target,
      velocity,
    );

    _controller.animateWith(simulation);
  }

  void close() {
    _animateTo(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background actions
        if (_dragExtent > 0 && widget.leftAction != null)
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: _dragExtent.clamp(0.0, widget.actionWidth * 2.0),
                child: widget.leftAction,
              ),
            ),
          ),
        if (_dragExtent < 0 && widget.rightAction != null)
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _dragExtent.abs().clamp(0.0, widget.actionWidth * 2.0),
                child: widget.rightAction,
              ),
            ),
          ),

        // Foreground content
        Transform.translate(
          offset: Offset(_dragExtent, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            behavior: HitTestBehavior.opaque,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
