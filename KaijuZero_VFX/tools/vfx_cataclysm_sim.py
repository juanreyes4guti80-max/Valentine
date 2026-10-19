"""Simulador de la ULTIMATE de Omnívora (cataclismo gravitacional) para los videos de vista previa.

La misma lógica que playCataclysm en el módulo Luau: el campo gravitacional (L, S, A), las rocas con sus estados
(enterradas temblando, vuelo, rotura, choque, tragadas, caída), los portadores de partículas (pegadas a ellos como con
LockedToPart), las cadenas de Beams (corrientes, brazos de polvo, acreción, ondas), la singularidad hecha de geometría,
la detonación, las víctimas (el mismo recorrido que cataVictimCFrame) y sus impactos (la spec CataclysmImpact, como
play()). Dibuja con las piezas de vfx_sim y agrega el destello blanco y la corrección de color de cada cuadro.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

import vfx_sim as V

FPS = V.FPS
SUN = V.CubeSim.SUN


# ----------------------------------------------------------------------------- utilidades (como en el módulo)
def smooth01(a, b, t):
    u = min(max((t - a) / max(b - a, 1e-6), 0.0), 1.0)
    return u * u * (3 - 2 * u)


def ease_out(u):
    v = 1 - min(max(u, 0.0), 1.0)
    return 1 - v * v * v


def curve(points, t):
    """evalNum del módulo: lineal entre puntos (t absolutos)."""
    if t <= points[0][0]:
        return points[0][1]
    for a, b in zip(points, points[1:]):
        if t <= b[0]:
            u = (t - a[0]) / max(b[0] - a[0], 1e-6)
            return a[1] + (b[1] - a[1]) * u
    return points[-1][1]


def noise1(seed, x):
    """Ruido suave en -0.5..0.5 (en el módulo es math.noise)."""
    i = math.floor(x)
    f = x - i

    def h(n):
        return ((math.sin(n * 127.1 + seed * 311.7) * 43758.5453) % 1.0) - 0.5
    a, b = h(i), h(i + 1)
    u = f * f * (3 - 2 * f)
    return a + (b - a) * u


def look_rot(fwd):
    """Rotación de CFrame.lookAt: columnas = derecha, arriba, -adelante (Roblox mira hacia -Z)."""
    f = np.asarray(fwd, float)
    f = f / max(np.linalg.norm(f), 1e-9)
    up = np.array([0.0, 1.0, 0.0])
    r = np.cross(f, up)
    if np.linalg.norm(r) < 1e-6:
        r = np.array([1.0, 0.0, 0.0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return np.stack([r, u, -f], 1)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def axis_angle(axis, ang):
    return V.axis_angle(np.asarray(axis, float), ang)


def cata_field(Cf, t):
    T, F, Hh = Cf["t"], Cf["field"], Cf["hole"]
    after = t >= T["det"]
    L = 0.0 if after else smooth01(T["lift"][0], T["lift"][1], t)
    S = smooth01(T["swirl"][0], T["swirl"][1], t) * (1 + F["swirl_boost"] * smooth01(T["swirl_up"][0], T["swirl_up"][1], t))
    if after:
        S *= math.exp(-(t - T["det"]) * 3)
    A = 0.0 if after else (F["a_mid"] * smooth01(T["attract"][0], T["attract"][1], t)
                           + (1 - F["a_mid"]) * smooth01(T["attract"][1], T["attract"][2], t))
    rbk = 0.0
    if T["sing"][0] <= t and not after:
        g = smooth01(T["sing"][0], T["sing"][1], t)
        rbk = (Hh["rb"][0] + (Hh["rb"][1] - Hh["rb"][0]) * g) / Hh["rb"][1]
        rbk *= 1 - (1 - Hh["crit_shrink"]) * smooth01(T["crit"][0] + 0.8, T["crit"][1], t)
    return L, S, A, rbk


class Tracer:
    __slots__ = ("r", "th", "y", "w", "band", "rise", "inward", "vy", "seed")


def new_tracer(rng, r, th, y, band):
    o = Tracer()
    o.r, o.th, o.y, o.band = r, th, y, band
    o.w, o.rise, o.inward = rng.uniform(0.85, 1.15), rng.uniform(0.6, 1.0), rng.uniform(0.85, 1.15)
    o.vy, o.seed = 0.0, rng.uniform(0, 1000)
    return o


def step_tracer(o, dt, F, R, Hs, k, L, S, A):
    omega = F["omega0"] * o.w * (R / (o.r + F["r_core"] * R)) ** F["omega_pow"] * S
    o.th += omega * dt
    if A > 0:
        o.r = max(o.r - A * F["c_in"] * o.inward * (o.r + 0.06 * R) * dt, 0.0)
    yb = o.band * Hs
    yt = yb + A * (Hs - yb) * math.exp(-o.r / (F["funnel"] * R))
    vmax = 140 * k * o.rise
    o.y += min(max((yt - o.y) * o.rise * L * F["c_rise"], -vmax), vmax) * dt + o.vy * dt
    o.vy *= math.exp(-1.6 * dt)
    if A > 0:
        o.y += (Hs - o.y) * min(1.0, A * A * F["c_up"] * dt)


def tracer_pos(o, C, F, R, Hs, t):
    rr = max(o.r + R * F["turb_r"] * noise1(o.seed, t * 0.35), 0.0)
    yy = o.y + Hs * F["turb_y"] * noise1(o.seed + 7.3, t * 0.5)
    return C + np.array([math.cos(o.th) * rr, yy, math.sin(o.th) * rr])


def skewed(rng, lo, hi, skew):
    return lo + (hi - lo) * rng.random() ** skew


# ----------------------------------------------------------------------------- piezas que se dibujan
class Carrier:
    """Caja invisible que lleva emisores (LockedToPart: las partículas viajan pegadas a ella)."""

    def __init__(self, layers, index):
        self.pos = np.zeros(3)
        self.Rm = np.eye(3)
        self.size = np.ones(3)
        self.ems = [[L, 0.0] for L in layers if not (L.get("every") and index % L["every"] != 0)]
        self.on = True
        self.o = None
        self.ang = 0.0
        self.spin = 0.0
        self.r0 = 0.0
        self.t0 = self.t1 = 0.0


def emit_box(car, L, rng, k, parts):
    off = (np.array([rng.random(), rng.random(), rng.random()]) - 0.5) * car.size
    if L.get("locked"):
        p = V.spawn(L, np.zeros(3), rng, k)
        p.lofs = off + p.pos
        p.lock = car
        p.pos = car.pos + car.Rm @ p.lofs
    else:
        p = V.spawn(L, car.pos + car.Rm @ off, rng, k, car.Rm)
    parts.append(p)


def run_emitters(car, t, dt, gate, rng, k, parts):
    for em in car.ems:
        L = em[0]
        env = curve(L["env"], t) if L.get("env") else 1.0
        em[1] += L.get("rate", 0) * env * gate * dt
        while em[1] >= 1.0:
            em[1] -= 1.0
            emit_box(car, L, rng, k, parts)


class Rock:
    __slots__ = ("o", "size", "s0", "kind", "state", "t1", "Rm", "axis", "spin", "pos", "break_at", "die_at",
                 "die_t", "die_dur", "consume", "vel", "base", "color", "scale")


def chain_spec_beam(Bs, k):
    return {"texture": Bs["texture"], "mode": "Wrap", "tex_len": Bs["tex_len"] * k, "speed": Bs["speed"],
            "light_emission": Bs["light_emission"], "brightness": Bs["brightness"],
            "color": [(c[0], tuple(c[1])) for c in Bs["color"]]}


def chain_items(Bs, k, pts, widths, trs, closed, items, cam):
    """Segmentos de una cadena de Beams (cada Beam con su ancho de punta a punta y transparencia constante)."""
    base = chain_spec_beam(Bs, k)
    n = len(pts)
    # como en el módulo: cerca de la cámara se desvanece (un Beam ancho pegado a la cámara sería una pared)
    trs = [1 - (1 - tr) * min(max((float(np.linalg.norm(p - cam.C)) - w * 0.8) / (w * 2.5), 0), 1)
           for p, w, tr in zip(pts, widths, trs)]
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        tr = max(trs[i], trs[j])
        if tr >= 0.995:
            continue
        Bm = dict(base, w0=widths[i], w1=widths[j], transparency=[(0, tr), (1, tr)])
        z = cam.to_cam((pts[i] + pts[j]) * 0.5)[2]
        if z > 0.6:
            items.append((z, 4, (Bm, pts[i], pts[j])))


def loop_points(C, radius, y, n):
    return [C + np.array([math.cos(2 * math.pi * i / n) * radius, y, math.sin(2 * math.pi * i / n) * radius])
            for i in range(n)]


OBB_FACES = [(0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)]


def draw_obb(buf, cam, ctr, Rm, size, color):
    """Caja girada y sombreada (las rocas, los trozos de terreno, las figuras)."""
    half = np.asarray(size, float) * 0.5
    H, W = buf.shape[:2]
    pc = cam.project(ctr)
    if pc is None:
        return
    rad_px = cam.f * float(np.linalg.norm(half)) / pc[2]
    col = np.asarray(color, float) / 255
    if rad_px < 1.2:                       # lejísimos: un punto
        x, y = int(pc[0]), int(pc[1])
        if 0 <= x < W and 0 <= y < H:
            buf[y, x] = buf[y, x] * 0.4 + col * 0.6 * 0.7
        return
    for ax, sg in OBB_FACES:
        n = Rm[:, ax] * sg
        fc = ctr + n * half[ax]
        if n @ (cam.C - fc) <= 0:
            continue
        a1, a2 = [a for a in range(3) if a != ax]
        corners = []
        for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            q = fc + Rm[:, a1] * half[a1] * s1 + Rm[:, a2] * half[a2] * s2
            pr = cam.project(q)
            if pr is None:
                return
            corners.append((pr[0], pr[1]))
        xs, ys = [c[0] for c in corners], [c[1] for c in corners]
        x0, y0 = max(0, int(min(xs)) - 1), max(0, int(min(ys)) - 1)
        x1, y1 = min(W, int(max(xs)) + 2), min(H, int(max(ys)) + 2)
        if x0 >= x1 or y0 >= y1:
            continue
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in corners], fill=255)
        mm = np.asarray(m, np.float32)[..., None] / 255
        shade = 0.42 + 0.58 * max(0.0, float(n @ SUN))
        dst = buf[y0:y1, x0:x1]
        dst[:] = dst * (1 - mm) + col * shade * mm


def disk_mask(cam, center, radius, buf):
    """Recuadro y máscara suave del disco que proyecta una esfera (y la profundidad de su cara frontal)."""
    pr = cam.project(center)
    if pr is None:
        return None
    cx, cy, z = pr
    rp = cam.f * radius / z
    H, W = buf.shape[:2]
    x0, x1 = max(0, int(cx - rp) - 1), min(W, int(cx + rp) + 2)
    y0, y1 = max(0, int(cy - rp) - 1), min(H, int(cy + rp) + 2)
    if x0 >= x1 or y0 >= y1 or rp < 0.5:
        return None
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2) / rp
    return (x0, x1, y0, y1, d, rp)


def draw_black_ball(buf, cam, center, radius):
    dm = disk_mask(cam, center, radius, buf)
    if dm is None:
        return
    x0, x1, y0, y1, d, rp = dm
    a = np.clip((1 - d) * rp + 0.5, 0, 1)[..., None]
    dst = buf[y0:y1, x0:x1]
    dst[:] = dst * (1 - a)


def sphere_front_depth(cam, center, radius, buf):
    """Distancia (a lo largo del rayo) a la cara frontal de la esfera en cada píxel; 0 fuera de ella."""
    H, W = buf.shape[:2]
    occ = np.zeros((H, W), np.float32)
    dm = disk_mask(cam, center, radius, buf)
    if dm is None:
        return occ
    x0, x1, y0, y1, _, _ = dm
    us, vs = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    r = cam.ray(us.ravel(), vs.ravel())
    oc = center - cam.C
    b = oc @ r
    disc = b * b - (oc @ oc - radius * radius)
    tf = np.where(disc > 0, b - np.sqrt(np.maximum(disc, 0)), 0.0)
    occ[y0:y1, x0:x1] = tf.reshape(y1 - y0, x1 - x0)
    return occ


def draw_neon_ball(buf, cam, center, radius, color, alpha):
    dm = disk_mask(cam, center, radius, buf)
    if dm is None or alpha <= 0.005:
        return
    x0, x1, y0, y1, d, rp = dm
    a = (np.clip((1 - d) * rp + 0.5, 0, 1) * alpha)[..., None]
    col = np.asarray(color, float)
    dst = buf[y0:y1, x0:x1]
    dst[:] = dst * (1 - a * 0.3) + col * a


_FF = {}


def ff_noise(n=256, seed=3):
    if n not in _FF:
        from scipy.ndimage import gaussian_filter
        rng = np.random.default_rng(seed)
        a = gaussian_filter(rng.random((n, n)), 3, mode="wrap")
        a = (a - a.min()) / (a.max() - a.min())
        _FF[n] = a.astype(np.float32)
    return _FF[n]


def draw_forcefield(buf, cam, center, radius, color, alpha, t):
    """Material ForceField de Roblox: energía translúcida con dibujo que se mueve, más brillante en el borde."""
    dm = disk_mask(cam, center, radius, buf)
    if dm is None or alpha <= 0.005:
        return
    x0, x1, y0, y1, d, rp = dm
    nz = ff_noise()
    ys, xs = np.mgrid[y0:y1, x0:x1]
    u = ((xs - x0) / max(rp, 1) * 40 + t * 30).astype(int) % 256
    v = ((ys - y0) / max(rp, 1) * 40 + t * 18).astype(int) % 256
    pat = nz[v, u]
    rim = np.clip(d, 0, 1) ** 3
    a = (np.clip((1 - d) * rp + 0.5, 0, 1) * alpha * (0.12 + 0.55 * rim + 0.35 * pat * rim))[..., None]
    dst = buf[y0:y1, x0:x1]
    dst += np.asarray(color, float) * a * 1.4


def draw_bill(buf, tb, cam, pos, size, roll, tex, color, tr):
    """Decal en una Part que mira a la cámara (los anillos y discos del agujero negro)."""
    if tr >= 0.995:
        return
    pr = cam.project(pos)
    if pr is None:
        return
    px = cam.f * size / pr[2]
    if px < 1:
        return
    spr = tb.sprite(tex, "None", 0, px, px, math.degrees(roll))
    spr[..., :3] *= np.asarray(color, np.float32)
    spr[..., 3] *= (1 - tr)
    V.draw_sprite(buf, spr, pr[0], pr[1], 0.0, 1.0)


class FlatQuad:
    """Lo mínimo que draw_flat necesita de una partícula: un plano (normal = vel) girado `rot` grados."""
    __slots__ = ("pos", "vel", "rot")

    def __init__(self, pos, normal, rot):
        self.pos, self.vel, self.rot = pos, normal, rot


class SubSpec:
    """Un efecto normal (como play() en el módulo) dentro de la escena: ráfagas, Decals, rocas y emisión continua."""

    def __init__(self, spec, origin, t0, scale):
        self.spec, self.o, self.t0, self.k = spec, np.asarray(origin, float), t0, scale
        self.events = sorted([(ev[0], ev[1], L) for L in spec["layers"] for ev in L.get("emit", [])], key=lambda e: e[0])
        self.streams = [[L, 0.0] for L in spec["layers"] if L.get("stream")]

    def step(self, t, dt, rng, parts, meteors):
        tl = t - self.t0
        while self.events and self.events[0][0] <= tl + 1e-9:
            _, n, L = self.events.pop(0)
            for _ in range(n):
                if L.get("type") == "meteor":
                    m = V.spawn_meteor(L, self.o, rng, self.k, np.eye(3))
                    meteors.append((m, self.k))
                else:
                    parts.append(V.spawn(L, self.o, rng, self.k, np.eye(3)))
        for st in self.streams:
            L = st[0]
            rate = 0.0
            for (a0, a1, r0, r1) in L["stream"]:
                if a0 <= tl <= a1:
                    rate += r0 + (r1 - r0) * (tl - a0) / max(a1 - a0, 1e-6)
            st[1] += rate * dt
            while st[1] >= 1.0:
                st[1] -= 1.0
                parts.append(V.spawn(L, self.o, rng, self.k, np.eye(3)))


def update_meteors(meteors, parts, dt, rng, ground_y):
    for m, k in meteors:
        if m.dead:
            continue
        if not m.landed:
            for i, TL in enumerate(m.L.get("trails", [])):
                m.acc[i] += TL["rate"] * dt
                while m.acc[i] >= 1.0:
                    m.acc[i] -= 1.0
                    p = V.spawn(TL, m.pos, rng, k, np.eye(3))
                    if TL.get("locked"):
                        p.lock, p.lofs = m, p.pos - m.pos
                    parts.append(p)
            if (m.pos[1] <= ground_y + 0.3 and m.vel[1] < 0) or m.age >= m.life:
                m.landed = True
                if m.pos[1] <= ground_y + 0.6:
                    lp = np.array([m.pos[0], ground_y + 0.4, m.pos[2]])
                    for LL in m.L.get("land", []):
                        for _ in range(LL["emit"][0][1] if LL.get("emit") else 2):
                            parts.append(V.spawn(LL, lp, rng, k, np.eye(3)))
                m.dead = True
        acc = np.asarray(m.L.get("accel", (0, -100, 0)), float) * k
        m.vel = m.vel * (2.0 ** (-m.L.get("drag", 0.0) * dt)) + acc * dt
        m.pos = m.pos + m.vel * dt
        m.rot += m.rots * dt
        m.age += dt


# ----------------------------------------------------------------------------- la escena
def render_cataclysm(spec, impact_spec, tex_folder, out_dir, cam, victims, duration=None, seed=7, center=(0, 0, 0),
                     background=None, bloom=None, only_frames=None, caster=None, info=None, radius=None):
    """victims = [{"start": (x, y, z) pivote, "height": alto, "boxes": [(centro relativo al pivote, tamaño, color)]}].
    caster = cajas de Omnívora en el epicentro (solo para verla). info: lista donde se anota (t, fase) por cuadro."""
    rng = random.Random(seed)
    tb = V.TexBank(tex_folder)
    Cf = spec["cataclysm"]
    T, Fd, Hh, Rk = Cf["t"], Cf["field"], Cf["hole"], Cf["rocks"]
    R = radius or Cf["radius"]
    k = R / Cf["radius"]
    Hs = Cf["height"] * k
    C = np.asarray(center, float)
    B = C + np.array([0.0, Hs, 0.0])
    gy = C[1]
    duration = duration or T["end"]
    nframes = int(round(duration * FPS))
    os.makedirs(out_dir, exist_ok=True)
    bg = background if background is not None else V.make_background(cam, gy)
    roles = {}
    for L in spec["layers"]:
        roles.setdefault(L["role"], []).append(L)
    by_name = {L["name"]: L for L in spec["layers"]}
    parts, meteors, subs = [], [], []
    LO, Cu, Bd, St, Vc, Dc = Cf["loops"], Cf["currents"], Cf["bands"], Cf["streams"], Cf["victims"], Cf["det"]

    def front_r(t):
        return R * ease_out((t - T["front"][0]) / (T["front"][1] - T["front"][0]))

    def burst(name, pos, n, sk=1.0):
        L = by_name[name]
        for _ in range(n):
            parts.append(V.spawn(L, pos, rng, k * sk, np.eye(3)))

    def decal(name, pos, sk):
        L = by_name[name]
        parts.append(V.spawn(L, np.asarray(pos, float) + np.array([0, 0.3 * k, 0]), rng, k * sk, np.eye(3)))

    # portadores
    front = []
    for i in range(Cf["front_n"]):
        c = Carrier(roles.get("front", []), i + 1)
        c.ang = 2 * math.pi * i / Cf["front_n"] + rng.uniform(-0.1, 0.1)
        front.append(c)
    storm = []
    idx = 0
    for ring in Cf["rings"]:
        r, n, band, hgt = ring[0] * R, ring[1], ring[2], ring[3] * Hs
        for i in range(n):
            idx += 1
            c = Carrier(roles.get("storm", []), idx)
            th = 2 * math.pi * i / n + rng.uniform(-0.25, 0.25)
            c.o = new_tracer(rng, r, th, band * Hs * 0.3, band)
            c.size0 = np.array([min(R * 0.15, 2000), min(hgt, 2000), min(2 * math.pi * r / n * 0.85, 2000)])
            c.size = c.size0.copy()
            c.r0 = r
            storm.append(c)
    UD, ED = Cf["updrafts"], Cf["eddies"]
    updrafts = []
    for i in range(UD["n"]):
        c = Carrier(roles.get("updraft", []), i + 1)
        c.o = new_tracer(rng, rng.uniform(*UD["r"]) * R, rng.uniform(0, 2 * math.pi), 0.0, rng.uniform(*UD["band"]))
        c.size = np.array([120, 40, 120]) * k
        updrafts.append(c)
    eddies = []
    for i in range(ED["n"]):
        c = Carrier(roles.get("eddy", []), i + 1)
        c.o = new_tracer(rng, rng.uniform(*ED["r"]) * R, rng.uniform(0, 2 * math.pi), 0.0, rng.uniform(*ED["band"]))
        c.size = np.array(ED["box"], float) * k
        c.spin = math.radians(rng.uniform(*ED["spin"]))
        c.t0, c.t1 = ED["life"][i % len(ED["life"])]
        eddies.append(c)
    lenses = []
    for i in range(3):
        o = new_tracer(rng, rng.uniform(0.15, 0.5) * R, rng.uniform(0, 6.28), 0.0, rng.uniform(0.12, 0.3))
        lenses.append([o, rng.uniform(140, 260) * k, (i + 1) * 2.1])
    currents = []
    for c in range(Cu["n"]):
        frac = c / max(Cu["n"] - 1, 1)
        currents.append({"Bs": Cu["beams"][c % len(Cu["beams"])],
                         "rc": R * (Cu["r"][0] + (Cu["r"][1] - Cu["r"][0]) * ((frac * 7.31) % 1)),
                         "th": 2 * math.pi * c / Cu["n"] + rng.uniform(-0.2, 0.2), "wind": rng.uniform(*Cu["wind"]),
                         "w": rng.uniform(*Cu["w"]), "inward": rng.uniform(0.8, 1.2), "seed": rng.uniform(0, 1000)})
    arms = []
    for a in range(Bd["n"]):
        th0 = 2 * math.pi * a / Bd["n"] + rng.uniform(-0.2, 0.2)
        w = rng.uniform(0.95, 1.05)
        pts = []
        for j in range(Bd["points"]):
            u = j / (Bd["points"] - 1)
            band = Bd["band"][0] + (Bd["band"][1] - Bd["band"][0]) * u
            o = new_tracer(rng, R * (Bd["r"][0] + (Bd["r"][1] - Bd["r"][0]) * u), th0 + Bd["spiral"] * u,
                           band * Hs * 0.4, band)
            o.w, o.rise, o.inward = w, 0.6, 1.0
            pts.append(o)
        arms.append({"Bs": Bd["beams"][a % len(Bd["beams"])], "pts": pts})
    streams = []
    for s in range(St["n"]):
        o = new_tracer(rng, rng.uniform(*St["r"]) * R, 2 * math.pi * s / St["n"], 0.0, rng.uniform(*St["band"]))
        o.y = o.band * Hs
        streams.append({"Bs": St["beams"][s % len(St["beams"])], "o": o})

    # víctimas (el mismo recorrido que cataVictimCFrame)
    vics = []
    nv = len(victims)
    for i, vd in enumerate(victims):
        start = np.asarray(vd["start"], float)
        rel = np.array([start[0] - C[0], 0.0, start[2] - C[2]])
        dist = min(float(np.linalg.norm(rel)), Vc["land_max"] * Hs)
        dirv = rel / np.linalg.norm(rel) if np.linalg.norm(rel) > 1e-3 else np.array([1.0, 0, 0])
        land = C + dirv * dist
        land[1] = gy
        idx1 = i + 1
        l0 = T["victims"][0] + Vc["stagger"] * i
        tl = T["det"] + Vc["fall_stagger"] * i
        car = Carrier(roles.get("victim", []) + roles.get("trail", []), idx1)
        vics.append({"vd": vd, "index": idx1, "start": start, "land": land, "height": vd["height"],
                     "phi": math.atan2(rel[2], rel[0]) + math.pi * i / max(nv, 1), "l0": l0, "tl": tl,
                     "ti": tl + Vc["fall"], "r0": float(np.linalg.norm(rel)), "th0": math.atan2(rel[2], rel[0]),
                     "axis": np.array([math.sin(idx1 * 1.7), 0.6, math.cos(idx1 * 2.3)]) /
                     np.linalg.norm([math.sin(idx1 * 1.7), 0.6, math.cos(idx1 * 2.3)]),
                     "car": car, "lifted": False, "launched": False, "impacted": False})
    vk_of = {id(v): k * min(max(v["height"] / (Vc["ref"] * k), 0.6), 2.2) for v in vics}

    def rb_at(tt):
        return cata_field(Cf, min(tt, T["det"] - 1e-3))[3] * Hh["rb"][1] * k

    def hold_pos(v, tt):
        rb = rb_at(tt)
        ang = v["phi"] + Vc["hold_spin"] * (tt - v["l0"])
        rr = Vc["hold_r"] * rb + v["height"] * 0.6
        return B + np.array([math.cos(ang) * rr, -Vc["hold_drop"] * rb + math.sin(tt * 1.7 + v["index"]) * 6 * k,
                             math.sin(ang) * rr])

    def victim_cf(v, tt):
        start = v["start"]
        if tt < v["l0"]:
            a = smooth01(v["l0"] - Vc["tremble"], v["l0"], tt) * v["height"] * 0.02
            return start + np.array([noise1(v["index"] + 0.5, tt * 23) * a, 0, noise1(v["index"] + 5.5, tt * 23) * a]), np.eye(3)
        lift_end = T["victims"][1]
        if tt < lift_end:
            u = smooth01(v["l0"], lift_end, tt)
            Hp = hold_pos(v, tt)
            rel = Hp - C
            rH = math.hypot(rel[0], rel[2])
            thH = math.atan2(rel[2], rel[0])
            target = v["th0"] + Vc["turns"] * 2 * math.pi
            dth = (thH - target + math.pi) % (2 * math.pi) - math.pi
            th = v["th0"] + (Vc["turns"] * 2 * math.pi + dth) * u
            rr = v["r0"] + (rH - v["r0"]) * u ** 0.9
            yy = start[1] + (Hp[1] - start[1]) * (u * u * (3 - 2 * u))
            return np.array([C[0] + math.cos(th) * rr, yy, C[2] + math.sin(th) * rr]), axis_angle(v["axis"], u * 2.2)
        if tt < v["tl"]:
            return hold_pos(v, tt), axis_angle(v["axis"], 2.2 + (tt - lift_end) * 0.8)
        if tt < v["ti"]:
            s = (tt - v["tl"]) / (v["ti"] - v["tl"])
            fr = hold_pos(v, v["tl"])
            to = v["land"] + np.array([0, v["height"] * 0.35, 0])
            return fr + (to - fr) * (s * s), axis_angle(v["axis"], 2.2 + (v["tl"] - lift_end) * 0.8 + s * 2)
        return v["land"] + np.array([0, v["height"] * 0.3, 0]), axis_angle(v["axis"], 0.5)

    # rocas
    rocks = []
    counts = {"medium": 0, "chunk": 0, "frag": 0, "rain": 0}
    spawn_acc = {"medium": 0.0, "chunk": 0.0}
    ground_col = (112, 108, 116)

    def spawn_rock(kind, t):
        P = Rk[kind]
        rf = min(front_r(t), R)
        rmin = Rk["r_min"] * R
        if rf <= rmin * 1.3:
            return
        r = math.sqrt(rng.uniform((rmin / R) ** 2, (rf / R) ** 2)) * R
        th = rng.uniform(0, 2 * math.pi)
        gp = C + np.array([math.cos(th) * r, 0.0, math.sin(th) * r])
        col = ground_col
        if rng.random() < P["dark"]:
            col = (66, 68, 80)
        col = tuple(min(255, max(0, int(c * rng.uniform(0.85, 1.12)))) for c in col)
        s = skewed(rng, P["size"][0], P["size"][1], P["skew"]) * k
        size = np.array([s * rng.uniform(0.75, 1.25), s * rng.uniform(*P["aspect"]), s * rng.uniform(0.75, 1.25)])
        o = Tracer()
        o.r, o.th, o.y = r, th, -size[1] * 0.35
        o.w, o.band, o.rise, o.inward = rng.uniform(*P["w"]), rng.uniform(*P["band"]), rng.uniform(*P["rise"]), rng.uniform(*P["inward"])
        o.vy, o.seed = 0.0, rng.uniform(0, 1000)
        shoot = rng.random() < P["shoot"]
        rk = Rock()
        rk.o, rk.size, rk.s0, rk.kind, rk.state = o, size, size.copy(), kind, "embed"
        rk.t1 = t + (rng.uniform(0.08, 0.2) if shoot else rng.uniform(*P["tremble"]))
        if kind == "chunk":
            rk.Rm = V.axis_angle(np.array([1.0, 0, 0]), rng.uniform(-0.15, 0.15)) @ rot_y(rng.uniform(0, 6.28))
        else:
            rk.Rm = V.axis_angle(np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)]) + 1e-6, rng.uniform(0, 6.28))
        ax = np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)])
        rk.axis = ax / max(np.linalg.norm(ax), 1e-6)
        rk.spin = rng.uniform(0.2, 0.6) if kind == "chunk" else rng.uniform(0.8, 3.0)
        rk.pos = gp.copy()
        rk.break_at = rng.uniform(*P["break_t"]) if rng.random() < P["break_p"] else None
        rk.die_at, rk.die_t, rk.die_dur, rk.consume = None, 0.0, 0.45, False
        rk.vel = np.zeros(3)
        rk.base = gp + np.array([0, -size[1] * 0.35, 0])
        rk.color = col
        rk.scale = 1.0
        if shoot:
            o.vy = rng.uniform(300, 500) * k
        rocks.append(rk)
        counts[kind] += 1
        if kind == "chunk":
            decal("GroundCrack", gp, size[0] / (80 * k))
            decal("GroundVoid", gp, size[0] / (90 * k))
            burst("BurstDust", gp + np.array([0, 10 * k, 0]), 8, size[0] / (60 * k))
            burst("BurstDebris", gp, 10)
        elif rng.random() < 0.3:
            burst("BurstDust", gp, 2, 0.5)

    def new_frag(parent, t, kind="frag"):
        Fg = Rk["frag"]
        sz = np.array([parent.size[0] * rng.uniform(*Fg["k"]), min(parent.size[1] * rng.uniform(*Fg["k"]) * 1.5, parent.size[1]),
                       parent.size[2] * rng.uniform(*Fg["k"])])
        po = parent.o
        o = Tracer()
        o.r = max(po.r + rng.uniform(-0.5, 0.5) * parent.size[0], 0.0)
        o.th = po.th + rng.uniform(-0.5, 0.5) * parent.size[0] / max(po.r, 1.0)
        o.y = po.y + rng.uniform(-0.5, 0.5) * parent.size[1]
        o.w, o.band = po.w * rng.uniform(0.85, 1.25), po.band * rng.uniform(0.9, 1.4)
        o.rise, o.inward = po.rise * rng.uniform(1, 1.5), po.inward * rng.uniform(0.9, 1.3)
        o.vy, o.seed = rng.uniform(-40, 120) * k, rng.uniform(0, 1000)
        rk = Rock()
        rk.o, rk.size, rk.s0, rk.kind, rk.state, rk.t1 = o, sz, sz.copy(), kind, "fly", t
        rk.Rm = parent.Rm @ V.axis_angle(np.array([0.3, 1.0, 0.2]), rng.uniform(0, 3))
        ax = np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)])
        rk.axis = ax / max(np.linalg.norm(ax), 1e-6)
        rk.spin = rng.uniform(1.5, 4.0)
        rk.pos = parent.pos.copy()
        rk.break_at, rk.die_at, rk.die_t, rk.die_dur, rk.consume = None, t + rng.uniform(*Fg["life"]), 0.0, 0.5, False
        rk.vel, rk.base, rk.color, rk.scale = np.zeros(3), parent.pos.copy(), parent.color, 1.0
        rocks.append(rk)
        counts["frag"] += 1

    def fragment(rk, t):
        n = rng.randint(Rk["frag"]["n"][0], Rk["frag"]["n"][1])
        if counts["frag"] > 80:
            n = 1
        for _ in range(n):
            new_frag(rk, t)
        sk = float(np.linalg.norm(rk.size)) / (40 * k)
        burst("BurstDust", rk.pos, 4 + int(sk * 4), min(max(sk, 0.4), 2))
        burst("BurstSparks", rk.pos, 10, min(max(sk, 0.5), 2))
        burst("BurstDebris", rk.pos, 8)
        if rk.kind == "chunk":
            burst("BurstFlash", rk.pos, 1, min(max(sk, 0.6), 1.5))
        counts[rk.kind] -= 1

    def kill(rk, t, consume, dur):
        rk.state, rk.die_t, rk.die_dur, rk.consume = "die", t, dur, consume

    rain = Rk["rain"]
    rain_times = [rain["t"][0] + (rain["t"][1] - rain["t"][0]) * i / max(rain["n"] - 1, 1) for i in range(rain["n"])]
    rain_next = 0

    def spawn_rain():
        r = rng.uniform(*rain["r"]) * R
        th = rng.uniform(0, 2 * math.pi)
        s = rng.uniform(*rain["size"]) * k
        rk = Rock()
        rk.size = np.array([s * rng.uniform(0.7, 1.3), s * rng.uniform(0.6, 1), s * rng.uniform(0.7, 1.3)])
        rk.s0 = rk.size.copy()
        rk.pos = C + np.array([math.cos(th) * r, rng.uniform(*rain["height"]) * k, math.sin(th) * r])
        o = Tracer()
        o.r, o.th, o.y, o.w, o.band, o.rise, o.inward, o.vy, o.seed = r, th, rk.pos[1], 1, 0, 0, 0, 0, rng.uniform(0, 1000)
        rk.o, rk.kind, rk.state, rk.t1 = o, "rain", "fall", 0.0
        rk.Rm = V.axis_angle(np.array([1.0, 0.2, 0.0]), rng.uniform(0, 6))
        ax = np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)])
        rk.axis = ax / max(np.linalg.norm(ax), 1e-6)
        rk.spin = rng.uniform(1, 4)
        rk.break_at, rk.die_at, rk.die_t, rk.die_dur, rk.consume = None, None, 0.0, 0.3, False
        rk.vel = np.array([rng.uniform(-20, 20), -rng.uniform(0, 60), rng.uniform(-20, 20)]) * k
        rk.base, rk.color, rk.scale = rk.pos.copy(), (96, 98, 110), 1.0
        rocks.append(rk)
        counts["rain"] += 1

    # la singularidad, la detonación y lo que queda después
    hole = None
    hole_cars = []
    det = None
    det_cars = []
    after_cars = []
    pulse_phase = 0.0
    next_crack = Cf["cracks"][0]
    phase_i = -1
    next_collide = 0.0
    dt = 1.0 / FPS
    stats = []
    det_layers = roles.get("det", [])

    for fi in range(nframes):
        t = fi * dt
        while phase_i + 1 < len(Cf["phases"]) and t >= Cf["phases"][phase_i + 1][1]:
            phase_i += 1
        L_, S_, A_, rbk = cata_field(Cf, t)
        rb = rbk * Hh["rb"][1] * k
        items = []

        # ---------------- el despertar
        rf = front_r(t)
        for c in front:
            if not c.on:
                continue
            if t > T["front"][1] + 4.5:
                c.on = False
                continue
            c.pos = C + np.array([math.cos(c.ang) * rf, 30 * k, math.sin(c.ang) * rf])
            c.Rm = look_rot([-math.sin(c.ang), 0, math.cos(c.ang)])
            c.size = np.array([160 * k, 60 * k, min(max(2 * math.pi * rf / Cf["front_n"] * 0.8, 40 * k), 2000)])
            run_emitters(c, t, dt, 1.0, rng, k, parts)
        while t >= next_crack and next_crack <= Cf["cracks"][1]:
            next_crack += Cf["cracks"][2]
            cr = math.sqrt(rng.uniform((Rk["r_min"] * R / max(rf, 1)) ** 2, 1)) * rf
            ca = rng.uniform(0, 2 * math.pi)
            decal("GroundCrack", C + np.array([math.cos(ca) * cr, 0, math.sin(ca) * cr]), rng.uniform(0.6, 1.3))
        ftr = 1 - (1 - LO["front"]["transparency"]) * (1 - smooth01(T["front"][1] - 0.4, T["front"][1] + 0.5, t))
        if ftr < 0.995:
            pts = loop_points(C, max(rf, 1), 18 * k, LO["points"])
            chain_items(LO["front"], k, pts, [LO["front"]["width"] * k] * len(pts), [ftr] * len(pts), True, items, cam)
        for ri, ts in enumerate(LO["ripples"]):
            u = (t - ts) / LO["ripple_time"]
            if 0 <= u <= 1:
                Bs = LO["ripple_purple"] if ri % 3 == 1 else LO["ripple"]
                pts = loop_points(C, R * (0.05 + 0.95 * ease_out(u)), 12 * k, LO["points"])
                w = Bs["width"] * k * (1 - 0.4 * u)
                tr = 1 - (1 - Bs["transparency"]) * (1 - u) ** 0.7
                chain_items(Bs, k, pts, [w] * len(pts), [tr] * len(pts), True, items, cam)

        # ---------------- la tormenta
        for c in storm:
            if not c.on:
                continue
            step_tracer(c.o, dt, Fd, R, Hs, k, L_, S_, A_)
            pos = tracer_pos(c.o, C, Fd, R, Hs, t)
            if (rb > 1 and A_ > 0.25 and np.linalg.norm(pos - B) < rb * Fd["capture"] * 1.5) or t >= T["det"]:
                c.on = False
                continue
            shrink = min(max((c.o.r / c.r0) ** 0.8, 0.15), 1.0)
            c.size = np.array([c.size0[0] * shrink, c.size0[1], c.size0[2] * shrink])
            c.pos, c.Rm = pos, look_rot([-math.sin(c.o.th), 0, math.cos(c.o.th)])
            run_emitters(c, t, dt, 1.0, rng, k, parts)
        for c in updrafts:
            if not c.on:
                continue
            step_tracer(c.o, dt, Fd, R, Hs, k, L_, S_, A_)
            pos = tracer_pos(c.o, C, Fd, R, Hs, t)
            if (rb > 1 and A_ > 0.25 and np.linalg.norm(pos - B) < rb * Fd["capture"] * 2) or t >= T["det"]:
                c.on = False
                continue
            up = pos + np.array([0, 1000 * k, 0])
            aim = up + (B - up) * min(max(A_ * 1.3, 0), 1)
            c.pos, c.Rm = pos, look_rot(aim - pos)
            run_emitters(c, t, dt, 1.0, rng, k, parts)
        for c in eddies:
            if not c.on:
                continue
            step_tracer(c.o, dt, Fd, R, Hs, k, L_, S_, A_)
            pos = tracer_pos(c.o, C, Fd, R, Hs, t)
            if t > c.t1 + 2.5 or (rb > 1 and A_ > 0.25 and np.linalg.norm(pos - B) < rb * Fd["capture"] * 1.5):
                c.on = False
                continue
            c.ang += c.spin * dt
            c.pos, c.Rm = pos, rot_y(-c.ang)
            gate = smooth01(c.t0, c.t0 + 0.8, t) * (1 - smooth01(c.t1 - 0.8, c.t1, t))
            run_emitters(c, t, dt, gate, rng, k, parts)
        for ls in lenses:
            step_tracer(ls[0], dt, Fd, R, Hs, k, L_, S_, A_)
            vis = smooth01(0.6, 2.0, t) * (1 - smooth01(9.0, 10.5, t))
            if vis > 0.01:
                pos = tracer_pos(ls[0], C, Fd, R, Hs, t)
                size = ls[1] * (0.75 + 0.25 * math.sin(t * 2.3 + ls[2]))
                z = cam.to_cam(pos)[2]
                if z > 1:
                    items.append((z, 2, (pos, size * 0.5, 0.18 * vis)))

        # ---------------- cadenas de Beams
        np_ = Cu["points"]
        for cur in currents:
            omega = Fd["omega0"] * cur["w"] * (R / (cur["rc"] + Fd["r_core"] * R)) ** Fd["omega_pow"] * S_
            cur["th"] += omega * dt
            if A_ > 0:
                cur["rc"] = max(cur["rc"] - A_ * Fd["c_in"] * cur["inward"] * (cur["rc"] + 0.06 * R) * dt, 0.0)
            alpha = smooth01(Cu["fade"][0], Cu["fade"][1], t) * min(max(cur["rc"] / (0.12 * R), 0), 1)
            if t >= T["det"] or alpha <= 0.01:
                continue
            Bs = cur["Bs"]
            bend = min(max(A_ * Cu["bend"], 0), 1)
            pts, ws, trs = [], [], []
            for j in range(np_):
                u = j / (np_ - 1)
                rr = cur["rc"] * (1 - 0.3 * u)
                th = cur["th"] + cur["wind"] * u + 0.15 * noise1(cur["seed"], t * 0.4 + u * 2)
                yy = u * Cu["top"] * Hs
                b = bend * u ** 1.2
                rr *= 1 - b
                yy += (Hs - yy) * b
                pts.append(C + np.array([math.cos(th) * rr, yy, math.sin(th) * rr]))
                ws.append(Bs["width"] * k * (1 - Cu["taper"] * u) * (0.85 + 0.3 * noise1(cur["seed"] + 3, t * 0.8 + u)))
                end_fade = min(max(min(u / 0.12, (1 - u) / 0.12), 0), 1)
                trs.append(1 - (1 - Bs["transparency"]) * alpha * end_fade)
            chain_items(Bs, k, pts, ws, trs, False, items, cam)
        na = Bd["points"]
        for arm in arms:
            Bs = arm["Bs"]
            pts, ws, trs = [], [], []
            for j, o in enumerate(arm["pts"]):
                step_tracer(o, dt, Fd, R, Hs, k, L_, S_, A_)
                u = j / (na - 1)
                pts.append(tracer_pos(o, C, Fd, R, Hs, t))
                ws.append(Bs["width"] * k * (0.55 + 0.45 * math.sin(math.pi * u)))
                alpha = 0.0 if t >= T["det"] else smooth01(Bd["fade"][0], Bd["fade"][1], t) * min(max(o.r / (0.1 * R), 0), 1)
                end_fade = min(max(min(u / 0.15, (1 - u) / 0.15), 0), 1)
                trs.append(1 - (1 - Bs["transparency"]) * alpha * end_fade)
            chain_items(Bs, k, pts, ws, trs, False, items, cam)
        ns = St["points"]
        for stm in streams:
            o = stm["o"]
            step_tracer(o, dt, Fd, R, Hs, k, L_, S_, A_)
            alpha = smooth01(St["fade"][0], St["fade"][1], t) * (1 - smooth01(13.6, 14.3, t)) * min(max(o.r / (0.08 * R), 0), 1)
            if t >= T["det"] or alpha <= 0.01 or rb < 1:
                continue
            Bs = stm["Bs"]
            base = tracer_pos(o, C, Fd, R, Hs, t)
            pts, ws, trs = [], [], []
            for j in range(ns):
                u = j / (ns - 1)
                rr = o.r * (1 - u) ** 1.3
                th = o.th + St["turns"] * 2 * math.pi * u
                yy = (base[1] - C[1]) + (Hs - (base[1] - C[1])) * u ** 0.8
                pts.append(B.copy() if j == ns - 1 else C + np.array([math.cos(th) * rr, yy, math.sin(th) * rr]))
                ws.append(Bs["width"] * k * (1 - 0.75 * u))
                trs.append(1 - (1 - Bs["transparency"]) * alpha * min(max(u / 0.1, 0), 1))
            chain_items(Bs, k, pts, ws, trs, False, items, cam)

        # ---------------- rocas
        if t < T["det"]:
            for kind in ("medium", "chunk"):
                P = Rk[kind]
                rate = 0.0
                for w in P["rate"]:
                    if w[0] <= t <= w[1]:
                        rate += w[2] + (w[3] - w[2]) * (t - w[0]) / max(w[1] - w[0], 1e-3)
                spawn_acc[kind] += rate * dt
                while spawn_acc[kind] >= 1:
                    spawn_acc[kind] -= 1
                    if counts[kind] < P["max"]:
                        spawn_rock(kind, t)
        while rain_next < len(rain_times) and t >= rain_times[rain_next]:
            rain_next += 1
            spawn_rain()
        if t >= next_collide and t < T["det"]:
            next_collide = t + Rk["collide"]["every"]
            big = [r_ for r_ in rocks if r_.state == "fly" and max(r_.size[0], r_.size[2]) >= Rk["collide"]["min_size"] * k]
            hit = None
            for a in range(len(big)):
                for b in range(a + 1, len(big)):
                    if np.linalg.norm(big[a].pos - big[b].pos) < (np.linalg.norm(big[a].size) + np.linalg.norm(big[b].size)) * 0.35:
                        hit = (big[a], big[b])
                        break
                if hit:
                    break
            if hit:
                burst("BurstFlash", (hit[0].pos + hit[1].pos) / 2, 1)
                for r_ in hit:
                    if r_ in rocks:
                        fragment(r_, t)
                        rocks.remove(r_)
        keep = []
        for rk in rocks:
            o = rk.o
            pos = rk.pos
            removed = False
            if rk.state == "embed":
                a = float(np.linalg.norm(rk.size)) * 0.03
                pos = rk.base + np.array([noise1(o.seed, t * 25) * a, noise1(o.seed + 3, t * 25) * a * 0.5, noise1(o.seed + 6, t * 25) * a])
                if t >= rk.t1:
                    rk.state = "fly"
                    if rk.kind == "chunk":
                        burst("BurstDust", rk.base, 4, rk.size[0] / (70 * k))
            elif rk.state == "fly":
                if t >= T["det"]:
                    out = pos - B
                    nrm = np.linalg.norm(out)
                    rk.vel = (out / nrm if nrm > 1e-3 else np.array([0, 1.0, 0])) * rng.uniform(250, 600) * k
                    rk.state = "fall"
                else:
                    # al final del consumo la atracción se lleva lo que siga flotando
                    sweep = smooth01(T["attract"][2], T["attract"][2] + Rk["sweep"][0], t)
                    if sweep > 0:
                        o.inward = max(o.inward, Rk["sweep"][1] * sweep)
                    step_tracer(o, dt, Fd, R, Hs, k, L_, S_, A_)
                    pos = tracer_pos(o, C, Fd, R, Hs, t)
                    if (rb > 1 and A_ > 0.2 and np.linalg.norm(pos - B) < rb * Fd["capture"]) or t >= T["crit"][0]:
                        kill(rk, t, True, 0.25)
                        burst("ConsumeFlash", pos, 1, min(max(float(np.linalg.norm(rk.size)) / (30 * k), 0.4), 1.6))
                    elif rk.break_at is not None and t >= rk.break_at:
                        rk.pos = pos
                        fragment(rk, t)
                        removed = True
                    elif rk.die_at is not None and t >= rk.die_at:
                        kill(rk, t, False, 0.5)
                        burst("BurstSparks", pos, 3, 0.5)
            elif rk.state == "die":
                u = (t - rk.die_t) / rk.die_dur
                if u >= 1:
                    counts[rk.kind] -= 1
                    removed = True
                else:
                    if rk.consume:
                        pos = pos + (B - pos) * min(1.0, dt * 8)
                    rk.size = rk.s0 * max(1 - u, 0.05)
            elif rk.state == "fall":
                rk.vel = (rk.vel + np.array([0, -230 * k, 0]) * dt) * math.exp(-0.4 * dt)
                pos = pos + rk.vel * dt
                if pos[1] <= gy + rk.size[1] * 0.3:
                    pos = np.array([pos[0], gy + rk.size[1] * 0.3, pos[2]])
                    burst("BurstDust", pos, 2, min(max(float(np.linalg.norm(rk.size)) / (25 * k), 0.3), 1.2))
                    kill(rk, t, False, 0.3)
            if not removed:
                if rk.state != "embed":
                    rk.Rm = rk.Rm @ V.axis_angle(rk.axis, rk.spin * dt)
                rk.pos = pos
                keep.append(rk)
                z = cam.to_cam(pos)[2]
                if z > 1:
                    items.append((z, 1, rk))
        rocks = keep

        # ---------------- la singularidad
        if hole is None and T["sing"][0] <= t < T["det"]:
            cp = cam.C
            d = np.array([cp[0] - B[0], 0.0, cp[2] - B[2]])
            tilt = np.eye(3)
            if np.linalg.norm(d) > 1e-3:
                tilt = V.axis_angle(np.cross([0, 1.0, 0], d / np.linalg.norm(d)), math.radians(Hh["tilt"]))
            hole = {"tilt": tilt}
            burst("BurstFlash", B, 2, 3)
            burst("ConsumeFlash", B, 2, 3)
            burst("BurstSparks", B, 30, 2)
            for role in ("hole", "crit"):
                for L in roles.get(role, []):
                    hole_cars.append([L, 0.0])
        if hole is not None and t < T["det"]:
            birth = smooth01(T["sing"][0], T["sing"][0] + 0.8, t)
            crit = smooth01(T["crit"][0], T["crit"][1], t)
            pulse_phase += 2 * math.pi * (Hh["pulse_hz"][0] + (Hh["pulse_hz"][1] - Hh["pulse_hz"][0]) * crit) * dt
            pulse = 0.5 + 0.5 * math.sin(pulse_phase)
            gk = 1.8 + 1.7 * crit * (0.6 + 0.4 * pulse)
            zB = cam.to_cam(B)[2]
            hole["now"] = dict(rb=rb, birth=birth, crit=crit, pulse=pulse, gk=gk, S=S_, t=t)
            if zB > 1:
                away = B - cam.C
                lens_pos = B + away / np.linalg.norm(away) * rb * 0.9
                items.append((zB + rb * 0.9, 2, (lens_pos, Hh["lens"] * rb * 0.5 * (1 + 0.08 * crit * pulse), 0.42 * birth)))
                items.append((zB, 6, None))
            for hc in hole_cars:
                L = hc[0]
                env = curve(L["env"], t) if L.get("env") else 1.0
                hc[1] += L.get("rate", 0) * env * birth * dt
                shell = L.get("shell", 1.0) * rb
                while hc[1] >= 1.0:
                    hc[1] -= 1.0
                    u = np.array([rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)])
                    u /= max(np.linalg.norm(u), 1e-9)
                    p = V.spawn(L, B + u * shell, rng, k, np.eye(3))
                    if L.get("outward"):
                        p.vel = u * rng.uniform(*L.get("speed", (0, 0))) * k
                    else:
                        p.vel = -u * shell / max(p.life, 1e-3)
                    parts.append(p)

        # ---------------- las víctimas
        for v in vics:
            vp, vR = victim_cf(v, t)
            v["now"] = (vp, vR)
            car = v["car"]
            car.pos, car.Rm = vp, np.eye(3)
            car.size = np.array([v["height"] * 0.8, v["height"], v["height"] * 0.8])
            if not v["lifted"] and t >= v["l0"]:
                v["lifted"] = True
                gp = np.array([v["start"][0], gy, v["start"][2]])
                burst("BurstDust", gp + np.array([0, 8 * k, 0]), 10, v["height"] / (40 * k))
                burst("BurstDebris", gp, 16)
                burst("BurstFlash", gp + np.array([0, v["height"] * 0.5, 0]), 1)
                decal("GroundCrack", gp, v["height"] / (50 * k))
                decal("GroundVoid", gp, v["height"] / (60 * k))
            if not v["impacted"] and t >= v["ti"]:
                v["impacted"] = True
                subs.append(SubSpec(impact_spec, v["land"], t, vk_of[id(v)]))
            vk = vk_of[id(v)]
            for em in car.ems:
                L = em[0]
                on = (v["l0"] <= t < v["tl"]) if L["role"] == "victim" else (v["tl"] <= t < v["ti"])
                if on:
                    em[1] += L.get("rate", 0) * dt
                    while em[1] >= 1.0:
                        em[1] -= 1.0
                        emit_box(car, L, rng, vk, parts)
            ton = smooth01(v["l0"] + 0.3, v["l0"] + 1.0, t) * (1 - smooth01(v["tl"] - 0.15, v["tl"], t))
            if ton > 0.01 and rb > 1:
                Bs = Vc["tether"]
                tr = 1 - (1 - Bs["transparency"]) * ton * (0.7 + 0.3 * math.sin(t * 9 + v["index"]))
                chain_items(Bs, k, [vp, B.copy()], [Bs["width"] * k, Bs["width"] * k * 0.4], [tr, tr], False, items, cam)
            for (rel, size, color) in v["vd"]["boxes"]:
                ctr = vp + vR @ np.asarray(rel, float)
                z = cam.to_cam(ctr)[2]
                if z > 1:
                    items.append((z, 3, (ctr, vR, size, color)))
        for (ctr, size, color) in (caster or []):
            z = cam.to_cam(np.asarray(ctr, float))[2]
            if z > 1:
                items.append((z, 3, (np.asarray(ctr, float), np.eye(3), size, color)))

        # ---------------- la detonación
        if det is None and t >= T["det"]:
            det = {"t": t}
            rb_max = Hh["rb"][1] * k
            for L in det_layers:
                for _ in range(L.get("n", 10)):
                    p = V.spawn(L, B, rng, k, np.eye(3))
                    if L.get("shape"):          # en el módulo salen de una esfera del tamaño del agujero
                        sp = np.linalg.norm(p.vel)
                        if sp > 1e-6:
                            p.pos = B + p.vel / sp * rb_max
                    parts.append(p)
            for i in range(Dc["wall_n"]):
                c = Carrier(roles.get("wall", []), i + 1)
                c.ang = 2 * math.pi * i / Dc["wall_n"]
                det_cars.append(c)
        if det is not None:
            td = t - T["det"]
            if td <= 3.0:
                rb_max = Hh["rb"][1] * k
                core = min(2 * rb_max * Dc["core"][1] * ease_out(td / Dc["core"][0]), 2048)
                det["core"] = (core / 2, 1 - smooth01(Dc["core"][2], Dc["core"][2] + Dc["core"][3], td))
                sh = min(300 * k + (Dc["shell"][1] - 300 * k) * ease_out(td / Dc["shell"][0]), 2048)
                det["shell"] = (sh / 2, 1 - (Dc["shell"][2] + (1 - Dc["shell"][2]) * smooth01(0, Dc["shell"][0], td) ** 0.7))
                td2 = td - Dc["shell2"][2]
                sh2 = min(200 * k + (Dc["shell2"][1] - 200 * k) * ease_out(td2 / Dc["shell2"][0]), 2048)
                det["shell2"] = (sh2 / 2, 0.0 if td2 < 0 else 1 - (Dc["shell2"][3] + (1 - Dc["shell2"][3]) * smooth01(0, Dc["shell2"][0], td2) ** 0.7))
                det["ring"] = (min(Dc["ring"][1] * ease_out(td / Dc["ring"][0]), 2048), smooth01(0, Dc["ring"][0], td))
                det["distort"] = (min(Dc["distort"][1] * ease_out(td / Dc["distort"][0]), 2048) / 2,
                                  1 - (Dc["distort"][2] + (1 - Dc["distort"][2]) * smooth01(0, Dc["distort"][0], td)))
                zB = cam.to_cam(B)[2]
                if zB > 1:
                    items.append((zB + det["distort"][0] * 0.5, 2, (B.copy(), det["distort"][0], 0.3 * det["distort"][1])))
                    items.append((zB, 8, None))
                us_ = min(max(td / Dc["sky"][0], 0), 1)
                if us_ < 1:
                    for ci, Bs in enumerate((LO["det_sky"], LO["det_sky_purple"])):
                        pts = loop_points(C, R * Dc["sky"][1] * ease_out(us_) * (1 if ci == 0 else 0.92), Hs, LO["points"])
                        chain_items(Bs, k, pts, [Bs["width"] * k * (1 - 0.5 * us_)] * len(pts),
                                    [1 - (1 - Bs["transparency"]) * (1 - us_) ** 0.8] * len(pts), True, items, cam)
                ug = min(max((td - Dc["ground"][0]) / Dc["ground"][1], 0), 1)
                ground_r = R * Dc["ground"][2] * ease_out(ug)
                if td >= Dc["ground"][0] and ug < 1:
                    for Bs in (LO["det_ground"], LO["det_ground_core"]):
                        pts = loop_points(C, max(ground_r, 1), 28 * k, LO["points"])
                        chain_items(Bs, k, pts, [Bs["width"] * k * (1 - 0.35 * ug)] * len(pts),
                                    [1 - (1 - Bs["transparency"]) * (1 - ug) ** 0.6] * len(pts), True, items, cam)
                for c in det_cars:
                    c.pos = C + np.array([math.cos(c.ang) * ground_r, 30 * k, math.sin(c.ang) * ground_r])
                    c.Rm = look_rot([-math.sin(c.ang), 0, math.cos(c.ang)])
                    c.size = np.array([120 * k, 60 * k, min(max(2 * math.pi * ground_r / Dc["wall_n"] * 0.8, 40 * k), 2000)])
                    run_emitters(c, t, dt, 1.0 if td >= Dc["ground"][0] else 0.0, rng, k, parts)
        if t >= T["det"] + 0.3 and not after_cars:
            AF = Cf["after"]
            for i in range(AF["n"]):
                r = rng.uniform(*AF["r"]) * R
                th = rng.uniform(0, 2 * math.pi)
                c = Carrier(roles.get("after", []), i + 1)
                c.pos = C + np.array([math.cos(th) * r, 40 * k, math.sin(th) * r])
                c.size = np.array([300, 80, 300]) * k
                after_cars.append(c)
        for c in after_cars:
            run_emitters(c, t, dt, 1.0, rng, k, parts)

        # ---------------- los impactos y lo que salió volando
        for sb in subs:
            sb.step(t, dt, rng, parts, meteors)
        update_meteors(meteors, parts, dt, rng, gy)
        parts = [p for p in parts if p.age < p.life]

        draw = only_frames is None or fi in only_frames
        if info is not None:
            info.append((t, Cf["phases"][max(phase_i, 0)][0]))
        if draw:
            buf = bg.copy()
            for p in parts:
                wp = p.pos
                d = cam.to_cam(wp)
                if d[2] > 0.5:
                    items.append((d[2] - p.L.get("zoffset", 0.0) * p.ks, 0, (p, d)))
            for m, mk in meteors:
                if not m.dead:
                    d = cam.to_cam(m.pos)
                    if d[2] > 0.5:
                        items.append((d[2], 10, m))
            items.sort(key=lambda x: -x[0])
            for _, kind, obj in items:
                if kind == 0:
                    p, d = obj
                    if isinstance(p.lock, Carrier):
                        vl = p.vel
                        p.vel = p.lock.Rm @ vl
                        V.draw_particle(buf, tb, cam, p, d, k, gy, 1.0)
                        p.vel = vl
                    else:
                        V.draw_particle(buf, tb, cam, p, d, k, gy, 1.0)
                elif kind == 1:
                    draw_obb(buf, cam, obj.pos, obj.Rm, obj.size, obj.color)
                elif kind == 2:
                    pos, rad, strength = obj
                    if strength > 0.01:
                        V.apply_lens(buf, cam, pos, rad, strength)
                elif kind == 3:
                    ctr, Rm, size, color = obj
                    draw_obb(buf, cam, ctr, Rm, size, color)
                elif kind == 4:
                    Bm, A0, A1 = obj
                    V.draw_beam(buf, tb, cam, Bm, A0, A1, 1.0, 0.0, t, 1.0)
                elif kind == 6:
                    draw_hole(buf, tb, cam, hole, Hh, B)
                elif kind == 8:
                    draw_detonation(buf, tb, cam, det, B, t)
                elif kind == 10:
                    m = obj
                    pr = cam.project(m.pos)
                    if pr is not None:
                        sp = m.L["sprite"]
                        px = cam.f * m.size / pr[2]
                        spr = tb.sprite(sp["texture"], sp.get("layout", "Grid2x2"), m.frame, px, px, m.rot)
                        spr[..., :3] *= np.array(sp.get("color", (255, 255, 255)), float) / 255
                        V.draw_sprite(buf, spr, pr[0], pr[1], 0.0, 1.0)
            if bloom:
                buf = V.apply_bloom(buf, **bloom)
            buf = color_correct(buf, Cf["cc"], t)
            buf = flash(buf, Cf["flash"], t)
            Image.fromarray((np.clip(buf, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, f"{fi:04d}.png"))
        stats.append(len(parts))
        # física de las partículas (las pegadas a un portador viajan con él)
        for p in parts:
            Lp = p.L
            acc = np.asarray(Lp.get("accel", (0, 0, 0)), float) * p.ks
            p.vel = p.vel * (2.0 ** (-Lp.get("drag", 0.0) * dt)) + acc * dt
            if isinstance(p.lock, Carrier):
                p.lofs = p.lofs + p.vel * dt
                p.pos = p.lock.pos + p.lock.Rm @ p.lofs
            elif p.lock is not None:
                p.lofs = p.lofs + p.vel * dt
                p.pos = p.lock.pos + p.lofs
            else:
                p.pos = p.pos + p.vel * dt
            p.rot += p.rots * dt
            p.age += dt
    return stats


def draw_hole(buf, tb, cam, hole, Hh, B):
    """El agujero negro: halo oscuro, discos, anillos de luz, el núcleo negro (el disco inclinado le pasa por delante)."""
    n = hole["now"]
    rb, birth, crit, pulse, gk, S, t = n["rb"], n["birth"], n["crit"], n["pulse"], n["gk"], n["S"], n["t"]
    draw_bill(buf, tb, cam, B, Hh["halo"] * rb, 0, "fx_glow", (10 / 255, 14 / 255, 40 / 255), 1 - 0.75 * birth)
    draw_bill(buf, tb, cam, B, Hh["wind"] * rb, math.radians(Hh["spin_wind"] * t), "fx_wind_swirl", (0.75, 0.3, 1.0),
              1 - 0.6 * birth)
    draw_bill(buf, tb, cam, B, Hh["swirl"] * rb, math.radians(Hh["spin_swirl"] * t * (0.6 + 0.4 * S)), "fx_swirl_rings",
              (0.55, 0.85, 1.1), 1 - 0.65 * birth)
    tilt = hole["tilt"]
    normal = tilt @ np.array([0, 1.0, 0])
    disks = [("fx_swirl_rings", Hh["disk"] * rb * 1.25, (1.2, 0.6, 1.6), 1 - 0.45 * birth, -Hh["spin_disk"] * 0.6 * t),
             ("kk_light_03", Hh["disk"] * rb, (0.75, 1.1, 1.5), 1 - 0.55 * birth, Hh["spin_disk"] * t)]
    for tex, size, col, tr, rot in disks:
        if tr < 0.995:
            V.draw_flat(buf, tb, cam, FlatQuad(B, normal, rot), tex, "None", 0, size, np.array(col, np.float32), tr, 0.0, 1.0)
    draw_black_ball(buf, cam, B, rb)
    occ = sphere_front_depth(cam, B, rb, buf)
    for tex, size, col, tr, rot in disks:
        if tr < 0.995:
            V.draw_flat(buf, tb, cam, FlatQuad(B, normal, rot), tex, "None", 0, size, np.array(col, np.float32), tr, 0.0,
                        1.0, occ)
    draw_bill(buf, tb, cam, B, Hh["purple"] * rb, 0, "kk_circle_02", (0.72 * gk, 0.4 * gk, 0.8 * gk), 1 - 0.6 * birth)
    draw_bill(buf, tb, cam, B, Hh["photon"] * rb, 0, "kk_circle_02", (0.92 * gk, 0.97 * gk, gk),
              1 - (0.9 - 0.1 * crit) * birth)
    glow_tr = 1 - (0.92 * crit ** 1.5) * (0.7 + 0.3 * pulse)
    draw_bill(buf, tb, cam, B, rb * (Hh["glow"][0] + (Hh["glow"][1] - Hh["glow"][0]) * crit), 0, "fx_glow",
              (0.9 * gk, 0.95 * gk, gk), glow_tr)


def draw_detonation(buf, tb, cam, det, B, t):
    r, a = det["core"]
    draw_neon_ball(buf, cam, B, r, (1.6, 1.75, 2.0), a)
    r, a = det["shell2"]
    draw_forcefield(buf, cam, B, r, (0.75, 0.35, 1.0), a, t)
    r, a = det["shell"]
    draw_forcefield(buf, cam, B, r, (0.43, 0.67, 1.0), a, t)
    size, tr = det["ring"]
    draw_bill(buf, tb, cam, B, size, 0, "kk_circle_02", (2.0, 2.2, 2.5), tr)


def color_correct(buf, cc, t):
    """ColorCorrectionEffect: brillo, contraste, saturación y tinte del cuadro."""
    row = cc[-1]
    for a, b in zip(cc, cc[1:]):
        if t <= b[0]:
            u = min(max((t - a[0]) / max(b[0] - a[0], 1e-6), 0), 1)
            row = [a[i] + (b[i] - a[i]) * u for i in range(7)]
            break
    br, co, sa = row[1], row[2], row[3]
    tint = np.array(row[4:7], np.float32) / 255
    if abs(br) < 1e-4 and abs(co) < 1e-4 and abs(sa) < 1e-4 and np.allclose(tint, 1):
        return buf
    out = buf * tint
    lum = out @ np.array([0.299, 0.587, 0.114], np.float32)
    out = lum[..., None] + (out - lum[..., None]) * (1 + sa)
    out = (out - 0.5) * (1 + co) + 0.5 + br
    return out


def flash(buf, fl, t):
    a = 0.0
    if fl[0] <= t < fl[1]:
        a = ((t - fl[0]) / (fl[1] - fl[0])) ** 2
    elif fl[1] <= t < fl[1] + fl[2]:
        a = 1.0
    elif t >= fl[1] + fl[2]:
        a = 1 - min(max((t - fl[1] - fl[2]) / fl[3], 0), 1)
    if a <= 0:
        return buf
    return buf * (1 - a) + a


def background(cam, dark=False, ground_y=0.0, grid=120.0):
    """Fondo para una escena de kilómetros: cielo, suelo con una rejilla gruesa que se desvanece a lo lejos (sin moiré)."""
    W, H = cam.W, cam.H
    us, vs = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    rays = cam.ray(us.ravel(), vs.ravel())
    dy = rays[1]
    if dark:
        sky = np.array([0.2, 0.21, 0.27]) * (1 - np.clip(dy * 1.5, 0, 1)[:, None] * 0.55)
        g0, g1 = np.array([0.075, 0.075, 0.085]), np.array([0.2, 0.21, 0.23])
    else:
        top, hor = np.array([0.30, 0.52, 0.86]), np.array([0.72, 0.82, 0.94])
        u = np.clip(dy * 2.2, 0, 1)[:, None]
        sky = hor * (1 - u) + top * u
        g0, g1 = np.array([0.55, 0.62, 0.7]), np.array([0.62, 0.68, 0.76])
    tt = (ground_y - cam.C[1]) / np.where(dy < -1e-6, dy, -1e-6)
    gx = cam.C[0] + rays[0] * tt
    gz = cam.C[2] + rays[2] * tt
    lw = 0.03 + 0.0 * gx
    fx = np.abs(((gx / grid) % 1) - 0.5) > 0.5 - lw
    fz = np.abs(((gz / grid) % 1) - 0.5) > 0.5 - lw
    fade = np.clip(1 - tt / 4500.0, 0, 1)[:, None]
    line = (fx | fz)[:, None] * fade
    haze = np.clip(tt / 9000.0, 0, 1)[:, None]
    ground = g0 * (1 - line) + g1 * line
    ground = ground * (1 - haze) + (sky if not dark else g0) * haze
    img = np.where((dy < 0)[:, None], ground, sky)
    return img.reshape(H, W, 3).astype(np.float32)
