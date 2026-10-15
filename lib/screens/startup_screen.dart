import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_icons.dart';
import '../services/run_saver.dart';
import '../state/evolution_state.dart';
import '../state/user_doc.dart';
import '../widgets/block_ui.dart';
import '../widgets/lottie_fx.dart';
import '../widgets/pixel_icon.dart';

/// Shown once after login. Loads the player's profile, hero art, icons and
/// effects IN PARALLEL behind a progress bar, then fades into [child].
///
/// If something is slow it says so (after 6 s) and offers RETRY / CONTINUE
/// ANYWAY (after 12 s), so the player is never stuck on a frozen screen.
class StartupGate extends StatefulWidget {
  final String uid;
  final Widget child;
  const StartupGate({super.key, required this.uid, required this.child});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _Task {
  final String label;
  final double weight;
  final Duration timeout;
  final bool critical; // failing this means the app has no data to show
  final Future<void> Function() run;
  const _Task(this.label, this.weight, this.timeout, this.critical, this.run);
}

class _StartupGateState extends State<StartupGate> {
  double _target = 0.03;
  double _creep = 0.03;
  String _status = 'STARTING...';
  bool _ready = false;
  bool _slow = false;
  bool _stuck = false;
  bool _failed = false;
  int _attempt = 0;
  Timer? _slowT, _stuckT, _creepT;

  @override
  void initState() {
    super.initState();
    // start after the first frame: precacheImage needs a laid-out context
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _slowT?.cancel();
    _stuckT?.cancel();
    _creepT?.cancel();
  }

  Future<void> _precacheAll(List<String> paths) async {
    for (final p in paths) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(p), context);
      } catch (_) {}
    }
  }

  List<_Task> _tasks() => [
        _Task('LOADING YOUR PROFILE...', 4, const Duration(seconds: 12), true,
            () async {
          if (UserDoc.instance.snapshotFor(widget.uid) != null) return;
          await UserDoc.instance.stream.first;
        }),
        _Task('PREPARING YOUR HERO...', 3, const Duration(seconds: 15), false,
            () async {
          EvolutionState.instance.start();
          if (!mounted) return;
          await EvolutionState.instance.precacheBodies(context);
        }),
        _Task('LOADING ICONS...', 2, const Duration(seconds: 15), false, () {
          return _precacheAll([
            ...AppIcons.runFrames,
            AppIcons.coin,
            AppIcons.gem,
            AppIcons.star,
            AppIcons.starEmpty,
            AppIcons.lock,
            AppIcons.shopChest,
            AppIcons.gearShield,
            AppIcons.ranksTrophy,
            AppIcons.activityBurst,
          ]);
        }),
        _Task('LOADING EFFECTS...', 2, const Duration(seconds: 15), false,
            () async {
          await Future.wait([
            for (final f in const [
              Fx.unlockBurst,
              Fx.confetti,
              Fx.levelBurst,
              Fx.coinSpin,
              Fx.gemPop,
              Fx.runLoader,
              Fx.pointingHand,
              Fx.arrowBounce,
            ])
              AssetLottie(f).load().then<void>((_) {}).catchError((_) {}),
          ]);
        }),
        _Task('SYNCING YOUR RUNS...', 1, const Duration(seconds: 6), false,
            () async {
          await RunOutbox.flush(widget.uid);
        }),
      ];

  Future<void> _run() async {
    final attempt = ++_attempt;
    _cancelTimers();
    setState(() {
      _target = 0.03;
      _creep = 0.03;
      _ready = false;
      _slow = false;
      _stuck = false;
      _failed = false;
    });

    _slowT = Timer(const Duration(seconds: 6), () {
      if (mounted && attempt == _attempt && !_ready) {
        setState(() => _slow = true);
      }
    });
    _stuckT = Timer(const Duration(seconds: 12), () {
      if (mounted && attempt == _attempt && !_ready) {
        setState(() => _stuck = true);
      }
    });
    // keeps the bar gently moving while a slow step is still working
    _creepT = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || attempt != _attempt || _ready) return;
      setState(() => _creep += (0.9 - _creep) * 0.04);
    });

    final tasks = _tasks();
    final total = tasks.fold<double>(0, (s, t) => s + t.weight);
    final pending = <String>[for (final t in tasks) t.label];
    var done = 0.0;
    var failed = false;

    await Future.wait([
      for (final t in tasks)
        () async {
          try {
            await t.run().timeout(t.timeout);
          } catch (_) {
            if (t.critical) failed = true;
          }
          if (!mounted || attempt != _attempt) return;
          done += t.weight;
          pending.remove(t.label);
          setState(() {
            _target = 0.03 + done / total * 0.97;
            if (pending.isNotEmpty) _status = pending.first;
          });
        }(),
    ]);

    if (!mounted || attempt != _attempt) return;
    _cancelTimers();
    if (failed) {
      // no profile data yet: let the player choose instead of hanging
      setState(() {
        _failed = true;
        _stuck = true;
        _slow = true;
        _status = 'COULD NOT REACH THE SERVER';
      });
      return;
    }
    setState(() {
      _target = 1.0;
      _status = 'READY!';
    });
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (mounted && attempt == _attempt) setState(() => _ready = true);
  }

  void _continueAnyway() {
    _attempt++; // cancels the running load
    _cancelTimers();
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _ready
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : StartupView(
              key: const ValueKey('loading'),
              progress: _target > _creep ? _target : _creep,
              status: _status,
              slow: _slow,
              stuck: _stuck,
              failed: _failed,
              onRetry: _run,
              onContinue: _continueAnyway,
            ),
    );
  }
}

