#!/usr/bin/env python3
"""Generates every Card Rush sound effect and the menu/table music loops.

All audio is synthesised here from scratch (no samples), so it is original and
license-free. Pure standard library: python3 tools/assets/make_audio.py
Outputs WAV files into assets/audio/ (music is converted to OGG with ffmpeg when
available, otherwise left as WAV).
"""
import math
import os
import random
import shutil
import struct
import subprocess
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rnd = random.Random(7)


def silence(sec):
    return [0.0] * int(SR * sec)


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    out = []
    an, dn, rn = int(a * SR), int(d * SR), int(r * SR)
    sn = max(0, n - an - dn - rn)
    for i in range(n):
        if i < an:
            v = i / max(1, an)
        elif i < an + dn:
            v = 1 - (1 - s) * (i - an) / max(1, dn)
        elif i < an + dn + sn:
            v = s
        else:
            v = s * max(0.0, 1 - (i - an - dn - sn) / max(1, rn))
        out.append(v)
    return out


def tone(freq, sec, kind="sine", vol=0.5, a=0.005, d=0.05, s=0.6, r=0.1, vibrato=0.0, glide=0.0):
    n = int(SR * sec)
    env = env_adsr(n, a, d, s, r)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1 + glide * t / max(sec, 1e-6)) * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        ph += 2 * math.pi * f / SR
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif kind == "square":
            v = 0.6 if math.sin(ph) > 0 else -0.6
        elif kind == "saw":
            v = ((ph / math.pi) % 2) - 1
        else:  # soft bell: sine + partials
            v = math.sin(ph) + 0.35 * math.sin(2.76 * ph) * math.exp(-6 * t) + 0.2 * math.sin(5.4 * ph) * math.exp(-10 * t)
        out.append(v * env[i] * vol)
    return out


def noise(sec, vol=0.5, lp=0.5, a=0.002, d=0.05, s=0.3, r=0.05, hp=0.0):
    n = int(SR * sec)
    env = env_adsr(n, a, d, s, r)
    out, y, prev_x, hp_y = [], 0.0, 0.0, 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        y += lp * (x - y)  # one-pole low-pass
        if hp > 0:
            hp_y = hp * (hp_y + y - prev_x)
            prev_x = y
            v = hp_y
        else:
            v = y
        out.append(v * env[i] * vol)
    return out


def sweep_noise(sec, lp0, lp1, vol=0.5, a=0.01, r=0.1):
    n = int(SR * sec)
    env = env_adsr(n, a, 0.02, 0.9, r)
    out, y = [], 0.0
    for i in range(n):
        lp = lp0 + (lp1 - lp0) * i / n
        y += lp * (rnd.uniform(-1, 1) - y)
        out.append(y * env[i] * vol)
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * SR) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        s = int(o * SR)
        for i, v in enumerate(t):
            out[s + i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(name, data, peak=0.85, sr=SR):
    m = max(1e-6, max(abs(v) for v in data))
    g = peak / m if m > peak else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in data))
    return path


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# --- sound effects -------------------------------------------------------------------

