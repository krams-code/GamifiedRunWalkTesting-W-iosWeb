import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_quest_definitions.dart';
import '../models/run_mode.dart';
import 'friends_service.dart';

/// Everything needed to save one finished run. Plain JSON, so it can sit in
/// the outbox on the phone while the player is offline.
class RunPayload {
  /// Unique per run (start time in ms). Saving the same id twice does nothing.
  final String id;
  final String uid;
  final String modeId;
  final String? outcome;
  final bool good;
  final double rewardMult;

  /// ActivitySession.toFirestore() with startTime / endTime as ms integers.
  final Map<String, dynamic> fields;
  final List<dynamic> challenges;
  final Map<String, dynamic>? ghost;
  final int xp;
  final int coins;
  final int gems; // challenge + ghost crystals
  final int lootChests;
  final int elapsedSeconds;

  const RunPayload({
    required this.id,
    required this.uid,
    required this.modeId,
    required this.outcome,
    required this.good,
    required this.rewardMult,
    required this.fields,
    required this.challenges,
    required this.ghost,
    required this.xp,
    required this.coins,
    required this.gems,
    required this.lootChests,
    required this.elapsedSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'modeId': modeId,
        'outcome': outcome,
        'good': good,
        'rewardMult': rewardMult,
        'fields': fields,
        'challenges': challenges,
        'ghost': ghost,
        'xp': xp,
        'coins': coins,
        'gems': gems,
        'lootChests': lootChests,
        'elapsedSeconds': elapsedSeconds,
      };

  factory RunPayload.fromJson(Map<String, dynamic> j) => RunPayload(
        id: j['id'] as String,
        uid: j['uid'] as String,
        modeId: j['modeId'] as String,
        outcome: j['outcome'] as String?,
        good: j['good'] as bool? ?? false,
        rewardMult: (j['rewardMult'] as num?)?.toDouble() ?? 1.0,
        fields: Map<String, dynamic>.from(j['fields'] as Map),
        challenges: List<dynamic>.from(j['challenges'] as List? ?? const []),
        ghost: j['ghost'] == null
            ? null
            : Map<String, dynamic>.from(j['ghost'] as Map),
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        gems: (j['gems'] as num?)?.toInt() ?? 0,
        lootChests: (j['lootChests'] as num?)?.toInt() ?? 0,
        elapsedSeconds: (j['elapsedSeconds'] as num?)?.toInt() ?? 0,
      );
}

/// What the summary card needs from a finished save.
class RunSaveResult {
  final List<DailyQuest> completedQuests;
  final int stars;
  final int bonusGems;
  final bool firstClear;
  final RunMode? unlockedRank;

  /// True when this run had already been saved before (nothing was written).
  final bool duplicate;

  const RunSaveResult({
    this.completedQuests = const [],
    this.stars = 0,
    this.bonusGems = 0,
    this.firstClear = false,
    this.unlockedRank,
    this.duplicate = false,
  });
}

/// Saves a run in ONE atomic, repeat-safe transaction: the activity, the
/// player totals, daily quests and the stage record all land together or not
/// at all. If it cannot finish (offline, slow network) the run goes into the
/// on-phone outbox and is re-sent later by [RunOutbox.flush].
abstract final class RunSaver {
  static const Duration timeout = Duration(seconds: 12);

