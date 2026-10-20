import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'block_ui.dart';

/// A tiny, offline "map" of a run: the GPS route drawn as a line with a
/// green start dot and a red finish flag. No map tiles or API keys needed.
class RouteMiniMap extends StatelessWidget {
  /// [{lat, lng}] points saved with the run.
  final List<Map<String, double>> points;
  final double height;

  const RouteMiniMap({super.key, required this.points, this.height = 90});

  /// Runs with fewer than 2 points have no route to draw.
  static bool hasRoute(List<Map<String, double>> p) => p.length >= 2;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1F3B2D),
          border: Border.all(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: CustomPaint(painter: _RoutePainter(points)),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<Map<String, double>> pts;
  _RoutePainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;

    // faint grid so it reads as a map
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in pts) {
      final la = p['lat'] ?? 0, ln = p['lng'] ?? 0;
      minLat = math.min(minLat, la);
      maxLat = math.max(maxLat, la);
      minLng = math.min(minLng, ln);
      maxLng = math.max(maxLng, ln);
    }
    // longitude degrees are shorter than latitude degrees away from the equator
    final k = math.cos(((minLat + maxLat) / 2) * math.pi / 180);
    final w = math.max((maxLng - minLng) * k, 1e-6);
    final h = math.max(maxLat - minLat, 1e-6);
    const pad = 14.0;
    final scale = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;

    Offset at(Map<String, double> p) => Offset(
          dx + ((p['lng'] ?? 0) - minLng) * k * scale,
          size.height - (dy + ((p['lat'] ?? 0) - minLat) * scale),
        );

    final path = Path()..moveTo(at(pts.first).dx, at(pts.first).dy);
    for (final p in pts.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = Rb.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);

    void dot(Offset o, Color c) {
      canvas.drawCircle(o, 7, Paint()..color = Colors.black);
      canvas.drawCircle(o, 5, Paint()..color = c);
    }

    dot(at(pts.first), const Color(0xFF3DDC5A));
    dot(at(pts.last), const Color(0xFFFF4D4D));
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.pts != pts;
}