def sfx():
    write("card_draw", mix(sweep_noise(0.16, 0.05, 0.6, 0.5, a=0.01, r=0.08), tone(900, 0.05, "sine", 0.08), offsets=[0, 0.1]))
    write("card_play", mix(noise(0.07, 0.9, lp=0.35, d=0.03, s=0.15, r=0.03), tone(140, 0.09, "sine", 0.5, d=0.05, s=0.2, r=0.04, glide=-0.4)))
    write("card_special", mix(
        noise(0.08, 0.7, lp=0.35, d=0.03, s=0.15, r=0.03), tone(150, 0.1, "sine", 0.45, glide=-0.4),
        tone(note(76), 0.18, "bell", 0.25, r=0.15), tone(note(83), 0.22, "bell", 0.2, r=0.18),
        offsets=[0, 0, 0.03, 0.08]))
    write("shuffle", seq(*[mix(noise(0.022, 0.6, lp=0.5, d=0.01, s=0.2, r=0.01)) + silence(rnd.uniform(0.008, 0.02)) for _ in range(26)]))
    write("deal", mix(sweep_noise(0.09, 0.15, 0.7, 0.4, a=0.005, r=0.05)))
    write("color_pick", mix(tone(note(72), 0.12, "tri", 0.35, r=0.08), tone(note(79), 0.16, "tri", 0.3, r=0.1), offsets=[0, 0.06]))
    write("uno", mix(
        tone(note(72), 0.12, "square", 0.22, r=0.05), tone(note(76), 0.12, "square", 0.22, r=0.05),
        tone(note(79), 0.32, "square", 0.22, r=0.2, vibrato=0.006), tone(note(84), 0.34, "bell", 0.3, r=0.25),
        offsets=[0, 0.08, 0.16, 0.16]))
    write("your_turn", mix(tone(note(81), 0.25, "bell", 0.3, r=0.2), tone(note(88), 0.3, "bell", 0.22, r=0.25), offsets=[0, 0.09]))
    write("opponent_last", mix(tone(note(79), 0.14, "tri", 0.35, r=0.06), tone(note(74), 0.14, "tri", 0.35, r=0.06),
                               tone(note(79), 0.14, "tri", 0.35, r=0.06), offsets=[0, 0.15, 0.3]))
    write("penalty", mix(tone(110, 0.32, "saw", 0.25, r=0.15, glide=-0.3), noise(0.2, 0.25, lp=0.1, r=0.1)))
    write("skip", mix(sweep_noise(0.22, 0.6, 0.05, 0.5, a=0.01, r=0.1), tone(note(67), 0.12, "tri", 0.25, glide=-0.5)))
    write("reverse", mix(tone(note(64), 0.18, "tri", 0.3, glide=0.5), tone(note(71), 0.18, "tri", 0.3, glide=-0.4), offsets=[0, 0.12]))
    write("round_win", mix(*[tone(note(n), 0.35, "bell", 0.28, r=0.3) for n in (72, 76, 79, 84)], offsets=[0, 0.09, 0.18, 0.27]))
    win = [tone(note(n), 0.5 if i < 5 else 1.2, "bell", 0.26, r=0.4 if i < 5 else 1.0) for i, n in enumerate((67, 72, 76, 79, 84, 88))]
    write("match_win", mix(*win, tone(note(48), 1.6, "tri", 0.2, a=0.05, r=1.0), offsets=[0, 0.1, 0.2, 0.3, 0.42, 0.56, 0.56]))
    write("lose", mix(*[tone(note(n), 0.4, "tri", 0.25, r=0.3) for n in (72, 69, 65, 60)], offsets=[0, 0.16, 0.32, 0.48]))
    write("button", mix(tone(1400, 0.035, "sine", 0.3, d=0.015, s=0.2, r=0.015), noise(0.02, 0.15, lp=0.6)))
    write("hover", tone(2200, 0.025, "sine", 0.12, d=0.01, s=0.2, r=0.01))
    write("transition", sweep_noise(0.35, 0.02, 0.45, 0.35, a=0.12, r=0.15))
    write("join", mix(tone(note(76), 0.15, "bell", 0.25), tone(note(83), 0.2, "bell", 0.22), offsets=[0, 0.08]))
    write("leave", mix(tone(note(76), 0.15, "bell", 0.2), tone(note(69), 0.22, "bell", 0.2), offsets=[0, 0.1]))
    write("caught", mix(tone(note(84), 0.08, "square", 0.2), tone(note(84), 0.08, "square", 0.2), tone(140, 0.3, "saw", 0.2, glide=-0.3),
                        offsets=[0, 0.1, 0.18]))
    write("reward", mix(*[tone(note(n), 0.25, "bell", 0.25, r=0.2) for n in (79, 83, 86, 91)], offsets=[0, 0.07, 0.14, 0.21]))


# --- music ---------------------------------------------------------------------------

def pad_chord(notes, sec, vol=0.08):
    return mix(*[tone(note(n), sec, "tri", vol, a=0.6, d=0.3, s=0.8, r=0.8, vibrato=0.002) for n in notes]
               + [tone(note(n) * 1.004, sec, "sine", vol * 0.6, a=0.6, s=0.8, r=0.8) for n in notes])


def music(name, prog, bpm, bars_per_chord=1, beat=True, arp=True, loops=2):
    beat_s = 60.0 / bpm
    bar = beat_s * 4
    total = []
    for _ in range(loops):
        for chord in prog:
            dur = bar * bars_per_chord
            layer = [pad_chord(chord, dur + 0.6, 0.07)]
            offs = [0.0]
            if arp:
                pattern = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
                steps = int(dur / (beat_s / 2))
                for i in range(steps):
                    layer.append(tone(note(pattern[i % 4]), beat_s * 0.45, "bell", 0.06, a=0.005, d=0.08, s=0.2, r=0.12))
                    offs.append(i * beat_s / 2)
            if beat:
                for b in range(int(dur / beat_s)):
                    layer.append(tone(55, 0.18, "sine", 0.22, d=0.08, s=0.1, r=0.06, glide=-0.5))
                    offs.append(b * beat_s)
                    if b % 2 == 1:
                        layer.append(noise(0.06, 0.08, lp=0.9, hp=0.95, d=0.03, s=0.1, r=0.02))
                        offs.append(b * beat_s)
                    layer.append(noise(0.03, 0.035, lp=0.95, hp=0.97, d=0.01, s=0.1, r=0.01))
                    offs.append(b * beat_s + beat_s / 2)
            seg = mix(*layer, offsets=offs)[: int(dur * SR)]
            total.extend(seg)
    path = write(name, total, peak=0.6)
    if shutil.which("ffmpeg"):
        ogg = path[:-4] + ".ogg"
        r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "3", ogg])
        if r.returncode == 0:
            os.remove(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    # A minor-ish lounge progression for menus, brighter faster one for the table.
    music("music_menu", [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], bpm=92, beat=True)
    music("music_table", [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]], bpm=104, beat=True)
    print("audio written to", os.path.abspath(OUT))
