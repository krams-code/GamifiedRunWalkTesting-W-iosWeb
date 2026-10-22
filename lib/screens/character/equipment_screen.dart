import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/body_composition.dart';
import '../../models/character_profile.dart' show BodyTier, BodyCompositionTierX;
import '../../models/hero_items.dart';
import '../../models/hero_progress.dart';
import '../../models/hero_roster.dart';
import '../../state/evolution_state.dart';
import '../../widgets/block_ui.dart';
import '../../widgets/hero_rig.dart';
import '../../widgets/scene_backdrop.dart';
import '../../widgets/pixel_icon.dart';
import '../shop/avatar_shop_screen.dart' show ItemCrop;
import '../../state/user_doc.dart';
import '../../widgets/lottie_fx.dart';
import '../../widgets/unlock_sheet.dart' show showConfirmSheet;

// ═════════════════════════════════════════════════════════════════
//  WARDROBE (the GEAR tab): switch hero, and dress them with the
//  items the player owns or has earned. Buying lives in the Shop.
//
//  Reads  users/{uid}: hero_id, owned_heroes, owned_items, hero_outfit + the
//                      numbers the unlock rules use (xp, total_km, stage_records)
//  Writes users/{uid}: hero_id, hero_outfit.<slot>
// ═════════════════════════════════════════════════════════════════

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  HeroSlot _slot = HeroSlot.head;
  RigPose _pose = RigPose.idle;
  bool _busy = false;

  DocumentReference<Map<String, dynamic>>? get _ref {
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

  Future<void> _wear(HeroItem i, bool on) async {
    final ref = _ref;
    if (ref == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.update({
        'hero_outfit.${i.slot.name}': on ? i.id : FieldValue.delete(),
      });
    } catch (_) {
      _snack('Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takeOffSlot(HeroSlot s) async {
    final ref = _ref;
    if (ref == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.update({'hero_outfit.${s.name}': FieldValue.delete()});
    } catch (_) {
      _snack('Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gear is only drawn on SPROUT. Tapping gear while wearing a costume asks
  /// to switch back to SPROUT first.
  void _askWear(HeroItem i, String heroId) {
    final sprout = heroById(kDefaultHeroId);
    final costume = heroById(heroId);
    if (sprout == null) return;
    showConfirmSheet(
      context,
      title: 'SWITCH TO SPROUT?',
      message: '${costume?.name ?? 'Costumes'} comes with its own outfit, so gear '
          'can only be worn by SPROUT, your main hero. Switch to SPROUT and wear ${i.name}?',
      art: HeroStill(heroId: kDefaultHeroId, tier: BodyTier.normal),
      confirmLabel: 'YES, SWITCH & WEAR',
      onConfirm: () async {
        await _switchHero(sprout, quiet: true);
        await _wear(i, true);
      },
    );
  }

  Future<void> _switchHero(HeroDef h, {bool quiet = false}) async {
    final ref = _ref;
    if (ref == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.set({
        'hero_id': h.id,
        'owned_heroes': FieldValue.arrayUnion([h.id]),
      }, SetOptions(merge: true));
      if (!quiet) {
        _snack(h.costume
            ? 'You are now wearing the ${h.name} costume!'
            : '${h.name} is back as your hero!');
      }
    } catch (_) {
      _snack('Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = _ref;
    if (ref == null) {
      return const Scaffold(
        backgroundColor: Rb.bg,
        body: LoadingRunner(),
      );
    }
    return Scaffold(
      backgroundColor: Rb.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: UserDoc.instance.stream,
          initialData: UserDoc.instance.snapshotFor(ref.id),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const LoadingRunner();
            }
            final data = snap.data!.data() ?? <String, dynamic>{};
            return ValueListenableBuilder<BodyCompositionState>(
              valueListenable: EvolutionState.instance.composition,
              builder: (_, form, __) => _body(
                context,
                HeroProgress.fromData(data),
                outfitOf(data),
                heroIdOf(data) ?? kDefaultHeroId,
                form.tier,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, HeroProgress prog, HeroOutfit worn,
      String heroId, BodyTier tier) {
    final hero = heroById(heroId);
    // costumes wear their own outfit: no gear is shown as worn on them
    if (hero?.costume ?? false) worn = <String, String>{};
    final mine = [
      for (final i in heroItemsIn(_slot))
        if (isItemUnlocked(i, prog)) i,
    ];
    final locked = heroItemsIn(_slot).length - mine.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const BlockText('\u{1F392} WARDROBE', size: 18, stroke: 4),
        const SizedBox(height: 8),

        // hero + pose
        Block(
          color: hero?.color ?? Rb.panel,
          edge: hero?.edge ?? Rb.panelEdge,
          depth: 5,
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SceneBackdrop(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 150 * SceneBackdrop.grassFraction,
                        child: SizedBox(
                          height: 150 * (1 - SceneBackdrop.grassFraction) - 6,
                          child: HeroRig(
                              heroId: heroId,
                              tier: tier,
                              pose: _pose,
                              height:
                                  150 * (1 - SceneBackdrop.grassFraction) - 6,
                              outfit: worn),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlockText(hero?.name ?? 'HERO', size: 16, stroke: 3.5),
                    const SizedBox(height: 2),
                    Text(hero?.tagline ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const BlockText('WEARING', size: 10, stroke: 3),
                    const SizedBox(height: 4),
                    if (hero?.costume ?? false)
                      const Text('Its own costume outfit.',
                          style: TextStyle(color: Colors.white, fontSize: 12))
                    else if (worn.isEmpty)
                      const Text('Nothing yet. Pick items below.',
                          style: TextStyle(color: Colors.white, fontSize: 12))
                    else
                      for (final s in kSlotDrawOrder.reversed)
                        if (worn[s.name] != null)
                          if (heroItemById(worn[s.name]) case final it?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  PixelIcon(it.iconPath, size: 16),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(it.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in RigPose.values)
                          PressBlock(
                            color: _pose == p ? Rb.blue : Rb.slot,
                            edge: _pose == p ? Rb.blueEdge : Rb.panelEdge,
                            depth: 2,
                            radius: 8,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            onTap: () => setState(() => _pose = p),
                            child: BlockText(p.name.toUpperCase(),
                                size: 10, stroke: 2.5),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // hero switcher
        const BlockText('YOUR COSTUMES', size: 13, stroke: 3),
        const SizedBox(height: 6),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final h in kHeroes)
                if (isHeroUnlocked(h, prog))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _heroTile(h, h.id == heroId, tier),
                  ),
            ],
          ),
        ),
        if (hero?.costume ?? false) ...[
          const SizedBox(height: 8),
          Block(
            color: const Color(0xFF3A3F46),
            edge: Rb.panelEdge,
            depth: 3,
            radius: 10,
            padding: const EdgeInsets.all(8),
            child: Text(
              '\u{1F3AD} ${hero!.name} is a costume with its own outfit, so gear can\'t be worn on it. Tap a gear item to switch back to SPROUT and wear it.',
              style: const TextStyle(
                  color: Color(0xFFFFE9A8), fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // slot tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in HeroSlot.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PressBlock(
                    color: _slot == s ? Rb.green : Rb.slot,
                    edge: _slot == s ? Rb.greenEdge : Rb.panelEdge,
                    depth: 3,
                    radius: 10,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onTap: () => setState(() => _slot = s),
                    child: BlockText('${s.emoji} ${s.label}', size: 11, stroke: 3),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (mine.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nothing owned for this slot yet. Visit the Shop or keep running to earn items!',
              style: TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
            ),
          )
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 8.0;
            final w = (c.maxWidth - gap * 3) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final i in mine)
                  _itemTile(i, w, worn[_slot.name] == i.id, heroId, tier),
              ],
            );
          }),
        const SizedBox(height: 12),
        if (worn[_slot.name] != null)
          PressBlock(
            color: Rb.slot,
            edge: Rb.panelEdge,
            depth: 4,
            radius: 10,
            padding: const EdgeInsets.symmetric(vertical: 10),
            onTap: _busy ? null : () => _takeOffSlot(_slot),
            child: Center(
                child: BlockText('TAKE OFF ${_slot.label}', size: 13, stroke: 3)),
          ),
        if (locked > 0) ...[
          const SizedBox(height: 10),
          Text(
            '$locked more ${_slot.label.toLowerCase()} item${locked == 1 ? '' : 's'} to buy or earn in the Shop.',
            style: const TextStyle(color: Color(0xFFD0D5DB), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _heroTile(HeroDef h, bool active, BodyTier tier) => PressBlock(
        color: active ? Rb.gold : h.color,
        edge: active ? Rb.goldEdge : h.edge,
        depth: 4,
        radius: 12,
        padding: const EdgeInsets.all(6),
        onTap: active || _busy ? null : () => _switchHero(h),
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              SizedBox(height: 56, child: HeroStill(heroId: h.id, tier: tier)),
              const SizedBox(height: 2),
              Text(active ? '✔ ${h.name}' : h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );

  Widget _itemTile(HeroItem i, double w, bool on, String heroId, BodyTier tier) =>
      SizedBox(
        width: w,
        child: PressBlock(
          color: on ? Rb.gold : Rb.slot,
          edge: on ? Rb.goldEdge : Rb.panelEdge,
          depth: 4,
          radius: 12,
          padding: const EdgeInsets.all(6),
          onTap: _busy
              ? null
              : (heroIsCostume(heroId) ? () => _askWear(i, heroId) : () => _wear(i, !on)),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: const Color(0xFF8FD0FF),
                    child: ItemCrop(
                        item: i,
                        heroId: heroIsCostume(heroId) ? kDefaultHeroId : heroId,
                        tier: tier),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(i.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              Text(on ? '✔ WORN' : 'TAP TO WEAR',
                  style: const TextStyle(
                      color: Color(0xFFFFE9A8), fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}
