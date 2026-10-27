import 'package:flutter/material.dart';

import '../services/sound.dart';
import 'block_ui.dart';
import 'lottie_fx.dart';

/// The small "you got something!" card used for every reward in the game
/// (streaks, weekly goal, level ups, new items / heroes, coin bonuses...).
///
///   showRewardPopup(context, title: '+250 COINS', subtitle: '3-day streak!');
///
/// It pops in with a bounce, a coin / burst animation and a sound, and goes
/// away when the player taps anywhere (or by itself after [autoClose]).
Future<void> showRewardPopup(
  BuildContext context, {
  required String title,
  String? subtitle,
  String emoji = '\u{1FA99}',
  Color color = const Color(0xFF1E6B45),
  Color edge = const Color(0xFF0B2E1D),
  String fx = Fx.coinSpin,
  Sfx sound = Sfx.gem,
  Duration? autoClose = const Duration(seconds: 4),
}) {
  if (!context.mounted) return Future.value();
  Sound.I.play(sound);
  var open = true;
  final nav = Navigator.of(context, rootNavigator: true);
  if (autoClose != null) {
    Future<void>.delayed(autoClose, () {
      if (open && nav.mounted && nav.canPop()) nav.pop();
    });
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) => _RewardCard(
      title: title,
      subtitle: subtitle,
      emoji: emoji,
      color: color,
      edge: edge,
      fx: fx,
    ),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
    ),
  ).whenComplete(() => open = false);
}

class _RewardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String emoji;
  final Color color;
  final Color edge;
  final String fx;

  const _RewardCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.edge,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    // tap ANYWHERE (card included) closes it
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // confetti behind the card
                  const Positioned(
                    left: -40,
                    right: -40,
                    top: -70,
                    bottom: -70,
                    child: IgnorePointer(
                        child: FxOnce(Fx.confetti, fit: BoxFit.cover)),
                  ),
                  Block(
                    color: color,
                    edge: edge,
                    depth: 7,
                    radius: 20,
                    gloss: true,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(child: FxOnce(fx)),
                              Text(emoji, style: const TextStyle(fontSize: 38)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BlockText(title,
                              size: 24, stroke: 5, color: Rb.gold),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          BlockText(subtitle!,
                              size: 12, stroke: 3, align: TextAlign.center),
                        ],
                        const SizedBox(height: 10),
                        const BlockText('TAP ANYWHERE TO CONTINUE',
                            size: 9,
                            stroke: 2.5,
                            color: Color(0xFFD3D5D7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
