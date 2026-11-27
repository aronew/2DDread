"""Procedural placeholder SFX + music for DREAD.

    python3 tools/audio/gen_sfx.py

Writes 16-bit mono WAVs into assets/audio/. Every sound is shaped to match the
mechanical identity of its weapon/enemy. Replace any file with a recorded
asset of the same name to upgrade it — no code changes needed.
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env(dur, attack=0.002, decay=0.1, sustain=0.0, curve=1.0):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-5)) ** curve
    return a * (sustain + (1 - sustain) * d)


def sweep(f0, f1, dur, shape="sine", curve=1.0):
    t = t_axis(dur)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1


def band(x, lo=20.0, hi=20000.0, soft=0.25):
    """FFT band-limit with soft shoulders."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    lo_g = 1 / (1 + (lo / np.maximum(f, 1)) ** (2 / soft)) if lo > 20 else 1.0
    hi_g = 1 / (1 + (f / hi) ** (2 / soft)) if hi < 20000 else 1.0
    return np.fft.irfft(X * lo_g * hi_g, n)


def sat(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def delay(x, dt, amt):
    d = int(SR * dt)
    y = np.copy(x)
    y[d:] += x[:-d] * amt
    return y


def verb(x, amount=0.25, length=0.6):
    """Cheap diffuse tail: sum of decaying delays."""
    y = np.pad(x, (0, int(SR * length)))
    out = np.copy(y)
    for i, dt in enumerate([0.029, 0.037, 0.053, 0.071, 0.089, 0.113]):
        d = int(SR * dt)
        g = amount * (0.7 ** i)
        out[d:] += y[:-d] * g
    return band(out, 80, 9000)


def write(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def click(dur=0.012, lo=2000, hi=9000):
    return band(noise(dur), lo, hi) * env(dur, 0.0005, 0.003)


# ---------------------------------------------------------------- weapons

def rifle():
    d = 0.22
    body = band(noise(d), 300, 5000) * env(d, 0.001, 0.035)
    thump = sweep(160, 55, d, curve=0.4) * env(d, 0.001, 0.05) * 0.9
    zap = sweep(2600, 700, d, "saw", 0.5) * env(d, 0.0005, 0.018) * 0.35
    return verb(sat(mix(body, thump, zap), 2.5), 0.18, 0.25)


def shotgun():
    d = 0.7
    blast = band(noise(d), 80, 3500) * env(d, 0.001, 0.09)
    sub = sweep(95, 35, d, curve=0.35) * env(d, 0.002, 0.18) * 1.3
    crack = band(noise(d), 2500, 12000) * env(d, 0.0003, 0.012) * 0.7
    tail = band(noise(d), 100, 1200) * env(d, 0.02, 0.25) * 0.25
    pump = pad(np.zeros(int(SR * 0.42)), 0.42)
    pump = np.concatenate([pump, click(0.02, 800, 5000) * 0.5, np.zeros(int(SR * 0.06)), click(0.025, 600, 4000) * 0.6])
    return verb(sat(mix(blast, sub, crack, tail, pump * 0.6), 3.0), 0.22, 0.5)


def arc():
    d = 0.14
    t = t_axis(d)
    buzz = np.sign(np.sin(2 * np.pi * 95 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    crackle = band(noise(d), 2000, 9000) * (rng.uniform(0, 1, len(t)) > 0.92) * 2.0
    zap = sweep(3200, 1200, d, "saw") * env(d, 0.001, 0.03) * 0.4
    return sat(band(mix(buzz * 0.4, crackle, zap), 200, 9000) * env(d, 0.002, 0.07), 2.0)


def rail_charge():
    d = 0.65
    rise = sweep(220, 1700, d, "saw", 1.6) * 0.35 + sweep(440, 3400, d, "sine", 1.6) * 0.25
    whine = sweep(3000, 5200, d) * 0.08
    return band(mix(rise, whine), 150, 8000) * env(d, 0.25, 10.0)


def rail_fire():
    d = 1.1
    crack = band(noise(d), 3000, 16000) * env(d, 0.0002, 0.01) * 1.2
    zap = sweep(4200, 160, d, "saw", 0.35) * env(d, 0.001, 0.12) * 0.6
    boom = sweep(75, 30, d, curve=0.3) * env(d, 0.002, 0.25) * 1.3
    ring = sum(np.sin(2 * np.pi * f * t_axis(d)) * a for f, a in ((1870, 0.2), (2930, 0.14), (4410, 0.1))) * env(d, 0.001, 0.25)
    return verb(sat(mix(crack, zap, boom, ring), 2.5), 0.3, 0.8)


def launcher():
    d = 0.5
    thump = sweep(170, 45, d, curve=0.4) * env(d, 0.002, 0.08) * 1.2
    puff = band(noise(d), 120, 1800) * env(d, 0.002, 0.07)
    tube = sweep(600, 300, d) * env(d, 0.001, 0.04) * 0.3
    return verb(sat(mix(thump, puff, tube), 2.0), 0.2, 0.4)


def reload():
    return mix(click(0.02, 1500, 7000), pad(np.zeros(1), 0.11), np.concatenate([np.zeros(int(SR * 0.11)), band(noise(0.07), 1500, 6000) * env(0.07, 0.005, 0.03) * 0.5]))


def reload_done():
    d = 0.12
    clack = band(noise(d), 500, 5000) * env(d, 0.0005, 0.02)
    ping = np.sin(2 * np.pi * 1450 * t_axis(d)) * env(d, 0.0005, 0.03) * 0.3
    return mix(clack, ping)


def empty():
    return click(0.03, 2500, 8000)


def overheat():
    d = 0.9
    hiss = band(noise(d), 3000, 12000) * env(d, 0.01, 0.35)
    tone = sweep(900, 300, d) * env(d, 0.005, 0.2) * 0.4
    return mix(hiss, tone)


# ---------------------------------------------------------------- impacts / explosions

def impact_flesh():
    d = 0.14
    sq = band(noise(d), 150, 2200) * env(d, 0.001, 0.035)
    drop = sweep(260, 90, d) * env(d, 0.001, 0.04) * 0.6
    return sat(mix(sq, drop), 1.8)


def impact_metal():
    d = 0.16
    t = t_axis(d)
    ping = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((2150, 0.5), (3380, 0.35), (5170, 0.2))) * env(d, 0.0003, 0.035)
    return mix(ping, click(0.01, 3000, 12000))


def impact_armor():
    d = 0.3
    t = t_axis(d)
    clank = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((820, 0.5), (1310, 0.4), (2090, 0.3))) * env(d, 0.0005, 0.07)
    hit = band(noise(d), 400, 4000) * env(d, 0.0005, 0.02)
    return sat(mix(clank, hit), 1.5)


def explosion(big):
    d = 1.8 if big else 0.9
    body = band(noise(d), 40, 1400 if big else 2200) * env(d, 0.003, 0.45 if big else 0.22)
    sub = sweep(60 if big else 80, 24, d, curve=0.3) * env(d, 0.004, 0.5 if big else 0.25) * 1.5
    crack = band(noise(d), 1500, 9000) * env(d, 0.0005, 0.03) * 0.6
    debris = band(noise(d), 1200, 6000) * env(d, 0.15, 0.4) * (rng.uniform(0, 1, int(SR * d)) > 0.97) * 1.5
    return verb(sat(mix(body, sub, crack, debris * 0.5), 3.0 if big else 2.2), 0.3, 1.0 if big else 0.5)


# ---------------------------------------------------------------- enemies

def enemy_death():
    d = 0.45
    t = t_axis(d)
    screech = sweep(1100, 280, d, "saw", 0.6) * (1 + 0.3 * np.sin(2 * np.pi * 38 * t)) * env(d, 0.003, 0.12) * 0.4
    splat = band(noise(d), 100, 2000) * env(d, 0.001, 0.06)
    return sat(band(mix(screech, splat), 100, 7000), 2.0)


def enemy_death_big():
    d = 1.0
    t = t_axis(d)
    roar = mix(sweep(140, 55, d, "saw", 0.5), sweep(143, 57, d, "saw", 0.5)) * (1 + 0.4 * np.sin(2 * np.pi * 27 * t)) * env(d, 0.01, 0.35)
    gore = band(noise(d), 80, 1600) * env(d, 0.002, 0.12) * 1.2
    return verb(sat(band(mix(roar * 0.5, gore), 60, 4000), 2.5), 0.25, 0.6)


def mite_attack():
    d = 0.3
    t = t_axis(d)
    chit = np.sin(2 * np.pi * 1900 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 42 * t)))
    hiss = band(noise(d), 2500, 8000) * 0.4
    return band(mix(chit * 0.5, hiss), 800, 9000) * env(d, 0.01, 0.1)


