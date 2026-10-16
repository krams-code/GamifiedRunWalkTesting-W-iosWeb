import 'package:flutter/material.dart';

import '../models/hero_progress.dart';
import '../models/run_mode.dart';
import 'block_ui.dart';

/// One line of "how to unlock": what is needed and how far the player is.
class UnlockReq {
  final String text;

  /// "LV 3 / 5", "4.2 / 10 km" ... (null for plain done / not done goals)
  final String? progress;

  /// 0..1 for the little bar (null = no bar)
  final double? fraction;
  final bool done;

  const UnlockReq(this.text, {this.progress, this.fraction, required this.done});
}

/// Turns an [UnlockRule] into readable lines for the player's current
/// progress. Used by heroes, shop items and anything else with a rule.
List<UnlockReq> unlockReqs(UnlockRule r, HeroProgress p) {
  final out = <UnlockReq>[];
  if (r.level > 1) {
    out.add(UnlockReq('Reach LEVEL ${r.level}',
        progress: 'LV ${p.level} / ${r.level}',
        fraction: (p.level / r.level).clamp(0.0, 1.0),
        done: p.level >= r.level));
  }
  if (r.km > 0) {
    out.add(UnlockReq('Run ${r.km.toStringAsFixed(0)} km in total',
        progress:
            '${p.totalKm.toStringAsFixed(1)} / ${r.km.toStringAsFixed(0)} km',
        fraction: (p.totalKm / r.km).clamp(0.0, 1.0),
        done: p.totalKm >= r.km));
  }
  final s = r.stageId;
  if (s != null) {
    final m = RunMode.byId(s);
    out.add(UnlockReq('Clear ${m?.name ?? 'the rank'}',
        progress: p.cleared(s) ? 'CLEARED' : 'NOT YET', done: p.cleared(s)));
  }
  if (r.stars > 0) {
    out.add(UnlockReq('Collect ${r.stars} stars',
        progress: '${p.totalStars} / ${r.stars} ⭐',
        fraction: (p.totalStars / r.stars).clamp(0.0, 1.0),
        done: p.totalStars >= r.stars));
  }
  return out;
}

/// A friendly "where to do it" line for the first unmet goal.
String? unlockTip(UnlockRule r, HeroProgress p) {
  if (r.level > 1 && p.level < r.level) {
    return 'Every run earns XP. Longer and faster runs earn more!';
  }
  if (r.km > 0 && p.totalKm < r.km) {
    return 'All the distance you run counts, in any mode.';
  }
  final s = r.stageId;
  if (s != null && !p.cleared(s)) {
    return 'Open RUN, then STAGE MODE, and finish the rank before its clock runs out.';
  }
  if (r.stars > 0 && p.totalStars < r.stars) {
    return 'Finish ranks with time to spare to earn up to 3 ⭐ each.';
  }
  return null;
}

/// "HOW TO UNLOCK" pop-up: shows the picture, the rule with the player's
/// progress, and (when it can be bought) the price.
///
/// [priceLabel] example: "100 \u{1F48E}". When the goals are done and it is
/// for sale, pass [onBuy] to show a BUY button.
Future<void> showUnlockSheet(
  BuildContext context, {
  required String title,
  required String kind, // "EPIC HERO", "HEAD ITEM", "RANK"
  required Widget art,
  required List<UnlockReq> reqs,
  String? priceLabel,
  String? youHave, // "You have 40 \u{1F48E}"
  String? tip,
  bool canBuy = false,
  VoidCallback? onBuy,
  Color accent = Rb.blue,
  Color accentEdge = Rb.blueEdge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UnlockSheet(
      title: title,
      kind: kind,
      art: art,
      reqs: reqs,
      priceLabel: priceLabel,
      youHave: youHave,
      tip: tip,
      canBuy: canBuy,
      onBuy: onBuy,
      accent: accent,
      accentEdge: accentEdge,
    ),
  );
}

