import 'package:flutter/material.dart';

import '../challenges/challenge_engine.dart';

/// The two core game loops.
enum RunLoop { stage, endless }

/// Which mid-run events a mode triggers.
enum EventPlan { none, oneSprintQuest, paceTrials }

/// One selectable way to run: a Stage rank (Novice / Vanguard / Slayer) or
/// the casual Endless Run. Everything the run screen needs lives here, so
/// balancing a mode means editing ONE constant below.
class RunMode {
  final String id; // saved on the activity document
  final RunLoop loop;
  final String emoji;
  final String name; // "NOVICE RANK"
  final String mapName; // "The Verdant Vale"

  /// Distance to clear. Null = no target (Endless).
  final double? targetKm;

  /// Stage clock in minutes. Null = no clock (Endless).
  final int? clockMinutes;

  /// Multiplier on XP, coins and challenge crystals.
  final double rewardMult;

  final EventPlan events;
  final Color color;
  final Color edge;

  /// Map picture used as the live-run background and on the mode cards.
  final String mapAsset;

  /// One-time bonus crystals for the FIRST clear of this rank.
  final int firstClearGems;

  /// Rank that must be cleared (>= 1 star) before this one opens. Null = open.
  final String? requiresId;

  const RunMode({
    required this.id,
    required this.loop,
    required this.emoji,
    required this.name,
    required this.mapName,
    required this.targetKm,
    required this.clockMinutes,
    required this.rewardMult,
    required this.events,
    required this.color,
    required this.edge,
    required this.mapAsset,
    this.firstClearGems = 0,
    this.requiresId,
  });

  /// Every star you can collect across the three ranks.
  static const int maxStars = 9;

  /// Stars saved for [id] in the user's `stage_records` map.
  static int starsIn(Object? records, String id) {
    if (records is Map) {
      final r = records[id];
      if (r is Map) {
        final v = r['stars'];
        if (v is num) return v.toInt();
      }
    }
    return 0;
  }

  /// All stars earned so far (0..9).
  static int totalStars(Object? records) {
    var n = 0;
    for (final m in kStageModes) {
      n += starsIn(records, m.id);
    }
    return n;
  }

  /// Is [m] open? Novice and Endless always are; each rank needs the one
  /// before it cleared at least once.
  static bool isUnlocked(RunMode m, Object? records) {
    final need = m.requiresId;
    return need == null || starsIn(records, need) > 0;
  }

  /// "Clear NOVICE RANK to unlock" (null when already open / no requirement).
  String? get lockHint {
    final need = requiresId;
    if (need == null) return null;
    final r = byId(need);
    return r == null ? null : 'Clear ${r.name} to unlock';
  }

  /// Crystals for every NEW star earned on a rank (after the first clear).
  static const int starGems = 5;

  /// Stars for a cleared stage, by how much of the clock was left:
  /// ★ clear · ★★ clear with 1/3+ of the clock left · ★★★ with 1/2+ left.
  int starsFor(int secondsUsed) {
    final total = clockSeconds;
    if (total == null || total <= 0) return 0;
    final used = secondsUsed / total;
    if (used <= 0.5) return 3;
    if (used <= 2 / 3) return 2;
    return 1;
  }

