"""Texturas de fuego estilo anime para Roblox (flipbooks cel-shaded con erosión).

Genera PNG listos para subir con el Asset Manager de Studio. Las llamas tienen
bandas de color planas (núcleo crema -> amarillo -> naranja -> rojo) y contorno
oscuro fino; al final de su vida se ERODEN en jirones (no se desvanecen en una
neblina): eso es lo que hace que la explosión "cierre" limpio.

uso: python make_textures.py <outdir>
"""
import sys
import os
import math
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)

# Paleta de fuego (no blanco puro: el núcleo es crema para que el bloom no lo queme)
CORE = np.array([255, 244, 196])
YELLOW = np.array([255, 208, 58])
ORANGE = np.array([255, 140, 34])
RED = np.array([232, 74, 24])
DARK = np.array([104, 26, 12])


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


class Noise:
    """Ruido de gradiente 3D (Perlin) vectorizado en numpy."""
    G = np.array([[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1],
                  [1, 0, -1], [-1, 0, -1], [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]], float)

    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        p = rng.permutation(256)
        self.p = np.concatenate([p, p, p])

    def n3(self, x, y, z):
        z = np.full_like(x, float(z)) if np.isscalar(z) else z
        xi, yi, zi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
        xf, yf, zf = x - xi, y - yi, z - zi
        xi, yi, zi = xi & 255, yi & 255, zi & 255
        f = lambda t: t * t * t * (t * (t * 6 - 15) + 10)
        u, v, w = f(xf), f(yf), f(zf)
        p, G = self.p, self.G

        def g(ix, iy, iz, dx, dy, dz):
            h = p[p[p[ix] + iy] + iz] % 12
            gg = G[h]
            return gg[..., 0] * dx + gg[..., 1] * dy + gg[..., 2] * dz

        n000 = g(xi, yi, zi, xf, yf, zf)
        n100 = g(xi + 1, yi, zi, xf - 1, yf, zf)
        n010 = g(xi, yi + 1, zi, xf, yf - 1, zf)
        n110 = g(xi + 1, yi + 1, zi, xf - 1, yf - 1, zf)
        n001 = g(xi, yi, zi + 1, xf, yf, zf - 1)
        n101 = g(xi + 1, yi, zi + 1, xf - 1, yf, zf - 1)
        n011 = g(xi, yi + 1, zi + 1, xf, yf - 1, zf - 1)
        n111 = g(xi + 1, yi + 1, zi + 1, xf - 1, yf - 1, zf - 1)
        L = lambda a, b, t: a + (b - a) * t
        x00, x10 = L(n000, n100, u), L(n010, n110, u)
        x01, x11 = L(n001, n101, u), L(n011, n111, u)
        return L(L(x00, x10, v), L(x01, x11, v), w) * 1.4

    def fbm(self, x, y, z, octaves=4, lac=2.0, gain=0.5):
        tot = np.zeros_like(x)
        amp, f, norm = 1.0, 1.0, 0.0
        for o in range(octaves):
            tot += amp * self.n3(x * f, y * f, z * f + o * 7.31)
            norm += amp
            amp *= gain
            f *= lac
        return tot / norm


def grid(n):
    v = np.linspace(-1, 1, n)
    x, y = np.meshgrid(v, v)
    return x, -y  # y hacia arriba


def bands(I, cool=0.0):
    """Intensidad (0..1) -> color cel-shaded. `cool` (0..1) enfría la llama con el tiempo."""
    th = np.array([0.58, 0.38, 0.2, 0.07]) + cool * np.array([0.42, 0.22, 0.1, 0.02])
    col = np.zeros(I.shape + (3,))
    col[...] = DARK
    col[I > th[3]] = RED
    col[I > th[2]] = ORANGE
    col[I > th[1]] = YELLOW
    col[I > th[0]] = CORE
    return col


