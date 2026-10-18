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
        off = Rf @ (np.array([rng.uniform(-0.5, 0.5) * bx, rng.uniform(-0.5, 0.5) * by,
                              rng.uniform(-0.5, 0.5) * bz]) * scale)
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
    __slots__ = ("pos", "vel", "age", "life", "rot", "rots", "size", "frame", "L", "acc", "landed", "dead")


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
    m.vel = d * rng.uniform(*L["speed"]) * scale
    m.age = 0.0
    m.life = rng.uniform(*L["lifetime"])
    sp = L["sprite"]
    m.size = rng.uniform(*sp["size"]) * scale
    m.rot = rng.uniform(0, 360)
    m.rots = rng.uniform(*sp.get("rot_speed", (0, 0)))
    m.frame = rng.randrange(4)
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
    streams = []   # (L, origin, t_base)
    for L in spec["layers"]:
        if L.get("orb"):
            continue           # van pegadas al proyectil (OrbSim)
        oL = o0 + Rf @ np.array([0.0, 0.0, -L.get("line_u", 0.0) * length])
        if L.get("stream"):
            streams.append([L, oL, 0.0, 0.0])
        for ev in L.get("emit", []):
            t, n = ev[0], ev[1]
            pos = oL.copy()
            if len(ev) > 2:
                u, side, up = ev[2], ev[3], ev[4]
                pos = o0 + Rf @ np.array([side * scale, up * scale, -u * length])
            events.append((t, n, L, pos, None, None))
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
            L, o, tb0, acc = st_
            rate = 0.0
            for (a0, a1, r0, r1) in L["stream"]:
                ta = t - tb0
                if a0 <= ta <= a1:
                    rate += r0 + (r1 - r0) * (ta - a0) / max(a1 - a0, 1e-6)
            acc += rate * dt
            while acc >= 1.0:
                acc -= 1.0
                parts.append(spawn(L, o, rng, scale, Rf))
            st_[3] = acc
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
            am = fade.get(id(obj.L), 1.0)
            if obj.spin:
                pos0 = obj.pos
                obj.pos = wp
                draw_particle(buf, tb, cam, obj, d, scale, ground_y, am)
                obj.pos = pos0
            else:
                draw_particle(buf, tb, cam, obj, d, scale, ground_y, am)
        for m in (meteors if draw else []):
            if m.dead:
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
            img = Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8))
            img.save(os.path.join(out_dir, f"{fi:04d}.png"))
            stats.append(len(parts))
        # avanzar física
        for m in meteors:
            if m.dead:
                continue
            acc = np.asarray(m.L.get("accel", (0, -100, 0)), float) * scale
            m.vel = m.vel * (2.0 ** (-m.L.get("drag", 0.0) * dt)) + acc * dt
            m.pos = m.pos + m.vel * dt
            m.rot += m.rots * dt
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


def draw_particle(buf, tb, cam, p, d, scale, ground_y, amul=1.0):
    L = p.L
    tl = min(p.age / p.life, 1.0)
    size = max(eval_seq(L["size"], tl, p.r_size) * p.ks * p.gm, 0.0)
    if size <= 0.01:
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
        if mode == "OneShot":
            idx = min(int(tl * n), n - 1)
        elif mode == "Loop":
            idx = (p.frame0 + int(p.age * fps)) % n
        else:  # Random
            idx = p.frame0 if fps <= 0 else int(abs(hash((p.seed, int(p.age * fps))))) % n
    else:
        layout, idx = "None", 0
    light = L.get("light_emission", 0.0)
    bright = L.get("brightness", 1.0)
    ori = L.get("orientation", "FacingCamera")
    z = d[2]
    f = cam.f
    if ori == "VelocityPerpendicular":
        if L.get("decal"):
            # en Roblox es un Decal: sin LightEmission (mezcla alfa normal); el módulo sobre-ilumina
            # su Color3 (>1) en proporción a light_emission para que brille con el Bloom
            light, bright = 0.0, decal_glow(L)
        draw_flat(buf, tb, cam, p, L["texture"], layout, idx, size, col, tr, light, bright)
        return
    proj = cam.project(p.pos)
    if proj is None:
        return
    cx, cy, _ = proj
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
            return (wy > ground_y).astype(np.float32)
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
        return (wy > ground_y).astype(np.float32)

    draw_sprite(buf, spr, cx, cy, light, bright, mask)


def draw_flat(buf, tb, cam, p, tex, layout, idx, size, col, tr, light, bright):
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
                lp = self.o0 + np.array([0, Lt["h"] * (self.zone["H"] if Lt.get("hu") == "H" else self.s), 0])
                dv = lp - c.pos
                d = np.linalg.norm(dv)
                rng_ = Lt["range"] * self.s
                if d >= rng_:
                    continue
                fall = (1 - d / rng_) ** 2
                col = col + c.col * (np.array(Lt["color"], float) / 255) * inten * 0.16 * max(0.0, float(n @ dv) / d) * fall
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
