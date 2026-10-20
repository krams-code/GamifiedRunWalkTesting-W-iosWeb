import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short sound effects. File names live in assets/audio/sfx/.
enum Sfx {
  click('click'),
  back('back'),
  tab('tab'),
  open('open'),
  error('error'),
  coin('coin'),
  gem('gem'),
  star('star'),
  buy('buy'),
  unlock('unlock'),
  levelUp('level_up'),
  success('success'),
  fail('fail'),
  beep('beep'),
  go('go'),
  fast('fast'),
  easy('easy'),
  next('next');

  final String file;
  const Sfx(this.file);
}

/// Looping background tracks. Files live in assets/audio/music/.
enum Bgm {
  menu('menu', 0.75),
  run('run', 1.0),
  sprint('sprint', 0.75);

  final String file;

  /// Loudness trim so different tracks sit at the same level.
  final double gain;
  const Bgm(this.file, this.gain);
}

/// One place for every sound in the game. Every call is safe: if audio is
/// unavailable (browser blocks it, no sound device, missing file) it just stays
/// silent instead of crashing.
///
/// Own sounds: replace a file in assets/audio/sfx or assets/audio/music with
/// one of the same name (or change the names in the enums above).
class Sound with WidgetsBindingObserver {
  Sound._();
  static final Sound I = Sound._();

  static const _kSfx = 'sound_sfx_on';
  static const _kMusic = 'sound_music_on';
  static const _kSfxVol = 'sound_sfx_vol';
  static const _kMusicVol = 'sound_music_vol';
  static const _kVibe = 'vibrate_on';
  static const double _musicBase = 0.45; // volume of the music at slider 100%
  static const int _poolSize = 4;

  /// Toggles other widgets can listen to (SOUND / MUSIC switches).
  final ValueNotifier<bool> sfxOn = ValueNotifier<bool>(true);
  final ValueNotifier<bool> musicOn = ValueNotifier<bool>(true);

  /// Volume sliders, 0.0 - 1.0.
  final ValueNotifier<double> sfxVolume = ValueNotifier<double>(0.8);
  final ValueNotifier<double> musicVolume = ValueNotifier<double>(0.7);

  /// Phone vibration (interval cues, challenges, hold buttons).
  final ValueNotifier<bool> vibrateOn = ValueNotifier<bool>(true);

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  AudioPlayer? _music;
  Bgm? _want; // the track that SHOULD be playing
  Bgm? _playing;
  bool _ready = false;
  bool _paused = false;
  int _fadeToken = 0;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final sp = await SharedPreferences.getInstance();
      sfxOn.value = sp.getBool(_kSfx) ?? true;
      musicOn.value = sp.getBool(_kMusic) ?? true;
      sfxVolume.value = sp.getDouble(_kSfxVol) ?? 0.8;
      musicVolume.value = sp.getDouble(_kMusicVol) ?? 0.7;
      vibrateOn.value = sp.getBool(_kVibe) ?? true;
    } catch (_) {}
    try {
      WidgetsBinding.instance.addObserver(this);
      try {
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ));
      } catch (_) {} // not supported on every platform (e.g. web)
      for (var i = 0; i < _poolSize; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      _music = AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Sound init failed: $e');
    }
  }

  // ───────────── sound effects ─────────────
  void play(Sfx s, {double volume = 1.0}) {
    if (!sfxOn.value || _pool.isEmpty) return;
    try {
      final p = _pool[_next];
      _next = (_next + 1) % _pool.length;
      p.stop().catchError((_) {});
      p.play(AssetSource('audio/sfx/${s.file}.wav'),
              volume: (sfxVolume.value * volume).clamp(0.0, 1.0))
          .catchError((_) {});
    } catch (_) {}
  }

  /// Phone buzz that respects the VIBRATION setting.
  void buzz([int level = 2]) {
    if (!vibrateOn.value) return;
    try {
      if (level >= 3) {
        HapticFeedback.heavyImpact();
      } else if (level == 2) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Browsers only allow audio after a tap. Called on every tap; the first one
  /// starts the music that was waiting.
  void userGesture() {
    if (_want != null && _playing == null && musicOn.value && !_paused) {
      _startMusic(_want!);
    }
  }

  // ───────────── music ─────────────
  /// Switches to [b]. Does nothing if it is already the current track.
  void music(Bgm? b) {
    _want = b;
    if (b == null) {
      _stopMusic();
      return;
    }
    if (!musicOn.value || _paused) return;
    if (_playing == b) return;
    _startMusic(b);
  }

  Future<void> _startMusic(Bgm b) async {
    final m = _music;
    if (m == null) return;
    final token = ++_fadeToken;
    try {
      _playing = b;
      await m.stop();
      await m.setVolume(0);
      await m.play(AssetSource('audio/music/${b.file}.wav'));
      // quick fade-in
      for (var i = 1; i <= 6; i++) {
        if (token != _fadeToken) return;
        await m.setVolume(_targetVol(b) * i / 6);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    } catch (_) {
      // Most likely the browser still blocks autoplay: try again on next tap.
      if (token == _fadeToken) _playing = null;
    }
  }

  double _targetVol(Bgm b) =>
      (_musicBase * musicVolume.value * b.gain).clamp(0.0, 1.0);

  Future<void> _stopMusic() async {
    final m = _music;
    if (m == null) return;
    final token = ++_fadeToken;
    final from = _want != null ? _targetVol(_want!) : _musicBase * musicVolume.value;
    _playing = null;
    try {
      for (var i = 5; i >= 0; i--) {
        if (token != _fadeToken) return;
        await m.setVolume(from * i / 6);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (token == _fadeToken) await m.stop();
    } catch (_) {}
  }

  // ───────────── settings ─────────────
  Future<void> setSfx(bool on) async {
    sfxOn.value = on;
    if (on) play(Sfx.click);
    try {
      (await SharedPreferences.getInstance()).setBool(_kSfx, on);
    } catch (_) {}
  }

  Future<void> setSfxVolume(double v, {bool preview = false}) async {
    sfxVolume.value = v.clamp(0.0, 1.0);
    if (preview) play(Sfx.click);
    try {
      (await SharedPreferences.getInstance()).setDouble(_kSfxVol, sfxVolume.value);
    } catch (_) {}
  }

  Future<void> setMusicVolume(double v) async {
    musicVolume.value = v.clamp(0.0, 1.0);
    if (_playing != null) {
      try {
        await _music?.setVolume(_targetVol(_playing!));
      } catch (_) {}
    }
    try {
      (await SharedPreferences.getInstance()).setDouble(_kMusicVol, musicVolume.value);
    } catch (_) {}
  }

  Future<void> setVibrate(bool on) async {
    vibrateOn.value = on;
    if (on) buzz(2);
    try {
      (await SharedPreferences.getInstance()).setBool(_kVibe, on);
    } catch (_) {}
  }

  Future<void> setMusic(bool on) async {
    musicOn.value = on;
    if (on) {
      if (_want != null) _startMusic(_want!);
    } else {
      _stopMusic();
    }
    try {
      (await SharedPreferences.getInstance()).setBool(_kMusic, on);
    } catch (_) {}
  }

  // ───────────── app lifecycle ─────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      if (_want != null && musicOn.value) _startMusic(_want!);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _paused = true;
      _fadeToken++;
      _playing = null;
      _music?.pause().catchError((_) {});
    }
  }
}