/// The loading picture: title, runner riding the progress bar, a scrolling
/// strip of game icons, a status line and (when slow) the help message.
class StartupView extends StatefulWidget {
  final double progress; // 0..1
  final String status;
  final bool slow;
  final bool stuck;
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  const StartupView({
    super.key,
    required this.progress,
    this.status = 'LOADING...',
    this.slow = false,
    this.stuck = false,
    this.failed = false,
    this.onRetry,
    this.onContinue,
  });

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  static const _tips = [
    'TIP: Clear NOVICE RANK to unlock more modes.',
    'TIP: Hold END SESSION to finish a run.',
    'TIP: Finish a stage faster for up to 3 stars.',
    'TIP: INTERVAL RUN alternates FAST and EASY.',
    'TIP: No signal? Your run is saved and sent later.',
  ];
  int _tip = 0;
  Timer? _tipT;

  @override
  void initState() {
    super.initState();
    _tipT = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _tipT?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  static const _strip = [
    AppIcons.coin,
    AppIcons.gem,
    AppIcons.star,
    AppIcons.sneaker,
    AppIcons.medal,
    AppIcons.flag,
    AppIcons.shopChest,
    AppIcons.crown,
  ];

  Widget _scrollingStrip() {
    const size = 30.0, gap = 22.0, span = size + gap;
    final count = _strip.length;
    return SizedBox(
      height: size,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _scroll,
          builder: (_, __) {
            final dx = -_scroll.value * span * count;
            return OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 4 copies cover any phone / browser width
                    for (var r = 0; r < 4; r++)
                      for (final p in _strip)
                        Padding(
                          padding: const EdgeInsets.only(right: gap),
                          child: PixelIcon(p, size: size),
                        ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bar(double p) {
    const h = 24.0, runner = 44.0;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: runner + h - 6,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // track + fill
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  color: Rb.track,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Rb.panelEdge, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: p.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Rb.green, Rb.neon]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // the runner rides the head of the bar
            TweenAnimationBuilder<double>(
              tween: Tween(end: p.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, v, __) => Positioned(
                left: (w - runner) * v,
                bottom: h - 8,
                child: const PixelIconAnim(AppIcons.runFrames,
                    size: runner, intervalMs: 170),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).clamp(0, 100).round();
    return Scaffold(
      backgroundColor: Rb.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: BlockText('HAKBANGHERO', size: 34, stroke: 7),
                  ),
                  const SizedBox(height: 4),
                  const BlockText('RUN. WALK. LEVEL UP.',
                      size: 11,
                      stroke: 3,
                      align: TextAlign.center,
                      color: Rb.neon),
                  const SizedBox(height: 28),
                  _bar(widget.progress),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BlockText(widget.status,
                            size: 11, stroke: 3, align: TextAlign.left),
                      ),
                      BlockText('$pct%', size: 13, stroke: 3.5),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _scrollingStrip(),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: BlockText(_tips[_tip],
                        key: ValueKey(_tip),
                        size: 11,
                        stroke: 3,
                        align: TextAlign.center,
                        color: const Color(0xFFD7DADD)),
                  ),
                  if (widget.slow) ...[
                    const SizedBox(height: 22),
                    Block(
                      color: Rb.slate,
                      edge: Rb.slateEdge,
                      depth: 5,
                      radius: 12,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          BlockText(
                              widget.failed
                                  ? 'NO CONNECTION'
                                  : 'TAKING LONGER THAN USUAL...',
                              size: 13,
                              stroke: 3.5,
                              align: TextAlign.center,
                              color: Rb.gold),
                          const SizedBox(height: 6),
                          const Text(
                            'Your connection may be slow. We keep trying. '
                            'You can also continue and the app will use the '
                            'data saved on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFD7DADD),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          if (widget.stuck) ...[
                            const SizedBox(height: 10),
                            _btn('RETRY', Rb.blue, Rb.blueEdge, widget.onRetry),
                            const SizedBox(height: 8),
                            _btn('CONTINUE ANYWAY', Rb.green, Rb.greenEdge,
                                widget.onContinue),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, Color c, Color e, VoidCallback? onTap) =>
      PressBlock(
        color: c,
        edge: e,
        depth: 5,
        radius: 12,
        padding: const EdgeInsets.symmetric(vertical: 12),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Center(child: BlockText(label, size: 14, stroke: 3.5)),
        ),
      );
}
