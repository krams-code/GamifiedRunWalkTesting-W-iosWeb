import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'block_ui.dart';
import '../services/sound.dart';

/// Lottie effect files (assets/animations/lottie/). Drawn in code to match the
/// block / jelly art style: see ICON_MAP / the generator notes if you want
/// to change one.
abstract final class Fx {
  static const _d = 'assets/animations/lottie';

  /// One-shot rays + rings + sparkles. A rank / mode was just unlocked.
  static const unlockBurst = '$_d/unlock_burst.json';

  /// One-shot confetti + gold stars raining down the whole screen.
  static const confetti = '$_d/confetti.json';

  /// Loop: slow-turning sunburst. Sits BEHIND a level number.
  static const levelBurst = '$_d/level_burst.json';

  /// Loop: spinning coin.
  static const coinSpin = '$_d/coin_spin.json';

  /// One-shot: a coin pops in with sparkles.
  static const gemPop = '$_d/gem_pop.json';

  /// Loop: a little hero running on the spot (loading / empty states).
  static const runLoader = '$_d/run_loader.json';

  /// Loop: finger taps, ripple at the fingertip. Tutorial pointer.
  static const pointingHand = '$_d/pointing_hand.json';

  /// Loop: arrow bouncing downward. Tutorial pointer.
  static const arrowBounce = '$_d/arrow_bounce.json';
}

Widget _fxError(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();

/// Plays an effect once, then (optionally) calls [onDone]. Stays on its last
/// frame afterwards, so one-shots like [Fx.gemPop] keep the finished gem
/// showing. Never intercepts touches.
class FxOnce extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onDone;

  /// Wait this long before starting (handy to stagger several effects).
  final Duration delay;

  const FxOnce(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.onDone,
    this.delay = Duration.zero,
  });

  @override
  State<FxOnce> createState() => _FxOnceState();
}

class _FxOnceState extends State<FxOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _start(LottieComposition comp) {
    _c.duration = comp.duration;
    _t?.cancel();
    if (widget.delay == Duration.zero) {
      if (mounted) _c.forward(from: 0);
    } else {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward(from: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Lottie.asset(
          widget.path,
          controller: _c,
          onLoaded: _start,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          frameRate: FrameRate.composition,
          errorBuilder: _fxError,
        ),
      );
}

/// Loops an effect forever. Pauses by itself while its tab is hidden.
class FxLoop extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const FxLoop(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Lottie.asset(
          path,
          repeat: true,
          animate: true,
          width: width,
          height: height,
          fit: fit,
          frameRate: FrameRate.composition,
          errorBuilder: _fxError,
        ),
      );
}

/// Draws [path] BEHIND [child], bigger than it by [bleed] on every side.
/// Doesn't change the size of [child].
class FxBehind extends StatelessWidget {
  final String path;
  final double bleed;
  final Widget child;
  const FxBehind({super.key, required this.path, required this.child, this.bleed = 20});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -bleed,
            right: -bleed,
            top: -bleed,
            bottom: -bleed,
            child: IgnorePointer(child: FxLoop(path)),
          ),
          child,
        ],
      );
}

/// Shows the level-up sunburst behind [child] for a few seconds whenever
/// [level] goes UP while this widget is on screen (not on first build).
class LevelUpBurst extends StatefulWidget {
  final int level;
  final double bleed;
  final Widget child;
  const LevelUpBurst({super.key, required this.level, required this.child, this.bleed = 26});

  @override
  State<LevelUpBurst> createState() => _LevelUpBurstState();
}

class _LevelUpBurstState extends State<LevelUpBurst> {
  bool _on = false;
  Timer? _t;

  @override
  void didUpdateWidget(LevelUpBurst old) {
    super.didUpdateWidget(old);
    if (widget.level > old.level && old.level > 0) {
      Sound.I.play(Sfx.levelUp);
      _t?.cancel();
      setState(() => _on = true);
      _t = Timer(const Duration(milliseconds: 3600), () {
        if (mounted) setState(() => _on = false);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _on ? FxBehind(path: Fx.levelBurst, bleed: widget.bleed, child: widget.child) : widget.child;
}

/// Little running hero + optional label. Use instead of a spinner.
class LoadingRunner extends StatelessWidget {
  final double size;
  final String? label;
  const LoadingRunner({super.key, this.size = 96, this.label = 'LOADING...'});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: size, height: size, child: const FxLoop(Fx.runLoader)),
            if (label != null) BlockText(label!, size: 12, stroke: 3),
          ],
        ),
      );
}