def to_rgba(col, alpha, ss):
    """Supersampling -> RGBA uint8 (alpha premultiplicado al reducir)."""
    a = alpha[..., None]
    img = np.concatenate([col * a, a * 255.0], axis=-1)
    h = img.shape[0] // ss
    img = img.reshape(h, ss, h, ss, 4).mean(axis=(1, 3))
    a = img[..., 3:4]
    rgb = np.where(a > 0.5, img[..., :3] / np.maximum(a, 1e-6) * 255.0, 0)
    return np.concatenate([np.clip(rgb, 0, 255), np.clip(a, 0, 255)], axis=-1).astype(np.uint8)


def sheet(frames, cols):
    n = frames[0].shape[0]
    rows = math.ceil(len(frames) / cols)
    out = np.zeros((rows * n, cols * n, 4), np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * n:(r + 1) * n, c * n:(c + 1) * n] = f
    return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------------------
# 1) BOLA DE FUEGO que revienta y se erosiona (explosión principal)
# ---------------------------------------------------------------------------
def puffs_field(x, y, t, seed, n_puffs=10, spread=0.3, r0=0.3, grow=0.45, drift=0.25, up=0.0,
                die=(0.55, 1.0), fade_len=0.4):
    """Campo 'coliflor': unión de bolas redondas que crecen, se separan y luego
    se ENCOGEN una por una (escalonado) hasta desaparecer, redondas."""
    rng = np.random.default_rng(seed)
    F = np.full(x.shape, -9.0)
    s = 0.55 + grow * (1 - (1 - t) ** 2.4)
    for k in range(n_puffs):
        if k == 0:
            cx, cy, r = 0.0, 0.0, r0 * 1.25
            td = die[1]
        else:
            a = 2 * np.pi * k / (n_puffs - 1) + rng.uniform(-0.3, 0.3)
            d = spread * rng.uniform(0.75, 1.15)
            cx, cy, r = np.cos(a) * d, np.sin(a) * d, r0 * rng.uniform(0.7, 1.0)
            td = rng.uniform(*die)
        cx *= (1 + drift * t)
        cy = cy * (1 + drift * t) + up * t
        m = 1 - smooth((t - (td - fade_len)) / fade_len)
        if m <= 0.01:
            continue
        f = 1 - np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (r * s * m)
        F = np.maximum(F, f)
    return F


def flame_shade(F, thr, det, x, y, t, rim=0.035):
    """Color cel-shaded con luz arriba-izquierda y contorno oscuro fino."""
    e = F - thr
    I = e / (1 - thr + 1e-6) * (1.35 - 0.55 * t) + 0.12 * (-x + y) + 0.1 * det
    col = bands(np.clip(I, 0, 1), cool=t ** 1.15)
    col[(e < rim) & (e > 0)] = DARK
    return col


def fire_burst(seed=1, frames=16, size=256, ss=2):
    N = Noise(seed)
    n = size * ss
    x, y = grid(n)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        z = t * 1.4
        wa = 0.05 + 0.1 * t
        wx = N.fbm(x * 1.6, y * 1.6, z + 11, 3) * wa
        wy = N.fbm(x * 1.6 + 5, y * 1.6, z + 23, 3) * wa
        X, Y = x + wx, y + wy
        F = puffs_field(X, Y, t, seed, n_puffs=10, spread=0.3, r0=0.3, grow=0.48, drift=0.28, up=0.06,
                        die=(0.5, 1.0), fade_len=0.42)
        det = N.fbm(X * 3.0, Y * 3.0 - t, z, 3)
        er = N.fbm(X * 4.2, Y * 4.2, z + 40, 3)
        Fe = F + er * (0.06 + 0.22 * t ** 1.3)
        thr = 0.01 + 0.25 * t ** 2
        alpha = smooth((Fe - thr) * 30)
        col = flame_shade(Fe, thr, det, X, Y, t)
        out.append(to_rgba(col, alpha, ss))
    return out


