import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// A map picture that scrolls right-to-left forever.
///
/// The pictures are not tileable, so every second tile is mirrored: the edges
/// of neighbouring tiles always match and the loop has no visible seam.
class MapBackdrop extends StatelessWidget {
  final String asset;
  final ValueListenable<double> scroll; // px travelled
  final double factor;

  /// width / height of the picture (all map art is 16:9).
  final double aspect;

  const MapBackdrop({
    super.key,
    required this.asset,
    required this.scroll,
    this.factor = 1.0,
    this.aspect = 1.7917,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      final tileW = h * aspect;
      return RepaintBoundary(
        child: ClipRect(
          child: ValueListenableBuilder<double>(
            valueListenable: scroll,
            builder: (_, s, __) {
              final off = (s * factor) % (tileW * 2);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: i * tileW - off,
                      top: 0,
                      width: tileW + 1, // +1 hides hairline gaps
                      height: h,
                      child: Transform.flip(
                        flipX: i.isOdd,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}