def spitter_charge():
    d = 0.65
    t = t_axis(d)
    gurgle = band(noise(d), 150, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * t))
    rise = sweep(180, 520, d, "tri", 1.3) * 0.5
    return mix(gurgle, rise) * env(d, 0.15, 10.0)


def spitter_spit():
    d = 0.3
    burst = band(noise(d), 400, 2500) * env(d, 0.001, 0.05)
    drop = sweep(500, 140, d) * env(d, 0.001, 0.06) * 0.6
    return sat(mix(burst, drop), 2.0)


def acid_splash():
    d = 0.4
    return band(noise(d), 2500, 11000) * env(d, 0.002, 0.13) * (0.6 + 0.4 * (rng.uniform(0, 1, int(SR * d)) > 0.5))


def brute_roar():
    d = 1.2
    t = t_axis(d)
    base = mix(sweep(85, 70, d, "saw"), sweep(87, 71, d, "saw"), sweep(170, 140, d, "saw") * 0.5)
    growl = base * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    form = band(growl, 200, 1400) + band(noise(d), 300, 2000) * 0.2
    return verb(sat(form * env(d, 0.08, 0.5), 3.0), 0.3, 0.6)


def brute_slam():
    d = 1.2
    boom = sweep(70, 25, d, curve=0.3) * env(d, 0.002, 0.35) * 1.6
    crunch = band(noise(d), 200, 3000) * env(d, 0.001, 0.08)
    rattle = band(noise(d), 1000, 5000) * env(d, 0.05, 0.3) * (rng.uniform(0, 1, int(SR * d)) > 0.95) * 1.2
    return verb(sat(mix(boom, crunch, rattle * 0.5), 3.0), 0.25, 0.7)


