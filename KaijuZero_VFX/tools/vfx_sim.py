"""Simulador de ParticleEmitter estilo Roblox para previsualizar VFX en video.

Reproduce lo esencial de ParticleEmitter: Emit(n) en tiempos dados, Lifetime,
Speed, SpreadAngle, EmissionDirection, forma esférica, Acceleration, Drag
(v·2^(-Drag·t)), Size/Transparency/Color como secuencias (con envelope),
Rotation/RotSpeed, Flipbooks (OneShot/Loop/Random), LightEmission (mezcla
alfa->aditiva), Brightness, ZOffset y Orientation (FacingCamera,
VelocityParallel, VelocityPerpendicular). También oculta lo que queda por
debajo del suelo, como hace el depth test de Roblox.

Unidades: studs; Y arriba (como Roblox).
"""
import copy
import math
import os
import random
import subprocess
import numpy as np
from PIL import Image

FPS = 60


# --------------------------------------------------------------- secuencias
def eval_seq(seq, t, r=0.0):
    """seq: [(time, value, envelope?)]; r in [-1,1] aleatorio por partícula."""
    if t <= seq[0][0]:
        k = seq[0]
        return k[1] + (k[2] if len(k) > 2 else 0) * r
    for a, b in zip(seq, seq[1:]):
        if t <= b[0]:
            u = (t - a[0]) / max(b[0] - a[0], 1e-9)
            va = a[1] + (a[2] if len(a) > 2 else 0) * r
            vb = b[1] + (b[2] if len(b) > 2 else 0) * r
            return va + (vb - va) * u
    k = seq[-1]
    return k[1] + (k[2] if len(k) > 2 else 0) * r


def eval_color(seq, t):
    if t <= seq[0][0]:
        return np.array(seq[0][1], float) / 255
    for a, b in zip(seq, seq[1:]):
        if t <= b[0]:
            u = (t - a[0]) / max(b[0] - a[0], 1e-9)
            return (np.array(a[1], float) * (1 - u) + np.array(b[1], float) * u) / 255
    return np.array(seq[-1][1], float) / 255


# --------------------------------------------------------------- texturas
class TexBank:
    def __init__(self, folder):
        self.folder = folder
        self.frames = {}
        self.cache = {}

    def get(self, name, layout):
        key = (name, layout)
        if key not in self.frames:
            im = Image.open(os.path.join(self.folder, name + ".png")).convert("RGBA")
            g = {"None": 1, "Grid2x2": 2, "Grid4x4": 4, "Grid8x8": 8}[layout]
            w, h = im.size[0] // g, im.size[1] // g
            fr = []
            for r in range(g):
                for c in range(g):
                    fr.append(im.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)))
            self.frames[key] = fr
        return self.frames[key]

    def sprite(self, name, layout, idx, w_px, h_px, angle):
        """Frame escalado a (w_px, h_px) y rotado `angle` grados (antihorario).
        Tamaños en escalones geométricos de 4% y ángulos de 3° para reutilizar el caché."""
        def q(v):
            v = max(1.0, float(v))
            return max(1, int(round(1.04 ** round(math.log(v) / math.log(1.04)))))
        # una partícula que pasa pegada a la cámara no puede pedir un sprite de miles de píxeles (memoria)
        k = min(1.0, 2600.0 / max(w_px, h_px, 1.0))
        w_px, h_px = q(w_px * k), q(h_px * k)
        a = int(round(angle / 3.0)) * 3 % 360
        key = (name, layout, idx, w_px, h_px, a)
        s = self.cache.get(key)
        if s is None:
            fr = self.get(name, layout)[idx]
            im = fr.resize((w_px, h_px), Image.BILINEAR)
            if a:
                im = im.rotate(a, resample=Image.BICUBIC, expand=True)
            s = np.asarray(im, dtype=np.uint8)      # en uint8: 4 veces más sprites en el caché
            self.bytes = getattr(self, "bytes", 0) + s.nbytes
            if self.bytes > 1.5e9:
                self.cache.clear()
                self.bytes = s.nbytes
            self.cache[key] = s
        return s.astype(np.float32) * (1.0 / 255.0)


# --------------------------------------------------------------- cámara
class Camera:
    def __init__(self, pos, target, fov=70.0, W=960, H=540):
        self.C = np.array(pos, float)
        self.T = np.array(target, float)
        self.W, self.H = W, H
        fwd = self.T - self.C
        fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 1, 0])
        right /= np.linalg.norm(right)
        up = np.cross(right, fwd)
        self.R = np.stack([right, up, fwd])  # filas: ejes cámara en mundo
        self.f = (H / 2) / math.tan(math.radians(fov) / 2)

    def to_cam(self, P):
        return self.R @ (np.asarray(P, float) - self.C)

    def project(self, P):
        d = self.to_cam(P)
        if d[2] <= 0.1:
            return None
        return (self.W / 2 + self.f * d[0] / d[2], self.H / 2 - self.f * d[1] / d[2], d[2])

    def ray(self, u, v):
        x = (u - self.W / 2) / self.f
        y = -(v - self.H / 2) / self.f
        d = self.R.T @ np.stack([x, y, np.ones_like(x)], 0).reshape(3, -1)
        return d / np.linalg.norm(d, axis=0)


# --------------------------------------------------------------- emisión
DIRS = {"Top": (0, 1, 0), "Bottom": (0, -1, 0), "Front": (0, 0, -1), "Back": (0, 0, 1),
        "Right": (1, 0, 0), "Left": (-1, 0, 0)}
# ejes sobre los que se reparte SpreadAngle (X, Y) para cada dirección
SPREAD_AXES = {"Top": ((1, 0, 0), (0, 0, 1)), "Bottom": ((1, 0, 0), (0, 0, 1)),
               "Front": ((1, 0, 0), (0, 1, 0)), "Back": ((1, 0, 0), (0, 1, 0)),
               "Right": ((0, 0, 1), (0, 1, 0)), "Left": ((0, 0, 1), (0, 1, 0))}


def rot_toward(d, axis, ang):
    """Gira el vector d hacia `axis` un ángulo ang (rad), en el plano (d, axis)."""
    d = np.asarray(d, float)
    a = np.asarray(axis, float)
    return d * math.cos(ang) + a * math.sin(ang)


def rand_unit(rng):
    while True:
        v = np.array([rng.uniform(-1, 1) for _ in range(3)])
        n = np.linalg.norm(v)
        if 0.05 < n <= 1:
            return v / n


class P:
    __slots__ = ("pos", "vel", "age", "life", "rot", "rots", "r_size", "r_tr", "frame0", "L", "seed", "ks", "spin",
                 "lock", "lofs", "gm")


def spawn(L, origin, rng, scale, Rf=None, length=0.0, zone=None):
    """Rf: rotación (3x3) del contenedor: lleva ejes locales del emisor a mundo.
    Ojo: Acceleration en Roblox es en espacio mundo (no se rota).
    zone: {"R", "H"} del pilar (velocidades speed_r / speed_h relativas al radio y a la altura)."""
    Rf = np.eye(3) if Rf is None else Rf
    p = P()
    p.ks = scale
    p.spin = 0.0
    p.lock = None                      # roca a la que va pegada (estela con LockedToPart)
    p.gm = 1.0                         # multiplicador de tamaño (capas que crecen con el proyectil)
    sh = L.get("shape")
    off = np.zeros(3)
    normal = None
    if sh and sh["type"] == "Sphere":
        u = rand_unit(rng)
        rad = sh["radius"] * scale * (1.0 if sh.get("style") == "Surface" else rng.random() ** (1 / 3))
        off = u * rad
        normal = u
    elif sh and sh["type"] == "Box":
        bx, by, bz = sh["size"]
        lz = length * sh["len_k"] if sh.get("len_k") else bz * scale      # a lo largo de toda la línea
        off = Rf @ np.array([rng.uniform(-0.5, 0.5) * bx * scale, rng.uniform(-0.5, 0.5) * by * scale,
                             rng.uniform(-0.5, 0.5) * lz])
    p.pos = np.asarray(origin, float) + off + Rf @ (np.asarray(L.get("offset", (0, 0, 0)), float) * scale)
    inout = (L.get("shape") or {}).get("inout", "Outward")
    if normal is not None and inout in ("Outward", "Inward"):
        d = normal if inout == "Outward" else -normal
        ax1 = np.cross(d, [0, 1, 0]) if abs(d[1]) < 0.95 else np.array([1.0, 0, 0])
        ax1 /= np.linalg.norm(ax1)
        ax2 = np.cross(d, ax1)
    else:
        dname = L.get("direction", "Top")
        d = Rf @ np.array(DIRS[dname], float)
        ax1, ax2 = (Rf @ np.array(a, float) for a in SPREAD_AXES[dname])
    sx, sy = L.get("spread", (0, 0))
    d = rot_toward(d, ax1, math.radians(rng.uniform(-sx, sx)))
    d = rot_toward(d, ax2, math.radians(rng.uniform(-sy, sy)))
    d /= np.linalg.norm(d)
    if L.get("speed_len"):          # velocidad proporcional al largo del efecto (la ola cruza el triángulo)
        spd = rng.uniform(*L["speed_len"]) * length
    elif L.get("speed_h"):          # fracción de la altura del pilar por segundo
        spd = rng.uniform(*L["speed_h"]) * zone["H"]
    elif L.get("speed_r"):          # fracción del radio de la zona por segundo
        spd = rng.uniform(*L["speed_r"]) * zone["R"]
    else:
        spd = rng.uniform(*L.get("speed", (0, 0))) * scale
    p.vel = d * spd
    p.age = 0.0
    p.life = rng.uniform(*L["lifetime"])
    p.rot = rng.uniform(*L.get("rotation", (0, 0)))
    p.rots = rng.uniform(*L.get("rot_speed", (0, 0)))
    p.r_size = rng.uniform(-1, 1)
    p.r_tr = rng.uniform(-1, 1)
    fb = L.get("flipbook")
    n = {"None": 1, "Grid2x2": 4, "Grid4x4": 16, "Grid8x8": 64}[fb[0]] if fb else 1
    p.frame0 = rng.randrange(n) if (fb and fb[3]) else 0
    p.L = L
    p.seed = rng.random()
    return p


# --------------------------------------------------------------- render
def draw_sprite(buf, spr, cx, cy, light, bright, mask_fn=None):
    h, w = spr.shape[:2]
    x0, y0 = int(round(cx - w / 2)), int(round(cy - h / 2))
    H, W = buf.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xa >= xb or ya >= yb:
        return
    s = spr[ya - y0:yb - y0, xa - x0:xb - x0]
    a = s[..., 3:4]
    if mask_fn is not None:
        a = a * mask_fn(xa, ya, xb, yb)[..., None]
    rgb = s[..., :3] * bright
    dst = buf[ya:yb, xa:xb]
    dst *= (1 - a * (1 - light))
    dst += rgb * a


