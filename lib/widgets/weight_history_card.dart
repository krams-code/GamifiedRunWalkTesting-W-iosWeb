import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'block_ui.dart';

/// Profile: weight over the weekly check-ins (users/{uid}/weight_checkins).
class WeightHistoryCard extends StatelessWidget {
  final String uid;

  /// users/{uid}.weight_kg - shown as the only point until history exists.
  final double? currentKg;
  const WeightHistoryCard({super.key, required this.uid, this.currentKg});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('weight_checkins')
          .orderBy('at')
          .limitToLast(12)
          .snapshots(),
      builder: (context, snap) {
        final pts = <_Pt>[];
        for (final d in snap.data?.docs ?? const []) {
          final w = (d.data()['weight_kg'] as num?)?.toDouble();
          final t = d.data()['at'];
          if (w != null) pts.add(_Pt(t is Timestamp ? t.toDate() : DateTime.now(), w));
        }
        if (pts.isEmpty && currentKg != null) pts.add(_Pt(DateTime.now(), currentKg!));

        final first = pts.isNotEmpty ? pts.first.kg : 0.0;
        final last = pts.isNotEmpty ? pts.last.kg : 0.0;
        final diff = last - first;

        return Block(
          color: Rb.panel,
          edge: Rb.panelEdge,
          depth: 5,
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                    child: BlockText('⚖️ WEIGHT PROGRESS', size: 13, stroke: 3.5)),
                if (pts.length >= 2)
                  BlockText(
                    '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
                    size: 13,
                    stroke: 3.5,
                    color: diff <= 0 ? Rb.neon : const Color(0xFFFFB347),
                  ),
              ]),
              const SizedBox(height: 8),
              if (pts.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    pts.isEmpty
                        ? 'Do your first weekly check-in to start the chart.'
                        : 'Current weight: ${pts.first.kg.toStringAsFixed(1)} kg.\nYour chart appears after your next weekly check-in.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                )
              else ...[
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: _WeightPainter(pts),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Start ${first.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                    Text('Now ${last.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Pt {
  final DateTime at;
  final double kg;
  _Pt(this.at, this.kg);
}

class _WeightPainter extends CustomPainter {
  final List<_Pt> pts;
  _WeightPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = pts.map((p) => p.kg).reduce(math.min);
    final hi = pts.map((p) => p.kg).reduce(math.max);
    final pad = math.max(0.5, (hi - lo) * 0.2);
    final minY = lo - pad, maxY = hi + pad;
    const m = 8.0;
    final w = size.width - m * 2, h = size.height - m * 2;

    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = m + h * i / 3;
      canvas.drawLine(Offset(m, y), Offset(size.width - m, y), grid);
    }

    Offset at(int i) => Offset(
          m + (pts.length == 1 ? w / 2 : w * i / (pts.length - 1)),
          m + h * (1 - (pts[i].kg - minY) / (maxY - minY)),
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        line,
        Paint()
          ..color = Rb.neon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(at(i), 5.5, Paint()..color = Colors.black);
      canvas.drawCircle(at(i), 3.5, Paint()..color = i == pts.length - 1 ? Rb.gold : Colors.white);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.pts != pts;
}
