import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/reward_popup.dart';
import '../../services/sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/body_composition.dart';
import '../../models/character_profile.dart';
import '../../models/hero_items.dart';
import '../../models/hero_progress.dart';
import '../../models/hero_roster.dart';
import '../../state/evolution_state.dart';
import '../../widgets/block_ui.dart';
import '../../widgets/unlock_sheet.dart';
import '../../widgets/hero_rig.dart';
import '../../state/user_doc.dart';
import '../../widgets/lottie_fx.dart';

/// Turns a Firestore error into something a tester can report.
String saveErrorText(Object e, [String fallback = 'Could not save. Try again.']) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'Blocked by the server rules (permission-denied). Publish the latest firestore.rules.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No connection. Check your internet and try again.';
      case 'not-found':
        return 'Your profile was not found. Log out and back in.';
      default:
        return '$fallback (${e.code})';
    }
  }
  return fallback;
}

/// Choose a hero.
///
///  * [firstTime]: the one-time choice on day one. Only the starter heroes
///    can be picked, there is no back button, and the screen closes (returning
///    true) once a hero is saved.
///  * otherwise: switch between every hero the player has unlocked, and buy
///    heroes that are for sale. Locked heroes show how to get them.
///
/// Saved on users/{uid}: `hero_id`, `owned_heroes` (bought / chosen).
class HeroPickerScreen extends StatefulWidget {
  final bool firstTime;
  const HeroPickerScreen({super.key, this.firstTime = false});

  @override
  State<HeroPickerScreen> createState() => _HeroPickerScreenState();
}