def apply_screen(buf, Sc, t, cam, o0, zone):
    """La corrección de color (ColorCorrectionEffect) y el destello de pantalla de una ULTIMATE, como runScreen en el
    módulo: se nota entero dentro de la zona y se apaga a Sc["range"] × radio."""
    d = math.hypot(cam.C[0] - o0[0], cam.C[2] - o0[2])
    k = min(max(1 - (d - zone["R"]) / max((Sc["range"] - 1) * zone["R"], 1.0), 0.0), 1.0)
    rows = Sc["cc"]
    v = [float(np.interp(t, [r[0] for r in rows], [r[j] for r in rows])) for j in range(1, 7)]
    b, c, sat = v[0] * k, v[1] * k, v[2] * k
    tint = np.array([1 - (1 - v[3] / 255) * k, 1 - (1 - v[4] / 255) * k, 1 - (1 - v[5] / 255) * k], np.float32)
    out = np.clip(buf, 0, None) + b
    out = (out - 0.5) * (1 + c) + 0.5
    gray = (out @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
    out = gray + (out - gray) * (1 + sat)
    out = out * tint
    al = 0.0
    for (ft, fa, up, down) in Sc["flash"]:
        tt = t - ft
        if tt >= 0:
            w = tt / up if tt < up else 1 - min(max((tt - up) / down, 0.0), 1.0)
            al = max(al, w * fa)
    if al > 0:
        out = out * (1 - al * k) + np.array(Sc["flash_color"], np.float32) / 255 * al * k
    return out.astype(np.float32)


def apply_bloom(buf, threshold=0.92, intensity=0.55, sigmas=(4, 14)):
    """Bloom simple: lo que pasa del umbral (HDR por suma aditiva) se difumina y se suma."""
    from scipy.ndimage import gaussian_filter
    bright = np.clip(buf - threshold, 0, None)
    if bright.max() <= 0:
        return buf
    acc = np.zeros_like(buf)
    for sg in sigmas:
        acc += gaussian_filter(bright, sigma=(sg, sg, 0))
    return buf + acc * (intensity / len(sigmas)) * 2.0


class Meteor:
    __slots__ = ("pos", "vel", "age", "life", "rot", "rots", "size", "frame", "L", "acc", "landed", "dead", "stuck_until",
                 "R3", "axis", "spin", "col")


def spawn_meteor(L, origin, rng, scale, Rf):
    m = Meteor()
    dname = L.get("direction", "Top")
    d = Rf @ np.array(DIRS[dname], float)
    ax1, ax2 = (Rf @ np.array(a, float) for a in SPREAD_AXES[dname])
    sx, sy = L.get("spread", (0, 0))
    d = rot_toward(d, ax1, math.radians(rng.uniform(-sx, sx)))
    d = rot_toward(d, ax2, math.radians(rng.uniform(-sy, sy)))
    d /= np.linalg.norm(d)
    m.pos = np.asarray(origin, float) + Rf @ (np.asarray(L.get("offset", (0, 0, 0)), float) * scale)
    sh = L.get("shape")
    if sh and sh.get("type") == "Box":           # cada pieza sale de un punto al azar de la caja
        b = np.asarray(sh["size"], float)
        m.pos = m.pos + Rf @ (np.array([rng.uniform(-0.5, 0.5) for _ in range(3)]) * b * scale)
    m.vel = d * rng.uniform(*L["speed"]) * scale
    m.age = 0.0
    m.life = rng.uniform(*L["lifetime"])
    sp = L["sprite"]
    m.size = rng.uniform(*sp["size"]) * scale
    m.rot = 0.0 if sp.get("upright") else rng.uniform(0, 360)
    m.rots = rng.uniform(*sp.get("rot_speed", (0, 0)))
    m.frame = sp.get("frame", rng.randrange(4))
    m.stuck_until = None
    if sp.get("cube"):                           # se dibuja como lo que es en Roblox: un bloque que da vueltas
        m.R3 = axis_angle((0, 1, 0), rng.uniform(0, 6.28)) if sp.get("upright") else \
            orthonormal(np.array([[rng.uniform(-1, 1) for _ in range(3)] for _ in range(3)]))
        m.axis = np.array([rng.uniform(-1, 1) for _ in range(3)])
        m.spin = math.radians(rng.uniform(*sp.get("rot_speed", (0, 0))))
        base = np.array(sp.get("preview_color", sp.get("color", (255, 255, 255))), float) / 255
        m.col = np.clip(base * rng.uniform(*sp.get("color_var", (1.0, 1.0))), 0, 1)
    m.L = L
    m.acc = [0.0] * len(L.get("trails", []))
    m.landed = False
    m.dead = False
    return m


class OrbSim:
    """Proyectil que crece (agujero negro): la misma trayectoria, el mismo radio y las mismas capas que
    orbAt / runOrb en el módulo Luau."""

    def __init__(self, spec, A, B, scale, cam, ground_y):
        self.O = spec["orb"]
        self.A, self.B, self.s, self.gy = A, B, scale, ground_y
        self.pos, self.r, self.rr, self.done = A.copy(), 0.0, 0.02 * scale, False
        self.layers = [L for L in spec["layers"] if L.get("orb")]
        self.acc = {id(L): 0.0 for L in self.layers}
        self.ei = {id(L): 0 for L in self.layers}
        self.grow = []
        self.R = self.frame(cam)

    def frame(self, cam):
        """Mira hacia donde va; el eje del disco ("Top") se inclina tilt grados hacia la cámara."""
        d = self.B - self.A
        d = np.array([d[0], 0.0, d[2]])
        d = d / np.linalg.norm(d) if np.linalg.norm(d) > 1e-3 else np.array([0.0, 0.0, -1.0])
        up = np.array([0.0, 1.0, 0.0])
        side = cam.C - (self.A + self.B) * 0.5
        side = np.array([side[0], 0.0, side[2]])
        if np.linalg.norm(side) > 1e-3:
            a = math.radians(self.O["tilt"])
            up = up * math.cos(a) + side / np.linalg.norm(side) * math.sin(a)
            up /= np.linalg.norm(up)
        look = d - up * (d @ up)
        look /= np.linalg.norm(look)
        right = np.cross(look, up)
        return np.stack([right, up, -look], axis=1)

    def at(self, t):
        O, s, S = self.O, self.s, self.O["size"]
        if t < O["travel"][0]:
            u = min(1.0, max(0.0, (t - O["form"][0]) / max(O["form"][1] - O["form"][0], 1e-3)))
            return self.A.copy(), S[1] * (1 - (1 - u) ** 2) * s
        if t < O["travel"][1]:
            u = (t - O["travel"][0]) / max(O["travel"][1] - O["travel"][0], 1e-3)
            e = u * u * (3 - 2 * u)
            p = self.A + (self.B - self.A) * e + np.array([0.0, O["arc"] * s * math.sin(math.pi * u), 0.0])
            return p, (S[1] + (S[2] - S[1]) * u ** 0.9) * s
        if t < O["collapse"][0]:
            return self.B.copy(), S[2] * s
        u = min(1.0, max(0.0, (t - O["collapse"][0]) / max(O["collapse"][1] - O["collapse"][0], 1e-3)))
        return self.B.copy(), (S[2] + (S[3] - S[2]) * u * u) * s

    def spawn(self, L, rng):
        s, rr = self.s, self.rr
        if L.get("shell") or L.get("shell_abs"):
            rad = L["shell"] * rr if L.get("shell") else L["shell_abs"] * s
            u = rand_unit(rng)
            p = spawn(L, self.pos + u * rad, rng, s, self.R)
            p.vel = -u * rng.uniform(*L["speed"]) * (rr if L.get("shell") else s)
        elif L["orb"] == "ground":
            p = spawn(L, np.array([self.pos[0], self.gy, self.pos[2]]), rng, s, None)
        else:
            p = spawn(L, self.pos, rng, s, self.R)
        if L.get("locked") or L.get("shell") or L.get("shell_abs"):
            p.lock, p.lofs = self, p.pos - self.pos
        if L.get("grow"):
            p.gm = rr / s
            self.grow.append(p)
        return p

    def step(self, t, dt, rng):
        if self.done:
            return []
        self.pos, self.r = self.at(t)
        self.rr = max(self.r, 0.02 * self.s)
        out = []
        for L in self.layers:
            n = 0
            evs, i = L.get("emit", []), self.ei[id(L)]
            while i < len(evs) and evs[i][0] <= t + 1e-9:
                n += evs[i][1]
                i += 1
            self.ei[id(L)] = i
            rate = 0.0
            for (a0, a1, r0, r1) in L.get("stream", []):
                if a0 <= t <= a1:
                    rate += r0 + (r1 - r0) * (t - a0) / max(a1 - a0, 1e-6)
            self.acc[id(L)] += rate * dt
            while self.acc[id(L)] >= 1.0:
                self.acc[id(L)] -= 1.0
                n += 1
            out += [self.spawn(L, rng) for _ in range(n)]
        self.grow = [p for p in self.grow if p.age < p.life]
        for p in self.grow:          # el emisor cambia su Size cada cuadro: también las ya emitidas
            p.gm = self.rr / self.s
        if t >= self.O["collapse"][1]:
            self.done = True
        return out

    def lens(self, cam):
        """(centro, radio) de la lente de vidrio detrás del agujero, o None."""
        if self.done or not self.O.get("lens") or self.r < 0.1 * self.s:
            return None
        lr = self.O["lens"] * self.r
        away = self.pos - cam.C
        return self.pos + away / np.linalg.norm(away) * lr * 1.05, lr


def apply_lens(buf, cam, center, radius, strength=0.5):
    """Refracción del vidrio (como el Glass de Roblox con gráficos altos): lo de detrás se ve aumentado
    hacia el centro y algo más oscuro y azulado."""
    from scipy.ndimage import map_coordinates
    pr = cam.project(center)
    if pr is None:
        return
    cx, cy, z = pr
    Rp = cam.f * radius / z
    H, W = buf.shape[:2]
    x0, x1 = max(0, int(cx - Rp)), min(W, int(cx + Rp) + 1)
    y0, y1 = max(0, int(cy - Rp)), min(H, int(cy + Rp) + 1)
    if Rp < 3 or x0 >= x1 or y0 >= y1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs + 0.5 - cx, ys + 0.5 - cy
    d = np.sqrt(dx * dx + dy * dy) / Rp
    k = strength * np.clip(1 - d * d, 0, 1) ** 1.5       # aumenta hacia el centro y dobla lo de alrededor
    sx, sy = cx + dx * (1 - k) - 0.5, cy + dy * (1 - k) - 0.5
    src = np.stack([map_coordinates(buf[..., ch], [sy, sx], order=1, mode="nearest") for ch in range(3)], -1)
    w = np.clip((1 - d) / 0.15, 0, 1)[..., None]
    src = src * np.array([0.8, 0.84, 1.0], np.float32)
    dst = buf[y0:y1, x0:x1]
    dst[:] = dst * (1 - w) + src * w


def smooth_noise(seed, x):
    """Ruido suave en -1..1 (para el pulso del rayo; en Roblox es math.noise)."""
    return 0.5 * math.sin(x * 1.7 + seed) + 0.3 * math.sin(x * 3.1 + seed * 2.3) + 0.2 * math.sin(x * 5.3 + seed * 0.7)


def draw_beam(buf, tb, cam, Bm, A, Bp, w, fade, t, scale):
    """Beam de Roblox (FaceCamera): cinta recta de A a Bp que en cada punto se gira hacia la cámara, con la
    textura a lo largo (Wrap: se repite cada tex_len studs y corre hacia Bp a 'speed' repeticiones por segundo;
    Stretch: una vez). Cada píxel busca el punto del eje más cercano a su rayo: la distancia es el ancho."""
    d = Bp - A
    Ln = float(np.linalg.norm(d))
    if Ln < 1e-3:
        return
    d = d / Ln
    w0, w1 = w * Bm["w0"], w * Bm["w1"]
    # recuadro en pantalla: los extremos (recortados delante de la cámara) más el medio ancho en píxeles
    zA, zB = cam.to_cam(A)[2], cam.to_cam(Bp)[2]
    near = 0.6
    if zA < near and zB < near:
        return
    A_, B_ = A, Bp
    if zA < near:
        A_ = A + (Bp - A) * (near - zA) / (zB - zA)
    elif zB < near:
        B_ = Bp + (A - Bp) * (near - zB) / (zA - zB)
    H, W = buf.shape[:2]
    xs, ys = [], []
    for P_, ww in ((A_, max(w0, w1)), (B_, max(w0, w1))):
        q = cam.project(P_)
        if q is None:
            continue
        hw = cam.f * ww / 2 / q[2] + 2
        xs += [q[0] - hw, q[0] + hw]
        ys += [q[1] - hw, q[1] + hw]
    if not xs:
        return
    xa, xb = max(0, int(min(xs))), min(W, int(max(xs)) + 1)
    ya, yb = max(0, int(min(ys))), min(H, int(max(ys)) + 1)
    if xa >= xb or ya >= yb:
        return
    us, vs = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
    r = cam.ray(us.ravel(), vs.ravel())                      # 3 x N, unitarios
    w0v = cam.C - A
    bb = d @ r
    dd = r.T @ w0v
    ee = float(d @ w0v)
    den = np.maximum(1 - bb * bb, 1e-9)
    tt = (bb * ee - dd) / den                                 # a lo largo del rayo del píxel
    sl = (ee - bb * dd) / den                                 # a lo largo del eje del Beam
    Pa = A[:, None] + d[:, None] * sl
    toc = cam.C[:, None] - Pa
    nrm = toc - d[:, None] * (d @ toc)                          # la cinta mira a la cámara en ese punto del eje
    nrm /= np.maximum(np.linalg.norm(nrm, axis=0), 1e-9)
    side = np.cross(d, nrm.T).T                                 # dirección del ancho
    # el rayo del píxel contra el plano de la cinta en ese punto (visto casi de punta, el plano se pierde)
    den2 = np.sum(r * nrm, axis=0)
    t2 = np.sum((Pa - cam.C[:, None]) * nrm, axis=0) / np.where(np.abs(den2) < 1e-6, 1e-6, den2)
    diff = cam.C[:, None] + r * t2 - Pa
    sl = sl + d @ diff
    q = np.sum(diff * side, axis=0)
    fr = np.clip(sl / Ln, 0, 1)
    wl = w0 + (w1 - w0) * fr
    ok = (sl >= 0) & (sl <= Ln) & (np.abs(q) <= wl / 2) & (t2 > 0) & (np.abs(den2) > 0.05)
    if not ok.any():
        return
    T = np.asarray(tb.get(Bm["texture"], "None")[0], dtype=np.float32) / 255.0
    th, tw = T.shape[:2]
    v = q / np.maximum(wl, 1e-6) + 0.5
    if Bm["mode"] == "Wrap":
        u = (sl / (Bm["tex_len"] * scale) - Bm["speed"] * t) % 1.0
    else:
        u = fr
    ix = np.clip((u * tw).astype(int), 0, tw - 1)
    iy = np.clip((v * th).astype(int), 0, th - 1)
    smp = T[iy, ix]
    smp[~ok] = 0
    keys = [k[0] for k in Bm["color"]]
    col = np.stack([np.interp(fr, keys, [k[1][c] / 255 for k in Bm["color"]]) for c in range(3)], -1)
    tr = np.interp(fr, [k[0] for k in Bm["transparency"]], [k[1] for k in Bm["transparency"]])
    tr = tr + (1 - tr) * fade
    smp = smp.reshape(yb - ya, xb - xa, 4)
    rgb = smp[..., :3] * col.reshape(yb - ya, xb - xa, 3) * Bm["brightness"]
    a = smp[..., 3:4] * (1 - tr).reshape(yb - ya, xb - xa, 1)
    le = Bm["light_emission"]
    dst = buf[ya:yb, xa:xb]
    dst *= (1 - a * (1 - le))
    dst += rgb * a



def rot_x(a):
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def rot_y(a):
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rot_z(a):
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def ease_out_back(p, k=1.6):
    p = min(max(p, 0.0), 1.0) - 1
    return 1 + p * p * ((k + 1) * p + k)


SIZE_KEYS = ("wid", "thick", "len", "tilt")


def make_slab(rng, SL, s, x, z, across_yaw, side, t_s):
    """Una losa o bloque que salta del suelo (igual que makeSlab en el módulo). (x, z) local; se inclina
    hacia across_yaw (radianes en el plano X-Z): el borde de adentro asoma y el de afuera queda enterrado.
    Con "ice" una fracción son de hielo (y pueden tener su propio tamaño); "big" agranda unas pocas."""
    ice = bool(SL.get("ice")) and rng.random() < SL["ice"].get("frac", 1.0)
    P = dict(SL, **{k: v for k, v in SL["ice"].items() if k in SIZE_KEYS}) if ice else SL
    k = SL["big"]["k"] if SL.get("big") and rng.random() < SL["big"]["frac"] else 1.0
    w = rng.uniform(*P["wid"]) * s * k
    th = rng.uniform(*P["thick"]) * s * k
    ln = rng.uniform(*P["len"]) * s * k
    a = math.radians(rng.uniform(*P["tilt"]))
    x += side * w / 2 * math.cos(a) * math.cos(across_yaw)
    z += side * w / 2 * math.cos(a) * math.sin(across_yaw)
    R3 = rot_y(-across_yaw + math.radians(rng.uniform(-SL["yaw"], SL["yaw"]))) @ \
        rot_x(math.radians(rng.uniform(-SL["pitch"], SL["pitch"]))) @ rot_z(-side * a)
    top = w / 2 * math.sin(a) + th / 2 * math.cos(a)            # del centro a la esquina más alta
    y0 = top * (2 * SL["show"] - 1)                              # show = qué fracción asoma del suelo
    return {"t": t_s, "x": x, "z": z, "size": (w, th, ln), "R3": R3, "y0": y0, "drop": y0 + top + 0.3 * s,
            "hold": rng.uniform(*SL["hold"]), "rise": SL["rise"], "sink": SL["sink"],
            "ice": SL["ice"] if ice else None, "shatter": SL.get("end") == "shatter", "L": SL,
            "tip_s": SL["tip"] * min(w, ln) if SL.get("tip") else 0.0}


# la punta de un cristal: un cubo parado sobre un vértice (su diagonal (1, 1, 1) hacia arriba) en la cara de arriba
TIP_ROT = None


def tip_rot():
    global TIP_ROT
    if TIP_ROT is None:
        TIP_ROT = axis_angle(np.array([-1.0, 0.0, 1.0]) / math.sqrt(2), math.acos(1 / math.sqrt(3)))
    return TIP_ROT


def slab_poses(slabs, t, o0, Rf, ground_y):
    """(centro, giro, tamaño, losa) de las losas visibles en t. Suben con un rebote, se quedan y se hunden (o,
    con end = "shatter", desaparecen de golpe al terminar: ahí revientan en partículas)."""
    out = []
    for L in slabs:
        age = t - L["t"]
        if age < 0:
            continue
        if age < L["rise"]:
            y = L["y0"] - L["drop"] * (1 - ease_out_back(age / L["rise"]))
        elif age < L["rise"] + L["hold"]:
            y = L["y0"]
        elif not L["shatter"] and age < L["rise"] + L["hold"] + L["sink"]:
            p = (age - L["rise"] - L["hold"]) / L["sink"]
            y = L["y0"] - L["drop"] * p * p
        else:
            continue
        P = o0 + Rf @ np.array([L["x"], 0.0, L["z"]])
        P[1] = ground_y + y
        R3 = Rf @ L["R3"]
        out.append((P, R3, L["size"], L))
        if L.get("tip_s"):
            ts = L["tip_s"]
            out.append((P + R3 @ np.array([0.0, L["size"][1] / 2, 0.0]), R3 @ tip_rot(), (ts, ts, ts), L))
    return out


def wave_u(wave, t):
    """Hasta dónde llegó el frente de la ola (fracción del largo) en t: sale rápido y se va frenando (ease)."""
    T0, TW = wave[0], wave[1]
    ease = wave[2] if len(wave) > 2 else 1.0
    p = min(max((t - T0) / TW, 0.0), 1.0)
    return 1 - (1 - p) ** ease


def wave_t(wave, u):
    """Cuándo el frente llega a u (la inversa de wave_u)."""
    T0, TW = wave[0], wave[1]
    ease = wave[2] if len(wave) > 2 else 1.0
    return T0 + TW * (1 - (1 - min(max(u, 0.0), 1.0)) ** (1 / ease))


class ConeFront:
    """Emisores que viajan con el frente de la ola triangular (lo mismo que runFront en el módulo): `count` puntos
    repartidos a lo ancho del frente; cada capa suelta partículas por tasa (más cuanto más ancho está el frente) en
    la dirección del abanico. Como nacen en el frente y se frenan, dejan detrás una estela espesa."""

    def __init__(self, Fr, length, angle, scale):
        self.Fr, self.len, self.s = Fr, length, scale
        self.tanH = math.tan(math.radians(angle / 2))
        K, sm = Fr["count"], Fr["s_max"]
        self.S = [-sm + 2 * sm * (k + 0.5) / K for k in range(K)]
        self.acc = {}

    def step(self, t, dt, o0, Rf, rng):
        W = self.Fr["wave"]
        if t < W[0] or t > W[0] + W[1]:
            return []
        u = wave_u(W, t)
        out = []
        for ei, E in enumerate(self.Fr["emitters"]):
            rate = E["rate"] * (0.25 + 0.75 * u)
            pt = math.radians(E.get("pitch", 0.0))
            Rx = np.array([[1, 0, 0], [0, math.cos(pt), -math.sin(pt)], [0, math.sin(pt), math.cos(pt)]])
            for k, sk in enumerate(self.S):
                key = (ei, k)
                self.acc[key] = self.acc.get(key, 0.0) + rate * dt
                if self.acc[key] < 1.0:
                    continue
                P = o0 + Rf @ np.array([sk * u * self.len * self.tanH, E.get("up", 0.0) * self.s, -u * self.len])
                phi = -math.atan(sk * self.tanH)
                Ry = np.array([[math.cos(phi), 0, math.sin(phi)], [0, 1, 0], [-math.sin(phi), 0, math.cos(phi)]])
                while self.acc[key] >= 1.0:
                    self.acc[key] -= 1.0
                    out.append(spawn(E, P, rng, self.s, Rf @ Ry @ Rx, self.len))
        return out


class ConeField:
    """Lo que la ola triangular deja a su paso (lo mismo que runField en el módulo): grupos de bloques y losas
    repartidos por el triángulo (más donde es más ancho) que saltan cuando pasa el frente (t = wave[0] +
    wave[1]·u) y se quedan; los de hielo revientan al final."""

    def __init__(self, F, length, angle, scale):
        self.F, self.len, self.s = F, length, scale
        tanH = math.tan(math.radians(angle / 2))
        rng = random.Random(F.get("seed", 9))
        self.slabs = []
        for G in F["groups"]:
            for _ in range(G["count"]):
                u0, u1 = G["u"]
                u = math.sqrt(rng.uniform(u0 * u0, u1 * u1))
                x = rng.uniform(*G["s"]) * u * length * tanH
                z = -u * length
                yaw = math.atan2(z, x) if G.get("lean") == "radial" else rng.uniform(0, 2 * math.pi)
                t_s = wave_t(F["wave"], u) + rng.uniform(*G["delay"])
                self.slabs.append(make_slab(rng, G, scale, x, z, yaw, 1, t_s))


class ZoneField:
    """Cristales y losas que brotan en una zona circular (lo mismo que runZoneField en el módulo). Cada grupo reparte
    `count` piezas entre r = (r0, r1) (fracción del radio; ring = parejas alrededor del anillo); brotan cuando la
    onda que sale del centro llega a su radio (t + sweep·r) y se inclinan hacia afuera (lean = "radial"). Con end_at
    = (t0, t1) todas terminan a la vez: las de hielo (end = "shatter") revientan. Los tamaños siguen al radio."""

    def __init__(self, F, zone, scale, radius0):
        rng = random.Random(F.get("seed", 9))
        R = zone["R"]
        k = self.k = R / radius0
        self.slabs = []
        for G in F["groups"]:
            G = dict({"hold": (1.0, 1.0), "sink": 0.4}, **G)
            n = G["count"]
            for i in range(n):
                if G.get("ring"):
                    ang = 2 * math.pi * (i + rng.uniform(-0.35, 0.35)) / n
                    r = rng.uniform(*G["r"])
                else:
                    ang = rng.uniform(0, 2 * math.pi)
                    r = math.sqrt(rng.uniform(G["r"][0] ** 2, G["r"][1] ** 2))
                x, z = math.cos(ang) * r * R, math.sin(ang) * r * R
                yaw = ang if G.get("lean") == "radial" else rng.uniform(0, 2 * math.pi)
                t_s = G["t"] + G.get("sweep", 0.0) * r + rng.uniform(*G["delay"])
                SL = make_slab(rng, G, k, x, z, yaw, 1, t_s)
                if G.get("end_at"):
                    SL["hold"] = max(0.05, rng.uniform(*G["end_at"]) - t_s - SL["rise"])
                self.slabs.append(SL)


class BladeGeo:
    """La media luna de energía que vuela (lo mismo que runBlade en el módulo). Va vertical y de canto: de lado se ve
    la media luna (la punta adelante, los cuernos atrás) y desde atrás, una hoja fina que apunta hacia donde va.
    Está hecha de trazos finos (strands): j = 0 es el filo de afuera y j = 1 el borde de adentro; cada trazo es un
    arco de radio (1 - shrink·j)·R que empieza thick·R·j detrás de la punta y abarca arc_k·arc grados hacia cada
    cuerno. Adelante = -Z local. Su cuerno de abajo roza el suelo: ahí corta (gash), las losas del suelo saltan a los
    lados (slabs) y al final queda un cráter de losas (crater)."""

    def __init__(self, B, length, scale):
        self.B, self.len, self.s = B, length, scale
        self.arc, tl = math.radians(B["arc"]), math.radians(B["tilt"])
        self.axis = np.array([math.sin(tl), math.cos(tl), 0.0])
        self.n = B["n"]
        # lo más bajo de la hoja (por unidad de radio): roza el suelo y ahí corta
        self.ymin, self.low_x, self.low_z = 0.0, 0.0, 0.0
        for S_ in B["strands"]:
            for i in range(self.n):
                P = self.local(S_, i / (self.n - 1), 0.0, 1.0, 0.0)
                if P[1] < self.ymin:
                    self.ymin, self.low_x, self.low_z = P[1], P[0], P[2]
        self.slabs = self._make_slabs()

    def local(self, S_, sm, d, R, h):
        """Punto (local) del trazo S_ en sm (0..1, de un cuerno al otro) con la punta a d studs del origen."""
        a = self.arc * S_.get("arc_k", 1.0)
        th = -a + 2 * a * sm
        Rj = R * (1 - self.B["shrink"] * S_["j"])
        back = self.B["thick"] * R * S_["j"]
        return np.array([0.0, h, -d + back + Rj * (1 - math.cos(th))]) + self.axis * (Rj * math.sin(th))

    def state(self, t):
        """(u, k, R, h, fade) en t, o None si la hoja no está."""
        B = self.B
        t0, tw, fd = B["t0"], B["travel"], B["fade"]
        if t < t0 or t > t0 + tw + fd:
            return None
        u = min(max((t - t0) / tw, 0.0), 1.0)
        gr = min(max((t - t0) / max(B["grow"], 1e-3), 0.0), 1.0)
        gr = gr * gr * (3 - 2 * gr)
        k = self.s * (B["start_k"] + (1 - B["start_k"]) * gr)
        fz = min(max((t - t0 - tw) / max(fd, 1e-3), 0.0), 1.0)
        R = B["radius"] * k
        return u, k, R, B["lift"] * self.s - R * self.ymin, fz * fz * (3 - 2 * fz)

    def chains(self, t, o0, Rf):
        """Por trazo: (puntos, anchos, transparencia, trazo)."""
        st = self.state(t)
        if st is None:
            return []
        u, k, R, h, fade = st
        d, n, out = self.len * u, self.n, []
        for S_ in self.B["strands"]:
            tr = 1 - (1 - S_["transparency"]) * (1 - fade)
            pts = [o0 + Rf @ self.local(S_, i / (n - 1), d, R, h) for i in range(n)]
            ws = [S_["width"] * k * max(math.sin(math.pi * i / (n - 1)), 0.0) ** self.B["taper"] for i in range(n)]
            out.append((pts, ws, tr, S_))
        return out

    def emit_points(self, t, o0, Rf, E):
        """Dónde están los emisores de la estela (pegados a la hoja) mientras vuela."""
        B = self.B
        if t < B["t0"] or t > B["t0"] + B["travel"]:
            return []
        u, k, R, h, fade = self.state(t)
        S_ = {"j": E.get("j", 0.0), "arc_k": E.get("arc_k", 1.0)}
        return [o0 + Rf @ self.local(S_, sm, self.len * u, R, h) for sm in E["at"]]

    # ---------------------------------------------------------------- el corte del suelo
    def R_full(self):
        return self.B["radius"] * self.s

    def cut_head(self, t):
        """Hasta dónde va el corte (studs desde el origen) en t."""
        st = self.state(min(t, self.B["t0"] + self.B["travel"]))
        if st is None:
            return -1.0
        u, k, R, h, fade = st
        return self.len * u - self.low_z * R

    def cut_time(self, x):
        """Cuándo el corte llega a x (studs desde el origen)."""
        B = self.B
        return B["t0"] + B["travel"] * min(max((x + self.low_z * self.R_full()) / self.len, 0.0), 1.0)

    def gash(self, t):
        """Los tramos del corte: (desde, hasta, lado, edad); edad = s desde que el corte pasó por el inicio."""
        G = self.B.get("gash")
        if not G or t < self.B["t0"]:
            return []
        seg = G["seg"] * self.s
        head = self.cut_head(t)
        side = self.low_x * self.R_full()
        out, a = [], G.get("start", 0.0) * self.s
        while a < self.len - 1e-6:
            b = min(a + seg, self.len)
            vis = min(head, b) - a
            if vis > 0.05:
                out.append((a, a + vis, side, t - self.cut_time(a)))
            a = b
        return out

    # ---------------------------------------------------------------- las losas del suelo
    def _make_slabs(self):
        B, s, out = self.B, self.s, []
        SL = B.get("slabs")
        if SL:          # dos filas de losas a los lados del corte, que saltan cuando pasa
            rng = random.Random(SL.get("seed", 5))
            xc = self.low_x * self.R_full()
            z, zend = SL["start"] * s, self.len - self.low_z * self.R_full()
            while z < zend:
                for side in (-1, 1):
                    zz = z + rng.uniform(-0.3, 0.3) * SL["spacing"] * s
                    t_s = self.cut_time(zz) + rng.uniform(0, SL["delay"])
                    out.append(make_slab(rng, SL, s, xc + side * SL["gap"] * s, -zz, 0.0, side, t_s))
                z += SL["spacing"] * s
        CR = B.get("crater")
        if CR:          # el cráter de la detonación: losas en anillo, inclinadas hacia afuera
            rng = random.Random(CR.get("seed", 6))
            for i in range(CR["count"]):
                phi = 2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / CR["count"]
                r = CR["radius"] * s * rng.uniform(0.85, 1.15)
                t_s = B["t0"] + B["travel"] + CR["at"] + rng.uniform(0, CR["delay"])
                out.append(make_slab(rng, CR, s, r * math.cos(phi), -self.len + r * math.sin(phi), phi, 1, t_s))
        return out

    def slab_poses(self, t, o0, Rf, ground_y):
        return slab_poses(self.slabs, t, o0, Rf, ground_y)


def blade_chains(B, t, o0, Rf, length, scale):
    """Compatibilidad: las cadenas de la media luna en t."""
    return BladeGeo(B, length, scale).chains(t, o0, Rf)


def draw_box(buf, cam, pr_):
    """Caja sombreada de referencia (p. ej. un enemigo) apoyada en pos (centro de la base)."""
    from PIL import ImageDraw
    pos = np.asarray(pr_["pos"], float)
    sx, sy, sz = pr_["size"]
    col = np.array(pr_["color"], float) / 255
    ctr = pos + np.array([0.0, sy / 2, 0.0])
    half = np.array([sx / 2, sy / 2, sz / 2])
    H, W = buf.shape[:2]
    for f, nrm in zip(CubeSim.FACES, CubeSim.NORMALS):
        n = np.array(nrm, float)
        fc = ctr + n * half
        if n @ (cam.C - fc) <= 0:
            continue
        pts = [cam.project(ctr + np.array(q, float) * half) for q in f]
        if any(q is None for q in pts):
            return
        xs, ys = [q[0] for q in pts], [q[1] for q in pts]
        x0, y0 = max(0, int(min(xs)) - 1), max(0, int(min(ys)) - 1)
        x1, y1 = min(W, int(max(xs)) + 2), min(H, int(max(ys)) + 2)
        if x0 >= x1 or y0 >= y1:
            continue
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in zip(xs, ys)], fill=255)
        mm = np.asarray(m, np.float32)[..., None] / 255
        shade = 0.45 + 0.55 * max(0.0, float(n @ CubeSim.SUN))
        dst = buf[y0:y1, x0:x1]
        dst[:] = dst * (1 - mm) + col * shade * mm


