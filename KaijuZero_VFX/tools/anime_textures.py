"""Flipbooks estilo ANIME (como la referencia del usuario): formas de llama recortadas
con círculos (puntas filosas en arco), relleno gris claro + sombra gris + contorno
oscuro + halo suave. Se rompen en ESQUIRLAS: agujeros circulares que crecen y
cortan la forma en fragmentos puntiagudos, que se afinan hasta desaparecer.
Texturas en escala de grises: Roblox las tiñe con el ColorSequence.

uso: python anime_textures.py <outdir> [preview.png]
"""
import sys
import os
import math
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)

BODY, SHADE, RIM, HI = 214.0, 158.0, 104.0, 236.0


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def ease_out(t, p=2.6):
    return 1 - (1 - np.clip(t, 0, 1)) ** p


class Noise:
    """Ruido de gradiente 2D+t vectorizado (para ondular los bordes)."""
    G = np.array([[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]], float)

    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        p = rng.permutation(256)
        self.p = np.concatenate([p, p, p])

    def n2(self, x, y):
        xi, yi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
        xf, yf = x - xi, y - yi
        xi, yi = xi & 255, yi & 255
        f = lambda t: t * t * t * (t * (t * 6 - 15) + 10)
        u, v = f(xf), f(yf)
        p, G = self.p, self.G

        def g(ix, iy, dx, dy):
            h = p[p[ix] + iy] % 8
            return G[h, 0] * dx + G[h, 1] * dy
        a = g(xi, yi, xf, yf)
        b = g(xi + 1, yi, xf - 1, yf)
        c = g(xi, yi + 1, xf, yf - 1)
        d = g(xi + 1, yi + 1, xf - 1, yf - 1)
        return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v

    def fbm(self, x, y, oct=3):
        s, a, f, n = 0, 1.0, 1.0, 0
        for o in range(oct):
            s += a * self.n2(x * f + o * 13.7, y * f + o * 7.1)
            n += a
            a *= 0.5
            f *= 2
        return s / n


def grid(n):
    v = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(v, v)
    return x, -y


def circ(x, y, cx, cy, r):
    return np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - r


def crescent(x, y, cx, cy, r, ang, cut=0.55, cut_r=0.92):
    """Media luna: círculo menos círculo desplazado (puntas filosas)."""
    ox, oy = math.cos(ang) * r * cut, math.sin(ang) * r * cut
    return np.maximum(circ(x, y, cx, cy, r), -circ(x, y, cx + ox, cy + oy, r * cut_r))


def rot(x, y, a):
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c


def shade(sdf, sdf_off, px, glow=0.22):
    """Colorea con relleno, sombra (lado opuesto a la luz), contorno y halo."""
    inside = smooth(0.5 - sdf / px)
    rim_w = 2.2 * px
    col = np.full(sdf.shape, BODY)
    col = np.where(sdf_off > -0.004, SHADE, col)          # banda de sombra
    col = np.where((sdf > -rim_w), RIM, col)               # contorno
    hi = (sdf < -0.05) & (sdf_off < -0.07)
    col = np.where(hi, HI, col)                            # luz interior
    halo = np.exp(-np.maximum(sdf, 0) / 0.03) * glow * (sdf > 0)
    a = np.clip(inside + halo, 0, 1)
    c = np.where(inside > 0.02, col, 200.0)
    return c, a


def pack(c, a, ss):
    n = c.shape[0] // ss
    pa = a.reshape(n, ss, n, ss).mean(axis=(1, 3))
    pc = (c * a).reshape(n, ss, n, ss).mean(axis=(1, 3)) / np.maximum(pa, 1e-6)
    rgb = np.repeat(np.clip(pc, 0, 255)[..., None], 3, -1)
    return np.concatenate([rgb, (pa * 255)[..., None]], -1).astype(np.uint8)


def sheet(frames, cols=4):
    n = frames[0].shape[0]
    rows = math.ceil(len(frames) / cols)
    out = np.zeros((rows * n, cols * n, 4), np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * n:(r + 1) * n, c * n:(c + 1) * n] = f
    return Image.fromarray(out, "RGBA")


def holes_field(x, y, t, rng_seed, n=11, start=(0.22, 0.6), speed=(0.9, 1.6), area=0.75):
    """Agujeros circulares que crecen (erosión en esquirlas)."""
    rng = np.random.default_rng(rng_seed)
    H = np.full(x.shape, 9.0)
    for k in range(n):
        cx, cy = rng.uniform(-area, area, 2)
        t0 = rng.uniform(*start)
        sp = rng.uniform(*speed)
        r = max(0.0, (t - t0)) * sp * 0.55
        if r > 0:
            H = np.minimum(H, circ(x, y, cx, cy, r))
    return H


