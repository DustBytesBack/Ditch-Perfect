import 'package:flutter/material.dart';

class RankedBunkingPage extends StatelessWidget {
  const RankedBunkingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.primaryContainer,

      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                /// HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .08),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, -1),
                            ),
                          ],
                        ),
                        child: Text(
                          "Ranked Bunking",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),

                      const Spacer(),

                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: scheme.onSurface,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),

                /// PANEL
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),

                    child: const _ComingSoonScatter(),
                  ),
                ),
              ],
            ),
          ),

          /// NAV BAR FIX
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 12,
              color: scheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scatters the words "Coming" and "Soon" (and some filler words)
/// at random positions and slight rotations across the panel.
class _ComingSoonScatter extends StatelessWidget {
  const _ComingSoonScatter();

  static const _words = [
    'Coming',
    'Soon',
    'Coming',
    'Soon',
    'Coming',
    'Soon',
    'like',
    'really',
    'soon',
    'trust',
    'me',
    'bro',
    'any',
    'day',
    'now',
  ];

  static const _sizes = [
    32.0,
    28.0,
    40.0,
    24.0,
    36.0,
    22.0,
    14.0,
    13.0,
    18.0,
    14.0,
    12.0,
    15.0,
    12.0,
    13.0,
    11.0,
  ];

  static const _rotations = [
    -0.08,
    0.12,
    0.05,
    -0.15,
    0.1,
    -0.06,
    0.2,
    -0.18,
    0.14,
    -0.1,
    0.22,
    -0.25,
    0.15,
    -0.12,
    0.08,
  ];

  // Pre-baked fractional positions (x, y) so they don't overlap too badly
  // and fill the space in a scattered but readable way.
  static const _positions = [
    Offset(0.05, 0.06),
    Offset(0.55, 0.04),
    Offset(0.25, 0.22),
    Offset(0.65, 0.18),
    Offset(0.08, 0.40),
    Offset(0.50, 0.38),
    Offset(0.78, 0.32),
    Offset(0.15, 0.56),
    Offset(0.55, 0.54),
    Offset(0.02, 0.72),
    Offset(0.42, 0.70),
    Offset(0.72, 0.66),
    Offset(0.20, 0.85),
    Offset(0.58, 0.84),
    Offset(0.80, 0.80),
  ];

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFFDCB6E),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFD63031),
    Color(0xFFA29BFE),
    Color(0xFF55EFC4),
    Color(0xFFFF7675),
    Color(0xFF74B9FF),
    Color(0xFFE84393),
    Color(0xFF00CEC9),
    Color(0xFFFD79A8),
    Color(0xFF636E72),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: List.generate(_words.length, (i) {
            final word = _words[i];
            final isBig = i < 6;

            return Positioned(
              left: _positions[i].dx * (w - 80),
              top: _positions[i].dy * (h - 40),
              child: Transform.rotate(
                angle: _rotations[i],
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: _sizes[i],
                    fontWeight: isBig ? FontWeight.w800 : FontWeight.w600,
                    color: _colors[i],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
