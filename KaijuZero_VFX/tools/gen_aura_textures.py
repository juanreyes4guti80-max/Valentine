"""Texturas de las AURAS (Omnívora y Kaiju Zero). Las dos auras usan las mismas formas; cambia el color.
  om_aura_wisp_2x2   cuatro lenguas de energía que suben (redondeadas abajo, en punta arriba, con bordes ondulados),
                     pintadas como la nebulosa de Omnívora: azul muy oscuro con venas celestes, manchas púrpura y
                     estrellas. Trae su propio color.
  kz_aura_wisp_2x2   las mismas lenguas en carmesí: casi negro por dentro, rojo intenso, venas naranja y chispas
                     blancas al rojo. Trae su propio color.
  fx_aura_tongue_2x2 lenguas finas de energía (escala de grises: el color lo pone cada capa). Va en los dos módulos.
uso: python -I gen_aura_textures.py <carpeta Omnivora_VFX/textures> <carpeta KaijuZero_VFX/textures>"""
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_lava_textures import save
from gen_beam_textures import noise, warp


def save_rgba(col, alpha, dst):
    img = np.concatenate([np.clip(col, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(dst)


def mix(base, color, k):
    return base * (1 - k[..., None]) + (np.array(color) / 255.0)[None, None] * k[..., None]


def wisp_fields(n, seed):
    """Forma de una lengua (alfa) y sus campos internos (nubes, venas, manchas, estrellas) en un cuadro n x n."""
    rng = np.random.default_rng(seed)
    v = 1 - (np.arange(n)[:, None] + 0.5) / n            # 0 abajo .. 1 arriba
    u = (np.arange(n)[None, :] + 0.5) / n
    ph = rng.uniform(0, 6.28, 3)
    cx = 0.5 + 0.07 * np.sin(2 * np.pi * (1.1 * v) + ph[0]) * v + 0.04 * np.sin(2 * np.pi * 2.3 * v + ph[1])
    width = 0.3 * np.clip(v / 0.22, 0, 1) ** 0.6 * (1 - v) ** 0.9 + 0.01
    wx = (noise(rng, n, n, 10, 10) - 0.5) * n * 0.14
    wy = (noise(rng, n, n, 14, 8) - 0.5) * n * 0.08
    d = np.abs(u - cx) / width                               # 0 en el eje .. 1 en el borde
    edge = warp(d, wx, wy)
    a = np.clip((1 - edge) / 0.5, 0, 1) ** 1.4
    a *= np.clip(1 - (v - 0.86) / 0.14, 0, 1) * np.clip(v / 0.06, 0, 1)
    cloud = warp(noise(rng, n, n, 6, 9), wx * 1.5, wy * 2)
    ridge = 1 - np.abs(2 * warp(noise(rng, n, n, 7, 9), wx * 1.2, wy * 2.5) - 1)
    veins = gaussian_filter(np.clip((ridge - 0.78) / 0.22, 0, 1) ** 1.5, 1.2)
    patch = np.clip((warp(noise(rng, n, n, 9, 12), wx, wy) - 0.58) / 0.2, 0, 1)
    pts = (rng.random((n, n)) > 0.9965).astype(float)
    stars = np.clip(gaussian_filter(pts, 0.6) * 6, 0, 1) * (a > 0.3)
    rim = np.clip(1 - np.abs(edge - 0.72) / 0.16, 0, 1) * (edge < 1)
    a = a * (0.75 + 0.25 * cloud)
    return a, cloud, veins, patch, stars, rim


def wisp_atlas(dst_om, dst_kz, cell=256):
    om = np.zeros((cell * 2, cell * 2, 3))
    kz = np.zeros((cell * 2, cell * 2, 3))
    al = np.zeros((cell * 2, cell * 2))
    for k in range(4):
        a, cloud, veins, patch, stars, rim = wisp_fields(cell, 11 + k)
        # cósmica: azul muy oscuro -> celeste, manchas púrpura, estrellas blancas
        c = np.broadcast_to(np.array([12, 24, 80]) / 255.0, (cell, cell, 3)) * (1 - 0.4 * cloud[..., None])
        c = mix(c, (40, 90, 220), 0.4 * cloud)
        c = mix(c, (150, 60, 230), 0.6 * patch)
        c = mix(c, (110, 185, 255), 0.85 * veins)
        c = mix(c, (110, 185, 255), 0.55 * rim)
        c = mix(c, (240, 248, 255), stars)
        # carmesí: casi negro por dentro, rojo intenso, venas naranja, chispas blancas al rojo
        r = np.broadcast_to(np.array([22, 2, 6]) / 255.0, (cell, cell, 3)) * (1 - 0.3 * cloud[..., None])
        r = mix(r, (150, 10, 24), 0.55 * cloud)
        r = mix(r, (60, 4, 8), 0.5 * patch)                 # un poco de negro
        r = mix(r, (255, 110, 30), 0.85 * veins)
        r = mix(r, (255, 60, 40), 0.6 * rim)
        r = mix(r, (255, 240, 220), stars)
        r0, c0 = (k // 2) * cell, (k % 2) * cell
        om[r0:r0 + cell, c0:c0 + cell] = c
        kz[r0:r0 + cell, c0:c0 + cell] = r
        al[r0:r0 + cell, c0:c0 + cell] = np.maximum(a, stars)
    save_rgba(om, al, dst_om)
    save_rgba(kz, al, dst_kz)


def tongue_atlas(dsts, cell=256):
    g = np.zeros((cell * 2, cell * 2))
    al = np.zeros((cell * 2, cell * 2))
    for k in range(4):
        rng = np.random.default_rng(40 + k)
        v = 1 - (np.arange(cell)[:, None] + 0.5) / cell
        u = (np.arange(cell)[None, :] + 0.5) / cell
        out = np.zeros((cell, cell))
        for j in range(3):
            ph = rng.uniform(0, 6.28, 2)
            amp = rng.uniform(0.05, 0.12)
            cx = 0.5 + rng.uniform(-0.12, 0.12) + amp * np.sin(2 * np.pi * rng.uniform(0.8, 1.6) * v + ph[0]) * v
            th = rng.uniform(0.025, 0.05) * (1 - v) ** 0.8 * np.clip(v / 0.1, 0, 1) ** 0.5 + 0.004
            top = rng.uniform(0.7, 0.95)
            line = np.exp(-((u - cx) / th) ** 2) * np.clip((top - v) / 0.15, 0, 1)
            out = np.maximum(out, line * rng.uniform(0.7, 1.0))
        a = np.clip(out + gaussian_filter(out, 4) * 0.8, 0, 1)
        r0, c0 = (k // 2) * cell, (k % 2) * cell
        g[r0:r0 + cell, c0:c0 + cell] = np.clip(0.7 + 0.3 * out, 0, 1)
        al[r0:r0 + cell, c0:c0 + cell] = a
    for d in dsts:
        save(g, al, d)


def main(om_dir, kz_dir):
    wisp_atlas(os.path.join(om_dir, "om_aura_wisp_2x2.png"), os.path.join(kz_dir, "kz_aura_wisp_2x2.png"))
    tongue_atlas([os.path.join(om_dir, "fx_aura_tongue_2x2.png"), os.path.join(kz_dir, "fx_aura_tongue_2x2.png")])
    print("OK om_aura_wisp_2x2, kz_aura_wisp_2x2, fx_aura_tongue_2x2")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
