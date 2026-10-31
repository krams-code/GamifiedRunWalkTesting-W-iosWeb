import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sound.dart';
import 'block_ui.dart';

/// The game's own messages: no plain white snack bars anywhere.
///
///  * [showGameAlert]  a pop-up window for things that went wrong
///                     (save failed, not enough coins, locked...). The
///                     player closes it with OK, so it is never missed.
///  * [showGameToast]  a small game card that drops in at the top and goes
///                     away by itself (copied, saved, friend online, a form
///                     hint...).
///  * [showGameNotice] picks one of the two from the message itself, so old
///                     `_snack('...')` calls need no other change.
enum NoticeKind { error, warning, success, info }

/// Guess the kind of a message from its words.
NoticeKind guessNoticeKind(String m) {
  final t = m.toLowerCase();
  const hardFail = [
    'failed', 'could not', "couldn't", 'not enough', 'locked', 'refused',
    'blocked', 'no internet', 'no connection', 'wrong', 'is taken',
    'every 12 hours', 'already claimed', 'too many', 'not found',
    'still friends', 'need to be logged in',
  ];
  if (hardFail.any(t.contains)) return NoticeKind.error;
  const hint = ['enter ', 'please ', 'pick ', 'fix the', 'lost', 'hidden'];
  if (hint.any(t.contains)) return NoticeKind.warning;
  const good = [
    '✅', '\u{1F389}', 'saved', 'added', 'copied', 'wearing', 'is back',
    'kept', 'sent', 'online', 'evolved',
  ];
  if (good.any(t.contains)) return NoticeKind.success;
  return NoticeKind.info;
}

/// Shows [message] the right way for its kind (see the top of this file).
Future<void> showGameNotice(BuildContext context, String message,
    {NoticeKind? kind, String? title}) {
  final k = kind ?? guessNoticeKind(message);
  if (k == NoticeKind.error) {
    return showGameAlert(context, message: message, title: title);
  }
  showGameToast(context, message, kind: k);
  return Future.value();
}

// ───────────────────────── pop-up window ─────────────────────────

Future<void> showGameAlert(
  BuildContext context, {
  required String message,
  String? title,
  String okLabel = 'OK',
}) {
  if (!context.mounted) return Future.value();
  Sound.I.play(Sfx.error);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x80000000),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Block(
              color: const Color(0xFF7A2A2A),
              edge: const Color(0xFF2E0E0E),
              depth: 7,
              radius: 20,
              gloss: true,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BlockText(title ?? 'OOPS!',
                      size: 22, stroke: 5, color: const Color(0xFFFFD166)),
                  const SizedBox(height: 8),
                  BlockText(message,
                      size: 12.5, stroke: 3, align: TextAlign.center),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: PressBlock(
                      color: Rb.gold,
                      edge: Rb.goldEdge,
                      depth: 5,
                      radius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Center(
                          child: BlockText(okLabel, size: 15, stroke: 3.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

// ───────────────────────── drop-in card ─────────────────────────

OverlayEntry? _toast;
Timer? _toastTimer;

void _hideToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _toast?.remove();
  _toast = null;
}

void showGameToast(BuildContext context, String message,
    {NoticeKind kind = NoticeKind.info}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _hideToast();
  final (Color fill, Color edge, String icon) = switch (kind) {
    NoticeKind.success => (Rb.green, Rb.greenEdge, '⭐'),
    NoticeKind.warning => (const Color(0xFFD98E00), const Color(0xFF6B4300), '\u{1F449}'),
    NoticeKind.error => (Rb.red, Rb.redEdge, '⚠️'),
    NoticeKind.info => (Rb.blue, Rb.blueEdge, '\u{1F4AC}'),
  };
  if (kind == NoticeKind.success) Sound.I.play(Sfx.coin);
  final entry = OverlayEntry(
    builder: (ctx) => _ToastCard(
      message: message,
      fill: fill,
      edge: edge,
      icon: icon,
      onTap: _hideToast,
    ),
  );
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(
    Duration(milliseconds: 2200 + message.length * 25),
    _hideToast,
  );
}

class _ToastCard extends StatelessWidget {
  final String message;
  final Color fill, edge;
  final String icon;
  final VoidCallback onTap;

  const _ToastCard({
    required this.message,
    required this.fill,
    required this.edge,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      left: 14,
      right: 14,
      top: top + 10,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                  offset: Offset(0, (1 - t) * -40), child: child),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: onTap,
                child: Block(
                  color: fill,
                  edge: edge,
                  depth: 5,
                  radius: 14,
                  gloss: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: SizedBox(
                    width: double.infinity,
                    child: BlockText(message,
                        size: 12, stroke: 3, align: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