def bloater_prime():
    d = 1.0
    t = t_axis(d)
    rate = 6 + 24 * (t / d) ** 2
    beep = (np.sin(2 * np.pi * np.cumsum(rate) / SR) > 0.3).astype(float)
    tone = sweep(620, 1400, d, "sine", 1.5)
    gurgle = band(noise(d), 100, 600) * 0.3
    return mix(tone * beep * 0.5, gurgle) * env(d, 0.02, 10.0)


def spawn():
    d = 0.5
    swell = band(noise(d), 300, 3000) * np.linspace(0, 1, int(SR * d)) ** 2
    hum = sweep(80, 160, d) * np.linspace(0, 1, int(SR * d)) * 0.5
    return mix(swell, hum) * np.concatenate([np.ones(int(SR * (d - 0.04))), np.linspace(1, 0, int(SR * 0.04))])


def elite_spawn():
    d = 1.6
    horn = mix(sweep(55, 52, d, "saw"), sweep(82.4, 78, d, "saw") * 0.7, sweep(110, 104, d, "saw") * 0.5)
    return verb(band(sat(horn * env(d, 0.15, 0.9), 2.0), 40, 2500), 0.4, 1.0)


def shield_break():
    d = 0.6
    t = t_axis(d)
    glass = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((3150, 0.3), (4470, 0.25), (5910, 0.2), (7300, 0.15))) * env(d, 0.0005, 0.12)
    burst = band(noise(d), 3000, 14000) * env(d, 0.0005, 0.05)
    return verb(mix(glass, burst), 0.3, 0.5)


# ---------------------------------------------------------------- player / abilities

def dash():
    d = 0.28
    t = t_axis(d)
    n = noise(d)
    lo = band(n, 300, 1200)
    hi = band(n, 1500, 6000)
    k = t / d
    return (lo * (1 - k) + hi * k) * np.sin(np.pi * k) ** 1.5


