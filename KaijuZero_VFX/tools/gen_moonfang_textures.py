"""Texturas propias de MOONFANG (lobo kaiju lunar de cristal). Todas en blanco/gris con alfa: el color lo pone
la capa (Color), así una misma textura sirve en plata, hielo o azul cristal.
  mf_crescent        media luna con borde brillante (cortes, ondas, el escudo del bloqueo)
  mf_chomp_4x4       el mordisco (16 cuadros): SOLO los colmillos de cristal, sin encía; las dos filas se cierran,
                     quedan trabadas, destellan y se rompen en pedazos
  mf_shard_2x2       cuatro esquirlas de cristal facetadas
  mf_moon            luna llena con cráteres
  mf_frost_cracks    grietas de cristal que salen del centro (Decal del suelo)
  mf_moonlight_2x2   cuatro variantes de luz de luna que cae (cuerpo de la columna del Eclipse)
  mf_aura_wisp_2x2   lenguas del aura en plata y hielo (sale de om_aura_wisp_2x2, ya coloreada)
  mf_blade_solid / mf_blade_line / mf_blade_glow   los Beams de la media luna (cuerpo nítido, filo y estelas, halo)
  mf_frost_patch     escarcha que se forma en el suelo alrededor del corte de la medialuna (Decal)
  mf_moonbeam        Beam de la columna del Eclipse: luz de luna que cae en vetas, se repite a lo largo (Wrap)
  mf_eclipse_sigil   el círculo lunar del suelo del Eclipse (las 8 fases de la luna, octagrama y media luna)
  mf_moon_eclipse_4x4  la luna llena que se va eclipsando (16 cuadros: la sombra entra hasta taparla)
  mf_ice_spikes_2x2  púas de cristal de hielo (4 variantes): brotan alrededor del rugido
uso: python gen_moonfang_textures.py <carpeta textures de Moonfang> <carpeta textures de Omnívora>"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

SS = 2   # supermuestreo


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1     # -1..1, y hacia abajo


def save(a_rgb, a_alpha, path, size):
    rgb = np.clip(a_rgb * 255, 0, 255).astype(np.uint8)
    al = np.clip(a_alpha * 255, 0, 255).astype(np.uint8)
    if rgb.ndim == 2:
        rgb = np.stack([rgb] * 3, -1)
    im = Image.fromarray(np.dstack([rgb, al]), "RGBA").resize((size, size), Image.LANCZOS)
    im.save(path)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def noise(n, scale, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((scale + 2, scale + 2)).astype(np.float32)
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    return np.asarray(im, np.float32) / 255


def crescent(n):
    """Media luna vertical (cuernos arriba y abajo, abierta a la derecha) como hoja de luz: muy brillante en el
    borde exterior y se desvanece hacia el borde interior."""
    x, y = grid(n)
    r1 = np.hypot(x + 0.12, y) / 0.86
    r2 = np.hypot(x - 0.26, y * 1.02) / 0.78
    inside = smooth(1.0, 0.95, r1) * smooth(0.98, 1.02, r2)
    depth = np.clip((1.0 - r1) / 0.32, 0, 1)                  # 0 en el borde exterior .. 1 hacia dentro
    blade = inside * (1 - depth) ** 1.6
    edge = np.exp(-((r1 - 0.965) / 0.03) ** 2) * smooth(0.98, 1.04, r2)
    glow = np.clip(np.exp(-np.abs(r1 - 0.97) * 9) * smooth(0.95, 1.12, r2), 0, 1) * 0.3
    a = np.clip(np.maximum(blade, glow) + edge * 0.7, 0, 1)
    v = np.clip(0.7 + 0.3 * np.maximum(edge, 1 - depth), 0, 1)
    return v, a


def spike(n):
    """Una aguja de cristal sola (para las púas que brotan)."""
    v, a = shard(n, 0, 3)
    return v, a


# colmillos de cada fila: (x de la base, largo, ancho de la base); la de abajo va corrida para que se traben
UPPER_TEETH = [(0.075, 0.17, 0.075), (0.19, 0.18, 0.08), (0.30, 0.42, 0.13), (0.45, 0.22, 0.10), (0.58, 0.17, 0.09)]
LOWER_TEETH = [(0.04, 0.13, 0.065), (0.12, 0.14, 0.07), (0.22, 0.34, 0.12), (0.38, 0.20, 0.10), (0.52, 0.16, 0.09)]


def fang_halves(cx, by, dirn, length, width, curve=0.22, n=14):
    """Un colmillo curvo: dos mitades (izquierda y derecha de su lomo) en coordenadas -1..1 (y hacia arriba).
    dirn = -1 apunta hacia abajo (fila de arriba), +1 hacia arriba; la punta se curva hacia el centro."""
    spine, left, right = [], [], []
    for k in range(n + 1):
        s = k / n
        sx = cx - math.copysign(curve * length * s * s, cx) if cx != 0 else 0.0
        sy = by + dirn * length * s
        w = width / 2 * (1 - s) ** 0.8
        spine.append((sx, sy))
        left.append((sx - w, sy))
        right.append((sx + w, sy))
    return left + spine[::-1], spine + right[::-1]


def fang_rows(n, h, scale=1.0, open_k=1.0):
    """Las dos filas de colmillos con la abertura h (de la línea del medio a la base de cada fila).
    Devuelve (valor, alfa) con las caras de cristal (una mitad más clara que la otra) y el filo brillante."""
    from PIL import ImageDraw
    S = n
    val = Image.new("L", (S, S), 0)
    alp = Image.new("L", (S, S), 0)
    dv, da = ImageDraw.Draw(val), ImageDraw.Draw(alp)

    def px(p):
        return ((p[0] * scale * 0.5 + 0.5) * S, (0.5 - p[1] * scale * 0.5) * S)

    for row, dirn in ((UPPER_TEETH, -1), (LOWER_TEETH, 1)):
        for x0, ln, wd in row:
            for sgn in ((-1, 1) if x0 > 0 else (1,)):
                cx = sgn * x0
                by = -dirn * (h + 0.07 * (cx / 0.6) ** 2)     # las bases forman un arco suave
                L_, R_ = fang_halves(cx, by, dirn, ln, wd)
                hi, lo = (L_, R_) if cx <= 0 else (R_, L_)  # la cara que da al centro, más clara
                da.polygon([px(p) for p in L_ + R_], fill=255)
                dv.polygon([px(p) for p in hi], fill=255)
                dv.polygon([px(p) for p in lo], fill=170)
                outline = [px(p) for p in L_[:len(L_) // 2 + 1]] + [px(p) for p in R_[len(R_) // 2:]]
                dv.line([px(p) for p in L_[: len(L_) // 2 + 1]], fill=255, width=max(2, S // 200))
                dv.line([px(p) for p in R_[len(R_) // 2:]], fill=255, width=max(2, S // 200))
    v = np.asarray(val, np.float32) / 255
    a = np.asarray(alp.filter(ImageFilter.GaussianBlur(S / 700)), np.float32) / 255
    return v, a


def vblur(img, r):
    """Desenfoque vertical (el barrido de los colmillos al cerrarse)."""
    if r < 1:
        return img
    k = np.ones(int(r) * 2 + 1, np.float32) / (int(r) * 2 + 1)
    return np.apply_along_axis(lambda c: np.convolve(c, k, mode="same"), 0, img)


def chomp_frame(n, i, nf=16, k_close=4):
    """Un cuadro del mordisco: SOLO los colmillos (de cristal), sin encía ni contorno de boca. La fila de arriba
    (apunta hacia abajo) y la de abajo (hacia arriba) se cierran de golpe con su barrido (cuadros 0..k_close-1) y
    quedan trabadas, con los caninos cruzados; en k_close destellan; se quedan clavados un instante y se rompen en
    pedazos que se apagan."""
    x, y = grid(n)
    y = -y
    H_CLOSED = 0.2
    if i < k_close:
        p = i / k_close
        h = H_CLOSED + 0.62 * (1 - p ** 1.5)
        v, a = fang_rows(n, h)
        # el barrido: copias desde donde venían, desenfocadas en vertical
        ga = np.zeros_like(a)
        span = 0.1 + 0.32 * p                                # el barrido es más largo cuanto más rápido van
        for j in range(1, 11):
            _, aj = fang_rows(n, h + span * j / 10)
            ga = np.maximum(ga, aj * 0.42 * (1 - j / 11) ** 1.3)
        ga = vblur(ga, n * span / 10 * 1.2)
        a = np.maximum(a * min(1.0, 0.55 + i * 0.3), ga)
        v = np.maximum(v, smooth(0.0, 0.3, ga))                # vetas claras
        return np.clip(v, 0, 1), np.clip(a, 0, 1)
    q = (i - k_close) / (nf - 1 - k_close)                    # 0 al cerrarse .. 1 al final
    h = H_CLOSED + 0.05 * q ** 1.5                             # se separan apenas al soltar
    v, a = fang_rows(n, h, scale=1.0 + 0.05 * (1 - q) ** 3)    # el golpe los infla un poco
    if i == k_close:                                           # el chasquido: un destello corto donde se traban
        flash = np.exp(-(y / 0.09) ** 2) * np.exp(-(x / 0.45) ** 2) * 0.55
        a = np.maximum(a, flash)
        v = np.maximum(v, flash)
        return np.clip(v, 0, 1), np.clip(a, 0, 1)
    # se quedan clavados y se rompen en pedazos que se apagan
    crack = noise(n, 18, 21) * 0.65 + noise(n, 47, 22) * 0.35
    thr = max(0.0, (q - 0.35) / 0.65) ** 0.9                  # se quedan clavados y después se rompen
    keep = smooth(thr - 0.04, thr + 0.04, crack)
    lines = smooth(0.035, 0.0, np.abs(crack - 0.52)) * smooth(0.0, 0.3, q) * 0.6   # grietas que se marcan antes
    a = a * keep * (1 - 0.35 * q)
    v = np.clip(v * (1 - lines) + lines * 0.3, 0, 1)
    glow = np.exp(-(y / 0.3) ** 2) * np.exp(-(x / 0.6) ** 2) * 0.25 * (1 - q) ** 2
    return np.clip(np.maximum(v, glow * 0.8), 0, 1), np.clip(np.maximum(a, glow), 0, 1)


def shard(n, kind, seed):
    """Esquirla facetada: polígono con caras de distinto gris y bordes claros."""
    rng = np.random.default_rng(seed)
    S = n
    shapes = {
        0: [(0.5, 0.02), (0.68, 0.45), (0.55, 0.98), (0.36, 0.5)],                 # aguja
        1: [(0.42, 0.04), (0.8, 0.3), (0.7, 0.86), (0.25, 0.95), (0.18, 0.4)],     # trozo roto
        2: [(0.5, 0.06), (0.92, 0.85), (0.08, 0.8)],                               # triángulo
        3: [(0.3, 0.05), (0.72, 0.12), (0.88, 0.6), (0.5, 0.96), (0.14, 0.62)],    # cristal ancho
    }
    pts = np.array(shapes[kind]) * S
    c = pts.mean(0)
    img = Image.new("L", (S, S), 0)
    alpha = Image.new("L", (S, S), 0)
    from PIL import ImageDraw
    da, dv = ImageDraw.Draw(alpha), ImageDraw.Draw(img)
    da.polygon([tuple(p) for p in pts], fill=255)
    m = len(pts)
    for i in range(m):          # una cara por lado, desde el centro: gris distinto
        tri = [tuple(c), tuple(pts[i]), tuple(pts[(i + 1) % m])]
        dv.polygon(tri, fill=int(rng.uniform(120, 245)))
    for i in range(m):          # aristas claras
        dv.line([tuple(pts[i]), tuple(pts[(i + 1) % m])], fill=255, width=max(2, S // 60))
        dv.line([tuple(c), tuple(pts[i])], fill=235, width=max(1, S // 110))
    v = np.asarray(img, np.float32) / 255
    a = np.asarray(alpha.filter(ImageFilter.GaussianBlur(S / 300)), np.float32) / 255
    return v, a


def moon(n):
    x, y = grid(n)
    r = np.hypot(x, y) / 0.82
    disk = smooth(1.0, 0.985, r)
    limb = 0.82 + 0.18 * np.sqrt(np.clip(1 - r ** 2, 0, 1))
    tex = 0.85 + 0.15 * noise(n, 14, 4) + 0.08 * (noise(n, 40, 5) - 0.5)
    rng = np.random.default_rng(7)
    craters = np.zeros_like(x)
    for _ in range(40):
        cx, cy = rng.uniform(-0.7, 0.7, 2)
        rad = 0.02 + 0.12 * rng.random() ** 3          # casi todos pequeños, pocos grandes
        d = np.hypot(x - cx, y - cy) / rad
        k = rng.uniform(0.05, 0.13)
        craters += k * smooth(1.1, 0.3, d) - 0.6 * k * np.exp(-((d - 1.0) / 0.2) ** 2)   # fondo oscuro y borde claro
    maria = 0.22 * smooth(0.45, 0.8, noise(n, 4, 9)) + 0.1 * smooth(0.5, 0.9, noise(n, 7, 12))
    v = np.clip(limb * tex - craters - maria, 0, 1) * disk
    glow = np.exp(-np.maximum(r - 1, 0) * 5) * (1 - disk) * 0.55
    return np.clip(v + glow * 0.9, 0, 1), np.clip(disk + glow, 0, 1)


def moon_eclipse(n, i, nf=16):
    """Cuadro i de la luna que se eclipsa (mf_moon_eclipse_4x4): la sombra, un disco apenas mayor, entra desde arriba
    a la izquierda (cuadro 0: la toca por fuera) hasta taparla entera en el último. Lo tapado queda casi negro (apenas
    se ven los cráteres) y opaco; el resplandor de alrededor se apaga donde llega la sombra."""
    v, a = moon(n)
    x, y = grid(n)
    p = i / (nf - 1)
    st = np.array([-1.0, -0.62])
    st = st / np.linalg.norm(st) * 1.66
    ds = np.hypot(x - st[0] * (1 - p), y - st[1] * (1 - p))
    cov = smooth(0.835, 0.825, ds)
    cov_g = smooth(1.05, 0.83, ds)
    disk = smooth(1.0, 0.985, np.hypot(x, y) / 0.82)
    dark = 0.05 + 0.08 * v
    v2 = np.where(disk > 0.5, v * (1 - cov) + dark * cov, v * (1 - cov_g))
    a2 = disk + (a - disk) * (1 - cov_g)
    return np.clip(v2, 0, 1), np.clip(a2, 0, 1)


def frost_cracks(n):
    rng = np.random.default_rng(11)
    S = n
    img = Image.new("L", (S, S), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)

    def branch(x, y, ang, length, width, depth):
        steps = int(length / (S * 0.06)) + 1
        for _ in range(steps):
            ang += rng.uniform(-0.12, 0.12) if rng.random() < 0.75 else rng.uniform(-0.6, 0.6)
            nx = x + math.cos(ang) * length / steps
            ny = y + math.sin(ang) * length / steps
            d.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            width *= 0.93
            if depth < 3 and rng.random() < 0.18:
                branch(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), length * 0.45, width * 0.8, depth + 1)
    for i in range(11):
        a0 = 2 * math.pi * i / 11 + rng.uniform(-0.2, 0.2)
        branch(S / 2, S / 2, a0, S * rng.uniform(0.34, 0.47), S / 70, 0)
    core = np.asarray(img, np.float32) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(S / 90)), np.float32) / 255
    x, y = grid(S)
    fade = smooth(1.0, 0.75, np.hypot(x, y))
    a = np.clip(core + glow * 1.6, 0, 1) * fade
    return np.clip(core * 0.6 + 0.6, 0, 1), a


def moonlight(n, seed):
    x, y = grid(n)
    rng = np.random.default_rng(seed)
    cols = noise(n, 14, seed)[0:1, :].repeat(n, 0)
    cols2 = noise(n, 31, seed + 3)[0:1, :].repeat(n, 0)
    streak = 0.55 * cols + 0.45 * cols2
    streak = (streak - streak.min()) / max(np.ptp(streak), 1e-3)
    wob = noise(n, 3, seed + 1)
    prof = np.clip(1 - ((np.abs(x) + 0.15 * (wob - 0.5)) / 0.8) ** 2, 0, 1) ** 1.3   # perfil redondo
    vert = np.clip(1 - np.abs(y) ** 4, 0, 1)
    a = np.clip((0.3 + 0.7 * streak ** 1.5) * prof * vert, 0, 1) * 0.85
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(n / 120)),
                   np.float32) / 255
    v = np.clip(0.75 + 0.25 * streak, 0, 1)
    for _ in range(22):                                        # chispas de estrella dentro
        sx, sy = rng.uniform(-0.55, 0.55), rng.uniform(-0.85, 0.85)
        d = np.hypot(x - sx, y - sy)
        sp = np.exp(-(d / 0.012) ** 2) + 0.4 * np.exp(-(d / 0.03) ** 2)
        a = np.maximum(a, sp * prof)
        v = np.maximum(v, sp)
    return v, a


def blade(w, h, kind):
    """Texturas para los Beams de la media luna (u = a lo largo, v = a lo ancho; perfil simétrico).
    core: línea brillante y dura; glow: halo ancho y suave; frost: cuerpo con vetas de escarcha."""
    v = (np.arange(h, dtype=np.float32) + 0.5) / h * 2 - 1           # -1..1 a lo ancho
    u = (np.arange(w, dtype=np.float32) + 0.5) / w
    V_, U_ = np.meshgrid(v, u, indexing="ij")
    if kind == "solid":                                           # cuerpo nítido: lleno y con borde duro
        a = smooth(0.9, 0.76, np.abs(V_))
        val = np.clip(0.8 + 0.2 * np.exp(-(V_ / 0.35) ** 2), 0, 1)
    elif kind == "line":                                          # línea fina y dura (el filo y las estelas)
        a = smooth(0.85, 0.5, np.abs(V_))
        val = np.ones_like(a)
    elif kind == "core":
        a = np.exp(-(V_ / 0.16) ** 2) * 1.0 + 0.45 * np.exp(-(V_ / 0.45) ** 2)
        val = np.clip(0.8 + 0.2 * np.exp(-(V_ / 0.16) ** 2), 0, 1)
    elif kind == "glow":
        a = np.exp(-(V_ / 0.55) ** 2) * 0.9
        val = np.ones_like(a)
    else:
        rng = np.random.default_rng(31)
        streak = np.zeros_like(V_)
        for _ in range(14):                                       # vetas finas a lo largo
            c, wdt, amp = rng.uniform(-0.8, 0.8), rng.uniform(0.02, 0.07), rng.uniform(0.4, 1.0)
            streak += amp * np.exp(-((V_ - c) / wdt) ** 2) * (0.6 + 0.4 * np.sin(U_ * rng.uniform(4, 9) * np.pi
                                                                               + rng.uniform(0, 6)))
        prof = np.exp(-(V_ / 0.62) ** 2)
        a = np.clip(prof * (0.35 + 0.65 * np.clip(streak, 0, 1)), 0, 1)
        val = np.clip(0.75 + 0.25 * np.clip(streak, 0, 1), 0, 1)
    a = np.clip(a, 0, 1)
    rgb = np.stack([val] * 3, -1)
    return Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), a[..., None] * 255]).astype(np.uint8), "RGBA")


def moonbeam(w, h, seed=5):
    """Beam de la columna del Eclipse (u = a lo largo, se repite: TextureMode Wrap; v = a lo ancho): luz de luna que
    cae en vetas finas con pulsos (al correr la textura bajan) y chispas; bordes suaves para que las cortinas de
    la columna se fundan entre sí."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(h)[:, None] * h               # ciclos a lo ancho
    fx = np.fft.fftfreq(w)[None, :] * w               # ciclos a lo largo (entero: se repite sin costura)

    def field(kx, ky):
        F = rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))
        f = np.real(np.fft.ifft2(F * np.exp(-(fx / kx) ** 2 - (fy / ky) ** 2)))
        return (f - f.min()) / max(np.ptp(f), 1e-6)
    streak = 0.6 * field(2.5, 16) + 0.4 * field(5, 42)    # vetas largas a lo largo, finas a lo ancho
    v = (np.arange(h, dtype=np.float32) + 0.5) / h * 2 - 1
    u = (np.arange(w, dtype=np.float32) + 0.5) / w
    V_, U_ = np.meshgrid(v, u, indexing="ij")
    prof = smooth(1.0, 0.5, np.abs(V_))
    a = (0.22 + 0.78 * np.clip(streak, 0, 1) ** 1.6) * prof * 0.9
    val = np.clip(0.8 + 0.2 * streak, 0, 1)
    for _ in range(26):                                # chispas (con su estela hacia arriba: u menor)
        cu, cv = rng.uniform(0, 1), rng.uniform(-0.6, 0.6)
        du = (U_ - cu + 0.5) % 1.0 - 0.5
        dv = V_ - cv
        sp = np.exp(-(du * w / 2.2) ** 2 - (dv * h / 2.6) ** 2)
        sp += 0.45 * np.exp(-(np.clip(du, None, 0) * w / 14) ** 2 - (dv * h / 1.6) ** 2) * (du < 0)
        a = np.maximum(a, np.clip(sp, 0, 1) * prof)
        val = np.maximum(val, np.clip(sp, 0, 1))
    rgb = np.stack([val] * 3, -1)
    return Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), np.clip(a, 0, 1)[..., None] * 255])
                           .astype(np.uint8), "RGBA")


def eclipse_sigil(n):
    """El círculo lunar que se dibuja en el suelo del Eclipse (Decal): anillo doble en el borde, las 8 fases de la
    luna alrededor, anillo con marcas, un octagrama y una media luna al centro. Líneas finas con un halo suave."""
    from PIL import ImageDraw
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    c = n / 2

    def ring(r, w):
        d.ellipse([c - r * c, c - r * c, c + r * c, c + r * c], outline=255, width=max(1, int(w * c)))

    def pol(r, a):
        return c + r * c * math.cos(a), c + r * c * math.sin(a)
    ring(0.955, 0.026)
    ring(0.912, 0.011)
    ring(0.682, 0.017)
    ring(0.43, 0.013)
    for i in range(48):                                   # marcas del anillo de adentro (más largas cada 6)
        a = 2 * math.pi * i / 48
        r1 = 0.735 if i % 6 == 0 else 0.708
        d.line([pol(0.682, a), pol(r1, a)], fill=255, width=max(1, int((0.017 if i % 6 == 0 else 0.009) * c)))
    for k in range(2):                                    # octagrama: dos cuadrados girados
        pts = [pol(0.682, math.pi / 4 * k + math.pi / 2 * i + math.pi / 8) for i in range(4)]
        d.line(pts + [pts[0]], fill=255, width=max(1, int(0.011 * c)), joint="curve")
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    X, Y = (x + 0.5) / c - 1, (y + 0.5) / c - 1
    a = np.asarray(img, np.float32) / 255
    rho = 0.062
    for k in range(8):                                    # las 8 fases (nueva, creciente, ..., llena, ..., menguante)
        ang = 2 * math.pi * k / 8 - math.pi / 2
        cx, cy = 0.80 * math.cos(ang), 0.80 * math.sin(ang)
        tx, ty = -math.sin(ang), math.cos(ang)            # eje x del icono: tangente al anillo
        lx = (X - cx) * tx + (Y - cy) * ty
        ly = (X - cx) * math.cos(ang) + (Y - cy) * math.sin(ang)
        rr = np.hypot(lx, ly)
        inside = smooth(rho + 0.004, rho - 0.002, rr)
        th = math.pi * k / 4
        term = rho * math.cos(th) * np.sqrt(np.clip(1 - (ly / rho) ** 2, 0, 1))
        lit = (lx > term) if k <= 4 else (lx < -term)
        if k == 0:
            lit = np.zeros_like(lx, bool)
        edge = smooth(0.012, 0.004, np.abs(rr - rho))     # contorno (la parte oscura se ve)
        a = np.maximum(a, np.maximum(inside * lit, edge * 0.85))
    # la media luna del centro y una estrella en su hueco
    disc = smooth(0.30, 0.296, np.hypot(X, Y))
    cut = smooth(0.262, 0.266, np.hypot(X - 0.11, Y + 0.03))
    a = np.maximum(a, disc * cut)
    st = np.hypot(X - 0.1, Y + 0.02)
    ang = np.arctan2(Y + 0.02, X - 0.1)
    star = smooth(0.11 * (0.35 + 0.65 * np.abs(np.cos(2 * ang)) ** 6), 0.0, st)
    a = np.maximum(a, np.clip(star * 1.6, 0, 1))
    glow = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(n / 160)),
                      np.float32) / 255
    a = np.clip(np.maximum(a, glow * 0.7), 0, 1)
    return np.ones_like(a), a


def ice_spike(n, k):
    """Cristales de hielo que apuntan hacia arriba (mf_ice_spikes_2x2; con VelocityParallel salen en la dirección en
    que vuelan): uno alto, dos en V, un racimo de tres y uno con un brote al lado. Caras facetadas y filo claro."""
    from PIL import ImageDraw
    img = Image.new("L", (n, n), 0)
    val = Image.new("L", (n, n), 0)
    da, dv = ImageDraw.Draw(img), ImageDraw.Draw(val)
    c = n / 2

    def crystal(cx, by, h, w, ang):
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

        def P(px, py):                                    # px a lo ancho, py hacia arriba desde la base
            return c + (cx + px * ca + py * sa) * c, c - (by + py * ca - px * sa) * c
        tip, sh = P(0, h), h * 0.72
        L0, R0, L1, R1, M0, M1 = P(-w, 0), P(w, 0), P(-w, sh), P(w, sh), P(0, 0), P(0, sh)
        da.polygon([L0, L1, tip, R1, R0], fill=255)
        dv.polygon([L0, L1, tip, M1, M0], fill=235)      # cara izquierda clara
        dv.polygon([M0, M1, tip, R1, R0], fill=150)      # cara derecha más oscura
        dv.line([M0, M1, tip], fill=255, width=max(1, n // 120))
    if k == 0:
        crystal(0.0, -0.9, 1.75, 0.16, 0)
    elif k == 1:
        crystal(-0.08, -0.9, 1.6, 0.13, -14)
        crystal(0.08, -0.9, 1.2, 0.11, 18)
    elif k == 2:
        crystal(0.0, -0.9, 1.7, 0.13, 0)
        crystal(-0.12, -0.9, 1.05, 0.1, -24)
        crystal(0.13, -0.9, 0.95, 0.1, 26)
    else:
        crystal(0.0, -0.9, 1.6, 0.15, 6)
        crystal(-0.1, -0.6, 0.6, 0.07, -38)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(n / 400)), np.float32) / 255
    v = np.asarray(val.filter(ImageFilter.GaussianBlur(n / 500)), np.float32) / 255
    return np.clip(v, 0, 1), a


def frost_patch(n):
    """Escarcha que se forma en el suelo alrededor del corte: agujas finas de hielo que salen hacia afuera, con
    ramitas como copos, sobre un velo suave. Igual en todas las direcciones (sirve girada o estirada)."""
    from PIL import ImageDraw
    rng = np.random.default_rng(41)
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(170):
        r0 = n * 0.5 * math.sqrt(rng.uniform(0, 0.55))
        a0 = rng.uniform(0, 2 * math.pi)
        x0, y0 = n / 2 + math.cos(a0) * r0, n / 2 + math.sin(a0) * r0
        ang = a0 + rng.uniform(-0.5, 0.5)
        ln = n * rng.uniform(0.05, 0.16)
        w = max(1, int(n / rng.uniform(260, 420)))
        x1, y1 = x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln
        d.line([(x0, y0), (x1, y1)], fill=int(rng.uniform(150, 255)), width=w)
        for k in range(rng.integers(1, 4)):                       # ramitas a ±60°
            f = rng.uniform(0.3, 0.8)
            bx, by = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
            for sg in (-1, 1):
                ba = ang + sg * math.pi / 3
                bl = ln * rng.uniform(0.15, 0.3)
                d.line([(bx, by), (bx + math.cos(ba) * bl, by + math.sin(ba) * bl)], fill=int(rng.uniform(110, 200)),
                       width=max(1, w - 1))
    needles = np.asarray(img, np.float32) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(n / 140)), np.float32) / 255
    x, y = grid(n)
    r = np.hypot(x, y)
    veil = 0.32 * smooth(0.95, 0.15, r)
    a = np.clip(needles * 0.95 + glow * 0.8 + veil, 0, 1) * smooth(1.0, 0.55, r)
    v = np.clip(0.72 + 0.28 * needles, 0, 1)
    return v, a


def atlas(tiles, n):
    out_v = np.zeros((2 * n, 2 * n), np.float32)
    out_a = np.zeros((2 * n, 2 * n), np.float32)
    for i, (v, a) in enumerate(tiles):
        r, c = divmod(i, 2)
        out_v[r * n:(r + 1) * n, c * n:(c + 1) * n] = v
        out_a[r * n:(r + 1) * n, c * n:(c + 1) * n] = a
    return out_v, out_a


def main(out, omni_tex):
    os.makedirs(out, exist_ok=True)
    N = 512 * SS
    v, a = crescent(N)
    save(v, a, os.path.join(out, "mf_crescent.png"), 512)
    # flipbook 4x4 del mordisco: los colmillos se cierran (cuadros 0-4), destellan (5) y se rompen (6-15)
    n = 256 * SS
    fv = np.zeros((4 * n, 4 * n), np.float32)
    fa = np.zeros_like(fv)
    for i in range(16):
        v, a = chomp_frame(n, i)
        r, c = divmod(i, 4)
        fv[r * n:(r + 1) * n, c * n:(c + 1) * n] = v
        fa[r * n:(r + 1) * n, c * n:(c + 1) * n] = a
    save(fv, fa, os.path.join(out, "mf_chomp_4x4.png"), 1024)
    n = 256 * SS
    v, a = atlas([shard(n, k, 3 + k) for k in range(4)], n)
    save(v, a, os.path.join(out, "mf_shard_2x2.png"), 512)
    v, a = spike(512)
    save(v, a, os.path.join(out, "mf_spike.png"), 256)
    v, a = moon(N)
    save(v, a, os.path.join(out, "mf_moon.png"), 512)
    v, a = frost_cracks(N)
    save(v, a, os.path.join(out, "mf_frost_cracks.png"), 512)
    v, a = atlas([moonlight(n, 20 + k) for k in range(4)], n)
    save(v, a, os.path.join(out, "mf_moonlight_2x2.png"), 512)
    # lenguas del aura: las de Omnívora pasadas a plata y hielo (sin púrpura)
    w = np.asarray(Image.open(os.path.join(omni_tex, "om_aura_wisp_2x2.png")).convert("RGBA"), np.float32) / 255
    lum = w[..., :3] @ np.array([0.3, 0.55, 0.15], np.float32)
    lum = np.clip(lum / max(lum.max(), 1e-3), 0, 1)
    deep, ice, white = np.array([0.10, 0.18, 0.42]), np.array([0.55, 0.78, 1.0]), np.array([0.95, 0.98, 1.0])
    t = lum[..., None]
    rgb = np.where(t < 0.5, deep + (ice - deep) * (t / 0.5), ice + (white - ice) * ((t - 0.5) / 0.5))
    Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), w[..., 3:] * 255]).astype(np.uint8), "RGBA") \
        .save(os.path.join(out, "mf_aura_wisp_2x2.png"))
    for kind in ("solid", "line", "glow"):
        blade(256, 128, kind).save(os.path.join(out, f"mf_blade_{kind}.png"))
    v, a = frost_patch(N)
    save(v, a, os.path.join(out, "mf_frost_patch.png"), 256)
    moonbeam(512, 256).save(os.path.join(out, "mf_moonbeam.png"))
    v, a = eclipse_sigil(2048)
    save(v, a, os.path.join(out, "mf_eclipse_sigil.png"), 1024)
    n = 256 * SS
    ev = np.zeros((4 * n, 4 * n), np.float32)
    ea = np.zeros_like(ev)
    for i in range(16):
        v, a = moon_eclipse(n, i)
        r, c = divmod(i, 4)
        ev[r * n:(r + 1) * n, c * n:(c + 1) * n] = v
        ea[r * n:(r + 1) * n, c * n:(c + 1) * n] = a
    save(ev, ea, os.path.join(out, "mf_moon_eclipse_4x4.png"), 1024)
    # las púas de hielo que brotan alrededor del rugido
    n = 256 * SS
    v, a = atlas([ice_spike(n, k) for k in range(4)], n)
    save(v, a, os.path.join(out, "mf_ice_spikes_2x2.png"), 512)
    print("OK texturas de Moonfang ->", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
