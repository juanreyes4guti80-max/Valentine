"""KAIJU ZERO H1 — EXPLOSIÓN DE LAVA (la explosión gigante con esencia magmática, no una granada).

Al impactar, el suelo se abre en grietas de magma y brota un charco de lava fundida. Sale una FUENTE DE
MAGMA espesa: gotas que suben, se enfrían en el aire (amarillo -> naranja -> rojo -> costra oscura) y
llueven sobre el suelo dejando salpicaduras encendidas. Vuelan ROCAS FUNDIDAS (Parts con el material
CrackedLava de Roblox) que gotean lava y, al caer, salpican y quedan ardiendo. Sube una columna de humo
volcánico oscuro iluminada desde abajo, con brasas. Durante 5 s la lava sigue viva en el suelo:
burbujea, escupe chorritos y suelta brasas, mientras se enfría poco a poco.
Origen = punto del SUELO bajo la explosión. Escala 1 ≈ la misma que la explosión anterior.
"""
import math
import random

STATIC2x2 = ("Grid2x2", "Random", 0, True)
DECAL = dict(decal=True, orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))

# ----------------------------------------------------------------------------- colores
# Las texturas son grises con mucho contraste: con Brightness > 1 el centro satura a amarillo-naranja y los
# bordes quedan rojo oscuro (lava de verdad). El verde se mantiene bajo para que no se vuelva amarillo-blanco.
LAVA_GLOB = [(0, (255, 150, 52)), (0.25, (250, 118, 36)), (0.6, (215, 70, 20)), (1, (125, 32, 12))]   # se enfría
LAVA_JET = [(0, (255, 150, 50)), (0.5, (255, 120, 36)), (1, (230, 80, 22))]
GLOB_FADE = [(0, 0), (0.75, 0.05), (1, 1)]
ROCK_HOT = [(0, (255, 150, 60)), (0.4, (245, 108, 34)), (1, (185, 54, 18))]     # grietas de las rocas, se enfrían
LAVA_FLAME = [(0, (255, 190, 90)), (0.3, (255, 140, 45)), (0.7, (235, 85, 22)), (1, (160, 40, 12))]
EMBER = [(0, (255, 170, 80)), (0.5, (255, 120, 36)), (1, (220, 58, 15))]
ASH = [(0, (255, 120, 45)), (0.07, (130, 72, 48)), (0.2, (74, 60, 55)), (0.6, (88, 80, 76)), (1, (108, 102, 98))]
ASH_DUST = [(0, (120, 92, 78)), (0.5, (100, 86, 78)), (1, (92, 86, 82))]
POOL = [(0, (255, 140, 50)), (0.1, (255, 115, 38)), (0.55, (232, 82, 26)), (0.85, (168, 48, 17)), (1, (90, 26, 12))]
CRACKS = [(0, (255, 140, 50)), (0.1, (255, 112, 36)), (0.6, (225, 70, 22)), (1, (130, 34, 12))]
SPLAT = [(0, (255, 130, 45)), (0.3, (240, 98, 30)), (0.75, (165, 44, 16)), (1, (80, 26, 14))]


def glob(name, emit, speed, spread, life, sizes, offset=(0, 3, 0), accel=-150, drag=0.5, direction="Top",
         shape=None, le=0.15, bright=1.5, color=LAVA_GLOB, **kw):
    """Gotas de magma espesas: suben, caen por la gravedad y se enfrían."""
    a, b, c = sizes
    L = dict(name=name, texture="kz_lava_glob_2x2", flipbook=STATIC2x2, emit=emit, offset=offset,
             direction=direction, spread=spread, speed=speed, drag=drag, accel=(0, accel, 0), lifetime=life,
             size=[(0, a, a * 0.35), (0.2, b, b * 0.3), (1, c, c * 0.3)], color=color,
             transparency=GLOB_FADE, light_emission=le, brightness=bright,
             rotation=(0, 360), rot_speed=(-220, 220))
    if shape:
        L["shape"] = shape
    L.update(kw)
    return L


