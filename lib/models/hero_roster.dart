import 'package:flutter/material.dart';

import 'character_profile.dart' show BodyTier, BodyTierExt;
import 'hero_progress.dart';

/// A playable block hero. The art lives in
/// assets/images/heroes/<id>/<bodyTier>/<layer>.png (see hero_rig.dart).
///
/// ADD A HERO: draw the 7 pictures per body form (generator), add one
/// HeroDef below, and add its folders to pubspec.yaml. Nothing else.
///
/// The chosen hero is saved as `hero_id` on users/{uid}; bought heroes go in
/// `owned_heroes`.
class HeroDef {
  final String id;
  final String name;
  final String tagline;
  final Color color;
  final Color edge;

  /// Anyone may pick this one on day one (the first-launch choice).
  final bool starter;

  /// Crystals to buy it (0 = not for sale, earned by [rule] instead).
  final int gemPrice;

  /// Level / km / rank / star requirement (all must be met).
  final UnlockRule rule;

  const HeroDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.color,
    required this.edge,
    this.starter = false,
    this.gemPrice = 0,
    this.rule = UnlockRule.none,
  });

  /// "Earned" heroes unlock by themselves when [rule] is met.
  bool get isEarned => gemPrice == 0 && !starter;
}

const String kDefaultHeroId = 'sprout';

const List<HeroDef> kHeroes = [
  HeroDef(
    id: 'sprout',
    name: 'SPROUT',
    tagline: 'Fresh legs, big heart',
    color: Color(0xFF00B06F),
    edge: Color(0xFF006B44),
    starter: true,
  ),
  HeroDef(
    id: 'ember',
    name: 'EMBER',
    tagline: 'Goggles on, speed up',
    color: Color(0xFFD98E00),
    edge: Color(0xFF7A4B00),
    starter: true,
  ),
  HeroDef(
    id: 'nova',
    name: 'NOVA',
    tagline: 'A star in the making',
    color: Color(0xFF5B3A9E),
    edge: Color(0xFF2A1A52),
    starter: true,
  ),
  HeroDef(
    id: 'blaze',
    name: 'BLAZE',
    tagline: 'Armoured and unstoppable',
    color: Color(0xFFE5484D),
    edge: Color(0xFF7A1C20),
    rule: UnlockRule(stageId: 'stage_vanguard'),
  ),
  HeroDef(
    id: 'frost',
    name: 'FROST',
    tagline: 'Cool head, hot pace',
    color: Color(0xFF2B8FD6),
    edge: Color(0xFF144E7A),
    rule: UnlockRule(level: 5),
  ),
  HeroDef(
    id: 'jade',
    name: 'JADE',
    tagline: 'Silent and swift',
    color: Color(0xFF1F9A6A),
    edge: Color(0xFF0B4A33),
    gemPrice: 120,
  ),
  HeroDef(
    id: 'shadow',
    name: 'SHADOW',
    tagline: 'Born in the Abyss Citadel',
    color: Color(0xFF3B3F55),
    edge: Color(0xFF14151F),
    rule: UnlockRule(stageId: 'stage_slayer'),
  ),
  HeroDef(
    id: 'aurum',
    name: 'AURUM',
    tagline: 'The golden champion',
    color: Color(0xFFE0A800),
    edge: Color(0xFF7A5A00),
    rule: UnlockRule(stars: 9),
  ),
];

/// The hero with this id, or null.
HeroDef? heroById(Object? id) {
  if (id is! String) return null;
  for (final h in kHeroes) {
    if (h.id == id) return h;
  }
  return null;
}

/// Hero id stored on a users/{uid} map. Falls back to the default hero for
/// accounts that have not chosen yet, so the classic avatar is never shown.
/// (Declared nullable only so older call sites keep compiling; never null.)
String? heroIdOf(Map<String, dynamic>? data) =>
    heroById(data?['hero_id'])?.id ?? kDefaultHeroId;

/// True once the player has made their hero choice (first launch).
bool hasChosenHero(Map<String, dynamic>? data) =>
    heroById(data?['hero_id']) != null;

/// Can [h] be used right now?
///  * starters: always
///  * priced heroes: only once bought
///  * earned heroes: automatically when the rule is met
bool isHeroUnlocked(HeroDef h, HeroProgress p) {
  if (h.starter) return true;
  if (p.ownedHeroes.contains(h.id)) return true;
  if (h.gemPrice > 0) return false;
  return h.rule.met(p);
}

/// Why [h] is locked ("Reach LV 5", "120 💎"), null when open.
String? heroLockHint(HeroDef h, HeroProgress p) {
  if (isHeroUnlocked(h, p)) return null;
  if (h.gemPrice > 0) return 'Buy for ${h.gemPrice} \u{1F48E}';
  return h.rule.label ?? 'Locked';
}

/// assets/images/heroes/ember/overweight/arm_front.png
String heroLayerAsset(String heroId, BodyTier tier, String layer) =>
    'assets/images/heroes/$heroId/${tier.id}/$layer.png';

/// Body form label ("Obese") for previews.
String heroTierLabel(BodyTier t) => t.label;
