"""Texturas propias de LAVA para la H1 de Kaiju Zero (escala de grises + alfa: Roblox las tiñe con Color,
así la versión Ignition sale carmesí sola). Los patrones de magma salen de las muestras CC0 de Effekseer.
  kz_lava_glob_2x2  gotas de magma (4 formas): núcleo caliente, borde y manchas de costra más oscuros
  kz_lava_drop      gota alargada en vuelo (cabeza redonda, cola corta) para los chorros de magma
  kz_lava_rock_2x2  trozos de roca de lava (4 formas): costra oscura con grietas encendidas
  kz_lava_pool      charco de lava fundida con placas de costra y borde irregular (Decal)
  kz_lava_cracks    grietas volcánicas anchas que salen del centro (Decal)
  kz_lava_splat     salpicadura de lava con gotitas alrededor (Decal)
uso: python -I gen_lava_textures.py <carpeta Effekseer Release/Sample> <outdir>"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, gaussian_filter1d, map_coordinates


def save(gray, alpha, dst):
    img = np.stack([np.clip(gray, 0, 1) * 255] * 3 + [np.clip(alpha, 0, 1) * 255], -1).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(dst)


def fbm(rng, n, octaves=5, base=4.0, stretch=1.0):
    acc, amp, tot = np.zeros((n, n)), 1.0, 0.0
    for o in range(octaves):
        sg = n / (base * 2 ** o)
        f = gaussian_filter(rng.normal(0, 1, (n, n)), (sg * stretch, sg), mode="wrap")
        acc += amp * f / (f.std() + 1e-9)
        tot += amp
        amp *= 0.55
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min())


def blob_mask(rng, n, r0=0.36, amp=0.09, lobes=7):
    """Silueta redonda e irregular (radio que varía con el ángulo)."""
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + 0.5) / n - 0.5
    y = (yy + 0.5) / n - 0.5
    ang = np.arctan2(y, x)
    r = np.hypot(x, y)
    rad = r0 + sum(rng.uniform(-amp, amp) / (k ** 0.6) * np.cos(k * ang + rng.uniform(0, 6.28))
                   for k in range(2, lobes + 1))
    return r, rad


def glob_2x2(dst, cell=256, seed=7):
    """Gotas de magma (4 formas): masa fundida irregular, algo estirada, con vetas calientes y placas de costra
    por dentro y el borde más oscuro. Nada de brillo especular: no debe parecer una bola sombreada."""
    out_g = np.zeros((cell * 2, cell * 2))
    out_a = np.zeros((cell * 2, cell * 2))
    for k in range(4):
        rng = np.random.default_rng(seed + 13 * k)
        r, rad = blob_mask(rng, cell, r0=0.32 + 0.02 * k, amp=0.045, lobes=5)
        ys = (1.0, 0.85, 0.92, 0.78)[k]                 # algunas más estiradas
        yy, xx = np.mgrid[0:cell, 0:cell]
        x = (xx + 0.5) / cell - 0.5
        y = ((yy + 0.5) / cell - 0.5) / ys
        r = np.hypot(x, y)
        alpha = np.clip((rad - r) / 0.012, 0, 1)
        t = np.clip(r / rad, 0, 1)                         # 0 centro .. 1 borde
        veins = fbm(rng, cell, octaves=4, base=4.0)
        crust = fbm(rng, cell, octaves=3, base=6.0)
        g = 0.5 + 0.3 * (1 - t ** 2) + 0.2 * np.clip((veins - 0.35) / 0.4, 0, 1)   # núcleo y vetas calientes
        g *= 1 - 0.55 * np.clip((crust - 0.6) / 0.14, 0, 1) * np.clip((t - 0.25) * 2, 0, 1)   # placas de costra
        g *= 1 - 0.55 * np.clip((t - 0.7) / 0.3, 0, 1) ** 1.5                 # borde que se enfría
        r0, c0 = (k // 2) * cell, (k % 2) * cell
        out_g[r0:r0 + cell, c0:c0 + cell] = np.clip(g, 0, 1)
        out_a[r0:r0 + cell, c0:c0 + cell] = alpha
    save(out_g, out_a, dst)


def drop(dst, n=256):
    """Gota de magma en vuelo (la textura apunta hacia arriba): cabeza redonda y gruesa arriba, cuerpo que se
    afina hacia una cola corta y redondeada, borde algo ondulado. Núcleo caliente, bordes más oscuros."""
    rng = np.random.default_rng(5)
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + 0.5) / n - 0.5
    y = (yy + 0.5) / n                                   # 0 arriba .. 1 abajo
    head_y, head_r, tail_y, tail_r = 0.28, 0.15, 0.8, 0.06
    # unión de círculos a lo largo del eje: el radio pasa de la cabeza a la cola (las dos puntas redondas)
    w = np.zeros((n, n))
    for c in np.linspace(0, 1, 48):
        cy = head_y + (tail_y - head_y) * c
        rr = head_r + (tail_r - head_r) * c ** 0.8
        rr *= 1 + 0.06 * np.sin(c * 11 + 0.7) * c
        w = np.maximum(w, rr - np.hypot(x, y - cy))
    alpha = np.clip(w / 0.018, 0, 1)
    u = np.clip((y - head_y) / (tail_y - head_y), 0, 1)
    g = 1.0 - 0.55 * u - 0.35 * np.clip(1 - w / 0.06, 0, 1)
    g = np.clip(g + 0.1 * (fbm(rng, n, octaves=3, base=6.0) - 0.5), 0.15, 1)
    save(g, alpha, dst)


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


def pool(dst, eff, n=512, seed=21):
    """Charco de lava: vetas brillantes de magma (de la muestra de Effekseer) entre placas de costra."""
    rng = np.random.default_rng(seed)
    flow = np.asarray(Image.open(os.path.join(eff, "01_Suzuki01/001_magma_effect/Texture/aura3_type2.png"))
                      .convert("L").resize((n, n), Image.LANCZOS)).astype(np.float32) / 255
    mag = np.asarray(Image.open(os.path.join(eff, "01_Suzuki01/001_magma_effect/Texture/magma.png"))
                     .convert("L").resize((n, n), Image.LANCZOS)).astype(np.float32) / 255
    plates = fbm(rng, n, octaves=4, base=5.0)
    r, rad = blob_mask(rng, n, r0=0.4, amp=0.07, lobes=9)
    t = np.clip(r / rad, 0, 1.2)
    hot = np.clip(0.55 * flow + 0.45 * mag, 0, 1)
    g = 0.25 + 0.75 * hot
    g *= 1 - 0.6 * np.clip((plates - 0.52) / 0.18, 0, 1)            # placas de costra oscura
    g = g * (1 - 0.35 * np.clip((t - 0.6) / 0.4, 0, 1))              # más frío hacia el borde
    g = np.clip(g * 1.15 + 0.35 * np.clip(0.35 - t, 0, 0.35) / 0.35, 0, 1)   # el centro arde más
    edge_noise = gaussian_filter(rng.normal(0, 1, (n, n)), 3)
    alpha = np.clip((rad + 0.02 * edge_noise / (np.abs(edge_noise).max() + 1e-9) - r) / 0.03, 0, 1)
    # gotitas alrededor del charco
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(40):
        a = rng.uniform(0, 2 * np.pi)
        rr = rng.uniform(0.42, 0.49) * n
        s = rng.uniform(2, 7)
        cx, cy = n / 2 + np.cos(a) * rr, n / 2 + np.sin(a) * rr
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=255)
    drops = np.asarray(img.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    alpha = np.maximum(alpha, drops)
    g = np.where(drops > alpha * 0.99, 0.75, g)
    save(g, alpha, dst)


def cracks(dst, n=512, seed=9):
    """Grietas anchas y quebradas que salen del centro, con resplandor alrededor."""
    rng = np.random.default_rng(seed)
    S = n * 2
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2

    def crack(x, y, ang, length, width, depth):
        step = S * 0.022
        pts = [(x, y)]
        for _ in range(int(length / step) + 1):
            ang += rng.normal(0, 0.28)
            x += np.cos(ang) * step
            y += np.sin(ang) * step
            pts.append((x, y))
            if depth < 1 and rng.random() < 0.12:
                crack(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), length * rng.uniform(0.3, 0.5),
                      max(3.0, width * 0.55), depth + 1)
        for i in range(len(pts) - 1):
            w = width * (1 - 0.7 * i / len(pts))
            d.line([pts[i], pts[i + 1]], fill=255, width=max(2, int(round(w))))

    for k in range(9):
        ang = 2 * np.pi * (k + rng.uniform(-0.3, 0.3)) / 9
        crack(c + np.cos(ang) * S * 0.03, c + np.sin(ang) * S * 0.03, ang, S * rng.uniform(0.33, 0.46), 16, 0)
    line = np.asarray(img.filter(ImageFilter.GaussianBlur(1.5)).resize((n, n), Image.LANCZOS), np.float32) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(14)).resize((n, n), Image.LANCZOS), np.float32) / 255
    yy, xx = np.mgrid[0:n, 0:n]
    r = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)
    fade = np.clip((0.98 - r) / 0.25, 0, 1)
    alpha = np.clip(line * 1.2 + glow * 0.7, 0, 1) * fade
    g = np.clip(0.55 + 0.45 * line, 0, 1)
    save(g, alpha, dst)


def splat(dst, n=256, seed=33):
    """Salpicadura: mancha central irregular con chorritos y gotas alrededor."""
    rng = np.random.default_rng(seed)
    r, rad = blob_mask(rng, n, r0=0.2, amp=0.06)
    body = np.clip((rad - r) / 0.03, 0, 1)
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(14):                               # chorritos que salen
        a = rng.uniform(0, 2 * np.pi)
        l0, l1 = 0.18 * n, rng.uniform(0.28, 0.46) * n
        w = rng.uniform(4, 9)
        x0, y0 = n / 2 + np.cos(a) * l0, n / 2 + np.sin(a) * l0
        x1, y1 = n / 2 + np.cos(a) * l1, n / 2 + np.sin(a) * l1
        d.line([(x0, y0), (x1, y1)], fill=255, width=int(w))
        d.ellipse([x1 - w * 0.8, y1 - w * 0.8, x1 + w * 0.8, y1 + w * 0.8], fill=255)
    for _ in range(26):                               # gotas sueltas
        a = rng.uniform(0, 2 * np.pi)
        rr = rng.uniform(0.25, 0.48) * n
        s = rng.uniform(2, 5)
        cx, cy = n / 2 + np.cos(a) * rr, n / 2 + np.sin(a) * rr
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=255)
    arms = np.asarray(img.filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255
    alpha = np.maximum(body, arms)
    g = np.clip(0.55 + 0.45 * np.clip(1 - r / 0.25, 0, 1), 0, 1)
    save(g, alpha, dst)


def main(eff, out):
    os.makedirs(out, exist_ok=True)
    glob_2x2(os.path.join(out, "kz_lava_glob_2x2.png"))
    drop(os.path.join(out, "kz_lava_drop.png"))
    rock_2x2(os.path.join(out, "kz_lava_rock_2x2.png"))
    pool(os.path.join(out, "kz_lava_pool.png"), eff)
    cracks(os.path.join(out, "kz_lava_cracks.png"))
    splat(os.path.join(out, "kz_lava_splat.png"))
    print("OK kz_lava_glob_2x2, kz_lava_drop, kz_lava_rock_2x2, kz_lava_pool, kz_lava_cracks, kz_lava_splat")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