def lava_clusters(n=9, seed=41, t0=0.2, t_end=5.2):
    """Manchas de lava que quedan vivas en el suelo: burbujean, escupen chorritos y sueltan brasas."""
    g = random.Random(seed)
    layers = []
    for k in range(n):
        if k == 0:
            x, z, sc = 0.0, 0.0, 2.0
        else:
            r = 10 + 24 * g.random() ** 0.5
            a = g.random() * 2 * math.pi
            x, z, sc = math.cos(a) * r, math.sin(a) * r, 0.9 + 0.7 * g.random()
        box = {"type": "Box", "size": (5 * sc, 0.2, 5 * sc)}
        life = t_end - t0
        layers += [
            dict(name=f"LavaPatch{k}", texture="kz_lava_pool", emit=[(t0 + 0.05 * k, 1)], offset=(x, 0.22, z),
                 lifetime=(life, life), size=[(0, 2 * sc), (0.05, 13 * sc), (1, 13.5 * sc)],
                 transparency=[(0, 0.05), (0.8, 0.2), (1, 1)], color=POOL, light_emission=0.7,
                 rotation=(0, 360), **DECAL),
            dict(name=f"LavaBubbles{k}", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, offset=(x, 0.6, z),
                 shape=box, direction="Top", spread=(25, 25), speed=(6 * sc, 13 * sc), drag=0.5,
                 accel=(0, -45, 0), lifetime=(0.4, 0.65), size=[(0, 0.6 * sc, 0.2), (0.3, 1.5 * sc, 0.4), (1, 1.0 * sc, 0.3)],
                 color=LAVA_GLOB, light_emission=0.15, brightness=1.5, rotation=(0, 360),
                 stream=[(t0, t_end - 0.3, 9, 3)]),
            dict(name=f"LavaLick{k}", texture="kk_muzzle_04" if k % 2 == 0 else "kk_muzzle_05",
                 orientation="VelocityParallel", offset=(x, 0.5, z), shape=box, direction="Top", spread=(12, 12),
                 speed=(3 * sc, 7 * sc), drag=2, lifetime=(0.3, 0.5),
                 size=[(0, 1.5 * sc, 0.5), (0.3, 4.5 * sc, 1), (1, 3 * sc, 0.8)],
                 transparency=[(0, 0.05), (0.6, 0.2), (1, 1)], color=LAVA_FLAME, light_emission=0.4,
                 brightness=1.5, stream=[(t0, t_end - 0.5, 5, 1)]),
            dict(name=f"LavaHeat{k}", texture="kk_flare_01", offset=(x, 1.5, z),
                 shape={"type": "Box", "size": (5 * sc, 1, 5 * sc)}, direction="Top", spread=(30, 30),
                 speed=(5, 12), drag=1.5, accel=(0, 9, 0), lifetime=(0.7, 1.1),
                 size=[(0, 0), (0.1, 1.3, 0.4), (1, 0)], color=EMBER, light_emission=1.0, brightness=1.6,
                 stream=[(t0 + 0.1, t_end - 0.2, 5, 1)]),
            dict(name=f"LavaSmoke{k}", texture="kk_smoke_04", offset=(x, 2.5, z), direction="Top",
                 spread=(15, 15), speed=(5, 10), drag=1.2, accel=(0, 5, 0), lifetime=(1.2, 1.7),
                 size=[(0, 3 * sc, sc), (1, 12 * sc, 3 * sc)], transparency=[(0, 0.6), (0.3, 0.5), (1, 1)],
                 color=ASH, rotation=(0, 360), rot_speed=(-25, 25), zoffset=-2, stream=[(0.4, t_end, 2.5, 0.8)]),
        ]
        if k == 0:
            # el cráter escupe chorros de magma cada tanto
            spurts = [(round(ts, 2), 7) for ts in (0.8, 1.35, 1.9, 2.6, 3.3, 4.0, 4.6)]
            layers.append(glob("LavaSpurts", spurts, (22, 42), (22, 22), (0.6, 0.9), (1.5, 3.2, 2.2),
                               offset=(0, 1, 0), accel=-110, shape={"type": "Box", "size": (8, 0.5, 8)}))
    return layers


def splat_points(g, n=14, t=(0.75, 1.35), r=(14, 42)):
    """Salpicaduras donde cae la lluvia de magma (posiciones sueltas alrededor)."""
    out = []
    for _ in range(n):
        a = g.uniform(0, 2 * math.pi)
        rr = g.uniform(*r)
        out.append((round(g.uniform(*t), 3), 1, round(math.cos(a) * rr, 2), 0.24, round(math.sin(a) * rr, 2)))
    return sorted(out)


