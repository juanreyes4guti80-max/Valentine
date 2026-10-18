"""Texturas propias del RAYO definitivo de Kaiju Zero (escala de grises + alfa: el color lo pone cada capa).
  kz_beam_core      núcleo del rayo: franja blanca estrecha (se repite a lo largo y corre)
  kz_beam_flow      la energía que envuelve el rayo: vetas de lava y fuego estiradas, bordes deshilachados
                    (se repite a lo largo: el Beam la hace correr hacia el impacto)
  kz_beam_glow      resplandor suave y ancho alrededor del rayo
  kz_beam_ring      anillo fino doble con cortes (los aros que rodean el rayo)
  kz_lava_rock_2x2  trozos de roca de lava con grietas encendidas (escombros que salen volando)
Las franjas del rayo van a lo largo del eje X (así las dibuja un Beam de Roblox: de Attachment0 a Attachment1).
uso: python -I gen_beam_textures.py <outdir>"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_lava_textures import fbm, save


def noise(rng, h, w, sy, sx):
    """Ruido suave periódico (se repite en los dos ejes) normalizado a 0..1."""
    f = gaussian_filter(rng.normal(0, 1, (h, w)), (sy, sx), mode="wrap")
    return (f - f.min()) / (f.max() - f.min() + 1e-9)


def core(dst, w=512, h=128, seed=3):
    rng = np.random.default_rng(seed)
    y = (np.arange(h) + 0.5) / h - 0.5
    flick = 0.82 + 0.18 * noise(rng, 1, w, 0.1, 18)[0]          # parpadeo a lo largo (al correr)
    a = np.exp(-(y[:, None] / 0.12) ** 2) * flick[None, :]
    g = np.clip(0.9 + 0.1 * flick[None, :] + 0 * a, 0, 1)
    save(np.broadcast_to(g, (h, w)), a, dst)


def warp(img, wx, wy):
    """Muestrea img en coordenadas desplazadas (periódico): remolinos en vez de rayas rectas."""
    h, w = img.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return map_coordinates(img, [yy + wy, xx + wx], order=1, mode="grid-wrap")


def flow(dst, w=512, h=256, seed=8):
    """Energía turbulenta que envuelve el rayo: corrientes con remolinos, vetas de lava encendidas que se
    ramifican y lenguas de fuego en los bordes (el borde sube y baja a lo largo del rayo)."""
    rng = np.random.default_rng(seed)
    y = (np.arange(h) + 0.5) / h
    e = np.abs(y - 0.5)[:, None] * 2                             # 0 en el eje .. 1 en el borde
    wx = (noise(rng, h, w, 16, 34) - 0.5) * 70                   # desplazamientos suaves (remolinos)
    wy = (noise(rng, h, w, 12, 26) - 0.5) * 34
    streams = warp(noise(rng, h, w, 4, 26), wx, wy)              # corrientes estiradas a lo largo
    big = noise(rng, h, w, 24, 80)                               # pulsos grandes a lo largo del rayo
    ridge = 1 - np.abs(2 * warp(noise(rng, h, w, 3.0, 20), wx * 0.6, wy * 0.6) - 1)
    ridge2 = 1 - np.abs(2 * warp(noise(rng, h, w, 1.6, 10), wx, wy) - 1)
    veins = np.clip((ridge - 0.88) / 0.12, 0, 1) ** 1.4 + 0.55 * np.clip((ridge2 - 0.9) / 0.1, 0, 1) ** 1.6
    veins = np.clip(veins, 0, 1)
    thr = 0.66 + 0.28 * (big - 0.5) + 0.26 * (streams - 0.5)      # lenguas de fuego en el borde
    a = np.clip((thr - e) / 0.24, 0, 1) * (0.5 + 0.5 * streams)
    a = np.maximum(a, veins * np.clip((0.95 - e) / 0.3, 0, 1))
    g = 0.22 + 0.5 * streams + 0.75 * veins + 0.3 * np.exp(-(e / 0.2) ** 2)
    save(np.clip(g, 0, 1), np.clip(a, 0, 1), dst)


def glow(dst, w=256, h=128):
    y = (np.arange(h) + 0.5) / h - 0.5
    a = np.exp(-(y / 0.26) ** 2) * 0.95
    save(np.ones((h, w)), np.broadcast_to(a[:, None], (h, w)), dst)


def ring(dst, n=512, seed=12):
    """Dos aros finos concéntricos con cortes (arcos) y un brillo suave alrededor."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:n, 0:n]
    x, y = (xx + 0.5) / n - 0.5, (yy + 0.5) / n - 0.5
    r, ang = np.hypot(x, y), np.arctan2(y, x)

    def arcs(k):
        m = np.ones_like(ang)
        for _ in range(k):                                       # cortes al azar
            c, wdt = rng.uniform(-np.pi, np.pi), rng.uniform(0.25, 0.7)
            d = np.abs((ang - c + np.pi) % (2 * np.pi) - np.pi)
            m *= np.clip((d - wdt / 2) / 0.08, 0, 1)
        return m

    l1 = np.clip(1 - np.abs(r - 0.44) / 0.006, 0, 1) * arcs(3)
    l2 = np.clip(1 - np.abs(r - 0.405) / 0.0035, 0, 1) * arcs(4) * 0.8
    lines = np.maximum(l1, l2)
    glow_ = gaussian_filter(lines, 6)
    a = np.clip(lines + 1.6 * glow_, 0, 1)
    save(np.clip(0.75 + 0.25 * lines, 0, 1), a, dst)


