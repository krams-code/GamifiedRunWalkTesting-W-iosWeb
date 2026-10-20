import '../utils/player_stats.dart' show LevelProgress;
import 'run_mode.dart';

/// Everything the hero / item unlock rules need to know about a player,
/// read once from the users/{uid} map so the shop, wardrobe and hero picker
/// can never disagree.
class HeroProgress {
  final int coins;
  final int xp;
  final int level;
  final double totalKm;

  /// users/{uid}.stage_records (stars per rank).
  final Object? records;

  /// Bought items / heroes (users/{uid}.owned_items, .owned_heroes).
  final Set<String> ownedItems;
  final Set<String> ownedHeroes;

  const HeroProgress({
    this.coins = 0,
    this.xp = 0,
    this.level = 1,
    this.totalKm = 0,
    this.records,
    this.ownedItems = const <String>{},
    this.ownedHeroes = const <String>{},
  });

  factory HeroProgress.fromData(Map<String, dynamic>? d) {
    final m = d ?? const <String, dynamic>{};
    Set<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toSet() : <String>{};
    final xp = (m['xp'] as num?)?.toInt() ?? 0;
    return HeroProgress(
      coins: (m['coins'] as num?)?.toInt() ?? 0,
      xp: xp,
      level: LevelProgress.fromXp(xp).level,
      totalKm: (m['total_km'] as num?)?.toDouble() ?? 0.0,
      records: m['stage_records'],
      ownedItems: strings(m['owned_items']),
      ownedHeroes: strings(m['owned_heroes']),
    );
  }

  int get totalStars => RunMode.totalStars(records);
  bool cleared(String stageId) => RunMode.starsIn(records, stageId) > 0;
}

/// The requirements an item or hero can have. All of them must be met.
/// (A price is separate: priced things must also be BOUGHT.)
class UnlockRule {
  final int level; // 0 = none
  final double km; // total km, 0 = none
  final String? stageId; // stage rank that must be cleared
  final int stars; // total stars, 0 = none

  const UnlockRule({this.level = 0, this.km = 0, this.stageId, this.stars = 0});

  static const UnlockRule none = UnlockRule();

  bool get isNone => level <= 1 && km <= 0 && stageId == null && stars <= 0;

  bool met(HeroProgress p) {
    if (level > 1 && p.level < level) return false;
    if (km > 0 && p.totalKm < km) return false;
    final s = stageId;
    if (s != null && !p.cleared(s)) return false;
    if (stars > 0 && p.totalStars < stars) return false;
    return true;
  }

  /// Short reason shown on locks, e.g. "Reach LV 5" (null when no rule).
  String? get label {
    final parts = <String>[];
    if (level > 1) parts.add('Reach LV $level');
    if (km > 0) parts.add('Run ${km.toStringAsFixed(0)} total km');
    final s = stageId;
    if (s != null) {
      final r = RunMode.byId(s);
      if (r != null) parts.add('Clear ${r.name}');
    }
    if (stars > 0) parts.add('Collect $stars stars');
    return parts.isEmpty ? null : parts.join(' + ');
  }
}
