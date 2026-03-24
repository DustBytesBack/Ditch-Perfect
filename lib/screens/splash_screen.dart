import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/m3_loading_indicator.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _showMain = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // After 3.5s, begin the exit animation
    _timer = Timer(const Duration(milliseconds: 3500), _exitSplash);
  }

  void _exitSplash() {
    if (!mounted) return;
    _fadeController.forward().then((_) {
      if (mounted) {
        setState(() => _showMain = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showMain) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          // Scale up slightly and fade out during exit
          final double exitProgress = _fadeController.value;
          final double scale = 1.0 + exitProgress * 0.15;
          final double opacity = 1.0 - exitProgress;

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Stack(
          children: [
            // Shape + icon: truly centered on screen
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    M3ExpressiveLoadingIndicator(
                      size: 240,
                      color: scheme.primaryContainer,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon/Ditch_Perfect_Icon.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text sits below the shape without affecting its centering
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.18,
              child: Column(
                children: [
                  Text(
                    'Ditch Perfect',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DustBytesBack',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
