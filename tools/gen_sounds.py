#!/usr/bin/env python3
"""
Synthesises HakbangHero's sound effects and background music (8-bit style).

  python3 tools/gen_sounds.py          # only creates MISSING files
  python3 tools/gen_sounds.py --force  # rebuilds everything (overwrites your own files!)

Writes WAV files to assets/audio/sfx/ and assets/audio/music/.
To use your OWN sounds, just replace a file with one of the same name
(keep music files looping-friendly). Needs: numpy.
"""
import math, pathlib, struct, sys, wave
import numpy as np

SR = 22050
ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / 'assets/audio/sfx'
MUS = ROOT / 'assets/audio/music'
SFX.mkdir(parents=True, exist_ok=True)
MUS.mkdir(parents=True, exist_ok=True)

NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7,
        'G#': 8, 'A': 9, 'A#': 10, 'B': 11}

def hz(name):
    """'A4' -> 440.0"""
    n, o = name[:-1], int(name[-1])
    midi = 12 * (o + 1) + NOTE[n]
    return 440.0 * 2 ** ((midi - 69) / 12)

def t_axis(dur):
    return np.arange(int(SR * dur)) / SR

def square(f, dur, duty=0.5):
    t = t_axis(dur)
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)

def tri(f, dur):
    t = t_axis(dur)
    return 2 * np.abs(2 * ((t * f) % 1.0) - 1) - 1

def saw(f, dur):
    t = t_axis(dur)
    return 2 * ((t * f) % 1.0) - 1

def noise(dur, seed=1):
    rng = np.random.default_rng(seed)
    return rng.uniform(-1, 1, int(SR * dur))

def env(n, a=0.004, d=0.0, s=1.0, r=0.03):
    """attack / decay-to-sustain / release envelope over n samples"""
    e = np.ones(n)
    a_n, d_n, r_n = int(SR * a), int(SR * d), int(SR * r)
    a_n = min(a_n, n)
    if a_n: e[:a_n] = np.linspace(0, 1, a_n)
    if d_n and a_n + d_n < n:
        e[a_n:a_n + d_n] = np.linspace(1, s, d_n)
        e[a_n + d_n:] = s
    elif d_n == 0:
        e[a_n:] = s
    r_n = min(r_n, n)
    if r_n: e[-r_n:] *= np.linspace(1, 0, r_n)
    return e

def tone(f, dur, wave_='square', vol=0.5, duty=0.5, a=0.004, d=0.05, s=0.6, r=0.04, slide=None):
    if slide:  # glide from f to slide over the note
        t = t_axis(dur)
        freq = np.linspace(f, slide, len(t))
        phase = np.cumsum(freq) / SR
        w = np.where(phase % 1.0 < duty, 1.0, -1.0) if wave_ == 'square' else \
            (2 * np.abs(2 * (phase % 1.0) - 1) - 1)
    else:
        w = {'square': lambda: square(f, dur, duty), 'tri': lambda: tri(f, dur),
             'saw': lambda: saw(f, dur)}[wave_]()
    return w * env(len(w), a, d, s, r) * vol

def place(buf, sig, at):
    i = int(SR * at)
    end = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:end] += sig[:end - i]

def save(path, sig, peak=0.85):
    if path.exists() and '--force' not in sys.argv:
        return  # keep sounds you replaced yourself; use --force to rebuild all
    sig = np.asarray(sig, dtype=np.float64)
    m = np.max(np.abs(sig)) or 1.0
    sig = sig / m * peak
    pcm = (sig * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())

def seq(notes, wave_='square', vol=0.5, gap=0.0, **kw):
    """[(note, dur), ...] played one after another"""
    total = sum(d + gap for _, d in notes)
    buf = np.zeros(int(SR * total) + 1)
    at = 0.0
    for n, d in notes:
        if n:
            place(buf, tone(hz(n), d, wave_, vol, **kw), at)
        at += d + gap
    return buf