def flash_spikes(size=256, ss=2, seed=4, variants=4):
    """Destello inicial tipo 'POW': estrella irregular de picos (2x2 variantes)."""
    rng = np.random.default_rng(seed)
    frames = []
    for k in range(variants):
        n = size * ss
        x, y = grid(n)
        r = np.sqrt(x * x + y * y)
        th = np.arctan2(y, x)
        m = rng.integers(9, 14)
        angs = np.sort(rng.uniform(0, 2 * np.pi, m))
        R = np.zeros_like(x) + 0.32
        for a in angs:
            L = rng.uniform(0.55, 0.95)
            w = rng.uniform(0.07, 0.14)
            dth = np.angle(np.exp(1j * (th - a)))
            R = np.maximum(R, 0.32 + (L - 0.32) * np.clip(1 - np.abs(dth) / w, 0, 1) ** 1.6)
        e = R - r
        alpha = smooth(e / 0.012)
        col = np.zeros(x.shape + (3,))
        col[...] = ORANGE
        col[e > 0.04] = YELLOW
        col[e > 0.12] = CORE
        frames.append(to_rgba(col, alpha, ss))
    return sheet(frames, 2)


# ---------------------------------------------------------------------------
# 2) LENGUA DE FUEGO (apunta hacia arriba en la textura; usar VelocityParallel)
# ---------------------------------------------------------------------------
def fire_tongue(seed=2, frames=16, size=256, ss=2):
    N = Noise(seed)
    n = size * ss
    x, y = grid(n)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        z = t * 2.2
        yy = (y + 1) / 2                                  # 0 abajo .. 1 arriba
        width = 0.62 * (1 - yy) ** 0.85 + 0.04             # se afila hacia la punta
        wob = N.fbm(np.zeros_like(x) + 0.0, y * 1.8 - t * 3.0, z, 3) * 0.28 * yy
        shape = 1 - np.abs(x - wob) / np.maximum(width, 1e-3)
        det = N.fbm(x * 3.2, y * 2.2 - t * 4.0, z + 9, 4)
        base = smooth((yy - 0.02) * 6)                     # base redondeada
        top = 1 - smooth((yy - (0.98 - 0.25 * t)) * 8)
        D = shape * base * top + 0.3 * det
        thr = 0.08 + 0.8 * t ** 1.8
        alpha = smooth((D - thr) * 20)
        I = (D - thr) / (1 - thr + 1e-6) * (1.3 - 0.5 * yy - 0.3 * t) + 0.15 * det
        col = bands(np.clip(I, 0, 1), cool=t ** 1.3)
        out.append(to_rgba(col, alpha, ss))
    return out


# ---------------------------------------------------------------------------
# 3) HUMO toon (café oscuro con luz arriba-izquierda, se erosiona)
# ---------------------------------------------------------------------------
def smoke(seed=3, frames=16, size=256, ss=2):
    N = Noise(seed)
    n = size * ss
    x, y = grid(n)
    hi = np.array([150, 136, 126])
    mid = np.array([104, 92, 86])
    sh = np.array([66, 57, 53])
    rimc = np.array([40, 33, 31])
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        z = t * 1.1
        wa = 0.05 + 0.08 * t
        X = x + N.fbm(x * 1.4, y * 1.4, z + 3, 3) * wa
        Y = y + N.fbm(x * 1.4 + 7, y * 1.4, z + 5, 3) * wa
        F = puffs_field(X, Y, t, seed + 50, n_puffs=7, spread=0.3, r0=0.36, grow=0.4, drift=0.22, up=0.1,
                        die=(0.45, 1.0), fade_len=0.45)
        er = N.fbm(X * 2.4, Y * 2.4, z + 17, 2)
        Fe = F + er * 0.05
        thr = 0.02
        e = Fe - thr
        alpha = smooth(e * 26)
        L = e / (1 - thr + 1e-6) + 0.35 * (-X + Y) * 0.5
        col = np.zeros(x.shape + (3,))
        col[...] = sh
        col[L > 0.18] = mid
        col[L > 0.5] = hi
        col[(e < 0.03) & (e > 0)] = rimc
        out.append(to_rgba(col, alpha, ss))
    return out


