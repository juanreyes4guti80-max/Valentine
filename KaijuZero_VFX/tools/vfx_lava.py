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
LAVA_HOT = [(0, (255, 220, 140)), (0.15, (255, 170, 60)), (0.4, (250, 120, 30)), (0.75, (225, 70, 15)),
            (1, (190, 50, 12))]
LAVA_GLOB = [(0, (255, 214, 120)), (0.2, (255, 150, 40)), (0.55, (240, 90, 18)), (1, (185, 44, 12))]    # se enfría
GLOB_FADE = [(0, 0), (0.75, 0.05), (1, 1)]
LAVA_FLAME = [(0, (255, 236, 150)), (0.3, (255, 166, 50)), (0.7, (240, 90, 20)), (1, (160, 40, 12))]
EMBER = [(0, (255, 225, 130)), (0.5, (255, 140, 40)), (1, (220, 60, 15))]
ASH = [(0, (255, 130, 50)), (0.06, (130, 74, 50)), (0.2, (78, 64, 58)), (0.6, (92, 84, 80)), (1, (112, 106, 102))]
ROCKY = [(0, (150, 70, 40)), (0.3, (92, 44, 30)), (1, (60, 34, 26))]                  # trozos de roca de lava
ASH_DUST = [(0, (128, 100, 84)), (0.5, (106, 92, 84)), (1, (96, 90, 86))]
POOL = [(0, (255, 210, 110)), (0.08, (255, 160, 55)), (0.55, (235, 96, 30)), (0.85, (170, 50, 18)), (1, (90, 26, 12))]
SPLAT = [(0, (255, 190, 80)), (0.3, (245, 120, 35)), (0.75, (170, 48, 16)), (1, (80, 26, 14))]


