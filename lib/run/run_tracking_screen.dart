import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hakbanghero/models/activity_model.dart';
import 'package:hakbanghero/models/daily_quest_definitions.dart';
import 'package:hakbanghero/models/ghost_run.dart';
import '../models/run_mode.dart';
import '../services/run_saver.dart';

import '../challenges/challenge_audio.dart';
import '../challenges/challenge_engine.dart';
import '../models/tutorial_progress.dart';
import '../widgets/block_ui.dart';
import '../widgets/lottie_fx.dart';
import '../widgets/post_run_tutorial.dart';
import '../widgets/pre_run_view.dart';
import '../widgets/session_views.dart';
import '../widgets/stage_briefing_view.dart';
import '../widgets/warmup_view.dart';

class RunTrackingScreen extends StatefulWidget {
  final VoidCallback? onExit;

  /// Called with `true` once the player leaves the pre-run screen
  /// (warm-up / live tracking / summary) and `false` when back on it.
  /// MainShell uses this to hide the bottom navigation bar mid-run.
  final ValueChanged<bool>? onActiveChanged;

  /// Switches the bottom-nav tab (0 SHOP, 3 RANKS, 4 ACTIVITY). Used by the
  /// post-run tutorial, which walks the player through those tabs.
  final ValueChanged<int>? onNavigate;

  const RunTrackingScreen({
    super.key,
    this.onExit,
    this.onActiveChanged,
    this.onNavigate,
  });

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen>
    with TickerProviderStateMixin {

  // ── State machine ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.preRun;

  /// Warm-up difficulty follows the mode; the real type is detected from GPS.
  ActivityType _userPick = ActivityType.run;

  /// The mode chosen in the Mode Selection overlay (Stage rank or Endless).
  RunMode _mode = kNovice;

  /// Set once when the session is being ended (END SESSION, target reached or
  /// the stage clock ran out) so it can never be saved twice.
  bool _ending = false;
  String? _outcome; // "STAGE CLEARED!" / "TIME UP" / null
  bool _outcomeGood = false;

  // Stage record result of the run that just ended (shown on the summary)
  int _stageStars = 0;
  int _stageBonusGems = 0;
  bool _stageFirstClear = false;
  RunMode? _unlockedRank; // next rank this clear just opened
  RunMode? _pendingNextRank; // set when NEXT RANK is tapped on the summary

  // ── GPS / tracking ─────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;

  Position? _lastPosition;

  double _distanceKm = 0;
  double _currentSpeedKmh = 0;
  double _maxSpeedKmh = 0;

  final List<double> _speedSamples = [];
  final List<Map<String, double>> _routePoints = [];

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _timer;

  int _elapsedSeconds = 0;

  DateTime? _lastMoveAt;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  // ── Saving ─────────────────────────────────────────────────────────────────
  bool _isSaving = false;

  bool? _lastActive;

  // Quests completed during this save
  List<DailyQuest> _newlyCompletedQuests = [];

  // ── Sudden mid-run challenges (Sprint Blitz / Pace Keeper) ────────────────
  final ChallengeEngine _challenge = ChallengeEngine();
  List<ChallengeRecord> _summaryChallenges = [];

  // ── Ghost race (your own best run) ────────────────────────────────────────
  GhostRun? _ghost;          // personal best, loaded for the pre-run screen
  bool _ghostOn = true;      // player's opt-in
  GhostRun? _raceGhost;      // the ghost locked in when this run started
  GhostResult? _summaryGhost;

  Future<void> _loadGhost() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final g = await GhostRun.loadBest(uid);
    if (mounted) setState(() => _ghost = g);
  }

  @override
  void initState() {
    super.initState();
    _loadGhost();

    _challenge.onEvent = (e) => ChallengeAudio.instance.onEvent(e);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: Curves.easeInOut,
      ),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _fadeCtrl.forward();

    // Send any run that was saved on the phone while offline.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) RunOutbox.flush(uid);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();

    _pulseCtrl.dispose();
    _fadeCtrl.dispose();