def crack_points(g, n=12, r=(12, 38), t=(0.03, 0.2), y=0.6):
    """Puntos de las grietas por donde revienta la lava: salen antes cerca del centro y después más lejos,
    a medida que las grietas se abren."""
    out = []
    for k in range(n):
        a = 2 * math.pi * (k + g.uniform(-0.35, 0.35)) / n
        rr = g.uniform(*r)
        tt = t[0] + (rr - r[0]) / (r[1] - r[0]) * (t[1] - t[0])
        out.append((round(tt, 3), round(math.cos(a) * rr, 2), y, round(math.sin(a) * rr, 2)))
    return sorted(out)


def at_points(pts, n):
    return [(t, n, x, y, z) for (t, x, y, z) in pts]


def lava_explosion_spec():
    g = random.Random(5)
    crater = {"type": "Box", "size": (7, 1, 7)}
    cracks = crack_points(random.Random(11))
    layers = [
        # ---------------- el suelo se abre: grietas de magma, charco de lava y quemadura (sin destello) ----------------
        dict(name="VentGlow", texture="fx_glow", emit=[(0.0, 1)], offset=(0, 2, 0), lifetime=(0.6, 0.6),
             size=[(0, 8), (0.25, 30), (1, 34)], transparency=[(0, 0.35), (0.5, 0.6), (1, 1)],
             color=[(0, (255, 130, 45)), (1, (200, 55, 18))], light_emission=0.5, brightness=0.9, zoffset=-2),
        dict(name="Scorch", texture="kz_scorch", emit=[(0.0, 1)], offset=(0, 0.14, 0), lifetime=(5.6, 5.6),
             size=[(0, 12), (0.03, 66), (1, 70)], transparency=[(0, 0.1), (0.8, 0.22), (1, 1)],
             rotation=(0, 360), zoffset=-1, **DECAL),
        dict(name="LavaCracks", texture="kz_lava_cracks", emit=[(0.0, 1)], offset=(0, 0.18, 0), lifetime=(5.4, 5.4),
             size=[(0, 20), (0.04, 92), (1, 98)], transparency=[(0, 0.05), (0.7, 0.25), (1, 1)], color=CRACKS,
             light_emission=0.8, rotation=(0, 360), **DECAL),
        dict(name="LavaPool", texture="kz_lava_pool", emit=[(0.03, 1)], offset=(0, 0.2, 0), lifetime=(5.5, 5.5),
             size=[(0, 10), (0.05, 52), (1, 56)], transparency=[(0, 0), (0.85, 0.15), (1, 1)], color=POOL,
             light_emission=0.7, rotation=(0, 360), **DECAL),
        # ceniza que se arrastra por el suelo (lenta: no es una onda expansiva)
        dict(name="AshSurge", texture="kk_smoke_07", emit=[(0.04, 20)], offset=(0, 2.5, 0), direction="Front",
             spread=(180, 3), speed=(35, 60), drag=2.2, accel=(0, 5, 0), lifetime=(1.3, 1.8),
             size=[(0, 8, 2), (0.3, 16, 3), (1, 24, 4)], transparency=[(0, 0.5), (0.2, 0.32), (0.6, 0.5), (1, 1)],
             color=ASH_DUST, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3),
        # ---------------- la erupción: brota un domo de magma y sale un GÉISER de lava espesa ----------------
        dict(name="MagmaDome", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, emit=[(0.0, 4), (0.08, 3)],
             offset=(0, 1.5, 0), shape={"type": "Box", "size": (5, 0.5, 5)}, direction="Top", spread=(25, 25),
             speed=(8, 18), drag=1.5, accel=(0, -20, 0), lifetime=(0.45, 0.6), size=[(0, 6, 1.5), (0.4, 14, 2), (1, 11, 2)],
             color=LAVA_GLOB, transparency=[(0, 0), (0.7, 0.1), (1, 1)], light_emission=0.15, brightness=1.5,
             rotation=(0, 360), rot_speed=(-40, 40), zoffset=2),
        # el géiser: un chorro continuo y espeso que sube ~60 studs y llueve alrededor del cráter
        glob("LavaGeyser", [(0.0, 30)], (60, 140), (9, 9), (1.2, 2.0), (2, 3.8, 2.8), offset=(0, 2, 0),
             shape=crater, accel=-130, drag=0.3, stream=[(0.0, 0.4, 200, 140), (0.4, 1.3, 140, 10)]),
        # el corazón del géiser: un chorro de lava continuo que se rompe en gotas arriba
        dict(name="LavaJet", texture="kz_lava_drop", orientation="VelocityParallel", offset=(0, 2, 0),
             shape={"type": "Box", "size": (4, 0.5, 4)}, direction="Top", spread=(3, 3), speed=(115, 150), drag=0.3,
             accel=(0, -130, 0), lifetime=(0.3, 0.45), size=[(0, 5, 1), (0.3, 9, 1.5), (1, 7, 1)], color=LAVA_JET,
             transparency=[(0, 0), (0.6, 0.1), (1, 1)], light_emission=0.3, brightness=1.8,
             stream=[(0.0, 0.35, 70, 55), (0.35, 1.2, 55, 0)]),
        glob("LavaBlobs", [(0.02, 8), (0.1, 6), (0.2, 4)], (70, 110), (28, 28), (1.3, 1.7), (5, 8, 6.5),
             offset=(0, 2, 0), shape=crater, accel=-130, drag=0.3, bright=1.9),
        glob("LavaCrown", [(0.0, 36), (0.05, 16)], (32, 68), (72, 72), (0.6, 0.9), (1.6, 3.0, 2.2),
             offset=(0, 1.5, 0), shape=crater, accel=-150),
        # el suelo revienta: la lava sale a chorros por las grietas, en anillo, a medida que se abren
        glob("CrackBursts", [], (30, 65), (22, 22), (0.6, 0.9), (1.6, 3.2, 2.4), offset=(0, 0, 0),
             points=at_points(cracks, 7), accel=-140, shape={"type": "Box", "size": (3, 0.5, 3)}),
        dict(name="CrackJets", texture="kz_lava_drop", orientation="VelocityParallel", points=at_points(cracks, 4),
             direction="Top", spread=(10, 10), speed=(50, 80), drag=0.3, accel=(0, -130, 0), lifetime=(0.3, 0.45),
             size=[(0, 2.5, 0.5), (0.3, 4.5, 0.8), (1, 3.5, 0.6)], color=LAVA_GLOB,
             transparency=[(0, 0), (0.6, 0.1), (1, 1)], light_emission=0.2, brightness=1.6),
        dict(name="CrackPuffs", texture="kk_smoke_04", points=at_points(cracks, 2), direction="Top", spread=(20, 20),
             speed=(8, 16), drag=1.2, accel=(0, 6, 0), lifetime=(1.0, 1.4), size=[(0, 4, 1), (1, 14, 3)],
             transparency=[(0, 0.5), (0.3, 0.45), (1, 1)], color=ASH, rotation=(0, 360), rot_speed=(-30, 30),
             zoffset=-4),
        dict(name="LavaDrops", texture="kz_lava_drop", orientation="VelocityParallel",
             emit=[(0.0, 36), (0.06, 18), (0.15, 10)], offset=(0, 2, 0), shape=crater, direction="Top",
             spread=(45, 45), speed=(70, 120), drag=0.3, accel=(0, -130, 0), lifetime=(0.8, 1.3),
             size=[(0, 1.5, 0.4), (0.3, 3, 0.6), (1, 2.2, 0.5)], color=LAVA_GLOB, transparency=GLOB_FADE,
             light_emission=0.2, brightness=2.0),
        # trozos de ROCA DE LAVA: costra oscura con grietas encendidas, dan vueltas y caen
        dict(name="LavaRocks", texture="kz_lava_rock_2x2", flipbook=STATIC2x2, emit=[(0.0, 26), (0.05, 14), (0.12, 6)],
             offset=(0, 2, 0), shape=crater, direction="Top", spread=(55, 55), speed=(60, 120), drag=0.3,
             accel=(0, -130, 0), lifetime=(1.1, 1.7), size=[(0, 2.4, 1.2), (1, 2.2, 1.1)], color=ROCK_HOT,
             light_emission=0.1, brightness=1.6, rotation=(0, 360), rot_speed=(-300, 300)),
        dict(name="LavaRocksBig", texture="kz_lava_rock_2x2", flipbook=STATIC2x2, emit=[(0.02, 6), (0.1, 4)],
             offset=(0, 2, 0), shape=crater, direction="Top", spread=(35, 35), speed=(60, 95), drag=0.3,
             accel=(0, -130, 0), lifetime=(1.2, 1.6), size=[(0, 5, 1.5), (1, 4.6, 1.4)], color=ROCK_HOT,
             light_emission=0.1, brightness=1.6, rotation=(0, 360), rot_speed=(-160, 160)),
        # ---------------- humo volcánico oscuro: una columna que sigue saliendo mientras brota la lava ----------------
        dict(name="AshColumn", texture="kk_smoke_07", offset=(0, 7, 0), shape={"type": "Box", "size": (10, 6, 10)},
             direction="Top", spread=(12, 12), speed=(18, 30), drag=0.8, accel=(0, 6, 0), lifetime=(1.6, 2.2),
             size=[(0, 12, 3), (0.5, 30, 5), (1, 42, 6)], transparency=[(0, 0.55), (0.12, 0.32), (0.6, 0.45), (1, 1)],
             color=ASH, rotation=(0, 360), rot_speed=(-20, 20), zoffset=-12,
             stream=[(0.15, 0.6, 10, 12), (0.6, 2.4, 12, 2)]),
        dict(name="AshPlume", texture="kk_smoke_08", emit=[(0.35, 4), (0.6, 4)], offset=(0, 32, 0),
             shape={"type": "Sphere", "radius": 10.0}, direction="Top", spread=(50, 50), speed=(10, 18),
             drag=1.2, accel=(0, 8, 0), lifetime=(1.9, 2.4), size=[(0, 22, 4), (0.4, 40, 6), (1, 52, 6)],
             transparency=[(0, 0.6), (0.15, 0.38), (0.6, 0.5), (1, 1)], color=ASH, rotation=(0, 360),
             rot_speed=(-20, 20), zoffset=-12),
        dict(name="AshBase", texture="kk_smoke_04", emit=[(0.1, 6), (0.3, 5)], offset=(0, 6, 0),
             shape={"type": "Box", "size": (16, 8, 16)}, direction="Top", spread=(25, 25), speed=(8, 16),
             drag=1.2, accel=(0, 7, 0), lifetime=(1.5, 2.0), size=[(0, 14, 3), (0.5, 26, 4), (1, 32, 4)],
             transparency=[(0, 0.5), (0.2, 0.3), (0.7, 0.45), (1, 1)], color=ASH, rotation=(0, 360),
             rot_speed=(-25, 25), zoffset=-11),
        # ---------------- rocas fundidas: gotean lava y al caer salpican y quedan ardiendo ----------------
        dict(name="MoltenRocks", type="meteor", emit=[(0.02, 12), (0.1, 8)], offset=(0, 3, 0), direction="Top",
             spread=(58, 58), speed=(70, 118), accel=(0, -120, 0), drag=0.2, lifetime=(1.4, 1.8),
             sprite={"texture": "kz_lava_rock_2x2", "layout": "Grid2x2", "size": (2.8, 4.4),
                     "rot_speed": (-480, 480), "color": (255, 150, 60), "material": "CrackedLava"},
             trails=[
                 {"name": "RockDrip", "rate": 26, "texture": "kz_lava_glob_2x2", "flipbook": STATIC2x2,
                  "speed": (0, 3), "direction": "Top", "spread": (180, 180), "accel": (0, -70, 0),
                  "lifetime": (0.35, 0.55), "size": [(0, 1.6, 0.4), (1, 0.8, 0.2)], "color": LAVA_GLOB,
                  "light_emission": 0.15, "brightness": 1.5, "rotation": (0, 360)},
                 {"name": "RockEmbers", "rate": 30, "texture": "kk_flare_01", "speed": (0, 3), "direction": "Top",
                  "spread": (180, 180), "lifetime": (0.25, 0.45), "size": [(0, 0), (0.15, 2.2, 0.6), (1, 0)],
                  "color": EMBER, "light_emission": 1.0, "brightness": 1.5},
                 {"name": "RockSmoke", "rate": 24, "texture": "kk_smoke_04", "speed": (1, 4), "direction": "Top",
                  "spread": (180, 180), "drag": 2, "accel": (0, 6, 0), "lifetime": (0.55, 0.85),
                  "size": [(0, 3, 0.8), (1, 9, 2)], "transparency": [(0, 0.35), (0.6, 0.55), (1, 1)],
                  "color": ASH, "rotation": (0, 360)},
             ],
             land=[
                 dict(name="RockSplat", texture="kz_lava_splat", emit=[(0, 1)], lifetime=(3.0, 3.0),
                      size=[(0, 2), (0.04, 11), (1, 12)], transparency=[(0, 0), (0.8, 0.2), (1, 1)], color=SPLAT,
                      light_emission=0.7, rotation=(0, 360), **DECAL),
                 dict(name="RockSplash", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, emit=[(0, 8)],
                      direction="Top", spread=(60, 60), speed=(14, 28), accel=(0, -110, 0), drag=0.5,
                      lifetime=(0.4, 0.65), size=[(0, 1.2, 0.3), (0.3, 2.2, 0.5), (1, 1.4, 0.4)], color=LAVA_GLOB,
                      light_emission=0.15, brightness=1.5, rotation=(0, 360)),
                 dict(name="RockBurn", texture="kk_muzzle_05", orientation="VelocityParallel", direction="Top",
                      spread=(10, 10), speed=(3, 7), drag=2, lifetime=(0.3, 0.5),
                      size=[(0, 1.2, 0.4), (0.3, 3.5, 0.8), (1, 2.2, 0.6)], transparency=[(0, 0.05), (0.6, 0.2), (1, 1)],
                      color=LAVA_FLAME, light_emission=0.3, brightness=1.4, stream=[(0, 2.5, 8, 0)]),
                 dict(name="RockWisp", texture="kk_smoke_04", direction="Top", spread=(15, 15), speed=(4, 9),
                      drag=1.2, accel=(0, 5, 0), lifetime=(1.0, 1.4), size=[(0, 2, 0.6), (1, 7, 2)],
                      transparency=[(0, 0.6), (0.3, 0.5), (1, 1)], color=ASH, rotation=(0, 360),
                      stream=[(0.1, 2.6, 2.5, 0.5)]),
             ]),
        # la lluvia de magma deja salpicaduras encendidas alrededor
        dict(name="RainSplats", texture="kz_lava_splat", points=splat_points(g, n=16, t=(0.6, 1.45), r=(10, 34)),
             lifetime=(3.4, 3.4), size=[(0, 2), (0.04, 9), (1, 10)], transparency=[(0, 0), (0.8, 0.2), (1, 1)],
             color=SPLAT, light_emission=0.7, rotation=(0, 360), **DECAL),
        # ---------------- brasas que suben del magma ----------------
        dict(name="Embers", texture="kk_flare_01", emit=[(0.1, 24), (0.4, 18)], offset=(0, 8, 0),
             shape={"type": "Sphere", "radius": 12.0}, direction="Top", spread=(60, 60), speed=(10, 30), drag=1.5,
             accel=(0, 14, 0), lifetime=(0.9, 1.5), size=[(0, 0), (0.1, 2.2, 0.7), (1, 0)], color=EMBER,
             light_emission=1.0, brightness=1.2, stream=[(0.2, 2.0, 30, 6)]),
    ] + lava_clusters()
    return {
        "name": "GiantExplosion",
        "doc": ("Explosión GIGANTE DE LAVA: el suelo se abre en grietas de magma, brota un charco de lava, una fuente "
                "de magma llueve gotas que se enfrían y salpican, vuelan rocas fundidas (CrackedLava) que gotean lava, "
                "sube humo volcánico y la lava queda viva en el suelo 5 s. Cierra limpio a los 5.8 s."),
        "duration": 5.8,
        "light": {"color": (255, 120, 40), "brightness": 5, "range": 60, "time": 4.5},
        "layers": layers,
    }


LAVA_EXPLOSION = lava_explosion_spec()
