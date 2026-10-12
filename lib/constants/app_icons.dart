/// Local pixel-art icon assets (replace system emojis).
/// Draw them with `PixelIcon(AppIcons.runFire)` (widgets/pixel_icon.dart).
class AppIcons {
  const AppIcons._();

  static const String _d = 'assets/images/icons';

  // activity tiers
  static const String walkShoe = '$_d/icon_shoe.png';
  static const String jogBolt = '$_d/icon_bolt.png';
  static const String runFire = '$_d/icon_fire.png';

  // nav / panels
  static const String shopChest = '$_d/icon_shop_chest.png';
  static const String gearShield = '$_d/icon_shield.png';
  static const String ranksTrophy = '$_d/icon_ranks_trophy.png';
  static const String activityBurst = '$_d/icon_burst.png';

  // ── new pixel pack (replaces the emoji placeholders) ──
  static const String backpack = '$_d/icon_backpack.png';
  static const String battery = '$_d/icon_battery.png';
  static const String calendar = '$_d/icon_calendar.png';
  static const String cape = '$_d/icon_cape.png';
  static const String cart = '$_d/icon_cart.png';
  static const String chart = '$_d/icon_chart.png';
  static const String chat = '$_d/icon_chat.png';
  static const String check = '$_d/icon_check.png';
  static const String coin = '$_d/icon_coin.png';
  static const String crate = '$_d/icon_crate.png';
  static const String cross = '$_d/icon_cross.png';
  static const String crown = '$_d/icon_crown.png';
  static const String door = '$_d/icon_door.png';
  static const String dumbbell = '$_d/icon_dumbbell.png';
  static const String eye = '$_d/icon_eye.png';
  static const String flag = '$_d/icon_flag.png';
  static const String friends = '$_d/icon_friends.png';
  static const String gem = '$_d/icon_gem.png';
  static const String ghost = '$_d/icon_ghost.png';
  static const String gift = '$_d/icon_gift.png';
  static const String glasses = '$_d/icon_glasses.png';
  static const String hat = '$_d/icon_hat.png';
  static const String heart = '$_d/icon_heart.png';
  static const String hero = '$_d/icon_hero.png';
  static const String heroMask = '$_d/icon_hero_mask.png';
  static const String infinity = '$_d/icon_infinity.png';
  static const String lock = '$_d/icon_lock.png';
  static const String mail = '$_d/icon_mail.png';
  static const String map = '$_d/icon_map.png';
  static const String medal = '$_d/icon_medal.png';
  static const String party = '$_d/icon_party.png';
  static const String pencil = '$_d/icon_pencil.png';
  static const String pin = '$_d/icon_pin.png';
  static const String profile = '$_d/icon_profile.png';
  static const String ruler = '$_d/icon_ruler.png';
  static const String runner = '$_d/icon_runner.png';
  static const String save = '$_d/icon_save.png';
  static const String scale = '$_d/icon_scale.png';
  static const String scarf = '$_d/icon_scarf.png';
  static const String search = '$_d/icon_search.png';
  static const String shirt = '$_d/icon_shirt.png';
  static const String shorts = '$_d/icon_shorts.png';
  static const String skull = '$_d/icon_skull.png';
  static const String sneaker = '$_d/icon_sneaker.png';
  static const String sparkle = '$_d/icon_sparkle.png';
  static const String star = '$_d/icon_star.png';
  static const String starEmpty = '$_d/icon_star_empty.png';
  static const String stopwatch = '$_d/icon_stopwatch.png';
  static const String swords = '$_d/icon_swords.png';
  static const String target = '$_d/icon_target.png';
  static const String unlock = '$_d/icon_unlock.png';
  static const String walker = '$_d/icon_walker.png';
  static const String warning = '$_d/icon_warning.png';
  static const String wings = '$_d/icon_wings.png';

  static const String scroll = '$_d/icon_scroll.png';
  static const String hand = '$_d/icon_hand.png';
  static const String gps = '$_d/icon_gps.png';
  static const String whistle = '$_d/icon_whistle.png';
  static const String arrowLeft = '$_d/icon_arrow_left.png';
  static const String arrowRight = '$_d/icon_arrow_right.png';
  static const String play = '$_d/icon_play.png';
  static const String pause = '$_d/icon_pause.png';
  static const String mountain = '$_d/icon_mountain.png';

  // The big RUN-button runner (2 frames)
  static const List<String> runFrames = [
    '$_d/icon_run_a.png',
    '$_d/icon_run_b.png',
  ];

  // 2-frame animations: show them with PixelIconAnim (widgets/pixel_icon.dart)
  static const List<String> runnerFrames = [
    '$_d/icon_runner_a.png',
    '$_d/icon_runner_b.png',
  ];
  static const List<String> walkerFrames = [
    '$_d/icon_walker_a.png',
    '$_d/icon_walker_b.png',
  ];

  /// Icon of a hero item id (see models/hero_items.dart).
  static String item(String id) => '$_d/items/item_$id.png';
}
