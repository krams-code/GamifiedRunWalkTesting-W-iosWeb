import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/run_mode.dart';
import 'block_ui.dart';
import 'emoji_icons.dart';
import 'lottie_fx.dart';

/// Roblox-style Mode Selection Overlay, opened by the ▶ PLAY STAGE button.
///
///   MAIN MENU            ⚔️ STAGE MODE   → difficulty sub-menu
///                        ♾️ ENDLESS RUN  → starts straight away
///   DIFFICULTY SUB-MENU  🟢 Novice · 🟡 Vanguard · 🔴 Slayer
///
/// Resolves to the chosen [RunMode], or null if the player closes it.
///
/// [records] is the user's `stage_records` map (stars per rank), if loaded.
///
/// [firstRun] = the brand-new-hero version: opens straight on the rank list,
/// can't be closed, and the only rank that can be picked is NOVICE.
Future<RunMode?> showModeSelectPanel(BuildContext context,
    {Map<String, dynamic>? records, Object? seen, bool firstRun = false}) {
  return showGeneralDialog<RunMode>(
    context: context,
    barrierDismissible: !firstRun,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _ModePanel(
      firstRun: firstRun,
      records: records,
      seen: seen is List ? seen.whereType<String>().toSet() : <String>{},
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _ModePanel extends StatefulWidget {
  final Map<String, dynamic>? records;

  /// Ranks whose NEW! badge the player has already acted on.
  final Set<String> seen;

  /// Brand-new hero: must pick NOVICE (nothing else is open yet).
  final bool firstRun;
  const _ModePanel({this.records, this.seen = const {}, this.firstRun = false});

  @override
  State<_ModePanel> createState() => _ModePanelState();
}

class _ModePanelState extends State<_ModePanel> {
  late bool _pickingRank = widget.firstRun; // false = main menu, true = ranks

  void _close() {
    if (widget.firstRun) return; // the first mode can't be skipped
    Navigator.of(context).pop();
  }

  void _pick(RunMode m) {
    if (_isNew(m)) _markSeen(m); // the player noticed it: retire the badge
    Navigator.of(context).pop(m);
  }

  /// Unlocked, never cleared and not yet opened = freshly unlocked.
  bool _isNew(RunMode m) =>
      m.requiresId != null &&
      RunMode.isUnlocked(m, widget.records) &&
      RunMode.starsIn(widget.records, m.id) == 0 &&
      !widget.seen.contains(m.id);

  Future<void> _markSeen(RunMode m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'stage_seen': FieldValue.arrayUnion([m.id]),
      });
    } catch (_) {/* the badge just shows once more */}
  }

  Widget _startHereBadge() => Transform.rotate(
        angle: -0.08,
        child: Block(
          color: const Color(0xFF5ED67B),
          edge: const Color(0xFF1A6B30),
          depth: 3,
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: const BlockText('START HERE', size: 12, stroke: 3.5),
        ),
      );

  Widget _newBadge() => Transform.rotate(
        angle: 0.1,
        child: Block(
          color: const Color(0xFFFFD21F),
          edge: const Color(0xFF8A5A00),
          depth: 3,
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: const BlockText('NEW!', size: 12, stroke: 3.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
            child: Block(
              color: Rb.slate,
              edge: Colors.black,
              depth: 8,
              radius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _pickingRank
                            ? KeyedSubtree(key: const ValueKey('ranks'), child: _ranks())
                            : KeyedSubtree(key: const ValueKey('menu'), child: _menu()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── header: back / title / close ──────────────────────────────────────

  Widget _header() {
    return Row(
      children: [
        if (_pickingRank && !widget.firstRun) ...[
          PressBlock(
            color: Rb.hud,
            edge: Rb.hudEdge,
            depth: 4,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => setState(() => _pickingRank = false),
            child: const EmojiText('◀',
                style: TextStyle(
                    color: Color(0xFF232527), fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: BlockText(
                widget.firstRun
                    ? 'CHOOSE YOUR FIRST MODE'
                    : (_pickingRank ? 'CHOOSE YOUR RANK' : 'SELECT MODE'),
                size: 21,
                stroke: 5),
          ),
        ),
        if (!widget.firstRun) ...[
          const SizedBox(width: 8),
          PressBlock(
            color: Rb.red,
            edge: Rb.redEdge,
            depth: 4,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: _close,
            child: const BlockText('✕', size: 15, stroke: 3.5),
          ),
        ],
      ],
    );
  }

  // ── picture card: map art + dark scrim so the white text always reads ──

  Widget _pictureCard({
    required String asset,
    required Color color,
    required Color edge,
    required VoidCallback? onTap,
    required Widget child,
    double depth = 10,
    bool locked = false,
    Widget? badge,
    bool burst = false, // freshly unlocked: play the unlock burst once
  }) {
    return PressBlock(
      color: color,
      edge: edge,
      depth: depth,
      radius: 18,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned.fill(
              child: locked
                  ? ColorFiltered(
                      // locked ranks show their map in grey
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Image.asset(asset, fit: BoxFit.cover),
                    )
                  : Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.center),
            ),
            // scrim: darker at the bottom where the small text sits
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: locked ? 0.55 : 0.30),
                      Colors.black.withValues(alpha: locked ? 0.85 : 0.72),
                    ],
                  ),
                ),
              ),
            ),
            if (burst)
              Positioned.fill(child: FxOnce(Fx.unlockBurst, fit: BoxFit.cover)),
            // thin colour bar keeps each rank's identity colour
            Positioned(left: 0, right: 0, top: 0, height: 6, child: ColoredBox(color: color)),
            // full width, so the picture fills the whole card evenly
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: child,
              ),
            ),
            if (badge != null) Positioned(top: 12, right: 12, child: badge),
          ],
        ),
      ),
    );
  }

  // ── main menu ─────────────────────────────────────────────────────────

  Widget _menu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pictureCard(
          asset: kVanguard.mapAsset,
          color: Rb.orange,
          edge: Rb.orangeEdge,
          badge: kStageModes.any(_isNew) ? _newBadge() : null,
          burst: kStageModes.any(_isNew),
          onTap: () => setState(() => _pickingRank = true),
          child: Column(
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: BlockText('\u2694\uFE0F STAGE MODE', size: 24, stroke: 5.5),
              ),
              const SizedBox(height: 4),
              const BlockText('THE MAIN CAMPAIGN',
                  size: 11, stroke: 3, color: Color(0xFFFFE3C2)),
              const SizedBox(height: 8),
              _chips([
                '\u{1F3AF} Target distance',
                '\u23F1 Stage clock',
                '\u2B50 ${RunMode.totalStars(widget.records)}/${RunMode.maxStars} stars',
                '\u{1F48E} Up to 2.5x rewards',
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _pictureCard(
          asset: kEndless.mapAsset,
          color: kEndless.color,
          edge: kEndless.edge,
          locked: !RunMode.isUnlocked(kEndless, widget.records),
          badge: _isNew(kEndless) ? _newBadge() : null,
          burst: _isNew(kEndless),
          onTap: RunMode.isUnlocked(kEndless, widget.records)
              ? () => _pick(kEndless)
              : null,
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BlockText(
                    '${RunMode.isUnlocked(kEndless, widget.records) ? '\u267E\uFE0F' : '\u{1F512}'} ENDLESS RUN',
                    size: 24,
                    stroke: 5.5),
              ),
              if (!RunMode.isUnlocked(kEndless, widget.records))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: BlockText('${kEndless.lockHint}',
                      size: 12.5, stroke: 3.5, color: const Color(0xFFFFE066)),
                ),
              const SizedBox(height: 4),
              const BlockText('THE CASUAL TRACKER',
                  size: 11, stroke: 3, color: Color(0xFFD7C8FF)),
              const SizedBox(height: 8),
              _chips(const [
                'No target',
                'No clock',
                'No interruptions',
                '+0.2x XP & Crystals per km',
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _pictureCard(
          asset: kInterval.mapAsset,
          color: kInterval.color,
          edge: kInterval.edge,
          locked: !RunMode.isUnlocked(kInterval, widget.records),
          badge: _isNew(kInterval) ? _newBadge() : null,
          burst: _isNew(kInterval),
          onTap: RunMode.isUnlocked(kInterval, widget.records)
              ? () => _pick(kInterval)
              : null,
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BlockText(
                    '${RunMode.isUnlocked(kInterval, widget.records) ? '\u26A1' : '\u{1F512}'} INTERVAL RUN',
                    size: 24,
                    stroke: 5.5),
              ),
              if (!RunMode.isUnlocked(kInterval, widget.records))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: BlockText('${kInterval.lockHint}',
                      size: 12.5, stroke: 3.5, color: const Color(0xFFFFE066)),
                ),
              const SizedBox(height: 4),
              const BlockText('FAST, EASY, REPEAT',
                  size: 11, stroke: 3, color: Color(0xFFBDEBFF)),
              const SizedBox(height: 8),
              _chips(const [
                '6 rounds',
                '1 min FAST / 1 min EASY',
                '12 min',
                '1.3x XP & Crystals',
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chips(List<String> items) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BlockText(t, size: 10, stroke: 2.5),
          ),
      ],
    );
  }

  // ── difficulty sub-menu ───────────────────────────────────────────────

  Widget _ranks() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.firstRun) ...[
          Block(
            color: const Color(0xFF1E6B45),
            edge: const Color(0xFF0B2E1D),
            depth: 4,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: SizedBox(
              width: double.infinity,
              child: BlockText(
                'Start with NOVICE RANK. Clear it to unlock VANGUARD, SLAYER and ENDLESS RUN!',
                size: 11.5,
                stroke: 3,
                align: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: BlockText(
            '\u2B50 TOTAL ${RunMode.totalStars(widget.records)}/${RunMode.maxStars}',
            size: 13,
            stroke: 3.5,
            color: const Color(0xFFFFD21F),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < kStageModes.length; i++) ...[
          _rankCard(kStageModes[i]),
          if (i != kStageModes.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  int _starsOf(RunMode m) => RunMode.starsIn(widget.records, m.id);

  Widget _rankCard(RunMode m) {
    final stars = _starsOf(m);
    final locked = !RunMode.isUnlocked(m, widget.records);

    Widget line(String t) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: BlockText(t, size: 11.5, stroke: 3),
        );

    return _pictureCard(
      asset: m.mapAsset,
      color: m.color,
      edge: m.edge,
      depth: 8,
      locked: locked,
      badge: (widget.firstRun && !locked) ? _startHereBadge() : null,
      burst: _isNew(m),
      onTap: locked ? null : () => _pick(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BlockText('${locked ? '\u{1F512}' : m.emoji} ${m.name}',
                      size: 20, stroke: 5),
                ),
              ),
              const SizedBox(width: 8),
              if (_isNew(m)) ...[_newBadge(), const SizedBox(width: 8)],
              BlockText(m.multLabel, size: 16, stroke: 4, color: const Color(0xFFFFD21F)),
            ],
          ),
          const SizedBox(height: 2),
          BlockText(
            '\u2605' * stars + '\u2606' * (3 - stars),
            size: 18,
            stroke: 3.5,
            color: stars > 0 ? const Color(0xFFFFD21F) : const Color(0xFFB8BDC4),
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BlockText('${m.lockHint}',
                  size: 12.5, stroke: 3.5, color: const Color(0xFFFFE066)),
            ),
          line('\u{1F3AF} Target ${m.targetKm!.toStringAsFixed(1)} KM   \u23F1 ${m.clockMinutes}-minute clock'),
          line('\u{1F5FA} Map: ${m.mapName}'),
          line('\u{1F48E} Rewards: ${m.rewardLabel}'),
          if (m.events != EventPlan.none) line('\u26A1 ${m.eventLabel}'),
        ],
      ),
    );
  }
}
