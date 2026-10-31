#!/usr/bin/env python3
"""Generate PLACEHOLDER sound effects and music for Realms Rumble.

Simple synthesized chiptune-style audio so the game has sound while real
assets are produced. Every file is replaceable: drop a new file with the same
name into audio/ (see docs/AUDIO.md). Requires numpy and ffmpeg (libvorbis).

    python3 tools/synth_placeholder_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.005, release=None, decay=None):
    """Attack-then-exponential-decay envelope of n samples."""
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e[a:] *= np.exp(-np.arange(n - a) / (SR * decay))
    if release:
        r = min(n, int(SR * release))
        e[-r:] *= np.linspace(1, 0, r)
    return e


def sweep(f0, f1, seconds, wave_fn=np.sin):
    f = np.geomspace(f0, f1, int(SR * seconds))
    return wave_fn(2 * np.pi * np.cumsum(f) / SR)


def square(phase):
    return np.sign(np.sin(phase))


def tri(phase):
    return 2 / np.pi * np.arcsin(np.sin(phase))


def noise(seconds):
    return rng.uniform(-1, 1, int(SR * seconds))


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def normalize(x, peak_db=-3.0):
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * (10 ** (peak_db / 20))


def write(rel, x, peak_db=-3.0):
    path = os.path.join(ROOT, rel + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (normalize(x, peak_db) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.unlink(tmp.name)
    print("wrote", os.path.relpath(path, ROOT))


# --- Sound effects --------------------------------------------------------------
def sfx():
    n = noise(0.12)
    thump = sweep(180, 50, 0.12)
    write("sfx/hit_spark", (lowpass(n, 0.35) * 0.8 + thump) * env(len(n), 0.001, decay=0.035))
    n = noise(0.28)
    write("sfx/hit_heavy", (lowpass(n, 0.25) * 0.7 + sweep(140, 35, 0.28) * 1.2) * env(len(n), 0.001, decay=0.08))
    ping = np.sin(2 * np.pi * 1320 * t(0.25)) + 0.5 * np.sin(2 * np.pi * 1980 * t(0.25))
    write("sfx/shield_hit", (ping * 0.6 + lowpass(noise(0.25), 0.5) * 0.3) * env(len(ping), 0.001, decay=0.06))
    write("sfx/guard_block", (sweep(900, 600, 0.2) + lowpass(noise(0.2), 0.4) * 0.3) * env(int(SR * 0.2), 0.001, decay=0.05))
    shards = sum(np.sin(2 * np.pi * f * t(0.6)) * env(int(SR * 0.6), 0.001, decay=d)
                 for f, d in [(2200, 0.05), (3100, 0.08), (1700, 0.12), (2600, 0.2)])
    write("sfx/shield_break", shards + lowpass(noise(0.6), 0.6) * env(int(SR * 0.6), 0.001, decay=0.15))
    boom = sweep(90, 30, 1.0) * env(int(SR * 1.0), 0.002, decay=0.35)
    whoosh = lowpass(noise(1.0), 0.08) * env(int(SR * 1.0), 0.05, decay=0.3)
    write("sfx/blast_ko", boom * 1.4 + whoosh)
    write("sfx/respawn", sum(np.sin(2 * np.pi * f * t(0.7)) * env(int(SR * 0.7), 0.01 + i * 0.08, decay=0.25)
                            for i, f in enumerate([523, 659, 784, 1047])))
    write("sfx/double_jump", sweep(300, 900, 0.18, tri) * env(int(SR * 0.18), 0.005, release=0.08), -6)
    write("sfx/jump", sweep(220, 520, 0.12, tri) * env(int(SR * 0.12), 0.003, release=0.06), -8)
    write("sfx/dodge", lowpass(noise(0.22), 0.15) * np.sin(np.linspace(0, np.pi, int(SR * 0.22))), -6)
    write("sfx/shield_up", np.sin(2 * np.pi * 440 * t(0.15)) * env(int(SR * 0.15), 0.01, release=0.1), -10)
    write("sfx/projectile_fizzle", lowpass(noise(0.3), 0.2) * env(int(SR * 0.3), 0.001, decay=0.1), -8)
    write("sfx/fireball_cast", (lowpass(noise(0.35), 0.1) + sweep(200, 90, 0.35) * 0.5) * env(int(SR * 0.35), 0.01, decay=0.12))
    zap = square(2 * np.pi * np.cumsum(rng.uniform(300, 2400, int(SR * 0.25))) / SR)
    write("sfx/lightning_bolt", lowpass(zap, 0.5) * env(int(SR * 0.25), 0.001, decay=0.07))
    write("sfx/lightning_telegraph", np.sin(2 * np.pi * np.cumsum(np.linspace(600, 1400, int(SR * 0.3))) / SR)
          * 0.6 * env(int(SR * 0.3), 0.05, release=0.05), -12)
    for name in ["staff_swing", "saber_swing", "heavy_staff_swing", "heavy_saber_swing"]:
        heavy = name.startswith("heavy")
        d = 0.3 if heavy else 0.16
        x = lowpass(noise(d), 0.12 if heavy else 0.2) * np.sin(np.linspace(0, np.pi, int(SR * d)))
        if "saber" in name:
            x += 0.4 * np.sin(2 * np.pi * 110 * t(d)) * np.sin(np.linspace(0, np.pi, int(SR * d)))
        write("sfx/" + name, x, -6)
    for name in ["magic_push", "force_push"]:
        write("sfx/" + name, (lowpass(noise(0.4), 0.06) * 1.5 + sweep(160, 60, 0.4) * 0.6) * env(int(SR * 0.4), 0.02, decay=0.15))
    write("sfx/force_choke", sweep(70, 55, 0.6, square) * 0.3 * env(int(SR * 0.6), 0.05, release=0.2), -10)
    write("sfx/choke_release", lowpass(noise(0.25), 0.2) * env(int(SR * 0.25), 0.001, decay=0.08), -8)
    write("sfx/force_guard", sweep(300, 600, 0.3) * env(int(SR * 0.3), 0.01, decay=0.12), -8)
    # Menus
    write("ui/move", np.sin(2 * np.pi * 880 * t(0.05)) * env(int(SR * 0.05), 0.001, decay=0.015), -14)
    c = np.concatenate([np.sin(2 * np.pi * 660 * t(0.06)), np.sin(2 * np.pi * 990 * t(0.09))])
    write("ui/confirm", c * env(len(c), 0.001, decay=0.06), -10)
    b = np.concatenate([np.sin(2 * np.pi * 660 * t(0.06)), np.sin(2 * np.pi * 440 * t(0.09))])
    write("ui/back", b * env(len(b), 0.001, decay=0.06), -12)


# --- Music ---------------------------------------------------------------------
NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}


def freq(name, octave):
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def tone(f, seconds, kind="square", vol=1.0, decay=None):
    ph = 2 * np.pi * f * t(seconds)
    w = {"square": square(ph) * 0.5 + np.sin(ph) * 0.5, "tri": tri(ph), "sin": np.sin(ph),
         "pulse": np.where(np.mod(ph, 2 * np.pi) < np.pi * 0.5, 1.0, -1.0)}[kind]
    return w * vol * env(len(ph), 0.004, release=min(0.03, seconds / 3), decay=decay)


def drum(kind, seconds):
    n = int(SR * seconds)
    if kind == "kick":
        return sweep(120, 40, seconds) * env(n, 0.001, decay=0.09)
    if kind == "snare":
        return (lowpass(noise(seconds), 0.6) * 0.8 + np.sin(2 * np.pi * 190 * t(seconds)) * 0.3) * env(n, 0.001, decay=0.05)
    return lowpass(noise(seconds), 0.9) * env(n, 0.001, decay=0.015) * 0.4  # hat


def render(bpm, bars, chords, lead, drums=True, lead_kind="pulse", arp=True):
    beat = 60.0 / bpm
    total = int(SR * beat * 4 * bars)
    mix = np.zeros(total + SR)

    def put(x, start_beats):
        i = int(SR * beat * start_beats)
        mix[i:i + len(x)] += x

    for bar in range(bars):
        root, quality = chords[bar % len(chords)]
        third = 3 if quality == "m" else 4
        names = list(NOTE)
        tones = [names[(NOTE[root] + step) % 12] for step in (0, third, 7)]
        for b in range(4):
            put(tone(freq(root, 2), beat * 0.9, "tri", 0.55), bar * 4 + b)
            if arp:
                for s in range(2):
                    put(tone(freq(tones[(b * 2 + s) % 3], 4), beat * 0.45, "square", 0.12), bar * 4 + b + s * 0.5)
            if drums:
                put(drum("kick", beat * 0.5), bar * 4 + b) if b % 2 == 0 else put(drum("snare", beat * 0.5), bar * 4 + b)
                put(drum("hat", beat * 0.25), bar * 4 + b + 0.5)
    for (note, octave, start, length) in lead:
        put(tone(freq(note, octave), beat * length * 0.95, lead_kind, 0.22), start)
    return mix[:total]


def music():
    battle_chords = [("A", "m"), ("F", ""), ("C", ""), ("G", "")]
    melody = []
    phrase = [("E", 5, 0, 1), ("A", 5, 1, 1), ("G", 5, 2, 0.5), ("E", 5, 2.5, 0.5), ("D", 5, 3, 1),
              ("C", 5, 4, 1.5), ("D", 5, 5.5, 0.5), ("E", 5, 6, 2),
              ("G", 5, 8, 1), ("E", 5, 9, 1), ("D", 5, 10, 1), ("C", 5, 11, 1),
              ("D", 5, 12, 2), ("B", 4, 14, 2)]
    for rep in range(2):
        melody += [(n, o, s + rep * 16, l) for n, o, s, l in phrase]
    write("music/battle", render(144, 8, battle_chords, melody), -4)
    menu_chords = [("C", ""), ("A", "m"), ("F", ""), ("G", "")]
    menu_melody = [("E", 5, 0, 2), ("G", 5, 2, 2), ("A", 5, 4, 3), ("G", 5, 7, 1),
                   ("F", 5, 8, 2), ("E", 5, 10, 2), ("D", 5, 12, 4)]
    write("music/menu", render(100, 4, menu_chords, menu_melody, drums=False, lead_kind="tri"), -6)
    fanfare = np.concatenate([tone(freq(n, 5), d, "pulse", 0.5) for n, d in
                              [("C", 0.15), ("E", 0.15), ("G", 0.15), ("C", 0.6)]])
    pad = sum(tone(freq(n, 4), len(fanfare) / SR, "tri", 0.3) for n in ["C", "E", "G"])
    write("music/victory", fanfare + pad[:len(fanfare)], -4)


if __name__ == "__main__":
    sfx()
    music()
