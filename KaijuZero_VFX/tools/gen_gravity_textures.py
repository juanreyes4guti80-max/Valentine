"""Texturas del M1 3 de Omnívora (Empuje gravitatorio): la marca negra que deja el raspón de gravedad.
  om_scrape       un parche de suelo raspado: rayas finas a lo largo (el eje vertical de la imagen), surcos más
                  oscuros, grano, bordes rotos y puntas deshilachadas. Simétrico arriba/abajo (sirve en los dos
                  sentidos). Gris claro: el color (casi negro) lo pone la capa.
  om_scrape_line  un surco largo y fino (el arrastre de una roca empujada), también a lo largo del eje vertical,
                  con un borde suave de tierra removida y las puntas afiladas.
Las dos son cuadradas (en Roblox van en un Decal sobre una Part cuadrada): la forma alargada va dentro de la imagen.
En el módulo, las rayas quedan en la dirección del empuje (desde el vértice hacia afuera).
  om_grav_band    (2x2, cuatro variantes) la banda del frente de gravedad: dos líneas finas y nítidas, rayas
                  horizontales de compresión adentro (oscuro y translúcido) y estrellitas; mira a la cámara y queda
                  acostada, así muchos trozos en fila forman la pared que avanza.
uso: python -I gen_gravity_textures.py <carpeta Omnivora_VFX/textures>"""
import os
import sys
import numpy as np
from scipy.ndimage import gaussian_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_lava_textures import save
from gen_beam_textures import noise


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def scrape(dst, n=512, seed=5):
    rng = np.random.default_rng(seed)
    y = (np.arange(n)[:, None] + 0.5) / n - 0.5          # -0.5 .. 0.5 (a lo largo del raspón)
    x = (np.arange(n)[None, :] + 0.5) / n - 0.5          # -0.5 .. 0.5 (a lo ancho)
    ay = np.abs(y)
    # ancho del parche: forma de lente (más ancho en medio) con el borde un poco roto
    edge = 0.36 + 0.03 * (noise(rng, n, 1, 26, 1)[:, :1] - 0.5) * 2
    half = edge * np.sqrt(np.clip(1 - (ay / 0.5) ** 2, 0.02, 1))
    ex = 1 - smoothstep(0.35, 1.0, np.abs(x) / half)
    # cada raya tiene su largo (las del medio llegan más lejos): las puntas quedan deshilachadas
    lens = np.sqrt(np.clip(1 - (x / 0.4) ** 2, 0, 1))
    reach = (0.30 + 0.16 * noise(rng, 1, n, 1, 5.0)) * (0.55 + 0.45 * lens)
    ey = 1 - smoothstep(0.45, 1.0, ay / np.maximum(reach, 1e-3))
    # rayas finas y medianas (estiradas a lo largo) y grano
    fine = noise(rng, n, n, 60, 0.9)
    mid = noise(rng, n, n, 90, 3.0)
    streak = np.clip(0.35 + 0.9 * (fine - 0.5) + 0.7 * (mid - 0.5), 0, 1)
    grit = gaussian_filter((rng.random((n, n)) > 0.985).astype(float), 0.7) * 2.2
    blot = noise(rng, n, n, 26, 20)                      # manchas grandes (más y menos raspado)
    # surcos: líneas finas más oscuras y opacas, casi rectas, con su propio largo
    gouge = np.zeros((n, n))
    for _ in range(7):
        x0 = rng.uniform(-0.28, 0.28)
        w = rng.uniform(0.004, 0.009)
        L = rng.uniform(0.28, 0.46)
        wob = 0.006 * np.sin(2 * np.pi * (y * rng.uniform(1.0, 2.2) + rng.uniform(0, 1)))
        g = np.exp(-((x - x0 - wob) / w) ** 2) * (1 - smoothstep(0.6, 1.0, ay / L))
        gouge = np.maximum(gouge, g * rng.uniform(0.6, 1.0))
    core = np.exp(-(x / 0.26) ** 2 - (y / 0.34) ** 2)     # más oscuro en el centro del parche
    a = ex * ey * (0.46 + 0.3 * streak + 0.14 * blot + 0.25 * core)
    a = np.clip(a + 0.35 * grit * ex * ey, 0, 1)
    a = np.maximum(a, 0.95 * gouge * np.clip(ex * 1.4, 0, 1))
    a = gaussian_filter(a, 0.6)
    # gris claro con las rayas un poco más claras y los surcos más oscuros (la capa lo tiñe de casi negro)
    gray = np.clip(0.78 + 0.18 * (streak - 0.5) + 0.1 * (blot - 0.5) - 0.35 * gouge, 0, 1)
    save(gray, a, dst)


