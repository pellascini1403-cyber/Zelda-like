#!/usr/bin/env python3
"""Synthesizes the placeholder sound set (pure Python, no dependencies).

Every file is replaceable: drop a final .ogg/.wav with the same name into
assets/audio/ (.ogg wins if both exist). Mono 22.05 kHz 16-bit keeps the
whole set small for mobile builds.   Run: python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = random.Random(7)


def write(name, samples, loop=False):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32000)) for s in samples))
    if loop:
        # Godot reads loop settings from the .import file.
        with open(os.path.join(OUT, name + ".wav.import"), "w") as f:
            f.write(IMPORT_LOOP.format(name=name))


IMPORT_LOOP = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://assets/audio/{name}.wav"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
"""


def env(i, n, a=0.01, r=0.3):
    t = i / RATE
    dur = n / RATE
    if t < a:
        return t / a
    return max(0.0, 1.0 - (t - a) / max(dur - a, 1e-4)) ** (1.0 / max(r, 0.05))


def noise(n):
    return [rng.uniform(-1, 1) for _ in range(n)]


def lowpass(x, k):
    y, out = 0.0, []
    for s in x:
        y += k * (s - y)
        out.append(y)
    return out


def highpass(x, k):
    lp = lowpass(x, k)
    return [a - b for a, b in zip(x, lp)]