# ---------------------------------------------------------------------------
# 4) Texturas simples (sin flipbook)
# ---------------------------------------------------------------------------
def star(size=256, ss=2):
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-6
    ax = np.abs(x) * np.abs(y)
    rays = np.exp(-(np.minimum(np.abs(x), np.abs(y)) / 0.035) ** 1.2) * np.clip(1 - r, 0, 1) ** 1.5
    core = np.exp(-(r / 0.16) ** 2)
    glow = np.exp(-(r / 0.42) ** 2) * 0.45
    a = np.clip(rays + core + glow, 0, 1)
    col = np.zeros(x.shape + (3,))
    col[...] = CORE
    col = col * 0 + CORE * (0.75 + 0.25 * core[..., None])
    return Image.fromarray(to_rgba(col, a, ss), "RGBA")


def streak(w=96, h=512, ss=2):
    W, H = w * ss, h * ss
    x = np.linspace(-1, 1, W)[None, :].repeat(H, 0)
    y = np.linspace(-1, 1, H)[:, None].repeat(W, 1)
    taper = np.clip(1 - np.abs(y), 0, 1) ** 0.6 * (1 - 0.35 * (y < 0))   # cabeza arriba más gruesa
    width = 0.08 + 0.55 * taper
    core = np.exp(-(x / (width * 0.45)) ** 2) * taper
    a = np.clip(core * 1.4, 0, 1)
    col = np.zeros(x.shape + (3,))
    col[...] = CORE
    img = np.concatenate([col * a[..., None], a[..., None] * 255], -1)
    img = img.reshape(h, ss, w, ss, 4).mean(axis=(1, 3))
    al = img[..., 3:4]
    rgb = np.where(al > 0.5, img[..., :3] / np.maximum(al, 1e-6) * 255, 0)
    return Image.fromarray(np.concatenate([rgb, al], -1).clip(0, 255).astype(np.uint8), "RGBA")


def ring(size=512, ss=2, width=0.07):
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    R = 0.86
    inner = smooth((r - (R - width)) / 0.012)
    outer = 1 - smooth((r - R) / 0.09)
    a = inner * outer
    a = np.clip(a * (0.65 + 0.35 * smooth((R - r) / width + 0.5)), 0, 1)
    col = np.zeros(x.shape + (3,))
    col[...] = np.array([255, 236, 190])
    return Image.fromarray(to_rgba(col, a, ss), "RGBA")


def wind_arcs(size=512, ss=2, seed=5):
    """Arcos de viento/smear (anime): 3 trazos finos concéntricos y cortados."""
    rng = np.random.default_rng(seed)
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    a = np.zeros_like(x)
    for k in range(4):
        R = 0.5 + 0.12 * k
        w = 0.012 + 0.008 * (3 - k)
        t0, t1 = rng.uniform(0.1, 0.6), rng.uniform(1.6, 2.6)
        seg = smooth((th - t0) / 0.25) * (1 - smooth((th - t1) / 0.4))
        taper = np.clip(np.sin(np.clip((th - t0) / (t1 - t0), 0, 1) * math.pi), 0, 1)
        a = np.maximum(a, np.exp(-((r - R) / w) ** 2) * seg * taper)
    col = np.zeros(x.shape + (3,))
    col[...] = np.array([255, 248, 230])
    return Image.fromarray(to_rgba(col, np.clip(a * 1.2, 0, 1), ss), "RGBA")


def ember(size=64, ss=2):
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    a = np.clip(np.exp(-(r / 0.35) ** 2) * 1.3, 0, 1)
    col = np.zeros(x.shape + (3,))
    col[...] = np.array([255, 214, 120])
    col = col * (1 - 0.3 * (r[..., None] > 0.3)) + np.array([255, 120, 40]) * 0.3 * (r[..., None] > 0.3)
    return Image.fromarray(to_rgba(col, a, ss), "RGBA")