def nova():
    d = 1.3
    crack = band(noise(d), 2000, 14000) * env(d, 0.0005, 0.04) * 1.2
    boom = sweep(90, 30, d, curve=0.3) * env(d, 0.003, 0.35) * 1.4
    zap = sweep(2800, 300, d, "saw", 0.3) * env(d, 0.001, 0.15) * 0.5
    crackle = band(noise(d), 2500, 10000) * (rng.uniform(0, 1, int(SR * d)) > 0.96) * env(d, 0.05, 0.4) * 1.5
    return verb(sat(mix(crack, boom, zap, crackle), 2.5), 0.3, 0.8)


def seeker_launch():
    d = 0.25
    hiss = band(noise(d), 1500, 8000) * env(d, 0.003, 0.09)
    pop = sweep(700, 200, d) * env(d, 0.0005, 0.02) * 0.5
    return mix(hiss, pop)


def melee_swing():
    d = 0.2
    t = t_axis(d)
    k = t / d
    return band(noise(d), 400, 4000) * np.sin(np.pi * k) ** 2 * (0.5 + k)


def melee_hit():
    d = 0.35
    thud = sweep(150, 50, d, curve=0.4) * env(d, 0.001, 0.07) * 1.3
    crunch = band(noise(d), 300, 3500) * env(d, 0.0005, 0.04)
    return sat(mix(thud, crunch), 2.5)


def execute():
    d = 0.9
    thud = sweep(120, 35, d, curve=0.35) * env(d, 0.001, 0.15) * 1.5
    crunch = band(noise(d), 200, 4000) * env(d, 0.0005, 0.08)
    splat = band(noise(d), 80, 1200) * env(d, 0.02, 0.15) * 0.8
    shimmer = sweep(1200, 2400, d) * env(d, 0.05, 0.25) * 0.15
    return verb(sat(mix(thud, crunch, splat, shimmer), 3.0), 0.35, 0.7)


