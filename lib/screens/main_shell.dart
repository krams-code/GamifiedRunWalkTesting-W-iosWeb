import '../services/sound.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'activity/activity_screen.dart';
import 'leaderboard/leaderboard_screen.dart';
import 'profile/profile_screen.dart';

import 'package:hakbanghero/screens/character/equipment_screen.dart';
import 'package:hakbanghero/screens/shop/avatar_shop_screen.dart';
import 'package:hakbanghero/run/run_tracking_screen.dart';

import '../models/hero_roster.dart';
import '../state/evolution_state.dart';
import 'character/hero_picker_screen.dart';
import '../widgets/block_navbar.dart';
import '../widgets/block_ui.dart';
import '../widgets/global_top_bar.dart';
import '../widgets/onboarding_tutorial.dart';
import '../widgets/tutorial_keys.dart';
import '../utils/perf_probe.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 = SHOP, 1 = GEAR, 2 = RUN, 3 = RANKS, 4 = ACTIVITY, 5 = PROFILE
  int _currentIndex = 2;

  /// True from warm-up until the session summary is dismissed.
  /// While true the bottom nav bar is removed so a stray tap can't
  /// interrupt tracking.
  bool _isTrackingActive = false;

  bool _bodiesPrecached = false;

  // ── Speed ───────────────────────────────────────────────────────────
  // Tabs are built the first time you open them (not all six at launch),
  // then kept alive. Each screen object is created ONCE, so switching tabs
  // doesn't rebuild every screen and reconnect their Firestore listeners.
  static const _tabNames = ['SHOP', 'GEAR', 'RUN', 'RANKS', 'ACTIVITY', 'PROFILE'];
  final Set<int> _visited = {2};
  final List<Widget?> _cache = List<Widget?>.filled(6, null);
  late final Widget _topBar = GlobalTopBar(onOpenProfile: () => _navigateTo(5));

  @override
  void initState() {
    super.initState();
    // App-wide body-form state (follows sign-in/out by itself).
    EvolutionState.instance.start();
    Sound.I.music(Bgm.menu);
    PerfProbe.start(); // frame / jank meter (debug + profile builds only)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeChooseHero();
      await _maybeStartTutorial();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bodiesPrecached) {
      _bodiesPrecached = true;
      // Decode all four body sprites now, so an evolution swap is a
      // synchronous ImageCache hit (zero asset-loading lag).
      EvolutionState.instance.precacheBodies(context);
    }
  }

  void _navigateTo(int index) {
    if (_isTrackingActive) return; // belt and braces
    if (index == _currentIndex) return;
    Sound.I.play(Sfx.tab);
    PerfProbe.markNav(_tabNames[index]);
    setState(() {
      _visited.add(index);
      _currentIndex = index;
    });
  }

  void _onTrackingChanged(bool active) {
    if (_isTrackingActive == active) return;
    if (!active) Sound.I.music(Bgm.menu); // run is over: back to menu music
    setState(() {
      _isTrackingActive = active;
      if (active) _currentIndex = 2;
    });
  }

  // First launch with heroes: accounts that never picked one choose now.
  Future<void> _maybeChooseHero() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null || hasChosenHero(data)) return;
      if (data['character_created'] == false) return; // creation screen picks
      if (!mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const HeroPickerScreen(firstTime: true),
      ));
    } catch (_) {
      // never block the app on the picker
    }
  }

  // ── Onboarding ────────────────────────────────────────────────────────
  // CharacterCreationScreen writes `tutorial_done: false` for brand-new
  // players. Existing accounts have no such field, so they never see it.
  Future<void> _maybeStartTutorial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await ref.get();
      if (snap.data()?['tutorial_done'] != false) return;
      if (!mounted) return;

      setState(() => _currentIndex = 2); // hero, milestone bar, RUN button
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      OnboardingTutorial.show(
        context,
        onFinished: () {
          ref.update({'tutorial_done': true}).catchError((_) {});
          // brand-new hero: now they must pick their first mode (NOVICE)
          TutorialKeys.requestFirstMode();
        },
      );
    } catch (_) {
      // never block the app on the tutorial
    }
  }

  Widget _build(int i) {
    switch (i) {
      case 0:
        return const AvatarShopScreen();
      case 1:
        return const EquipmentScreen();
      case 2:
        return RunTrackingScreen(
          onExit: () => _navigateTo(0),
          onActiveChanged: _onTrackingChanged,
          onNavigate: _navigateTo, // post-run tutorial drives the tabs
        );
      case 3:
        return const LeaderboardScreen();
      case 4:
        return const ActivityScreen();
      default:
        return ProfileScreen(onBackTap: () => _navigateTo(2));
    }
  }

  /// A visited tab: same widget object every time, repainted on its own
  /// layer, and its animations are paused while it's hidden.
  Widget _tab(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    return TickerMode(
      enabled: i == _currentIndex,
      child: RepaintBoundary(child: _cache[i] ??= _build(i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Rb.bg,
      body: Column(
        children: [
          // Global header: profile block + username + logout tray.
          // Hidden mid-run so nothing can interrupt tracking.
          if (!_isTrackingActive)
            _topBar,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              // the top bar already covers the status-bar inset
              removeTop: !_isTrackingActive,
              child: Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: [for (var i = 0; i < 6; i++) _tab(i)],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
      // Removed entirely during an active run.
      // Slides open when the run ends (and closes when a run starts).
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _isTrackingActive
            ? const SizedBox(width: double.infinity)
            : BlockNavBar(
                currentIndex: _currentIndex == 5 ? -1 : _currentIndex,
                onTap: _navigateTo,
              ),
      ),
    );
  }
}