def debris(size=128, ss=2, seed=9):
    """4 fragmentos de roca angulares (2x2, FlipbookMode Random)."""
    rng = np.random.default_rng(seed)
    frames = []
    for k in range(4):
        n = size * ss
        x, y = grid(n)
        m = rng.integers(5, 7)
        ang = np.sort(rng.uniform(0, 2 * np.pi, m))
        rad = rng.uniform(0.55, 0.9, m)
        P = np.stack([np.cos(ang) * rad, np.sin(ang) * rad], 1)
        inside = np.ones_like(x, bool)
        dist = np.full(x.shape, 9.0)
        for j in range(m):
            a, b = P[j], P[(j + 1) % m]
            ex, ey = b - a
            # lado interior (polígono antihorario)
            cross = ex * (y - a[1]) - ey * (x - a[0])
            inside &= cross > 0
            L = np.hypot(ex, ey)
            dist = np.minimum(dist, np.abs(cross) / L)
        col = np.zeros(x.shape + (3,))
        col[...] = np.array([66, 54, 48])
        col[(x * 0.6 - y * 0.8) < -0.05] = np.array([104, 88, 76])
        col[dist < 0.05] = np.array([28, 22, 20])
        a = inside.astype(float)
        frames.append(to_rgba(col, a, ss))
    return sheet(frames, 2)


def crack_patch(size=512, ss=2, seed=12):
    """Parche de grietas brillantes (independiente de la rotación: se solapan en línea)."""
    rng = np.random.default_rng(seed)
    N = Noise(seed)
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    glow = np.zeros_like(x)
    core = np.zeros_like(x)
    # grietas radiales quebradas + algunas ramas
    for k in range(7):
        a0 = rng.uniform(0, 2 * np.pi)
        L = rng.uniform(0.55, 0.95)
        wig = N.fbm(r * 4 + k * 3.1, np.zeros_like(r) + k, 0.5, 3) * 0.35
        dth = np.angle(np.exp(1j * (th - a0 - wig)))
        dist = np.abs(dth) * r
        w = 0.012 + 0.03 * (1 - r / L)
        m = (r < L)
        core = np.maximum(core, np.exp(-(dist / (w * 0.6)) ** 2) * m * (1 - r / L) ** 0.3)
        glow = np.maximum(glow, np.exp(-(dist / (w * 3.0)) ** 2) * m * (1 - r / L) ** 0.6)
    centre = np.exp(-(r / 0.18) ** 2)
    core = np.maximum(core, centre)
    glow = np.maximum(glow, np.exp(-(r / 0.35) ** 2) * 0.8)
    col = np.zeros(x.shape + (3,))
    col[...] = DARK
    col[glow > 0.35] = RED
    col[glow > 0.6] = ORANGE
    col[core > 0.45] = YELLOW
    col[core > 0.8] = CORE
    alpha = np.clip(np.maximum(np.where(glow > 0.35, glow, 0) * 1.1, core), 0, 1)
    return Image.fromarray(to_rgba(col, alpha, ss), "RGBA")


def scorch(size=512, ss=2, seed=13):
    """Mancha de quemado en el suelo (borde irregular, centro más oscuro)."""
    N = Noise(seed)
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    det = N.fbm(x * 2.5, y * 2.5, 0.3, 4)
    D = 1 - r / 0.8 + 0.3 * det
    a = smooth(D * 6) * 0.85
    col = np.zeros(x.shape + (3,))
    col[...] = np.array([70, 44, 30])
    col[D > 0.35] = np.array([48, 30, 22])
    col[D > 0.7] = np.array([34, 22, 18])
    return Image.fromarray(to_rgba(col, a, ss), "RGBA")


if __name__ == "__main__":
    jobs = {
        "kz_fire_burst_4x4.png": lambda: sheet(fire_burst(), 4),
        "kz_fire_tongue_4x4.png": lambda: sheet(fire_tongue(), 4),
        "kz_smoke_4x4.png": lambda: sheet(smoke(), 4),
        "kz_flash_2x2.png": flash_spikes,
        "kz_star.png": star,
        "kz_streak.png": streak,
        "kz_ring.png": ring,
        "kz_wind_arcs.png": wind_arcs,
        "kz_ember.png": ember,
        "kz_debris_2x2.png": debris,
        "kz_crack.png": crack_patch,
        "kz_scorch.png": scorch,
    }
    for name, fn in jobs.items():
        img = fn()
        img.save(os.path.join(OUT, name))
        print("OK", name, img.size)
