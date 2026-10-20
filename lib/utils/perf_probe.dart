
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tiny performance meter for debug / profile runs (does nothing in release).
///
///  * Frames: every 5 s prints how many frames were slow
///    ( > 16 ms = missed 60 fps, > 32 ms = visible jank ) plus the worst one.
///  * Navigation: `PerfProbe.markNav('RANKS')` prints how long it took for the
///    new tab to appear on screen.
///
/// Read the numbers in the console lines that start with `[perf]`.
/// For honest numbers run:  flutter run -d chrome --profile
class PerfProbe {
  PerfProbe._();

  static bool _started = false;
  static int _frames = 0, _slow = 0, _jank = 0;
  static double _worstMs = 0, _sumMs = 0;
  static DateTime _windowStart = DateTime.now();

  static bool get _on => kDebugMode || kProfileMode;

  static void start() {
    if (!_on || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      _frames++;
      _sumMs += ms;
      if (ms > 16.7) _slow++;
      if (ms > 33.4) _jank++;
      if (ms > _worstMs) _worstMs = ms;
    }
    final now = DateTime.now();
    if (now.difference(_windowStart).inSeconds >= 5) {
      if (_frames > 0 && _slow > 0) {
        debugPrint('[perf] $_frames frames  avg ${(_sumMs / _frames).toStringAsFixed(1)} ms'
            '  slow(>16ms) $_slow  jank(>33ms) $_jank  worst ${_worstMs.toStringAsFixed(0)} ms');
      }
      _frames = _slow = _jank = 0;
      _worstMs = _sumMs = 0;
      _windowStart = now;
    }
  }

  /// Call right where a tab / screen change is requested.
  static void markNav(String label) {
    if (!_on) return;
    final sw = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[perf] open $label: ${sw.elapsedMilliseconds} ms to first frame');
    });
  }
}