  /// "Under 15:00" style goal for the 3-star / 2-star rows on the briefing.
  String starGoalLabel(int stars) {
    final total = clockSeconds ?? 0;
    final secs = stars == 3 ? (total * 0.5).round() : (total * 2 / 3).round();
    final m = secs ~/ 60, s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isStage => loop == RunLoop.stage;
  bool get isEndless => loop == RunLoop.endless;
  int? get clockSeconds => clockMinutes == null ? null : clockMinutes! * 60;

  String get multLabel => '${rewardMult.toStringAsFixed(1)}x';

  /// "1.0x XP & Crystals" / "+0.2x XP & Crystals per km"
  String get rewardLabel => isEndless
      ? '+$multLabel XP & Crystals per km'
      : '$multLabel XP & Crystals';

  String get eventLabel {
    switch (events) {
      case EventPlan.none:
        return isEndless ? 'No events. Just run.' : 'No sudden events';
      case EventPlan.oneSprintQuest:
        return '1 random Mid-Run Sprint Quest';
      case EventPlan.paceTrials:
        return 'Multiple high-velocity Pace Trials';
    }
  }

  /// Which events this mode fires, as an engine config.
  /// Returns null when the mode has no events (the engine stays off).
  ChallengeConfig? get challengeConfig {
    switch (events) {
      case EventPlan.none:
        return null;
      case EventPlan.oneSprintQuest:
        // exactly one Sprint Blitz, never a Pace Keeper
        // 100 m in 25 s = 14.4 km/h: a real sprint a fit runner can win.
        // (The old 300 m in 20 s needs 54 km/h, which nobody can do.)
        return const ChallengeConfig(
          sprintMinElapsedSeconds: 120,
          sprintChancePerSecond: 1 / 60,
          sprintMaxPerRun: 1,
          sprintTargetMeters: 100,
          sprintSeconds: 25,
          paceMaxPerRun: 0,
        );
      case EventPlan.paceTrials:
        // Pace Trials at 1.0 km and again 1 km after each trial ends;
        // no Sprint Blitz in this mode.
        return const ChallengeConfig(
          sprintMaxPerRun: 0,
          paceTriggerKm: 1.0,
          paceSectionKm: 1.0,
          paceSeconds: 300,
          paceMaxPerRun: 2,
          paceRepeatGapKm: 1.0,
        );
    }
  }

  /// Plain-language heads-up lines for the Stage Briefing card.
  List<String> get briefingWarnings {
    final cfg = challengeConfig;
    switch (events) {
      case EventPlan.none:
        return const ['No sudden events. Just reach the target before the clock runs out.'];
      case EventPlan.oneSprintQuest:
        return [
          '\u26A1 1 random Sprint Quest will appear mid-run: cover '
              '${cfg!.sprintTargetMeters.round()} m in ${cfg.sprintSeconds} s '
              '(+${cfg.sprintBonusXp} XP, +${cfg.sprintBonusGems} \u{1F48E}).',
        ];
      case EventPlan.paceTrials:
        final m = cfg!.paceSeconds ~/ 60, sec = cfg.paceSeconds % 60;
        return [
          '\u26A1 ${cfg.paceMaxPerRun} Pace Trials: run ${cfg.paceSectionKm.toStringAsFixed(1)} km '
              'in under $m:${sec.toString().padLeft(2, '0')} each.',
          'First one starts at ${cfg.paceTriggerKm.toStringAsFixed(1)} km. Beat it for a loot chest!',
        ];
    }
  }

  static RunMode? byId(String? id) {
    for (final m in kRunModes) {
      if (m.id == id) return m;
    }
    return null;
  }
}

const RunMode kNovice = RunMode(
  id: 'stage_novice',
  loop: RunLoop.stage,
  emoji: '\u{1F7E2}',
  name: 'NOVICE RANK',
  mapName: 'The Verdant Vale',
  targetKm: 1.5,
  clockMinutes: 30,
  rewardMult: 1.0,
  events: EventPlan.none,
  color: Color(0xFF00B06F),
  edge: Color(0xFF006B44),
  mapAsset: 'assets/images/maps/verdant_vale.jpg',
  firstClearGems: 10,
);

const RunMode kVanguard = RunMode(
  id: 'stage_vanguard',
  loop: RunLoop.stage,
  emoji: '\u{1F7E1}',
  name: 'VANGUARD RANK',
  mapName: 'The Ember Plains',
  targetKm: 3.5,
  clockMinutes: 45,
  rewardMult: 1.5,
  events: EventPlan.oneSprintQuest,
  color: Color(0xFFD98E00),
  edge: Color(0xFF7A4B00),
  mapAsset: 'assets/images/maps/ember_plains.jpg',
  firstClearGems: 25,
  requiresId: 'stage_novice',
);

const RunMode kSlayer = RunMode(
  id: 'stage_slayer',
  loop: RunLoop.stage,
  emoji: '\u{1F534}',
  name: 'SLAYER RANK',
  mapName: 'The Abyss Citadel',
  targetKm: 5.0,
  clockMinutes: 60,
  rewardMult: 2.5,
  events: EventPlan.paceTrials,
  color: Color(0xFFE5484D),
  edge: Color(0xFF7A1C20),
  mapAsset: 'assets/images/maps/abyss_citadel.jpg',
  firstClearGems: 50,
  requiresId: 'stage_vanguard',
);

const RunMode kEndless = RunMode(
  id: 'endless',
  loop: RunLoop.endless,
  emoji: '♾️',
  name: 'ENDLESS RUN',
  mapName: 'The Open Road',
  targetKm: null,
  clockMinutes: null,
  rewardMult: 0.2,
  events: EventPlan.none,
  color: Color(0xFF5B3A9E),
  edge: Color(0xFF2A1A52),
  mapAsset: 'assets/images/maps/open_road.jpg',
);

const List<RunMode> kStageModes = [kNovice, kVanguard, kSlayer];
const List<RunMode> kRunModes = [kNovice, kVanguard, kSlayer, kEndless];
