#!/usr/bin/env python3
"""Writes assets/sounds/tone.wav: the soft chime between items in Listen mode.

Run:  python3 tool/make_tone.py

Generated rather than downloaded so it's ours to ship and easy to tweak:
a bell-like A5 with a fifth above it, a 6 ms fade-in so it doesn't click,
and an exponential decay so it rings out instead of stopping. Quiet on
purpose — it marks the gap between words, it isn't an alarm.
"""
import math
import os
import struct
import wave

RATE = 44100
LENGTH = 0.45   # seconds
VOLUME = 0.32
PARTIALS = [(880.0, 1.0), (1320.0, 0.35), (1760.0, 0.12)]  # A5, E6, A6

out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "sounds", "tone.wav")
frames = bytearray()
n = int(RATE * LENGTH)
for i in range(n):
    t = i / RATE
    attack = min(1.0, t / 0.006)
    decay = math.exp(-t * 7.5)
    v = sum(a * math.sin(2 * math.pi * f * t) for f, a in PARTIALS)
    v *= attack * decay * VOLUME / sum(a for _, a in PARTIALS)
    frames += struct.pack("<h", int(max(-1, min(1, v)) * 32767))
os.makedirs(os.path.dirname(out), exist_ok=True)
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(bytes(frames))
print(f"wrote {out} ({len(frames) // 1024} KB)")
