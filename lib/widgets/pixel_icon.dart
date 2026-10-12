import 'dart:async';

import 'package:flutter/material.dart';

/// A crisp pixel-art icon from a local asset path.
///
///   PixelIcon('assets/images/icons/icon_run_fire.png')   // 24 x 24
///
/// Always `FilterQuality.none` so the pixels stay sharp.
class PixelIcon extends StatelessWidget {
  final String path;
  final double size;
  const PixelIcon(this.path, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => Image.asset(
        path,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
}

/// Icon + label on one line (used for tabs / badges / headers).
class IconLabel extends StatelessWidget {
  final String iconPath;
  final Widget label;
  final double iconSize;
  final double gap;
  const IconLabel({
    super.key,
    required this.iconPath,
    required this.label,
    this.iconSize = 20,
    this.gap = 6,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(iconPath, size: iconSize),
          SizedBox(width: gap),
          label,
        ],
      );
}

/// A 2-frame (or more) pixel animation: flips between [frames] every
/// [intervalMs]. Example: `PixelIconAnim(AppIcons.runnerFrames, size: 28)`.
class PixelIconAnim extends StatefulWidget {
  final List<String> frames;
  final double size;
  final int intervalMs;
  const PixelIconAnim(this.frames,
      {super.key, this.size = 24, this.intervalMs = 220});

  @override
  State<PixelIconAnim> createState() => _PixelIconAnimState();
}

class _PixelIconAnimState extends State<PixelIconAnim> {
  Timer? _t;
  int _i = 0;
  bool _visible = true; // false while its tab is hidden (TickerMode off)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    for (final f in widget.frames) {
      precacheImage(AssetImage(f), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(milliseconds: widget.intervalMs), (_) {
      if (mounted && _visible && widget.frames.isNotEmpty) {
        setState(() => _i = (_i + 1) % widget.frames.length);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) return SizedBox(width: widget.size, height: widget.size);
    return PixelIcon(widget.frames[_i % widget.frames.length], size: widget.size);
  }
}