def rock_2x2(dst, cell=256, seed=17):
    """Trozos de ROCA DE LAVA (4 formas): silueta angulosa, costra oscura y grietas encendidas entre placas.
    Con LightEmission bajo y Brightness > 1 la costra queda oscura y solo brillan las grietas."""
    out_g = np.zeros((cell * 2, cell * 2))
    out_a = np.zeros((cell * 2, cell * 2))
    yy, xx = np.mgrid[0:cell, 0:cell].astype(np.float32)
    for k in range(4):
        rng = np.random.default_rng(seed + 31 * k)
        S = cell * 4
        nv = int(rng.integers(6, 9))
        angs = (np.arange(nv) + rng.uniform(-0.3, 0.3, nv)) * 2 * np.pi / nv + rng.uniform(0, 6.28)
        rads = rng.uniform(0.34, 0.46, nv) * S
        img = Image.new("L", (S, S), 0)
        V = [(S / 2 + np.cos(a) * r, S / 2 + np.sin(a) * r) for a, r in zip(angs, rads)]
        pts = []
        for i in range(nv):                              # lados rectos que se quiebran con muescas
            (x0, y0), (x1, y1) = V[i], V[(i + 1) % nv]
            nx, ny = y1 - y0, -(x1 - x0)                 # normal del lado (hacia afuera o adentro: da igual)
            for j in range(4):
                f = j / 4
                jit = rng.uniform(-0.06, 0.04) if j else 0.0
                pts.append((x0 + (x1 - x0) * f + nx * jit, y0 + (y1 - y0) * f + ny * jit))
        ImageDraw.Draw(img).polygon(pts, fill=255)
        alpha = np.asarray(img.resize((cell, cell), Image.LANCZOS), np.float32) / 255
        # grietas = bordes de celdas de Voronoi con las coordenadas deformadas (líneas quebradas)
        wx = xx + 34 * (fbm(rng, cell, octaves=4, base=4.0) - 0.5)
        wy = yy + 34 * (fbm(rng, cell, octaves=4, base=4.0) - 0.5)
        seeds = rng.uniform(0.1, 0.9, (7 + k, 2)) * cell
        d = np.sqrt((wx[..., None] - seeds[:, 0]) ** 2 + (wy[..., None] - seeds[:, 1]) ** 2)
        d.sort(axis=-1)
        width = (7.0, 6.0, 4.5, 3.6)[k]                  # las dos primeras más calientes (grietas anchas)
        crack = np.clip(1 - (d[..., 1] - d[..., 0]) / width, 0, 1) ** 1.4
        glow = gaussian_filter(crack, 4)
        cf = fbm(rng, cell, octaves=4, base=6.0)
        crust = 0.07 + 0.13 * cf + 0.25 * np.clip((cf - 0.84) / 0.14, 0, 1)   # costra con zonas aún calientes
        crack *= 0.6 + 0.4 * fbm(rng, cell, octaves=3, base=5.0)                # grietas que se abren y se cierran
        g = np.clip(crust + 0.95 * crack + 0.55 * glow, 0, 1)
        # canto inferior algo más caliente (la roca sale del magma) y un poco de relieve arriba
        g = np.clip(g + 0.12 * np.clip((yy / cell - 0.55) * 2.5, 0, 1) * glow, 0, 1)
        r0, c0 = (k // 2) * cell, (k % 2) * cell
        out_g[r0:r0 + cell, c0:c0 + cell] = g
        out_a[r0:r0 + cell, c0:c0 + cell] = alpha
    save(out_g, out_a, dst)


def main(out):
    os.makedirs(out, exist_ok=True)
    core(os.path.join(out, "kz_beam_core.png"))
    flow(os.path.join(out, "kz_beam_flow.png"))
    glow(os.path.join(out, "kz_beam_glow.png"))
    ring(os.path.join(out, "kz_beam_ring.png"))
    rock_2x2(os.path.join(out, "kz_lava_rock_2x2.png"))
    print("OK kz_beam_core, kz_beam_flow, kz_beam_glow, kz_beam_ring, kz_lava_rock_2x2")


if __name__ == "__main__":
    main(sys.argv[1])
