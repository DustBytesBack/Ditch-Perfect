import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
//  M3 Expressive Loading Indicator
//  Flutter port of the "expressive-shapes" algorithm by amansxcalibur.
//  Uses RoundedPolygon with per-vertex CornerRounding, cubic Bezier
//  morphing via segment balancing + control-point interpolation.
// ═══════════════════════════════════════════════════════════════════

class M3ExpressiveLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? containerColor;
  final bool contained;

  const M3ExpressiveLoadingIndicator({
    super.key,
    this.size = 48,
    this.color,
    this.containerColor,
    this.contained = false,
  });

  @override
  State<M3ExpressiveLoadingIndicator> createState() =>
      _M3ExpressiveLoadingIndicatorState();
}

class _M3ExpressiveLoadingIndicatorState
    extends State<M3ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Pre-computed morph pairs for each transition
  late List<List<List<_Cubic>>> _morphPairs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();

    // Pre-compute all shape transitions
    _morphPairs = [];
    for (int i = 0; i < _shapePresets.length; i++) {
      final next = (i + 1) % _shapePresets.length;
      final polyA = _buildPolygon(_shapePresets[i]);
      final polyB = _buildPolygon(_shapePresets[next]);
      final matched = _Morph.match(polyA, polyB);
      _morphPairs.add(matched);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final containerColor = widget.containerColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _M3MorphPainter(
              progress: _controller.value,
              color: color,
              containerColor: widget.contained ? containerColor : null,
              morphPairs: _morphPairs,
              shapeCount: _shapePresets.length,
            ),
          );
        },
      ),
    );
  }
}

// ─── Geometry: Point ─────────────────────────────────────────────

class _Pt {
  final double x, y;
  const _Pt(this.x, this.y);

  _Pt operator +(_Pt o) => _Pt(x + o.x, y + o.y);
  _Pt operator -(_Pt o) => _Pt(x - o.x, y - o.y);
  _Pt operator *(_Pt o) => _Pt(x * o.x, y * o.y); // unused but handy
  _Pt scale(double s) => _Pt(x * s, y * s);
  _Pt divBy(double s) => _Pt(x / s, y / s);

  double get dist => sqrt(x * x + y * y);
  double get distSq => x * x + y * y;
  double distTo(_Pt o) => (this - o).dist;
  double dot(_Pt o) => x * o.x + y * o.y;

  _Pt get direction {
    final d = dist;
    return d > 0 ? divBy(d) : const _Pt(0, 0);
  }

  _Pt get rotate90 => _Pt(-y, x);
  _Pt get rotate270 => _Pt(y, -x);

  static _Pt lerp(_Pt a, _Pt b, double t) =>
      _Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

// ─── Geometry: Cubic Bezier ──────────────────────────────────────

class _Cubic {
  final _Pt p0, p1, p2, p3;
  const _Cubic(this.p0, this.p1, this.p2, this.p3);

  _Cubic reversed() => _Cubic(p3, p2, p1, p0);

  static _Cubic straightLine(double x0, double y0, double x1, double y1) {
    final a = _Pt(x0, y0);
    final b = _Pt(x1, y1);
    return _Cubic(a, a, b, b);
  }

  static _Cubic circularArc(
      double cx, double cy, double x0, double y0, double x1, double y1,
      {required bool isConvex}) {
    final p0 = _Pt(x0, y0);
    final p3 = _Pt(x1, y1);
    final center = _Pt(cx, cy);

    final v0 = p0 - center;
    final v3 = p3 - center;

    final d0 = v0.direction;
    final d3 = v3.direction;
    final dotVal = d0.dot(d3).clamp(-1.0, 1.0);
    final angle = acos(dotVal);

    final kappa = (4.0 / 3.0) * tan(angle / 4.0);

    _Pt cp1, cp2;
    if (isConvex) {
      cp1 = p0 + v0.rotate90.scale(kappa);
      cp2 = p3 + v3.rotate90.scale(-kappa);
    } else {
      cp1 = p0 + v0.rotate270.scale(kappa);
      cp2 = p3 + v3.rotate270.scale(-kappa);
    }
    return _Cubic(p0, cp1, cp2, p3);
  }