# ─────────────────────────── sound effects ───────────────────────────
def make_sfx():
    save(SFX / 'click.wav', tone(hz('E6'), 0.05, 'square', 0.5, duty=0.25, d=0.02, s=0.3, r=0.02) +
         tone(hz('A6'), 0.05, 'square', 0.25, duty=0.25, d=0.02, s=0.2, r=0.02))
    save(SFX / 'back.wav', seq([('A5', 0.05), ('E5', 0.08)], 'square', 0.5, duty=0.25))
    save(SFX / 'tab.wav', tone(hz('C6'), 0.035, 'tri', 0.8, d=0.01, s=0.4, r=0.015))
    save(SFX / 'open.wav', tone(300, 0.16, 'square', 0.4, duty=0.25, slide=900, s=0.5, r=0.06))
    save(SFX / 'error.wav', seq([('A3', 0.09), ('F3', 0.16)], 'square', 0.55, duty=0.5))
    save(SFX / 'coin.wav', seq([('B5', 0.06), ('E6', 0.28)], 'square', 0.5, duty=0.25, d=0.1, s=0.5, r=0.12))
    save(SFX / 'gem.wav', seq([('E6', 0.05), ('G6', 0.05), ('B6', 0.05), ('E7', 0.2)], 'tri', 0.8, d=0.08, s=0.5, r=0.1))
    save(SFX / 'star.wav', seq([('C6', 0.06), ('E6', 0.06), ('G6', 0.06), ('C7', 0.06), ('E7', 0.22)],
                               'square', 0.4, duty=0.125, d=0.05, s=0.5, r=0.08))
    # shop purchase: "cha-ching"
    b = np.zeros(int(SR * 0.7))
    place(b, noise(0.06, 3) * env(int(SR * 0.06), 0.002, 0.03, 0.2, 0.02) * 0.25, 0.0)
    place(b, tone(hz('E6'), 0.09, 'square', 0.45, duty=0.25), 0.02)
    place(b, tone(hz('A6'), 0.4, 'square', 0.45, duty=0.25, d=0.2, s=0.4, r=0.15), 0.1)
    save(SFX / 'buy.wav', b)
    save(SFX / 'unlock.wav', seq([('C5', 0.08), ('E5', 0.08), ('G5', 0.08), ('C6', 0.08), ('E6', 0.08), ('G6', 0.3)],
                                 'square', 0.45, duty=0.25, d=0.08, s=0.6, r=0.1))
    # level up fanfare
    lu = np.zeros(int(SR * 1.6))
    for i, (n, d) in enumerate([('G4', 0.12), ('C5', 0.12), ('E5', 0.12), ('G5', 0.12), ('C6', 0.5)]):
        at = sum(x[1] for x in [('G4', 0.12), ('C5', 0.12), ('E5', 0.12), ('G5', 0.12)][:i])
        place(lu, tone(hz(n), d + 0.02, 'square', 0.45, duty=0.25, d=0.06, s=0.7, r=0.05), at)
    place(lu, tone(hz('E5'), 0.5, 'square', 0.25, duty=0.5, d=0.1, s=0.6, r=0.2), 0.48)
    place(lu, tone(hz('G5'), 0.5, 'square', 0.25, duty=0.5, d=0.1, s=0.6, r=0.2), 0.48)
    place(lu, tone(hz('C4'), 0.7, 'tri', 0.6, d=0.2, s=0.7, r=0.3), 0.48)
    save(SFX / 'level_up.wav', lu)
    # stage cleared / run complete jingle
    s = np.zeros(int(SR * 2.0))
    mel = [('C5', 0.14), ('C5', 0.14), ('C5', 0.14), ('G5', 0.4), ('E5', 0.14), ('G5', 0.14), ('C6', 0.6)]
    at = 0.0
    for n, d in mel:
        place(s, tone(hz(n), d + 0.03, 'square', 0.42, duty=0.25, d=0.05, s=0.7, r=0.06), at)
        place(s, tone(hz(n) / 2, d + 0.03, 'tri', 0.5, d=0.05, s=0.8, r=0.06), at)
        at += d
    save(SFX / 'success.wav', s)
    # fail: slow descending
    save(SFX / 'fail.wav', seq([('E4', 0.2), ('D#4', 0.2), ('D4', 0.2), ('A3', 0.6)], 'square', 0.4,
                               duty=0.5, d=0.1, s=0.7, r=0.15))
    # countdown beep / GO
    save(SFX / 'beep.wav', tone(hz('A5'), 0.13, 'square', 0.5, duty=0.5, d=0.03, s=0.8, r=0.04))
    save(SFX / 'go.wav', tone(hz('A6'), 0.45, 'square', 0.5, duty=0.5, d=0.1, s=0.8, r=0.12) +
         tone(hz('A5'), 0.45, 'square', 0.3, duty=0.25, d=0.1, s=0.8, r=0.12))
    # interval cues: FAST = rising double, EASY = falling soft
    save(SFX / 'fast.wav', seq([('E5', 0.07), ('A5', 0.07), ('E6', 0.2)], 'square', 0.5, duty=0.25, d=0.05, s=0.7, r=0.06))
    save(SFX / 'easy.wav', seq([('E5', 0.1), ('B4', 0.1), ('G4', 0.25)], 'tri', 0.9, d=0.08, s=0.7, r=0.1))
    # warm-up exercise change
    save(SFX / 'next.wav', seq([('G5', 0.06), ('C6', 0.14)], 'square', 0.45, duty=0.25, d=0.04, s=0.6, r=0.06))

