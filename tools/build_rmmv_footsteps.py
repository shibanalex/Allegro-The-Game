#!/usr/bin/env python3
"""Generate a clean, light, subtly bitcrushed wooden floor footstep (44100 Hz 16-bit WAV)."""
import math
import wave
from pathlib import Path
import numpy as np

OUT_WAV = Path("/home/allegro/allegro-the-game/assets/audio/se/wood_step.wav")
SR = 44100


def biquad_filter(x: np.ndarray, b0: float, b1: float, b2: float, a0: float, a1: float, a2: float) -> np.ndarray:
    b0 /= a0; b1 /= a0; b2 /= a0
    a1 /= a0; a2 /= a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, x0 in enumerate(x):
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = y0
        x2, x1 = x1, x0
        y2, y1 = y1, y0
    return y


def biquad_bandpass(x: np.ndarray, fc: float, q: float) -> np.ndarray:
    w0 = 2.0 * math.pi * fc / SR
    alpha = math.sin(w0) / (2.0 * q)
    return biquad_filter(x, alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * math.cos(w0), 1.0 - alpha)


def biquad_lowpass(x: np.ndarray, fc: float, q: float = 0.707) -> np.ndarray:
    w0 = 2.0 * math.pi * fc / SR
    c = math.cos(w0)
    alpha = math.sin(w0) / (2.0 * q)
    return biquad_filter(x, (1 - c) / 2, 1 - c, (1 - c) / 2, 1 + alpha, -2 * c, 1 - alpha)


def build_wood_step() -> np.ndarray:
    rng = np.random.default_rng(771)
    # 0.22s total buffer: active crisp 45ms hit + clean zero tail (zero Vorbis pre-echo or clip)
    n = int(SR * 0.22)
    t = np.arange(n) / SR

    # Start with smooth pink-ish random excitation in time domain
    w = rng.normal(0.0, 1.0, n)
    # Warm up noise slightly
    exc = biquad_lowpass(w, 6000.0, 0.7)

    # Layer 1: Light hollow parquet board knock (~380 Hz, fast 11ms decay -> light, not boomy)
    body = biquad_bandpass(exc, 390.0, 1.35)
    body *= (1.0 - np.exp(-t / 0.0012)) * np.exp(-t / 0.011)

    # Layer 2: Soft wood tap (~920 Hz, very brief 6ms decay)
    tap = biquad_bandpass(exc * 0.8 + w * 0.2, 920.0, 1.6)
    tap *= (1.0 - np.exp(-t / 0.0008)) * np.exp(-t / 0.006)

    # Layer 3: Subtle dry sole touch 10ms later (~1650 Hz, tiny grain)
    t2 = np.maximum(0.0, t - 0.010)
    m2 = (t >= 0.010).astype(float)
    brush = biquad_bandpass(w, 1650.0, 1.8)
    brush *= m2 * (1.0 - np.exp(-t2 / 0.0010)) * np.exp(-t2 / 0.005)

    dry = 1.8 * body + 0.85 * tap + 0.28 * brush

    # Gentle retro bitcrush: 4x sample-hold (~11025 Hz) + 6.5-bit quantization, followed by smooth LPF @ 4.5 kHz
    peak0 = np.max(np.abs(dry)) or 1.0
    dry_n = dry / peak0

    hold = 4
    crushed = dry_n.copy()
    for i in range(0, len(crushed), hold):
        crushed[i:i + hold] = crushed[i]
    levels = 2.0 ** 5.5
    crushed = np.round(crushed * levels) / levels
    crushed = biquad_lowpass(crushed, 4400.0, 0.75)

    sig = 0.60 * crushed + 0.40 * dry_n

    # Clean fade-in (1.5ms) & smooth tail fade before silence
    fade_in = int(0.0015 * SR)
    sig[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    tail_mask = np.where(t < 0.08, 1.0, np.exp(-(t - 0.08) / 0.015))
    sig *= tail_mask
    sig[int(0.16 * SR):] = 0.0

    peak = np.max(np.abs(sig)) or 1.0
    sig = sig / peak * 0.45
    return np.clip(sig * 32767.0, -32767, 32767).astype(np.int16)


def main() -> None:
    OUT_WAV.parent.mkdir(parents=True, exist_ok=True)
    samples = build_wood_step()
    with wave.open(str(OUT_WAV), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(samples.tobytes())
    print("Generated", OUT_WAV, "frames=", len(samples))


if __name__ == "__main__":
    main()