  /// De Casteljau split at parameter t
  (  _Cubic, _Cubic) split(double t) {
    final p01 = _Pt.lerp(p0, p1, t);
    final p12 = _Pt.lerp(p1, p2, t);
    final p23 = _Pt.lerp(p2, p3, t);
    final p012 = _Pt.lerp(p01, p12, t);
    final p123 = _Pt.lerp(p12, p23, t);
    final p0123 = _Pt.lerp(p012, p123, t);
    return (_Cubic(p0, p01, p012, p0123), _Cubic(p0123, p123, p23, p3));
  }
}

// ─── Corner Rounding ─────────────────────────────────────────────

class _CornerRounding {
  final double radius;
  final double smoothing;
  const _CornerRounding({this.radius = 0.0, this.smoothing = 0.0});
}

class _RoundedCorner {
  static const double _eps = 1e-3;

  final _Pt p0, p1, p2;
  final _CornerRounding rounding;
  late final _Pt d1, d2;
  late final double cornerRadius, smoothing, cosAngle, sinAngle;
  late final double expectedRoundCut;
  late final bool isConvex;
  _Pt center = const _Pt(0, 0);

  _RoundedCorner(this.p0, this.p1, this.p2, this.rounding,
      {bool clockwiseWinding = true}) {
    final v01 = p0 - p1;
    final v21 = p2 - p1;
    final d01 = v01.dist;
    final d21 = v21.dist;

    if (d01 > 0 && d21 > 0) {
      d1 = v01.divBy(d01);
      d2 = v21.divBy(d21);
      cornerRadius = rounding.radius;
      smoothing = rounding.smoothing;
      cosAngle = d1.dot(d2);
      sinAngle = sqrt(max(0.0, 1.0 - cosAngle * cosAngle));

      final vIn = p1 - p0;
      final vOut = p2 - p1;
      final cross = vIn.x * vOut.y - vIn.y * vOut.x;
      isConvex = clockwiseWinding ? cross <= 0 : cross >= 0;

      if (sinAngle > _eps) {
        expectedRoundCut = cornerRadius * (cosAngle + 1) / sinAngle;
      } else {
        expectedRoundCut = 0.0;
      }
    } else {
      d1 = const _Pt(0, 0);
      d2 = const _Pt(0, 0);
      cornerRadius = 0;
      smoothing = 0;
      cosAngle = 0;
      sinAngle = 0;
      expectedRoundCut = 0;
      isConvex = true;
    }
  }

  double get expectedCut => (1 + smoothing) * expectedRoundCut;

  _Pt getStartPoint(double allowedCut) => p1 + d1.scale(allowedCut);

  List<_Cubic> getCubics(double allowedCut0, double allowedCut1) {
    final allowedCut = min(allowedCut0, allowedCut1);

    if (expectedRoundCut < _eps ||
        allowedCut < _eps ||
        cornerRadius < _eps) {
      center = p1;
      return [_Cubic.straightLine(p1.x, p1.y, p1.x, p1.y)];
    }

    final actualRoundCut = min(allowedCut, expectedRoundCut);
    final actualSmoothing0 = _calcSmoothing(allowedCut0);
    final actualSmoothing1 = _calcSmoothing(allowedCut1);
    final actualR = cornerRadius * actualRoundCut / expectedRoundCut;

    final centerDist = sqrt(actualR * actualR + actualRoundCut * actualRoundCut);
    final bisectorDir = (d1 + d2).direction;
    center = p1 + bisectorDir.scale(centerDist);

    final circleInter0 = p1 + d1.scale(actualRoundCut);
    final circleInter2 = p1 + d2.scale(actualRoundCut);

    final flanking0 = _computeFlankingCurve(
        actualRoundCut, actualSmoothing0, p1, p0, circleInter0, circleInter2,
        center, actualR);
    final flanking2 = _computeFlankingCurve(
            actualRoundCut, actualSmoothing1, p1, p2, circleInter2,
            circleInter0, center, actualR)
        .reversed();

    return [
      flanking0,
      _Cubic.circularArc(center.x, center.y, flanking0.p3.x, flanking0.p3.y,
          flanking2.p0.x, flanking2.p0.y,
          isConvex: isConvex),
      flanking2,
    ];
  }

