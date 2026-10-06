"""Renders the Phase 3 pilot track: media/common/music/menu.ogg.

A calm, seamless 32-second loop (soft pad chords + a slow plucked
arpeggio), synthesized here from scratch -- own work, no samples, so its
CREDITS.json entry is "own-work". It exists to prove the media-common pack
pipeline end to end; the owner's licensed tracks replace it later (same
file name = no code change).

    python tools/music/make_pilot.py        # needs numpy + ffmpeg (libvorbis)

Loudness follows STANDARDS §10: measured with ffmpeg's loudnorm, then one
plain gain to -16 LUFS (a static gain keeps the loop seam intact), encoded
OGG Vorbis ~96 kbps stereo. Every note is written with wrap-around, so the
pad and arpeggio tails at the end continue into the start: the loop has no
click and no gap. The import file sets loop = true (offset 0).
"""

import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "media/common/music/menu.ogg"
RATE = 44100
BEAT = 60.0 / 60.0          # 60 BPM
BAR = 4 * BEAT
CHORDS = [                  # Am9, Fmaj7, Cmaj7, G6 -- two bars each
    [57, 60, 64, 67, 71],
    [53, 57, 60, 64, 69],
    [48, 55, 59, 64, 67],
    [55, 59, 62, 64, 71],
]
LENGTH = len(CHORDS) * 2 * BAR          # 32 s
N = int(LENGTH * RATE)
TARGET_LUFS = -16.0


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(buf: np.ndarray, start: float, sig: np.ndarray, pan: float) -> None:
    """Adds a mono note at `start` seconds, wrapping past the end."""
    i0 = int(start * RATE) % N
    idx = (np.arange(sig.size) + i0) % N
    left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    np.add.at(buf[0], idx, sig * left)
    np.add.at(buf[1], idx, sig * right)


def pad(midi: int, dur: float) -> np.ndarray:
    t = np.arange(int((dur + 3.0) * RATE)) / RATE
    f = hz(midi)
    s = sum(np.sin(2 * np.pi * f * d * t + d) for d in (0.997, 1.0, 1.003))
    s += 0.25 * np.sin(2 * np.pi * 2 * f * t)
    attack = np.clip(t / 1.5, 0, 1)
    release = np.clip(1 - (t - dur) / 3.0, 0, 1)
    return s * attack * release * 0.05


def pluck(midi: int) -> np.ndarray:
    t = np.arange(int(2.5 * RATE)) / RATE
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6)
    return s * np.exp(-t * 2.2) * np.clip(t / 0.01, 0, 1) * 0.09


def render() -> np.ndarray:
    buf = np.zeros((2, N))
    for c, chord in enumerate(CHORDS):
        t0 = c * 2 * BAR
        for k, note in enumerate(chord):
            add(buf, t0, pad(note - 12 if k == 0 else note, 2 * BAR), pan=-0.4 + 0.2 * k)
        # arpeggio: up through the chord an octave higher, eighth notes
        pattern = chord[1:] + chord[1:][::-1]
        for step in range(16):
            note = pattern[step % len(pattern)] + 12
            add(buf, t0 + step * BEAT / 2, pluck(note), pan=0.5 if step % 2 else -0.5)
    # a gentle "room": two short wrapped echoes
    for delay, gain in ((0.37, 0.25), (0.71, 0.12)):
        d = int(delay * RATE)
        buf += gain * np.roll(buf[::-1], d, axis=1)  # ping-pong: each echo crosses sides
    return buf / max(1e-9, np.abs(buf).max()) * 0.5


def write_wav(path: Path, buf: np.ndarray) -> None:
    pcm = (np.clip(buf.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def measure_lufs(path: Path) -> float:
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
                          "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(json.loads(re.search(r"\{[^{}]*\}", out, re.S).group(0))["input_i"])


def main() -> int:
    buf = render()
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "raw.wav"
        write_wav(raw, buf)
        gain = 10 ** ((TARGET_LUFS - measure_lufs(raw)) / 20)
        peak = np.abs(buf).max() * gain
        if peak > 0.97:
            gain *= 0.97 / peak  # never clip; slightly under target is fine
        final = Path(tmp) / "final.wav"
        write_wav(final, buf * gain)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(final),
                        "-c:a", "libvorbis", "-b:a", "96k", str(OUT)], check=True)
        print(f"{OUT.relative_to(ROOT)}: {OUT.stat().st_size:,} bytes, "
              f"{LENGTH:.0f} s, {measure_lufs(final):.1f} LUFS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
