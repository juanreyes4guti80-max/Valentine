"""Texturas del RAYO CÓSMICO de Omnívora (franjas a lo largo del eje X, como las dibuja un Beam de Roblox).
  om_beam_nebula  el cuerpo: nebulosa de azul muy oscuro con venas celestes, manchas púrpura y estrellas, que se
                  aclara hacia los bordes (como el pilar). Trae su propio color. Se repite a lo largo.
  om_beam_flow    hebras de energía onduladas que corren a lo largo del rayo (escala de grises: el color lo pone
                  cada capa)
  om_beam_stars   polvo de estrellas dentro del rayo (escala de grises)
  om_beam_core    el núcleo blanco (escala de grises)
  om_beam_glow    el resplandor ancho (escala de grises)
uso: python -I gen_cosmic_beam_textures.py <outdir>"""
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_lava_textures import save
from gen_beam_textures import noise, warp, core, glow

NAVY, BLUE, CELESTE = np.array([10, 20, 70]), np.array([40, 90, 220]), np.array([110, 185, 255])
PURPLE, WHITE = np.array([150, 60, 230]), np.array([240, 248, 255])


def save_rgba(col, alpha, dst):
    img = np.concatenate([np.clip(col, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(dst)


def mix(base, color, k):
    return base * (1 - k[..., None]) + (color / 255.0)[None, None] * k[..., None]


def stars_field(rng, h, w, density, sigma=0.6, gain=6.0):
    """Estrellitas al azar (se repiten a lo largo: el difuminado es periódico)."""
    pts = (rng.random((h, w)) > 1 - density).astype(float)
    return np.clip(gaussian_filter(pts, sigma, mode="wrap") * gain, 0, 1)


def nebula(dst, w=512, h=256, seed=4):
    rng = np.random.default_rng(seed)
    y = (np.arange(h) + 0.5) / h
    e = np.abs(y - 0.5)[:, None] * 2                             # 0 en el eje .. 1 en el borde
    wx = (noise(rng, h, w, 18, 40) - 0.5) * 80                   # remolinos
    wy = (noise(rng, h, w, 14, 30) - 0.5) * 30
    cloud = warp(noise(rng, h, w, 8, 34), wx, wy)                # nubes grandes
    detail = warp(noise(rng, h, w, 3, 12), wx * 0.5, wy * 0.5)
    ridge = 1 - np.abs(2 * warp(noise(rng, h, w, 2.5, 18), wx, wy) - 1)
    veins = np.clip((ridge - 0.86) / 0.14, 0, 1) ** 1.3          # venas de luz celeste
    purple = np.clip((warp(noise(rng, h, w, 12, 50), wx, wy) - 0.58) / 0.2, 0, 1)
    big = noise(rng, h, w, 24, 90)
    thr = 0.74 + 0.22 * (big - 0.5) + 0.2 * (cloud - 0.5)        # borde con lenguas
    a = np.clip((thr - e) / 0.22, 0, 1) * (0.82 + 0.18 * detail)
    rim = np.clip(1 - np.abs(e - (thr - 0.12)) / 0.14, 0, 1) * (e < thr)   # el borde se aclara
    col = np.broadcast_to(NAVY / 255.0, (h, w, 3)) * (1 - 0.5 * cloud[..., None])
    col = mix(col, BLUE, 0.35 * cloud)
    col = mix(col, PURPLE, 0.55 * purple)
    col = mix(col, CELESTE, 0.8 * veins)
    col = mix(col, CELESTE, 0.5 * rim)
    st = stars_field(rng, h, w, 0.0035) * (e < thr)[..., None][..., 0]
    col = mix(col, WHITE, st)
    a = np.maximum(a, st)
    save_rgba(col, a, dst)


def strands(dst, w=512, h=128, seed=6, n=8):
    """Hebras onduladas (períodos enteros a lo largo: se repiten sin costura) que aparecen y se desvanecen."""
    rng = np.random.default_rng(seed)
    v = ((np.arange(h) + 0.5) / h)[:, None]
    u = ((np.arange(w) + 0.5) / w)[None, :]
    out = np.zeros((h, w))
    for _ in range(n):
        k1, k2 = rng.integers(1, 4), rng.integers(2, 6)
        p1, p2 = rng.uniform(0, 2 * np.pi, 2)
        amp = rng.uniform(0.08, 0.27)
        c = 0.5 + amp * (0.7 * np.sin(2 * np.pi * k1 * u + p1) + 0.3 * np.sin(2 * np.pi * k2 * u + p2))
        th = rng.uniform(0.012, 0.03) * (0.6 + 0.4 * np.sin(2 * np.pi * k2 * u + p1) ** 2)
        line = np.exp(-((v - c) / th) ** 2)
        out = np.maximum(out, line * (0.45 + 0.55 * np.sin(2 * np.pi * k1 * u + p2) ** 2))
    a = np.clip(out + gaussian_filter(out, 3, mode="wrap") * 0.7, 0, 1) * np.exp(-((v - 0.5) / 0.44) ** 8)
    save(np.clip(0.6 + 0.4 * out, 0, 1), a, dst)


def star_dust(dst, w=512, h=128, seed=9):
    rng = np.random.default_rng(seed)
    v = ((np.arange(h) + 0.5) / h)[:, None]
    dens = np.exp(-((v - 0.5) / 0.26) ** 2)                      # más estrellas cerca del eje
    small = stars_field(rng, h, w, 0.006, 0.5, 5.0) * dens
    big = stars_field(rng, h, w, 0.0009, 1.1, 9.0) * dens
    # las grandes con una crucecita de luz
    cross = np.maximum(gaussian_filter(big, (0.4, 3.0), mode="wrap"), gaussian_filter(big, (3.0, 0.4), mode="wrap")) * 2
    a = np.clip(small + big + cross, 0, 1)
    save(np.ones((h, w)), a, dst)


def main(out):
    os.makedirs(out, exist_ok=True)
    nebula(os.path.join(out, "om_beam_nebula.png"))
    strands(os.path.join(out, "om_beam_flow.png"))
    star_dust(os.path.join(out, "om_beam_stars.png"))
    core(os.path.join(out, "om_beam_core.png"))
    glow(os.path.join(out, "om_beam_glow.png"))
    print("OK om_beam_nebula, om_beam_flow, om_beam_stars, om_beam_core, om_beam_glow")


if __name__ == "__main__":
    main(sys.argv[1])
