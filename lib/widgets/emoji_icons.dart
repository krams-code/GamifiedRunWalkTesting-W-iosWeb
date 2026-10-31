import 'package:flutter/material.dart';

/// Maps emoji (by code point) to the pixel icons in assets/images/icons.
/// Any text drawn through [BlockText] or [EmojiText] gets these swapped
/// in automatically, so screens don't need hand-editing.
const String _d = 'assets/images/icons/icon_';

const Map<int, String> kEmojiIcons = {
  0x1F48E: '${_d}gem.png',
  0x1FA99: '${_d}coin.png',
  0x2B50: '${_d}star.png',
  0x1F31F: '${_d}star.png',
  0x2605: '${_d}star.png',
  0x2606: '${_d}star_empty.png',
  0x1F512: '${_d}lock.png',
  0x1F513: '${_d}unlock.png',
  0x2694: '${_d}swords.png',
  0x1F451: '${_d}crown.png',
  0x1F3C5: '${_d}medal.png',
  0x1F396: '${_d}medal.png',
  0x1F3AF: '${_d}target.png',
  0x1F3C1: '${_d}flag.png',
  0x1F6A9: '${_d}flag.png',
  0x2714: '${_d}check.png',
  0x2705: '${_d}check.png',
  0x2713: '${_d}check.png',
  0x2716: '${_d}cross.png',
  0x274C: '${_d}cross.png',
  0x2715: '${_d}cross.png',
  0x26A0: '${_d}warning.png',
  0x1F4AC: '${_d}chat.png',
  0x1F464: '${_d}profile.png',
  0x1F465: '${_d}friends.png',
  0x1F4CD: '${_d}pin.png',
  0x1F4C5: '${_d}calendar.png',
  0x1F4CA: '${_d}chart.png',
  0x1F4C8: '${_d}chart.png',
  0x1F381: '${_d}gift.png',
  0x1F392: '${_d}backpack.png',
  0x1F455: '${_d}shirt.png',
  0x1F9B9: '${_d}hero_mask.png',
  0x1F4AA: '${_d}dumbbell.png',
  0x2696: '${_d}scale.png',
  0x1F4CF: '${_d}ruler.png',
  0x23F1: '${_d}stopwatch.png',
  0x267E: '${_d}infinity.png',
  0x1F5FA: '${_d}map.png',
  0x1F441: '${_d}eye.png',
  0x2709: '${_d}mail.png',
  0x1F6AA: '${_d}door.png',
  0x1F389: '${_d}party.png',
  0x1F47B: '${_d}ghost.png',
  0x1F480: '${_d}skull.png',
  0x1F50B: '${_d}battery.png',
  0x270F: '${_d}pencil.png',
  0x1F4BE: '${_d}save.png',
  0x1F50D: '${_d}search.png',
  0x1F6D2: '${_d}cart.png',
  0x1F4E6: '${_d}crate.png',
  0x1F3C3: '${_d}run_a.png',
  0x1F6B6: '${_d}walker.png',
  0x1F3A9: '${_d}hat.png',
  0x1F9E2: '${_d}hat.png',
  0x1F576: '${_d}glasses.png',
  0x1F453: '${_d}glasses.png',
  0x1FA73: '${_d}shorts.png',
  0x1F45F: '${_d}sneaker.png',
  0x1F97E: '${_d}sneaker.png',
  0x1F9B8: '${_d}hero.png',
  0x1F9E3: '${_d}scarf.png',
  0x1FABD: '${_d}wings.png',
  0x2728: '${_d}sparkle.png',
  0x2764: '${_d}heart.png',
  0x1F6E1: '${_d}shield.png',
  0x1F525: '${_d}fire.png',
  0x26A1: '${_d}bolt.png',
  0x1F3C6: '${_d}ranks_trophy.png',
  0x1F4A5: '${_d}burst.png',
  0x1F4DC: '${_d}scroll.png',
  0x1F510: '${_d}lock.png',
  0x1F50F: '${_d}lock.png',
  0x1F446: '${_d}hand.png',
  0x261D: '${_d}hand.png',
  0x1F4E1: '${_d}gps.png',
  0x1F9D1: '${_d}whistle.png',
  0x25C0: '${_d}arrow_left.png',
  0x25B6: '${_d}arrow_right.png',
  0x279C: '${_d}arrow_right.png',
  0x23F8: '${_d}pause.png',
  0x1F3D4: '${_d}mountain.png',
  0x1F9B5: '${_d}sneaker.png',
  // added Oct 2026
  0x1F634: '${_d}sleep.png',
  0x1F4A4: '${_d}sleep.png',
  0x1F4F4: '${_d}offline.png',
  0x1F624: '${_d}lost.png',
  0x1F61E: '${_d}lost.png',
  0x1F622: '${_d}lost.png',
  0x1F4A1: '${_d}bulb.png',
  0x2B1C: '${_d}box_empty.png',
  0x1F91D: '${_d}handshake.png',
  0x2642: '${_d}boy.png',
  0x1F466: '${_d}boy.png',
  0x2640: '${_d}girl.png',
  0x1F467: '${_d}girl.png',
  0x1F3AD: '${_d}costume.png',
  0x23F3: '${_d}hourglass.png',
  0x231B: '${_d}hourglass.png',
  0x2699: '${_d}gear.png',
  0x1F3B5: '${_d}music.png',
  0x1F3B6: '${_d}music.png',
  0x1F50A: '${_d}speaker.png',
  0x1F509: '${_d}speaker.png',
  0x1F4F3: '${_d}vibrate.png',
  0x2795: '${_d}plus.png',
  0x2691: '${_d}report.png',
  0x26D4: '${_d}block.png',
  0x1F6AB: '${_d}block.png',
  0x1F511: '${_d}key.png',
  0x1F6D1: '${_d}stop.png',
  0x1F6F0: '${_d}satellite.png',
  0x1F552: '${_d}clock.png',
  0x23F0: '${_d}clock.png',
  0x1F3EB: '${_d}school.png',
  0x1F44B: '${_d}wave.png',
  0x1F44F: '${_d}clap.png',
  0x1F575: '${_d}detective.png',
  // existing pictures for a few more emoji
  0x1F4E7: '${_d}mail.png',
  0x1F4E8: '${_d}mail.png',
  0x1F449: '${_d}hand.png',
  0x1F947: '${_d}medal.png',
  0x1F949: '${_d}medal.png',
};