def axis_angle(axis, ang):
    """Matriz de giro de `ang` rad alrededor de `axis` (como CFrame.fromAxisAngle)."""
    a = np.asarray(axis, float) / max(np.linalg.norm(axis), 1e-9)
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * (K @ K)


def draw_solid_box(buf, cam, pos, R3, size3, col, alpha=1.0):
    """Una Part (bloque) girada: caras sombreadas con el sol, como los cubos de la zona."""
    from PIL import ImageDraw
    half = np.asarray(size3, float) * 0.5
    corners = {}
    for f in CubeSim.FACES:
        for q in f:
            if q not in corners:
                pr = cam.project(pos + R3 @ (np.array(q, float) * half))
                if pr is None:
                    return
                corners[q] = (pr[0], pr[1])
    xs = [v[0] for v in corners.values()]
    ys = [v[1] for v in corners.values()]
    H, W = buf.shape[:2]
    x0, y0 = int(math.floor(min(xs))) - 1, int(math.floor(min(ys))) - 1
    x1, y1 = int(math.ceil(max(xs))) + 1, int(math.ceil(max(ys))) + 1
    if x1 <= 0 or y1 <= 0 or x0 >= W or y0 >= H or (x1 - x0) * (y1 - y0) > 250000:
        return
    ss = 4 if (x1 - x0) < 60 else 2
    pw, ph = x1 - x0, y1 - y0
    rgb = np.zeros((ph, pw, 3), np.float32)
    acc = np.zeros((ph, pw, 1), np.float32)
    col = np.asarray(col, float)
    for f, nrm in zip(CubeSim.FACES, CubeSim.NORMALS):
        n = R3 @ np.array(nrm, float)
        fc = pos + n * float(np.abs(np.array(nrm, float)) @ half)
        if n @ (cam.C - fc) <= 0:
            continue
        shade = 0.42 + 0.58 * max(0.0, float(n @ CubeSim.SUN))
        m = Image.new("L", (pw * ss, ph * ss), 0)
        ImageDraw.Draw(m).polygon([((corners[q][0] - x0) * ss, (corners[q][1] - y0) * ss) for q in f], fill=255)
        mm = np.asarray(m.resize((pw, ph), Image.BOX), np.float32)[..., None] / 255
        mm = np.minimum(mm, 1 - acc)
        rgb += mm * col * shade
        acc += mm
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    dst = buf[ya:yb, xa:xb]
    sa = acc[ya - y0:yb - y0, xa - x0:xb - x0] * alpha
    dst *= (1 - sa)
    dst += rgb[ya - y0:yb - y0, xa - x0:xb - x0] * alpha


def draw_ground_quad(buf, cam, center, along, half_len, half_w, rgb, alpha, tex=None, light=0.0):
    """Rectángulo horizontal en el suelo (una Part delgada o un Decal sobre ella) centrado en `center` y con el largo
    hacia `along`. tex = RGBA 0..1 estirada sobre el rectángulo (u a lo largo, v a lo ancho). light = LightEmission:
    0 tapa lo de abajo, 1 suma luz."""
    center = np.asarray(center, float)
    along = np.asarray(along, float)
    along = along / np.linalg.norm(along)
    perp = np.array([-along[2], 0.0, along[0]])
    prs = [cam.project(center + along * a + perp * b) for a in (-half_len, half_len) for b in (-half_w, half_w)]
    if any(p is None for p in prs):
        return
    H, W = buf.shape[:2]
    xa, xb = max(0, int(min(p[0] for p in prs)) - 2), min(W, int(max(p[0] for p in prs)) + 3)
    ya, yb = max(0, int(min(p[1] for p in prs)) - 2), min(H, int(max(p[1] for p in prs)) + 3)
    if xa >= xb or ya >= yb:
        return
    us, vs = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
    r = cam.ray(us.ravel(), vs.ravel())
    ry = np.where(np.abs(r[1]) < 1e-4, -1e-4, r[1])
    tt = (center[1] - cam.C[1]) / ry
    rel = cam.C[:, None] + r * tt - center[:, None]
    a, b = along @ rel, perp @ rel
    # lo que mide un píxel en el suelo en cada dirección (se estira en la dirección de la mirada)
    hv = np.stack([r[0], r[2]])
    hv = hv / np.maximum(np.linalg.norm(hv, axis=0), 1e-9)
    stretch = 1 / np.maximum(np.abs(ry), 0.08) ** 2 - 1
    base = np.abs(tt) / cam.f
    pa = base * np.sqrt(1 + (along[0] * hv[0] + along[2] * hv[1]) ** 2 * stretch)
    pb = base * np.sqrt(1 + (perp[0] * hv[0] + perp[2] * hv[1]) ** 2 * stretch)
    cov = np.clip((half_len - np.abs(a)) / pa + 0.5, 0, 1) * np.clip((half_w - np.abs(b)) / pb + 0.5, 0, 1)
    cov[tt <= 0] = 0
    if not cov.any():
        return
    rgb = np.asarray(rgb, np.float32)
    if tex is not None:
        th, tw = tex.shape[:2]
        uu = np.clip(((a / (2 * half_len) + 0.5) * tw).astype(int), 0, tw - 1)
        vv = np.clip(((b / (2 * half_w) + 0.5) * th).astype(int), 0, th - 1)
        smp = tex[vv, uu]
        col = smp[:, :3] * rgb
        al = smp[:, 3] * cov * alpha
    else:
        col = np.broadcast_to(rgb, (cov.size, 3))
        al = cov * alpha
    al = al.reshape(yb - ya, xb - xa, 1).astype(np.float32)
    dst = buf[ya:yb, xa:xb]
    dst *= (1 - al * (1 - light))
    dst += col.reshape(yb - ya, xb - xa, 3) * al


def slab_color(spec, SLb):
    """Color de vista previa de una losa (en Roblox toma el color y el material del suelo)."""
    if "col" not in SLb:
        base = np.array(SLb["L"].get("preview_color") or spec.get("blade", {}).get("slab_color") or (96, 94, 104),
                        float) / 255
        h = (hash((round(SLb["x"], 2), round(SLb["z"], 2))) % 1000) / 1000
        SLb["col"] = np.clip(base * (0.82 + 0.25 * h), 0, 1)
    return SLb["col"]


def lerp_rgb(a, b, u):
    return (np.asarray(a, float) * (1 - u) + np.asarray(b, float) * u) / 255


