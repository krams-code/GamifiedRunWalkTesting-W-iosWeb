import 'character_profile.dart' show BodyTier, BodyTierExt;
import 'hero_item_art.dart';
import 'hero_progress.dart';

/// Where an item is worn.
enum HeroSlot {
  head('HEAD', '\u{1F3A9}'),
  face('FACE', '\u{1F576}'),
  top('TOP', '\u{1F455}'),
  bottom('BOTTOM', '\u{1FA73}'),
  shoes('SHOES', '\u{1F45F}'),
  back('BACK', '\u{1F9B8}'),
  neck('NECK', '\u{1F9E3}');

  final String _label;
  final String emoji;
  const HeroSlot(this._label, this.emoji);

  String get label => _label;
}

/// Draw order of the slots, bottom to top. Used when several worn items
/// share one layer (e.g. bottoms and shoes both paint on the legs).
const List<HeroSlot> kSlotDrawOrder = [
  HeroSlot.back,
  HeroSlot.bottom,
  HeroSlot.shoes,
  HeroSlot.top,
  HeroSlot.neck,
  HeroSlot.face,
  HeroSlot.head,
];

/// One wearable. Art for it lives in hero_item_art.dart (generated).
///
/// HOW IT IS GOT:
///  * price 0 + no rule           free starter item
///  * price 0 + rule              EARNED: unlocks by itself (level / km / rank / stars)
///  * coins price                 BOUGHT once (rule must also be met, if any)
class HeroItem {
  final String id;
  final HeroSlot slot;
  final String name;
  final String emoji;

  /// 0 common · 1 rare · 2 epic · 3 legendary (colours the shop card).
  final int rarity;

  final int coins;
  final UnlockRule rule;

  const HeroItem(
    this.id,
    this.slot,
    this.name,
    this.emoji, {
    this.rarity = 0,
    this.coins = 0,
    this.rule = UnlockRule.none,
  });

  /// Pixel-art icon of this item (assets/images/icons/items).
  String get iconPath => 'assets/images/icons/items/item_$id.png';

  bool get isFree => coins == 0 && rule.isNone;
  bool get isEarned => coins == 0 && !rule.isNone;
  bool get isForSale => coins > 0;

  /// "120 \u{1FA99}" / "FREE" / "EARN".
  String get priceLabel {
    if (coins > 0) return '$coins \u{1FA99}';
    return isFree ? 'FREE' : 'EARN';
  }
}

