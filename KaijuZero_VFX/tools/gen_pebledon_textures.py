"""Texturas propias de PEBLEDON (kaiju de piedra con venas de energía turquesa y placas dorsales de cristal cian).
  pb_rock_2x2        cuatro rocas facetadas con venas turquesa que brillan (ya coloreada: se usa con Color blanco)
  pb_sonic_ring      onda de sonido: un anillo nítido con ondas detrás (blanco con alfa: el color lo pone la capa)
  pb_vein_cracks     grietas del suelo con venas de energía (blanco con alfa: oscuras = suelo roto, turquesa = venas)
  pb_breath_fire     Beam del aliento: fuego concentrado en vetas que corre a lo largo (se repite a lo largo del rayo)
  pb_buff_ring       el círculo de la mejora alrededor del cristal: un anillo nítido con marcas de cristal (Decal)
uso: python gen_pebledon_textures.py <carpeta textures de Pebledon>"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2   # supermuestreo
STONE = np.array([93, 85, 76], np.float32) / 255
STONE_HI = np.array([150, 140, 128], np.float32) / 255
VEIN = np.array([94, 229, 224], np.float32) / 255
VEIN_CORE = np.array([215, 255, 252], np.float32) / 255


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1     # -1..1, y hacia abajo


def save(rgb, alpha, path, size):
    rgb = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    al = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    if rgb.ndim == 2:
        rgb = np.stack([rgb] * 3, -1)
    Image.fromarray(np.dstack([rgb, al]), "RGBA").resize((size, size), Image.LANCZOS).save(path)


def noise(n, scale, seed):
    """Ruido suave (varias octavas de valores al azar interpolados)."""
    g = np.random.default_rng(seed)
    out = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(4):
        k = max(2, int(scale * 2 ** o))
        small = Image.fromarray((g.random((k, k)) * 255).astype(np.uint8))
        out += amp * np.asarray(small.resize((n, n), Image.BICUBIC), np.float32) / 255
        tot += amp
        amp *= 0.5
    return out / tot


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def jagged(g, p0, p1, steps, rough):
    """Polilínea quebrada de p0 a p1."""
    pts = [np.array(p0, float)]
    d = np.array(p1, float) - np.array(p0, float)
    nrm = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-6)
    for i in range(1, steps):
        u = i / steps
        pts.append(np.array(p0) + d * u + nrm * g.normal(0, rough))
    pts.append(np.array(p1, float))
    return [tuple(p) for p in pts]


# ----------------------------------------------------------------------------- rocas con venas
def rock(n, seed):
    """Una roca facetada (polígono irregular con caras de distinta luz), contorno oscuro y venas turquesa."""
    g = np.random.default_rng(seed)
    k = int(g.integers(7, 11))
    angs = np.sort(g.uniform(0, 2 * math.pi, k))
    rad = g.uniform(0.68, 0.92, k)
    pts = [(n / 2 + math.cos(a) * r * n * 0.52, n / 2 + math.sin(a) * r * n * 0.52 * g.uniform(0.8, 1.0))
           for a, r in zip(angs, rad)]
    peak = (n / 2 + g.uniform(-0.12, 0.12) * n, n / 2 + g.uniform(-0.12, 0.12) * n)
    shade = Image.new("F", (n, n), 0.0)
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    light = np.array([-0.55, -0.7, 0.45])
    light /= np.linalg.norm(light)
    d = ImageDraw.Draw(shade)
    for i in range(k):
        a, b = pts[i], pts[(i + 1) % k]
        nv = np.array([(a[0] + b[0]) / 2 - peak[0], (a[1] + b[1]) / 2 - peak[1], 0.0])
        nv[:2] /= (np.linalg.norm(nv[:2]) + 1e-6)
        nv[2] = g.uniform(0.5, 1.3)
        nv /= np.linalg.norm(nv)
        d.polygon([peak, a, b], fill=float(0.25 + 0.75 * max(0.0, nv @ light)))
    sh = np.asarray(shade, np.float32)
    m = np.asarray(mask, np.float32) / 255
    tex = noise(n, 6, seed) * 0.5 + noise(n, 22, seed + 7) * 0.5
    base = STONE[None, None] * (0.55 + 0.9 * sh[..., None]) * (0.75 + 0.5 * tex[..., None])
    base = base + (STONE_HI - STONE)[None, None] * np.clip(sh - 0.75, 0, 1)[..., None] * 1.5
    # venas: 2 o 3 grietas que cruzan la roca, con un núcleo casi blanco y un resplandor turquesa
    vimg = Image.new("L", (n, n), 0)
    vd = ImageDraw.Draw(vimg)
    for _ in range(int(g.integers(2, 4))):
        a0, a1 = g.uniform(0, 2 * math.pi), g.uniform(0, 2 * math.pi)
        p0 = (n / 2 + math.cos(a0) * n * 0.5, n / 2 + math.sin(a0) * n * 0.5)
        p1 = (n / 2 + math.cos(a1) * n * 0.12, n / 2 + math.sin(a1) * n * 0.12)
        line = jagged(g, p0, p1, 7, n * 0.025)
        vd.line(line, fill=255, width=max(2, n // 70))
        if g.random() < 0.7:     # una rama
            j = int(g.integers(2, 5))
            q = line[j]
            a2 = a0 + g.uniform(-1.2, 1.2) + math.pi / 2
            vd.line(jagged(g, q, (q[0] + math.cos(a2) * n * 0.22, q[1] + math.sin(a2) * n * 0.22), 4, n * 0.02),
                    fill=255, width=max(1, n // 110))
    v = np.asarray(vimg, np.float32) / 255
    inner = blur(m, n / 90) > 0.6
    v = v * inner
    glow = np.clip(blur(v, n / 40) * 2.2, 0, 1) * m
    core = np.clip(blur(v, n / 300) * 1.4, 0, 1)
    rgb = base * (1 - glow[..., None] * 0.85) + VEIN[None, None] * glow[..., None] * 0.95
    rgb = rgb * (1 - core[..., None]) + VEIN_CORE[None, None] * core[..., None]
    # contorno oscuro fino (ayuda a leer la roca de lejos)
    edge = np.clip(m - (blur(m, n / 120) > 0.92).astype(np.float32), 0, 1)
    rgb = rgb * (1 - 0.55 * edge[..., None])
    alpha = blur(m, 0.8)
    return np.clip(rgb, 0, 1), alpha


def atlas(tiles, n):
    rgb = np.zeros((2 * n, 2 * n, 3), np.float32)
    al = np.zeros((2 * n, 2 * n), np.float32)
    for i, (c, a) in enumerate(tiles):
        r, cc = divmod(i, 2)
        rgb[r * n:(r + 1) * n, cc * n:(cc + 1) * n] = c
        al[r * n:(r + 1) * n, cc * n:(cc + 1) * n] = a
    return rgb, al


# ----------------------------------------------------------------------------- onda de sonido
def sonic_ring(n):
    """Anillo nítido en el borde con dos ondas más débiles detrás y un velo suave por dentro; el borde ondula un
    poco (no es un círculo perfecto, se siente como aire empujado)."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    wob = 0.005 * np.sin(5 * th + 0.6) + 0.003 * np.sin(11 * th + 2.1) + 0.002 * np.sin(19 * th + 4.0)
    rr = r + wob
    def band(c, w):
        return np.exp(-((rr - c) / w) ** 2)
    a = 1.0 * band(0.90, 0.022) + 0.45 * band(0.80, 0.02) + 0.22 * band(0.70, 0.018)
    a += 0.18 * np.clip((rr - 0.45) / 0.45, 0, 1) ** 2 * (rr < 0.9)
    a += 0.35 * np.exp(-((rr - 0.91) / 0.06) ** 2)          # halo del borde
    a *= np.clip((0.985 - r) / 0.02, 0, 1)
    v = np.clip(0.75 + 0.25 * band(0.90, 0.03), 0, 1)
    return v, np.clip(a, 0, 1)