def glob(name, emit, speed, spread, life, sizes, offset=(0, 3, 0), accel=-150, drag=0.5, direction="Top",
         shape=None, le=0.55, bright=1.45, color=LAVA_GLOB):
    """Gotas de magma espesas: suben, caen por la gravedad y se enfrían."""
    a, b, c = sizes
    L = dict(name=name, texture="kz_lava_glob_2x2", flipbook=STATIC2x2, emit=emit, offset=offset,
             direction=direction, spread=spread, speed=speed, drag=drag, accel=(0, accel, 0), lifetime=life,
             size=[(0, a, a * 0.35), (0.2, b, b * 0.3), (1, c, c * 0.3)], color=color,
             transparency=GLOB_FADE, light_emission=le, brightness=bright,
             rotation=(0, 360), rot_speed=(-220, 220))
    if shape:
        L["shape"] = shape
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
                 transparency=[(0, 0.05), (0.8, 0.2), (1, 1)], color=POOL, light_emission=0.9,
                 rotation=(0, 360), **DECAL),
            dict(name=f"LavaBubbles{k}", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, offset=(x, 0.6, z),
                 shape=box, direction="Top", spread=(25, 25), speed=(6 * sc, 13 * sc), drag=0.5,
                 accel=(0, -45, 0), lifetime=(0.4, 0.65), size=[(0, 0.6 * sc, 0.2), (0.3, 1.5 * sc, 0.4), (1, 1.0 * sc, 0.3)],
                 color=LAVA_GLOB, light_emission=0.4, brightness=1.5, rotation=(0, 360),
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


def lava_explosion_spec():
    g = random.Random(5)
    layers = [
        # ---------------- impacto: resplandor de magma (sin destello blanco de granada) ----------------
        dict(name="FlashGlow", texture="fx_glow", emit=[(0.0, 1)], offset=(0, 6, 0), lifetime=(0.3, 0.3),
             size=[(0, 16), (0.25, 50), (1, 56)], transparency=[(0, 0.25), (0.5, 0.5), (1, 1)],
             color=[(0, (255, 170, 70)), (0.4, (255, 120, 40)), (1, (210, 60, 18))], light_emission=1.0,
             brightness=0.9, zoffset=10),
        dict(name="FlashBurst", texture="fx_burst_fan", emit=[(0.0, 2)], offset=(0, 5, 0), lifetime=(0.12, 0.15),
             size=[(0, 14), (0.4, 38), (1, 42)], transparency=[(0, 0.2), (0.5, 0.45), (1, 1)],
             color=[(0, (255, 170, 80)), (1, (230, 80, 25))], light_emission=1.0, brightness=1.0,
             rotation=(0, 360), zoffset=11),
        dict(name="Glow", texture="fx_glow", emit=[(0.0, 1)], offset=(0, 10, 0), lifetime=(1.4, 1.4),
             size=[(0, 30), (0.1, 80), (1, 90)], transparency=[(0, 0.45), (0.4, 0.72), (1, 1)],
             color=[(0, (255, 140, 55)), (1, (200, 60, 20))], light_emission=0.6, brightness=0.9, zoffset=-12),
        # ---------------- el suelo se abre: grietas de magma, charco de lava y quemadura ----------------
        dict(name="Scorch", texture="kz_scorch", emit=[(0.0, 1)], offset=(0, 0.14, 0), lifetime=(5.6, 5.6),
             size=[(0, 12), (0.03, 66), (1, 70)], transparency=[(0, 0.1), (0.8, 0.22), (1, 1)],
             rotation=(0, 360), zoffset=-1, **DECAL),
        dict(name="LavaCracks", texture="kz_lava_cracks", emit=[(0.0, 1)], offset=(0, 0.18, 0), lifetime=(5.4, 5.4),
             size=[(0, 20), (0.05, 92), (1, 98)], transparency=[(0, 0.05), (0.7, 0.25), (1, 1)],
             color=[(0, (255, 210, 110)), (0.1, (255, 150, 50)), (0.6, (230, 80, 25)), (1, (130, 34, 12))],
             light_emission=1.0, rotation=(0, 360), **DECAL),
        dict(name="LavaPool", texture="kz_lava_pool", emit=[(0.02, 1)], offset=(0, 0.2, 0), lifetime=(5.5, 5.5),
             size=[(0, 10), (0.03, 52), (1, 56)], transparency=[(0, 0), (0.85, 0.15), (1, 1)], color=POOL,
             light_emission=1.0, rotation=(0, 360), **DECAL),
        dict(name="HeatRing", texture="kk_circle_03", emit=[(0.0, 1)], offset=(0, 0.3, 0), lifetime=(0.45, 0.45),
             size=[(0, 20), (0.3, 70), (1, 120)], transparency=[(0, 0.55), (0.4, 0.78), (1, 1)],
             color=[(0, (255, 150, 60)), (1, (220, 70, 25))], light_emission=0.4, **DECAL),
        # polvo volcánico que corre por el suelo
        dict(name="DustWave", texture="kk_smoke_07", emit=[(0.02, 32)], offset=(0, 2.5, 0), direction="Front",
             spread=(180, 3), speed=(95, 150), drag=3.6, accel=(0, 6, 0), lifetime=(1.1, 1.5),
             size=[(0, 9, 2), (0.3, 22, 4), (1, 30, 5)], transparency=[(0, 0.45), (0.15, 0.25), (0.6, 0.45), (1, 1)],
             color=ASH_DUST, rotation=(0, 360), rot_speed=(-40, 40), zoffset=-3),
        # ---------------- la erupción: núcleo de magma, fuente, corona de salpicaduras y chorros ----------------
        dict(name="MagmaCore", texture="kk_fire_02", emit=[(0.0, 3), (0.06, 2)], offset=(0, 6, 0),
             speed=(0, 5), direction="Top", spread=(180, 180), lifetime=(0.4, 0.5),
             size=[(0, 10, 3), (0.3, 24, 4), (1, 26, 4)], transparency=[(0, 0.1), (0.6, 0.3), (1, 1)],
             color=[(0, (255, 200, 110)), (0.3, (255, 140, 45)), (1, (225, 70, 20))], light_emission=0.4,
             brightness=1.2, rotation=(0, 360), rot_speed=(-80, 80), zoffset=3),
        dict(name="MagmaBurst", texture="fx_fire_2x2", flipbook=STATIC2x2, emit=[(0.0, 6), (0.05, 4)],
             offset=(0, 6, 0), shape={"type": "Sphere", "radius": 6.0}, direction="Top", spread=(180, 180),
             speed=(18, 36), drag=3, accel=(0, 8, 0), lifetime=(0.5, 0.75),
             size=[(0, 8, 2), (0.3, 18, 3), (1, 20, 3)], transparency=[(0, 0), (0.6, 0.12), (1, 1)],
             color=LAVA_HOT, light_emission=0.25, brightness=1.35, rotation=(0, 360), rot_speed=(-60, 60)),
        glob("LavaFountain", [(0.0, 44), (0.05, 32), (0.12, 20), (0.2, 12)], (90, 150), (18, 18), (1.0, 1.4),
             (3, 6, 4), offset=(0, 4, 0), accel=-140),
        glob("LavaCrown", [(0.0, 60), (0.04, 28)], (40, 85), (75, 75), (0.7, 1.0), (2, 3.6, 2.6),
             offset=(0, 2, 0), accel=-150),
        dict(name="LavaDrops", texture="kz_lava_drop", orientation="VelocityParallel", emit=[(0.0, 60), (0.06, 30)],
             offset=(0, 4, 0), direction="Top", spread=(70, 70), speed=(80, 140), drag=0.5, accel=(0, -150, 0),
             lifetime=(0.5, 0.8), size=[(0, 2.5, 0.6), (0.3, 4.5, 1), (1, 3, 0.6)], color=LAVA_HOT,
             transparency=GLOB_FADE, light_emission=0.6, brightness=1.5),
        # trozos de roca de lava (costra oscura) que vuelan con el magma
        dict(name="LavaChunks", texture="kz_debris_2x2", flipbook=STATIC2x2, emit=[(0.0, 36), (0.05, 14)],
             offset=(0, 4, 0), direction="Top", spread=(65, 65), speed=(60, 120), drag=0.4, accel=(0, -140, 0),
             lifetime=(0.8, 1.3), size=[(0, 1.6, 0.6), (1, 1.4, 0.5)], color=ROCKY, light_emission=0.1,
             rotation=(0, 360), rot_speed=(-400, 400)),
        dict(name="MagmaJets", texture="kk_muzzle_04", orientation="VelocityParallel", emit=[(0.01, 12), (0.07, 6)],
             offset=(0, 6, 0), direction="Top", spread=(100, 100), speed=(60, 100), drag=6, accel=(0, -10, 0),
             lifetime=(0.4, 0.6), size=[(0, 8, 2), (0.3, 22, 4), (1, 18, 3)],
             transparency=[(0, 0), (0.6, 0.15), (1, 1)], color=LAVA_FLAME, light_emission=0.3, brightness=1.6),
        # ---------------- humo volcánico oscuro, iluminado desde abajo ----------------
        dict(name="AshPlume", texture="kk_smoke_07", emit=[(0.15, 6), (0.3, 6), (0.5, 5), (0.75, 4)],
             offset=(0, 22, 0), shape={"type": "Box", "size": (14, 26, 14)}, direction="Top", spread=(35, 35),
             speed=(12, 24), drag=1.2, accel=(0, 9, 0), lifetime=(2.0, 2.6),
             size=[(0, 20, 4), (0.4, 40, 6), (1, 54, 6)], transparency=[(0, 0.55), (0.12, 0.36), (0.6, 0.5), (1, 1)],
             color=ASH, rotation=(0, 360), rot_speed=(-20, 20), zoffset=-12),
        dict(name="AshPlume2", texture="kk_smoke_08", emit=[(0.2, 5), (0.45, 4), (0.7, 3)], offset=(0, 34, 0),
             shape={"type": "Sphere", "radius": 12.0}, direction="Top", spread=(60, 60), speed=(10, 20),
             drag=1.2, accel=(0, 8, 0), lifetime=(1.9, 2.4), size=[(0, 22, 4), (0.4, 42, 6), (1, 56, 6)],
             transparency=[(0, 0.55), (0.12, 0.34), (0.6, 0.5), (1, 1)], color=ASH, rotation=(0, 360),
             rot_speed=(-20, 20), zoffset=-12),
        dict(name="AshBase", texture="kk_smoke_04", emit=[(0.1, 6), (0.3, 5)], offset=(0, 8, 0),
             shape={"type": "Box", "size": (16, 10, 16)}, direction="Top", spread=(25, 25), speed=(8, 16),
             drag=1.2, accel=(0, 7, 0), lifetime=(1.5, 2.0), size=[(0, 14, 3), (0.5, 26, 4), (1, 32, 4)],
             transparency=[(0, 0.5), (0.2, 0.3), (0.7, 0.45), (1, 1)], color=ASH, rotation=(0, 360),
             rot_speed=(-25, 25), zoffset=-11),
        # ---------------- rocas fundidas: gotean lava y al caer salpican y quedan ardiendo ----------------
        dict(name="MoltenRocks", type="meteor", emit=[(0.02, 16)], offset=(0, 4, 0), direction="Top",
             spread=(58, 58), speed=(70, 118), accel=(0, -120, 0), drag=0.2, lifetime=(1.4, 1.8),
             sprite={"texture": "kz_debris_2x2", "layout": "Grid2x2", "size": (2.8, 4.4), "rot_speed": (-480, 480),
                     "color": (150, 62, 32), "material": "CrackedLava"},
             trails=[
                 # resplandor de la roca fundida: pegado a la roca (LockedToPart), aditivo y suave
                 {"name": "RockGlow", "rate": 60, "locked": True, "texture": "fx_glow", "speed": (0, 0),
                  "direction": "Top", "lifetime": (0.075, 0.075), "size": [(0, 6.5, 0.8), (1, 6.5, 0.8)],
                  "color": [(0, (255, 80, 10)), (1, (255, 80, 10))], "transparency": [(0, 0.92), (1, 0.92)],
                  "light_emission": 1.0, "brightness": 1.0},
                 {"name": "RockDrip", "rate": 26, "texture": "kz_lava_glob_2x2", "flipbook": STATIC2x2,
                  "speed": (0, 3), "direction": "Top", "spread": (180, 180), "accel": (0, -70, 0),
                  "lifetime": (0.35, 0.55), "size": [(0, 1.6, 0.4), (1, 0.8, 0.2)], "color": LAVA_GLOB,
                  "light_emission": 0.4, "brightness": 1.5, "rotation": (0, 360)},
                 {"name": "RockEmbers", "rate": 34, "texture": "kk_flare_01", "speed": (0, 3), "direction": "Top",
                  "spread": (180, 180), "lifetime": (0.25, 0.45), "size": [(0, 0), (0.15, 2.4, 0.6), (1, 0)],
                  "color": EMBER, "light_emission": 1.0, "brightness": 1.7},
                 {"name": "RockSmoke", "rate": 24, "texture": "kk_smoke_04", "speed": (1, 4), "direction": "Top",
                  "spread": (180, 180), "drag": 2, "accel": (0, 6, 0), "lifetime": (0.55, 0.85),
                  "size": [(0, 3, 0.8), (1, 9, 2)], "transparency": [(0, 0.35), (0.6, 0.55), (1, 1)],
                  "color": ASH, "rotation": (0, 360)},
             ],
             land=[
                 dict(name="RockSplat", texture="kz_lava_splat", emit=[(0, 1)], lifetime=(3.0, 3.0),
                      size=[(0, 2), (0.04, 11), (1, 12)], transparency=[(0, 0), (0.8, 0.2), (1, 1)], color=SPLAT,
                      light_emission=1.0, rotation=(0, 360), **DECAL),
                 dict(name="RockSplash", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, emit=[(0, 8)],
                      direction="Top", spread=(60, 60), speed=(14, 28), accel=(0, -110, 0), drag=0.5,
                      lifetime=(0.4, 0.65), size=[(0, 1.2, 0.3), (0.3, 2.2, 0.5), (1, 1.4, 0.4)], color=LAVA_GLOB,
                      light_emission=0.4, brightness=1.5, rotation=(0, 360)),
                 dict(name="RockBurn", texture="kk_muzzle_05", orientation="VelocityParallel", direction="Top",
                      spread=(10, 10), speed=(3, 7), drag=2, lifetime=(0.3, 0.5),
                      size=[(0, 1.2, 0.4), (0.3, 4, 0.8), (1, 2.5, 0.6)], transparency=[(0, 0), (0.6, 0.15), (1, 1)],
                      color=LAVA_FLAME, light_emission=0.4, brightness=1.5, stream=[(0, 2.5, 8, 0)]),
                 dict(name="RockWisp", texture="kk_smoke_04", direction="Top", spread=(15, 15), speed=(4, 9),
                      drag=1.2, accel=(0, 5, 0), lifetime=(1.0, 1.4), size=[(0, 2, 0.6), (1, 7, 2)],
                      transparency=[(0, 0.6), (0.3, 0.5), (1, 1)], color=ASH, rotation=(0, 360),
                      stream=[(0.1, 2.6, 2.5, 0.5)]),
             ]),
        # la lluvia de magma deja salpicaduras encendidas alrededor
        dict(name="RainSplats", texture="kz_lava_splat", points=splat_points(g), lifetime=(3.4, 3.4),
             size=[(0, 2), (0.04, 9), (1, 10)], transparency=[(0, 0), (0.8, 0.2), (1, 1)], color=SPLAT,
             light_emission=1.0, rotation=(0, 360), **DECAL),
        # ---------------- brasas y chispas ----------------
        dict(name="Embers", texture="kk_flare_01", emit=[(0.05, 40), (0.3, 30), (0.6, 22), (1.0, 14)],
             offset=(0, 10, 0), shape={"type": "Sphere", "radius": 14.0}, direction="Top", spread=(120, 120),
             speed=(10, 35), drag=1.5, accel=(0, 14, 0), lifetime=(0.9, 1.5),
             size=[(0, 0), (0.1, 2.6, 0.8), (1, 0)], color=EMBER, light_emission=1.0, brightness=1.7),
        dict(name="Sparks", texture="fx_line", orientation="VelocityParallel", offset=(0, 6, 0),
             emit=[(0.0, 22), (0.06, 10)], direction="Top", spread=(180, 180), speed=(110, 200), drag=4,
             accel=(0, -60, 0), lifetime=(0.3, 0.5), size=[(0, 16, 4), (1, 5)],
             color=[(0, (255, 220, 130)), (0.5, (255, 160, 50)), (1, (240, 90, 20))], light_emission=1.0,
             brightness=1.5),
    ] + lava_clusters()
    return {
        "name": "GiantExplosion",
        "doc": ("Explosión GIGANTE DE LAVA: el suelo se abre en grietas de magma, brota un charco de lava, una fuente "
                "de magma llueve gotas que se enfrían y salpican, vuelan rocas fundidas (CrackedLava) que gotean lava, "
                "sube humo volcánico y la lava queda viva en el suelo 5 s. Cierra limpio: lo último se apaga a los 6.9 s."),
        "duration": 5.8,
        "light": {"color": (255, 130, 45), "brightness": 6, "range": 60, "time": 1.4},
        "layers": layers,
    }


LAVA_EXPLOSION = lava_explosion_spec()

# en la Ignition, el núcleo de magma nace blanco y pasa a rojo (como el amarillo-blanco de la normal)
IGNITION_CORE = {
    "MagmaCore": [(0, (255, 242, 242)), (0.35, (255, 172, 178)), (1, (220, 40, 60))],
    "MagmaBurst": [(0, (255, 246, 246)), (0.2, (255, 202, 206)), (0.45, (255, 96, 110)), (0.75, (220, 36, 56)),
                   (1, (170, 20, 40))],
}