def whip_lash():
    """Leather whoosh that rises as the loop unrolls toward the tip."""
    d = 0.16
    t = t_axis(d)
    k = t / d
    air = band(noise(d), 600, 5000) * np.sin(np.pi * k) ** 1.5 * (0.3 + k)
    flutter = band(noise(d), 200, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * np.sin(np.pi * k) * 0.35
    return mix(air, flutter)


def whip_crack():
    """The tip breaking the sound barrier: a hard broadband snap with a short slap-back."""
    d = 0.3
    snap = band(noise(d), 1800, 16000) * env(d, 0.0002, 0.006) * 1.6
    body = band(noise(d), 500, 4000) * env(d, 0.0005, 0.025) * 0.7
    pop = sweep(2400, 600, d, curve=0.2) * env(d, 0.0002, 0.01) * 0.5
    x = sat(mix(snap, body, pop), 3.0)
    return verb(delay(x, 0.045, 0.25), 0.18, 0.25)


def whip_yank():
    """Rope going taut (creak) then the heavy tug."""
    d = 0.32
    creak = band(sweep(180, 90, d, "saw", curve=0.6), 150, 2500) * env(d, 0.002, 0.08) * 0.5
    thump = sweep(110, 45, d, curve=0.4) * env(d, 0.004, 0.09) * 1.2
    swish = band(noise(d), 400, 3000) * env(d, 0.01, 0.06) * 0.4
    return sat(mix(creak, thump, swish), 2.2)


def player_hurt():
    d = 0.3
    thump = sweep(180, 70, d) * env(d, 0.001, 0.06)
    grit = band(noise(d), 300, 2500) * env(d, 0.001, 0.05) * 0.7
    tink = np.sin(2 * np.pi * 2600 * t_axis(d)) * env(d, 0.0005, 0.03) * 0.2
    return sat(mix(thump, grit, tink), 2.0)


def shock_zap():
    d = 0.22
    return band(noise(d), 2000, 10000) * (rng.uniform(0, 1, int(SR * d)) > 0.85) * env(d, 0.002, 0.08) * 2.0


def tones(freqs, d, step=0.0, decay=0.3, wave="sine"):
    out = np.zeros(int(SR * (d + step * len(freqs))))
    for i, f in enumerate(freqs):
        s = sweep(f, f, d, wave) * env(d, 0.003, decay)
        o = int(SR * step * i)
        out[o:o + len(s)] += s
    return out


def pickup_item():
    return verb(tones([880, 1318.5, 1760], 0.35, 0.05, 0.15), 0.3, 0.5)


def pickup_orb():
    d = 0.18
    return sweep(560, 940, d) * env(d, 0.003, 0.06)


def xp_orb():
    d = 0.08
    return sweep(1900, 2300, d) * env(d, 0.001, 0.025)


def level_up():
    chord = tones([440, 554.4, 659.3, 880, 1108.7], 0.9, 0.06, 0.5, "tri")
    return verb(chord, 0.4, 1.2)


def legendary_drop():
    chord = tones([523.3, 659.3, 784, 1046.5, 1318.5], 1.4, 0.04, 0.7)
    shimmer = band(noise(2.0), 5000, 12000) * env(2.0, 0.05, 0.6) * 0.15
    return verb(mix(chord, shimmer), 0.5, 1.5)


def door_lock():
    d = 0.9
    thud = sweep(110, 40, d, curve=0.4) * env(d, 0.002, 0.15) * 1.3
    servo = sweep(900, 300, d, "saw") * env(d, 0.01, 0.2) * 0.2
    alarm = tones([880, 660, 880, 660], 0.12, 0.13, 0.08, "square") * 0.25
    return verb(mix(thud, servo, np.concatenate([np.zeros(int(SR * 0.15)), alarm])), 0.3, 0.6)


def door_open():
    d = 0.8
    servo = sweep(300, 900, d, "saw") * env(d, 0.05, 0.25) * 0.25
    hiss = band(noise(d), 2000, 9000) * env(d, 0.05, 0.3) * 0.5
    return verb(mix(servo, hiss), 0.25, 0.5)


def chest_open():
    d = 0.8
    creak = band(sweep(180, 260, d, "saw"), 200, 2000) * env(d, 0.05, 0.25) * 0.4
    return verb(mix(creak, tones([659.3, 987.8, 1318.5], 0.5, 0.08, 0.25)), 0.35, 0.8)


def crate_break():
    d = 0.4
    return sat(band(noise(d), 200, 5000) * env(d, 0.001, 0.07) * (0.6 + 0.4 * (rng.uniform(0, 1, int(SR * d)) > 0.7)), 2.0)


def wall_break():
    d = 1.6
    rumble = band(noise(d), 30, 600) * env(d, 0.01, 0.6) * 1.2
    debris = band(noise(d), 800, 5000) * env(d, 0.05, 0.5) * (rng.uniform(0, 1, int(SR * d)) > 0.93) * 1.5
    return verb(sat(mix(rumble, debris), 2.0), 0.3, 0.8)


def ui_click():
    return click(0.02, 1500, 6000)


# ---------------------------------------------------------------- music

def music_calm():
    d = 32.0
    t = t_axis(d)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / d * 2)
    drone = (np.sin(2 * np.pi * 55 * t) * 0.5 + np.sin(2 * np.pi * 82.41 * t) * 0.3 * lfo
             + np.sin(2 * np.pi * 110 * t) * 0.2 * (1 - lfo) + np.sin(2 * np.pi * 164.8 * t) * 0.08)
    wind = band(noise(d), 200, 900) * (0.3 + 0.2 * np.sin(2 * np.pi * t / d * 3)) * 0.35
    out = drone * 0.6 + wind
    for k, f in enumerate([440, 523.3, 392, 659.3, 440, 587.3]):
        start = 2.0 + k * 5.0
        s = sweep(f, f, 4.0, "sine") * env(4.0, 0.01, 1.2) * 0.12
        s += sweep(f * 2.01, f * 2.01, 4.0) * env(4.0, 0.01, 0.6) * 0.04
        o = int(SR * start)
        out[o:o + len(s)] += s[:len(out) - o]
    out = verb(out, 0.35, 1.5)[:len(t)]
    # seamless loop: crossfade tail into head
    xf = int(SR * 1.5)
    out[:xf] = out[:xf] * np.linspace(0, 1, xf) + out[-xf:] * np.linspace(1, 0, xf)
    return out[:len(t) - xf]


