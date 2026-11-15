#!/usr/bin/env python3
"""Measures recorded thunder peals and writes how loud each band of frequencies is
every FRAME seconds: tools/sound/thunder_bands.gd (what tools/make_sounds.gd builds the
thunders from) and the whole peal's loudness every 0.1 s into
src/client/audio/thunder_shape.gd's ENVELOPES (what the phone's vibration follows).
Only these measurements go into the repository, not the recordings.

  python3 tools/sound/thunder_bands.py <file.wav>:<from s>:<to s>[:<stretch>] ...

Each argument is one variant: a mono 22050 Hz WAV, the seconds of its peal, and how
much slower to make it (1 as it is). Needs numpy.
"""
import sys
import wave

import numpy as np

RATE = 22050
FRAME = 0.05
BANDS = [(30, 60), (60, 120), (120, 250), (250, 500), (500, 1000), (1000, 2000), (2000, 4000)]


def read(path):
    w = wave.open(path)
    assert w.getframerate() == RATE and w.getnchannels() == 1, path
    return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768


def band(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / RATE)
    f[(fr < lo) | (fr >= hi)] = 0
    return np.fft.irfft(f, len(x))


def frames(x, seconds):
    n = int(seconds * RATE)
    return np.array([np.sqrt((x[i:i + n] ** 2).mean()) for i in range(0, len(x) - n + 1, n)])


def main():
    variants = []
    for arg in sys.argv[1:]:
        parts = arg.split(":")
        x = read(parts[0])[int(float(parts[1]) * RATE):int(float(parts[2]) * RATE)]
        stretch = float(parts[3]) if len(parts) > 3 else 1.0
        bands = np.array([frames(band(x, lo, hi), FRAME) for lo, hi in BANDS])
        whole = frames(x, 0.1)
        if stretch != 1.0:
            t = np.arange(0, bands.shape[1] * stretch) / stretch
            bands = np.array([np.interp(t, np.arange(bands.shape[1]), b) for b in bands])
            t = np.arange(0, len(whole) * stretch) / stretch
            whole = np.interp(t, np.arange(len(whole)), whole)
        variants.append((bands / bands.max(), whole / whole.max()))
    out = ["extends RefCounted",
           "## Made by tools/sound/thunder_bands.py from recorded thunder: for each variant, how",
           "## loud each band of BANDS (Hz) is every FRAME seconds (0..1). tools/make_sounds.gd",
           "## builds the thunders from it.",
           "",
           "const FRAME := %s" % FRAME,
           "const BANDS := %s" % [list(b) for b in BANDS],
           "const VARIANTS := ["]
    for bands, _whole in variants:
        out.append("\t[")
        for b in bands:
            out.append("\t\t[%s]," % ", ".join("%.3f" % v for v in b))
        out.append("\t],")
    out.append("]")
    open("tools/sound/thunder_bands.gd", "w").write("\n".join(out) + "\n")
    env = ["const ENVELOPES := ["]
    for _bands, whole in variants:
        env.append("\t[%s]," % ", ".join("%.2f" % v for v in whole))
    env.append("]")
    path = "src/client/audio/thunder_shape.gd"
    text = open(path).read()
    start = text.index("const ENVELOPES := [")
    end = text.index("\n]\n", start) + 3
    open(path, "w").write(text[:start] + "\n".join(env) + "\n" + text[end:])
    print("%d variants" % len(variants))


main()