# ----------------------------------------------------------------------------- grietas con venas
def vein_cracks(n, seed=11):
    """Red de grietas que sale del centro y se ramifica (gruesas cerca del centro), con un resplandor suave."""
    g = np.random.default_rng(seed)
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)

    def branch(p, ang, length, width, depth):
        if depth == 0 or length < n * 0.03:
            return
        q = (p[0] + math.cos(ang) * length, p[1] + math.sin(ang) * length)
        pts = jagged(g, p, q, 6, length * 0.06)
        d.line(pts, fill=255, width=max(1, int(width)))
        for j in range(1, len(pts) - 1):
            if g.random() < 0.28:
                branch(pts[j], ang + g.choice([-1, 1]) * g.uniform(0.4, 1.0), length * g.uniform(0.35, 0.6),
                       width * 0.6, depth - 1)
        branch(q, ang + g.uniform(-0.45, 0.45), length * g.uniform(0.5, 0.7), width * 0.72, depth - 1)

    for k in range(7):
        a = 2 * math.pi * k / 7 + g.uniform(-0.3, 0.3)
        branch((n / 2, n / 2), a, n * g.uniform(0.15, 0.22), n / 70, 4)
    c = np.asarray(img, np.float32) / 255
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    fade = np.clip((1.0 - r) / 0.25, 0, 1)
    glow = np.clip(blur(c, n / 90) * 1.8, 0, 1)
    a = np.clip(np.maximum(c, glow * 0.55), 0, 1) * fade
    v = np.clip(0.55 + 0.45 * c, 0, 1)
    return v, a