class _HeroPickerScreenState extends State<HeroPickerScreen> {
  RigPose _pose = RigPose.jog;
  BodyTier? _previewTier; // null = the player's real form
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _choose(HeroDef h) async {
    final doc = _doc;
    if (doc == null || _saving) return;
    setState(() => _saving = true);
    try {
      await doc.set({
        'hero_id': h.id,
        'owned_heroes': FieldValue.arrayUnion([h.id]),
      }, SetOptions(merge: true));
      if (widget.firstTime && mounted) {
        Navigator.of(context).pop(true);
        return;
      }
      _snack(h.costume
          ? 'You are now wearing the ${h.name} costume!'
          : '${h.name} is back as your hero!');
    } catch (e) {
      debugPrint('hero save failed: $e');
      _snack(saveErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _buy(HeroDef h) async {
    final doc = _doc;
    if (doc == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(doc);
        final coins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (coins < h.coinPrice) throw 'coins';
        txn.update(doc, {
          'coins': FieldValue.increment(-h.coinPrice),
          'owned_heroes': FieldValue.arrayUnion([h.id]),
          'hero_id': h.id,
        });
      });
      if (mounted) {
        await showRewardPopup(context,
            emoji: '\u{1F389}',
            title: 'HERO UNLOCKED!',
            subtitle: '${h.name} joins your team.',
            fx: Fx.unlockBurst,
            sound: Sfx.unlock,
            color: const Color(0xFF5B3A9E),
            edge: const Color(0xFF2A1A52));
      }
    } catch (e) {
      debugPrint('hero buy failed: $e');
      _snack(e == 'coins' ? 'Not enough \u{1FA99} coins.' : saveErrorText(e, 'Purchase failed. Try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return PopScope(
      canPop: !widget.firstTime,
      child: Scaffold(
        backgroundColor: Rb.bg,
        body: SafeArea(
          child: doc == null
              ? const Center(child: BlockText('Please sign in', size: 18))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: UserDoc.instance.stream,
                  initialData: UserDoc.instance.snapshotFor(doc.id),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LoadingRunner();
                    }
                    final data = snap.data!.data() ?? const <String, dynamic>{};
                    final chosen = hasChosenHero(data) ? heroIdOf(data) : null;
                    final prog = HeroProgress.fromData(data);
                    final outfit = outfitOf(data);
                    return ValueListenableBuilder<BodyCompositionState>(
                      valueListenable: EvolutionState.instance.composition,
                      builder: (_, form, __) {
                        final tier = _previewTier ?? form.tier;
                        return _content(context, prog, chosen, outfit, form.tier, tier);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, HeroProgress prog, String? chosen,
      HeroOutfit outfit, BodyTier realTier, BodyTier tier) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            if (!widget.firstTime) ...[
              PressBlock(
                color: Rb.slot,
                edge: Rb.panelEdge,
                depth: 4,
                radius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => Navigator.of(context).maybePop(),
                child: const BlockText('◀ BACK', size: 13, stroke: 3),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: BlockText(
                widget.firstTime ? 'CHOOSE YOUR COSTUME' : 'YOUR COSTUMES',
                size: 20,
                stroke: 4,
              ),
            ),
            if (!widget.firstTime)
              Block(
                color: Rb.panel,
                edge: Rb.panelEdge,
                depth: 3,
                radius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: BlockText('${prog.coins} \u{1FA99}', size: 13, stroke: 3),
              ),
          ],
        ),
        if (widget.firstTime) ...[
          const SizedBox(height: 6),
          const Text(
            'Pick the look that runs with you. SPROUT is the main hero you can fully customize with shop gear; the other costumes are ready-made looks. More unlock as you play, and you can switch any time.',
            style: TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
          ),
        ],
        const SizedBox(height: 14),

        // preview controls
        Block(
          color: Rb.panel,
          edge: Rb.panelEdge,
          depth: 5,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BlockText('PREVIEW MOVE', size: 12, stroke: 3),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in RigPose.values)
                    _chip(p.name.toUpperCase(), _pose == p,
                        () => setState(() => _pose = p)),
                ],
              ),
              const SizedBox(height: 12),
              const BlockText('PREVIEW BODY FORM', size: 12, stroke: 3),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in BodyTier.values)
                    _chip(
                      t == realTier
                          ? '${t.label.toUpperCase()} (YOU)'
                          : t.label.toUpperCase(),
                      tier == t,
                      () => setState(() => _previewTier = t == realTier ? null : t),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Your hero follows your weight check-in. Try each form to see how it changes.',
                style: TextStyle(color: Color(0xFFD0D5DB), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        for (final h in kHeroes) ...[
          _heroCard(h, prog, chosen, outfit, tier),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => PressBlock(
        color: on ? Rb.blue : Rb.slot,
        edge: on ? Rb.blueEdge : Rb.panelEdge,
        depth: 3,
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: onTap,
        child: BlockText(label, size: 11, stroke: 3),
      );

  /// Switching hero asks first ("are you sure?"). The very first pick is free.
  void _confirmChoose(HeroDef h, String? chosen, BodyTier tier) {
    final old = heroById(chosen);
    if (widget.firstTime || old == null || old.id == h.id) {
      _choose(h);
      return;
    }
    showConfirmSheet(
      context,
      title: 'CHANGE COSTUME?',
      message: 'Switch from ${old.name} to ${h.name}? '
          '${h.costume && !old.costume ? '${h.name} wears its own outfit, so your shop gear stays saved for SPROUT. ' : ''}'
          'You can switch back any time.',
      art: HeroStill(heroId: h.id, tier: tier),
      confirmLabel: 'YES, CHANGE',
      onConfirm: () => _choose(h),
    );
  }

  /// Buying also makes it your hero, so it gets the same question.
  void _confirmBuy(HeroDef h, String? chosen, BodyTier tier) {
    final old = heroById(chosen);
    showConfirmSheet(
      context,
      title: 'BUY ${h.name}?',
      message: 'Spend ${h.coinPrice} \u{1FA99} and switch your look '
          '${old == null ? '' : 'from ${old.name} '}to ${h.name}?',
      art: HeroStill(heroId: h.id, tier: tier),
      confirmLabel: 'YES, BUY',
      onConfirm: () => _buy(h),
    );
  }

  void _showHow(HeroDef h, HeroProgress prog, BodyTier tier, [String? chosen]) {
    final price = h.coinPrice > 0 ? '${h.coinPrice} \u{1FA99}' : null;
    final goalsDone = h.rule.met(prog);
    showUnlockSheet(
      context,
      title: h.name,
      kind: h.id == kDefaultHeroId ? 'MAIN HERO' : '${h.rarityLabel} COSTUME',
      art: HeroStill(heroId: h.id, tier: tier),
      reqs: [
        ...unlockReqs(h.rule, prog),
        if (price != null)
          UnlockReq('Get ${h.coinPrice} \u{1FA99} coins',
              progress: '${prog.coins} / ${h.coinPrice}',
              fraction: (prog.coins / h.coinPrice).clamp(0.0, 1.0),
              done: prog.coins >= h.coinPrice),
      ],
      priceLabel: price,
      youHave: price == null ? null : 'You have ${prog.coins} \u{1FA99}',
      tip: unlockTip(h.rule, prog) ??
          (price != null && prog.coins < h.coinPrice
              ? 'Coins come from daily quests, first rank clears and stars.'
              : null),
      canBuy: !widget.firstTime && goalsDone && prog.coins >= h.coinPrice && h.coinPrice > 0,
      onBuy: () => _confirmBuy(h, chosen, tier),
      accent: h.color,
      accentEdge: h.edge,
    );
  }

  Widget _heroCard(HeroDef h, HeroProgress prog, String? chosen,
      HeroOutfit outfit, BodyTier tier) {
    final open = isHeroUnlocked(h, prog);
    final selected = chosen == h.id;
    final hint = heroLockHint(h, prog);
    final canBuy = !open && heroCanBuy(h, prog) && !widget.firstTime;
    final affordable = prog.coins >= h.coinPrice;

    final figure = SizedBox(
      width: 110,
      height: 150,
      child: open || canBuy
          ? HeroRig(heroId: h.id, tier: tier, pose: _pose, height: 150, outfit: open ? outfit : const {})
          : ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2, 0.2, 0.2, 0, 0, //
                0.2, 0.2, 0.2, 0, 0,
                0.2, 0.2, 0.2, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: HeroStill(heroId: h.id, tier: tier),
            ),
    );

    Widget action;
    VoidCallback? onTap;
    if (open) {
      action = Block(
        color: selected ? Rb.gold : Rb.green,
        edge: selected ? Rb.goldEdge : Rb.greenEdge,
        depth: 3,
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: BlockText(
          selected ? '✔ SELECTED' : (widget.firstTime ? 'TAP TO CHOOSE' : 'TAP TO SELECT'),
          size: 12,
          stroke: 3,
        ),
      );
      onTap = (_saving || (selected && !widget.firstTime)) ? null : () => _confirmChoose(h, chosen, tier);
    } else if (canBuy) {
      action = Block(
        color: affordable ? Rb.orange : Rb.panel,
        edge: affordable ? Rb.orangeEdge : Rb.panelEdge,
        depth: 3,
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: BlockText('BUY ${h.coinPrice} \u{1FA99}', size: 12, stroke: 3),
      );
      onTap = _saving ? null : (affordable ? () => _confirmBuy(h, chosen, tier) : () => _showHow(h, prog, tier, chosen));
    } else {
      action = Block(
        color: Rb.panel,
        edge: Rb.panelEdge,
        depth: 3,
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: BlockText('\u{1F512} ${hint ?? 'Locked'}', size: 11, stroke: 3),
      );
      onTap = () => _showHow(h, prog, tier, chosen); // tap: how to unlock it
    }

    return PressBlock(
      color: h.color,
      edge: h.edge,
      depth: 6,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          figure,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlockText(h.name, size: 17, stroke: 4),
                const SizedBox(height: 2),
                Text(h.tagline,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                if (h.starter)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(h.id == kDefaultHeroId ? 'MAIN HERO \u2022 CUSTOMIZABLE' : 'STARTER COSTUME',
                        style: TextStyle(
                            color: Color(0xFFFFE9A8),
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                const SizedBox(height: 10),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