def scrape_line(dst, n=512, seed=9):
    rng = np.random.default_rng(seed)
    y = (np.arange(n)[:, None] + 0.5) / n - 0.5
    x = (np.arange(n)[None, :] + 0.5) / n - 0.5
    ay = np.abs(y)
    wob = 0.004 * (noise(rng, n, 1, 30, 1)[:, :1] - 0.5) * 2
    taper = 1 - smoothstep(0.25, 1.0, ay / 0.47)            # se afina hacia las puntas
    tip = 1 - smoothstep(0.85, 1.0, ay / 0.47)
    w = 0.012 * (0.35 + 0.65 * taper)
    d = np.abs(x - wob)
    groove = np.exp(-(d / w) ** 2)                          # el surco
    rim = np.exp(-(d / (3.2 * w)) ** 2) * 0.45              # la tierra removida a los lados
    grain = noise(rng, n, n, 14, 1.2)
    a = np.clip(np.maximum(groove, rim * (0.6 + 0.6 * grain)) * tip, 0, 1)
    gray = np.clip(0.85 - 0.45 * groove + 0.1 * (grain - 0.5), 0, 1)
    save(gray, gaussian_filter(a, 0.5), dst)


def grav_band_cell(n, seed):
    """Un trozo de la banda: dos líneas finas y nítidas (la de abajo más fuerte), rayas horizontales de compresión
    adentro (oscuro y translúcido) y unas estrellitas. Los extremos izquierdo y derecho se desvanecen para que los
    trozos vecinos se junten en una banda continua."""
    rng = np.random.default_rng(seed)
    y = (np.arange(n)[:, None] + 0.5) / n
    x = (np.arange(n)[None, :] + 0.5) / n
    ph = rng.uniform(0, 1, 2)
    yt = 0.27 + rng.uniform(-0.008, 0.008) + 0.004 * np.sin(2 * np.pi * (1.3 * x + ph[0]))
    yb = 0.73 + rng.uniform(-0.008, 0.008) + 0.004 * np.sin(2 * np.pi * (1.1 * x + ph[1]))

    def line(y0, w):
        return np.exp(-((y - y0) / w) ** 2)
    flick = 0.8 + 0.2 * noise(rng, 1, n, 1, 6)              # brillo que cambia un poco a lo largo
    top = (0.95 * line(yt, 0.0055) + 0.3 * line(yt, 0.022)) * flick * 0.7
    bot = (1.0 * line(yb, 0.006) + 0.4 * line(yb, 0.026)) * flick
    inside = smoothstep(0.0, 0.02, y - yt) * (1 - smoothstep(-0.02, 0.0, y - yb))
    streak = noise(rng, n, n, 0.7, 24)                       # rayas finas y largas (horizontales)
    lines = np.clip((streak - 0.55) / 0.3, 0, 1) ** 1.5
    pts = (rng.random((n, n)) > 0.9986).astype(float)
    stars = np.clip(gaussian_filter(pts, 0.55) * 7, 0, 1) * inside
    ex = smoothstep(0.0, 0.22, x) * (1 - smoothstep(0.78, 1.0, x))
    v = np.clip((y - yt) / (yb - yt), 0, 1)                    # 0 arriba .. 1 abajo (abajo empuja más)
    gray = np.clip(np.maximum.reduce([0.03 + 0.3 * lines, np.clip((top + bot) * 1.4, 0, 1), stars]), 0, 1)
    a = np.maximum.reduce([inside * (0.22 + 0.4 * v ** 1.3 + 0.22 * lines), np.clip(top + bot, 0, 1), stars])
    return gray, np.clip(a * ex, 0, 1)


def grav_band(dst, cell=256):
    """om_grav_band (2x2): la banda del frente de gravedad, en cuatro variantes."""
    g = np.zeros((2 * cell, 2 * cell))
    a = np.zeros((2 * cell, 2 * cell))
    for k in range(4):
        gc, ac = grav_band_cell(cell, 31 + k)
        r, c = divmod(k, 2)
        g[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = gc
        a[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = ac
    save(g, a, dst)


if __name__ == "__main__":
    out = sys.argv[1]
    scrape(os.path.join(out, "om_scrape.png"))
    scrape_line(os.path.join(out, "om_scrape_line.png"))
    grav_band(os.path.join(out, "om_grav_band.png"))