# ----------------------------------------------------------------------------- fuego del aliento
def periodic_noise(W, H, a, b, beta, seed):
    """Ruido que se repite en los dos ejes (sale de un espectro al azar): a y b = cuántas vueltas de detalle a lo
    largo (U) y a lo ancho (V); con a < b las vetas quedan estiradas a lo largo."""
    g = np.random.default_rng(seed)
    fu = np.fft.fftfreq(W)[None, :] * W
    fv = np.fft.fftfreq(H)[:, None] * H
    amp = 1.0 / (1.0 + (fu / a) ** 2 + (fv / b) ** 2) ** beta
    amp[0, 0] = 0
    spec = amp * np.exp(2j * math.pi * g.random((H, W)))
    n = np.real(np.fft.ifft2(spec)).astype(np.float32)
    n -= n.min()
    return n / max(n.max(), 1e-6)


def breath_fire(w, h):
    """Fuego concentrado que corre a lo largo (Beam en Wrap): vetas estiradas, el centro denso y los bordes que se
    deshacen en lenguas; se repite en U (a lo largo del rayo)."""
    W, H = w * SS, h * SS
    v = (np.arange(H, dtype=np.float32)[:, None] + 0.5) / H * 2 - 1          # -1..1 a lo ancho
    streak = periodic_noise(W, H, 3.0, 14.0, 1.1, 41)                         # vetas a lo largo
    fine = periodic_noise(W, H, 8.0, 30.0, 1.0, 42)
    edge = periodic_noise(W, 8, 4.0, 2.0, 1.2, 43)[0][None, :]                 # el borde que ondula a lo largo
    hw = 0.36 + 0.24 * edge
    body = np.exp(-(v / hw) ** 2 * 1.8)
    dens = body * (0.3 + 0.9 * streak ** 1.4) * (0.8 + 0.4 * fine)
    tongues = np.clip((streak - 0.58) * 2.4, 0, 1) * np.exp(-(v / (hw + 0.22)) ** 2) * (1 - body) * 1.3
    core = np.exp(-(v / 0.15) ** 2)
    al = np.clip(dens * 1.2 + tongues + core * 0.5, 0, 1) * np.clip((1 - np.abs(v)) / 0.3, 0, 1)
    val = np.clip(0.72 + 0.28 * np.maximum(core, streak * body), 0, 1)
    rgb = np.repeat(val[..., None], 3, -1)
    im = Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), al[..., None] * 255]).astype(np.uint8), "RGBA")
    return im.resize((w, h), Image.LANCZOS)


# ----------------------------------------------------------------------------- el círculo de la mejora
def buff_ring(n):
    """Anillo nítido en el borde (r = 0.95) con un halo, una segunda línea fina por dentro, seis marcas de cristal
    (rombos) que apuntan hacia afuera y un velo muy suave hacia el centro."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    a = np.exp(-((r - 0.95) / 0.012) ** 2) + 0.5 * np.exp(-((r - 0.95) / 0.04) ** 2)
    a += 0.55 * np.exp(-((r - 0.86) / 0.006) ** 2)
    # seis rombos de cristal sobre el anillo (y seis chicos entre ellos)
    for k in range(12):
        ang = k * math.pi / 6
        big = k % 2 == 0
        L, W = (0.15, 0.05) if big else (0.07, 0.024)
        dth = np.angle(np.exp(1j * (th - ang)))
        u = (r - 0.905) / L                       # a lo largo (radial)
        v = dth * r / W                           # a lo ancho
        a = np.maximum(a, np.clip(1 - (np.abs(u) + np.abs(v)), 0, 1) ** 0.5 * (1.0 if big else 0.8))
    a += 0.16 * np.clip((r - 0.35) / 0.6, 0, 1) ** 2 * (r < 0.95)
    a *= np.clip((0.995 - r) / 0.02, 0, 1)
    v = np.clip(0.8 + 0.2 * np.exp(-((r - 0.95) / 0.02) ** 2), 0, 1)
    return v, np.clip(a, 0, 1)


def main(out):
    os.makedirs(out, exist_ok=True)
    n = 256 * SS
    rgb, al = atlas([rock(n, 30 + k) for k in range(4)], n)
    save(rgb, al, os.path.join(out, "pb_rock_2x2.png"), 512)
    v, a = sonic_ring(512 * SS)
    save(v, a, os.path.join(out, "pb_sonic_ring.png"), 512)
    v, a = vein_cracks(512 * SS)
    save(v, a, os.path.join(out, "pb_vein_cracks.png"), 512)
    breath_fire(512, 128).save(os.path.join(out, "pb_breath_fire.png"))
    v, a = buff_ring(1024 * SS)
    save(v, a, os.path.join(out, "pb_buff_ring.png"), 1024)
    print("OK texturas de Pebledon ->", out)


if __name__ == "__main__":
    main(sys.argv[1])