def draw_gash(buf, cam, tb, geo, t, o0, Rf, ground_y):
    """El corte que deja la hoja en el suelo (lo mismo que en runBlade): por tramo, escarcha (Decal), la grieta
    oscura y la línea de hielo (Neon) que se enfría; cada tramo vive `life` s y se desvanece en `fade` s."""
    G = geo.B["gash"]
    s = geo.s
    along = Rf @ np.array([0.0, 0.0, -1.0])
    Fr, Cr, Ln = G["frost"], G["crevice"], G["seam"]
    ftex = np.asarray(tb.get(Fr["texture"], "None")[0], np.float32) / 255
    for a, b, side, age in geo.gash(t):
        if age < 0:
            continue
        fz = min(max((age - G["life"]) / G["fade"], 0.0), 1.0)
        if fz >= 1:
            continue
        mid = o0 + Rf @ np.array([side, 0.0, -(a + b) / 2]) + np.array([0.0, ground_y - o0[1], 0.0])
        hl = (b - a) / 2
        op = lambda u: min(max(u, 0.0), 1.0)
        # escarcha: se extiende desde la línea en `spread` s
        sp = op(age / G["spread"])
        sp = sp * sp * (3 - 2 * sp)
        fw = Fr["width"] * s * (0.35 + 0.65 * sp) / 2
        ftr = 1 - (1 - Fr["transparency"]) * (1 - fz)
        glow = 1.0 + 1.5 * Fr.get("light_emission", 0.0)
        draw_ground_quad(buf, cam, mid + np.array([0, 0.08 * s, 0]), along, hl + Fr["overlap"] * s, fw,
                         np.asarray(Fr["color"], float) / 255 * glow, 1 - ftr, tex=ftex, light=Fr.get("light_emission", 0.0))
        # la grieta: se abre en `open` s
        op_ = op(age / G["open"])
        cw = Cr["width"] * s * (0.3 + 0.7 * op_) / 2
        draw_ground_quad(buf, cam, mid + np.array([0, Cr["height"] * s, 0]), along, hl, cw,
                         np.asarray(Cr["color"], float) / 255, 1 - fz)
        # la veta de hielo (Neon) en el fondo: clara al cortar, se enfría a azul hielo
        cu = op(age / G["cool"])
        col = lerp_rgb(Ln["hot"], Ln["cold"], cu * cu * (3 - 2 * cu)) * Ln.get("neon_k", 1.8)
        draw_ground_quad(buf, cam, mid + np.array([0, Ln["height"] * s, 0]), along, hl, Ln["width"] * s / 2,
                         col, (1 - Ln.get("transparency", 0.0)) * (1 - fz))


def render(spec, tex_folder, out_dir, cam, origin=(0, 2, 0), scale=1.0, duration=None, seed=7,
           ground_y=0.0, background=None, extra_draw=None, frame_rot=None, length=0.0, bloom=None,
           only_frames=None, cone_angle=60.0, zone=None, orb=None, props=None):
    """frame_rot: rotación del contenedor (local->mundo). Emisiones (t, n, u, side, up):
    u = fracción a lo largo de la línea (adelante = -Z local), side = +X local, up = +Y.
    zone = {"R": radio, "H": altura} para los efectos en una zona circular (pilar).
    orb = {"mouth": (x, y, z), "targets": [(x, y, z), ...], "radius": opcional} para el proyectil que crece
    (agujero negro): la detonación va en la zona que cubre a los enemigos.
    props = [{"pos", "size", "color"}]: cajas de referencia (p. ej. los enemigos) en la escena."""
    rng = random.Random(seed)
    tb = TexBank(tex_folder)
    duration = duration or spec["duration"] + 0.15
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    bg = background if background is not None else make_background(cam, ground_y)
    parts = []
    events = []      # (t, n, capa, posición, rotación del portador o None, escala de la capa o None)
    Rf = np.eye(3) if frame_rot is None else np.asarray(frame_rot, float)
    o0 = np.asarray(origin, float)
    orbst = None
    if spec.get("orb"):
        O = spec["orb"]
        orb = orb or {}
        A = np.asarray(orb.get("mouth", (0.0, 20.0, 0.0)), float)
        tg = [np.asarray(q, float) for q in orb.get("targets", [])]
        c = sum(tg) / len(tg) if tg else A + np.array([0.0, 0.0, -O["reach"] * scale])
        far = max([math.hypot(q[0] - c[0], q[2] - c[2]) for q in tg] + [0.0])
        R = orb.get("radius") or max(O["min_radius"] * scale, far + O["margin"] * scale)
        zone = {"R": R, "H": spec["zone"]["height"] * scale}
        o0 = np.array([c[0], ground_y, c[2]])
        orbst = OrbSim(spec, A, np.array([c[0], ground_y + O["height"] * scale, c[2]]), scale, cam, ground_y)
    meteors = []
    blade_geo = BladeGeo(spec["blade"], length, scale) if spec.get("blade") else None
    blade_acc = {}
    field = ConeField(spec["field"], length, cone_angle, scale) if spec.get("field") else None
    front = ConeFront(spec["front"], length, cone_angle, scale) if spec.get("front") else None
    shattered = set()
    streams = []   # (L, origin, t_base)
    for L in spec["layers"]:
        if L.get("orb"):
            continue           # van pegadas al proyectil (OrbSim)
        if L.get("floor"):
            # en el suelo bajo el efecto (offset horizontal; su Y es la altura sobre el suelo). ring = (n, radio):
            # n puntos alrededor, cada uno mirando hacia afuera (inclinado pitch grados hacia arriba)
            off = np.asarray(L.get("offset", (0, 0, 0)), float) * scale
            c = o0 + Rf @ np.array([off[0], 0.0, off[2]])
            c[1] = ground_y + off[1]
            Lf = dict(L, offset=(0, 0, 0))
            if L.get("stream"):
                streams.append([Lf, c, 0.0, 0.0, np.eye(3)])
            for ev in L.get("emit", []):
                if L.get("ring"):
                    n_, rr = L["ring"]
                    for i in range(n_):
                        th = 2 * math.pi * i / n_
                        P = c + np.array([math.cos(th), 0.0, math.sin(th)]) * rr * scale
                        events.append((ev[0], ev[1], Lf, P, radial_frame(th, L.get("pitch", 0.0)), None))
                else:
                    events.append((ev[0], ev[1], Lf, c, np.eye(3), None))
            continue
        RvL = None
        if L.get("at_ground"):            # en el suelo bajo el final de la línea (el impacto del rayo)
            P = o0 + Rf @ np.array([0.0, 0.0, -length])
            oL, RvL = np.array([P[0], ground_y, P[2]]), np.eye(3)
        else:
            oL = o0 + Rf @ np.array([0.0, 0.0, -L.get("line_u", 0.0) * length])
        if L.get("stream"):
            streams.append([L, oL, 0.0, 0.0, RvL])
        for ev in L.get("emit", []):
            t, n = ev[0], ev[1]
            pos = oL.copy()
            if len(ev) > 2:
                u, side, up = ev[2], ev[3], ev[4]
                pos = o0 + Rf @ np.array([side * scale, up * scale, -u * length])
            events.append((t, n, L, pos, RvL, None))
        for ev in L.get("points", []):   # (t, n, x, y, z): posición local absoluta
            t, n, x, y, z = ev
            events.append((t, n, L, o0 + Rf @ (np.array([x, y, z], float) * scale), None, None))
        # cono/triángulo hacia adelante: (t, n, u, s, alto); u = fracción del largo, s = fracción del
        # medio ancho en esa distancia. El portador mira desde el vértice hacia ese punto.
        tan_h = math.tan(math.radians(cone_angle / 2))
        pt = math.radians(L.get("pitch", 0.0))    # inclinación hacia arriba de la salida
        Rx = np.array([[1, 0, 0], [0, math.cos(pt), -math.sin(pt)], [0, math.sin(pt), math.cos(pt)]])
        for ev in L.get("cone_emit", []):
            t, n, u, sfrac, up = ev
            pos = o0 + Rf @ np.array([sfrac * u * length * tan_h, up * scale, -u * length])
            phi = -math.atan(sfrac * tan_h)
            Ry = np.array([[math.cos(phi), 0, math.sin(phi)], [0, 1, 0], [-math.sin(phi), 0, math.cos(phi)]])
            events.append((t, n, L, pos, Rf @ Ry @ Rx, None))
    zst, cubes = [], None
    if spec.get("zone"):
        zone = zone or {"R": spec["zone"]["radius"] * scale, "H": spec["zone"]["height"] * scale}
        zone["s"] = scale
        zev, zst, cubes = zone_setup(spec, zone, o0, scale, rng, ground_y)
        events += zev
        if spec.get("zfield"):
            field = ZoneField(spec["zfield"], zone, scale, spec["zone"]["radius"])
    events.sort(key=lambda e: e[0])
    clears = sorted(((L["clear_at"], L) for L in spec["layers"] if L.get("clear_at") is not None), key=lambda c: c[0])
    fades = [L for L in spec["layers"] if L.get("fade_at")]
    ei = 0
    dt = 1.0 / FPS
    stats = []
    for fi in range(nframes):
        t = fi * dt
        while ei < len(events) and events[ei][0] <= t + 1e-9:
            _, n, L, o, Re, kk = events[ei]
            Rv = Rf if Re is None else Re
            for _ in range(n):
                if L.get("type") == "meteor":
                    meteors.append(spawn_meteor(L, o, rng, scale, Rv))
                else:
                    parts.append(spawn(L, o, rng, scale if kk is None else kk, Rv, length, zone))
            ei += 1
        # emisión continua
        for st_ in streams:
            L, o, tb0, acc = st_[:4]
            Rs = st_[4] if len(st_) > 4 and st_[4] is not None else Rf
            rate = 0.0
            for (a0, a1, r0, r1) in L["stream"]:
                ta = t - tb0
                if a0 <= ta <= a1:
                    rate += r0 + (r1 - r0) * (ta - a0) / max(a1 - a0, 1e-6)
            acc += rate * dt
            while acc >= 1.0:
                acc -= 1.0
                parts.append(spawn(L, o, rng, scale, Rs, length))
            st_[3] = acc
        # los emisores que viajan con el frente de la ola
        if front is not None:
            parts += front.step(t, dt, o0, Rf, rng)
        # los bloques que revientan al terminar (end = "shatter"): sus partículas salen donde estaban
        if field is not None:
            for k_, SLb in enumerate(field.slabs):
                if SLb["shatter"] and k_ not in shattered and t >= SLb["t"] + SLb["rise"] + SLb["hold"]:
                    shattered.add(k_)
                    P = o0 + Rf @ np.array([SLb["x"], 0.0, SLb["z"]])
                    P[1] = ground_y + SLb["y0"]
                    for LL in SLb["L"].get("shatter", []):
                        for _ in range(LL["emit"][0][1]):
                            parts.append(spawn(LL, P, rng, getattr(field, "k", scale), Rf))
        # la hoja que vuela suelta su estela (emisores pegados a ella, por tasa)
        if blade_geo is not None:
            for ei_, E in enumerate(spec["blade"].get("emitters", [])):
                for pi_, P in enumerate(blade_geo.emit_points(t, o0, Rf, E)):
                    key = (ei_, pi_)
                    blade_acc[key] = blade_acc.get(key, 0.0) + E["rate"] * dt
                    while blade_acc[key] >= 1.0:
                        blade_acc[key] -= 1.0
                        parts.append(spawn(E, P, rng, scale, Rf, length))
        # proyectil que crece: se mueve y emite sus capas
        if orbst is not None:
            parts += orbst.step(t, dt, rng)
        # emisión continua dentro de la zona (puntos al azar o ranuras que giran con el pilar)
        for z in zst:
            parts += zone_stream_step(z, t, dt, rng, zone, o0)
        # capas que se desvanecen (fade_at) y al terminar se borran
        fade = {}
        for L in fades:
            f0, fd = L["fade_at"]
            if t >= f0:
                fade[id(L)] = max(0.0, 1 - (t - f0) / fd)
        if any(v <= 0 for v in fade.values()):
            parts = [p for p in parts if fade.get(id(p.L), 1.0) > 0]
        # capas que se borran de golpe (Emitter:Clear())
        if clears and clears[0][0] <= t + 1e-9:
            gone = set()
            while clears and clears[0][0] <= t + 1e-9:
                gone.add(id(clears.pop(0)[1]))
            parts = [p for p in parts if id(p.L) not in gone]
        # cubos de destrucción
        if cubes is not None:
            for (Lfx, k, pos) in cubes.step(t, dt):
                for _ in range(Lfx.get("emit_n", 2)):
                    parts.append(spawn(Lfx, pos, rng, k, None, 0.0, zone))
        # meteoros: estelas (por tasa) + aterrizaje
        for m in meteors:
            if m.dead:
                continue
            if m.stuck_until is not None:          # clavada en el suelo: se rompe al terminar
                if t >= m.stuck_until:
                    for LL in m.L.get("shatter", []):
                        for _ in range(LL["emit"][0][1]):
                            parts.append(spawn(LL, m.pos.copy(), rng, scale, Rf))
                    m.dead = True
                continue
            if not m.landed:
                for k, TL in enumerate(m.L.get("trails", [])):
                    m.acc[k] += TL["rate"] * dt
                    while m.acc[k] >= 1.0:
                        m.acc[k] -= 1.0
                        p = spawn(TL, m.pos, rng, scale, Rf)
                        if TL.get("locked"):      # LockedToPart: la partícula sigue a la roca
                            p.lock, p.lofs = m, p.pos - m.pos
                        parts.append(p)
                if (m.pos[1] <= ground_y + 0.3 and m.vel[1] < 0) or m.age >= m.life:
                    m.landed = True
                    if m.pos[1] <= ground_y + 0.6:
                        lp = np.array([m.pos[0], ground_y + 0.4, m.pos[2]])
                        for LL in m.L.get("land", []):
                            if LL.get("stream"):
                                streams.append([LL, lp, t, 0.0])
                            else:
                                for _ in range(LL["emit"][0][1]):
                                    parts.append(spawn(LL, lp, rng, scale, Rf))
                        stick = m.L["sprite"].get("stick", 0)
                        if stick:
                            asp = m.L["sprite"].get("aspect", (1, 0.8, 0.9))
                            h = m.size * asp[1]
                            m.pos = np.array([m.pos[0], ground_y + h * (0.5 - m.L["sprite"].get("sink", 0.3)), m.pos[2]])
                            m.stuck_until = t + stick
                            continue
                    m.dead = True
        # integrar (el primer frame de cada partícula se dibuja en su origen)
        alive = []
        for p in parts:
            if p.age >= p.life:
                continue
            alive.append(p)
        parts = alive
        if only_frames is not None and fi not in only_frames:
            stats.append(len(parts))
            draw = False
        else:
            draw = True
        buf = bg.copy() if draw else None
        if draw and cubes is not None:
            cubes.draw_shadows(buf, cam)
        if draw and blade_geo is not None and spec["blade"].get("gash"):
            draw_gash(buf, cam, tb, blade_geo, t, o0, Rf, ground_y)
        # ordenar atrás -> adelante (partículas y cubos)
        items = []
        for p in (parts if draw else []):
            wp = p.pos if not p.spin else spin_world(p, t, o0)
            d = cam.to_cam(wp)
            if d[2] <= 0.5:
                continue
            items.append((d[2] - p.L.get("zoffset", 0.0) * p.ks, 0, p, d, wp))
        if draw and cubes is not None:
            for c in cubes.visible():
                d = cam.to_cam(c.pos)
                if d[2] > 0.5:
                    items.append((d[2], 1, c, d, None))
        if draw and orbst is not None:
            lz = orbst.lens(cam)
            if lz is not None:
                items.append((cam.to_cam(lz[0])[2], 2, lz, None, None))
        for pr_ in (props or []) if draw else []:
            d = cam.to_cam(np.asarray(pr_["pos"], float))
            if d[2] > 0.5:
                items.append((d[2], 3, pr_, d, None))
        if draw and spec.get("beams"):
            Bq = spec["beam"]          # el rayo sale a los `start` s y en `grow` s llega al impacto
            kg = min(max((t - Bq["start"]) / max(Bq["grow"], 1e-3), 0.0), 1.0)
            bA, bB = o0, o0 + Rf @ np.array([0.0, 0.0, -length * kg])
            for bi, Bm in enumerate(spec["beams"]):
                w = Bm["width"] * scale * eval_seq(Bm["width_t"], t) * \
                    (1 + Bm["pulse"] * smooth_noise(bi * 7.1, t * Bm["pulse_hz"]))
                bfade = eval_seq(Bm["alpha_t"], t)
                if w > 0.02 and bfade < 0.999 and kg > 0:
                    dz = cam.to_cam((bA + bB) * 0.5)[2] - Bm.get("zoffset", 0.0) * scale
                    items.append((dz, 4, (Bm, bA, bB, w, bfade), None, None))
        if draw and spec.get("zbeams") and zone is not None:     # la columna de una zona: cintas que caen
            for zi, ZB in enumerate(spec["zbeams"]):
                Bm = {"texture": ZB["texture"], "mode": "Wrap", "tex_len": ZB["tex_len"] * zone["H"] / scale,
                      "speed": ZB["speed"], "w0": 1.0, "w1": 1.0, "color": ZB["color"],
                      "transparency": ZB["transparency"], "brightness": ZB["brightness"],
                      "light_emission": ZB["light_emission"]}
                for top, bot, w, bfade in zone_beams_at(ZB, zi, t, zone, cam.C - o0):
                    A_, B_ = o0 + top, o0 + bot
                    bfade = near_fade(ZB, bfade, w, cam.C, A_)
                    if bfade < 0.999:
                        dz = cam.to_cam((A_ + B_) * 0.5)[2] - ZB.get("zoffset", 0.0) * scale
                        items.append((dz, 4, (Bm, A_, B_, w, bfade), None, None))
        if draw and field is not None:           # los bloques de hielo y las losas que deja la ola triangular
            for P, R3, size3, SLb in slab_poses(field.slabs, t, o0, Rf, ground_y):
                d = cam.to_cam(P)
                if d[2] > 0.5:
                    items.append((d[2], 6, (P, R3, size3, SLb), d, None))
        if draw and blade_geo is not None:       # la media luna que vuela (cadenas de Beams que miran a la cámara)
            for P, R3, size3, SLb in blade_geo.slab_poses(t, o0, Rf, ground_y):
                d = cam.to_cam(P)
                if d[2] > 0.5:
                    items.append((d[2], 6, (P, R3, size3, SLb), d, None))
            for pts, ws, tr, BL in blade_geo.chains(t, o0, Rf):
                if tr >= 0.995:
                    continue
                nb = len(pts)
                for i in range(nb - 1):
                    c = eval_color(BL["color"], (i + 0.5) / (nb - 1)) * 255
                    Bm = {"texture": BL["texture"], "mode": "Stretch", "tex_len": 1.0, "speed": 0.0,
                          "light_emission": BL["light_emission"], "brightness": BL["brightness"],
                          "color": [(0, tuple(c)), (1, tuple(c))], "w0": ws[i], "w1": ws[i + 1],
                          "transparency": [(0, tr), (1, tr)]}
                    dz = cam.to_cam((pts[i] + pts[i + 1]) * 0.5)[2] - BL.get("zoffset", 0.0) * scale
                    if dz > 0.6:
                        items.append((dz, 4, (Bm, pts[i], pts[i + 1], 1.0, 0.0), None, None))
        for m in (meteors if draw else []):
            if not m.dead and m.L["sprite"].get("cube"):
                d = cam.to_cam(m.pos)
                if d[2] > 0.5:
                    items.append((d[2], 5, m, d, None))
        items.sort(key=lambda x: -x[0])
        for _, kind, obj, d, wp in items:
            if kind == 1:
                cubes.draw_cube(buf, cam, obj, t)
                continue
            if kind == 2:
                apply_lens(buf, cam, *obj)
                continue
            if kind == 3:
                draw_box(buf, cam, obj)
                continue
            if kind == 4:
                draw_beam(buf, tb, cam, *obj, t, scale)
                continue
            if kind == 5:
                asp = obj.L["sprite"].get("aspect", (1, 0.8, 0.9))
                draw_solid_box(buf, cam, obj.pos, obj.R3, np.asarray(asp, float) * obj.size, obj.col)
                continue
            if kind == 6:
                P, R3, size3, SLb = obj
                if SLb["ice"]:
                    draw_solid_box(buf, cam, P, R3, size3, np.array(SLb["ice"]["color"], float) / 255 * 1.15,
                                   1 - SLb["ice"]["transparency"])
                else:
                    draw_solid_box(buf, cam, P, R3, size3, slab_color(spec, SLb))
                continue
            am = fade.get(id(obj.L), 1.0)
            if obj.spin:
                pos0 = obj.pos
                obj.pos = wp
                draw_particle(buf, tb, cam, obj, d, scale, ground_y, am)
                obj.pos = pos0
            else:
                draw_particle(buf, tb, cam, obj, d, scale, ground_y, am)
        for m in (meteors if draw else []):
            if m.dead or m.L["sprite"].get("cube"):
                continue
            pr = cam.project(m.pos)
            if pr is None:
                continue
            sp = m.L["sprite"]
            px = cam.f * m.size / pr[2]
            gl = sp.get("glow")          # solo en la vista previa: el resplandor de la roca fundida
            if gl:
                gs = tb.sprite(gl["texture"], "None", 0, px * gl["size_k"], px * gl["size_k"], 0)
                gs[..., :3] *= np.array(gl["color"], float) / 255
                gs[..., 3] *= gl["alpha"]
                draw_sprite(buf, gs, pr[0], pr[1], 1.0, gl.get("brightness", 1.4))
            spr = tb.sprite(sp["texture"], sp.get("layout", "Grid2x2"), m.frame, px, px, m.rot)
            col = np.array(sp.get("color", (255, 255, 255)), float) / 255
            spr[..., :3] *= col
            draw_sprite(buf, spr, pr[0], pr[1], 0.0, 1.0)
        if draw:
            if extra_draw:
                extra_draw(buf, t)
            if bloom:
                buf = apply_bloom(buf, **bloom)
            if spec.get("screen") and zone is not None:
                buf = apply_screen(buf, spec["screen"], t, cam, o0, zone)
            img = Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8))
            img.save(os.path.join(out_dir, f"{fi:04d}.png"))
            stats.append(len(parts))
        # avanzar física
        for m in meteors:
            if m.dead or m.stuck_until is not None:
                continue
            acc = np.asarray(m.L.get("accel", (0, -100, 0)), float) * scale
            m.vel = m.vel * (2.0 ** (-m.L.get("drag", 0.0) * dt)) + acc * dt
            m.pos = m.pos + m.vel * dt
            m.rot += m.rots * dt
            if m.L["sprite"].get("cube"):
                m.R3 = axis_angle(m.axis, m.spin * dt) @ m.R3
            m.age += dt
        for p in parts:
            L = p.L
            drag = L.get("drag", 0.0)
            acc = np.asarray(L.get("accel", (0, 0, 0)), float) * p.ks
            p.vel = p.vel * (2.0 ** (-drag * dt)) + acc * dt
            if p.lock is not None:
                p.lofs = p.lofs + p.vel * dt
                p.pos = p.lock.pos + p.lofs
            else:
                p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats


def decal_glow(L):
    """Multiplicador de Color3 de un Decal (igual que en el módulo Luau)."""
    return round(1.0 + 1.5 * L.get("light_emission", 0.0), 3)


def draw_particle(buf, tb, cam, p, d, scale, ground_y, amul=1.0, occ=None):
    """occ = profundidad por píxel (a lo largo del rayo) de lo que tapa a las partículas (la figura del aura)."""
    L = p.L
    tl = min(p.age / p.life, 1.0)
    # Roblox no dibuja partículas de más de 100 studs (el tamaño de la secuencia por la escala); las capas bill
    # (BillboardGuis: la luna del cielo, los destellos gigantes) y las decal (Parts con Decal) no tienen tope
    cap = 1e9 if (L.get("bill") or L.get("decal")) else 100.0
    size = min(max(eval_seq(L["size"], tl, p.r_size) * p.ks, 0.0), cap) * p.gm
    if size <= 0.01:
        return
    if L.get("bill") and (L.get("slide") or L.get("zoffset")):
        # BillboardGui.StudsOffset (en el marco de la cámara): slide = corrimiento en pantalla y zoffset = hacia la
        # cámara de verdad (a diferencia del ZOffset de las partículas, se ve un poco más grande)
        p0 = p.pos
        p = copy.copy(p)
        p.pos = p0 + cam.R[2] * -L.get("zoffset", 0.0) * p.ks
        if L.get("slide"):
            sl = L["slide"]
            ts = [k[0] for k in sl]
            p.pos = p.pos + cam.R[0] * np.interp(tl, ts, [k[1] for k in sl]) * p.ks + \
                cam.R[1] * np.interp(tl, ts, [k[2] for k in sl]) * p.ks
        d = cam.to_cam(p.pos)
        if d[2] <= 0.5:
            return
    tr = eval_seq(L.get("transparency", [(0, 0), (1, 0)]), tl, p.r_tr)
    if amul < 1.0:                     # la capa se está desvaneciendo (fade_at)
        tr = 1 - (1 - tr) * amul
    if tr >= 0.999:
        return
    col = eval_color(L.get("color", [(0, (255, 255, 255)), (1, (255, 255, 255))]), tl)
    fb = L.get("flipbook")
    if fb:
        layout, mode, fps = fb[0], fb[1], fb[2]
        n = {"None": 1, "Grid2x2": 4, "Grid4x4": 16, "Grid8x8": 64}[layout]
        if L.get("flip_t"):           # bill: cuadro según la vida ([(t, cuadro)]), p. ej. la luna que se eclipsa
            ft = L["flip_t"]
            idx = min(max(int(round(np.interp(tl, [k[0] for k in ft], [k[1] for k in ft]))), 0), n - 1)
        elif mode == "OneShot":
            idx = min(int(tl * n), n - 1)
        elif mode == "Loop":
            idx = (p.frame0 + int(p.age * fps)) % n
        else:  # Random
            idx = p.frame0 if fps <= 0 else int(abs(hash((p.seed, int(p.age * fps))))) % n
    else:
        layout, idx = "None", 0
    light = L.get("light_emission", 0.0)
    bright = L.get("brightness", 1.0)
    if L.get("bill"):
        light = 0.0               # una ImageLabel no tiene LightEmission: mezcla alfa (Brightness sí la hace brillar)
    ori = L.get("orientation", "FacingCamera")
    z = d[2]
    f = cam.f
    if ori == "VelocityPerpendicular":
        if L.get("decal"):
            # en Roblox es un Decal: sin LightEmission (mezcla alfa normal); el módulo sobre-ilumina
            # su Color3 (>1) en proporción a light_emission para que brille con el Bloom
            light, bright = 0.0, decal_glow(L)
        draw_flat(buf, tb, cam, p, L["texture"], layout, idx, size, col, tr, light, bright, occ)
        return
    proj = cam.project(p.pos)
    if proj is None:
        return
    cx, cy, _ = proj

    def occ_mask(xa, ya, xb, yb, us, vs):
        if occ is None:
            return 1.0
        rays = cam.ray(us.ravel(), vs.ravel())
        cosang = (cam.R[2] @ rays).reshape(us.shape)
        return (occ[ya:yb, xa:xb] * cosang > z - 0.25 * p.ks).astype(np.float32)
    if ori == "FacingCameraWorldUp":
        a = cam.project(p.pos + np.array([0, 1.0, 0]) * size / 2)
        b = cam.project(p.pos - np.array([0, 1.0, 0]) * size / 2)
        if a is None or b is None:
            return
        dx, dy = a[0] - b[0], a[1] - b[1]
        ang = math.degrees(math.atan2(dx, -dy))
        px = f * size / z
        spr = tb.sprite(L["texture"], layout, idx, px, px, -ang + p.rot)   # copia nueva: se puede teñir
        spr[..., :3] *= col
        spr[..., 3] *= (1 - tr)

        def mask_up(xa, ya, xb, yb):
            us, vs = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
            x = (us - cam.W / 2) * z / f
            y = -(vs - cam.H / 2) * z / f
            wy = cam.C[1] + cam.R[0, 1] * x + cam.R[1, 1] * y + cam.R[2, 1] * z
            return (wy > ground_y).astype(np.float32) * occ_mask(xa, ya, xb, yb, us, vs)
        draw_sprite(buf, spr, cx, cy, light, bright, mask_up)
        return
    if ori == "VelocityParallel":
        v = p.vel
        sp = np.linalg.norm(v)
        vd = v / sp if sp > 1e-6 else np.array([0, 1.0, 0])
        a = cam.project(p.pos + vd * size / 2)
        b = cam.project(p.pos - vd * size / 2)
        if a is None or b is None:
            return
        dx, dy = a[0] - b[0], a[1] - b[1]
        length = max(math.hypot(dx, dy), 1.0)
        width = f * size / z
        angle = math.degrees(math.atan2(dx, -dy))  # textura apunta arriba
        spr = tb.sprite(L["texture"], layout, idx, width, length, -angle)
    else:
        px = f * size / z
        spr = tb.sprite(L["texture"], layout, idx, px, px, p.rot)
    spr[..., :3] *= col
    spr[..., 3] *= (1 - tr)

    def mask(xa, ya, xb, yb):
        # depth test contra el suelo: punto del billboard (plano a profundidad z)
        us, vs = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
        x = (us - cam.W / 2) * z / f
        y = -(vs - cam.H / 2) * z / f
        wy = cam.C[1] + cam.R[0, 1] * x + cam.R[1, 1] * y + cam.R[2, 1] * z
        return (wy > ground_y).astype(np.float32) * occ_mask(xa, ya, xb, yb, us, vs)

    draw_sprite(buf, spr, cx, cy, light, bright, mask)


def draw_flat(buf, tb, cam, p, tex, layout, idx, size, col, tr, light, bright, occ=None):
    """Quad plano perpendicular a la velocidad (p.ej. anillo en el suelo)."""
    v = p.vel
    n = v / np.linalg.norm(v) if np.linalg.norm(v) > 1e-9 else np.array([0, 1.0, 0])
    a1 = np.cross(n, [0, 0, 1.0]) if abs(n[2]) < 0.9 else np.cross(n, [1.0, 0, 0])
    a1 /= np.linalg.norm(a1)
    a2 = np.cross(n, a1)
    c, s = math.cos(math.radians(p.rot)), math.sin(math.radians(p.rot))
    a1, a2 = a1 * c + a2 * s, -a1 * s + a2 * c
    corners = [p.pos + (a1 * i + a2 * j) * size / 2 for i in (-1, 1) for j in (-1, 1)]
    pr = [cam.project(q) for q in corners]
    if any(q is None for q in pr):
        return
    xs = [q[0] for q in pr]
    ys = [q[1] for q in pr]
    xa, xb = max(0, int(min(xs))), min(cam.W, int(max(xs)) + 1)
    ya, yb = max(0, int(min(ys))), min(cam.H, int(max(ys)) + 1)
    if xa >= xb or ya >= yb:
        return
    fr = tb.get(tex, layout)[idx]
    T = np.asarray(fr, dtype=np.float32) / 255.0
    th, tw = T.shape[:2]
    us, vs = np.meshgrid(np.arange(xa, xb) + 0.5, np.arange(ya, yb) + 0.5)
    rays = cam.ray(us.ravel(), vs.ravel())
    denom = n @ rays
    tt = ((p.pos - cam.C) @ n) / np.where(np.abs(denom) < 1e-9, 1e-9, denom)
    X = cam.C[:, None] + rays * tt
    rel = X - p.pos[:, None]
    lu = (a1 @ rel) / size + 0.5
    lv = (a2 @ rel) / size + 0.5
    ok = (lu >= 0) & (lu < 1) & (lv >= 0) & (lv < 1) & (tt > 0)
    if occ is not None:
        ok &= occ[ya:yb, xa:xb].ravel() > tt
    ix = np.clip((lu * tw).astype(int), 0, tw - 1)
    iy = np.clip((lv * th).astype(int), 0, th - 1)
    smp = T[iy, ix]
    smp[~ok] = 0
    smp = smp.reshape(yb - ya, xb - xa, 4)
    rgb = smp[..., :3] * col * bright
    a = smp[..., 3:4] * (1 - tr)
    dst = buf[ya:yb, xa:xb]
    dst *= (1 - a * (1 - light))
    dst += rgb * a


def make_background(cam, ground_y=0.0):
    W, H = cam.W, cam.H
    us, vs = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    rays = cam.ray(us.ravel(), vs.ravel())
    dy = rays[1]
    sky_top = np.array([0.30, 0.55, 0.88])
    sky_hor = np.array([0.72, 0.84, 0.96])
    t = np.clip(dy * 3.0, 0, 1)[:, None]
    sky = sky_hor * (1 - t) + sky_top * t
    # suelo
    tt = (ground_y - cam.C[1]) / np.where(dy < -1e-6, dy, -1e-6)
    gx = cam.C[0] + rays[0] * tt
    gz = cam.C[2] + rays[2] * tt
    checker = ((np.floor(gx / 8) + np.floor(gz / 8)) % 2)[:, None]
    ground = np.array([0.56, 0.66, 0.78]) * (1 - 0.06 * checker)
    fog = np.clip(tt / 900.0, 0, 1)[:, None]
    ground = ground * (1 - fog) + sky_hor * fog
    img = np.where((dy < 0)[:, None], ground, sky)
    return img.reshape(H, W, 3).astype(np.float32)


def to_mp4(frame_dir, out, fps=FPS, label=None):
    vf = []
    if label:
        vf.append(f"drawtext=text='{label}':x=10:y=10:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.45")
    cmd = ["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", os.path.join(frame_dir, "%04d.png")]
    if vf:
        cmd += ["-vf", ",".join(vf)]
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", out]
    subprocess.run(cmd, check=True)
    return out


def make_background_dark(cam, ground_y=0.0):
    """Fondo nocturno con rejilla (como la referencia del usuario)."""
    W, H = cam.W, cam.H
    us, vs = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    rays = cam.ray(us.ravel(), vs.ravel())
    dy = rays[1]
    sky = np.array([0.36, 0.36, 0.4]) * (1 - np.clip(dy * 2, 0, 1)[:, None] * 0.4)
    tt = (ground_y - cam.C[1]) / np.where(dy < -1e-6, dy, -1e-6)
    gx = cam.C[0] + rays[0] * tt
    gz = cam.C[2] + rays[2] * tt
    line = ((np.abs(((gx / 8) % 1) - 0.5) > 0.47) | (np.abs(((gz / 8) % 1) - 0.5) > 0.47))[:, None]
    ground = np.where(line, np.array([0.32, 0.33, 0.35]), np.array([0.07, 0.07, 0.08]))
    img = np.where((dy < 0)[:, None], ground, sky)
    return img.reshape(H, W, 3).astype(np.float32)