/// Small message pop-up with one optional action button.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
  required Widget art,
  String? actionLabel,
  VoidCallback? onAction,
  String closeLabel = 'GOT IT',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Block(
          color: const Color(0xFF9A9EA3),
          edge: Colors.black,
          depth: 8,
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Block(
                  color: const Color(0xFFCBD5E1),
                  edge: Rb.slateEdge,
                  depth: 4,
                  radius: 14,
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(width: 70, height: 90, child: art),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlockText(title, size: 19, stroke: 4.5),
                ),
              ]),
              const SizedBox(height: 12),
              Text(message,
                  style: const TextStyle(
                      color: Color(0xFF1F2327),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (actionLabel != null && onAction != null) ...[
                PressBlock(
                  color: Rb.green,
                  edge: Rb.greenEdge,
                  depth: 7,
                  radius: 14,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAction();
                  },
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(
                        child: BlockText(actionLabel, size: 16, stroke: 4)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              PressBlock(
                color: Rb.blue,
                edge: Rb.blueEdge,
                depth: 7,
                radius: 14,
                silent: true,
                padding: const EdgeInsets.symmetric(vertical: 13),
                onTap: () => Navigator.of(ctx).maybePop(),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                      child: BlockText(closeLabel, size: 16, stroke: 4)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pop-up for a locked MODE (rank, endless, interval, trial).
Future<void> showModeLockedSheet(
  BuildContext context,
  RunMode m,
  Object? records, {
  Widget? art,
}) {
  final need = m.requiresId == null ? null : RunMode.byId(m.requiresId!);
  final done = need != null && RunMode.starsIn(records, need.id) > 0;
  final what = need == null
      ? 'Open from the start'
      : need.isTrial
          ? 'Clear the ${trialTimeLabel(need)} ${trialGroupLabel(need)} trial'
          : 'Clear ${need.name}';
  final how = need == null
      ? null
      : need.isTrial
          ? 'Finish that distance inside its time goal to open this one.'
          : 'Open RUN, then STAGE MODE, and clear ${need.name} to open this.';
  return showUnlockSheet(
    context,
    title: m.name,
    kind: m.isTrial
        ? 'DISTANCE TRIAL'
        : m.isStage
            ? 'STAGE RANK'
            : 'RUN MODE',
    art: art ?? Center(child: Text(m.emoji, style: const TextStyle(fontSize: 54))),
    reqs: [UnlockReq(what, progress: done ? 'CLEARED' : 'NOT YET', done: done)],
    tip: how,
    accent: m.color,
    accentEdge: m.edge,
  );
}

class _UnlockSheet extends StatelessWidget {
  final String title, kind;
  final Widget art;
  final List<UnlockReq> reqs;
  final String? priceLabel, youHave, tip;
  final bool canBuy;
  final VoidCallback? onBuy;
  final Color accent, accentEdge;

  const _UnlockSheet({
    required this.title,
    required this.kind,
    required this.art,
    required this.reqs,
    required this.priceLabel,
    required this.youHave,
    required this.tip,
    required this.canBuy,
    required this.onBuy,
    required this.accent,
    required this.accentEdge,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = reqs.every((r) => r.done);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Block(
          color: const Color(0xFF9A9EA3),
          edge: Colors.black,
          depth: 8,
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Block(
                      color: const Color(0xFFCBD5E1),
                      edge: accentEdge,
                      depth: 4,
                      radius: 14,
                      padding: const EdgeInsets.all(4),
                      child: SizedBox(
                        width: 84,
                        height: 104,
                        child: ColorFiltered(
                          colorFilter: allDone
                              ? const ColorFilter.mode(
                                  Colors.transparent, BlendMode.dst)
                              : const ColorFilter.matrix(<double>[
                                  0.45, 0.45, 0.45, 0, 0, //
                                  0.45, 0.45, 0.45, 0, 0,
                                  0.45, 0.45, 0.45, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                          child: art,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: BlockText(title, size: 22, stroke: 5),
                          ),
                          const SizedBox(height: 4),
                          Block(
                            color: accent,
                            edge: accentEdge,
                            depth: 3,
                            radius: 8,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            child: BlockText(kind, size: 10.5, stroke: 3),
                          ),
                          const SizedBox(height: 6),
                          BlockText(
                              allDone ? '✅ READY!' : '\u{1F512} LOCKED',
                              size: 13,
                              stroke: 3.5,
                              color: allDone
                                  ? const Color(0xFF7CFFB0)
                                  : const Color(0xFFFFD21F)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const BlockText('HOW TO GET IT', size: 13, stroke: 3.5),
                const SizedBox(height: 6),
                for (final r in reqs) ...[
                  _reqRow(r),
                  const SizedBox(height: 6),
                ],
                if (priceLabel != null) _priceRow(),
                if (tip != null) ...[
                  const SizedBox(height: 6),
                  Text('\u{1F4A1} $tip',
                      style: const TextStyle(
                          color: Color(0xFF1F2327),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 14),
                if (canBuy && onBuy != null) ...[
                  PressBlock(
                    color: Rb.orange,
                    edge: Rb.orangeEdge,
                    depth: 7,
                    radius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: () {
                      Navigator.of(context).pop();
                      onBuy!();
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: Center(
                          child: BlockText('BUY ${priceLabel ?? ''}',
                              size: 17, stroke: 4)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                PressBlock(
                  color: Rb.blue,
                  edge: Rb.blueEdge,
                  depth: 7,
                  radius: 14,
                  silent: true,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Center(child: BlockText('GOT IT', size: 17, stroke: 4)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reqRow(UnlockReq r) {
    return Block(
      color: r.done ? const Color(0xFF1E6B45) : Rb.panel,
      edge: r.done ? const Color(0xFF0B2E1D) : Rb.panelEdge,
      depth: 4,
      radius: 12,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(r.done ? '✅' : '⬜', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: BlockText(r.text, size: 13.5, stroke: 3.5),
                  ),
                ),
              ),
              if (r.progress != null) ...[
                const SizedBox(width: 8),
                BlockText(r.progress!,
                    size: 11.5,
                    stroke: 3,
                    color: r.done ? const Color(0xFF7CFFB0) : const Color(0xFFFFD21F)),
              ],
            ],
          ),
          if (r.fraction != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: r.fraction,
                minHeight: 8,
                backgroundColor: Rb.track,
                valueColor: AlwaysStoppedAnimation(
                    r.done ? Rb.neon : Rb.gold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow() {
    return Block(
      color: Rb.slate,
      edge: Rb.slateEdge,
      depth: 4,
      radius: 12,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          const Text('\u{1F6D2}', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BlockText(
                    reqs.isEmpty
                        ? 'Buy it for $priceLabel'
                        : 'Then buy it for $priceLabel',
                    size: 13.5,
                    stroke: 3.5),
              ),
            ),
          ),
          if (youHave != null)
            BlockText(youHave!,
                size: 11.5, stroke: 3, color: const Color(0xFFD7DADD)),
        ],
      ),
    );
  }
}


/// "Are you sure?" pop-up: CONFIRM runs [onConfirm], CANCEL just closes.
Future<void> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required Widget art,
  required String confirmLabel,
  required VoidCallback onConfirm,
}) {
  return showInfoSheet(
    context,
    title: title,
    message: message,
    art: art,
    actionLabel: confirmLabel,
    onAction: onConfirm,
    closeLabel: 'CANCEL',
  );
}

/// Same look as the unlock pop-up, for "you can't afford this yet".
/// Shows how far the player is and where crystals / coins come from.
Future<void> showNeedMoreSheet(
  BuildContext context, {
  required String what,
  int needGems = 0,
  int haveGems = 0,
  int needCoins = 0,
  int haveCoins = 0,
  Widget? art,
}) {
  final reqs = <UnlockReq>[
    if (needGems > 0)
      UnlockReq('Get $needGems \u{1F48E} crystals',
          progress: '$haveGems / $needGems',
          fraction: (haveGems / needGems).clamp(0.0, 1.0),
          done: haveGems >= needGems),
    if (needCoins > 0)
      UnlockReq('Get $needCoins \u{1FA99} coins',
          progress: '$haveCoins / $needCoins',
          fraction: (haveCoins / needCoins).clamp(0.0, 1.0),
          done: haveCoins >= needCoins),
  ];
  final gemsShort = needGems > haveGems;
  return showUnlockSheet(
    context,
    title: what,
    kind: gemsShort ? 'NOT ENOUGH CRYSTALS' : 'NOT ENOUGH COINS',
    art: art ??
        Center(
            child: Text(gemsShort ? '\u{1F48E}' : '\u{1FA99}',
                style: const TextStyle(fontSize: 54))),
    reqs: reqs,
    tip: gemsShort
        ? 'Crystals come from daily quests, first clears and stars on ranks, streak rewards and the weekly goal.'
        : 'Coins come from every run. The more km, the more coins!',
    accent: Rb.orange,
    accentEdge: Rb.orangeEdge,
  );
}