  double _calcSmoothing(double allowedCut) {
    if (allowedCut > expectedCut) return smoothing;
    if (allowedCut > expectedRoundCut) {
      return smoothing *
          (allowedCut - expectedRoundCut) /
          (expectedCut - expectedRoundCut);
    }
    return 0.0;
  }

  _Cubic _computeFlankingCurve(
      double actualRoundCut,
      double sm,
      _Pt corner,
      _Pt sideStart,
      _Pt circleInter,
      _Pt otherInter,
      _Pt ctr,
      double radius) {
    final sideDir = (sideStart - corner).direction;
    final curveStart = corner + sideDir.scale(actualRoundCut * (1 + sm));

    final p = _Pt.lerp(circleInter, (circleInter + otherInter).divBy(2.0), sm);
    final curveEnd = ctr + (p - ctr).direction.scale(radius);

    final circleTangent = (curveEnd - ctr).rotate90;
    final anchorEnd =
        _lineIntersection(sideStart, sideDir, curveEnd, circleTangent) ??
            circleInter;

    final anchorStart = (curveStart + anchorEnd.scale(2.0)).divBy(3.0);

    return _Cubic(curveStart, anchorStart, anchorEnd, curveEnd);
  }

  _Pt? _lineIntersection(_Pt p0, _Pt d0, _Pt p1, _Pt d1) {
    final rotD1 = d1.rotate90;
    final den = d0.dot(rotD1);
    if (den.abs() < _eps) return null;
    final num_ = (p1 - p0).dot(rotD1);
    return p0 + d0.scale(num_ / den);
  }
}

// ─── RoundedPolygon ──────────────────────────────────────────────

class _RoundedPolygon {
  final List<_Cubic> cubics;
  _RoundedPolygon(this.cubics);
}

_RoundedPolygon _buildPolygon(List<(_Pt, _CornerRounding)> preset) {
  final n = preset.length;
  final vertices = preset.map((e) => e.$1).toList();
  final roundings = preset.map((e) => e.$2).toList();

  // Check winding
  double area = 0;
  for (int i = 0; i < n; i++) {
    final x1 = vertices[i].x, y1 = vertices[i].y;
    final x2 = vertices[(i + 1) % n].x, y2 = vertices[(i + 1) % n].y;
    area += (x2 - x1) * (y2 + y1);
  }
  final isCW = area > 0;

  // Build corners
  final corners = <_RoundedCorner>[];
  for (int i = 0; i < n; i++) {
    corners.add(_RoundedCorner(
      vertices[(i + n - 1) % n],
      vertices[i],
      vertices[(i + 1) % n],
      roundings[i],
      clockwiseWinding: isCW,
    ));
  }

  // Resolve overlapping cuts
  final cutAdjusts = <(double, double)>[];
  for (int i = 0; i < n; i++) {
    final c1 = corners[i];
    final c2 = corners[(i + 1) % n];
    final expRound = c1.expectedRoundCut + c2.expectedRoundCut;
    final expTotal = c1.expectedCut + c2.expectedCut;
    final sideLen = vertices[i].distTo(vertices[(i + 1) % n]);

    if (expRound > sideLen) {
      cutAdjusts.add((sideLen / expRound, 0.0));
    } else if (expTotal > sideLen) {
      final smoothR = (sideLen - expRound) / (expTotal - expRound);
      cutAdjusts.add((1.0, smoothR));
    } else {
      cutAdjusts.add((1.0, 1.0));
    }
  }

  // Generate cubics
  final allCubics = <_Cubic>[];
  for (int i = 0; i < n; i++) {
    final (r0, s0) = cutAdjusts[(i + n - 1) % n];
    final allowed0 = corners[i].expectedRoundCut * r0 +
        (corners[i].expectedCut - corners[i].expectedRoundCut) * s0;

    final (r1, s1) = cutAdjusts[i];
    final allowed1 = corners[i].expectedRoundCut * r1 +
        (corners[i].expectedCut - corners[i].expectedRoundCut) * s1;

    final cornerCubics = corners[i].getCubics(allowed0, allowed1);
    allCubics.addAll(cornerCubics);

    // Edge to next corner
    final (nextR0, nextS0) = cutAdjusts[i];
    final nextAllowed0 = corners[(i + 1) % n].expectedRoundCut * nextR0 +
        (corners[(i + 1) % n].expectedCut -
                corners[(i + 1) % n].expectedRoundCut) *
            nextS0;
    final nextStart = corners[(i + 1) % n].getStartPoint(nextAllowed0);

    allCubics.add(_Cubic.straightLine(
        cornerCubics.last.p3.x, cornerCubics.last.p3.y, nextStart.x, nextStart.y));
  }

  return _RoundedPolygon(allCubics);
}

// ─── Morph ───────────────────────────────────────────────────────

class _Morph {
  /// Balance two lists of cubics to the same length by splitting longest segments.
  static List<_Cubic> _balance(List<_Cubic> curves, int target) {
    final result = List<_Cubic>.from(curves);
    while (result.length < target) {
      int idx = 0;
      double maxScore = -1;
      for (int i = 0; i < result.length; i++) {
        final c = result[i];
        final score = c.p0.distTo(c.p1) + c.p1.distTo(c.p2) + c.p2.distTo(c.p3);
        if (score > maxScore) {
          maxScore = score;
          idx = i;
        }
      }
      final (c1, c2) = result[idx].split(0.5);
      result[idx] = c1;
      result.insert(idx + 1, c2);
    }
    return result;
  }