# ─────────────────────────── music ───────────────────────────
def drum_kick(n=0.14):
    t = t_axis(n)
    f = np.linspace(150, 45, len(t))
    return np.sin(np.cumsum(f) * 2 * math.pi / SR) * env(len(t), 0.001, 0.05, 0.3, 0.05)

def drum_snare(n=0.12, seed=7):
    return noise(n, seed) * env(int(SR * n), 0.001, 0.05, 0.15, 0.05)

def drum_hat(n=0.04, seed=9):
    x = noise(n, seed)
    x = x - np.concatenate(([0], x[:-1])) * 0.9  # crude high-pass
    return x * env(len(x), 0.001, 0.02, 0.1, 0.01)

def chord_tones(root, kind):
    iv = {'maj': [0, 4, 7], 'min': [0, 3, 7]}[kind]
    return [root + i for i in iv]

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

def render_track(path, bpm, chords, melody_pat, bars_per_chord=1, kick='basic', swing_hat=True,
                 bass_style='root8', arp_vol=0.16, lead_vol=0.26, lead_wave='square', lead_duty=0.25,
                 lead_octave=0, seed=1, reps=2):
    """chords: [(rootMidi, 'maj'|'min')...] one per bar-group; melody_pat: per-bar list
    of 16 entries (chord-tone index 0..5, or None) -> 16th-note lead."""
    step = 60.0 / bpm / 4  # 16th
    bars = len(chords) * bars_per_chord * reps
    total = bars * 16 * step
    buf = np.zeros(int(SR * total) + int(SR * 0.5))
    rng = np.random.default_rng(seed)
    bar_i = 0
    for rep in range(reps):
        for ci, (root, kind) in enumerate(chords):
            for _ in range(bars_per_chord):
                tones = chord_tones(root, kind)
                bar_t = bar_i * 16 * step
                for s in range(16):
                    at = bar_t + s * step
                    # bass
                    if bass_style == 'root8' and s % 2 == 0:
                        note = tones[0] - 24 + (12 if s % 8 == 6 else 0)
                        place(buf, tone(midi_hz(note), step * 1.8, 'tri', 0.55, d=0.04, s=0.7, r=0.03), at)
                    elif bass_style == 'drive':
                        note = tones[0] - 24 + (7 if s % 8 == 5 else 0)
                        place(buf, tone(midi_hz(note), step * 0.9, 'saw', 0.28, d=0.03, s=0.6, r=0.02), at)
                    # arpeggio
                    arp = tones[[0, 1, 2, 1][s % 4]] + 12
                    place(buf, tone(midi_hz(arp), step * 0.9, 'square', arp_vol, duty=0.125,
                                    d=0.03, s=0.4, r=0.02), at)
                    # lead
                    idx = melody_pat[(bar_i) % len(melody_pat)][s]
                    if idx is not None:
                        ext = tones + [tones[0] + 12, tones[1] + 12, tones[2] + 12]
                        m = ext[idx] + 12 + 12 * lead_octave
                        place(buf, tone(midi_hz(m), step * 1.7, lead_wave, lead_vol, duty=lead_duty,
                                        d=0.06, s=0.6, r=0.05), at)
                    # drums
                    if kick == 'basic' and s in (0, 8):
                        place(buf, drum_kick() * 0.5, at)
                    if kick == 'four' and s % 4 == 0:
                        place(buf, drum_kick() * 0.55, at)
                    if kick in ('four', 'basic') and s in (4, 12):
                        place(buf, drum_snare(seed=int(rng.integers(1, 99))) * (0.22 if kick == 'basic' else 0.3), at)
                    if s % 2 == 1 or (kick == 'four' and s % 2 == 0):
                        place(buf, drum_hat(seed=int(rng.integers(1, 99))) * (0.12 if s % 2 else 0.07), at)
                bar_i += 1
    sig = buf[:int(SR * total)]
    # make the loop seamless: fade the very ends a hair
    f = int(SR * 0.004)
    sig[:f] *= np.linspace(0, 1, f); sig[-f:] *= np.linspace(1, 0, f)
    save(path, sig, peak=0.8)

