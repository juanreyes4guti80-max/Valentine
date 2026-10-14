"""Sprite PROTAGONISTA de la explosión anime: UNA sola bola de fuego coherente
(cuerpo coliflor + corona de lenguas en garra + remolinos internos), animada en
dos flipbooks de 4x4: A = expansión, B = disolución en esquirlas.
Escala de grises (Roblox la tiñe). uso: python hero_texture.py <outdir> [preview.png]"""
import sys, os, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anime_textures import (Noise, grid, circ, crescent, smooth, ease_out, pack, sheet,
                            holes_field, BODY, SHADE, RIM, HI)

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"


def silhouette(x, y, te, td, seed):
    """SDF de la silueta completa en coordenadas normalizadas por la escala."""
    rng = np.random.default_rng(seed)
    sd = circ(x, y, 0.0, -0.08, 0.4)
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6) + rng.uniform(-0.15, 0.15)
        d = 0.3 + rng.uniform(-0.03, 0.03)
        sd = np.minimum(sd, circ(x, y, math.cos(a) * d * 1.1, math.sin(a) * d - 0.05, rng.uniform(0.17, 0.24)))
    for k in range(3):
        a = -math.pi * (0.25 + 0.5 * k / 2)
        sd = np.minimum(sd, circ(x, y, math.cos(a) * 0.3, math.sin(a) * 0.18 - 0.12, 0.2))
    grow = 0.6 + 0.4 * ease_out(te, 2)
    push = 0.06 * te + 0.22 * td
    for k in range(7):
        a = math.pi * (0.12 + 0.76 * k / 6) + rng.uniform(-0.08, 0.08)
        d = 0.48 + push + rng.uniform(-0.04, 0.04)
        r = rng.uniform(0.17, 0.27) * grow * (1.25 if abs(a - math.pi / 2) < 0.5 else 1.0)
        tilt = a + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
        sd = np.minimum(sd, crescent(x, y, math.cos(a) * d, math.sin(a) * d - 0.02, r, tilt, 0.55, 0.9))
    for sgn in (-1, 1):
        sd = np.minimum(sd, crescent(x, y, sgn * (0.52 + push), -0.3, 0.2 * grow,
                                     (0.0 if sgn > 0 else math.pi) + 0.6 * sgn, 0.6, 0.9))
    return sd


def hero_frame(t, N, seed, n=256, ss=2):
    N2 = n * ss
    px = 2.0 / N2
    X0, Y0 = grid(N2)
    te = min(t / 0.5, 1.0)
    td = max((t - 0.5) / 0.5, 0.0)
    s = 0.28 + 0.72 * ease_out(te, 2.4)
    w = 0.03 + 0.03 * t
    xw = X0 + N.fbm(X0 * 1.4 + 2, Y0 * 1.4, 2) * w
    yw = Y0 + N.fbm(X0 * 1.4, Y0 * 1.4 + 9, 2) * w

    def full(dx=0.0, dy=0.0):
        xs, ys = (xw + dx) / s, (yw + dy + 0.12) / s
        sd = silhouette(xs, ys, te, td, seed) * s
        if td > 0:
            H = holes_field(xw + dx, yw + dy, td, seed + 7, n=16, start=(0.0, 0.45), speed=(0.85, 1.35), area=0.85)
            sd = np.maximum(sd, -H) + 0.07 * smooth((td - 0.5) / 0.5)
        return sd
    sdf = full()
    sd2 = full(0.05, -0.05)
    # remolinos internos
    x, y = xw / s, (yw + 0.12) / s
    strokes = np.full(sdf.shape, 9.0)
    spin = 0.9 * t
    for k in range(5):
        a = k * 2 * math.pi / 5 + spin
        c = crescent(x, y, math.cos(a) * 0.16, math.sin(a) * 0.12 - 0.08, 0.2 + 0.03 * k, a + 1.8, 0.35, 0.95)
        strokes = np.minimum(strokes, np.abs(c))
    stroke = (strokes * s < 0.011 + 0.004 * te) & (sdf < -0.03)
    inside = smooth(0.5 - sdf / px)
    col = np.full(sdf.shape, BODY)
    col = np.where((sd2 > 0) & (sdf < 0), SHADE, col)
    col = np.where((sd2 < -0.12) & (sdf < -0.05), HI, col)
    col = np.where(stroke, SHADE - 18, col)
    col = np.where(sdf > -2.4 * px, RIM, col)
    halo_amt = 0.16 * (1 - td)
    halo = np.exp(-np.maximum(sdf, 0) / 0.03) * halo_amt * (sdf > 0)
    a = np.clip(inside + halo, 0, 1)
    c = np.where(inside > 0.02, col, 170.0)
    return pack(c, a, ss)


def build(seed=77, size=256):
    N = Noise(seed)
    frames = [hero_frame(i / 31, N, seed, n=size) for i in range(32)]
    return sheet(frames[:16]), sheet(frames[16:])


if __name__ == "__main__":
    a, b = build()
    a.save(os.path.join(OUT, "ka_hero_a_4x4.png"))
    b.save(os.path.join(OUT, "ka_hero_b_4x4.png"))
    print("OK ka_hero_a_4x4.png / ka_hero_b_4x4.png", a.size)
    if len(sys.argv) > 2:
        prev = Image.new("RGB", (2048, 1024))
        for i, im in enumerate((a, b)):
            bg = Image.new("RGBA", im.size, (90, 140, 200, 255))
            r, g, bb, al = im.split()
            tint = Image.merge("RGBA", (r, g.point(lambda v: int(v * 0.62)), bb.point(lambda v: int(v * 0.22)), al))
            bg.alpha_composite(tint)
            prev.paste(bg.convert("RGB"), (i * 1024, 0))
        prev.resize((1600, 800)).save(sys.argv[2])
