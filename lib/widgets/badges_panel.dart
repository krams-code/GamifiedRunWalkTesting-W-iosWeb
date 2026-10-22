import 'package:flutter/material.dart';

import '../models/badge_definitions.dart';
import 'block_ui.dart';
import 'unlock_sheet.dart' show showInfoSheet;

/// Number of unlocked badges.
int unlockedBadgeCount(BadgeStats stats) =>
    kBadges.where((b) => b.unlocked(stats)).length;

/// Unlocked first, then the ones closest to unlocking.
List<AppBadge> _ordered(BadgeStats stats) => [...kBadges]..sort((a, b) {
    final au = a.unlocked(stats), bu = b.unlocked(stats);
    if (au != bu) return au ? -1 : 1;
    return b.progress(stats).compareTo(a.progress(stats));
  });

// ───────────────────────── the badge picture ─────────────────────────

/// Pixel-art badge tile. Locked badges are greyed out with a small lock.
class BadgeMedal extends StatelessWidget {
  final AppBadge badge;
  final bool unlocked;
  final double size;
  const BadgeMedal({
    super.key,
    required this.badge,
    required this.unlocked,
    this.size = 84,
  });

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      badge.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Center(
        child: Text(badge.emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          unlocked
              ? img
              : Opacity(
                  opacity: 0.45,
                  child: ColorFiltered(colorFilter: _grey, child: img),
                ),
          if (!unlocked)
            Text('🔒', style: TextStyle(fontSize: size * 0.30)),
        ],
      ),
    );
  }
}

// ───────────────────────── profile card + modal ─────────────────────────

/// Compact card for the profile: count, progress and a few medals.
/// Tapping it (or VIEW ALL) opens the full badge collection in a modal.
class BadgesPreviewCard extends StatelessWidget {
  final BadgeStats stats;
  const BadgesPreviewCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final done = unlockedBadgeCount(stats);
    final total = kBadges.length;
    final shown = _ordered(stats).take(4).toList();

    return PressBlock(
      color: Rb.panel,
      edge: Rb.panelEdge,
      depth: 6,
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: () => showBadgesSheet(context, stats),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BlockText('🎖️ BADGES', size: 15, stroke: 4),
              const Spacer(),
              BlockText('$done / $total', size: 12, stroke: 3, color: Rb.gold),
            ],
          ),
          const SizedBox(height: 8),
          BlockBar(value: total == 0 ? 0 : done / total, height: 14),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final b in shown)
                BadgeMedal(badge: b, unlocked: b.unlocked(stats), size: 62),
            ],
          ),
          const SizedBox(height: 10),
          const Center(
            child: BlockText('TAP TO VIEW ALL ▸',
                size: 10, stroke: 2.5, color: Color(0xFFB8BDC4)),
          ),
        ],
      ),
    );
  }
}

/// Full collection: 3 medals per row, title underneath.
Future<void> showBadgesSheet(BuildContext context, BadgeStats stats) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => _BadgesSheet(stats: stats, controller: scroll),
    ),
  );
}

class _BadgesSheet extends StatelessWidget {
  final BadgeStats stats;
  final ScrollController controller;
  const _BadgesSheet({required this.stats, required this.controller});

  @override
  Widget build(BuildContext context) {
    final done = unlockedBadgeCount(stats);
    final total = kBadges.length;
    final list = _ordered(stats);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Block(
        color: Rb.bg,
        edge: Colors.black,
        depth: 8,
        radius: 22,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: BlockText('🎖️ MY BADGES', size: 18, stroke: 4.5),
                  ),
                  BlockText('$done / $total',
                      size: 13, stroke: 3, color: Rb.gold),
                  const SizedBox(width: 10),
                  PressBlock(
                    color: Rb.red,
                    edge: Rb.redEdge,
                    depth: 4,
                    radius: 10,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    onTap: () => Navigator.of(context).pop(),
                    child: const BlockText('✕', size: 14, stroke: 3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: BlockBar(value: total == 0 ? 0 : done / total, height: 14),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final b = list[i];
                  final on = b.unlocked(stats);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showInfoSheet(
                      ctx,
                      title: b.title,
                      message: on
                          ? '${b.description}\n\nUnlocked! Nice work.'
                          : '${b.description}\n\nProgress: ${b.progressText(stats)}',
                      art: Center(
                        child: BadgeMedal(badge: b, unlocked: on, size: 110),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: FittedBox(
                            child: BadgeMedal(badge: b, unlocked: on, size: 100),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BlockText(
                            b.title,
                            size: 11,
                            stroke: 3,
                            color: on ? Colors.white : const Color(0xFFB8BDC4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BlockText(
                            on ? '✓ UNLOCKED' : b.progressText(stats),
                            size: 8,
                            stroke: 2,
                            color: on ? Rb.gold : const Color(0xFF9AA0A8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