# --------------------------------------------------------------- zona circular (pilar de Omnívora)
def radial_frame(theta, pitch_deg=0.0):
    """Rotación del portador en un punto del círculo: su Front (-Z) mira hacia afuera, inclinado
    `pitch` grados hacia arriba (igual que CFrame.lookAt(pos, pos + afuera) * CFrame.Angles(pitch, 0, 0))."""
    f = np.array([math.cos(theta), 0.0, math.sin(theta)])
    R = np.stack([np.array([-f[2], 0.0, f[0]]), np.array([0.0, 1.0, 0.0]), -f], axis=1)
    if pitch_deg:
        pt = math.radians(pitch_deg)
        R = R @ np.array([[1, 0, 0], [0, math.cos(pt), -math.sin(pt)], [0, math.sin(pt), math.cos(pt)]])
    return R


def layer_k(L, scale, zone, Z0):
    """Escala de tamaños de una capa: con el radio ("r"), con la altura ("h") o con la escala."""
    rel = L.get("rel")
    if rel == "r":
        return zone["R"] / Z0["radius"]
    if rel == "h":
        return zone["H"] / Z0["height"]
    return scale


def zone_y(L, h, k, zone):
    if L.get("hu") == "H":
        return h * zone["H"]
    if L.get("hu") == "s":
        return h * zone.get("s", 1.0)
    return h * k


def zone_point(L, rng, zone, k, o0, local=False):
    """Punto al azar según L["zdist"] = {"r": (r0, r1), "h": (h0, h1), "area": bool} y la rotación del portador."""
    d = L["zdist"]
    r0, r1 = d["r"]
    r = math.sqrt(rng.uniform(r0 * r0, r1 * r1)) if d.get("area") else rng.uniform(r0, r1)
    th = rng.uniform(0, 2 * math.pi)
    y = zone_y(L, rng.uniform(*d["h"]), k, zone)
    pos = np.array([math.cos(th) * r * zone["R"], y, math.sin(th) * r * zone["R"]])
    Rv = radial_frame(th, L.get("pitch", 0.0)) if L.get("radial", True) else np.eye(3)
    return (pos if local else o0 + pos), Rv


def cover_mul(L, k, kR, kH):
    """Capas que cubren la superficie del pilar: más partículas si el pilar es más alto/ancho que su tamaño."""
    if not L.get("cover"):
        return 1.0
    return min(2.5, max(0.5, kR * kH / (k * k)))


def zone_setup(spec, zone, o0, scale, rng, ground_y):
    Z0 = spec["zone"]
    kR, kH = zone["R"] / Z0["radius"], zone["H"] / Z0["height"]
    events, zst = [], []
    for L in spec["layers"]:
        k = layer_k(L, scale, zone, Z0)
        for (t, n, a, r, h) in L.get("ring_emit", []):
            th = 2 * math.pi * a
            pos = o0 + np.array([math.cos(th) * r * zone["R"], zone_y(L, h, k, zone), math.sin(th) * r * zone["R"]])
            Rv = radial_frame(th, L.get("pitch", 0.0)) if L.get("radial", True) else np.eye(3)
            events.append((t, n, L, pos, Rv, k))
        if L.get("zstream"):
            z = {"L": L, "k": k, "acc": 0.0, "mul": cover_mul(L, k, kR, kH)}
            if L.get("spin"):
                z["slots"] = [zone_point(L, rng, zone, k, o0, local=True) for _ in range(L.get("slots", 8))]
            zst.append(z)
    cubes = CubeSim(spec, zone, o0, scale, ground_y, random.Random(rng.random())) if spec.get("cubes") else None
    return events, zst, cubes


def zone_beams_at(ZB, zi, t, zone, cam_rel):
    """Las cintas (Beams FaceCamera) de la columna de una zona en el segundo t: (arriba, abajo, ancho, desvanecido)
    respecto al centro de la zona en el suelo. Bajan de la luna en ZB["drop"] = (t0, duración); count cintas en un
    anillo de r × radio que gira spin grados/s (count 1 y r 0 = una sola en el eje). rim: dos cintas finas en el
    contorno de la columna visto desde la cámara (cam_rel = la cámara respecto al centro): el delineado."""
    t0, dur = ZB["drop"]
    if t < t0:
        return []
    wk = eval_seq(ZB["width_t"], t)
    fade = eval_seq(ZB["alpha_t"], t)
    if wk <= 1e-3 or fade >= 0.999:
        return []
    H, R = zone["H"], zone["R"]
    top = ZB["h"][1] * H
    u = min((t - t0) / max(dur, 1e-3), 1.0)
    bot = top + (ZB["h"][0] * H - top) * (1 - (1 - u) ** 2)
    rr = ZB.get("r", 0.0) * R * (eval_seq(ZB["r_t"], t) if ZB.get("r_t") else 1.0)
    pts = []
    if ZB.get("rim"):
        d = math.hypot(cam_rel[0], cam_rel[2])
        if d <= rr * 1.02:
            return []                     # la cámara está dentro: no hay contorno
        ux, uz = cam_rel[0] / d, cam_rel[2] / d
        c = rr / d
        sn = math.sqrt(max(1 - c * c, 0.0))
        pts = [(rr * (c * ux - sn * uz), rr * (c * uz + sn * ux)), (rr * (c * ux + sn * uz), rr * (c * uz - sn * ux))]
    else:
        n = ZB.get("count", 1)
        for i in range(n):
            ang = 2 * math.pi * (ZB.get("a0", 0.0) + i / n) + math.radians(ZB.get("spin", 0.0)) * (t - t0)
            pts.append((math.cos(ang) * rr, math.sin(ang) * rr))
    out = []
    for i, (x, z) in enumerate(pts):
        w = ZB["width"] * R * wk * (1 + ZB.get("wobble", 0.0) * smooth_noise(zi * 7.1 + i * 3.3, t * 2.3))
        out.append((np.array([x, top, z]), np.array([x, bot, z]), w, fade))
    return out


def near_fade(ZB, fade, w, camC, top):
    """Con la cámara dentro de la columna, las cintas cercanas se aclaran (hasta ZB["near"]) para no tapar la vista."""
    k = ZB.get("near", 0.0)
    if k <= 0:
        return fade
    d = math.hypot(camC[0] - top[0], camC[2] - top[2])
    close = 1 - min(max((d - 0.5 * w) / max(w, 1e-3), 0.0), 1.0)
    return 1 - (1 - fade) * (1 - k * close)


def zone_stream_step(z, t, dt, rng, zone, o0):
    L = z["L"]
    rate = 0.0
    for (a0, a1, r0, r1) in L["zstream"]:
        if a0 <= t <= a1:
            rate += r0 + (r1 - r0) * (t - a0) / max(a1 - a0, 1e-6)
    z["acc"] += rate * z["mul"] * dt
    out = []
    while z["acc"] >= 1.0:
        z["acc"] -= 1.0
        if L.get("spin"):
            pos, Rv = z["slots"][rng.randrange(len(z["slots"]))]
            p = spawn(L, pos, rng, z["k"], Rv, 0.0, zone)
            p.spin = L["spin"]
        else:
            pos, Rv = zone_point(L, rng, zone, z["k"], o0)
            p = spawn(L, pos, rng, z["k"], Rv, 0.0, zone)
        out.append(p)
    return out


def spin_world(p, t, o0):
    """Partícula pegada a la pieza que gira (LockedToPart): local -> mundo con el giro actual."""
    th = math.radians(p.spin) * t
    c, s = math.cos(th), math.sin(th)
    x, y, z = p.pos
    return o0 + np.array([c * x + s * z, y, -s * x + c * z])


def axis_angle(axis, ang):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * (K @ K)


def flat_rot(rot):
    """La misma orientación, girada lo mínimo para que una cara quede apoyada en el suelo."""
    j = int(np.argmax(np.abs(rot[1])))
    up = rot[:, j] * (1 if rot[1, j] >= 0 else -1)
    axis = np.cross(up, [0, 1.0, 0])
    if np.linalg.norm(axis) < 1e-4:
        return rot.copy()
    return axis_angle(axis, math.acos(max(-1.0, min(1.0, up[1])))) @ rot


def orthonormal(m):
    u, _, vt = np.linalg.svd(m)
    return u @ vt


def zone_light_points(Lt, zone, s):
    """Dónde va cada PointLight de una luz de zona (respecto al centro): una en el eje a la altura h o, con
    ring = (cuántas, fracción del radio), un anillo de luces (el alcance de una PointLight no pasa de 60 studs)."""
    y = Lt["h"] * (zone["H"] if Lt.get("hu") == "H" else s)
    ring = Lt.get("ring")
    if not ring:
        return [np.array([0.0, y, 0.0])]
    n, rf = ring
    return [np.array([math.cos(2 * math.pi * i / n) * rf * zone["R"], y, math.sin(2 * math.pi * i / n) * rf * zone["R"]])
            for i in range(n)]


def light_at(Lt, t):
    """Intensidad de una luz de la zona: sube en `rise`, se mantiene `hold` y baja en `fall`."""
    tt = t - Lt["t"]
    if tt < 0:
        return 0.0
    if tt < Lt["rise"]:
        return Lt["brightness"] * tt / max(Lt["rise"], 1e-6)
    tt -= Lt["rise"]
    if tt < Lt["hold"]:
        return Lt["brightness"]
    tt -= Lt["hold"]
    return Lt["brightness"] * max(0.0, 1 - tt / max(Lt["fall"], 1e-6))


class Cube:
    pass


class CubeSim:
    """Cubos de destrucción (Parts en Roblox): la misma lógica que playCubes del módulo Luau."""
    FACES = [((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)), ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
             ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)), ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
             ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)), ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1))]
    NORMALS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    SUN = np.array([-0.4, 1.0, -0.3]) / np.linalg.norm([-0.4, 1.0, -0.3])

    def __init__(self, spec, zone, o0, scale, ground_y, rng):
        self.C = C = spec["cubes"]
        self.spec, self.zone, self.o0, self.s, self.gy, self.rng = spec, zone, o0, scale, ground_y, rng
        self.cleanup = spec.get("_cleanup", 99.0)
        self.lights = spec.get("lights", [])
        base = np.array(C.get("preview_color", (112, 106, 112)), float) / 255
        self.list = []
        for G in C["groups"]:
            for _ in range(G["count"]):
                c = Cube()
                c.G, c.mode = G, G["mode"]
                c.ang = rng.uniform(0, 2 * math.pi)
                c.out = np.array([math.cos(c.ang), 0.0, -math.sin(c.ang)])
                c.r = math.sqrt(rng.uniform(G["r"][0] ** 2, G["r"][1] ** 2)) * zone["R"]
                c.size = (G["size"][0] + (G["size"][1] - G["size"][0]) * rng.random() ** G["skew"]) * scale
                c.t0 = rng.uniform(*G["t"])
                c.pos = o0 + c.out * c.r + np.array([0, ground_y + c.size * 0.5, 0])
                c.vel = np.zeros(3)
                c.rot = orthonormal(np.array([[rng.uniform(-1, 1) for _ in range(3)] for _ in range(3)]))
                c.axis = np.array([rng.uniform(-1, 1) for _ in range(3)])
                c.spin = math.radians(rng.uniform(*C["spin"]))
                c.state, c.bounces, c.k, c.alpha = "wait", 0, 1.0, 1.0
                c.neon = rng.random() < G.get("neon", 0.0)
                c.dissolve = rng.random() < G.get("dissolve", 0.0)
                c.ncol = np.array(C["neon_colors"][rng.randrange(len(C["neon_colors"]))], float) / 255
                f = rng.uniform(*C["color_var"]) * (0.6 if rng.random() < C.get("dark", 0.0) else 1.0)
                c.col = np.clip(base * f, 0, 1)
                c.d0 = None
                c.ph = [rng.uniform(0, 6.28) for _ in range(3)]
                self.list.append(c)

    def h_low(self, c):
        return c.size * c.k * 0.5 * float(np.abs(c.rot[1]).sum())

    def launch(self, c, t):
        G, rng, s = c.G, self.rng, self.s
        tang = np.array([-c.out[2], 0.0, c.out[0]])
        c.vel = c.out * rng.uniform(*G["out"]) * s + np.array([0, rng.uniform(*G["up"]) * s, 0]) + tang * rng.uniform(-6, 6) * s
        c.state = "fly"
        if c.dissolve:
            c.dissolve_at = t + rng.uniform(*self.C["dissolve_time"])

    def start_dissolve(self, c, t, fx):
        if c.d0 is None:
            c.d0 = t
            c.dur = self.rng.uniform(*self.C["shrink"])
            fx.append(c.pos.copy())

    def step(self, t, dt):
        C, rng, s, gy = self.C, self.rng, self.s, self.gy
        g = C["gravity"] * s
        fxpos = []
        for c in self.list:
            if c.state == "dead":
                continue
            if c.state == "wait":
                if t < c.t0:
                    continue
                if c.mode == "lift":
                    c.state = "rise"
                    c.y0 = gy - c.size * 0.5
                    c.y1 = gy + c.size * 0.5 + rng.uniform(*c.G["lift"]) * s
                    c.trel = rng.uniform(*c.G["release"])
                elif c.mode == "blast":
                    self.launch(c, t)
                else:
                    c.state = "orbit"
                    c.r0, c.y = c.r, gy + c.size * 0.5
                    c.orbit = rng.uniform(*c.G["orbit"])
                    c.rise = rng.uniform(*c.G["rise"]) * self.zone["H"]
                    c.top = gy + rng.uniform(*c.G["top"]) * self.zone["H"]
            if c.d0 is not None:
                c.k = 1 - (t - c.d0) / c.dur
                if c.k <= 0:
                    c.state = "dead"
                    continue
            if c.state == "rise":
                u = min(1.0, max(0.0, (t - c.t0) / max(c.trel - c.t0, 1e-3)))
                e = 1 - (1 - u) ** 3
                jit = np.array([math.sin(37 * t + c.ph[0]) * 0.12, math.sin(29 * t + c.ph[1]) * 0.08,
                                math.sin(41 * t + c.ph[2]) * 0.12]) * s * u
                c.pos = self.o0 + c.out * c.r + np.array([0, c.y0 + (c.y1 - c.y0) * e, 0]) + jit
                c.rot = axis_angle(c.axis, c.spin * 0.15 * dt) @ c.rot
                if t >= c.trel:
                    self.launch(c, t)
            elif c.state == "fly":
                c.vel = c.vel + np.array([0, -g * (0.35 if c.d0 is not None else 1.0) * dt, 0])
                c.pos = c.pos + c.vel * dt
                c.rot = orthonormal(axis_angle(c.axis, c.spin * dt) @ c.rot)
                if c.dissolve and c.d0 is None and t >= c.dissolve_at:
                    self.start_dissolve(c, t, fxpos)
                low = c.pos[1] - self.h_low(c)
                if low <= gy and c.vel[1] < 0 and c.d0 is None:
                    c.pos[1] += gy - low
                    c.vel[1] = -c.vel[1] * C["bounce"]
                    c.vel[0] *= C["friction"]
                    c.vel[2] *= C["friction"]
                    c.spin *= 0.55
                    c.bounces += 1
                    if abs(c.vel[1]) < 7 * s or c.bounces >= 3:
                        c.state, c.ts, c.rot0, c.rot1 = "settle", t, c.rot.copy(), flat_rot(c.rot)
                        c.vel = np.zeros(3)
            elif c.state == "settle":
                u = min(1.0, (t - c.ts) / C["settle"])
                c.rot = orthonormal(c.rot0 * (1 - u) + c.rot1 * u)
                c.pos[1] = gy + self.h_low(c)
                if u >= 1:
                    c.state = "rest"
                    c.rest_end = min(t + rng.uniform(*C["rest"]), self.cleanup - C["fade"] - 0.05)
            elif c.state == "rest":
                if t >= c.rest_end:
                    c.state, c.tf = "fade", t
            elif c.state == "fade":
                c.alpha = 1 - (t - c.tf) / C["fade"]
                if c.alpha <= 0:
                    c.state = "dead"
            elif c.state == "orbit":
                c.ang += c.orbit * dt
                c.y += c.rise * dt
                prog = min(1.0, max(0.0, (c.y - gy) / max(c.top - gy, 1e-3)))
                r = c.r0 * (1 - 0.35 * prog)
                c.pos = self.o0 + np.array([math.cos(c.ang) * r, c.y, -math.sin(c.ang) * r])
                c.rot = orthonormal(axis_angle(c.axis, c.spin * dt) @ c.rot)
                if c.y >= c.top:
                    self.start_dissolve(c, t, fxpos)
                if t >= c.G["release"] and c.d0 is None:
                    tang = np.array([-math.sin(c.ang), 0.0, -math.cos(c.ang)])
                    c.vel = tang * c.orbit * r + np.array([0, rng.uniform(4, 12) * s, 0])
                    c.state, c.dissolve = "fly", True
                    c.dissolve_at = t + rng.uniform(0.15, 0.45)
        fx = self.C.get("fx")
        return [(fx, self.s, p) for p in fxpos] if fx else []

    def visible(self):
        return [c for c in self.list if c.state not in ("wait", "dead")]

    def draw_shadows(self, buf, cam):
        from PIL import ImageDraw, ImageFilter
        H, W = buf.shape[:2]
        for c in self.visible():
            sz = c.size * c.k
            h = c.pos[1] - self.gy - sz * 0.5
            a = 0.35 * max(0.0, 1 - h / (4 + 3 * sz)) * c.alpha
            if a < 0.02:
                continue
            rr = 0.62 * sz * (1 + 0.1 * max(h, 0))
            pts = [cam.project(np.array([c.pos[0] + rr * math.cos(q), self.gy + 0.02, c.pos[2] + rr * math.sin(q)]))
                   for q in np.linspace(0, 2 * math.pi, 14, endpoint=False)]
            if any(p is None for p in pts):
                continue
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            x0, y0 = int(math.floor(min(xs))) - 2, int(math.floor(min(ys))) - 2
            x1, y1 = int(math.ceil(max(xs))) + 2, int(math.ceil(max(ys))) + 2
            if x1 <= 0 or y1 <= 0 or x0 >= W or y0 >= H or x1 - x0 > 400:
                continue
            m = Image.new("L", (x1 - x0, y1 - y0), 0)
            ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in zip(xs, ys)], fill=255)
            m = m.filter(ImageFilter.GaussianBlur(1.2))
            mm = np.asarray(m, np.float32)[..., None] / 255 * a
            xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
            sub = mm[ya - y0:yb - y0, xa - x0:xb - x0]
            buf[ya:yb, xa:xb] *= (1 - sub)

    def draw_cube(self, buf, cam, c, t):
        from PIL import ImageDraw
        sz = c.size * c.k
        if sz < 0.02 or c.alpha <= 0:
            return
        corners = {}
        for f in self.FACES:
            for q in f:
                if q not in corners:
                    w = c.pos + c.rot @ (np.array(q, float) * sz * 0.5)
                    pr = cam.project(w)
                    if pr is None:
                        return
                    corners[q] = (pr[0], pr[1], w)
        xs = [v[0] for v in corners.values()]
        ys = [v[1] for v in corners.values()]
        H, W = buf.shape[:2]
        x0, y0 = int(math.floor(min(xs))) - 1, int(math.floor(min(ys))) - 1
        x1, y1 = int(math.ceil(max(xs))) + 1, int(math.ceil(max(ys))) + 1
        if x1 <= 0 or y1 <= 0 or x0 >= W or y0 >= H or (x1 - x0) * (y1 - y0) > 250000:
            return
        ss = 4 if (x1 - x0) < 60 else 2
        pw, ph = (x1 - x0), (y1 - y0)
        rgb = np.zeros((ph, pw, 3), np.float32)
        acc = np.zeros((ph, pw, 1), np.float32)
        neon_u = 0.0
        if c.neon:
            neon_u = 1.0
        elif c.d0 is not None:
            neon_u = min(1.0, (t - c.d0) / 0.06)
        for f, nrm in zip(self.FACES, self.NORMALS):
            n = c.rot @ np.array(nrm, float)
            fc = c.pos + n * sz * 0.5
            if n @ (cam.C - fc) <= 0:
                continue
            shade = 0.42 + 0.58 * max(0.0, float(n @ self.SUN))
            col = c.col * shade
            for Lt in self.lights:
                inten = light_at(Lt, t)
                if inten <= 0:
                    continue
                for lo in zone_light_points(Lt, self.zone, self.s):
                    dv = self.o0 + lo - c.pos
                    d = np.linalg.norm(dv)
                    rng_ = min(Lt["range"] * self.s, 60.0)
                    if d >= rng_:
                        continue
                    fall = (1 - d / rng_) ** 2
                    col = col + c.col * (np.array(Lt["color"], float) / 255) * inten * 0.16 * \
                        max(0.0, float(n @ dv) / d) * fall
            if neon_u > 0:
                col = col * (1 - neon_u) + c.ncol * 1.3 * neon_u
            m = Image.new("L", (pw * ss, ph * ss), 0)
            ImageDraw.Draw(m).polygon([((corners[q][0] - x0) * ss, (corners[q][1] - y0) * ss) for q in f], fill=255)
            mm = np.asarray(m.resize((pw, ph), Image.BOX), np.float32)[..., None] / 255
            mm = np.minimum(mm, 1 - acc)
            rgb += mm * col
            acc += mm
        a = acc * c.alpha
        xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
        dst = buf[ya:yb, xa:xb]
        sa = a[ya - y0:yb - y0, xa - x0:xb - x0]
        srgb = rgb[ya - y0:yb - y0, xa - x0:xb - x0] * c.alpha
        dst *= (1 - sa)
        dst += srgb