/// Variation selector / joiner / gender marks that trail an emoji.
bool _isTrailer(int r) =>
    r == 0xFE0F || r == 0x200D || r == 0x2640 || r == 0x2642 || r == 0x1F3EB;

/// Icon path for a single emoji string (e.g. '🏃' or '🏃‍♂️'), or null.
String? emojiIconPath(String emoji) {
  for (final r in emoji.runes) {
    final p = kEmojiIcons[r];
    if (p != null) return p;
  }
  return null;
}

bool containsMappedEmoji(String text) {
  for (final r in text.runes) {
    if (kEmojiIcons.containsKey(r)) return true;
  }
  return false;
}

/// Splits [text] into plain text runs and inline pixel icons.
/// With [placeholder] the icon is replaced by an empty box of the same size
/// (used by the outline layer of BlockText so both layers line up).
List<InlineSpan> emojiSpans(
  String text, {
  required double iconSize,
  TextStyle? style,
  bool placeholder = false,
}) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: style));
    buf.clear();
  }

  final runes = text.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    final path = kEmojiIcons[r];
    if (path == null) {
      buf.writeCharCode(r);
      continue;
    }
    flush();
    while (i + 1 < runes.length && _isTrailer(runes[i + 1])) {
      i++;
    }
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: iconSize * 0.06),
        child: placeholder
            ? SizedBox(width: iconSize, height: iconSize)
            : Image.asset(
                path,
                width: iconSize,
                height: iconSize,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) =>
                    SizedBox(width: iconSize, height: iconSize),
              ),
      ),
    ));
  }
  flush();
  return spans;
}

/// Drop-in for `Text` that shows pixel icons instead of emoji.
class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const EmojiText(this.text,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final size = (merged.fontSize ?? 14) * 1.15;
    return Text.rich(
      TextSpan(
        children: emojiSpans(text, iconSize: size, style: style),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