    _challenge.onEvent = null;
    _challenge.dispose();
    ChallengeAudio.instance.stop();

    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  ActivityType get _detectedType =>
      ActivityTypeExt.fromSpeed(_currentSpeedKmh);

  ActivityType get _effectiveType =>
      _currentSpeedKmh > 0.5
          ? _detectedType
          : _userPick;

  /// True while GPS reported real movement in the last few seconds.
  bool get _isMoving =>
      _lastMoveAt != null &&
      DateTime.now().difference(_lastMoveAt!).inSeconds < 4;

  String get _formattedTime {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }

    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String get _pace {
    if (_distanceKm <= 0 || _elapsedSeconds <= 0) {
      return '--:--';
    }

    final secsPerKm = _elapsedSeconds / _distanceKm;

    final m = secsPerKm ~/ 60;
    final s = (secsPerKm % 60).toInt();

    return "${m}'${s.toString().padLeft(2, '0')}\"";
  }

  double get _avgSpeed {
    if (_speedSamples.isEmpty) {
      return 0;
    }

    return _speedSamples.reduce((a, b) => a + b) /
        _speedSamples.length;
  }

  // ── EXIT ───────────────────────────────────────────────────────────────────

  void _exitRunScreen() {
    _positionSub?.cancel();
    _timer?.cancel();
    ChallengeAudio.instance.stop();

    if (widget.onExit != null) {
      widget.onExit!();
    }
  }

  // ── PRE-RUN → WARM-UP ─────────────────────────────────────────────────────

  /// A mode was chosen in the overlay: remember it and head to the warm-up.
  void _onModePicked(RunMode mode) {
    setState(() {
      _applyMode(mode);
      // Stage ranks get a briefing card first; Endless goes straight on.
      _phase = mode.isStage ? _Phase.briefing : _Phase.warmUp;
    });
  }

  void _applyMode(RunMode mode) {
    _mode = mode;
    // warm-up intensity follows the rank (GPS decides the real type)
    _userPick = mode.id == kNovice.id
        ? ActivityType.walk
        : mode.id == kSlayer.id
            ? ActivityType.run
            : ActivityType.jog;
  }

