"""Texturas propias de LAVA para la H1 de Kaiju Zero (escala de grises + alfa: Roblox las tiñe con Color,
así la versión Ignition sale carmesí sola). Los patrones de magma salen de las muestras CC0 de Effekseer.
  kz_lava_glob_2x2  gotas de magma (4 formas): núcleo caliente, borde y manchas de costra más oscuros
  kz_lava_drop      gota alargada (cabeza brillante, cola que se apaga) para los chorros de magma
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
    out_g = np.zeros((cell * 2, cell * 2))
    out_a = np.zeros((cell * 2, cell * 2))
    for k in range(4):
        rng = np.random.default_rng(seed + 13 * k)
        # gota casi redonda (líquida), algo estirada, con borde suave
        r, rad = blob_mask(rng, cell, r0=0.3 + 0.03 * k, amp=0.045, lobes=4)
        alpha = np.clip((rad - r) / 0.04, 0, 1)
        t = np.clip(r / rad, 0, 1)                         # 0 centro .. 1 borde
        crust = fbm(rng, cell, octaves=3, base=5.0)
        g = 1.0 - 0.5 * t ** 2.2                           # núcleo caliente, borde más oscuro
        g *= 1 - 0.3 * np.clip((crust - 0.62) / 0.15, 0, 1) * np.clip((t - 0.4) * 2, 0, 1)   # algo de costra al borde
        yy, xx = np.mgrid[0:cell, 0:cell]
        hl = np.exp(-(((xx / cell - 0.42) ** 2 + (yy / cell - 0.38) ** 2) / 0.004))      # brillo líquido
        g = np.clip(g + 0.25 * hl, 0, 1)
        r0, c0 = (k // 2) * cell, (k % 2) * cell
        out_g[r0:r0 + cell, c0:c0 + cell] = g
        out_a[r0:r0 + cell, c0:c0 + cell] = alpha
    save(out_g, out_a, dst)


def drop(dst, n=256):
    """Gota vertical: cabeza redonda abajo-arriba (la textura apunta hacia arriba) y cola que se afina."""
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + 0.5) / n - 0.5
    y = (yy + 0.5) / n                                   # 0 arriba .. 1 abajo
    head_y = 0.3
    w = np.where(y < head_y, 0.12 * np.sqrt(np.clip(1 - ((head_y - y) / head_y) ** 2, 0, 1)),
                 0.12 * np.clip(1 - (y - head_y) / (1 - head_y - 0.05), 0, 1) ** 0.8)
    alpha = np.clip((w - np.abs(x)) / 0.02, 0, 1)
    g = np.clip(1.0 - 0.6 * np.clip((y - head_y) / 0.6, 0, 1) - 0.25 * np.abs(x) / 0.12, 0.2, 1)
    save(g, alpha, dst)


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
    pool(os.path.join(out, "kz_lava_pool.png"), eff)
    cracks(os.path.join(out, "kz_lava_cracks.png"))
    splat(os.path.join(out, "kz_lava_splat.png"))
    print("OK kz_lava_glob_2x2, kz_lava_drop, kz_lava_pool, kz_lava_cracks, kz_lava_splat")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
