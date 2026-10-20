import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/run_mode.dart';
import 'block_ui.dart';
import 'emoji_icons.dart';

/// "Stage Briefing" card shown after a rank is picked and before the warm-up:
/// the map, the target, the clock, what events to expect, and the star goals.
class StageBriefingView extends StatelessWidget {
  final RunMode mode;
  final VoidCallback onBegin;
  final VoidCallback onBack;

  const StageBriefingView({
    super.key,
    required this.mode,
    required this.onBegin,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Rb.bg,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: uid == null
              ? null
              : FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snap) {
            final all = snap.data?.data()?['stage_records'];
            final rec = all is Map ? all[mode.id] : null;
            final stars = _intOf(rec, 'stars');
            final bestSecs = _intOf(rec, 'best_secs');
            return _body(stars, bestSecs > 0 ? bestSecs : null);
          },
        ),
      ),
    );
  }

  static int _intOf(Object? rec, String key) {
    if (rec is Map) {
      final v = rec[key];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  String _hms(int secs) {
    final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Distance Trial: one clear goal (distance + time) and the first-clear gift.
  Widget _trialGoal(int stars, int? best) {
    final clock = (mode.clockSeconds ?? 0);
    return Block(
      color: Rb.slate,
      edge: Rb.slateEdge,
      depth: 5,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BlockText('YOUR GOAL', size: 13, stroke: 3.5),
          const SizedBox(height: 8),
          BlockText(
            'Run ${mode.targetKm!.toStringAsFixed(mode.targetKm! % 1 == 0 ? 0 : 3)} KM in under ${_hms(clock)}',
            size: 14,
            stroke: 3.5,
            color: Rb.gold,
          ),
          const SizedBox(height: 6),
          BlockText(
            stars == 0
                ? 'FIRST CLEAR BONUS: +${mode.firstClearCoins} \u{1FA99}   \u2022   opens the next time goal'
                : 'CLEARED${best == null ? '' : '   \u2022   BEST ${_hms(best)}'}',
            size: 10.5,
            stroke: 3,
            color: Rb.neon,
          ),
        ],
      ),
    );
  }

  String _mmss(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  Widget _body(int stars, int? best) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PressBlock(
              color: Rb.slot,
              edge: Rb.panelEdge,
              depth: 4,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              onTap: onBack,
              child: const BlockText('◀  BACK', size: 14, stroke: 3.5),
            ),
          ),
          const SizedBox(height: 12),

          // ── map banner ──
          Block(
            color: mode.color,
            edge: mode.edge,
            depth: 8,
            radius: 20,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: SizedBox(
                height: 190,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(mode.mapAsset, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.80),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlockText(
                              mode.isTrial ? 'TRIAL BRIEFING' : 'STAGE BRIEFING',
                              size: 11,
                              stroke: 3,
                              color: const Color(0xFFFFD21F)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: BlockText('${mode.emoji} ${mode.name}', size: 26, stroke: 6),
                          ),
                          BlockText(mode.mapName.toUpperCase(), size: 13, stroke: 3.5),
                          const SizedBox(height: 4),
                          BlockText(
                            mode.isTrial
                                ? (stars > 0 ? '\u2714 CLEARED' : 'NOT CLEARED YET')
                                : '★' * stars + '☆' * (3 - stars),
                            size: 22,
                            stroke: 4,
                            color: stars > 0 ? const Color(0xFFFFD21F) : const Color(0xFFB8BDC4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── mission numbers ──
          Row(
            children: [
              _stat('\u{1F3AF}', 'TARGET', '${mode.targetKm!.toStringAsFixed(1)} KM'),
              _stat('⏱', 'CLOCK', '${mode.clockMinutes} MIN'),
              _stat('\u{1FA99}', 'REWARDS', mode.multLabel),
            ],
          ),
          const SizedBox(height: 14),

          // ── event warning ──
          Block(
            color: mode.events == EventPlan.none ? Rb.panel : const Color(0xFF7A2A12),
            edge: mode.events == EventPlan.none ? Rb.panelEdge : const Color(0xFF3A1206),
            depth: 5,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlockText(
                  mode.events == EventPlan.none ? 'WHAT TO EXPECT' : '⚠️ HEADS UP',
                  size: 13,
                  stroke: 3.5,
                  color: mode.events == EventPlan.none ? Colors.white : const Color(0xFFFFD21F),
                ),
                const SizedBox(height: 6),
                for (final w in mode.briefingWarnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── star goals (trials have one clear goal instead) ──
          if (mode.isTrial) _trialGoal(stars, best) else Block(
            color: Rb.slate,
            edge: Rb.slateEdge,
            depth: 5,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BlockText('STAR GOALS', size: 13, stroke: 3.5),
                const SizedBox(height: 8),
                _goal(1, stars, 'Reach ${mode.targetKm!.toStringAsFixed(1)} KM before the clock ends'),
                _goal(2, stars, 'Clear it in under ${mode.starGoalLabel(2)}'),
                _goal(3, stars, 'Clear it in under ${mode.starGoalLabel(3)}'),
                const SizedBox(height: 6),
                BlockText(
                  stars == 0
                      ? 'FIRST CLEAR BONUS: +${mode.firstClearCoins} \u{1FA99}   •   EACH NEW STAR: +${RunMode.starCoins} \u{1FA99}'
                      : 'EACH NEW STAR: +${RunMode.starCoins} \u{1FA99}${best == null ? '' : '   •   BEST ${_mmss(best)}'}',
                  size: 10.5,
                  stroke: 3,
                  color: Rb.neon,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          PressBlock(
            color: Rb.green,
            edge: Rb.greenEdge,
            depth: 10,
            radius: 18,
            padding: const EdgeInsets.symmetric(vertical: 20),
            onTap: onBegin,
            child: const Center(child: BlockText('▶ BEGIN WARM-UP', size: 24, stroke: 5)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Block(
          color: Rb.panel,
          edge: Rb.panelEdge,
          depth: 5,
          radius: 14,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              EmojiText(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BlockText(value, size: 18, stroke: 4),
              ),
              BlockText(label, size: 9, stroke: 2.5, color: const Color(0xFFB8BDC4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goal(int n, int have, String text) {
    final done = have >= n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          BlockText('★' * n,
              size: 16,
              stroke: 3.5,
              color: done ? const Color(0xFFFFD21F) : const Color(0xFF8C929A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: done ? Colors.white : const Color(0xFFD7DADD),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ),
          if (done) const BlockText('✔', size: 14, stroke: 3, color: Rb.neon),
        ],
      ),
    );
  }
}