  /// Match two polygons: balance segment counts and align by rotation.
  /// Returns [cubicsA, cubicsB] as parallel lists.
  static List<List<_Cubic>> match(_RoundedPolygon polyA, _RoundedPolygon polyB) {
    // Filter out degenerate cubics
    var a = polyA.cubics.where((c) => c.p0.distTo(c.p3) > 0.001).toList();
    var b = polyB.cubics.where((c) => c.p0.distTo(c.p3) > 0.001).toList();

    final target = max(a.length, b.length);
    a = _balance(a, target);
    b = _balance(b, target);

    // Find best rotation alignment
    int bestShift = 0;
    double minDist = double.infinity;
    for (int shift = 0; shift < b.length; shift++) {
      final d = a[0].p0.distTo(b[shift].p0);
      if (d < minDist) {
        minDist = d;
        bestShift = shift;
      }
    }
    b = [...b.sublist(bestShift), ...b.sublist(0, bestShift)];

    return [a, b];
  }

  /// Interpolate matched cubic pairs at the given progress (0.0 to 1.0).
  static List<_Cubic> interpolate(
      List<_Cubic> curvesA, List<_Cubic> curvesB, double alpha) {
    final result = <_Cubic>[];
    for (int i = 0; i < curvesA.length; i++) {
      final c1 = curvesA[i];
      final c2 = curvesB[i];
      result.add(_Cubic(
        _Pt.lerp(c1.p0, c2.p0, alpha),
        _Pt.lerp(c1.p1, c2.p1, alpha),
        _Pt.lerp(c1.p2, c2.p2, alpha),
        _Pt.lerp(c1.p3, c2.p3, alpha),
      ));
    }
    // Close the shape by snapping last end to first start
    if (result.isNotEmpty) {
      final last = result.last;
      final first = result.first;
      result[result.length - 1] = _Cubic(last.p0, last.p1, last.p2, first.p0);
    }
    return result;
  }
}

// ─── Painter ─────────────────────────────────────────────────────

class _M3MorphPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color? containerColor;
  final List<List<List<_Cubic>>> morphPairs;
  final int shapeCount;

