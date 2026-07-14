/// P1 task 6 — radar chart for the placement five-dim scores.
///
/// Plain [CustomPainter] so we don't pull in a charting dependency for a
/// single use case. Draws:
///   * 4 concentric reference polygons (25 / 50 / 75 / 100)
///   * 5 axis lines + labels (positioned just outside the outer ring)
///   * the score polygon (filled + stroked) with vertex dots
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlacementRadarChart extends StatelessWidget {
  final List<int> values; // length 5, each 0–100
  final List<String> labels; // length 5
  final Color? color;

  const PlacementRadarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280.0;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RadarPainter(
              values: values,
              labels: labels,
              color: color ?? Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).textTheme.bodySmall?.color ??
                  Colors.black,
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color color;
  final Color textColor;

  _RadarPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Leave room for labels around the outer ring.
    final radius = (size.width < size.height ? size.width : size.height) / 2 -
        36;
    if (radius <= 0) return;
    final n = values.length;
    const startAngle = -math.pi / 2; // top vertex

    Offset vertexAt(int i, double r) {
      final a = startAngle + (2 * math.pi * i / n);
      return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
    }

    // Reference rings (25 / 50 / 75 / 100).
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final v = vertexAt(i, radius * frac);
        if (i == 0) {
          path.moveTo(v.dx, v.dy);
        } else {
          path.lineTo(v.dx, v.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    // Axis lines.
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final v = vertexAt(i, radius);
      canvas.drawLine(Offset(cx, cy), v, axisPaint);
    }

    // Score polygon.
    final scorePath = Path();
    for (var i = 0; i < n; i++) {
      final v =
          vertexAt(i, radius * (values[i].clamp(0, 100) / 100));
      if (i == 0) {
        scorePath.moveTo(v.dx, v.dy);
      } else {
        scorePath.lineTo(v.dx, v.dy);
      }
    }
    scorePath.close();

    canvas.drawPath(
      scorePath,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      scorePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Vertex dots + labels.
    final dotPaint = Paint()..color = color;
    final labelStyle = TextStyle(
      color: textColor,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    for (var i = 0; i < n; i++) {
      final v =
          vertexAt(i, radius * (values[i].clamp(0, 100) / 100));
      canvas.drawCircle(v, 3, dotPaint);

      final labelV = vertexAt(i, radius + 14);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(
        canvas,
        Offset(labelV.dx - tp.width / 2, labelV.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.color != color ||
      old.textColor != textColor ||
      !_listEq(old.values, values) ||
      !_listEq(old.labels, labels);

  bool _listEq(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
