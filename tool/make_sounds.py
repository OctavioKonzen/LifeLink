"""Gera os sons do contador de vida (sem arquivos de terceiros):
dano, cura, veneno, dano de comandante e morte.

Uso: python3 tool/make_sounds.py
Grava em assets/sounds/ (app) e web-site/public/sounds/ (site).
"""

import os
import wave

import numpy as np

RATE = 22050
rng = np.random.default_rng(7)  # sempre os mesmos sons


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(x, decay, attack=0.004):
    """Envelope: sobe rápido e cai exponencialmente."""
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / decay)


def lowpass(signal, cutoff):
    """Filtro passa-baixa simples de um polo."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.zeros_like(signal)
    acc = 0.0
    for i, s in enumerate(signal):
        acc += alpha * (s - acc)
        out[i] = acc
    return out


def highpass(signal, cutoff):
    """Filtro passa-alta simples (o sinal menos o passa-baixa)."""
    return signal - lowpass(signal, cutoff)


def sweep(x, f0, f1, duration):
    """Tom que vai de f0 a f1 (Hz) ao longo da duração (fase contínua)."""
    f = f0 * (f1 / f0) ** np.clip(x / duration, 0, 1)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def mix(length, *parts):
    out = np.zeros(int(RATE * length))
    for start, sig in parts:
        i = int(RATE * start)
        n = min(len(sig), len(out) - i)
        out[i : i + n] += sig[:n]
    return out


def damage():
    """Pancada seca e grave."""
    x = t(0.4)
    thump = sweep(x, 170, 50, 0.18) * env(x, 0.09)
    hit = lowpass(rng.uniform(-1, 1, len(x)), 1400) * env(x, 0.025) * 2.2
    return np.tanh((thump + hit) * 1.6)


def heal():
    """Brilho subindo: três sininhos em arpejo."""
    out = mix(0.9)
    for k, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0]):
        x = t(0.7)
        bell = (np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * f * 2.01 * x) + 0.15 * np.sin(2 * np.pi * f * 3.02 * x)) * env(x, 0.22, 0.006)
        out = out + mix(0.9, (k * 0.075, bell * (0.8 - k * 0.1)))
    shimmer = lowpass(rng.uniform(-1, 1, len(out)), 6000) * env(t(0.9), 0.3, 0.05) * 0.05
    return out + shimmer


def poison():
    """Cobra: o chocalho (estalos rápidos) e o chiado agudo do bote."""
    snake = np.random.default_rng(11)  # sorteio próprio: os outros sons não mudam
    length = 1.0
    x = t(length)
    # Chocalho: rajadas curtas de ruído agudo, umas 28 por segundo.
    rattle_env = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * x))) * np.clip(x / 0.03, 0, 1) * np.exp(-x / 0.45)
    rattle = highpass(snake.uniform(-1, 1, len(x)), 2500) * rattle_env * 0.55
    # Chiado ("ssss"): ruído bem agudo que cresce e some, depois do chocalho.
    hiss_x = t(0.75)
    hiss_env = np.clip(hiss_x / 0.08, 0, 1) * np.exp(-np.maximum(hiss_x - 0.2, 0) / 0.18)
    hiss = highpass(snake.uniform(-1, 1, len(hiss_x)), 5000) * hiss_env * 0.9
    return mix(length, (0, rattle), (0.18, hiss))


def commander():
    """Golpe metálico de espada com um baque por baixo."""
    x = t(0.9)
    partials = [(523, 0.30, 1.0), (1381, 0.22, 0.7), (2211, 0.15, 0.5), (3172, 0.09, 0.35), (4430, 0.06, 0.2)]
    clang = sum(a * np.sin(2 * np.pi * f * x) * env(x, d, 0.002) for f, d, a in partials)
    hit = rng.uniform(-1, 1, len(x)) * env(x, 0.012) * 0.9
    thump = sweep(x, 140, 60, 0.12) * env(x, 0.07) * 0.8
    return clang + hit + thump


def death():
    """Tom grave descendo, um sino baixo e um estrondo."""
    x = t(1.6)
    fall = lowpass(np.sign(sweep(x, 220, 48, 1.1)) * 0.6 + sweep(x, 220, 48, 1.1), 900) * env(x, 0.55, 0.02)
    toll = (np.sin(2 * np.pi * 110 * x) + 0.5 * np.sin(2 * np.pi * 276 * x) + 0.25 * np.sin(2 * np.pi * 461 * x)) * env(x, 0.7, 0.005) * 0.6
    boom = (sweep(x, 90, 30, 0.5) * env(x, 0.35) + lowpass(rng.uniform(-1, 1, len(x)), 300) * env(x, 0.2) * 1.5) * 0.9
    return np.tanh(fall * 0.9 + toll + boom)


def save(name, signal, folders):
    signal = signal / np.max(np.abs(signal)) * 0.85
    # Pequeno fade no fim para não estalar.
    fade = min(len(signal), int(RATE * 0.02))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (signal * 32767).astype("<i2").tobytes()
    for folder in folders:
        os.makedirs(folder, exist_ok=True)
        with wave.open(os.path.join(folder, f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    folders = [os.path.join(root, "assets", "sounds"), os.path.join(root, "web-site", "public", "sounds")]
    for name, make in [("dano", damage), ("cura", heal), ("veneno", poison), ("comandante", commander), ("morte", death)]:
        save(name, make(), folders)
        print("ok", name)