def make_music():
    C, D, E, F, G, A, B = 60, 62, 64, 65, 67, 69, 71
    # MENU: 96 BPM, C – Am – F – G, friendly
    render_track(MUS / 'menu.wav', 96,
                 chords=[(C, 'maj'), (A - 12, 'min'), (F - 12, 'maj'), (G - 12, 'maj')],
                 melody_pat=[
                     [2, None, None, None, 1, None, 2, None, 3, None, None, None, 2, None, None, None],
                     [2, None, None, 1, None, None, 0, None, 1, None, 2, None, None, None, None, None],
                     [3, None, None, None, 4, None, 3, None, 2, None, None, None, 1, None, None, None],
                     [2, None, 1, None, 0, None, 1, None, 2, None, None, None, None, None, None, None],
                 ],
                 kick='basic', bass_style='root8', arp_vol=0.13, lead_vol=0.24, lead_duty=0.25, seed=3, reps=2)
    # RUN: 128 BPM, Am – F – C – G, steady and driving
    render_track(MUS / 'run.wav', 128,
                 chords=[(A - 12, 'min'), (F - 12, 'maj'), (C, 'maj'), (G - 12, 'maj')],
                 melody_pat=[
                     [2, None, 2, None, 3, None, 2, None, 1, None, None, None, 2, None, 3, None],
                     [3, None, 3, None, 4, None, 3, None, 2, None, None, None, 1, None, 2, None],
                     [4, None, 4, None, 3, None, 2, None, 3, None, None, None, 4, None, 5, None],
                     [3, None, 2, None, 1, None, 2, None, 3, None, None, None, 2, None, None, None],
                 ],
                 kick='four', bass_style='root8', arp_vol=0.14, lead_vol=0.24, lead_duty=0.25, seed=5, reps=2)
    # SPRINT (interval FAST): 160 BPM, Em – C – G – D, intense
    render_track(MUS / 'sprint.wav', 160,
                 chords=[(E - 12, 'min'), (C - 12, 'maj'), (G - 12, 'maj'), (D - 12, 'maj')],
                 melody_pat=[
                     [2, 3, 2, None, 4, 3, 2, None, 3, 4, 5, None, 4, 3, 2, None],
                     [3, 4, 3, None, 5, 4, 3, None, 2, 3, 4, None, 3, 2, 1, None],
                     [4, 5, 4, None, 5, 4, 3, None, 4, 5, 4, None, 3, 4, 5, None],
                     [3, 2, 3, None, 4, 3, 2, None, 1, 2, 3, None, 2, 1, 0, None],
                 ],
                 kick='four', bass_style='drive', arp_vol=0.16, lead_vol=0.26, lead_wave='square',
                 lead_duty=0.5, seed=8, reps=4)

if __name__ == '__main__':
    make_sfx(); make_music()
    for d in (SFX, MUS):
        for f in sorted(d.glob('*.wav')):
            print('%-28s %6.1f KB  %5.1f s' % (f.relative_to(ROOT), f.stat().st_size / 1024,
                                              (f.stat().st_size - 44) / 2 / SR))
