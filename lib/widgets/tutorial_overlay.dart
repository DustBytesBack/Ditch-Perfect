import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final Rect targetRect;
  final Rect previousTargetRect;
  final String title;
  final String description;
  final int stepIndex;
  final int totalSteps;
  final bool canGoBack;
  final bool allowTapOutside;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const TutorialOverlay({
    super.key,
    required this.targetRect,
    required this.previousTargetRect,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.totalSteps,
    required this.canGoBack,
    required this.allowTapOutside,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<Rect?>(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        tween: RectTween(begin: previousTargetRect, end: targetRect),
        builder: (context, animatedRect, child) {
          final rect = animatedRect ?? targetRect;
          final tooltipWidth = (screenSize.width - 32).clamp(240.0, 320.0);
          final tooltipHeight = 220.0;
          final focusRect = rect.inflate(12);
          final tooltipLeft = (focusRect.center.dx - (tooltipWidth / 2)).clamp(
            16.0,
            screenSize.width - tooltipWidth - 16,
          );
          final spaceBelow =
              screenSize.height - focusRect.bottom - safePadding.bottom;
          final placeBelow = spaceBelow > tooltipHeight + 24;

          final tooltipTop = placeBelow
              ? (focusRect.bottom + 18).clamp(
                  safePadding.top + 16,
                  screenSize.height - tooltipHeight - safePadding.bottom - 16,
                )
              : (focusRect.top - tooltipHeight - 18).clamp(
                  safePadding.top + 16,
                  screenSize.height - tooltipHeight - safePadding.bottom - 16,
                );

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: allowTapOutside ? onNext : null,
                  child: CustomPaint(
                    painter: _TutorialScrimPainter(focusRect: focusRect),
                  ),
                ),
              ),
              Positioned(
                left: tooltipLeft,
                top: tooltipTop,
                width: tooltipWidth,
                child: GestureDetector(
                  onTap: () {},
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey<String>('tutorial-$stepIndex-$title'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Step ${stepIndex + 1} of $totalSteps',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              TextButton(
                                onPressed: onSkip,
                                child: const Text('Skip'),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: canGoBack ? onPrevious : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: onNext,
                                child: Text(
                                  stepIndex == totalSteps - 1
                                      ? 'Finish'
                                      : 'Next',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TutorialScrimPainter extends CustomPainter {
  final Rect focusRect;

  const _TutorialScrimPainter({required this.focusRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(focusRect, const Radius.circular(24)));

    final scrim = Path.combine(
      PathOperation.difference,
      overlayPath,
      cutoutPath,
    );

    canvas.drawPath(scrim, Paint()..color = const Color(0xB3000000));

    canvas.drawRRect(
      RRect.fromRectAndRadius(focusRect, const Radius.circular(24)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialScrimPainter oldDelegate) {
    return oldDelegate.focusRect != focusRect;
  }
}