def tone(freq, dur, kind="sine", vol=1.0, sweep=0.0):
    n = int(dur * RATE)
    out, ph = [], 0.0
    for i in range(n):
        f = freq * (1 + sweep * i / n)
        ph += 2 * math.pi * f / RATE
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:
            v = 1.0 if math.sin(ph) > 0 else -1.0
        out.append(v * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def shaped(x, attack=0.005, release=0.3):
    n = len(x)
    return [s * env(i, n, attack, release) for i, s in enumerate(x)]


def sfx():
    n = lambda d: int(d * RATE)
    write("swing", shaped(highpass(lowpass(noise(n(0.22)), 0.35), 0.02), 0.06, 0.5))
    write("swing_heavy", shaped(lowpass(noise(n(0.4)), 0.18), 0.12, 0.6))
    write("hit", shaped(mix(lowpass(noise(n(0.18)), 0.4), tone(110, 0.18, "sine", 0.9, -0.5)), 0.001, 0.25))
    write("block", shaped(mix(tone(620, 0.2, "tri", 0.5), tone(930, 0.2, "sine", 0.3), highpass(noise(n(0.05)), 0.3)), 0.001, 0.3))
    write("parry", shaped(mix(tone(880, 0.5, "sine", 0.6), tone(1320, 0.5, "sine", 0.4), tone(1760, 0.3, "sine", 0.2)), 0.001, 0.6))
    write("hurt", shaped(mix(lowpass(noise(n(0.25)), 0.25), tone(90, 0.25, "sine", 0.8, -0.3)), 0.002, 0.4))
    write("dodge", shaped(lowpass(noise(n(0.3)), 0.12), 0.08, 0.6))
    write("jump", shaped(lowpass(noise(n(0.12)), 0.2), 0.005, 0.4))
    write("land", shaped(mix(lowpass(noise(n(0.18)), 0.08), tone(70, 0.18, "sine", 0.8)), 0.001, 0.3))
    write("grab", shaped(lowpass(noise(n(0.08)), 0.3), 0.001, 0.3))
    write("slip", shaped(lowpass(noise(n(0.35)), 0.2), 0.01, 0.5))
    for name, k in [("step_grass", 0.25), ("step_stone", 0.5), ("step_snow", 0.12), ("step_sand", 0.18)]:
        write(name, shaped(lowpass(noise(n(0.09)), k), 0.002, 0.25))
    write("glider_open", shaped(mix(lowpass(noise(n(0.35)), 0.3), tone(200, 0.35, "sine", 0.2, 0.6)), 0.02, 0.5))
    write("glider_close", shaped(lowpass(noise(n(0.2)), 0.25), 0.01, 0.4))
    write("splash", shaped(highpass(lowpass(noise(n(0.5)), 0.5), 0.05), 0.005, 0.5))
    write("pickup", shaped(mix(tone(660, 0.15, "sine", 0.5), tone(990, 0.15, "sine", 0.35)), 0.005, 0.5))
    write("gather", shaped(mix(lowpass(noise(n(0.15)), 0.3), tone(520, 0.12, "sine", 0.3)), 0.002, 0.4))
    write("strike_rock", shaped(mix(highpass(noise(n(0.12)), 0.2), tone(310, 0.12, "tri", 0.5)), 0.001, 0.25))
    write("break_wood", shaped(mix(lowpass(noise(n(0.35)), 0.3), tone(140, 0.2, "tri", 0.4, -0.5)), 0.001, 0.35))
    write("thud", shaped(mix(lowpass(noise(n(0.2)), 0.06), tone(55, 0.2, "sine", 0.9)), 0.001, 0.3))
    write("chest_open", shaped(mix(lowpass(noise(n(0.3)), 0.2), tone(180, 0.3, "tri", 0.3, 0.4)), 0.01, 0.5))
    write("explosion", shaped(mix(lowpass(noise(n(1.2)), 0.05), tone(45, 1.2, "sine", 0.9, -0.4)), 0.001, 0.45))
    write("ignite", shaped(lowpass(noise(n(0.6)), 0.15), 0.1, 0.6))
    write("thunder", shaped(mix(lowpass(noise(n(2.5)), 0.02), lowpass(noise(n(2.5)), 0.08)), 0.01, 0.5))
    write("charge", shaped(tone(220, 0.5, "tri", 0.4, 1.0), 0.05, 0.9))
    write("slam", shaped(mix(lowpass(noise(n(0.5)), 0.05), tone(48, 0.5, "sine", 1.0, -0.3)), 0.001, 0.4))
    write("spit", shaped(mix(lowpass(noise(n(0.18)), 0.35), tone(300, 0.18, "sine", 0.3, -0.6)), 0.002, 0.4))
    write("creature_alert", shaped(tone(420, 0.25, "tri", 0.5, 0.5), 0.01, 0.5))
    write("creature_die", shaped(mix(tone(300, 0.6, "tri", 0.5, -0.7), lowpass(noise(n(0.6)), 0.1)), 0.01, 0.6))
    write("npc_ouch", shaped(tone(350, 0.15, "tri", 0.4, -0.3), 0.005, 0.5))
    write("eat", shaped(mix(lowpass(noise(n(0.25)), 0.3), tone(400, 0.1, "sine", 0.2)), 0.005, 0.5))
    write("craft", shaped(mix(tone(520, 0.12, "tri", 0.4), tone(780, 0.2, "sine", 0.4)), 0.002, 0.6))
    write("cook", shaped(mix(lowpass(noise(n(0.6)), 0.4), tone(330, 0.6, "sine", 0.2, 0.3)), 0.05, 0.6))
    write("repair", shaped(mix(highpass(noise(n(0.25)), 0.4), tone(1200, 0.25, "sine", 0.2)), 0.01, 0.5))
    write("ui_click", shaped(tone(900, 0.04, "sine", 0.5), 0.001, 0.4))
    write("menu_open", shaped(mix(tone(440, 0.18, "sine", 0.4, 0.3), tone(660, 0.18, "sine", 0.2, 0.3)), 0.01, 0.5))
    write("menu_close", shaped(tone(520, 0.14, "sine", 0.4, -0.3), 0.01, 0.5))
    write("perfect_dodge", shaped(mix(tone(1200, 0.6, "sine", 0.4, -0.5), tone(600, 0.6, "sine", 0.3, -0.5)), 0.01, 0.7))
    notes = [523.25, 659.25, 783.99, 1046.5]
    write("discovery", mix(*[[0.0] * int(i * 0.12 * RATE) + shaped(tone(f, 1.2, "sine", 0.35), 0.01, 0.6) for i, f in enumerate(notes)]))


def pad(chord, dur, bright=0.3):
    # Soft evolving pad; last and first samples line up for seamless loops.
    n = int(dur * RATE)
    out = [0.0] * n
    for f in chord:
        for harm, g in [(1, 1.0), (2, bright), (3, bright * 0.4)]:
            ph = rng.random() * math.tau
            for i in range(n):
                t = i / RATE
                lfo = 1.0 + 0.004 * math.sin(math.tau * t / dur * 2)
                out[i] += g * math.sin(ph + math.tau * f * harm * lfo * t) / len(chord)
    for i in range(n):
        out[i] *= 0.55 + 0.45 * math.sin(math.pi * i / n) ** 0.5
    return out


def music():
    # 4 chords x 6 s, each voiced softly. Keys differ per mood.
    def progression(chords, sec, bright):
        s = []
        for c in chords:
            s += pad(c, sec, bright)
        return s
    D = lambda *m: [440.0 * 2 ** ((x - 69) / 12) for x in m]
    write("music_day", progression([D(50, 57, 62, 66), D(47, 54, 59, 62), D(43, 55, 59, 62), D(45, 52, 57, 61)], 6.0, 0.35), loop=True)
    write("music_night", progression([D(45, 52, 57, 60), D(41, 48, 53, 57), D(43, 50, 55, 58), D(40, 47, 52, 55)], 7.0, 0.15), loop=True)
    write("music_high", progression([D(48, 55, 62, 67), D(50, 57, 62, 69), D(45, 52, 60, 64), D(43, 50, 55, 62)], 7.0, 0.25), loop=True)
    write("music_title", progression([D(50, 57, 62, 69), D(46, 53, 58, 65), D(43, 50, 55, 62), D(45, 52, 57, 64)], 6.5, 0.3), loop=True)
    # Combat: pulsing low drone + rhythmic noise hits
    n = int(12.0 * RATE)
    base = pad(D(38, 45, 50), 12.0, 0.5)
    beat = [0.0] * n
    step = int(RATE * 60 / 132 / 2)
    for k in range(0, n, step):
        hit = shaped(lowpass(noise(int(0.08 * RATE)), 0.15 if (k // step) % 2 == 0 else 0.5), 0.001, 0.25)
        for i, s in enumerate(hit):
            if k + i < n:
                beat[k + i] += s * (0.6 if (k // step) % 4 == 0 else 0.3)
    write("music_combat", mix(base, beat), loop=True)


def ambience():
    n = int(8.0 * RATE)
    wind = lowpass(noise(n), 0.02)
    wind = [s * (0.6 + 0.4 * math.sin(math.tau * i / n * 2)) for i, s in enumerate(wind)]
    write("amb_wind", wind, loop=True)
    write("amb_rain", highpass(lowpass(noise(n), 0.5), 0.05), loop=True)
    day = [0.0] * n
    for _ in range(14):   # birds: short chirps
        start = rng.randint(0, n - RATE)
        f = rng.uniform(2200, 3600)
        ch = shaped(tone(f, 0.09, "sine", 0.25, 0.3), 0.005, 0.4)
        for rep in range(rng.randint(2, 4)):
            off = start + rep * int(0.13 * RATE)
            for i, s in enumerate(ch):
                if off + i < n:
                    day[off + i] += s
    day = mix(day, [s * 0.15 for s in lowpass(noise(n), 0.01)])
    write("amb_day", day, loop=True)
    night = [0.0] * n
    for k in range(0, n, int(0.05 * RATE)):   # crickets
        if (k // int(0.05 * RATE)) % 8 < 3:
            ch = shaped(tone(4200, 0.03, "sine", 0.12), 0.002, 0.3)
            for i, s in enumerate(ch):
                if k + i < n:
                    night[k + i] += s
    night = mix(night, [s * 0.1 for s in lowpass(noise(n), 0.01)])
    write("amb_night", night, loop=True)


def pluck(freq, dur, vol=0.5, decay=0.996):
    # Karplus-Strong string: a plucked zither-like voice for melodies.
    n = int(dur * RATE)
    period = max(2, int(RATE / freq))
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(n):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = decay * 0.5 * (v + nxt)
        out.append(v * vol)
    return shaped(out, 0.001, 0.5)


def melody(notes, step, total, vol=0.35):
    # notes: list of (beat, midi); pentatonic phrases over the pads.
    n = int(total * RATE)
    out = [0.0] * n
    for beat, m in notes:
        f = 440.0 * 2 ** ((m - 69) / 12)
        start = int(beat * step * RATE)
        s = pluck(f, 1.6, vol)
        for i, v in enumerate(s):
            if start + i < n:
                out[start + i] += v
    return out


def drums(total, bpm, pattern, vol=0.7):
    n = int(total * RATE)
    out = [0.0] * n
    step = int(RATE * 60 / bpm / 2)
    for k in range(0, n, step):
        idx = (k // step) % len(pattern)
        c = pattern[idx]
        if c == "B":
            hit = shaped(mix(lowpass(noise(int(0.25 * RATE)), 0.04), tone(52, 0.25, "sine", 1.0, -0.4)), 0.001, 0.35)
        elif c == "s":
            hit = shaped(lowpass(noise(int(0.1 * RATE)), 0.3), 0.001, 0.3)
        else:
            continue
        for i, v in enumerate(hit):
            if k + i < n:
                out[k + i] += v * vol
    return out


def sfx2():
    n = lambda d: int(d * RATE)
    write("quest_start", mix(*[[0.0] * int(i * 0.14 * RATE) + pluck(f, 1.4, 0.4) for i, f in enumerate([392.0, 523.25, 587.33])]))
    write("quest_stage", mix(pluck(659.25, 1.0, 0.35), [0.0] * int(0.1 * RATE) + pluck(783.99, 1.0, 0.3)))
    write("quest_complete", mix(*[[0.0] * int(i * 0.12 * RATE) + pluck(f, 1.8, 0.4) for i, f in enumerate([523.25, 587.33, 659.25, 783.99, 1046.5])]))
    write("boss_roar", shaped(mix(lowpass(noise(n(1.6)), 0.03), tone(70, 1.6, "saw", 0.6, -0.3), tone(105, 1.6, "tri", 0.3, -0.2)), 0.08, 0.5))
    write("gust", shaped(highpass(lowpass(noise(n(0.45)), 0.25), 0.02), 0.03, 0.6))
    write("jade", shaped(mix(tone(1320, 0.5, "sine", 0.35), tone(1980, 0.5, "sine", 0.2), tone(660, 0.5, "tri", 0.2)), 0.002, 0.7))
    write("wind_sight", shaped(mix(lowpass(noise(n(1.2)), 0.05), tone(880, 1.2, "sine", 0.15, 0.2), tone(1320, 1.2, "sine", 0.1, 0.2)), 0.2, 0.6))
    write("stillness", shaped(mix(tone(220, 1.5, "sine", 0.4, -0.5), tone(330, 1.5, "sine", 0.2, -0.5), lowpass(noise(n(1.5)), 0.02)), 0.02, 0.7))
    write("whistle", shaped(mix(tone(1400, 0.25, "sine", 0.4, 0.2), [0.0] * n(0.28) + tone(1700, 0.35, "sine", 0.4, -0.1)), 0.01, 0.5))
    write("mount", shaped(mix(lowpass(noise(n(0.3)), 0.1), tone(160, 0.3, "tri", 0.4, 0.3)), 0.01, 0.5))
    write("puzzle_solved", mix(*[[0.0] * int(i * 0.1 * RATE) + pluck(f, 1.6, 0.35) for i, f in enumerate([440.0, 554.37, 659.25, 880.0])]))
    write("coin", shaped(mix(tone(1568, 0.12, "sine", 0.35), [0.0] * n(0.05) + tone(2093, 0.18, "sine", 0.3)), 0.001, 0.6))


def sfx3():
    """Quest layer: wind-ring pass, chimes, an encounter sting."""
    n = lambda d: int(d * RATE)
    write("ring", shaped(mix(tone(988, 0.35, "sine", 0.35, 0.15), tone(1480, 0.35, "sine", 0.18, 0.1), highpass(lowpass(noise(n(0.35)), 0.3), 0.05)), 0.004, 0.7))
    write("chime", mix(*[[0.0] * int(i * 0.07 * RATE) + pluck(f, 2.2, 0.28, 0.9993) for i, f in enumerate([1318.5, 1567.98, 1975.5, 2349.3])]))
    write("encounter", shaped(mix(tone(98, 0.9, "saw", 0.35, -0.2), lowpass(noise(n(0.9)), 0.05), [0.0] * n(0.12) + tone(146.8, 0.7, "tri", 0.3, -0.1)), 0.01, 0.6))


def music2():
    D = lambda *m: [440.0 * 2 ** ((x - 69) / 12) for x in m]
    # Boss: taiko-like drums, low fifths, urgent pentatonic plucks.
    total = 16.0
    base = pad(D(38, 45, 50), 8.0, 0.55) + pad(D(36, 43, 48), 8.0, 0.55)
    dr = drums(total, 124, "B.s.B.sBB.s.BsBs")
    mel = melody([(0, 62), (1, 65), (2, 67), (3, 69), (4, 67), (6, 65), (8, 62), (9, 60), (10, 62), (12, 65), (13, 67), (14, 72), (16, 69), (18, 67), (20, 65), (22, 62), (24, 62), (26, 65), (28, 67), (30, 60)], 60 / 124, total, 0.3)
    write("music_boss", mix(base, dr, mel), loop=True)
    # Desert: open fifths drone, sparse descending plucks.
    total = 24.0
    base = pad(D(40, 47, 52), 12.0, 0.3) + pad(D(38, 45, 52), 12.0, 0.3)
    mel = melody([(0, 76), (3, 74), (4, 71), (8, 69), (12, 71), (15, 74), (16, 76), (20, 79), (24, 76), (27, 74), (28, 71), (32, 69), (36, 64), (40, 67), (44, 69)], 0.5, total, 0.28)
    write("music_desert", mix(base, mel), loop=True)
    # Veil: glassy detuned high pad, very slow tones.
    total = 28.0
    base = pad(D(57, 64, 71, 76), 14.0, 0.1) + pad(D(55, 62, 69, 74), 14.0, 0.1)
    det = pad(D(57.12, 64.1, 71.08), 28.0, 0.05)
    mel = melody([(0, 81), (8, 79), (16, 76), (24, 74), (32, 76), (40, 72), (48, 74)], 0.5, total, 0.18)
    write("music_veil", mix(base, [v * 0.5 for v in det], mel), loop=True)
    # Day theme gains a pentatonic melody over its pads.
    total = 24.0
    day = pad(D(50, 57, 62, 66), 6.0, 0.35) + pad(D(47, 54, 59, 62), 6.0, 0.35) + pad(D(43, 55, 59, 62), 6.0, 0.35) + pad(D(45, 52, 57, 61), 6.0, 0.35)
    mel = melody([(0, 74), (1, 76), (2, 78), (4, 81), (6, 78), (8, 76), (10, 74), (12, 71), (14, 74), (16, 76), (20, 74), (24, 78), (25, 81), (26, 83), (28, 81), (30, 78), (32, 76), (36, 74), (40, 71), (44, 74)], 0.5, total, 0.25)
    write("music_day", mix(day, mel), loop=True)


def ambience2():
    n = int(6.0 * RATE)
    roar = lowpass(noise(n), 0.12)
    hiss = highpass(noise(n), 0.3)
    write("amb_waterfall", [0.7 * a + 0.25 * b for a, b in zip(roar, hiss)], loop=True)


if __name__ == "__main__":
    import sys
    if "--new" not in sys.argv:
        sfx()
        ambience()
        music()
    sfx2()
    ambience2()
    music2()
    sfx3()   # last: earlier sounds keep their random streams
    print("audio written to", os.path.normpath(OUT))