# --------------------------------------------------------------- rayo que se apunta (dinámico)
def look_frame(d):
    """Rotación como CFrame.lookAt(A, A + d): columnas X (derecha), Y (arriba), Z (= -d)."""
    d = np.asarray(d, float) / np.linalg.norm(d)
    up = np.array([0.0, 0.0, 1.0]) if abs(d[1]) > 0.999 else np.array([0.0, 1.0, 0.0])
    right = np.cross(d, up)
    right /= np.linalg.norm(right)
    up2 = np.cross(right, d)
    return np.stack([right, up2, -d], axis=1)


def ray_scene(A, d, max_len, ground_y, props):
    """Primera superficie en el camino del rayo: el suelo (y = ground_y) o una caja de props. Devuelve la distancia
    (o None si no toca nada antes de max_len)."""
    best = None
    if d[1] < -1e-6:
        tg = (ground_y - A[1]) / d[1]
        if 0 < tg <= max_len:
            best = tg
    for pr in props or []:
        lo = np.array(pr["pos"], float) - np.array([pr["size"][0] / 2, 0, pr["size"][2] / 2])
        hi = lo + np.array(pr["size"], float)
        with np.errstate(divide="ignore", invalid="ignore"):
            t1, t2 = (lo - A) / d, (hi - A) / d
        tn, tf = np.nanmax(np.minimum(t1, t2)), np.nanmin(np.maximum(t1, t2))
        if tn <= tf and tf > 0 and 0 < tn <= max_len and (best is None or tn < best):
            best = tn
    return best


def render_beam(spec, tex_folder, out_dir, cam, path, scale=1.0, duration=None, seed=7, ground_y=0.0,
                background=None, bloom=None, only_frames=None, props=None, info=None):
    """El rayo que se apunta (como playBeam en el módulo): path(t) -> (origen, dirección) en cada cuadro. Lanza el
    rayo contra el suelo y los props, se corta en la primera superficie (o en max_len × escala) y mueve con él el
    impacto (capas impact / on_hit), la punta (line_u = 1), lo que va a lo largo (cajas len_k) y el suelo de
    debajo (at_ground); deja marcas (trail) al barrer el suelo. info: lista donde se anota (t, largo, pega)."""
    rng = random.Random(seed)
    tb = TexBank(tex_folder)
    Bq = spec["beam"]
    duration = duration or spec["duration"] + 0.15
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    bg = background if background is not None else make_background(cam, ground_y)
    max_len = Bq["max_len"] * scale
    parts, meteors, pending = [], [], []        # pending: (t, fn) ráfagas programadas
    streams = [L for L in spec["layers"] if L.get("stream") and not L.get("decal")]
    acc = {id(L): 0.0 for L in streams}
    trails = [L for L in spec["layers"] if L.get("trail")]
    onhit = [L for L in spec["layers"] if L.get("on_hit")]
    st = {"len": 0.05, "hit": False, "was": False, "last_end": -1e9, "ground": None, "trail_t": -1e9,
          "trail_p": None, "A": None, "R": np.eye(3)}

    def tip_origin(L):
        return st["A"] + st["R"] @ np.array([0.0, 0.0, -L.get("line_u", 0.0) * st["len"]])

    def gate(L):
        if L.get("at_ground"):
            return st["hit"] and st["ground"] is not None
        if L.get("impact"):
            return st["hit"]
        return True

    def emit_layer(L, n):
        if L.get("at_ground"):
            g = st["ground"]
            if g is None:
                return
            for _ in range(n):
                parts.append(spawn(L, g, rng, scale, np.eye(3), st["len"]))
        elif L.get("type") == "meteor":
            for _ in range(n):
                meteors.append(spawn_meteor(L, tip_origin(L), rng, scale, st["R"]))
        else:
            for _ in range(n):
                parts.append(spawn(L, tip_origin(L), rng, scale, st["R"], st["len"]))

    for L in spec["layers"]:
        if L.get("on_hit") or L.get("trail"):
            continue
        for ev in L.get("emit", []):
            def fire(L=L, n=ev[1]):
                if gate(L):
                    emit_layer(L, n)
            pending.append((ev[0], fire))
    dt = 1.0 / FPS
    stats = []
    for fi in range(nframes):
        t = fi * dt
        A, d = path(t)
        A, d = np.asarray(A, float), np.asarray(d, float) / np.linalg.norm(d)
        head = min(max((t - Bq["start"]) / max(Bq["grow"], 1e-3), 0.0), 1.0) * max_len
        th = ray_scene(A, d, max_len, ground_y, props)
        ray_len = th if th is not None else max_len
        st["len"] = max(min(ray_len, head), 0.05)
        st["hit"] = th is not None and head >= ray_len and t < Bq["stop"]
        st["A"], st["R"] = A, look_frame(d)
        P = A + d * st["len"]
        st["ground"] = None
        if st["hit"]:
            Q = P - d * 2 * scale
            st["ground"] = np.array([Q[0], ground_y, Q[2]])
        if info is not None:
            info.append((t, st["len"], st["hit"]))
        # cada vez que empieza a pegar: las capas on_hit (sus emit son relativos a ese momento)
        if st["hit"] and not st["was"] and t - st["last_end"] >= Bq["rehit"]:
            for L in onhit:
                for ev in L.get("emit", []):
                    def fire(L=L, n=ev[1]):
                        if L.get("decal"):
                            if st["ground"] is not None:
                                for _ in range(n):
                                    parts.append(spawn(L, st["ground"], rng, scale, np.eye(3), st["len"]))
                        elif gate(L) or not L.get("impact"):
                            emit_layer(L, n)
                    pending.append((t + ev[0], fire))
        if st["was"] and not st["hit"]:
            st["last_end"] = t
        st["was"] = st["hit"]
        # marcas que van quedando al barrer el suelo
        g = st["ground"]
        if g is not None and t - st["trail_t"] >= Bq["trail_every"] and (
                st["trail_p"] is None or np.linalg.norm(g - st["trail_p"]) >= Bq["trail_move"] * scale):
            st["trail_t"], st["trail_p"] = t, g
            for L in trails:
                parts.append(spawn(L, g, rng, scale, np.eye(3), st["len"]))
        # ráfagas en su tiempo
        keep = []
        for (te, fn) in pending:
            if te <= t + 1e-9:
                fn()
            else:
                keep.append((te, fn))
        pending = keep
        # emisión continua (en la posición de ahora)
        for L in streams:
            rate = 0.0
            for (a0, a1, r0, r1) in L["stream"]:
                if a0 <= t <= a1:
                    rate += r0 + (r1 - r0) * (t - a0) / max(a1 - a0, 1e-6)
            if not gate(L):
                rate = 0.0
            acc[id(L)] += rate * dt
            while acc[id(L)] >= 1.0:
                acc[id(L)] -= 1.0
                emit_layer(L, 1)
        # meteoros: estelas y aterrizaje
        for m in meteors:
            if m.dead:
                continue
            if not m.landed:
                for k, TL in enumerate(m.L.get("trails", [])):
                    m.acc[k] += TL["rate"] * dt
                    while m.acc[k] >= 1.0:
                        m.acc[k] -= 1.0
                        p = spawn(TL, m.pos, rng, scale, st["R"])
                        if TL.get("locked"):
                            p.lock, p.lofs = m, p.pos - m.pos
                        parts.append(p)
                if (m.pos[1] <= ground_y + 0.3 and m.vel[1] < 0) or m.age >= m.life:
                    m.landed = True
                    if m.pos[1] <= ground_y + 0.6:
                        lp = np.array([m.pos[0], ground_y + 0.4, m.pos[2]])
                        for LL in m.L.get("land", []):
                            if LL.get("stream"):
                                for _ in range(max(1, int(LL["stream"][0][2] * 0.6))):
                                    parts.append(spawn(LL, lp, rng, scale, np.eye(3)))
                            else:
                                for _ in range(LL["emit"][0][1]):
                                    parts.append(spawn(LL, lp, rng, scale, np.eye(3)))
                    m.dead = True
        parts = [p for p in parts if p.age < p.life]
        draw = only_frames is None or fi in only_frames
        if draw:
            buf = bg.copy()
            items = []
            for p in parts:
                dd = cam.to_cam(p.pos)
                if dd[2] > 0.5:
                    items.append((dd[2] - p.L.get("zoffset", 0.0) * p.ks, 0, p, dd))
            for pr_ in props or []:
                dd = cam.to_cam(np.asarray(pr_["pos"], float))
                if dd[2] > 0.5:
                    items.append((dd[2], 3, pr_, dd))
            if t >= Bq["start"]:
                B0, B1 = A, A + d * st["len"]
                for bi, Bm in enumerate(spec["beams"]):
                    w = Bm["width"] * scale * eval_seq(Bm["width_t"], t) * \
                        (1 + Bm["pulse"] * smooth_noise(bi * 7.1, t * Bm["pulse_hz"]))
                    bfade = eval_seq(Bm["alpha_t"], t)
                    if w > 0.02 and bfade < 0.999:
                        if not st["hit"]:          # sin superficie: la punta se esfuma (igual que el módulo)
                            kp = [k for k in Bm["transparency"] if k[0] < 0.8]
                            v = float(np.interp(0.8, [k[0] for k in Bm["transparency"]],
                                                [k[1] for k in Bm["transparency"]]))
                            Bm = dict(Bm, transparency=kp + [(0.8, v), (1.0, 1.0)])
                        dz = cam.to_cam((B0 + B1) * 0.5)[2] - Bm.get("zoffset", 0.0) * scale
                        items.append((dz, 4, (Bm, B0, B1, w, bfade), None))
            items.sort(key=lambda x: -x[0])
            for _, kind, obj, dd in items:
                if kind == 3:
                    draw_box(buf, cam, obj)
                elif kind == 4:
                    draw_beam(buf, tb, cam, *obj, t, scale)
                else:
                    draw_particle(buf, tb, cam, obj, dd, scale, ground_y, 1.0)
            for m in meteors:
                if m.dead:
                    continue
                pr = cam.project(m.pos)
                if pr is None:
                    continue
                sp = m.L["sprite"]
                px = cam.f * m.size / pr[2]
                gl = sp.get("glow")
                if gl:
                    gs = tb.sprite(gl["texture"], "None", 0, px * gl["size_k"], px * gl["size_k"], 0)
                    gs[..., :3] *= np.array(gl["color"], float) / 255
                    gs[..., 3] *= gl["alpha"]
                    draw_sprite(buf, gs, pr[0], pr[1], 1.0, gl.get("brightness", 1.4))
                spr = tb.sprite(sp["texture"], sp.get("layout", "Grid2x2"), m.frame, px, px, m.rot)
                spr[..., :3] *= np.array(sp.get("color", (255, 255, 255)), float) / 255
                draw_sprite(buf, spr, pr[0], pr[1], 0.0, 1.0)
            if bloom:
                buf = apply_bloom(buf, **bloom)
            Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, f"{fi:04d}.png"))
        stats.append(len(parts))
        # física
        for m in meteors:
            if m.dead:
                continue
            accm = np.asarray(m.L.get("accel", (0, -100, 0)), float) * scale
            m.vel = m.vel * (2.0 ** (-m.L.get("drag", 0.0) * dt)) + accm * dt
            m.pos = m.pos + m.vel * dt
            m.rot += m.rots * dt
            m.age += dt
        for p in parts:
            L = p.L
            accp = np.asarray(L.get("accel", (0, 0, 0)), float) * p.ks
            p.vel = p.vel * (2.0 ** (-L.get("drag", 0.0) * dt)) + accp * dt
            if p.lock is not None:
                p.lofs = p.lofs + p.vel * dt
                p.pos = p.lock.pos + p.lofs
            else:
                p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats


# --------------------------------------------------------------- aura alrededor de un modelo
def figure_depth(cam, boxes, off):
    """Profundidad (a lo largo del rayo) y normal de la caja más cercana en cada píxel: cajas alineadas a los ejes
    {"pos" (centro de la base), "size", "color"} desplazadas por off. inf donde no hay figura."""
    W, H = cam.W, cam.H
    us, vs = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    D = cam.ray(us.ravel(), vs.ravel())                         # 3 x N
    depth = np.full(D.shape[1], np.inf)
    nrm = np.zeros((3, D.shape[1]))
    col = np.zeros((3, D.shape[1]))
    inv = 1.0 / np.where(np.abs(D) < 1e-9, 1e-9, D)
    for b in boxes:
        sz = np.asarray(b["size"], float)
        c = np.asarray(b["pos"], float) + off + np.array([0, sz[1] / 2, 0])
        lo, hi = c - sz / 2, c + sz / 2
        t1 = (lo[:, None] - cam.C[:, None]) * inv
        t2 = (hi[:, None] - cam.C[:, None]) * inv
        tmin, tmax = np.minimum(t1, t2), np.maximum(t1, t2)
        tn = tmin.max(0)
        tf = tmax.min(0)
        hit = (tn <= tf) & (tf > 0) & (tn < depth)
        if not hit.any():
            continue
        ax = tmin.argmax(0)
        depth[hit] = tn[hit]
        n = np.zeros((3, D.shape[1]))
        n[ax, np.arange(D.shape[1])] = -np.sign(D[ax, np.arange(D.shape[1])])
        nrm[:, hit] = n[:, hit]
        col[:, hit] = (np.asarray(b["color"], float) / 255)[:, None]
    return depth.reshape(H, W), nrm.reshape(3, H, W), col.reshape(3, H, W)


def box_surface_point(rng, b, off):
    sz = np.asarray(b["size"], float)
    c = np.asarray(b["pos"], float) + off + np.array([0, sz[1] / 2, 0])
    areas = np.array([sz[1] * sz[2], sz[1] * sz[2], sz[0] * sz[2], sz[0] * sz[2], sz[0] * sz[1], sz[0] * sz[1]])
    f = rng.choices(range(6), weights=areas)[0]
    p = np.array([rng.uniform(-0.5, 0.5) for _ in range(3)]) * sz
    ax = f // 2
    p[ax] = (0.5 if f % 2 == 0 else -0.5) * sz[ax]
    return c + p


def render_aura(spec, tex_folder, out_dir, cam, boxes, duration, off_fn=None, stop_at=None, scale=1.0, seed=7,
                ground_y=0.0, background=None, bloom=None, only_frames=None):
    """El aura como playAura en el módulo: el delineado (Highlight) y las capas surface / body / feet sobre una
    figura hecha de cajas. off_fn(t) = desplazamiento de la figura (para verla moverse); stop_at = cuándo se apaga."""
    from scipy.ndimage import binary_dilation
    rng = random.Random(seed)
    tb = TexBank(tex_folder)
    Au = spec["aura"]
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    bg = background if background is not None else make_background(cam, ground_y)
    off_fn = off_fn or (lambda t: np.zeros(3))
    lo = np.min([np.asarray(b["pos"], float) - np.asarray(b["size"], float) * [0.5, 0, 0.5] for b in boxes], 0)
    hi = np.max([np.asarray(b["pos"], float) + np.asarray(b["size"], float) * [0.5, 1, 0.5] for b in boxes], 0)
    size0 = hi - lo
    k = scale * min(max(size0[1] / Au["ref"], 0.25), 8)
    areas = [2 * (b["size"][0] * b["size"][1] + b["size"][1] * b["size"][2] + b["size"][2] * b["size"][0]) for b in boxes]
    parts, acc = [], {}
    last_surge = 0.0
    c1, c2 = np.array(Au["outline"][0], float) / 255, np.array(Au["outline"][1], float) / 255
    fill = np.array(Au["fill"], float) / 255
    dt = 1.0 / FPS
    stats = []

    def emit(L, off):
        if L["aura"] == "surface":
            b = rng.choices(boxes, weights=areas)[0]
            pos = box_surface_point(rng, b, off)
        elif L["aura"] == "body":
            f = L.get("box", (1, 1, 1))
            ctr = (lo + hi) / 2 + off
            pos = ctr + np.array([rng.uniform(-0.5, 0.5) * size0[i] * f[i] for i in range(3)])
        else:
            ctr = (lo + hi) / 2 + off
            r = max(size0[0], size0[2]) * L.get("radius_k", 0.6) / 2 * math.sqrt(rng.random())
            a = rng.uniform(0, 2 * math.pi)
            pos = np.array([ctr[0] + r * math.cos(a), ground_y, ctr[2] + r * math.sin(a)])
        p = spawn(L, pos, rng, k)
        return p

    for fi in range(nframes):
        t = fi * dt
        off = np.asarray(off_fn(t), float)
        on = min(max(t / Au["fade_in"], 0.0), 1.0)
        if stop_at is not None:
            on = min(on, max(0.0, 1 - (t - stop_at) / Au["fade_out"]))
        surge = False
        if on > 0.5 and t - last_surge >= Au["surge"]:
            last_surge, surge = t, True
        surge_k = math.exp(-(t - last_surge) / 0.25) if last_surge > 0 else 0.0
        for L in spec["layers"]:
            key = id(L)
            acc[key] = acc.get(key, 0.0) + L.get("rate", 0) * on * dt
            n = int(acc[key])
            acc[key] -= n
            if surge:
                n += int(L.get("surge", 0))
            for _ in range(n):
                parts.append(emit(L, off))
        parts = [p for p in parts if p.age < p.life]
        if only_frames is None or fi in only_frames:
            buf = bg.copy()
            depth, nrm, col = figure_depth(cam, boxes, off)
            mask = np.isfinite(depth)
            shade = 0.45 + 0.55 * np.clip(np.einsum("ihw,i->hw", nrm, np.asarray(CubeSim.SUN, float)), 0, None)
            buf[mask] = (col.transpose(1, 2, 0) * shade[..., None])[mask]
            # el Highlight: relleno que respira y el delineado
            w = 0.5 + 0.5 * math.sin(t * math.pi * 2 * Au["pulse_hz"])
            ft = Au["fill_t"][0] + (Au["fill_t"][1] - Au["fill_t"][0]) * (1 - w)
            fa = min(1.0, (1 - ft) * on * (1 + surge_k * 0.6))
            buf[mask] = buf[mask] * (1 - fa) + fill * fa
            ot = Au["outline_t"][0] + (Au["outline_t"][1] - Au["outline_t"][0]) * (1 - w)
            oa = (1 - ot * (1 - surge_k)) * on
            ring = binary_dilation(mask, iterations=max(2, int(round(3 * cam.W / 960)))) & ~mask
            oc = c1 + (c2 - c1) * min(1.0, w * 0.7 + surge_k * 0.6)
            buf[ring] = buf[ring] * (1 - oa) + oc * 1.6 * oa
            items = []
            for p in parts:
                dd = cam.to_cam(p.pos)
                if dd[2] > 0.5:
                    items.append((dd[2] - p.L.get("zoffset", 0.0) * p.ks, p, dd))
            items.sort(key=lambda x: -x[0])
            for _, p, dd in items:
                draw_particle(buf, tb, cam, p, dd, k, ground_y, 1.0, occ=depth)
            if bloom:
                buf = apply_bloom(buf, **bloom)
            Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, f"{fi:04d}.png"))
        stats.append(len(parts))
        for p in parts:
            L = p.L
            accp = np.asarray(L.get("accel", (0, 0, 0)), float) * p.ks
            p.vel = p.vel * (2.0 ** (-L.get("drag", 0.0) * dt)) + accp * dt
            p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats



# --------------------------------------------------------------- aura de contorno (el delineado ES el aura)
def box_rays(boxes, off, C, D):
    """Rayos desde C con direcciones D (3×N, unitarias) contra las cajas de la figura: distancia al primer choque
    (inf si no toca) e índice de la caja."""
    N = D.shape[1]
    best = np.full(N, np.inf)
    idx = np.full(N, -1)
    inv = 1.0 / np.where(np.abs(D) < 1e-9, 1e-9, D)
    for bi, b in enumerate(boxes):
        sz = np.asarray(b["size"], float)
        c = np.asarray(b["pos"], float) + off + np.array([0, sz[1] / 2, 0])
        lo, hi = c - sz / 2, c + sz / 2
        t1 = (lo[:, None] - C[:, None]) * inv
        t2 = (hi[:, None] - C[:, None]) * inv
        tn = np.minimum(t1, t2).max(0)
        tf = np.maximum(t1, t2).min(0)
        hit = (tn <= tf) & (tf > 0) & (tn < best)
        best[hit] = tn[hit]
        idx[hit] = bi
    return best, idx


def silhouette_points(cam, boxes, off, S):
    """El contorno de la figura visto desde la cámara (lo mismo que silhouette() en el módulo). Una rejilla de rayos
    cubre el recuadro de la figura en pantalla (celdas de S["cell"] × alto de la pantalla, y como mucho S["max_rays"]
    rayos); los nodos que tocan la figura y tienen al lado (arriba, abajo, izquierda o derecha) uno que no la toca son
    el contorno. Devuelve (puntos del contorno, hacia afuera en el plano de la pantalla, puntos del cuerpo)."""
    corners = []
    for b in boxes:
        sz = np.asarray(b["size"], float)
        base = np.asarray(b["pos"], float) + off
        for dx in (-0.5, 0.5):
            for dy in (0.0, 1.0):
                for dz in (-0.5, 0.5):
                    q = cam.project(base + sz * np.array([dx, dy, dz]))
                    if q is None:
                        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3))
                    corners.append(q[:2])
    corners = np.array(corners)
    x0, y0 = corners.min(0)
    x1, y1 = corners.max(0)
    g = max(S["cell"] * cam.H, math.sqrt(max((x1 - x0) * (y1 - y0), 1.0) / S["max_rays"]))
    x0, y0 = max(x0 - g, 0.0), max(y0 - g, 0.0)
    x1, y1 = min(x1 + g, cam.W - 1.0), min(y1 + g, cam.H - 1.0)
    if x1 <= x0 or y1 <= y0:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3))
    xs = np.arange(x0, x1 + 1e-6, g)
    ys = np.arange(y0, y1 + 1e-6, g)
    U, Vv = np.meshgrid(xs, ys)
    D = cam.ray(U.ravel(), Vv.ravel())
    dist, _ = box_rays(boxes, off, cam.C, D)
    hit = np.isfinite(dist).reshape(len(ys), len(xs))
    pad = np.pad(hit, 1, constant_values=False)
    lm, rm = ~pad[1:-1, :-2], ~pad[1:-1, 2:]
    um, dm = ~pad[:-2, 1:-1], ~pad[2:, 1:-1]
    edge = hit & (lm | rm | um | dm)
    nx = (rm.astype(float) - lm.astype(float))[edge]
    ny = (dm.astype(float) - um.astype(float))[edge]
    out = cam.R[0][None, :] * nx[:, None] - cam.R[1][None, :] * ny[:, None]
    ln = np.linalg.norm(out, axis=1)
    out[ln < 1e-6] = np.array([0.0, 1.0, 0.0])
    out /= np.linalg.norm(out, axis=1)[:, None]
    P = (cam.C[:, None] + D * np.where(np.isfinite(dist), dist, 0.0)).T
    ef = edge.ravel()
    bf = (hit & ~edge).ravel()
    return P[ef], out, P[bf]


def sil_frame(direction, up_w):
    """Rotación cuya -Z (Front) apunta hacia afuera del contorno, mezclada con hacia arriba (up_w = 0..1)."""
    d = np.asarray(direction, float) * (1 - up_w) + np.array([0.0, 1.0, 0.0]) * up_w
    f = d / max(np.linalg.norm(d), 1e-9)
    r = np.cross(f, [0.0, 1.0, 0.0])
    if np.linalg.norm(r) < 1e-4:
        r = np.array([1.0, 0.0, 0.0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return np.column_stack([r, u, -f])


def render_silhouette_aura(spec, tex_folder, out_dir, cam_fn, boxes, duration, stop_at=None, scale=1.0, seed=7,
                           ground_y=0.0, dark=True, bloom=None, only_frames=None, extra=None):
    """El aura de contorno como playSilhouette en el módulo: cada cuadro busca el contorno de la figura visto desde la
    cámara (cam_fn(t) -> Camera) y de ahí salen las capas (sil = "edge": del contorno hacia afuera y arriba; "body":
    de los puntos de adentro; "feet": alrededor de los pies). Las partículas que quedan detrás del cuerpo no se ven,
    así que el aura sale del borde. burst = ráfaga al encender; end_burst = al apagar (stop_at)."""
    rng = random.Random(seed)
    tb = TexBank(tex_folder)
    Sc = spec["silhouette"]
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    lo = np.min([np.asarray(b["pos"], float) - np.asarray(b["size"], float) * [0.5, 0, 0.5] for b in boxes], 0)
    hi = np.max([np.asarray(b["pos"], float) + np.asarray(b["size"], float) * [0.5, 1, 0.5] for b in boxes], 0)
    size0 = hi - lo
    k = scale * min(max(size0[1] / Sc["ref"], 0.25), 8)
    off = np.zeros(3)
    parts, acc = [], {}
    edge_p, edge_o, body_p = np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3))
    next_scan = 0.0
    dt = 1.0 / FPS
    stats = []
    burst_done, end_done = False, False

    def emit(L, n):
        mode = L.get("sil", "edge")
        side = L.get("side")
        if mode == "edge" and side:          # solo el contorno de arriba y los lados ("up") o el de abajo ("down")
            cand = np.nonzero(edge_o[:, 1] > -0.35)[0] if side == "up" else np.nonzero(edge_o[:, 1] < -0.35)[0]
        else:
            cand = None
        for _ in range(n):
            if mode == "edge":
                if len(edge_p) == 0 or (cand is not None and len(cand) == 0):
                    return
                i = int(cand[rng.randrange(len(cand))]) if cand is not None else rng.randrange(len(edge_p))
                pos = edge_p[i] + edge_o[i] * L.get("push", 0.0) * k
                parts.append(spawn(L, pos, rng, k, sil_frame(edge_o[i], L.get("up", 0.0))))
            elif mode == "body":
                if len(body_p) == 0:
                    return
                pos = body_p[rng.randrange(len(body_p))]
                parts.append(spawn(L, pos, rng, k))
            else:
                ctr = (lo + hi) / 2 + off
                r = max(size0[0], size0[2]) * L.get("radius_k", 0.6) / 2 * math.sqrt(rng.random())
                a = rng.uniform(0, 2 * math.pi)
                parts.append(spawn(L, np.array([ctr[0] + r * math.cos(a), ground_y + L.get("h", 0.0) * k,
                                                ctr[2] + r * math.sin(a)]), rng, k))

    for fi in range(nframes):
        t = fi * dt
        cam = cam_fn(t)
        if t >= next_scan - 1e-9:
            edge_p, edge_o, body_p = silhouette_points(cam, boxes, off, Sc)
            next_scan = t + 1.0 / Sc["hz"]
        on = min(max(t / Sc["fade_in"], 0.0), 1.0)
        if stop_at is not None:
            on = min(on, max(0.0, 1 - (t - stop_at) / Sc["fade_out"]))
        breath = 1 + Sc.get("breath", 0.0) * math.sin(2 * math.pi * Sc.get("breath_hz", 0.8) * t)
        if not burst_done:
            burst_done = True
            for L in spec["layers"]:
                if L.get("burst"):
                    emit(L, L["burst"])
        if stop_at is not None and t >= stop_at and not end_done:
            end_done = True
            for L in spec["layers"]:
                if L.get("end_burst"):
                    emit(L, L["end_burst"])
        for L in spec["layers"]:
            key = id(L)
            acc[key] = acc.get(key, 0.0) + L.get("rate", 0) * on * breath * dt
            n = int(acc[key])
            acc[key] -= n
            if n:
                emit(L, n)
        parts = [p for p in parts if p.age < p.life]
        if only_frames is None or fi in only_frames:
            buf = make_background_dark(cam, ground_y) if dark else make_background(cam, ground_y)
            depth, nrm, col = figure_depth(cam, boxes, off)
            mask = np.isfinite(depth)
            shade = 0.45 + 0.55 * np.clip(np.einsum("ihw,i->hw", nrm, np.asarray(CubeSim.SUN, float)), 0, None)
            buf[mask] = (col.transpose(1, 2, 0) * shade[..., None])[mask]
            if extra:
                extra(buf, cam, t, depth)
            items = []
            for p in parts:
                dd = cam.to_cam(p.pos)
                if dd[2] > 0.5:
                    items.append((dd[2] - p.L.get("zoffset", 0.0) * p.ks, p, dd))
            items.sort(key=lambda x: -x[0])
            for _, p, dd in items:
                draw_particle(buf, tb, cam, p, dd, k, ground_y, 1.0, occ=depth)
            if bloom:
                buf = apply_bloom(buf, **bloom)
            Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, f"{fi:04d}.png"))
        stats.append((len(parts), len(edge_p)))
        for p in parts:
            L = p.L
            accp = np.asarray(L.get("accel", (0, 0, 0)), float) * p.ks
            p.vel = p.vel * (2.0 ** (-L.get("drag", 0.0) * dt)) + accp * dt
            p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats
