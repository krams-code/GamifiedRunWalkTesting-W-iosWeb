import 'dart:async';

import 'package:flutter/material.dart';

/// Hero scenery that follows the real clock: a sunny meadow by day and a
/// moonlit one from 6 PM to 6 AM. Used behind the hero on the Start Session,
/// Gear and Profile screens so they all look the same.
class SceneBackdrop extends StatefulWidget {
  const SceneBackdrop({super.key});

  /// Night is 18:00 - 05:59.
  static bool isNight([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    return h >= 18 || h < 6;
  }

  /// Fraction of the picture height taken by the grass strip at the bottom.
  /// Leave about this much room under the hero's feet so it stands on grass.
  static const double grassFraction = 0.12;

  static const String dayAsset = 'assets/images/backgrounds/home_meadow.jpg';
  static const String nightAsset = 'assets/images/backgrounds/home_night.jpg';

  @override
  State<SceneBackdrop> createState() => _SceneBackdropState();
}

class _SceneBackdropState extends State<SceneBackdrop> {
  Timer? _timer;
  bool _night = SceneBackdrop.isNight();

  @override
  void initState() {
    super.initState();
    // check once a minute so it flips by itself at 6 PM / 6 AM
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final n = SceneBackdrop.isNight();
      if (mounted && n != _night) setState(() => _night = n);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _night ? const Color(0xFF241A5E) : const Color(0xFF8FD0FF);
    return Positioned.fill(
      child: ColoredBox(
        color: fallback,
        child: Image.asset(
          _night ? SceneBackdrop.nightAsset : SceneBackdrop.dayAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0.3, 1),
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