  static String todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Future<RunSaveResult> save(RunPayload p) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(p.uid);
    final actRef = userRef.collection('activities').doc(p.id);
    final mode = RunMode.byId(p.modeId);
    final km = (p.fields['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final startMs = (p.fields['startTime'] as num).toInt();
    final endMs = (p.fields['endTime'] as num).toInt();
    final startHour = DateTime.fromMillisecondsSinceEpoch(startMs).hour;
    final today = todayString();

    var result = const RunSaveResult();

    await db.runTransaction((txn) async {
      // Transactions can retry: always start from a clean slate.
      result = const RunSaveResult();

      final existing = await txn.get(actRef);
      if (existing.exists) {
        result = const RunSaveResult(duplicate: true);
        return;
      }
      final snap = await txn.get(userRef);
      final data = snap.data() ?? <String, dynamic>{};

      final storedDate = data['daily_progress_date'] as String? ?? '';
      var dailyKm = (data['daily_progress_km'] as num?)?.toDouble() ?? 0.0;
      var claimed = Map<String, dynamic>.from(
          data['daily_quests_claimed'] as Map? ?? {});
      if (storedDate != today) {
        dailyKm = 0.0;
        claimed = {};
      }
      dailyKm += km;

      var crystals = 0;
      final done = <DailyQuest>[];
      for (final q in kDailyQuests) {
        if (claimed[q.id] == true) continue;
        if (q.beforeHour != null && startHour >= q.beforeHour!) continue;
        if (dailyKm >= q.thresholdKm) {
          claimed[q.id] = true;
          crystals += q.crystalReward;
          done.add(q);
        }
      }

      // Stage record: stars + first-clear bonus (cleared stages only).
      Map<String, dynamic>? records;
      var stars = 0, bonus = 0;
      var first = false;
      RunMode? opened;
      if (mode != null && mode.isStage && p.good) {
        final all =
            Map<String, dynamic>.from(data['stage_records'] as Map? ?? {});
        final old = Map<String, dynamic>.from(all[mode.id] as Map? ?? {});
        final oldStars = (old['stars'] as num?)?.toInt() ?? 0;
        final oldBest = (old['best_secs'] as num?)?.toInt() ?? 0;
        final oldClears = (old['clears'] as num?)?.toInt() ?? 0;
        stars = mode.starsFor(p.elapsedSeconds);
        first = oldStars == 0;
        final newStars = stars > oldStars ? stars - oldStars : 0;
        bonus = (first ? mode.firstClearGems : 0) + newStars * RunMode.starGems;
        all[mode.id] = {
          'stars': math.max(stars, oldStars),
          'best_secs': oldBest > 0
              ? math.min(oldBest, p.elapsedSeconds)
              : p.elapsedSeconds,
          'clears': oldClears + 1,
        };
        records = all;
        crystals += bonus;
        if (first) {
          for (final m in kRunModes) {
            if (m.requiresId == mode.id && m.isStage) opened = m;
          }
        }
      }

      final fields = Map<String, dynamic>.from(p.fields)
        ..['startTime'] = Timestamp.fromMillisecondsSinceEpoch(startMs)
        ..['endTime'] = Timestamp.fromMillisecondsSinceEpoch(endMs);

      txn.set(actRef, {
        ...fields,
        if (p.challenges.isNotEmpty) 'challenges': p.challenges,
        if (p.ghost != null) 'ghost': p.ghost,
        'mode': p.modeId,
        'reward_mult': p.rewardMult,
        if (p.outcome != null) 'stage_result': p.outcome,
      });

      final totalGems = p.gems + crystals;
      txn.update(userRef, {
        'total_km': FieldValue.increment(km),
        'total_sessions': FieldValue.increment(1),
        'xp': FieldValue.increment(p.xp),
        'coins': FieldValue.increment(p.coins),
        if (totalGems > 0) 'gems': FieldValue.increment(totalGems),
        if (p.lootChests > 0) 'loot_chests': FieldValue.increment(p.lootChests),
        'daily_progress_km': dailyKm,
        'daily_progress_date': today,
        'daily_quests_claimed': claimed,
        // feeds "friends this week" on the RUN tab
        ...FriendsService.weekFields(data, km),
        if (records != null) 'stage_records': records,
      });

      result = RunSaveResult(
        completedQuests: done,
        stars: stars,
        bonusGems: bonus,
        firstClear: first,
        unlockedRank: opened,
      );
    });

    return result;
  }
}

/// Runs that could not be saved yet. Lives in SharedPreferences, so it
/// survives closing the app. Re-sent on the next app start / next run.
abstract final class RunOutbox {
  static const _key = 'run_outbox_v1';
  static bool _flushing = false;

  static Future<List<RunPayload>> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(_key) ?? const <String>[];
      final out = <RunPayload>[];
      for (final s in raw) {
        try {
          out.add(RunPayload.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {
          // a damaged entry is dropped instead of blocking the queue
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _store(List<RunPayload> list) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(
          _key, [for (final p in list) jsonEncode(p.toJson())]);
    } catch (e) {
      debugPrint('RunOutbox store failed: $e');
    }
  }

  static Future<void> enqueue(RunPayload p) async {
    final list = await _load();
    if (list.any((e) => e.id == p.id)) return;
    list.add(p);
    await _store(list);
  }

  static Future<int> pendingCount(String uid) async =>
      (await _load()).where((p) => p.uid == uid).length;

  /// Tries to send every waiting run of [uid]. Returns how many went through.
  static Future<int> flush(String uid) async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final list = await _load();
      final left = <RunPayload>[];
      for (final p in list) {
        if (p.uid != uid) {
          left.add(p);
          continue;
        }
        try {
          await RunSaver.save(p).timeout(RunSaver.timeout);
          sent++;
        } catch (_) {
          left.add(p);
        }
      }
      if (sent > 0) await _store(left);
    } finally {
      _flushing = false;
    }
    return sent;
  }
}