  _M3MorphPainter({
    required this.progress,
    required this.color,
    this.containerColor,
    required this.morphPairs,
    required this.shapeCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double scale = size.width;

    // Container
    if (containerColor != null) {
      canvas.drawCircle(
          Offset(cx, cy), size.width / 2, Paint()..color = containerColor!);
    }

    // Determine current transition
    final double scaledProg = progress * shapeCount;
    final int fromIdx = scaledProg.floor() % shapeCount;
    final double localT = scaledProg - scaledProg.floor();

    // Smooth easing
    final double t = _smootherStep(localT);

    final matched = morphPairs[fromIdx];
    final curvesA = matched[0];
    final curvesB = matched[1];

    final morphed = _Morph.interpolate(curvesA, curvesB, t);

    // Rotation
    final double rotation = progress * 2 * pi * 1.5;

    // Build flutter Path from cubic beziers
    final path = Path();
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.translate(-cx, -cy);

    if (morphed.isNotEmpty) {
      path.moveTo(morphed[0].p0.x * scale, morphed[0].p0.y * scale);
      for (final c in morphed) {
        path.cubicTo(
          c.p1.x * scale, c.p1.y * scale,
          c.p2.x * scale, c.p2.y * scale,
          c.p3.x * scale, c.p3.y * scale,
        );
      }
      path.close();
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  double _smootherStep(double t) {
    t = t.clamp(0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }

  @override
  bool shouldRepaint(covariant _M3MorphPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ─── Shape Presets (unit coordinates 0.0–1.0) ────────────────────

const _round = _CornerRounding(radius: 0.20);
const _fullRound = _CornerRounding(radius: 1.0);
const _medRound = _CornerRounding(radius: 0.4);
const _diamondRound = _CornerRounding(radius: 0.15);
const _valley = _CornerRounding(radius: 0.2, smoothing: 1.0);

final List<List<(_Pt, _CornerRounding)>> _shapePresets = [
  // Circle (4-vertex squircle with full rounding)
  [
    (const _Pt(0.10, 0.10), _fullRound),
    (const _Pt(0.90, 0.10), _fullRound),
    (const _Pt(0.90, 0.90), _fullRound),
    (const _Pt(0.10, 0.90), _fullRound),
  ],
  // Rounded Triangle
  [
    (const _Pt(0.425, 0.15), _round),
    (const _Pt(0.575, 0.15), _round),
    (const _Pt(0.90, 0.75), _round),
    (const _Pt(0.80, 0.85), _round),
    (const _Pt(0.20, 0.85), _round),
    (const _Pt(0.10, 0.75), _round),
  ],
  // Diamond
  [
    (const _Pt(0.50, 0.00), _diamondRound),
    (const _Pt(0.85, 0.50), _diamondRound),
    (const _Pt(0.50, 1.00), _diamondRound),
    (const _Pt(0.15, 0.50), _diamondRound),
  ],
  // Cookie 4 (soft indented square)
  [
    (const _Pt(0.50, 0.20), _round),
    (const _Pt(0.70, 0.10), _round),
    (const _Pt(0.90, 0.30), _round),
    (const _Pt(0.80, 0.50), _round),
    (const _Pt(0.90, 0.70), _round),
    (const _Pt(0.70, 0.90), _round),
    (const _Pt(0.50, 0.80), _round),
    (const _Pt(0.30, 0.90), _round),
    (const _Pt(0.10, 0.70), _round),
    (const _Pt(0.20, 0.50), _round),
    (const _Pt(0.10, 0.30), _round),
    (const _Pt(0.30, 0.10), _round),
  ],
  // Pill
  [
    (const _Pt(0.00, 0.55), _medRound),
    (const _Pt(0.55, 0.00), _medRound),
    (const _Pt(1.00, 0.45), _medRound),
    (const _Pt(0.45, 1.00), _medRound),
  ],
  // Arrow
  [
    (const _Pt(0.50, 0.80), _valley),
    (const _Pt(0.25, 0.90), _round),
    (const _Pt(0.10, 0.75), _round),
    (const _Pt(0.40, 0.15), _round),
    (const _Pt(0.60, 0.15), _round),
    (const _Pt(0.90, 0.75), _round),
    (const _Pt(0.75, 0.90), _round),
  ],
  // Square
  [
    (const _Pt(0.10, 0.10), _round),
    (const _Pt(0.90, 0.10), _round),
    (const _Pt(0.90, 0.90), _round),
    (const _Pt(0.10, 0.90), _round),
  ],
];
