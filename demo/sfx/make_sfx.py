"""Synthesizes the demo videos' sound effects (no third-party audio): key clicks, the
'pick' chime when Space chooses a guess, Return, and a soft whoosh for scene changes."""
import numpy as np, wave, sys, os
SR = 48000
out = sys.argv[1] if len(sys.argv) > 1 else "."
rng = np.random.default_rng(7)

def save(name, x):
    x = np.clip(x / (np.abs(x).max() + 1e-9) * 0.9, -1, 1)
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def t(sec): return np.arange(int(SR * sec)) / SR

def bandnoise(n, lo, hi):
    f = np.fft.rfft(rng.standard_normal(n)); fr = np.fft.rfftfreq(n, 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(f, n)

def key(seed_shift, body=180):
    n = int(SR * 0.06); tt = t(0.06)
    click = bandnoise(n, 2500, 7000) * np.exp(-tt / 0.004)
    thock = np.sin(2 * np.pi * (body + seed_shift) * tt) * np.exp(-tt / 0.012) * 0.6
    return click + thock

for i, s in enumerate([0, 25, -20]):
    save(f"key{i+1}.wav", key(s))
save("return.wav", key(-60, body=120) * 1.0)

tt = t(0.35)
chime = (np.sin(2*np.pi*1318.5*tt) + 0.6*np.sin(2*np.pi*1975.5*tt) + 0.25*np.sin(2*np.pi*2637*tt))
chime *= np.exp(-tt / 0.09) * np.minimum(1, tt / 0.003)
save("pick.wav", chime)

tt = t(0.6); n = len(tt)
noise = bandnoise(n, 300, 6000)
env = np.sin(np.pi * tt / tt[-1]) ** 2
sweep = np.convolve(noise, np.ones(8) / 8, mode="same")
save("whoosh.wav", sweep * env * 0.5)
