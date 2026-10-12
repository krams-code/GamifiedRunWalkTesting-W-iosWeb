import '../models/hero_items.dart';
import 'player_stats.dart';

/// What the EXP bar's sub-text says. Driven by the hero item catalog: any
/// free item gated by a level rule is an XP milestone reward.
class XpMilestone {
  final String text;
  final HeroItem? item;
  const XpMilestone(this.text, this.item);
}

/// The next free (level-gated) item above the player's level, or a plain XP target.
XpMilestone nextXpMilestone(int totalXp) {
  final lv = LevelProgress.fromXp(totalXp);
  HeroItem? next;
  for (final i in kHeroItems) {
    if (!i.isEarned || i.rule.level <= lv.level) continue;
    if (next == null || i.rule.level < next.rule.level) next = i;
  }
  if (next != null) {
    return XpMilestone(
        'Next Free Item: ${next.name} at Level ${next.rule.level}!', next);
  }
  final need = lv.xpNeeded - lv.xpIntoLevel;
  return XpMilestone('Earn $need XP to clear Milestone ${lv.level}!', null);
}