def music_combat():
    bpm = 132
    beat = 60.0 / bpm
    bars = 8
    d = bars * 4 * beat
    n = int(SR * d)
    out = np.zeros(n)

    def place(s, time, gain=1.0):
        o = int(SR * time)
        e = min(n, o + len(s))
        out[o:e] += s[:e - o] * gain

    kick = sat(sweep(140, 42, 0.35, curve=0.25) * env(0.35, 0.001, 0.12), 2.0)
    snare = band(noise(0.25), 200, 7000) * env(0.25, 0.001, 0.07) + sweep(220, 180, 0.25) * env(0.25, 0.001, 0.04) * 0.5
    hat = band(noise(0.06), 6000, 14000) * env(0.06, 0.0005, 0.015)
    notes = [55, 55, 65.4, 55, 49, 55, 73.4, 65.4]
    for b in range(bars):
        for q in range(4):
            tb = (b * 4 + q) * beat
            place(kick, tb, 1.0 if q in (0, 2) else 0.0)
            if q in (1, 3):
                place(snare, tb, 0.7)
            for e in range(2):
                place(hat, tb + e * beat / 2, 0.35 if e else 0.2)
            if b % 2 == 1 and q == 3:
                place(kick, tb + beat * 0.5, 0.7)
        root = notes[b]
        for s16 in range(16):
            if s16 % 4 == 0:
                continue
            f = root * (2 if s16 % 8 == 6 else 1)
            bs = band(sweep(f, f, beat / 4, "saw"), 40, 900) * env(beat / 4, 0.002, 0.06)
            place(sat(bs, 2.5), (b * 4) * beat + s16 * beat / 4, 0.45)
        padn = sweep(root * 4, root * 4, 4 * beat, "saw") * 0.06 + sweep(root * 6, root * 6, 4 * beat, "saw") * 0.04
        place(band(padn, 200, 2000) * env(4 * beat, 0.3, 2.0, 0.6), b * 4 * beat)
    return sat(out, 1.4)


SOUNDS = {
    "rifle_fire": rifle, "shotgun_fire": shotgun, "arc_fire": arc, "rail_charge": rail_charge,
    "rail_fire": rail_fire, "launcher_fire": launcher, "reload": reload, "reload_done": reload_done,
    "empty": empty, "overheat": overheat, "impact_flesh": impact_flesh, "impact_metal": impact_metal,
    "impact_armor": impact_armor, "explosion_small": lambda: explosion(False), "explosion_big": lambda: explosion(True),
    "enemy_death": enemy_death, "enemy_death_big": enemy_death_big, "mite_attack": mite_attack,
    "spitter_charge": spitter_charge, "spitter_spit": spitter_spit, "acid_splash": acid_splash,
    "brute_roar": brute_roar, "brute_slam": brute_slam, "bloater_prime": bloater_prime, "dash": dash,
    "nova": nova, "seeker_launch": seeker_launch, "melee_swing": melee_swing, "melee_hit": melee_hit,
    "execute": execute, "pickup_item": pickup_item, "pickup_orb": pickup_orb, "xp_orb": xp_orb,
    "level_up": level_up, "door_lock": door_lock, "door_open": door_open, "chest_open": chest_open,
    "crate_break": crate_break, "wall_break": wall_break, "player_hurt": player_hurt, "shock_zap": shock_zap,
    "spawn": spawn, "legendary_drop": legendary_drop, "ui_click": ui_click, "elite_spawn": elite_spawn,
    "shield_break": shield_break, "whip_lash": whip_lash, "whip_crack": whip_crack, "whip_yank": whip_yank,
}

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    if only:  # regenerate just the named sounds, leaving every other file untouched
        for name in only:
            write(name, SOUNDS[name]())
        print("wrote", only)
        sys.exit(0)
    for name, fn in SOUNDS.items():
        write(name, fn())
    write("music_calm", music_calm(), 0.7)
    write("music_combat", music_combat(), 0.75)
    print("wrote", len(SOUNDS) + 2, "files to", os.path.abspath(OUT))
