"""Texturas de los golpes que recibe el rival (GARRA y MORDISCO), en escala de grises + alfa (el color lo pone cada capa).
  kz_claw_4x4    el corte: tres zarpazos rasgados (como la garra del logo de Monster) que se desgarran de arriba
                 abajo (cuadros 0-5), destellan (6) y se adelgazan (7-15). Flipbook OneShot: se reproduce una vez en
                 la vida de la partícula. Se guarda girado 180°: con VelocityParallel la parte de arriba de la textura
                 mira hacia donde va la partícula, así que con el tajo bajando se ve derecho (gruesos arriba, puntas
                 abajo).
  kz_claw        los tres zarpazos completos, quietos (la cicatriz que queda ardiendo en el corte quemado)
  kz_claw_glow   los zarpazos muy difuminados (su resplandor)
  kz_bite_4x4    el mordisco: dos mandíbulas de colmillos que se cierran (cuadros 0-6), chocan (7-8) y quedan
                 cerradas (9-15). Colmillos blancos con borde oscuro y un halo muy suave.
uso: python -I gen_hit_textures.py <outdir>"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, maximum_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_lava_textures import save

# ----------------------------------------------------------------------------- garra
# (centro, inclinación, arriba, abajo, grosor máximo) de cada zarpazo, como se ve en pantalla (v hacia abajo);
# el del medio empieza y termina un poco más abajo, como en el logo
STROKES = [(0.33, -0.02, 0.06, 0.90, 0.085), (0.50, 0.0, 0.11, 0.95, 0.08), (0.67, 0.02, 0.06, 0.88, 0.085)]
KNOTS = 42


def torn_edges(seed=5):
    """Bordes rasgados de cada zarpazo: zigzag al azar (con algún mordisco más hondo) en nudos a lo largo del
    trazo. Fijos por semilla: la misma forma en todos los cuadros y en todas las resoluciones."""
    rng = np.random.default_rng(seed)
    out = []
    for _ in STROKES:
        edges = []
        for _side in range(2):
            k = rng.uniform(-1, 1, KNOTS) * 0.35
            bites = rng.random(KNOTS) < 0.12
            k[bites] -= rng.uniform(0.5, 1.0, int(bites.sum()))
            edges.append(k)
        out.append((edges[0], edges[1], rng.uniform(0, 6.28)))
    return out


TORN = torn_edges()


def claw_field(n, progress=(1.0, 1.0, 1.0), thick=1.0, head=0.0):
    """Alfa y gris de los tres zarpazos en un cuadro de n px, derechos (gruesos arriba). progress = hasta dónde
    se desgarró cada uno (0 = nada, 1 = entero); head = brillo extra en la punta que avanza."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    U = (xx + 0.5) / n
    vs = (np.arange(n) + 0.5) / n
    alpha, gray = np.zeros((n, n)), np.zeros((n, n))
    for (base, lean, v0, v1, wmax), (jl, jr, ph), p in zip(STROKES, TORN, progress):
        t = (vs - v0) / (v1 - v0)                         # 0 arriba .. 1 abajo
        tc = np.clip(t, 0, 1)
        cx = base + lean * (vs - 0.5) + 0.01 * np.sin(2 * np.pi * 1.2 * vs + ph)
        w = wmax * thick * (1 - tc) ** 0.6 * np.clip(t / 0.05, 0, 1) ** 0.5   # el arranque arriba, punta abajo
        kv = np.linspace(0, 1, KNOTS)
        left = cx - w / 2 * (1 + np.interp(tc, kv, jl))
        right = cx + w / 2 * (1 + np.interp(tc, kv, jr))
        a = np.clip((U - left[:, None]) * n + 0.5, 0, 1) * np.clip((right[:, None] - U) * n + 0.5, 0, 1)
        a *= ((t >= 0) & (t <= 1))[:, None]
        a *= np.clip((p - t[:, None]) / 0.02 + 0.5, 0, 1)   # se desgarra de arriba hacia abajo
        near = (np.clip(1 - np.abs(t - p) / 0.08, 0, 1) * (t <= p))[:, None]
        core = np.clip(1 - np.abs(U - cx[:, None]) / (w[:, None] / 2 + 1e-6), 0, 1)
        g = np.clip(0.75 + 0.25 * core + 0.3 * head * near, 0, 1)
        gray = np.where(a > alpha, g, gray)
        alpha = np.maximum(alpha, a)
    return alpha, gray


def with_glow(a, g, sigma, k):
    glow = gaussian_filter(a, sigma) * k
    alpha = np.maximum(a, glow)
    gray = np.where(a > 0.02, g, 1.0)
    return gray, alpha


def flip(*arrs):
    """Girado 180°: con VelocityParallel y el tajo bajando, en pantalla se ve derecho."""
    return [np.rot90(x, 2) for x in arrs]


