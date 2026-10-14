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
        w_px, h_px = q(w_px), q(h_px)
        a = int(round(angle / 3.0)) * 3 % 360
        key = (name, layout, idx, w_px, h_px, a)
        s = self.cache.get(key)
        if s is None:
            fr = self.get(name, layout)[idx]
            im = fr.resize((w_px, h_px), Image.BILINEAR)
            if a:
                im = im.rotate(a, resample=Image.BICUBIC, expand=True)
            s = np.asarray(im, dtype=np.float32) / 255.0
            self.bytes = getattr(self, "bytes", 0) + s.nbytes
            if self.bytes > 1.5e9:
                self.cache.clear()
                self.bytes = s.nbytes
            self.cache[key] = s
        return s


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
    __slots__ = ("pos", "vel", "age", "life", "rot", "rots", "r_size", "r_tr", "frame0", "L", "seed")


def spawn(L, origin, rng, scale, Rf=None):
    """Rf: rotación (3x3) del contenedor: lleva ejes locales del emisor a mundo.
    Ojo: Acceleration en Roblox es en espacio mundo (no se rota)."""
    Rf = np.eye(3) if Rf is None else Rf
    p = P()
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
    if normal is not None and (L.get("shape") or {}).get("inout", "Outward") == "Outward":
        d = normal
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


def render(spec, tex_folder, out_dir, cam, origin=(0, 2, 0), scale=1.0, duration=None, seed=7,
           ground_y=0.0, background=None, extra_draw=None, frame_rot=None, length=0.0, bloom=None,
           only_frames=None):
    """frame_rot: rotación del contenedor (local->mundo). Emisiones (t, n, u, side, up):
    u = fracción a lo largo de la línea (adelante = -Z local), side = +X local, up = +Y."""
    rng = random.Random(seed)
    tb = TexBank(tex_folder)
    duration = duration or spec["duration"] + 0.15
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    bg = background if background is not None else make_background(cam, ground_y)
    parts = []
    events = []
    Rf = np.eye(3) if frame_rot is None else np.asarray(frame_rot, float)
    o0 = np.asarray(origin, float)
    meteors = []
    streams = []   # (L, origin, t_base)
    for L in spec["layers"]:
        oL = o0 + Rf @ np.array([0.0, 0.0, -L.get("line_u", 0.0) * length])
        if L.get("stream"):
            streams.append([L, oL, 0.0, 0.0])
        for ev in L.get("emit", []):
            t, n = ev[0], ev[1]
            pos = oL.copy()
            if len(ev) > 2:
                u, side, up = ev[2], ev[3], ev[4]
                pos = o0 + Rf @ np.array([side * scale, up * scale, -u * length])
            events.append((t, n, L, pos))
        for ev in L.get("points", []):   # (t, n, x, y, z): posición local absoluta
            t, n, x, y, z = ev
            events.append((t, n, L, o0 + Rf @ (np.array([x, y, z], float) * scale)))
    events.sort(key=lambda e: e[0])
    ei = 0
    dt = 1.0 / FPS
    stats = []
    for fi in range(nframes):
        t = fi * dt
        while ei < len(events) and events[ei][0] <= t + 1e-9:
            _, n, L, o = events[ei]
            for _ in range(n):
                if L.get("type") == "meteor":
                    meteors.append(spawn_meteor(L, o, rng, scale, Rf))
                else:
                    parts.append(spawn(L, o, rng, scale, Rf))
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
        # meteoros: estelas (por tasa) + aterrizaje
        for m in meteors:
            if m.dead:
                continue
            if not m.landed:
                for k, TL in enumerate(m.L.get("trails", [])):
                    m.acc[k] += TL["rate"] * dt
                    while m.acc[k] >= 1.0:
                        m.acc[k] -= 1.0
                        parts.append(spawn(TL, m.pos, rng, scale, Rf))
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
        # ordenar atrás -> adelante
        items = []
        for p in (parts if draw else []):
            d = cam.to_cam(p.pos)
            if d[2] <= 0.5:
                continue
            items.append((d[2] - p.L.get("zoffset", 0.0), p, d))
        items.sort(key=lambda x: -x[0])
        for _, p, d in items:
            draw_particle(buf, tb, cam, p, d, scale, ground_y)
        for m in (meteors if draw else []):
            if m.dead:
                continue
            pr = cam.project(m.pos)
            if pr is None:
                continue
            sp = m.L["sprite"]
            px = cam.f * m.size / pr[2]
            spr = tb.sprite(sp["texture"], sp.get("layout", "Grid2x2"), m.frame, px, px, m.rot).copy()
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
            acc = np.asarray(L.get("accel", (0, 0, 0)), float) * scale
            p.vel = p.vel * (2.0 ** (-drag * dt)) + acc * dt
            p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats


def decal_glow(L):
    """Multiplicador de Color3 de un Decal (igual que en el módulo Luau)."""
    return round(1.0 + 1.5 * L.get("light_emission", 0.0), 3)


def draw_particle(buf, tb, cam, p, d, scale, ground_y):
    L = p.L
    tl = min(p.age / p.life, 1.0)
    size = max(eval_seq(L["size"], tl, p.r_size) * scale, 0.0)
    if size <= 0.01:
        return
    tr = eval_seq(L.get("transparency", [(0, 0), (1, 0)]), tl, p.r_tr)
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
        spr = tb.sprite(L["texture"], layout, idx, px, px, -ang + p.rot)
        spr = spr.copy()
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
    spr = spr.copy()
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