def build_parts(kind, rng):
    """Lista de primitivas: ('c', cx, cy, r, ang, cut, cut_r) media luna | ('o', cx, cy, r) círculo."""
    P = []
    a0 = rng.uniform(-0.4, 0.4)
    if kind == "claw":           # gran "C" abierta a la derecha con brazos largos y espinas
        P.append(("c", -0.08, 0.0, 0.7, a0, 0.42, 0.86))
        for sgn in (-1, 1):      # ganchos en las puntas de los brazos
            a = a0 + sgn * 1.15
            P.append(("c", math.cos(a) * 0.55, math.sin(a) * 0.55, 0.26, a + sgn * 1.6, 0.6, 0.9))
        for k in range(5):       # espinas en el lomo
            a = a0 + math.pi + rng.uniform(-1.0, 1.0)
            P.append(("c", math.cos(a) * 0.62, math.sin(a) * 0.62, rng.uniform(0.12, 0.18),
                      a + rng.choice([-1, 1]) * 1.9, 0.7, 0.88))
    elif kind == "burst":        # flor de garras radiales (explosión)
        n = 6
        for k in range(n):
            a = a0 + k * 2 * np.pi / n + rng.uniform(-0.25, 0.25)
            d = rng.uniform(0.3, 0.42)
            P.append(("c", math.cos(a) * d, math.sin(a) * d, rng.uniform(0.3, 0.4),
                      a + rng.uniform(-0.5, 0.5), 0.5, 0.84))
        P.append(("o", 0.0, 0.0, 0.36))
    elif kind == "tongue":       # llama: base redonda + cuerno curvo + rizo en la punta
        P.append(("o", 0.0, -0.42, 0.4))
        P.append(("c", 0.18, -0.05, 0.55, np.pi * 0.62, 0.62, 0.9))
        P.append(("c", -0.12, 0.42, 0.32, np.pi * 0.35, 0.6, 0.9))
        P.append(("c", 0.3, -0.3, 0.2, np.pi * 0.2, 0.62, 0.9))
    elif kind == "smoke":        # nube: lóbulos redondos
        for k in range(7):
            a = a0 + k * 2 * np.pi / 7 + rng.uniform(-0.3, 0.3)
            d = rng.uniform(0.25, 0.42)
            P.append(("o", math.cos(a) * d, math.sin(a) * d, rng.uniform(0.26, 0.36)))
        P.append(("o", 0.0, 0.05, 0.42))
    return P


def parts_sdf(P, x, y):
    sd = np.full(x.shape, 9.0)
    for q in P:
        if q[0] == "c":
            sd = np.minimum(sd, crescent(x, y, q[1], q[2], q[3], q[4], q[5], q[6]))
        else:
            sd = np.minimum(sd, circ(x, y, q[1], q[2], q[3]))
    return sd


def flame_burst(seed=1, frames=16, size=256, ss=2, kind="claw"):
    """Forma anime que se expande y luego se rompe en esquirlas filosas."""
    N = Noise(seed)
    rng = np.random.default_rng(seed)
    n = size * ss
    px = 2.0 / n
    X0, Y0 = grid(n)
    P = build_parts(kind, rng)
    nh = {"claw": 10, "burst": 12, "tongue": 9, "smoke": 10}[kind]
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        s = 0.3 + 0.7 * ease_out(min(t / 0.32, 1.0))
        spin = {"claw": 0.3, "burst": 0.2, "tongue": 0.05, "smoke": 0.12}[kind] * t
        x, y = rot(X0, Y0, -spin)
        w = 0.035 + 0.04 * t
        xw = x + N.fbm(x * 1.5 + 3, y * 1.5, 2) * w
        yw = y + N.fbm(x * 1.5, y * 1.5 + 5, 2) * w
        # erosión (agujeros que crecen) en coordenadas de la imagen
        Hh = holes_field(xw, yw, t, seed + 101, n=nh, start=(0.34, 0.66), speed=(0.65, 1.15), area=0.65)
        thin = 0.08 * smooth((t - 0.7) / 0.3)
        sd = parts_sdf(P, xw / s, yw / s) * s
        sdf = np.maximum(sd, -Hh) + thin
        # sombra: forma desplazada hacia la luz (arriba-izquierda)
        dx, dy = 0.05, -0.05
        sd2 = parts_sdf(P, (xw + dx) / s, (yw + dy) / s) * s
        H2 = holes_field(xw + dx, yw + dy, t, seed + 101, n=nh, start=(0.34, 0.66), speed=(0.65, 1.15), area=0.65)
        sdf_sh = np.maximum(sd2, -H2) + thin
        c, a = shade2(sdf, sdf_sh, px)
        out.append(pack(c, a, ss))
    return out


def shade2(sdf, sdf_sh, px, glow=0.2):
    inside = smooth(0.5 - sdf / px)
    rim_w = 2.4 * px
    col = np.full(sdf.shape, BODY)
    col = np.where(sdf_sh > 0.0, SHADE, col)              # banda de sombra (abajo-derecha)
    col = np.where((sdf_sh < -0.075) & (sdf < -0.03), HI, col)  # luz interior
    col = np.where(sdf > -rim_w, RIM, col)                # contorno
    halo = np.exp(-np.maximum(sdf, 0) / 0.025) * glow * (sdf > 0)
    a = np.clip(inside + halo, 0, 1)
    c = np.where(inside > 0.02, col, 190.0)
    return c, a


def spark_star(size=256, ss=2):
    n = size * ss
    px = 2.0 / n
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-9
    th = np.arctan2(y, x)
    # estrella de 4 puntas con lados cóncavos (filosa)
    k = np.abs(np.cos(2 * th))
    R = 0.18 + 0.78 * k ** 6
    sdf = (r - R) * 0.6
    sdf_off = np.where(sdf < 0, (np.sqrt((x + 0.05) ** 2 + (y - 0.05) ** 2) - R) * 0.6, 9.0)
    c, a = shade(sdf, -sdf_off, px, glow=0.35)
    return Image.fromarray(pack(c, a, ss), "RGBA")


def jagged_ring(size=512, ss=2, seed=3):
    """Anillo de onda con borde interior dentado y filoso (anime)."""
    rng = np.random.default_rng(seed)
    n = size * ss
    px = 2.0 / n
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    teeth = 18
    tooth = np.abs(((th / (2 * np.pi) * teeth) % 1.0) - 0.5) * 2   # 0 en el centro del diente
    inner = 0.62 + 0.14 * tooth ** 2 + 0.02 * np.sin(th * 5 + rng.uniform(0, 6))
    outer = 0.9
    sdf = np.maximum(r - outer, inner - r) * 0.7
    sdf_off = np.where(sdf < 0, np.maximum(r - (outer - 0.06), (inner + 0.06) - r) * 0.7, 9.0)
    c, a = shade(sdf, -sdf_off, px, glow=0.18)
    return Image.fromarray(pack(c, a, ss), "RGBA")


def swoosh(size=512, ss=2, seed=4):
    """Arco de viento/corte anime: media luna larga con puntas muy filosas."""
    n = size * ss
    px = 2.0 / n
    x, y = grid(n)
    sd = crescent(x, y, 0.0, -0.1, 0.8, np.pi / 2, cut=0.28, cut_r=0.97)
    sd2 = crescent(x + 0.03, y - 0.03, 0.0, -0.1, 0.8, np.pi / 2, cut=0.28, cut_r=0.97)
    sdf_off = np.where(sd < 0, -sd2, 9.0)
    c, a = shade(sd, -sdf_off, px, glow=0.2)
    return Image.fromarray(pack(c, a, ss), "RGBA")


def thin_streak(w=64, h=512, ss=2):
    """Hilo de luz fino y largo (cabeza arriba), para VelocityParallel."""
    W, H = w * ss, h * ss
    x = np.linspace(-1, 1, W)[None, :].repeat(H, 0)
    y = np.linspace(-1, 1, H)[:, None].repeat(W, 1)
    taper = np.clip(1 - np.abs(y), 0, 1) ** 0.5 * np.where(y > 0, 1.0, 0.7)
    width = 0.05 + 0.22 * taper
    core = np.exp(-(x / (width * 0.35)) ** 2) * taper
    a = np.clip(core * 1.6, 0, 1)
    rgb = np.full(x.shape, 255.0)
    img = np.stack([rgb * a, rgb * a, rgb * a, a * 255], -1)
    img = img.reshape(h, ss, w, ss, 4).mean(axis=(1, 3))
    al = img[..., 3:4]
    col = np.where(al > 0.5, img[..., :3] / np.maximum(al, 1e-6) * 255, 0)
    return Image.fromarray(np.concatenate([col, al], -1).clip(0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    jobs = {
        "ka_flame_claw_4x4.png": lambda: sheet(flame_burst(seed=11, kind="claw")),
        "ka_flame_claw2_4x4.png": lambda: sheet(flame_burst(seed=23, kind="claw")),
        "ka_fire_puff_4x4.png": lambda: sheet(flame_burst(seed=31, kind="burst")),
        "ka_flame_tongue_4x4.png": lambda: sheet(flame_burst(seed=41, kind="tongue")),
        "ka_smoke_4x4.png": lambda: sheet(flame_burst(seed=51, kind="smoke")),
        "ka_spark.png": spark_star,
        "ka_ring.png": jagged_ring,
        "ka_swoosh.png": swoosh,
        "ka_streak.png": thin_streak,
    }
    for name, fn in jobs.items():
        im = fn()
        im.save(os.path.join(OUT, name))
        print("OK", name, im.size)
    if len(sys.argv) > 2:
        # hoja de revisión: sobre blanco (como la referencia) y teñida de fuego sobre azul
        tiles = []
        for name in ["ka_flame_claw_4x4.png", "ka_fire_puff_4x4.png", "ka_flame_tongue_4x4.png", "ka_smoke_4x4.png"]:
            im = Image.open(os.path.join(OUT, name)).convert("RGBA")
            bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
            bg.alpha_composite(im)
            tiles.append(bg.convert("RGB").resize((512, 512)))
        prev = Image.new("RGB", (1024, 1024))
        for i, tl in enumerate(tiles):
            prev.paste(tl, ((i % 2) * 512, (i // 2) * 512))
        prev.save(sys.argv[2])