const List<HeroItem> kHeroItems = [
  // ── HEAD ──
  HeroItem('cap_red', HeroSlot.head, 'Red Cap', '\u{1F9E2}'),
  HeroItem('beanie_blue', HeroSlot.head, 'Blue Beanie', '\u{1F9F6}',
      rule: UnlockRule(level: 2)),
  HeroItem('ears_cat', HeroSlot.head, 'Cat Ears', '\u{1F431}',
      rarity: 1, coins: 120),
  HeroItem('wizard_hat', HeroSlot.head, 'Wizard Hat', '\u{1F9D9}',
      rarity: 1, rule: UnlockRule(level: 10)),
  HeroItem('helm_knight', HeroSlot.head, 'Knight Helm', '\u{1FA96}',
      rarity: 1, rule: UnlockRule(stageId: 'stage_novice')),
  HeroItem('halo', HeroSlot.head, 'Angel Halo', '\u{1F607}',
      rarity: 2, coins: 400),
  HeroItem('crown_gold', HeroSlot.head, 'Gold Crown', '\u{1F451}',
      rarity: 3, rule: UnlockRule(stageId: 'stage_slayer')),

  // ── FACE ──
  HeroItem('stache', HeroSlot.face, 'Fancy Stache', '\u{1F468}',
      coins: 60),
  HeroItem('glasses_round', HeroSlot.face, 'Round Glasses', '\u{1F453}',
      coins: 80),
  HeroItem('shades', HeroSlot.face, 'Cool Shades', '\u{1F60E}',
      rarity: 1, coins: 150),
  HeroItem('mask_hero', HeroSlot.face, 'Hero Mask', '\u{1F9B9}',
      rarity: 1, rule: UnlockRule(level: 3)),

  // ── TOP ──
  HeroItem('tee_stripes', HeroSlot.top, 'Striped Tee', '\u{1F455}',
      coins: 100),
  HeroItem('hoodie_orange', HeroSlot.top, 'Orange Hoodie', '\u{1F9E5}',
      rarity: 1, rule: UnlockRule(level: 6)),
  HeroItem('jersey_bolt', HeroSlot.top, 'Bolt Jersey', '⚡',
      rarity: 1, coins: 200),
  HeroItem('gi_ninja', HeroSlot.top, 'Ninja Gi', '\u{1F977}',
      rarity: 2, coins: 350),
  HeroItem('armor_silver', HeroSlot.top, 'Silver Armor', '\u{1F6E1}',
      rarity: 2, rule: UnlockRule(stageId: 'stage_vanguard')),
  HeroItem('armor_gold', HeroSlot.top, 'Golden Armor', '\u{1F3C6}',
      rarity: 3, rule: UnlockRule(stars: 9)),

  // ── BOTTOM ──
  HeroItem('shorts_red', HeroSlot.bottom, 'Red Shorts', '\u{1FA73}'),
  HeroItem('pants_track', HeroSlot.bottom, 'Track Pants', '\u{1F456}',
      coins: 120),
  HeroItem('pants_camo', HeroSlot.bottom, 'Camo Pants', '\u{1F332}',
      rarity: 1, coins: 250),
  HeroItem('shorts_gold', HeroSlot.bottom, 'Gold Shorts', '\u{1F947}',
      rarity: 2, rule: UnlockRule(km: 25)),

  // ── SHOES ──
  HeroItem('sneak_red', HeroSlot.shoes, 'Red Sneakers', '\u{1F45F}'),
  HeroItem('runners_neon', HeroSlot.shoes, 'Neon Runners', '\u{1F3C3}',
      rarity: 1, rule: UnlockRule(level: 8)),
  HeroItem('boots_gold', HeroSlot.shoes, 'Gold Boots', '\u{1F97E}',
      rarity: 2, coins: 450),
  HeroItem('wing_shoes', HeroSlot.shoes, 'Winged Sneakers', '\u{1FABD}',
      rarity: 2, coins: 600),
  HeroItem('rocket_boots', HeroSlot.shoes, 'Rocket Boots', '\u{1F680}',
      rarity: 3, rule: UnlockRule(km: 100)),

  // ── BACK ──
  HeroItem('cape_red', HeroSlot.back, 'Hero Cape', '\u{1F9B8}',
      rarity: 1, rule: UnlockRule(level: 5)),
  HeroItem('backpack', HeroSlot.back, 'Hiker Backpack', '\u{1F392}',
      coins: 130),
  HeroItem('wings_bat', HeroSlot.back, 'Bat Wings', '\u{1F987}',
      rarity: 2, rule: UnlockRule(stars: 5)),
  HeroItem('wings_angel', HeroSlot.back, 'Angel Wings', '\u{1FABD}',
      rarity: 3, coins: 800),

  // ── NECK ──
  HeroItem('scarf_red', HeroSlot.neck, 'Red Scarf', '\u{1F9E3}',
      rule: UnlockRule(level: 4)),
  HeroItem('medal_gold', HeroSlot.neck, 'Gold Medal', '\u{1F3C5}',
      rarity: 1, rule: UnlockRule(km: 10)),
  HeroItem('belt_champ', HeroSlot.neck, 'Champion Belt', '\u{1F94A}',
      rarity: 2, rule: UnlockRule(km: 50)),
];

HeroItem? heroItemById(Object? id) {
  if (id is! String) return null;
  for (final i in kHeroItems) {
    if (i.id == id) return i;
  }
  return null;
}

List<HeroItem> heroItemsIn(HeroSlot slot) =>
    [for (final i in kHeroItems) if (i.slot == slot) i];

/// Is [i] wearable now? Free: yes. Priced: only once bought (and rule met).
/// Earned: when its rule is met.
bool isItemUnlocked(HeroItem i, HeroProgress p) {
  if (i.isFree) return true;
  if (!i.rule.isNone && !i.rule.met(p)) return false;
  if (i.isForSale) return p.ownedItems.contains(i.id);
  return true;
}

/// What the lock says: the rule, or the price when it is for sale.
String? itemLockHint(HeroItem i, HeroProgress p) {
  if (isItemUnlocked(i, p)) return null;
  if (!i.rule.isNone && !i.rule.met(p)) return i.rule.label;
  return i.priceLabel;
}

/// slot name -> item id, as saved in users/{uid}.hero_outfit.
typedef HeroOutfit = Map<String, String>;

/// Read the saved outfit, dropping unknown ids.
HeroOutfit outfitOf(Map<String, dynamic>? data) {
  final raw = data?['hero_outfit'];
  final out = <String, String>{};
  if (raw is Map) {
    for (final s in HeroSlot.values) {
      final item = heroItemById(raw[s.name]);
      if (item != null && item.slot == s) out[s.name] = item.id;
    }
  }
  return out;
}

/// SVG layers (full 286x512 canvas) of the worn items for one body layer,
/// bottom to top. [layer]: back | head | body | arm_back | arm_front |
/// leg_back | leg_front.
List<String> outfitSvgs(HeroOutfit outfit, BodyTier tier, String layer) {
  if (outfit.isEmpty) return const <String>[];
  final out = <String>[];
  for (final slot in kSlotDrawOrder) {
    final id = outfit[slot.name];
    if (id == null) continue;
    final svg = kHeroItemArt['$id/${tier.id}/$layer'];
    if (svg != null) out.add(svg);
  }
  return out;
}