def claw_flipbook(dst, cell=256):
    out_g, out_a = np.zeros((cell * 4, cell * 4)), np.zeros((cell * 4, cell * 4))
    for k in range(16):
        if k <= 5:                                       # se desgarran (el del medio y el derecho, un pelo después)
            f = 1 - (1 - (k + 1) / 6) ** 2
            a, g = claw_field(cell, progress=(f, f - 0.04, f - 0.08), head=1.0)
            glow_k = 0.3
        elif k == 6:                                     # destello: completos y algo más gruesos
            a, g = claw_field(cell, thick=1.12)
            g = np.minimum(g + 0.1, 1)
            glow_k = 0.4
        else:                                            # se adelgazan
            tk = (k - 6) / 9
            a, g = claw_field(cell, thick=1.0 - 0.6 * tk)
            glow_k = 0.3 * (1 - 0.6 * tk)
        g, a = with_glow(a, g, cell / 60, glow_k)
        g, a = flip(g, a)
        r0, c0 = (k // 4) * cell, (k % 4) * cell
        out_g[r0:r0 + cell, c0:c0 + cell] = g
        out_a[r0:r0 + cell, c0:c0 + cell] = a
    save(out_g, out_a, dst)


def claw_static(dst, n=512):
    a, g = claw_field(n)
    g, a = with_glow(a, g, n / 60, 0.3)
    save(*flip(g, a), dst)


def claw_glow(dst, n=256):
    a, _ = claw_field(n, thick=1.5)
    a = np.clip(gaussian_filter(a, n / 26) * 2.0, 0, 1) * 0.9
    save(np.ones((n, n)), flip(a)[0], dst)


# ----------------------------------------------------------------------------- mordisco
def jaw_polys(n, d, sx=1.0, upper=True):
    """Polígonos (en px de un lienzo n x n) de una mandíbula: el arco de la encía y sus colmillos.
    d = cuánto está abierta (0 = cerrada); sx = estiramiento horizontal (el golpe al chocar)."""
    def P(u, v):
        u = 0.5 + (u - 0.5) * sx
        v = v - d if upper else 1 - (v - d)
        return (u * n, v * n)

    def gum(u):                                          # arco: más alto en el centro, baja a los lados
        return 0.33 - 0.07 * (1 - ((u - 0.5) / 0.42) ** 2)
    polys = []
    us = np.linspace(0.08, 0.92, 40)
    top = [P(u, gum(u) - 0.04) for u in us]
    bot = [P(u, gum(u) + 0.004) for u in us[::-1]]
    polys.append(top + bot)                              # la encía (banda)
    # colmillos: los de los lados (caninos) más largos; los de abajo van corridos medio diente
    pos = np.linspace(0.17, 0.83, 7) + (0 if upper else 0.055)
    lens = [0.10, 0.20, 0.11, 0.09, 0.11, 0.20, 0.10]
    for i, (u0, L) in enumerate(zip(pos, lens)):
        if u0 > 0.88:
            continue
        hw = 0.04 if L > 0.15 else 0.032
        g0 = gum(u0)
        tip_u = u0 + (0.012 if u0 < 0.5 else -0.012)      # la punta se curva un poco hacia el centro
        side_l = [P(u0 - hw + (tip_u - u0 + hw) * t ** 1.4, g0 + L * t) for t in np.linspace(0, 1, 9)]
        side_r = [P(u0 + hw + (tip_u - u0 - hw) * t ** 1.4, g0 + L * t) for t in np.linspace(1, 0, 9)]
        polys.append([P(u0 - hw, g0 - 0.01)] + side_l + side_r + [P(u0 + hw, g0 - 0.01)])
    return polys


def bite_frame(n, d, sx):
    ss = 4
    img = Image.new("L", (n * ss, n * ss), 0)
    dr = ImageDraw.Draw(img)
    for upper in (True, False):
        for poly in jaw_polys(n * ss, d, sx, upper):
            dr.polygon(poly, fill=255)
    a = np.asarray(img.resize((n, n), Image.LANCZOS), np.float64) / 255
    rim = np.clip(maximum_filter(a, size=5) - a, 0, 1)    # borde oscuro de 2 px para que se lea sobre cualquier fondo
    shell = np.maximum(a, rim)
    halo = gaussian_filter(shell, n / 40) * 0.25
    alpha = np.maximum(shell, halo)
    yy = (np.arange(n)[:, None] + 0.5) / n
    shade = 0.86 + 0.14 * np.clip(np.abs(yy - 0.5) / 0.2, 0, 1)    # algo más claro hacia las encías
    gray = np.where(a > 0.5, shade, np.where(rim > 0.05, 0.22, 1.0))
    return gray, alpha


def bite_flipbook(dst, cell=256):
    out_g, out_a = np.zeros((cell * 4, cell * 4)), np.zeros((cell * 4, cell * 4))
    d_open, d_shut = 0.17, -0.1                          # abiertas .. cerradas (los colmillos se entrecruzan)
    for k in range(16):
        if k <= 6:                                       # se cierran acelerando
            d, sx = d_open - (d_open - d_shut) * (k / 6) ** 1.8, 1.0
        elif k == 7:                                     # chocan: se pasan un poco y se ensanchan
            d, sx = d_shut - 0.012, 1.05
        elif k == 8:
            d, sx = d_shut + 0.005, 1.02
        else:                                            # cerradas, crecen apenas mientras se desvanecen
            d, sx = d_shut, 1.0 + 0.05 * (k - 8) / 7
        g, a = bite_frame(cell, d, sx)
        r0, c0 = (k // 4) * cell, (k % 4) * cell
        out_g[r0:r0 + cell, c0:c0 + cell] = g
        out_a[r0:r0 + cell, c0:c0 + cell] = a
    save(out_g, out_a, dst)


def main(out):
    os.makedirs(out, exist_ok=True)
    claw_flipbook(os.path.join(out, "kz_claw_4x4.png"))
    claw_static(os.path.join(out, "kz_claw.png"))
    claw_glow(os.path.join(out, "kz_claw_glow.png"))
    bite_flipbook(os.path.join(out, "kz_bite_4x4.png"))
    print("OK kz_claw_4x4, kz_claw, kz_claw_glow, kz_bite_4x4")


if __name__ == "__main__":
    main(sys.argv[1])