  /// NEXT RANK on the summary: close it and land on the new rank's briefing.
  Future<void> _onNextRank() async {
    final next = _unlockedRank;
    if (next == null) return;
    _pendingNextRank = next;
    // the player already saw it unlocked: retire the NEW! badge
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'stage_seen': FieldValue.arrayUnion([next.id]),
      }).catchError((_) {});
    }
    await _onSummaryDone();
  }

  void _skipWarmUp() {
    _startTracking();
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  /// Why the last permission check failed: 'service' | 'denied' | 'forever'.
  String? _permIssue;

  // GPS chip: 0 timer-only, 1 searching, 2 weak, 3 good
  int _gpsStatus = 1;
  bool? _lastIntervalFast;

  Future<bool> _requestPermission() async {
    _permIssue = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 6), onTimeout: () => true)) {
        _permIssue = 'service';
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 20),
                onTimeout: () => LocationPermission.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        _permIssue = 'forever';
        return false;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _permIssue = 'denied'; // prompt dismissed (X) or refused
        return false;
      }
      return true;
    } catch (_) {
      _permIssue = 'denied';
      return false;
    }
  }

  /// Location is unavailable. Never leave the player stuck: ask what to do.
  Future<void> _onLocationBlocked() async {
    if (!mounted) return;
    final forever = _permIssue == 'forever';
    final msg = _permIssue == 'service'
        ? 'Location services are turned off on this device.'
        : forever
            ? 'Location permission is blocked. Enable it in your '
                'device / browser settings.'
            : 'Location permission was not granted.';

    Widget btn(String label, Color c, Color e, String result,
            {VoidCallback? onTap}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: PressBlock(
            color: c,
            edge: e,
            depth: 5,
            radius: 12,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onTap: onTap ?? () => Navigator.of(context).pop(result),
            child: SizedBox(
              width: double.infinity,
              child: Center(child: BlockText(label, size: 14, stroke: 3.5)),
            ),
          ),
        );

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Block(
          color: Rb.slate,
          edge: Rb.slateEdge,
          depth: 6,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BlockText('LOCATION NEEDED',
                  size: 18, stroke: 4, align: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '$msg\n\nGPS tracks your distance. You can still run '
                'with the timer only.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD7DADD),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              btn('RUN WITHOUT GPS', Rb.green, Rb.greenEdge, 'nogps'),
              btn('TRY AGAIN', Rb.blue, Rb.blueEdge, 'retry'),
              if (forever)
                btn('OPEN SETTINGS', Rb.gold, Rb.goldEdge, 'settings',
                    onTap: () {
                  Geolocator.openAppSettings(); // no-op on web
                }),
              btn('BACK', const Color(0xFF6B7078), const Color(0xFF1B1D20),
                  'back'),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    switch (choice) {
      case 'nogps':
        setState(() => _gpsStatus = 0); // timer-only: run is already going
        break;
      case 'retry':
        await _attachGps();
        break;
      default:
        _timer?.cancel();
        _positionSub?.cancel();
        setState(() => _phase = _Phase.preRun);
    }
  }

  // ── START TRACKING ─────────────────────────────────────────────────────────

  Future<void> _startTracking({bool useGps = true}) async {
    _positionSub?.cancel();
    _timer?.cancel();

    // Stage ranks fire their own events; Novice and Endless have none.
    _challenge.setup(_mode.challengeConfig);

    setState(() {
      _phase = _Phase.tracking;

      _distanceKm = 0;
      _currentSpeedKmh = 0;
      _maxSpeedKmh = 0;

      _elapsedSeconds = 0;

      _ending = false;
      _outcome = null;
      _outcomeGood = false;
      _stageStars = 0;
      _stageBonusGems = 0;
      _stageFirstClear = false;
      _unlockedRank = null;

      _speedSamples.clear();
      _routePoints.clear();

      _lastPosition = null;
      _lastMoveAt = null;
      _gpsStatus = useGps ? 1 : 0;
      _lastIntervalFast = null;

      _newlyCompletedQuests = [];
      _summaryChallenges = [];
      _raceGhost = _ghostOn ? _ghost : null;
      _summaryGhost = null;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
          _tickChallenge();
          _intervalCue();
          _checkStageLimits();
        }
      },
    );

    if (!useGps) return; // timer-only run
    await _attachGps();
  }

  /// Ask for location AFTER the run is already going, so a slow or dismissed
  /// permission prompt can never freeze the start.
  Future<void> _attachGps() async {
    final granted = await _requestPermission();
    if (!mounted) return;
    if (!granted) {
      await _onLocationBlocked();
      return;
    }
    _positionSub?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position pos) {
        if (!mounted) {
          return;
        }

        final st = pos.accuracy > 35 ? 2 : 3;
        if (st != _gpsStatus) setState(() => _gpsStatus = st);

        final speedKmh =
            (pos.speed * 3.6).clamp(0.0, 60.0);

        if (_lastPosition != null) {
          final delta = Geolocator.distanceBetween(
                _lastPosition!.latitude,
                _lastPosition!.longitude,
                pos.latitude,
                pos.longitude,
              ) /
              1000.0;

          // Ignore GPS noise and impossible jumps.
          if (delta > 0.002 && delta < 0.05) {
            setState(() {
              _distanceKm += delta;
              _lastMoveAt = DateTime.now();

              _currentSpeedKmh = speedKmh;

              if (speedKmh > _maxSpeedKmh) {
                _maxSpeedKmh = speedKmh;
              }

              _speedSamples.add(speedKmh);

              _routePoints.add({
                'lat': pos.latitude,
                'lng': pos.longitude,
              });
            });
            _tickChallenge();
            _checkStageLimits();
          }
        }

        _lastPosition = pos;
      },
      onError: (Object _) {
        if (mounted) _showSnack('GPS signal lost. The timer keeps running.');
      },
    );
  }

  /// Feed the challenge engine: once a second and after each accepted GPS fix.
  void _tickChallenge() {
    if (_phase != _Phase.tracking) return;
    _challenge.update(
      elapsedSeconds: _elapsedSeconds,
      distanceKm: _distanceKm,
      moving: _isMoving,
    );
  }

  // ── STAGE LIMITS / END SESSION ─────────────────────────────────────────────

  /// Seconds left on the stage clock (null in Endless).
  int? get _clockLeftSeconds {
    final total = _mode.clockSeconds;
    if (total == null) return null;
    return math.max(0, total - _elapsedSeconds);
  }

  String? get _clockLeftLabel {
    final left = _clockLeftSeconds;
    if (left == null) return null;
    final m = left ~/ 60;
    final sec = left % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Interval Run: buzz + sound whenever FAST and EASY swap.
  void _intervalCue() {
    if (!_mode.isInterval || _phase != _Phase.tracking) return;
    final ph = RunMode.intervalAt(_elapsedSeconds);
    if (ph == null) return;
    if (_lastIntervalFast != null && _lastIntervalFast != ph.fast) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    _lastIntervalFast = ph.fast;
  }

  /// Stage target reached -> STAGE CLEARED. Clock at zero -> TIME UP.
  void _checkStageLimits() {
    if (_phase != _Phase.tracking || _ending) return;
    if (_mode.isInterval) {
      if (_clockLeftSeconds == 0) {
        _endSession(outcome: 'INTERVALS DONE!', good: true);
      }
      return;
    }
    if (!_mode.isStage) return;
    final target = _mode.targetKm;
    if (target != null && _distanceKm >= target) {
      _endSession(outcome: 'STAGE CLEARED!', good: true);
    } else if (_clockLeftSeconds == 0) {
      _endSession(outcome: 'TIME UP', good: false);
    }
  }

  /// The one way a run ends: END SESSION, target reached or time up.
  /// No confirmation step. It saves the run and opens the summary card.
  Future<void> _endSession({String? outcome, bool good = false}) async {
    if (_ending || _phase != _Phase.tracking) return;
    _ending = true;
    _outcome = outcome ?? (_mode.isStage ? 'ENDED EARLY' : null);
    _outcomeGood = good;
    await _stopAndSave();
  }

  // ── STOP & SAVE ────────────────────────────────────────────────────────────

  Future<void> _stopAndSave() async {
    _positionSub?.cancel();
    _timer?.cancel();
    ChallengeAudio.instance.stop();

    // Sudden-quest rewards. A challenge still running when the player
    // finishes is simply abandoned (not counted).
    final challengeRecords = List<ChallengeRecord>.of(_challenge.records);
    final bonusXp = _challenge.bonusXp;
    final bonusGems = _challenge.bonusGems;
    final lootChests = _challenge.lootChests;
    _summaryChallenges = challengeRecords;

    // Ghost race result (null when not racing or the run was too short).
    final ghostResult =
        GhostResult.judge(_raceGhost, _distanceKm, _elapsedSeconds);
    _summaryGhost = ghostResult;
    final ghostGems = ghostResult?.won == true ? GhostResult.winGems : 0;

    // Determine final activity type by majority vote of speed samples.
    ActivityType finalType = _userPick;

    if (_speedSamples.isNotEmpty) {
      int walkCount = 0;
      int jogCount = 0;
      int runCount = 0;

      for (final speed in _speedSamples) {
        final type =
            ActivityTypeExt.fromSpeed(speed);

        if (type == ActivityType.walk) {
          walkCount++;
        } else if (type == ActivityType.jog) {
          jogCount++;
        } else {
          runCount++;
        }
      }

      if (runCount >= jogCount &&
          runCount >= walkCount) {
        finalType = ActivityType.run;
      } else if (jogCount >= walkCount) {
        finalType = ActivityType.jog;
      } else {
        finalType = ActivityType.walk;
      }
    }

    // Mode multiplier: Novice 1.0x, Vanguard 1.5x, Slayer 2.5x, Endless 0.2x.
    final mult = _mode.rewardMult;

    final xp =
        ((_distanceKm * 100 + _elapsedSeconds / 60 * 5) * mult).round() +
            (bonusXp * mult).round();

    final coins =
        (_distanceKm * 10 * mult).round();

    // Challenge crystals scale with the mode; the ghost prize stays fixed.
    final modeGems = (bonusGems * mult).round();

    final sessionStart =
        DateTime.now().subtract(
      Duration(seconds: _elapsedSeconds),
    );

    final session = ActivitySession(
      id: '',
      type: finalType,
      userPick: finalType,
      startTime: sessionStart,
      endTime: DateTime.now(),
      distanceKm:
          double.parse(
        _distanceKm.toStringAsFixed(3),
      ),
      durationSeconds: _elapsedSeconds,
      avgSpeedKmh:
          double.parse(
        _avgSpeed.toStringAsFixed(2),
      ),
      maxSpeedKmh:
          double.parse(
        _maxSpeedKmh.toStringAsFixed(2),
      ),
      xpEarned: xp,
      coinsEarned: coins,
      routePoints: _routePoints,
    );

    setState(() {
      _phase = _Phase.summary;
      _isSaving = true;
    });

    _savedOffline = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final fields = session.toFirestore()
        ..['startTime'] = session.startTime.millisecondsSinceEpoch
        ..['endTime'] = session.endTime.millisecondsSinceEpoch;
      final payload = RunPayload(
        id: '${session.startTime.millisecondsSinceEpoch}',
        uid: user.uid,
        modeId: _mode.id,
        outcome: _outcome,
        good: _outcomeGood,
        rewardMult: mult,
        fields: fields,
        challenges: challengeRecords.map((r) => r.toMap()).toList(),
        ghost: ghostResult?.toMap(),
        xp: xp,
        coins: coins,
        gems: modeGems + ghostGems,
        lootChests: lootChests,
        elapsedSeconds: _elapsedSeconds,
      );
      try {
        final r = await RunSaver.save(payload).timeout(RunSaver.timeout);
        _newlyCompletedQuests = r.completedQuests;
        _stageStars = r.stars;
        _stageBonusGems = r.bonusGems;
        _stageFirstClear = r.firstClear;
        _unlockedRank = r.unlockedRank;
        // connection is fine: also send any run that was waiting
        RunOutbox.flush(user.uid);
      } catch (e) {
        // Offline or too slow: keep the run on the phone, send it later.
        debugPrint('Run saved to outbox: $e');
        _savedOffline = true;
        await RunOutbox.enqueue(payload);
        if (_mode.isStage && _outcomeGood) {
          _stageStars = _mode.starsFor(_elapsedSeconds);
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }

    _showSummarySheet(session);
  }

  // ── SUMMARY ────────────────────────────────────────────────────────────────

  void _showSummarySheet(
    ActivitySession session,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => SessionSummarySheet(
        session: session,
        isSaving: _isSaving,
        queued: _savedOffline,
        completedQuests:
            _newlyCompletedQuests,
        challenges: _summaryChallenges,
        ghostResult: _summaryGhost,
        mode: _mode,
        outcome: _outcome,
        outcomeGood: _outcomeGood,
        stars: _stageStars,
        stageBonusGems: _stageBonusGems,
        firstClear: _stageFirstClear,
        unlockedRank: _unlockedRank,
        onNextRank: _unlockedRank == null ? null : _onNextRank,
        onDone: _onSummaryDone,
      ),
    );
  }

  bool _tutorialLaunching = false;
  bool _savedOffline = false;


  /// DONE on the Session Summary.
  ///
  /// First-ever run (hasCompletedFirstRunTutorial == false): the sheet is NOT
  /// closed. The Phase 2 tutorial takes over the screen, spotlights the
  /// rewards, and closes the summary itself when the player taps NEXT.
  Future<void> _onSummaryDone() async {
    if (_tutorialLaunching || PostRunTutorial.isActive) return;
    _tutorialLaunching = true;
    try {
      final pending = await TutorialProgress.loadFirstRunPending();
      if (!mounted) return;
      if (pending) {
        PostRunTutorial.show(
          context,
          hooks: PostRunTutorialHooks(
            closeSummary: () async => _closeSummary(),
            navigateTo: (i) => widget.onNavigate?.call(i),
            onFinished: TutorialProgress.markFirstRunDone,
          ),
        );
        return;
      }
      _closeSummary();
    } finally {
      _tutorialLaunching = false;
    }
  }

  /// Dismiss the summary sheet and return to the pre-run screen.
  void _closeSummary() {
    Navigator.of(context).pop();

    // Do NOT Navigator.pop() the RunTrackingScreen.
    // It lives inside MainShell's IndexedStack.
    if (mounted) {
      final next = _pendingNextRank;
      _pendingNextRank = null;
      setState(() {
        if (next != null) {
          _applyMode(next);
          _phase = _Phase.briefing;
        } else {
          _phase = _Phase.preRun;
        }
        _distanceKm = 0;
        _currentSpeedKmh = 0;
        _maxSpeedKmh = 0;
        _elapsedSeconds = 0;
        _ending = false;
        _lastPosition = null;
        _speedSamples.clear();
        _routePoints.clear();
      });
      _challenge.reset();
      _loadGhost(); // a new personal best becomes the next ghost
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Rb.panel,
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Tell the shell whether a run is in progress (anything past pre-run).
    final active = _phase != _Phase.preRun;
    if (active != _lastActive) {
      _lastActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onActiveChanged?.call(active);
      });
    }

    return Scaffold(
      backgroundColor: Rb.bg,
      body: FadeTransition(
        opacity: _fade,
        child: _buildCurrentPhase(),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_phase) {
      case _Phase.preRun:
        return _buildPreRun();

      case _Phase.warmUp:
        return WarmUpView(
          activityType: _userPick,
          onComplete: () => _startTracking(),
          onSkip: _skipWarmUp,
          onBack: () => setState(() =>
              _phase = _mode.isStage ? _Phase.briefing : _Phase.preRun),
        );

      case _Phase.briefing:
        return StageBriefingView(
          mode: _mode,
          onBegin: () => setState(() => _phase = _Phase.warmUp),
          onBack: () => setState(() => _phase = _Phase.preRun),
        );

      case _Phase.tracking:
        return _buildTracking();

      case _Phase.summary:
        // The hero runs on the spot while the run is being saved.
        return const LoadingRunner(label: 'SAVING YOUR RUN...');
    }
  }

  // ── PRE-RUN ────────────────────────────────────────────────────────────────

  Widget _buildPreRun() {
    return PreRunView(
      onBack: _exitRunScreen,
      onStart: _onModePicked,
      ghost: _ghost,
      ghostOn: _ghostOn,
      onGhostToggle: () => setState(() => _ghostOn = !_ghostOn),
    );
  }

  // ── ACTIVE TRACKING ────────────────────────────────────────────────────────

  Widget _buildTracking() {
    final left = _clockLeftSeconds;
    return TrackingView(
      type: _effectiveType,
      time: _formattedTime,
      speedKmh: _currentSpeedKmh,
      moving: _isMoving,
      distanceKm: _distanceKm,
      pace: _pace,
      maxSpeedKmh: _maxSpeedKmh,
      onFinish: () => _endSession(),
      mode: _mode,
      clockLeft: _clockLeftLabel,
      clockLow: left != null && left <= 60,
      // Novice and Endless have no sudden events at all
      challenge: _challenge.enabled ? _challenge : null,
      gpsStatus: _gpsStatus,
      ghost: _raceGhost,
      elapsedSeconds: _elapsedSeconds,
    );
  }
}

enum _Phase {
  preRun,
  briefing,
  warmUp,
  tracking,
  summary,
}
