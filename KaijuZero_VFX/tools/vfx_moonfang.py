"""MOONFANG — lobo kaiju lunar de cristal. VFX de su kit completo.

Identidad: luz de luna FRÍA (plata y blanco), hielo y azul cristal, esquirlas afiladas, medias lunas y destellos de
estrella. Formas cortantes y brillantes (Omnívora, en cambio, es nebulosa suave, púrpura y agujeros negros).

  M1        MoonBite (mordiscos 1-3) y MoonBiteFinisher (mordisco 4): mordiscos de energía sobre el rival
  BLOQUEO   MoonGuard (aura mientras bloquea) y MoonGuardHit (cada golpe bloqueado)
  PESADO    MoonFang: mordida lunar; brotan cristales de la herida y estallan
  SKILL 1   CrescentWave "Medialuna": una media luna de energía vuela de canto, corta el suelo y detona en hielo
  SKILL 2   IceWave "Ola de hielo": una ola de hielo se abre en triángulo y deja bloques de hielo, destrucción y humo
  SKILL 3   LunarHowl "Aullido lunar" (el aullido y la luna llena) + LunarAura (la mejora)
  SKILL 4   Eclipse: una luna se eclipsa sobre la zona y cae una columna de luz de luna
Los golpes sobre el rival usan el marco de playHit (X = derecha de la pantalla, Y = arriba, +Z hacia la cámara;
tamaño 1 = rival de 22 studs). Las demás se escalan con `scale`.
"""
import math
import random

import vfx_aura as AU
from vfx_omnivora import scatter, center, ring

STATIC2x2 = ("Grid2x2", "Random", 0, True)
ONESHOT = ("Grid4x4", "OneShot", 30, False)
DECAL = dict(decal=True, orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))
UP = "FacingCameraWorldUp"

# ----------------------------------------------------------------------------- colores
WHITE = [(0, (255, 255, 255)), (1, (235, 244, 255))]
SILVER = [(0, (255, 255, 255)), (0.5, (220, 232, 255)), (1, (165, 195, 250))]
ICE = [(0, (230, 245, 255)), (0.5, (155, 210, 255)), (1, (85, 145, 245))]
CRYST = [(0, (110, 170, 255)), (0.5, (60, 115, 240)), (1, (30, 60, 190))]
DEEP = [(0, (70, 110, 230)), (0.5, (40, 70, 180)), (1, (20, 36, 120))]
GLINT = [(0, (255, 255, 255)), (0.5, (225, 240, 255)), (1, (170, 205, 255))]
SHARD = [(0, (200, 230, 255)), (0.4, (120, 180, 255)), (1, (70, 120, 235))]
MIST = [(0, (215, 228, 248)), (1, (175, 190, 222))]
NIGHT = [(0, (14, 18, 44)), (1, (22, 28, 62))]
MOONC = [(0, (255, 255, 255)), (1, (235, 242, 255))]
SHADOW = [(0, (6, 8, 22)), (1, (6, 8, 22))]                 # el disco que eclipsa la luna
FROST = [(0, (120, 185, 255)), (0.15, (225, 242, 255)), (0.35, (130, 190, 255)), (1, (40, 80, 200))]
CRYSTAL_RGB = (150, 200, 255)                                # las piezas de cristal (Parts de material Ice)


def twinkle(k):
    return [(t, round(v * k, 3)) for t, v in [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2),
                                              (0.72, 2.8), (1, 0)]]


# ----------------------------------------------------------------------------- piezas comunes de los golpes
def impact(t, flash=18, ring_=34, glow=1.0, name="Hit"):
    """Destello, estrella y anillo del golpe (miran a la cámara)."""
    return [
        dict(name=f"{name}Flash", texture="fx_glow", emit=[(t, 1)], lifetime=(0.16, 0.18),
             size=[(0, 6), (0.3, flash), (1, flash * 1.1)], transparency=[(0, 1 - 0.75 * glow), (1, 1)], color=ICE,
             light_emission=1.0, brightness=0.9 * glow, zoffset=6),
        dict(name=f"{name}Star", texture="kk_star_06", emit=[(t, 1)], lifetime=(0.14, 0.14),
             size=[(0, 10), (0.4, flash * 0.95), (1, flash * 0.6)], transparency=[(0, 1 - glow), (1, 1)],
             color=GLINT, light_emission=1.0, brightness=1.6 * glow, rotation=(0, 360), zoffset=7),
        dict(name=f"{name}Ring", texture="kz_beam_ring", emit=[(t, 1)], lifetime=(0.22, 0.24),
             size=[(0, 6), (1, ring_)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=CRYST,
             light_emission=1.0, brightness=1.4, rotation=(0, 360), zoffset=3),
    ]


def shards(t, n, box, speed=(25, 55), size=1.4, name="Shards", direction="Back", spread=(70, 70)):
    """Esquirlas de cristal que salen volando, giran y caen."""
    return [dict(name=name, texture="mf_shard_2x2", flipbook=STATIC2x2, shape={"type": "Box", "size": box},
                 emit=[(t, n)], direction=direction, spread=spread, speed=speed, drag=0.6, accel=(0, -90, 0),
                 lifetime=(0.4, 0.7), size=[(0, size, size * 0.35), (1, size * 0.7, size * 0.25)],
                 transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
                 rotation=(0, 360), rot_speed=(-500, 500))]


def side_sparks(t, box, n=(14, 6), dirs=("Right", "Left"), name="Sparks"):
    return [dict(name=f"{name}{d}", texture="kk_trace_01", orientation="VelocityParallel",
                 shape={"type": "Box", "size": box}, direction=d, spread=(25, 35), speed=(70, 140), drag=5,
                 accel=(0, -40, 0), lifetime=(0.16, 0.3), emit=[(t - 0.01, n[0]), (t + 0.02, n[1])],
                 size=[(0, 6, 1.5), (1, 2)], color=ICE, light_emission=1.0, brightness=2.0) for d in dirs]


def glints(t, n, box, k=1.2, name="Glints", life=(0.35, 0.6)):
    return [dict(name=name, texture="kk_star_06", shape={"type": "Box", "size": box}, emit=[(t, n)],
                 direction="Back", spread=(80, 80), speed=(2, 8), drag=2, lifetime=life, size=twinkle(k),
                 color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45))]


def mist(t, n, box, name="Mist", size=(4, 11)):
    return [dict(name=name, texture="kk_smoke_04", shape={"type": "Box", "size": box}, emit=[(t, n)],
                 direction="Back", spread=(60, 60), speed=(3, 9), drag=2, accel=(0, 3, 0), lifetime=(0.45, 0.7),
                 size=[(0, size[0], 1), (1, size[1], 2)], transparency=[(0, 0.62), (0.3, 0.58), (1, 1)], color=MIST,
                 rotation=(0, 360), rot_speed=(-40, 40), zoffset=-2)]


def chomp(t, size, name="Chomp", bright=1.4, tr0=0.0, life=0.4):
    """El mordisco (flipbook que mira a la cámara): SOLO los colmillos de cristal, sin encía. Las dos filas se cierran
    y se traban a los t + life·4/16 s, se quedan clavadas un instante y se rompen; un resplandor suave detrás."""
    snap = t + life * 4 / 16
    return [
        dict(name=name, texture="mf_chomp_4x4", flipbook=ONESHOT, emit=[(t, 1)], lifetime=(life, life),
             size=[(0, size), (1, size * 1.04)], transparency=[(0, tr0), (0.8, tr0), (1, 1)],
             color=[(0, (215, 235, 255)), (0.3, (255, 255, 255)), (0.6, (170, 210, 255)), (1, (120, 175, 255))],
             light_emission=0.8, brightness=bright, zoffset=5),
        dict(name=f"{name}Glow", texture="fx_glow", emit=[(snap, 1)], lifetime=(0.24, 0.24),
             size=[(0, size * 0.4), (0.3, size * 0.75), (1, size * 0.85)], transparency=[(0, 0.7), (1, 1)],
             color=CRYST, light_emission=1.0, brightness=0.8, zoffset=-1),
    ]


def breath(t, n, box, name="Breath", size=(3, 10)):
    """Vaho helado que sale de la mordida (hacia los lados y hacia la cámara)."""
    return [dict(name=name, texture="fx_fog2001", shape={"type": "Box", "size": box}, emit=[(t, n)],
                 direction="Back", spread=(80, 40), speed=(8, 22), drag=3, accel=(0, 2, 0), lifetime=(0.5, 0.8),
                 size=[(0, size[0], 1), (1, size[1], 2)], transparency=[(0, 0.5), (0.3, 0.55), (1, 1)],
                 color=[(0, (225, 240, 255)), (1, (185, 210, 245))], light_emission=0.2, rotation=(0, 360),
                 rot_speed=(-60, 60), zoffset=-1)]


def frostbite(t, box, wound=14, drips=(14, 6), dur=1.0, name="Frostbite"):
    """La herida de escarcha que deja la mordida (como el sangrado de Primal Bite): grietas de hielo que se abren y
    cristalitos que gotean un rato."""
    return [
        dict(name=f"{name}Wound", texture="mf_frost_cracks", emit=[(t, 1)], lifetime=(dur, dur),
             size=[(0, wound * 0.3), (0.08, wound), (1, wound * 1.05)],
             transparency=[(0, 0), (0.4, 0.15), (0.8, 0.5), (1, 1)], color=FROST, light_emission=0.9,
             brightness=1.2, rotation=(0, 360), zoffset=2),
        dict(name=f"{name}Drip", texture="fx_spark002", shape={"type": "Box", "size": box},
             stream=[(t + 0.05, t + dur, drips[0], drips[1])], direction="Bottom", spread=(25, 25), speed=(2, 6),
             accel=(0, -45, 0), lifetime=(0.4, 0.7), size=twinkle(0.45), color=GLINT, light_emission=1.0,
             brightness=1.8, rotation=(0, 45)),
    ]


CHOMPBOX = (18, 2, 1)       # la línea donde se juntan las dos medias lunas

# ----------------------------------------------------------------------------- M1: mordiscos 1-3
# Mordiscos de energía, sin mandíbulas ni dientes: dos medias lunas de luz (arriba y abajo) se cierran de golpe sobre
# el rival como una boca que muerde, con su barrido; chasquean en una línea que destella y de la mordida salen chispas
# de hielo hacia los lados, esquirlas, vaho helado y destellos. Deja una herida de escarcha que gotea cristalitos
# (como el sangrado del Primal Bite de Devil Dinosaur). El 4.º es una embestida más fuerte (como el quinto mordisco
# de su Frenzied Feast).
T_BITE1 = 0.4 * 4 / 16       # los colmillos se traban
MOON_BITE = {
    "name": "MoonBite",
    "doc": ("MOONFANG M1 (mordiscos 1 a 3): dos filas de colmillos de cristal (solo los dientes, sin encía) se "
            "cierran de golpe sobre el rival y quedan trabadas; sueltan chispas de hielo, esquirlas y vaho helado, "
            "los colmillos se rompen y queda una herida de escarcha que gotea cristalitos un segundo."),
    "duration": 1.3,
    "hit": {"lift": 3, "ref": 22, "angle": 0, "angled": False, "impact": round(T_BITE1, 3)},
    "light": {"color": (170, 210, 255), "brightness": 3, "range": 22, "time": 0.25, "delay": round(T_BITE1, 3)},
    "shakes": [(round(T_BITE1, 3), 0.4, 0.2)],
    "layers": chomp(0.0, 26) + impact(T_BITE1, flash=10, ring_=30, glow=0.45)
    + side_sparks(T_BITE1, CHOMPBOX, n=(12, 6)) + shards(T_BITE1 + 0.12, 10, CHOMPBOX, speed=(25, 55), size=1.3)
    + breath(T_BITE1 + 0.01, 4, CHOMPBOX) + frostbite(T_BITE1 + 0.14, CHOMPBOX)
    + glints(T_BITE1 + 0.03, 6, (18, 8, 2)),
}

# ----------------------------------------------------------------------------- M1: mordisco 4 (remate)
T_FIN = 0.03 + 0.44 * 4 / 16  # los colmillos se traban
MOON_BITE_FINISHER = {
    "name": "MoonBiteFinisher",
    "doc": ("MOONFANG M1 (mordisco 4, remate): una embestida; líneas de velocidad se cierran sobre el rival y dos "
            "filas de colmillos más grandes (con su eco) se traban de golpe, se rompen y revientan en una flor de "
            "púas de hielo, esquirlas y vaho helado; deja una herida de escarcha más grande."),
    "duration": 1.6,
    "hit": {"lift": 3, "ref": 22, "angle": 0, "angled": False, "impact": round(T_FIN, 3)},
    "light": {"color": (180, 215, 255), "brightness": 5, "range": 28, "time": 0.35, "delay": round(T_FIN, 3)},
    "shakes": [(0.02, 0.25, 0.12), (round(T_FIN, 3), 0.8, 0.3)],
    "layers": [
        # la embestida: líneas de velocidad que se cierran sobre el rival
        dict(name="LungeLines", texture="kk_trace_03", orientation="VelocityParallel",
             shape={"type": "Sphere", "radius": 18, "style": "Surface", "inout": "Inward"}, emit=[(0.0, 14), (0.04, 8)],
             speed=(150, 200), lifetime=(0.09, 0.11), size=[(0, 9, 2), (1, 4)], transparency=[(0, 0.3), (1, 1)],
             color=ICE, light_emission=1.0, brightness=1.4),
    ]
    + chomp(0.03, 34, bright=1.5, life=0.44) + chomp(0.045, 42, name="ChompEcho", bright=1.0, tr0=0.7, life=0.44)
    + impact(T_FIN, flash=14, ring_=52, glow=0.5)
    + [dict(name="SnapStar", texture="kk_star_08", emit=[(T_FIN, 1)], lifetime=(0.2, 0.2),
            size=[(0, 8), (0.3, 28), (1, 14)], transparency=[(0, 0.45), (1, 1)], color=GLINT, light_emission=1.0,
            brightness=1.2, rotation=(0, 0), zoffset=7),
       dict(name="CrystalRing", texture="kk_circle_02", emit=[(T_FIN + 0.02, 1)], lifetime=(0.32, 0.32),
            size=[(0, 10), (1, 58)], transparency=[(0, 0.15), (0.6, 0.5), (1, 1)], color=ICE, light_emission=1.0,
            brightness=1.2, zoffset=2),
       # la flor de púas de hielo que revienta de la mordida
       dict(name="IceBloom", texture="mf_spike", orientation="VelocityParallel",
            shape={"type": "Sphere", "radius": 1.5}, emit=[(T_FIN + 0.12, 12)], direction="Back", spread=(180, 180),
            speed=(40, 70), drag=10, lifetime=(0.45, 0.6), size=[(0, 1), (0.15, 7, 1.5), (0.8, 7.5, 1.5), (1, 0)],
            transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.5, brightness=1.6, zoffset=4)]
    + side_sparks(T_FIN, (22, 2, 1), n=(18, 8)) + side_sparks(T_FIN, (22, 2, 1), n=(8, 4), dirs=("Top", "Bottom"),
                                                               name="SparksV")
    + shards(T_FIN + 0.12, 24, (22, 4, 1), speed=(35, 75), size=1.7) + breath(T_FIN + 0.01, 7, (22, 3, 1), size=(4, 13))
    + frostbite(T_FIN + 0.15, (22, 2, 1), wound=20, drips=(20, 8), dur=1.3)
    + glints(T_FIN + 0.02, 10, (24, 12, 2), k=1.4),
}

# ----------------------------------------------------------------------------- PESADO: mordida lunar
T_BITE = 0.14
T_SHATTER = 0.62
BITE_LINE = (18, 2, 1)
MOON_FANG = {
    "name": "MoonFang",
    "doc": ("MOONFANG PESADO (Colmillo lunar): unas mandíbulas de luz plateada se cierran de golpe sobre el rival; de "
            "la mordida brotan cristales que crecen y a los 0.62 s estallan en pedazos, con dos ondas de media luna."),
    "duration": 1.1,
    "hit": {"lift": 3, "ref": 22, "angle": 0, "angled": False, "impact": T_BITE},
    "light": {"color": (170, 210, 255), "brightness": 5, "range": 30, "time": 0.4, "delay": T_BITE},
    "shakes": [(T_BITE, 0.85, 0.3), (T_SHATTER, 0.5, 0.22)],
    "layers": [
        dict(name="Jaws", texture="kz_bite_4x4", flipbook=ONESHOT, emit=[(0.0, 1)], lifetime=(0.36, 0.36),
             size=[(0, 27), (1, 28)], transparency=[(0, 0.5), (0.06, 0), (0.62, 0), (1, 1)], color=SILVER,
             light_emission=0.3, brightness=1.3, zoffset=5),
        dict(name="JawGlow", texture="fx_glow", emit=[(0.08, 1)], lifetime=(0.3, 0.3), size=[(0, 18), (1, 30)],
             transparency=[(0, 0.55), (1, 1)], color=CRYST, light_emission=1.0, brightness=0.9, zoffset=4),
        # los cristales brotan de la mordida, se quedan y estallan
        dict(name="SpikesUp", texture="mf_spike",
             orientation="VelocityParallel", shape={"type": "Box", "size": BITE_LINE}, emit=[(T_BITE + 0.01, 7)],
             direction="Top", spread=(40, 10), speed=(30, 55), drag=12, lifetime=(T_SHATTER - T_BITE, T_SHATTER - T_BITE),
             size=[(0, 1), (0.2, 8, 2), (0.85, 8.6, 2), (1, 8.8, 2)], transparency=[(0, 0), (0.92, 0), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.6, zoffset=4.5),
        dict(name="SpikesDown", texture="mf_spike",
             orientation="VelocityParallel", shape={"type": "Box", "size": BITE_LINE}, emit=[(T_BITE + 0.02, 6)],
             direction="Bottom", spread=(40, 10), speed=(25, 45), drag=12,
             lifetime=(T_SHATTER - T_BITE - 0.01, T_SHATTER - T_BITE - 0.01),
             size=[(0, 1), (0.2, 6.5, 1.5), (0.85, 7, 1.5), (1, 7.2, 1.5)], transparency=[(0, 0), (0.92, 0), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.6, zoffset=4.5),
        # dos ondas de media luna, una a cada lado
        dict(name="CrescentL", texture="mf_crescent", emit=[(T_BITE, 1)], lifetime=(0.22, 0.22),
             size=[(0, 10), (1, 36)], transparency=[(0, 0.2), (0.5, 0.6), (1, 1)], color=ICE, light_emission=1.0,
             brightness=1.2, rotation=(0, 0), zoffset=3),
        dict(name="CrescentR", texture="mf_crescent", emit=[(T_BITE, 1)], lifetime=(0.22, 0.22),
             size=[(0, 10), (1, 36)], transparency=[(0, 0.2), (0.5, 0.6), (1, 1)], color=ICE, light_emission=1.0,
             brightness=1.2, rotation=(180, 180), zoffset=3),
        # el estallido de los cristales
        dict(name="ShatterFlash", texture="fx_glow", emit=[(T_SHATTER, 1)], lifetime=(0.14, 0.16),
             size=[(0, 10), (0.3, 26), (1, 28)], transparency=[(0, 0.35), (1, 1)], color=ICE, light_emission=1.0,
             brightness=1.0, zoffset=6),
        dict(name="ShatterStar", texture="kk_star_08", emit=[(T_SHATTER, 1)], lifetime=(0.2, 0.2),
             size=[(0, 10), (0.3, 36), (1, 18)], transparency=[(0, 0.1), (1, 1)], color=GLINT, light_emission=1.0,
             brightness=1.3, rotation=(0, 90), zoffset=7),
    ]
    + impact(T_BITE, flash=24, ring_=46, glow=0.7)
    + side_sparks(T_BITE, BITE_LINE, n=(12, 6))
    + shards(T_SHATTER, 30, (16, 14, 2), speed=(35, 80), size=1.8, name="ShatterShards", spread=(85, 85))
    + glints(T_SHATTER + 0.02, 12, (22, 18, 2), k=1.4, name="ShatterGlints")
    + mist(T_BITE + 0.01, 3, (12, 6, 1)) + mist(T_SHATTER + 0.01, 5, (16, 14, 1), name="ShatterMist", size=(5, 13)),
}

# ----------------------------------------------------------------------------- BLOQUEO: cada golpe bloqueado
T_GUARD = 0.02
MOON_GUARD_HIT = {
    "name": "MoonGuardHit",
    "doc": ("MOONFANG BLOQUEO (cada golpe bloqueado): una media luna de luz aparece como escudo delante de él, con "
            "esquirlas que rebotan a los lados, una onda y destellos. target = Moonfang."),
    "duration": 0.5,
    "hit": {"lift": 5, "ref": 22, "angle": 0, "angled": False, "impact": T_GUARD},
    "light": {"color": (170, 210, 255), "brightness": 2.5, "range": 20, "time": 0.2, "delay": T_GUARD},
    "shakes": [(T_GUARD, 0.3, 0.15)],
    "layers": [
        dict(name="Shield", texture="mf_crescent", emit=[(0.0, 1)], lifetime=(0.28, 0.28),
             size=[(0, 22), (0.2, 30), (1, 32)], transparency=[(0, 0.1), (0.5, 0.35), (1, 1)], color=SILVER,
             light_emission=1.0, brightness=1.15, rotation=(180, 180), zoffset=5),
        dict(name="ShieldGlow", texture="fx_glow", emit=[(0.0, 1)], lifetime=(0.24, 0.24), size=[(0, 26), (1, 34)],
             transparency=[(0, 0.55), (1, 1)], color=CRYST, light_emission=1.0, brightness=0.8, zoffset=4),
        dict(name="Ripple", texture="kz_beam_ring", emit=[(T_GUARD, 1)], lifetime=(0.22, 0.22),
             size=[(0, 8), (1, 36)], transparency=[(0, 0.2), (0.6, 0.55), (1, 1)], color=ICE, light_emission=1.0,
             brightness=1.3, zoffset=3),
        dict(name="GuardStar", texture="kk_star_06", emit=[(T_GUARD, 1)], lifetime=(0.12, 0.12),
             size=[(0, 8), (0.4, 18), (1, 10)], color=GLINT, light_emission=1.0, brightness=1.5, rotation=(0, 360),
             zoffset=7),
    ]
    + side_sparks(T_GUARD, (6, 20, 1), n=(12, 6), name="Ricochet")
    + shards(T_GUARD, 10, (6, 20, 1), speed=(30, 60), size=1.2, direction="Right", spread=(60, 40), name="ShardsR")
    + shards(T_GUARD, 10, (6, 20, 1), speed=(30, 60), size=1.2, direction="Left", spread=(60, 40), name="ShardsL")
    + glints(T_GUARD + 0.02, 6, (16, 24, 2)),
}

# ----------------------------------------------------------------------------- BLOQUEO (aura) y SKILL 3 (aura)
GUARD = {"wisp": "mf_aura_wisp_2x2", "wisp_le": 0.55, "tongue": ICE, "tongue2": CRYST, "star": GLINT,
         "star_up": 3, "mote": [(0, (255, 255, 255)), (1, (170, 210, 255))], "bolt": ICE, "halo": DEEP,
         "streak": ICE, "ring": CRYST}
LUNAR = {"wisp": "mf_aura_wisp_2x2", "wisp_le": 0.65, "tongue": SILVER, "tongue2": ICE, "star": GLINT,
         "star_up": 6, "mote": [(0, (255, 255, 255)), (1, (220, 235, 255))], "bolt": SILVER, "halo": CRYST,
         "streak": SILVER, "ring": ICE}


def guard_layers():
    L = AU.layers(GUARD)
    for x in L:                     # la guardia es más quieta: menos partículas y sin estelas disparadas
        if x["name"] in ("AuraStreaks", "AuraBolts"):
            x["rate"] = round(x.get("rate", 0) * 0.3, 2)
    L.append(dict(name="GuardShards", aura="body", box=(1.1, 0.9, 1.1), texture="mf_shard_2x2", flipbook=STATIC2x2,
                  direction="Top", spread=(180, 180), speed=(1, 3), drag=1, lifetime=(0.9, 1.4),
                  size=[(0, 0), (0.2, 1.1, 0.3), (0.8, 1.0, 0.3), (1, 0)], color=SHARD, light_emission=0.6,
                  brightness=1.5, rotation=(0, 360), rot_speed=(-90, 90), rate=14, surge=6))
    return L


def lunar_layers():
    L = AU.layers(LUNAR)
    L.append(dict(name="MoonGlints", aura="body", box=(1.2, 1.0, 1.2), texture="kk_star_06", direction="Top",
                  spread=(30, 30), speed=(2, 5), lifetime=(0.6, 1.0), size=twinkle(0.5), color=GLINT,
                  light_emission=1.0, brightness=2.0, rotation=(0, 45), rate=18, surge=12))
    L.append(dict(name="MoonCrescents", aura="body", box=(1.0, 0.8, 1.0), texture="mf_crescent", orientation=UP,
                  direction="Top", spread=(10, 10), speed=(4, 8), lifetime=(0.6, 0.9),
                  size=[(0, 1.5), (0.3, 3.5), (1, 4.5)], transparency=[(0, 1), (0.25, 0.45), (1, 1)], color=SILVER,
                  light_emission=1.0, brightness=1.3, rotation=(-20, 20), rate=4, surge=4))
    return L


MOON_GUARD = {
    "name": "MoonGuard",
    "doc": ("MOONFANG BLOQUEO (mientras mantiene el bloqueo): aura de escarcha que delinea todo su cuerpo en hielo y "
            "plata, con esquirlas de cristal que flotan a su alrededor. Enciéndela al bloquear y apágala con :Stop() "
            "al soltar."),
    "duration": 0,
    "aura": dict(AU.aura_cfg([(150, 205, 255), (240, 248, 255)], (30, 60, 150), (150, 200, 255)),
                 fade_in=0.15, fade_out=0.25, surge=1.6),
    "layers": guard_layers(),
}

LUNAR_AURA = {
    "name": "LunarAura",
    "doc": ("MOONFANG SKILL 3 (la mejora del Aullido lunar): aura de luz de luna plateada que respira hacia el hielo, "
            "con medias lunas pequeñas, estrellas y destellos que suben."),
    "duration": 0,
    "aura": AU.aura_cfg([(230, 240, 255), (130, 185, 255)], (40, 70, 160), (190, 220, 255)),
    "layers": lunar_layers(),
}

# ----------------------------------------------------------------------------- SKILL 1: Medialuna
# Una media luna de energía (geometría: trazos finos de Beams) que vuela VERTICAL y DE CANTO: de lado se ve la media
# luna con la punta hacia adelante; desde atrás (la cámara del jugador) se ve una hoja fina que apunta hacia donde va.
# El filo de afuera es blanco y duro; hacia adentro el cuerpo pasa a celeste y azul y se desvanece. Mientras vuela
# suelta una estela de humo frío, brillos y esquirlas. Su cuerno de abajo corta el suelo: se abre una grieta con
# escarcha, las losas del suelo saltan inclinadas a los dos lados y salen rocas (bloques) que caen y se quedan en el
# camino. Al llegar al final detona en hielo y deja un cráter de losas.
LW = 130.0                 # largo por defecto (escala 1)
T0 = 0.14                  # sale del zarpazo
TW = 0.62                  # tarda en recorrer la línea (la punta llega al final a los T0 + TW s)
TD = T0 + TW               # detona
SLAB_RGB = (96, 94, 104)   # color de las losas y rocas en la vista previa (en Roblox, el del suelo)


def blade_strands():
    """Los trazos de la hoja: j = 0 el filo de afuera .. 1 el borde de adentro (más corto, más azul, más tenue)."""
    out = [{"name": "BladeHalo", "j": 0.3, "arc_k": 0.94, "width": 6.0, "texture": "mf_blade_glow",
            "transparency": 0.62, "color": [(0, (40, 80, 210)), (0.5, (80, 140, 255)), (1, (40, 80, 210))],
            "light_emission": 1.0, "brightness": 1.0, "zoffset": -1}]
    #       j     ancho  largo  color             brillo transp.
    tbl = [(0.00, 0.8, 1.00, (255, 255, 255), 3.0, 0.0),        # el filo: blanco y duro
           (0.09, 1.3, 0.98, (225, 243, 255), 2.2, 0.0),
           (0.19, 1.8, 0.95, (170, 222, 255), 1.7, 0.04),
           (0.31, 2.2, 0.90, (120, 195, 255), 1.4, 0.12),
           (0.44, 2.4, 0.84, (90, 165, 255), 1.25, 0.22),
           (0.58, 2.4, 0.77, (70, 135, 245), 1.1, 0.34),
           (0.72, 2.2, 0.69, (55, 110, 235), 1.0, 0.46),
           (0.86, 1.9, 0.60, (45, 90, 220), 1.0, 0.58),
           (1.00, 1.5, 0.50, (40, 75, 200), 1.0, 0.7)]
    for i, (j, w, ak, c, br, tr) in enumerate(tbl):
        dark = tuple(int(v * 0.8) for v in c)
        out.append({"name": f"BladeStrand{i}", "j": j, "arc_k": ak, "width": w,
                    "texture": "mf_blade_line" if i < 2 else "mf_blade_solid", "transparency": tr,
                    "color": [(0, dark), (0.5, c), (1, dark)], "light_emission": 1.0, "brightness": br,
                    "zoffset": 3 - i * 0.4})
    return out


BLADE = {
    "t0": T0, "travel": TW, "fade": 0.12, "grow": 0.1, "start_k": 0.4,
    "radius": 18.0, "arc": 72.0, "tilt": 6.0, "thick": 0.3, "shrink": 0.1, "lift": 0.5, "n": 25, "taper": 0.7,
    "strands": blade_strands(),
    "light": {"color": (170, 210, 255), "brightness": 6, "range": 40, "flash": 14, "flash_time": 0.3},
    # la estela que suelta mientras vuela (emisores pegados a la hoja: at = dónde, de un cuerno al otro)
    "emitters": [
        dict(name="TrailMist", at=[0.12, 0.25, 0.4, 0.55], j=0.45, rate=36, texture="fx_fog2001",
             direction="Back", spread=(60, 60), speed=(1, 4), drag=2, accel=(0, -1.5, 0), lifetime=(0.9, 1.4),
             size=[(0, 6, 1), (0.4, 13, 2), (1, 18, 3)], transparency=[(0, 0.78), (0.3, 0.8), (1, 1)],
             color=[(0, (225, 240, 255)), (1, (190, 215, 250))], light_emission=0.15, rotation=(0, 360),
             rot_speed=(-40, 40), zoffset=-3),
        dict(name="TrailGlitter", at=[0.1, 0.3, 0.5, 0.7, 0.9], j=0.2, rate=30, texture="fx_spark002",
             direction="Back", spread=(180, 180), speed=(1, 4), drag=1, accel=(0, -2, 0), lifetime=(0.5, 0.9),
             size=None, color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45)),
        dict(name="TrailShards", at=[0.25, 0.5, 0.75], j=0.4, rate=18, texture="mf_shard_2x2", flipbook=STATIC2x2,
             direction="Back", spread=(50, 50), speed=(6, 14), drag=0.6, accel=(0, -110, 0), lifetime=(0.5, 0.8),
             size=[(0, 0.9, 0.3), (1, 0.5, 0.2)], transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD,
             light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500)),
        dict(name="TrailWind", at=[0.15, 0.4, 0.6, 0.85], j=0.1, rate=24, texture="kk_trace_03",
             orientation="VelocityParallel", direction="Back", spread=(6, 6), speed=(60, 90), drag=4,
             lifetime=(0.15, 0.25), size=[(0, 5, 1), (1, 2)], transparency=[(0, 0.35), (1, 1)], color=ICE,
             light_emission=1.0, brightness=1.6),
        dict(name="TipGlint", at=[0.5], j=0.0, rate=50, texture="kk_star_06", lifetime=(0.08, 0.12),
             size=[(0, 0), (0.25, 7, 1.5), (1, 0)], color=GLINT, light_emission=1.0, brightness=2.5,
             rotation=(0, 45)),
    ],
    # el corte: una grieta oscura con una veta de hielo al fondo y escarcha alrededor (tramos de `seg` studs)
    "gash": {"seg": 10.0, "start": 4.0, "life": 1.9, "fade": 0.5, "cool": 0.3, "spread": 0.25, "open": 0.06,
             "seam": {"width": 0.6, "height": 0.22, "hot": (220, 240, 255), "cold": (80, 150, 255), "neon_k": 1.5,
                      "transparency": 0.25},
             "crevice": {"width": 2.6, "height": 0.15, "color": (12, 14, 28)},
             "frost": {"texture": "mf_frost_patch", "width": 11, "overlap": 2.5, "color": (180, 220, 255),
                       "light_emission": 0.4, "transparency": 0.35}},
    # las losas del suelo: saltan inclinadas a los dos lados del corte cuando pasa, se quedan y se hunden
    "slabs": {"spacing": 2.3, "start": 6.0, "gap": 1.0, "wid": (1.6, 2.8), "thick": (0.5, 1.0), "len": (1.4, 2.6),
              "tilt": (18, 44), "yaw": 16, "pitch": 10, "show": 0.62, "rise": 0.08, "hold": (1.6, 2.1),
              "sink": 0.5, "delay": 0.04, "seed": 5,
              # algunas son de hielo: el corte congela el suelo y saltan placas de hielo entre las de tierra
              "ice": {"frac": 0.3, "wid": (1.8, 3.0), "thick": (0.45, 0.8), "len": (0.8, 1.5), "tilt": (50, 72),
                      "color": CRYSTAL_RGB, "material": "Ice", "transparency": 0.15, "mesh": "IceSlab"}},
    # el cráter de la detonación
    "crater": {"count": 20, "radius": 10.0, "wid": (2.2, 4.0), "thick": (0.8, 1.4), "len": (2.0, 3.6),
               "tilt": (30, 58), "yaw": 12, "pitch": 10, "show": 0.6, "rise": 0.1, "hold": (1.9, 2.4), "sink": 0.6,
               "at": 0.0, "delay": 0.05, "seed": 6},
    "slab_color": SLAB_RGB,
}
BLADE["emitters"][1]["size"] = twinkle(0.5)


def _blade_low(B):
    """El punto más bajo de la hoja (por unidad de radio): (lado, cuánto va detrás de la punta)."""
    arc, tl = math.radians(B["arc"]), math.radians(B["tilt"])
    best = (0.0, 0.0, 0.0)
    for S_ in B["strands"]:
        a = arc * S_.get("arc_k", 1.0)
        Rj = 1 - B["shrink"] * S_["j"]
        for i in range(B["n"]):
            th = -a + 2 * a * i / (B["n"] - 1)
            y = Rj * math.sin(th) * math.cos(tl)
            if y < best[0]:
                best = (y, Rj * math.sin(th) * math.sin(tl), B["thick"] * S_["j"] + Rj * (1 - math.cos(th)))
    return best[1], best[2]


_lx, _lz = _blade_low(BLADE)
CUT_SIDE = _lx * BLADE["radius"]           # el corte va corrido hacia un lado (studs a escala 1)
CUT_LAG = _lz * BLADE["radius"] / LW       # y detrás de la punta (en fracción del largo)
NP = 26                                    # puntos a lo largo del camino


def path(t0, n, per, up=0.0, side=0.0, jitter=0.0, seed=1, u0=0.03, u1=0.97, lag=0.0, jitter_up=0.0):
    """Eventos (t, n, u, lado, alto) a lo largo del camino, cuando pasa la hoja (lag = cuánto va detrás)."""
    g = random.Random(seed)
    out = []
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1)
        out.append((round(t0 + TW * min(u + lag, 1.0), 3), per, round(u, 3), round(side + g.uniform(-jitter, jitter), 2),
                    round(up + g.uniform(-jitter_up, jitter_up), 2)))
    return out


def cut(n, per, seed, jitter=1.5, up=0.2, u0=0.05, u1=0.88, side=0.0, delay=0.0):
    """En el corte del suelo (donde pasa el cuerno de abajo)."""
    return path(T0 + delay, n, per, up=up, side=CUT_SIDE + side, jitter=jitter, seed=seed, u0=u0, u1=u1, lag=CUT_LAG)


FROSTMIST = [(0, (220, 236, 255)), (1, (175, 200, 240))]
SNOW = [(0, (240, 246, 255)), (1, (205, 218, 240))]
ROCK_LAND = [dict(name="RockPuff", texture="kk_smoke_04", emit=[(0, 2)], direction="Top", spread=(70, 70),
                  speed=(4, 10), drag=2, accel=(0, 3, 0), lifetime=(0.5, 0.8), size=[(0, 3, 1), (1, 8, 2)],
                  transparency=[(0, 0.5), (0.4, 0.6), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2)]
ROCK_CRUMBLE = [dict(name="RockCrumble", texture="om_cubes_2x2", flipbook=STATIC2x2, emit=[(0, 5)],
                     shape={"type": "Box", "size": (2, 1.5, 2)}, direction="Top", spread=(70, 70), speed=(6, 16),
                     drag=0.5, accel=(0, -110, 0), lifetime=(0.35, 0.55), size=[(0, 0.9, 0.3), (1, 0.7, 0.2)],
                     color=[(0, (120, 118, 128)), (1, (96, 94, 104))], rotation=(0, 360), rot_speed=(-400, 400)),
                dict(name="RockDust", texture="kk_smoke_04", emit=[(0, 2)], direction="Top", spread=(60, 60),
                     speed=(2, 6), drag=2, lifetime=(0.4, 0.6), size=[(0, 2, 0.5), (1, 6, 1)],
                     transparency=[(0, 0.6), (0.4, 0.65), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2)]


def rocks(name, direction, n_ev, per, size, speed, spread, seed, side=0.0, up=0.3):
    """Rocas que el corte arranca: bloques del color y material del suelo que vuelan, caen, se quedan un rato en
    el camino y se desmoronan en cubitos."""
    return dict(name=name, type="meteor", emit=cut(n_ev, per, seed, jitter=1.2, up=up, side=side),
                direction=direction, spread=spread, speed=speed, accel=(0, -196, 0), drag=0.1, lifetime=(2.2, 2.2),
                sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": size, "aspect": (1.0, 1.0, 1.0),
                        "cube": True, "ground": True, "color": SLAB_RGB, "color_var": (0.8, 1.1),
                        "rot_speed": (-420, 420), "material": "Slate", "stick": 1.2, "sink": 0.2},
                trails=[{"name": name + "Dust", "rate": 14, "texture": "kk_smoke_04", "speed": (0, 2),
                         "direction": "Top", "spread": (180, 180), "drag": 2, "lifetime": (0.4, 0.6),
                         "size": [(0, 1.5, 0.5), (1, 4, 1)], "transparency": [(0, 0.55), (0.5, 0.65), (1, 1)],
                         "color": MIST, "rotation": (0, 360)}],
                land=ROCK_LAND, shatter=ROCK_CRUMBLE)


def det(t, n=1):
    return [(round(TD + t, 3), n, 1.0, 0.0, 0.0)]


def det_up(t, n, up):
    return [(round(TD + t, 3), n, 1.0, 0.0, up)]


CRESCENT_WAVE = {
    "name": "CrescentWave",
    "doc": ("MOONFANG SKILL 1 (Medialuna): de un zarpazo lanza una media luna de energía que vuela vertical y de "
            "canto (de lado se ve la media luna; desde atrás, una hoja que apunta hacia donde va) y deja una estela "
            "de humo frío. Su cuerno de abajo corta el suelo: se abre una grieta con escarcha, las losas del suelo "
            "saltan a los lados y salen rocas que se quedan en el camino. Al llegar al final (0.76 s) detona en "
            "hielo y deja un cráter. MoonfangVFX.CrescentWave(CFrame.lookAt(origen, origen + dirección), largo, "
            "escala)."),
    "duration": 4.0,
    "line": LW,
    "blade": BLADE,
    "light": {"color": (180, 215, 255), "brightness": 5, "range": 40, "time": 0.3},
    "shakes": [(0.02, 0.45, 0.25), (T0 + 0.1, 0.3, TW), (TD, 1.4, 0.55)],
    "layers": [
        # ---------------- el zarpazo que la lanza ----------------
        dict(name="SwipeFlash", texture="mf_crescent", emit=[(0.0, 1, 0.0, 0.0, 10)], lifetime=(0.18, 0.18),
             size=[(0, 12), (0.4, 32), (1, 36)], transparency=[(0, 0.1), (0.5, 0.45), (1, 1)], color=SILVER,
             light_emission=1.0, brightness=1.3, rotation=(160, 160), zoffset=4),
        dict(name="SwipeGlow", texture="fx_glow", emit=[(0.02, 1, 0.0, 0.0, 10)], lifetime=(0.26, 0.26),
             size=[(0, 10), (1, 40)], transparency=[(0, 0.5), (1, 1)], color=CRYST, light_emission=1.0, brightness=1.0),
        dict(name="SwipeWind", texture="kz_wind_arcs", emit=[(0.03, 2, 0.02, 0.0, 6)], lifetime=(0.25, 0.3),
             size=[(0, 10), (1, 42)], transparency=[(0, 0.35), (0.6, 0.6), (1, 1)], color=ICE, light_emission=0.7,
             brightness=1.1, rotation=(0, 360), rot_speed=(-160, 160)),
        dict(name="SwipeDust", texture="kk_smoke_04", emit=[(0.04, 8, 0.03, 0.0, 1)], direction="Front",
             spread=(180, 6), speed=(30, 55), drag=4, accel=(0, 4, 0), lifetime=(0.5, 0.7), size=[(0, 4, 1), (1, 12, 2)],
             transparency=[(0, 0.5), (0.4, 0.6), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2),
        # ---------------- el corte del suelo: nieve, hielo, polvo, niebla fría y brillos ----------------
        dict(name="CutSnow", texture="kk_smoke_04", direction="Top", spread=(35, 35), speed=(14, 30), drag=3,
             accel=(0, 2, 0), lifetime=(0.5, 0.8), size=[(0, 3, 1), (1, 9, 2)],
             transparency=[(0, 0.4), (0.4, 0.55), (1, 1)], color=SNOW, rotation=(0, 360), rot_speed=(-60, 60),
             emit=cut(NP, 3, 21, jitter=1.0, up=0.5)),
        dict(name="CutIce", texture="mf_shard_2x2", flipbook=STATIC2x2, direction="Top", spread=(50, 50),
             speed=(25, 55), drag=0.5, accel=(0, -120, 0), lifetime=(0.5, 0.8), size=[(0, 1.1, 0.4), (1, 0.6, 0.2)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
             rotation=(0, 360), rot_speed=(-500, 500), emit=cut(NP, 3, 22, jitter=1.0, up=0.4)),
        dict(name="CutSparks", texture="kk_trace_01", orientation="VelocityParallel", direction="Back",
             spread=(35, 25), speed=(50, 90), drag=4, accel=(0, -30, 0), lifetime=(0.16, 0.26),
             size=[(0, 5, 1), (1, 1.5)], color=ICE, light_emission=1.0, brightness=2.0,
             emit=cut(NP, 2, 23, jitter=0.8, up=0.5)),
        dict(name="CutChips", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top", spread=(70, 70),
             speed=(25, 50), drag=0.4, accel=(0, -130, 0), lifetime=(0.6, 0.9), size=[(0, 0.9, 0.3), (1, 0.7, 0.2)],
             color=[(0, (128, 126, 136)), (1, (100, 98, 108))], rotation=(0, 360), rot_speed=(-500, 500),
             emit=cut(NP, 4, 24, jitter=2.5, up=0.5)),
        dict(name="CutDust", texture="kk_smoke_04", direction="Top", spread=(70, 70), speed=(6, 14), drag=2,
             accel=(0, 3, 0), lifetime=(0.6, 0.9), size=[(0, 4, 1), (1, 12, 3)],
             transparency=[(0, 0.5), (0.4, 0.62), (1, 1)], color=MIST, rotation=(0, 360), rot_speed=(-40, 40),
             zoffset=-2, emit=cut(NP, 2, 25, jitter=4.0, up=1.0, delay=0.02)),
        dict(name="CutMistR", texture="kk_smoke_04", direction="Right", spread=(25, 6), speed=(6, 14), drag=1.5,
             accel=(0, 0.6, 0), lifetime=(1.4, 2.0), size=[(0, 5, 1), (0.5, 12, 2), (1, 15, 2)],
             transparency=[(0, 0.6), (0.3, 0.65), (1, 1)], color=FROSTMIST, rotation=(0, 360), rot_speed=(-20, 20),
             zoffset=-3, emit=cut(20, 1, 26, jitter=0.6, up=0.8, delay=0.05)),
        dict(name="CutMistL", texture="kk_smoke_04", direction="Left", spread=(25, 6), speed=(6, 14), drag=1.5,
             accel=(0, 0.6, 0), lifetime=(1.4, 2.0), size=[(0, 5, 1), (0.5, 12, 2), (1, 15, 2)],
             transparency=[(0, 0.6), (0.3, 0.65), (1, 1)], color=FROSTMIST, rotation=(0, 360), rot_speed=(-20, 20),
             zoffset=-3, emit=cut(20, 1, 27, jitter=0.6, up=0.8, delay=0.05)),
        dict(name="CutGlints", texture="fx_spark002", direction="Top", spread=(40, 40), speed=(1, 4), drag=1,
             lifetime=(0.8, 1.4), size=twinkle(0.5), color=GLINT, light_emission=1.0, brightness=1.8,
             rotation=(0, 45), emit=cut(NP, 2, 28, jitter=2.0, up=0.6, delay=0.03)),
        rocks("RocksOut", "Left", 20, 1, (1.2, 3.0), (45, 90), (40, 25), 31, side=-1.5),
        rocks("RocksIn", "Right", 16, 1, (1.1, 2.8), (40, 85), (40, 25), 32, side=1.5),
        rocks("RocksUp", "Top", 14, 1, (1.3, 3.2), (50, 85), (22, 22), 33),
        # ---------------- la detonación de hielo ----------------
        dict(name="DetFlash", texture="fx_glow", emit=det_up(0.0, 1, 10), lifetime=(0.22, 0.24),
             size=[(0, 14), (0.3, 72), (1, 80)], transparency=[(0, 0.25), (0.5, 0.55), (1, 1)], color=CRYST,
             light_emission=1.0, brightness=1.2, zoffset=5),
        dict(name="DetCore", texture="fx_glow", emit=det_up(0.0, 1, 9), lifetime=(0.16, 0.16),
             size=[(0, 8), (0.25, 34), (1, 30)], transparency=[(0, 0.0), (0.6, 0.4), (1, 1)], color=WHITE,
             light_emission=1.0, brightness=1.8, zoffset=6),
        dict(name="DetStar", texture="kk_star_09", emit=det_up(0.0, 1, 10), lifetime=(0.28, 0.28),
             size=[(0, 18), (0.2, 92), (1, 30)], transparency=[(0, 0.0), (1, 1)], color=GLINT, light_emission=1.0,
             brightness=1.5, rotation=(0, 90), zoffset=7),
        dict(name="DetHalo", texture="fx_halo", emit=det_up(0.02, 1, 10), lifetime=(0.38, 0.38),
             size=[(0, 12), (1, 110)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=CRYST, light_emission=1.0,
             brightness=1.2, rotation=(0, 360), zoffset=3),
        dict(name="DetShock", texture="kk_circle_02", emit=det_up(0.01, 1, 9), lifetime=(0.32, 0.32),
             size=[(0, 10), (1, 130)], transparency=[(0, 0.1), (0.6, 0.5), (1, 1)], color=SILVER, light_emission=1.0,
             brightness=1.3, zoffset=4),
        dict(name="DetRing", texture="kk_circle_02", emit=det_up(0.0, 1, 0.3), lifetime=(0.55, 0.55),
             size=[(0, 14), (1, 180)], transparency=[(0, 0.1), (0.5, 0.42), (1, 1)], color=ICE, light_emission=0.8,
             **DECAL),
        dict(name="DetRingSharp", texture="kk_circle_02", emit=det_up(0.03, 1, 0.32), lifetime=(0.36, 0.36),
             size=[(0, 12), (1, 150)], transparency=[(0, 0.0), (0.6, 0.4), (1, 1)], color=SILVER, light_emission=1.0,
             **DECAL),
        # el aire helado: una nube fría grande, ráfagas que giran y viento que corre por el suelo
        dict(name="ColdCloud", texture="kk_smoke_07", emit=det_up(0.01, 24, 8), shape={"type": "Sphere", "radius": 7},
             direction="Top", spread=(180, 180), speed=(30, 70), drag=3.2, accel=(0, 3, 0), lifetime=(1.4, 2.0),
             size=[(0, 12, 2), (0.3, 32, 5), (1, 44, 5)], transparency=[(0, 0.3), (0.3, 0.45), (0.8, 0.72), (1, 1)],
             color=FROSTMIST, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3),
        dict(name="ColdSwirl", texture="fx_wind_swirl", emit=det_up(0.0, 2, 10) + det_up(0.1, 2, 12),
             lifetime=(0.6, 0.85), size=[(0, 16), (1, 92)], transparency=[(0, 0.25), (0.5, 0.5), (1, 1)], color=ICE,
             light_emission=0.6, brightness=1.1, rotation=(0, 360), rot_speed=(-240, 240), zoffset=2),
        dict(name="ColdArcs", texture="kz_wind_arcs", emit=det_up(0.04, 4, 9), lifetime=(0.4, 0.55),
             size=[(0, 18), (1, 78)], transparency=[(0, 0.25), (0.6, 0.55), (1, 1)], color=SILVER, light_emission=0.7,
             brightness=1.2, rotation=(0, 360), rot_speed=(-200, 200), zoffset=2),
        dict(name="GroundGust", texture="kk_trace_03", orientation="VelocityParallel", emit=det_up(0.02, 36, 1.2),
             direction="Front", spread=(180, 5), speed=(110, 180), drag=3, lifetime=(0.4, 0.6),
             size=[(0, 12, 2), (0.4, 16, 3), (1, 4)], transparency=[(0, 0.15), (0.6, 0.42), (1, 1)], color=ICE,
             light_emission=1.0, brightness=1.5),
        dict(name="GroundMist", texture="kk_smoke_04", emit=det_up(0.03, 20, 1), direction="Front", spread=(180, 4),
             speed=(50, 95), drag=3.5, accel=(0, 2, 0), lifetime=(1.0, 1.4), size=[(0, 7, 1), (1, 22, 3)],
             transparency=[(0, 0.4), (0.4, 0.58), (1, 1)], color=FROSTMIST, rotation=(0, 360), zoffset=-2),
        # el hielo: lanzas que revientan hacia afuera, esquirlas, una corona de púas y pedazos que se clavan
        dict(name="IceBurst", texture="mf_spike", orientation="VelocityParallel", emit=det_up(0.0, 22, 8),
             shape={"type": "Sphere", "radius": 3}, direction="Top", spread=(180, 180), speed=(90, 150), drag=5,
             lifetime=(0.3, 0.45), size=[(0, 4, 1), (0.2, 14, 3), (1, 6)], transparency=[(0, 0), (0.7, 0.2), (1, 1)],
             color=SHARD, light_emission=0.6, brightness=1.8),
        dict(name="DetShards", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=det_up(0.0, 70, 8),
             shape={"type": "Sphere", "radius": 4}, direction="Top", spread=(180, 180), speed=(55, 120), drag=0.5,
             accel=(0, -110, 0), lifetime=(0.6, 1.0), size=[(0, 2.2, 0.6), (1, 1.4, 0.4)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.5,
             rotation=(0, 360), rot_speed=(-500, 500)),
        dict(name="IceCrown", texture="mf_spike", orientation="VelocityParallel", emit=det_up(0.04, 26, 0.5),
             shape={"type": "Box", "size": (28, 1, 28)}, direction="Top", spread=(25, 25), speed=(28, 44), drag=12,
             lifetime=(1.3, 1.6), size=[(0, 0.6), (0.1, 12, 3), (0.8, 12.5, 3), (1, 0)],
             transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.5, brightness=1.7),
        dict(name="IceChunks", type="meteor", emit=det_up(0.02, 12, 4), direction="Top", spread=(70, 70),
             speed=(60, 110), accel=(0, -196, 0), drag=0.1, lifetime=(2.4, 2.4),
             sprite={"texture": "mf_shard_2x2", "layout": "Grid2x2", "size": (4, 8), "aspect": (0.7, 1.6, 0.7),
                     "rot_speed": (-300, 300), "color": CRYSTAL_RGB, "material": "Ice", "stick": 0.9, "sink": 0.3},
             trails=[{"name": "ChunkSparkle", "rate": 16, "texture": "fx_spark002", "speed": (0, 4),
                      "direction": "Top", "spread": (180, 180), "lifetime": (0.3, 0.5), "size": twinkle(0.5),
                      "color": GLINT, "light_emission": 1.0, "brightness": 1.8, "rotation": (0, 45)}],
             land=[dict(name="ChunkCracks", texture="mf_frost_cracks", emit=[(0, 1)], lifetime=(1.2, 1.4),
                        rotation=(0, 360), size=[(0, 3), (0.1, 11), (1, 12)],
                        transparency=[(0, 0), (0.3, 0.15), (0.8, 0.45), (1, 1)], color=FROST, light_emission=0.9,
                        **DECAL)],
             shatter=[dict(name="ChunkBreak", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0, 8)],
                           shape={"type": "Box", "size": (3, 6, 3)}, direction="Top", spread=(90, 90),
                           speed=(12, 30), drag=0.5, accel=(0, -110, 0), lifetime=(0.4, 0.65),
                           size=[(0, 1.3, 0.4), (1, 0.9, 0.3)], color=SHARD, light_emission=0.45, brightness=1.4,
                           rotation=(0, 360), rot_speed=(-500, 500))]),
        # la escarcha que queda: grietas, un velo frío en el suelo y cristalitos que flotan y caen
        dict(name="DetCracks", texture="mf_frost_cracks", emit=det_up(0.02, 1, 0.22), lifetime=(2.4, 2.6),
             rotation=(0, 360), size=[(0, 24), (0.06, 84), (1, 88)],
             transparency=[(0, 0), (0.25, 0.1), (0.8, 0.4), (1, 1)], color=FROST, light_emission=0.9, **DECAL),
        dict(name="DetFrost", texture="fx_glow", emit=det_up(0.05, 1, 0.16), lifetime=(2.3, 2.5),
             size=[(0, 34), (0.1, 86), (1, 90)], transparency=[(0, 0.45), (0.7, 0.6), (1, 1)], color=ICE,
             light_emission=0.4, **DECAL),
        dict(name="Snow", texture="fx_spark002", shape={"type": "Sphere", "radius": 30}, direction="Top",
             spread=(180, 180), speed=(2, 6), drag=1, accel=(0, -3, 0), lifetime=(1.4, 2.2), size=twinkle(0.55),
             color=GLINT, light_emission=1.0, brightness=1.8, rotation=(0, 45),
             emit=det_up(0.05, 60, 14)),
    ],
}

# ----------------------------------------------------------------------------- SKILL 2: Ola de hielo
# Moonfang golpea el suelo y una OLA DENSA DE HUMO HELADO sale hacia adelante abriéndose en TRIÁNGULO (modo "cone":
# u = fracción del largo, s = fracción del medio ancho). Sale con fuerza y se va frenando hasta asentarse. El frente
# lleva emisores que viajan con él ("front"): un muro de humo helado, una cresta alta que se arremolina, niebla baja,
# polvo de nieve, brillos, esquirlas y polvo de tierra; ese humo nace en el frente y se queda atrás frenándose, así
# deja una estela espesa sobre todo el triángulo. A su paso brotan bloques de hielo (Parts), saltan losas, salen rocas
# volando, el suelo queda escarchado y sube humo frío. Al final los bloques de hielo revientan en esquirlas.
WL, WA = 110.0, 50.0       # largo y apertura del triángulo (escala 1; se eligen al llamar el efecto)
T0W, TWW, EASE = 0.12, 1.0, 1.5   # el frente sale, tarda en cruzar y cuánto se frena (1 = velocidad constante)
WAVE = (T0W, TWW, EASE)
TEW = T0W + TWW            # llega al borde lejano (ya casi quieto)


def wfront(u, delay=0.0):
    """Instante en que el frente pasa por u (sale rápido y se va frenando)."""
    return round(T0W + delay + TWW * (1 - (1 - min(max(u, 0.0), 1.0)) ** (1 / EASE)), 3)


def wsamples(g, n, u0=0.05, u1=1.0, s_max=0.95, up=(0.3, 0.3), delay=(0.0, 0.0)):
    """Puntos del triángulo (más donde es más ancho), en el instante en que pasa el frente (+ delay)."""
    out = []
    for _ in range(n):
        u = math.sqrt(g.uniform(u0 * u0, u1 * u1))
        out.append((round(wfront(u) + g.uniform(*delay), 3), 1, round(u, 4), round(g.uniform(-s_max, s_max), 3),
                    round(g.uniform(*up), 2)))
    return sorted(out)


def wcrest(g, n_u, per, up=0.5, u0=0.05, u1=1.0, s_max=0.97, delay=0.0):
    """La cresta: eventos repartidos a lo ancho del frente mientras avanza (más a lo ancho donde es más ancho)."""
    out = []
    for i in range(n_u):
        u = u0 + (u1 - u0) * i / max(1, n_u - 1)
        k = max(2, int(round(per * (0.35 + 0.65 * u))))
        for j in range(k):
            s = -s_max + 2 * s_max * (j + g.uniform(0.2, 0.8)) / k
            out.append((wfront(u, delay), 1, round(u, 4), round(s, 3), up))
    return sorted(out)


def wedge(n, up=0.5):
    """Donde la ola se asienta, al llegar al borde lejano."""
    return [(wfront(0.97), 1, 0.98, round(-0.97 + 1.94 * j / (n - 1), 3), up) for j in range(n)]


ICE_FOG = [(0, (238, 246, 255)), (0.35, (200, 222, 252)), (1, (160, 188, 236))]
# lo que viaja con el frente: `count` puntos a lo ancho; rate = partículas por segundo de cada punto con el frente
# a todo lo ancho (al principio, angosto, suelta menos)
WAVE_FRONT = {
    "wave": WAVE, "count": 14, "s_max": 0.95,
    "emitters": [
        # la base: humo denso y más oscuro (le da volumen a la ola); nace en el frente y se queda atrás (la estela)
        dict(name="FogCore", up=5.0, rate=18, texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front",
             spread=(35, 12), speed=(60, 100), drag=2.5, accel=(0, 1.5, 0), lifetime=(1.8, 2.8),
             size=[(0, 9, 2), (0.2, 15, 3), (0.6, 20, 3), (1, 23, 3)],
             transparency=[(0, 0.4), (0.1, 0.25), (0.35, 0.55), (0.7, 0.75), (1, 1)],
             color=[(0, (195, 214, 242)), (0.5, (152, 176, 216)), (1, (128, 150, 196))], rotation=(0, 360),
             rot_speed=(-30, 30), zoffset=-3),
        # el muro blanco encima, que crece y se arremolina
        dict(name="FogWall", up=6.0, rate=16, texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front",
             spread=(35, 18), speed=(55, 95), drag=2.4, accel=(0, 2, 0), lifetime=(2.0, 3.0),
             size=[(0, 10, 2), (0.15, 18, 3), (0.6, 26, 4), (1, 32, 4)],
             transparency=[(0, 0.45), (0.08, 0.3), (0.3, 0.58), (0.6, 0.76), (1, 1)], color=ICE_FOG,
             light_emission=0.12, rotation=(0, 360), rot_speed=(-40, 40), zoffset=-2),
        # la cresta alta, brillante
        dict(name="FogBillow", up=11.0, rate=10, texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front",
             spread=(30, 25), speed=(40, 80), drag=2.0, accel=(0, 5, 0), lifetime=(1.6, 2.4),
             size=[(0, 11, 2), (0.3, 21, 3), (1, 32, 4)], transparency=[(0, 0.55), (0.12, 0.38), (0.4, 0.64), (1, 1)],
             color=[(0, (250, 252, 255)), (1, (200, 218, 245))], light_emission=0.18, rotation=(0, 360),
             rot_speed=(-45, 45), zoffset=-1),
        # la niebla baja que se pega al suelo y se abre a los lados (lo que más dura)
        dict(name="FogLow", up=4.0, rate=18, texture="fx_fog2001", direction="Front", spread=(60, 6),
             speed=(30, 70), drag=1.8, accel=(0, 0.3, 0), lifetime=(2.6, 3.6),
             size=[(0, 6, 1), (0.4, 12, 2), (1, 16, 2)],
             transparency=[(0, 0.5), (0.12, 0.4), (0.4, 0.66), (0.8, 0.82), (1, 1)],
             color=[(0, (225, 238, 255)), (1, (182, 202, 236))], light_emission=0.12, rotation=(0, 360),
             rot_speed=(-20, 20), zoffset=-3),
        # el borde que se revuelve: humo más rápido que el frente que sale adelante y la ola se lo traga
        dict(name="FrontEdge", up=1.5, rate=14, texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front",
             spread=(30, 10), speed=(150, 200), drag=5, accel=(0, 3, 0), lifetime=(0.6, 1.0),
             size=[(0, 6, 1), (1, 14, 2)], transparency=[(0, 0.35), (0.3, 0.5), (1, 1)],
             color=[(0, (245, 250, 255)), (1, (205, 222, 248))], light_emission=0.15, rotation=(0, 360),
             rot_speed=(-60, 60)),
        # el borde de adelante: polvo de nieve, brillos, esquirlas y polvo de tierra (el destrozo)
        dict(name="FrontPowder", up=3.0, rate=18, texture="kk_smoke_04", direction="Front", spread=(25, 30),
             speed=(110, 160), drag=4, accel=(0, -10, 0), lifetime=(0.5, 0.9), size=[(0, 3, 1), (1, 10, 2)],
             transparency=[(0, 0.3), (0.5, 0.5), (1, 1)], color=SNOW, rotation=(0, 360), rot_speed=(-60, 60)),
        dict(name="FrontGlitter", up=4.0, rate=12, texture="fx_spark002", direction="Front", spread=(40, 40),
             speed=(60, 120), drag=3, accel=(0, -4, 0), lifetime=(0.6, 1.2), size=None, color=GLINT,
             light_emission=1.0, brightness=1.8, rotation=(0, 45)),
        dict(name="FrontIce", up=2.0, rate=10, pitch=35, texture="mf_shard_2x2", flipbook=STATIC2x2,
             direction="Front", spread=(30, 20), speed=(50, 90), drag=0.6, accel=(0, -110, 0), lifetime=(0.5, 0.9),
             size=[(0, 1.3, 0.4), (1, 0.8, 0.3)], transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD,
             light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500)),
        dict(name="FrontDust", up=1.0, rate=10, texture="kk_smoke_04", direction="Front", spread=(40, 20),
             speed=(40, 80), drag=3, accel=(0, 2, 0), lifetime=(0.8, 1.2), size=[(0, 5, 1), (1, 14, 3)],
             transparency=[(0, 0.45), (0.4, 0.58), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2),
    ],
}
WAVE_FRONT["emitters"][6]["size"] = twinkle(0.6)


ICE_BREAK = [dict(name="IceBreak", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0, 6)],
                  shape={"type": "Box", "size": (2.5, 2.5, 2.5)}, direction="Top", spread=(80, 80), speed=(12, 30),
                  drag=0.5, accel=(0, -110, 0), lifetime=(0.4, 0.7), size=[(0, 1.2, 0.4), (1, 0.8, 0.3)],
                  transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
                  rotation=(0, 360), rot_speed=(-500, 500)),
             dict(name="IceBreakGlint", texture="kk_star_06", emit=[(0, 2)], shape={"type": "Box", "size": (3, 3, 3)},
                  direction="Top", spread=(80, 80), speed=(2, 6), drag=2, lifetime=(0.3, 0.5), size=twinkle(1.0),
                  color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45)),
             dict(name="IceBreakMist", texture="fx_fog2001", emit=[(0, 1)], direction="Top", spread=(60, 60),
                  speed=(2, 5), drag=2, accel=(0, 1, 0), lifetime=(0.6, 0.9), size=[(0, 3, 1), (1, 8, 2)],
                  transparency=[(0, 0.6), (0.4, 0.65), (1, 1)], color=FROSTMIST, light_emission=0.15,
                  rotation=(0, 360), zoffset=-1)]
WAVE_FIELD = {
    "wave": WAVE, "seed": 9,
    "groups": [
        # bloques de hielo que brotan inclinados (algunos grandes) y al final revientan
        {"name": "IceBlocks", "count": 34, "u": (0.08, 0.55), "s": (-0.92, 0.92), "lean": "random",
         "wid": (1.0, 2.2), "thick": (1.0, 2.4), "len": (1.0, 2.2), "tilt": (5, 30), "yaw": 0, "pitch": 15,
         "show": 0.75, "rise": 0.09, "hold": (1.3, 2.0), "sink": 0.4, "delay": (0.0, 0.07),
         "big": {"frac": 0.15, "k": 1.8}, "end": "shatter", "shatter": ICE_BREAK,
         "ice": {"color": CRYSTAL_RGB, "material": "Ice", "transparency": 0.15}},
        {"name": "IceBlocks", "count": 36, "u": (0.55, 1.0), "s": (-0.92, 0.92), "lean": "random",
         "wid": (1.5, 3.2), "thick": (1.5, 3.4), "len": (1.5, 3.2), "tilt": (5, 30), "yaw": 0, "pitch": 15,
         "show": 0.75, "rise": 0.1, "hold": (1.3, 2.0), "sink": 0.4, "delay": (0.0, 0.07),
         "big": {"frac": 0.2, "k": 2.0}, "end": "shatter", "shatter": ICE_BREAK,
         "ice": {"color": CRYSTAL_RGB, "material": "Ice", "transparency": 0.15}},
        # losas del suelo que saltan inclinadas hacia afuera (toman el color y el material del suelo)
        {"name": "WaveSlabs", "count": 50, "u": (0.06, 1.0), "s": (-1.0, 1.0), "lean": "radial",
         "wid": (1.6, 3.0), "thick": (0.5, 1.0), "len": (1.4, 2.8), "tilt": (15, 40), "yaw": 14, "pitch": 10,
         "show": 0.62, "rise": 0.07, "hold": (1.4, 2.0), "sink": 0.5, "delay": (0.0, 0.05),
         "ground": True, "preview_color": SLAB_RGB},
    ],
}


def wave_layers(g):
    L = [
        # ---------------- el golpe en el suelo que la lanza (en el vértice) ----------------
        dict(name="SlamFlash", texture="fx_glow", emit=[(0.0, 1)], offset=(0, 3, -4), lifetime=(0.2, 0.2),
             size=[(0, 8), (0.3, 30), (1, 34)], transparency=[(0, 0.4), (1, 1)], color=CRYST, light_emission=1.0,
             brightness=1.1, zoffset=3),
        dict(name="SlamStar", texture="kk_star_09", emit=[(0.0, 1)], offset=(0, 3, -4), lifetime=(0.22, 0.22),
             size=[(0, 8), (0.2, 34), (1, 12)], transparency=[(0, 0.1), (1, 1)], color=GLINT, light_emission=1.0,
             brightness=1.4, rotation=(0, 90), zoffset=4),
        dict(name="SlamRing", texture="kk_circle_02", emit=[(0.02, 1)], offset=(0, 0.3, -4), lifetime=(0.45, 0.45),
             size=[(0, 6), (1, 60)], transparency=[(0, 0.15), (0.5, 0.45), (1, 1)], color=ICE, light_emission=0.8,
             **DECAL),
        dict(name="SlamMist", texture="kk_smoke_07", emit=[(0.02, 8)], offset=(0, 2, -4),
             shape={"type": "Sphere", "radius": 3}, direction="Top", spread=(180, 180), speed=(18, 36), drag=3,
             accel=(0, 2, 0), lifetime=(0.8, 1.2), size=[(0, 6, 1), (1, 18, 3)],
             transparency=[(0, 0.45), (0.4, 0.6), (1, 1)], color=FROSTMIST, rotation=(0, 360), zoffset=-2),
        dict(name="SlamShards", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0.0, 16)], offset=(0, 2, -4),
             shape={"type": "Sphere", "radius": 2}, direction="Top", spread=(90, 90), speed=(30, 60), drag=0.5,
             accel=(0, -110, 0), lifetime=(0.5, 0.8), size=[(0, 1.5, 0.4), (1, 1.0, 0.3)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
             rotation=(0, 360), rot_speed=(-500, 500)),
        # ---------------- la cresta: nieve, esquirlas y púas que saltan donde pasa el frente ----------------
        dict(name="CrestSpray", texture="kk_smoke_04", direction="Top", spread=(30, 30), speed=(22, 44), drag=2.5,
             accel=(0, -8, 0), lifetime=(0.6, 0.9), size=[(0, 4, 1), (1, 12, 2)],
             transparency=[(0, 0.35), (0.4, 0.5), (1, 1)], color=SNOW, rotation=(0, 360), rot_speed=(-60, 60),
             cone_emit=wcrest(g, 14, 7, up=0.6)),
        dict(name="CrestShards", texture="mf_shard_2x2", flipbook=STATIC2x2, direction="Front", pitch=40,
             spread=(25, 20), speed=(30, 60), drag=0.5, accel=(0, -120, 0), lifetime=(0.5, 0.9),
             size=[(0, 1.3, 0.4), (1, 0.8, 0.3)], transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD,
             light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500),
             cone_emit=wcrest(g, 12, 5, up=0.8)),
        dict(name="CrestSpikes", texture="mf_spike", orientation="VelocityParallel", direction="Top", spread=(20, 20),
             speed=(26, 44), drag=12, lifetime=(0.7, 1.0), size=[(0, 0.6), (0.12, 6, 1.5), (0.8, 6.5, 1.5), (1, 0)],
             transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.5, brightness=1.6,
             cone_emit=wcrest(g, 6, 6, up=0.3, u1=0.5)),
        dict(name="CrestSpikesFar", texture="mf_spike", orientation="VelocityParallel", direction="Top",
             spread=(20, 20), speed=(30, 50), drag=12, lifetime=(0.8, 1.1),
             size=[(0, 0.8), (0.12, 9.5, 2), (0.8, 10, 2), (1, 0)], transparency=[(0, 0), (0.8, 0.1), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.6, cone_emit=wcrest(g, 7, 7, up=0.3, u0=0.55)),
        dict(name="CrestGlints", texture="kk_star_06", direction="Top", spread=(60, 60), speed=(4, 10), drag=1.5,
             lifetime=(0.4, 0.7), size=twinkle(1.0), color=GLINT, light_emission=1.0, brightness=2.0,
             rotation=(0, 45), cone_emit=wcrest(g, 12, 4, up=2.0)),
        # ---------------- lo que queda: suelo escarchado, polvo, cubitos, rocas y humo frío ----------------
        dict(name="FrostFloor", texture="mf_frost_patch", lifetime=(2.2, 2.6), rotation=(0, 360),
             size=[(0, 6), (0.06, 18, 3), (1, 19, 3)], transparency=[(0, 0.3), (0.8, 0.5), (1, 1)],
             color=[(0, (190, 225, 255)), (1, (150, 200, 255))], light_emission=0.5,
             cone_emit=wsamples(g, 46, up=(0.2, 0.2), delay=(0.0, 0.08)), **DECAL),
        dict(name="FrostCracks", texture="mf_frost_cracks", lifetime=(2.0, 2.4), rotation=(0, 360),
             size=[(0, 8), (0.06, 24, 4), (1, 25, 4)], transparency=[(0, 0.4), (0.3, 0.45), (0.8, 0.65), (1, 1)],
             color=FROST, light_emission=0.5, cone_emit=wsamples(g, 8, u0=0.2, up=(0.25, 0.25), delay=(0, 0.05)),
             **DECAL),
        dict(name="GroundCracks", texture="mf_frost_cracks", lifetime=(2.6, 3.2), rotation=(0, 360),
             size=[(0, 8), (0.05, 22, 4), (1, 23, 4)], transparency=[(0, 0.25), (0.75, 0.4), (1, 1)],
             color=[(0, (34, 40, 56)), (1, (40, 46, 62))], cone_emit=wsamples(g, 24, u0=0.08, up=(0.15, 0.15)),
             **DECAL),
        dict(name="FieldDust", texture="kk_smoke_04", direction="Top", spread=(70, 70), speed=(6, 14), drag=2,
             accel=(0, 3, 0), lifetime=(0.6, 1.0), size=[(0, 4, 1), (1, 12, 3)],
             transparency=[(0, 0.5), (0.4, 0.62), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2,
             cone_emit=wsamples(g, 30, up=(0.8, 0.8), delay=(0.0, 0.05))),
        dict(name="FieldChips", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top", spread=(55, 55),
             speed=(25, 55), drag=0.4, accel=(0, -130, 0), lifetime=(0.6, 0.9), size=[(0, 0.9, 0.3), (1, 0.7, 0.2)],
             color=[(0, (128, 126, 136)), (1, (100, 98, 108))], rotation=(0, 360), rot_speed=(-500, 500),
             cone_emit=wce2(wsamples(g, 34, up=(0.5, 0.5)), 2)),
        dict(name="FieldSmoke", texture="fx_fog2001", direction="Top", spread=(30, 30), speed=(2, 6), drag=1,
             accel=(0, 1.5, 0), lifetime=(2.0, 3.0), size=[(0, 8, 2), (0.5, 18, 3), (1, 24, 3)],
             transparency=[(0, 0.72), (0.3, 0.62), (1, 1)], color=FROSTMIST, light_emission=0.15, rotation=(0, 360),
             rot_speed=(-20, 20), zoffset=-3, cone_emit=wsamples(g, 40, up=(1.0, 3.0), delay=(0.1, 0.7))),
        dict(name="WaveRocks", type="meteor", direction="Front", pitch=45, spread=(25, 20), speed=(50, 95),
             accel=(0, -196, 0), drag=0.1, lifetime=(2.2, 2.2),
             sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": (1.2, 3.0), "aspect": (1.0, 1.0, 1.0),
                     "cube": True, "ground": True, "color": SLAB_RGB, "color_var": (0.8, 1.1),
                     "rot_speed": (-420, 420), "material": "Slate", "stick": 1.2, "sink": 0.2},
             trails=[{"name": "WaveRockDust", "rate": 12, "texture": "kk_smoke_04", "speed": (0, 2),
                      "direction": "Top", "spread": (180, 180), "drag": 2, "lifetime": (0.4, 0.6),
                      "size": [(0, 1.5, 0.5), (1, 4, 1)], "transparency": [(0, 0.55), (0.5, 0.65), (1, 1)],
                      "color": MIST, "rotation": (0, 360)}],
             land=ROCK_LAND, shatter=ROCK_CRUMBLE, cone_emit=wce2(wsamples(g, 50, up=(0.5, 0.5)), 1)),
        dict(name="WaveChunks", type="meteor", direction="Front", pitch=55, spread=(20, 20), speed=(45, 75),
             accel=(0, -196, 0), drag=0.1, lifetime=(2.4, 2.4),
             sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": (2.5, 4.5), "aspect": (1.0, 0.8, 1.0),
                     "cube": True, "ground": True, "color": SLAB_RGB, "color_var": (0.8, 1.1),
                     "rot_speed": (-300, 300), "material": "Slate", "stick": 1.4, "sink": 0.25},
             trails=[{"name": "WaveChunkDust", "rate": 16, "texture": "kk_smoke_04", "speed": (0, 2),
                      "direction": "Top", "spread": (180, 180), "drag": 2, "lifetime": (0.5, 0.7),
                      "size": [(0, 2.5, 0.5), (1, 6, 1)], "transparency": [(0, 0.5), (0.5, 0.62), (1, 1)],
                      "color": MIST, "rotation": (0, 360)}],
             land=ROCK_LAND, shatter=ROCK_CRUMBLE, cone_emit=wce2(wsamples(g, 12, u0=0.2, up=(0.5, 0.5)), 1)),
        # ---------------- el choque contra el borde lejano ----------------
        dict(name="CrashSpray", texture="kk_smoke_07", direction="Top", spread=(35, 35), speed=(20, 45), drag=2.5,
             accel=(0, -6, 0), lifetime=(0.7, 1.1), size=[(0, 6, 1), (1, 18, 3)],
             transparency=[(0, 0.4), (0.4, 0.55), (1, 1)], color=SNOW, rotation=(0, 360), rot_speed=(-40, 40),
             cone_emit=wedge(16, 1.0)),
        dict(name="CrashSpikes", texture="mf_spike", orientation="VelocityParallel", direction="Front", pitch=60,
             spread=(20, 20), speed=(30, 50), drag=12, lifetime=(0.9, 1.2),
             size=[(0, 0.6), (0.12, 10, 2.5), (0.8, 10.5, 2.5), (1, 0)], transparency=[(0, 0), (0.8, 0.1), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.7, cone_emit=wedge(14, 0.3)),
        dict(name="CrashShards", texture="mf_shard_2x2", flipbook=STATIC2x2, direction="Front", pitch=50,
             spread=(35, 30), speed=(35, 70), drag=0.5, accel=(0, -110, 0), lifetime=(0.6, 1.0),
             size=[(0, 1.8, 0.5), (1, 1.2, 0.4)], transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD,
             light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500),
             cone_emit=wce2(wedge(12, 1.0), 2)),
    ]
    return L


def wce2(events, n):
    """Los mismos eventos con n partículas cada uno."""
    return [(t, n, u, s, h) for (t, _, u, s, h) in events]


ICE_WAVE = {
    "name": "IceWave",
    "doc": ("MOONFANG SKILL 2 (Ola de hielo): golpea el suelo y una ola densa de humo helado sale hacia adelante "
            "abriéndose en triángulo; sale con fuerza y se va frenando, y deja una estela espesa de humo. A su paso "
            "brotan bloques de hielo inclinados, saltan losas del suelo, salen rocas volando y el suelo queda "
            "escarchado. Llega al borde lejano a los 1.12 s; los bloques de hielo revientan al final."),
    "duration": 4.6,
    "cone": {"length": WL, "angle": WA, "wave": [T0W, TWW]},
    "front": WAVE_FRONT,
    "field": WAVE_FIELD,
    "light": {"color": (170, 210, 255), "brightness": 4, "range": 40, "time": 0.6},
    "shakes": [(0.02, 0.6, 0.3), (T0W + 0.05, 0.45, TWW), (wfront(0.97), 0.5, 0.35)],
}
ICE_WAVE["layers"] = wave_layers(random.Random(52))

# ----------------------------------------------------------------------------- SKILL 3: Aullido lunar
T_HOWL = 0.3
MOON_OFF = (0, 58, 48)     # la luna aparece detrás y encima de la cabeza (+Z = detrás de él)
LUNAR_HOWL = {
    "name": "LunarHowl",
    "doc": ("MOONFANG SKILL 3 (Aullido lunar): la luz se junta en su hocico, aúlla (ondas de sonido que salen hacia "
            "adelante y arriba) y una luna llena enorme aparece detrás de él y lo baña de luz. Después enciende "
            "LunarAura mientras dure la mejora. cf = la cabeza, mirando hacia adelante (-Z)."),
    "duration": 3.2,
    "light": {"color": (200, 225, 255), "brightness": 4, "range": 60, "time": 2.4, "delay": T_HOWL},
    "shakes": [(T_HOWL, 0.6, 0.6)],
    "layers": [
        # la luz se junta en el hocico
        dict(name="GatherMotes", texture="fx_particle02", shape={"type": "Sphere", "radius": 14, "style": "Surface",
                                                                 "inout": "Inward"},
             speed=(30, 40), lifetime=(0.3, 0.32), size=[(0, 0), (0.3, 1.0), (1, 0.4)], color=GLINT,
             light_emission=1.0, brightness=1.8, stream=[(0.0, 0.28, 120, 60)]),
        dict(name="GatherGlow", texture="fx_glow", emit=[(0.0, 1)], lifetime=(0.3, 0.3), size=[(0, 2), (1, 12)],
             transparency=[(0, 0.8), (1, 0.3)], color=ICE, light_emission=1.0, brightness=1.2),
        # el aullido: ondas de sonido hacia adelante y arriba
        dict(name="HowlRings", texture="kz_beam_ring", direction="Front",
             spread=(0, 0), speed=(45, 45), drag=1.2, lifetime=(0.6, 0.6), size=[(0, 10), (1, 60)],
             transparency=[(0, 0.15), (0.6, 0.5), (1, 1)], color=ICE, light_emission=1.0, brightness=1.4,
             emit=[(round(T_HOWL + 0.1 * k, 2), 1) for k in range(6)]),
        dict(name="HowlRingsUp", texture="kk_circle_02", orientation="VelocityPerpendicular", direction="Top",
             speed=(30, 30), drag=1.2, lifetime=(0.65, 0.65), size=[(0, 12), (1, 72)],
             transparency=[(0, 0.3), (0.6, 0.6), (1, 1)], color=SILVER, light_emission=1.0, brightness=1.1,
             emit=[(round(T_HOWL + 0.15 * k, 2), 1) for k in range(4)]),
        dict(name="HowlBlast", texture="fx_glow", emit=[(T_HOWL, 1)], lifetime=(0.25, 0.25),
             size=[(0, 8), (0.3, 30), (1, 34)], transparency=[(0, 0.35), (1, 1)], color=ICE, light_emission=1.0,
             brightness=1.1, zoffset=3),
        dict(name="HowlStreaks", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
             spread=(30, 30), speed=(80, 130), drag=4, lifetime=(0.2, 0.35), size=[(0, 8, 2), (1, 3)], color=ICE,
             light_emission=1.0, brightness=1.6, emit=[(T_HOWL, 18), (T_HOWL + 0.2, 10)]),
        # la luna llena detrás de él
        dict(name="Moon", texture="mf_moon", offset=MOON_OFF, emit=[(T_HOWL + 0.05, 1)], lifetime=(2.6, 2.6),
             size=[(0, 30), (0.12, 58), (0.85, 60), (1, 62)], transparency=[(0, 1), (0.1, 0.05), (0.8, 0.1), (1, 1)],
             color=MOONC, light_emission=0.12, brightness=1.0, zoffset=-6),
        dict(name="MoonHalo", texture="fx_glow", offset=MOON_OFF, emit=[(T_HOWL + 0.05, 1)], lifetime=(2.6, 2.6),
             size=[(0, 40), (0.12, 95), (1, 100)], transparency=[(0, 1), (0.1, 0.45), (0.8, 0.5), (1, 1)],
             color=CRYST, light_emission=1.0, brightness=0.9, zoffset=-7),
        dict(name="MoonRing", texture="kk_circle_02", offset=MOON_OFF, emit=[(T_HOWL + 0.08, 1)],
             lifetime=(0.6, 0.6), size=[(0, 60), (1, 150)], transparency=[(0, 0.3), (0.6, 0.6), (1, 1)],
             color=SILVER, light_emission=1.0, brightness=1.0, zoffset=-5),
        dict(name="MoonGlints", texture="kk_star_06", offset=MOON_OFF, shape={"type": "Sphere", "radius": 40},
             lifetime=(0.4, 0.7), size=twinkle(1.6), color=GLINT, light_emission=1.0, brightness=2.0,
             rotation=(0, 45), stream=[(T_HOWL + 0.1, 2.6, 18, 6)]),
        # la luz de la luna baja sobre él
        dict(name="Moonbeams", texture="mf_moonlight_2x2", flipbook=STATIC2x2, orientation=UP,
             offset=(0, 10, 10), shape={"type": "Box", "size": (24, 2, 6)}, lifetime=(0.7, 0.9),
             size=[(0, 26, 4), (1, 30, 4)], transparency=[(0, 1), (0.3, 0.7), (0.7, 0.75), (1, 1)], color=SILVER,
             light_emission=1.0, brightness=0.8, zoffset=-3, stream=[(T_HOWL + 0.2, 2.6, 6, 3)]),
        dict(name="FallingLight", texture="fx_spark002", offset=(0, 28, 10), shape={"type": "Box", "size": (30, 4, 12)},
             direction="Bottom", spread=(5, 5), speed=(10, 18), lifetime=(1.0, 1.4), size=twinkle(0.6), color=GLINT,
             light_emission=1.0, brightness=1.8, rotation=(0, 45), stream=[(T_HOWL + 0.2, 2.6, 30, 10)]),
    ],
}

# ----------------------------------------------------------------------------- SKILL 4: Eclipse
# Una luna gigante aparece sobre la zona y se eclipsa: en el suelo se dibuja el círculo lunar, la escarcha agrieta
# la zona y el hielo y los pedazos de suelo flotan hacia la luna. Al quedar tapada (TE_C) cae una columna de luz de
# luna de todo el ancho de la zona (TE_I): congela el suelo, brota una corona de picos de hielo en el borde y un
# campo de cristales, y vuela la tierra. La columna colapsa hacia el centro (TE_E) y todo el hielo revienta en una
# detonación (TE_D). La luna y el círculo usan BillboardGui y Decals (sin el tope de 100 studs de las partículas);
# la columna son Beams.
ER, EH = 120.0, 340.0      # radio de la zona y altura de la luna (escala 1)
MD = 2.6 * ER              # tamaño de la luna (el disco se ve de ~0.8 MD)
TE_C = 1.3                 # la luna queda eclipsada y cae la columna
TE_I = TE_C + 0.12         # la columna toca el suelo
TE_E = 3.3                 # la columna colapsa hacia el centro
TE_D = TE_E + 0.25         # detonación de hielo
SKY = dict(bill=True, rel="r", hu="H")
BIG = dict(bill=True, rel="r")
SIGIL_D = 2 * ER / 0.958   # mf_eclipse_sigil: el anillo de afuera queda en el radio
FROSTY = [(0, (150, 205, 255)), (0.3, (215, 236, 255)), (1, (120, 175, 250))]


def EW(rate, t0=TE_I, t1=TE_E, rin=0.1, rout=0.15):
    return [(t0 - 0.05, t0 + rin, rate * 0.4, rate), (t0 + rin, t1 - rout, rate, rate), (t1 - rout, t1, rate, 0.0)]


def pulses(t0, t1, every):
    out, t = [], t0
    while t < t1 - 1e-6:
        out += center(round(t, 3), 0.25)
        t += every
    return out


def eclipse_layers(g):
    D = 3.39 * ER                          # kk_circle_02: el anillo queda en el radio
    ML = TE_D + 1.2                        # vida de la luna

    def fr(t):                             # segundo t -> fracción de la vida de la luna
        return round(t / ML, 4)
    L = [
        # ================= el cielo: la luna gigante que se eclipsa, la corona y el anillo de diamante =================
        # (la luna va delante de la columna: zoffset alto; lo que está detrás de ella solo se ve por fuera del disco)
        dict(name="MoonHalo", texture="fx_glow", lifetime=(ML, ML),
             size=[(0, 0.5 * MD), (0.06, 1.9 * MD), (1, 2.0 * MD)],
             transparency=[(0, 1), (0.05, 0.45), (fr(TE_C - 0.3), 0.5), (fr(TE_C), 0.75), (fr(TE_D), 0.75),
                           (fr(TE_D + 0.1), 0.35), (0.85, 0.5), (1, 1)],
             color=CRYST, brightness=1.2, zoffset=50, ring_emit=center(0.0, 1.0), **SKY),
        dict(name="CoronaRays", texture="fx_halo", lifetime=(TE_D - TE_C + 0.6, TE_D - TE_C + 0.6),
             rotation=(0, 360), rot_speed=(7, 10),
             size=[(0, 0.95 * MD), (0.05, 1.32 * MD), (1, 1.42 * MD)],
             transparency=[(0, 1), (0.05, 0.4), (0.8, 0.5), (1, 1)], color=SILVER, brightness=1.3, zoffset=55,
             ring_emit=center(TE_C - 0.08, 1.0), **SKY),
        # la luna: mf_moon_eclipse_4x4 (cuadro 0 llena ... 15 tapada); vuelve a llena con la detonación
        dict(name="Moon", texture="mf_moon_eclipse_4x4", flipbook=("Grid4x4", "OneShot", 0, False),
             flip_t=[(0, 0), (fr(TE_C - 1.0), 0), (fr(TE_C), 15), (fr(TE_D - 0.01), 15), (fr(TE_D), 0), (1, 0)],
             lifetime=(ML, ML), size=[(0, 0.35 * MD), (0.05, 1.05 * MD), (0.09, MD), (1, MD)],
             transparency=[(0, 1), (0.04, 0.0), (0.88, 0.0), (1, 1)], color=MOONC, brightness=1.7, zoffset=60,
             ring_emit=center(0.0, 1.0), **SKY),
        dict(name="Corona", texture="kk_circle_02", lifetime=(TE_D - TE_C, TE_D - TE_C),
             size=[(0, 1.9 * MD), (0.04, 1.5 * MD), (1, 1.55 * MD)], transparency=[(0, 0.0), (0.9, 0.1), (1, 1)],
             color=SILVER, brightness=2.6, zoffset=62, ring_emit=center(TE_C, 1.0), **SKY),
        # el anillo de diamante: el último rayo de luna por el borde, justo antes de quedar tapada
        dict(name="DiamondGlow", texture="fx_glow", lifetime=(0.45, 0.45),
             size=[(0, 0.1 * MD), (0.2, 0.5 * MD), (1, 0.3 * MD)], transparency=[(0, 0.2), (0.6, 0.4), (1, 1)],
             slide=[(0, 0.29 * MD, 0.27 * MD), (1, 0.29 * MD, 0.27 * MD)], color=ICE, brightness=2.4, zoffset=64,
             ring_emit=center(TE_C - 0.06, 1.0), **SKY),
        dict(name="DiamondStar", texture="kk_star_09", lifetime=(0.45, 0.45), rotation=(10, 20),
             size=[(0, 0.05 * MD), (0.18, 1.1 * MD), (1, 0.15 * MD)], transparency=[(0, 0.0), (1, 0.4)],
             slide=[(0, 0.29 * MD, 0.27 * MD), (1, 0.29 * MD, 0.27 * MD)], color=GLINT, brightness=3.0,
             zoffset=65, ring_emit=center(TE_C - 0.06, 1.0), **SKY),
        # la luz vuelve de golpe con la detonación
        dict(name="MoonReturn", texture="fx_glow", lifetime=(0.6, 0.6),
             size=[(0, 0.9 * MD), (0.2, 1.7 * MD), (1, 1.9 * MD)], transparency=[(0, 0.1), (0.4, 0.5), (1, 1)],
             color=ICE, brightness=2.4, zoffset=63, ring_emit=center(TE_D, 1.0), **SKY),
        # la cabeza de la columna que baja de la luna al suelo en 0.12 s
        dict(name="DropHead", texture="fx_glow", direction="Bottom", speed_h=(8.2, 8.2), lifetime=(0.12, 0.12),
             size=[(0, 1.0 * ER), (1, 1.5 * ER)], transparency=[(0, 0.1), (1, 0.25)], color=ICE, brightness=2.0,
             ring_emit=center(TE_C, 1.0), **SKY),

        # ================= el suelo: círculo lunar, sombra, grietas y escarcha =================
        dict(name="ZoneShade", texture="fx_glow", rel="r", lifetime=(TE_D + 1.3, TE_D + 1.3),
             size=[(0, 0.4 * ER), (0.1, 2.5 * ER), (1, 2.6 * ER)], transparency=[(0, 1), (0.08, 0.4), (0.85, 0.45),
                                                                                 (1, 1)],
             color=NIGHT, ring_emit=center(0.05, 0.1), **DECAL),
        dict(name="Sigil", texture="mf_eclipse_sigil", rel="r", lifetime=(TE_D + 0.05, TE_D + 0.05),
             rotation=(0, 360), rot_speed=(6, 6),
             size=[(0, 1.25 * SIGIL_D), (0.06, SIGIL_D), (1, SIGIL_D)],
             transparency=[(0, 1), (0.05, 0.15), (0.3, 0.05), (0.97, 0.05), (1, 1)], color=FROSTY,
             light_emission=1.0, ring_emit=center(0.05, 0.16), **DECAL),
        dict(name="SigilFlash", texture="mf_eclipse_sigil", rel="r", lifetime=(0.5, 0.5), rotation=(0, 360),
             size=[(0, SIGIL_D), (1, 1.06 * SIGIL_D)], transparency=[(0, 0.0), (1, 1)], color=WHITE,
             light_emission=1.0, ring_emit=center(TE_I, 0.2), **DECAL),
        dict(name="ZoneCracks", texture="mf_frost_cracks", rel="r", lifetime=(TE_D + 1.0, TE_D + 1.0),
             rotation=(0, 360), size=[(0, 0.2 * ER), (0.08, 1.1 * ER), (1, 1.15 * ER)],
             transparency=[(0, 1), (0.05, 0.3), (0.85, 0.35), (1, 1)], color=FROST, light_emission=0.85,
             ring_emit=center(0.15, 0.18), **DECAL),
        dict(name="ZoneCracksOut", texture="mf_frost_cracks", rel="r", lifetime=(TE_D + 0.6, TE_D + 0.6),
             rotation=(0, 360), size=[(0, 0.15 * ER), (0.08, 0.75 * ER), (1, 0.8 * ER)],
             transparency=[(0, 1), (0.05, 0.35), (0.85, 0.4), (1, 1)], color=FROST, light_emission=0.85,
             ring_emit=[(round(0.25 + 0.5 * (e[3] - 0.4) / 0.55, 3), 1, e[2], e[3], 0.19)
                        for e in scatter(g, 14, 0.0, (0.4, 0.95), 0.19)], **DECAL),
        # al caer la columna el suelo se congela (de adentro hacia afuera)
        dict(name="FrostSheet", texture="mf_frost_patch", rel="r", lifetime=(TE_D + 1.4 - TE_I, TE_D + 1.4 - TE_I),
             rotation=(0, 360), size=[(0, 0.3 * ER), (0.06, 0.8 * ER), (1, 0.85 * ER)],
             transparency=[(0, 1), (0.05, 0.25), (0.85, 0.3), (1, 1)], color=FROSTY, light_emission=0.5,
             ring_emit=center(TE_I, 0.2) + [(round(TE_I + 0.25 * e[3], 3), 1, e[2], e[3], 0.2)
                                             for e in scatter(g, 16, 0.0, (0.3, 0.95), 0.2)], **DECAL),
        dict(name="GroundGlow", texture="fx_glow", rel="r", lifetime=(0.55, 0.65),
             size=[(0, 2.0 * ER), (1, 2.3 * ER)], transparency=[(0, 1), (0.3, 0.45), (0.7, 0.55), (1, 1)], color=ICE,
             light_emission=1.0, ring_emit=pulses(TE_I, TE_E, 0.45), **DECAL),
        dict(name="PulseRing", texture="kk_circle_02", rel="r", lifetime=(0.55, 0.55),
             size=[(0, 0.25 * D), (1, 1.05 * D)], transparency=[(0, 0.4), (0.6, 0.55), (1, 1)], color=ICE,
             light_emission=0.9, ring_emit=pulses(TE_I + 0.45, TE_E - 0.2, 0.45), **DECAL),
        dict(name="ShockRing", texture="kk_circle_02", rel="r", lifetime=(0.6, 0.6),
             size=[(0, D), (1, D * 2.4)], transparency=[(0, 0.15), (0.5, 0.45), (1, 1)], color=ICE,
             light_emission=0.8, ring_emit=center(TE_I, 0.21), **DECAL),
        dict(name="ShockRingSharp", texture="kk_circle_02", rel="r", lifetime=(0.42, 0.42),
             size=[(0, D), (1, D * 3.0)], transparency=[(0, 0.05), (0.6, 0.4), (1, 1)], color=SILVER,
             light_emission=0.9, ring_emit=center(TE_I, 0.22), **DECAL),
        dict(name="DetRing", texture="kk_circle_02", rel="r", lifetime=(0.7, 0.7),
             size=[(0, 0.3 * D), (1, D * 2.6)], transparency=[(0, 0.1), (0.5, 0.4), (1, 1)], color=ICE,
             light_emission=0.9, ring_emit=center(TE_D, 0.23), **DECAL),
        dict(name="DetRingSharp", texture="kk_circle_02", rel="r", lifetime=(0.5, 0.5),
             size=[(0, 0.3 * D), (1, D * 3.4)], transparency=[(0, 0.0), (0.6, 0.4), (1, 1)], color=SILVER,
             light_emission=1.0, ring_emit=center(TE_D, 0.24), **DECAL),

        # ================= la carga: brillos, hielo que flota hacia la luna y niebla que entra =================
        dict(name="ChargeRise", texture="kk_star_06", rel="r", direction="Top", speed=(14, 28), lifetime=(0.8, 1.2),
             size=twinkle(1.7), color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45),
             ring_emit=scatter(g, 170, (0.05, TE_C), (0.08, 1.0), (1.0, 5.0))),
        dict(name="ChargeIce", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", direction="Top", spread=(15, 15),
             speed=(8, 16), drag=0.6, accel=(0, 6, 0), lifetime=(1.0, 1.4),
             size=[(0, 0.5), (0.15, 2.2, 0.6), (0.85, 2.2, 0.6), (1, 0)], transparency=[(0, 0), (0.85, 0.1), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.4, rotation=(0, 360), rot_speed=(-120, 120),
             ring_emit=scatter(g, 110, (0.1, TE_C - 0.15), (0.12, 1.0), (0.5, 2.0))),
        dict(name="InflowMist", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Back",
             spread=(14, 6), speed=(26, 46), drag=1.2, lifetime=(1.5, 2.0),
             size=[(0, 18, 3), (1, 40, 5)], transparency=[(0, 1), (0.25, 0.55), (0.75, 0.68), (1, 1)],
             color=ICE_FOG, light_emission=0.15, rotation=(0, 360), rot_speed=(-25, 25), zoffset=-3,
             ring_emit=ring(0.1, 26, 1.06, 14.0) + ring(0.45, 26, 1.06, 14.0, a0=0.5 / 26) +
             ring(0.8, 26, 1.06, 14.0)),

        # ================= la columna (además de los Beams): lo que cae y lo que sube de la base =================
        dict(name="FallingStreaks", texture="kk_trace_01", rel="r", hu="H", orientation="VelocityParallel",
             direction="Bottom", speed_h=(0.9, 1.4), lifetime=(0.25, 0.4), size=[(0, 14), (0.3, 55), (1, 30)],
             color=ICE, light_emission=1.0, brightness=1.4, zstream=EW(200),
             zdist={"r": (0.05, 1.0), "h": (0.2, 0.62), "area": True}),
        dict(name="FallingStars", texture="fx_spark002", rel="r", hu="H", direction="Bottom", speed_h=(0.2, 0.32),
             lifetime=(0.8, 1.2), size=twinkle(2.2), color=GLINT, light_emission=1.0, brightness=2.0,
             rotation=(0, 45), zstream=EW(160), zdist={"r": (0.0, 1.05), "h": (0.1, 0.62), "area": True}),
        dict(name="BaseMist", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Front", spread=(30, 10),
             speed=(6, 16), drag=0.8, accel=(0, 2, 0), lifetime=(1.4, 2.0), size=[(0, 30, 4), (1, 55, 6)],
             transparency=[(0, 1), (0.25, 0.6), (0.8, 0.74), (1, 1)], color=ICE_FOG, light_emission=0.2,
             rotation=(0, 360), rot_speed=(-20, 20), zoffset=-5, zstream=EW(36),
             zdist={"r": (0.55, 1.12), "h": (18.0, 26.0)}),
        dict(name="GroundSpikes", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", orientation="VelocityParallel",
             direction="Top", spread=(18, 18), speed=(22, 34), drag=12, lifetime=(1.3, 1.6),
             size=[(0, 0.5), (0.12, 11, 3), (0.85, 11.5, 3), (1, 0)], transparency=[(0, 0), (0.85, 0.1), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.5,
             ring_emit=[(round(TE_I + 0.25 * e[3] + 0.03 * g.random(), 3), 1, e[2], e[3], 0.5)
                        for e in scatter(g, 90, 0.0, (0.15, 1.0), 0.5)]),

        # ================= el golpe: destello, estrella, polvo que rueda hacia afuera, esquirlas =================
        dict(name="ImpactFlash", texture="fx_glow", lifetime=(0.28, 0.28),
             size=[(0, 30), (0.2, 2.4 * ER), (1, 2.6 * ER)], transparency=[(0, 0.25), (0.3, 0.6), (1, 1)], color=ICE,
             brightness=2.0, zoffset=4, ring_emit=center(TE_I, 30.0), **BIG),
        dict(name="ImpactStar", texture="kk_star_09", lifetime=(0.35, 0.35), rotation=(0, 90),
             size=[(0, 40), (0.15, 3.2 * ER), (1, 40)], color=GLINT, brightness=2.5, zoffset=5,
             ring_emit=center(TE_I, 30.0), **BIG),
        dict(name="DustRing", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Front", spread=(10, 6),
             speed=(60, 110), drag=2.2, accel=(0, 3, 0), lifetime=(1.4, 2.0), size=[(0, 20, 3), (1, 52, 6)],
             transparency=[(0, 0.35), (0.3, 0.5), (1, 1)], color=ICE_FOG, light_emission=0.15, rotation=(0, 360),
             rot_speed=(-30, 30), zoffset=-2, ring_emit=ring(TE_I + 0.06, 40, 0.98, 17.0)),
        dict(name="DustRingHigh", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Front", pitch=35,
             spread=(12, 10), speed=(50, 90), drag=2.0, accel=(0, 4, 0), lifetime=(1.2, 1.8),
             size=[(0, 18, 3), (1, 44, 5)], transparency=[(0, 0.45), (0.3, 0.55), (1, 1)], color=ICE_FOG,
             light_emission=0.2, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-2,
             ring_emit=ring(TE_I + 0.1, 28, 0.95, 26.0, a0=0.5 / 28)),
        dict(name="EdgeShards", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", direction="Front", pitch=45,
             spread=(25, 20), speed=(60, 120), drag=0.4, accel=(0, -140, 0), lifetime=(0.9, 1.3),
             size=[(0, 3.2, 0.8), (1, 2.2, 0.6)], transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD,
             light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500),
             ring_emit=ring(TE_I + 0.08, 60, 0.97, 3.0)),

        # ================= la detonación: la columna colapsa y todo el hielo revienta =================
        dict(name="CollapseGlow", texture="fx_glow", hu="H", lifetime=(0.3, 0.3), direction="Bottom",
             speed_h=(2.2, 2.2), size=[(0, 0.8 * ER), (1, 0.4 * ER)], transparency=[(0, 0.2), (1, 0.4)], color=ICE,
             brightness=2.2, ring_emit=center(TE_E - 0.02, 0.85), **BIG),
        dict(name="DetFlash", texture="fx_glow", lifetime=(0.38, 0.38),
             size=[(0, 40), (0.15, 2.5 * ER), (1, 2.7 * ER)], transparency=[(0, 0.25), (0.3, 0.6), (1, 1)],
             color=ICE, brightness=2.4, zoffset=4, ring_emit=center(TE_D, 40.0), **BIG),
        dict(name="DetStar", texture="kk_star_09", lifetime=(0.4, 0.4), rotation=(0, 90),
             size=[(0, 60), (0.15, 3.8 * ER), (1, 60)], color=GLINT, brightness=2.8, zoffset=5,
             ring_emit=center(TE_D, 40.0), **BIG),
        dict(name="DetDome", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Front", pitch=30,
             spread=(14, 12), speed=(70, 130), drag=2.0, accel=(0, 3, 0), lifetime=(1.3, 1.9),
             size=[(0, 26, 4), (1, 70, 8)], transparency=[(0, 0.3), (0.3, 0.5), (1, 1)], color=ICE_FOG,
             light_emission=0.25, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-1,
             ring_emit=ring(TE_D, 34, 0.35, 26.0) + ring(TE_D, 20, 0.12, 48.0, a0=0.025)),
        dict(name="DetShards", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", direction="Top", spread=(70, 70),
             speed=(60, 140), drag=0.4, accel=(0, -150, 0), lifetime=(0.9, 1.4), size=[(0, 4.5, 1.2), (1, 3, 0.8)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.5,
             rotation=(0, 360), rot_speed=(-500, 500), ring_emit=scatter(g, 70, (TE_D, TE_D + 0.05), (0.0, 1.0),
                                                                         (5.0, 25.0), n=2)),
        dict(name="DetGlitter", texture="kk_star_06", rel="r", direction="Top", speed=(4, 14), drag=0.8,
             accel=(0, -6, 0), lifetime=(1.4, 2.2), size=twinkle(1.8), color=GLINT, light_emission=1.0,
             brightness=2.2, rotation=(0, 45), ring_emit=scatter(g, 170, (TE_D, TE_D + 0.5), (0.0, 1.1),
                                                                 (8.0, 70.0))),
        dict(name="AfterMist", texture="fx_smoke_2x2", flipbook=STATIC2x2, rel="r", direction="Top", spread=(60, 60),
             speed=(2, 6), drag=1, lifetime=(1.8, 2.4), size=[(0, 22, 3), (1, 44, 5)],
             transparency=[(0, 1), (0.3, 0.68), (0.8, 0.78), (1, 1)], color=ICE_FOG, light_emission=0.2,
             rotation=(0, 360), rot_speed=(-15, 15), zoffset=-4,
             ring_emit=scatter(g, 36, (TE_D + 0.1, TE_D + 0.6), (0.1, 1.0), (15.0, 20.0))),
    ]
    return L


# las columnas de luz: Beams que miran a la cámara (sin tope de tamaño). drop = cuándo y en cuánto bajan de la luna;
# width × radio; tex_len × altura; r_t encoge el anillo de cortinas al colapsar.
W_T = [(TE_C, 0.35), (TE_I, 1.1), (TE_I + 0.12, 1.0), (TE_E - 0.05, 1.0), (TE_E + 0.18, 0.05), (TE_D - 0.02, 0.03),
       (TE_D, 0.0)]
A_T = [(TE_C, 0.4), (TE_I, 0.0), (TE_E, 0.0), (TE_E + 0.2, 0.2), (TE_D, 0.5)]
R_T = [(TE_E - 0.05, 1.0), (TE_E + 0.18, 0.04)]
DROP = dict(drop=(TE_C, TE_I - TE_C), h=(0.0, 0.985))
TOPFADE = [(0, 1), (0.3, 1), (0.42, 0.42)]   # arriba no se ve (la tapa la luna): sale de debajo del disco
ECLIPSE_ZBEAMS = [
    # la línea guía que baja justo antes de la columna
    dict(name="Guide", texture="mf_blade_line", count=1, width=0.016, tex_len=1.0, speed=0.0, color=WHITE,
         transparency=[(0, 0.1), (1, 0.1)], brightness=2.4, light_emission=1.0, drop=(TE_C - 0.28, 0.14),
         h=(0.0, 0.985), width_t=[(TE_C - 0.28, 1.0), (TE_C, 1.6), (TE_I, 0.0)],
         alpha_t=[(TE_C - 0.28, 0.0), (TE_I - 0.03, 0.0), (TE_I, 1.0)]),
    # cortinas de luz en un anillo: de lejos se suman en los bordes (la columna se ve redonda) y desde adentro rodean
    dict(name="Curtain", texture="mf_moonbeam", count=14, r=0.74, spin=10, width=0.55, tex_len=0.35, speed=1.3,
         color=[(0, (215, 232, 255)), (0.5, (165, 208, 255)), (1, (130, 185, 255))],
         transparency=TOPFADE + [(0.92, 0.34), (1, 0.45)], brightness=1.0, light_emission=1.0,
         width_t=W_T, alpha_t=A_T, r_t=R_T, near=0.85, wobble=0.05, **DROP),
    dict(name="Body", texture="mf_moonbeam", count=1, width=1.6, tex_len=0.5, speed=0.9, a0=0.13,
         color=[(0, (150, 195, 255)), (1, (90, 150, 250))], transparency=[(0, 1), (0.3, 1), (0.42, 0.6),
                                                                           (1, 0.62)],
         brightness=0.85, light_emission=1.0, width_t=W_T, alpha_t=A_T, near=0.75, wobble=0.03, **DROP),
    dict(name="Heart", texture="mf_blade_glow", count=1, width=0.5, tex_len=1.0, speed=0.0,
         color=[(0, (255, 255, 255)), (1, (215, 235, 255))], transparency=[(0, 1), (0.3, 1), (0.42, 0.25),
                                                                            (1, 0.2)],
         brightness=1.5,
         light_emission=1.0, width_t=W_T, alpha_t=A_T, near=0.6, **DROP),
    dict(name="Core", texture="mf_blade_line", count=1, width=0.08, tex_len=1.0, speed=0.0, color=WHITE,
         transparency=[(0, 1), (0.3, 1), (0.42, 0.0), (1, 0.0)], brightness=2.4, light_emission=1.0,
         width_t=[(TE_C, 0.6), (TE_I, 1.2), (TE_I + 0.1, 1.0), (TE_E, 1.0), (TE_E + 0.15, 1.5), (TE_D - 0.03, 1.8),
                  (TE_D, 0.0)], alpha_t=[(TE_C, 0.2), (TE_I, 0.0)], **DROP),
    # el contorno: dos líneas finas en los bordes de la columna vista desde la cámara
    dict(name="Rim", texture="mf_blade_line", rim=True, r=1.0, width=0.022, tex_len=1.0, speed=0.0,
         color=[(0, (235, 245, 255)), (1, (175, 215, 255))], transparency=[(0, 1), (0.3, 1), (0.42, 0.1),
                                                                            (1, 0.15)],
         brightness=2.2, light_emission=1.0, width_t=W_T, alpha_t=A_T, r_t=R_T, **DROP),
]

# los cristales de hielo (Parts de material Ice) y las losas del suelo: brotan con la onda que sale del centro
CROWN_BREAK = [dict(name="CrownBreak", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0, 10)],
                    shape={"type": "Box", "size": (7, 26, 7)}, direction="Top", spread=(85, 85), speed=(25, 60),
                    drag=0.4, accel=(0, -120, 0), lifetime=(0.7, 1.1), size=[(0, 3.2, 0.8), (1, 2.2, 0.6)],
                    transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.5,
                    rotation=(0, 360), rot_speed=(-500, 500)),
               dict(name="CrownBreakGlint", texture="kk_star_06", emit=[(0, 3)],
                    shape={"type": "Box", "size": (8, 24, 8)}, direction="Top", spread=(80, 80), speed=(3, 9),
                    drag=2, lifetime=(0.4, 0.7), size=twinkle(1.8), color=GLINT, light_emission=1.0, brightness=2.2,
                    rotation=(0, 45)),
               dict(name="CrownBreakMist", texture="fx_smoke_2x2", flipbook=STATIC2x2, emit=[(0, 1)],
                    offset=(0, 10, 0), direction="Top", spread=(60, 60), speed=(4, 10), drag=1.5, accel=(0, 2, 0),
                    lifetime=(0.9, 1.3), size=[(0, 12, 2), (1, 26, 3)], transparency=[(0, 0.5), (0.4, 0.62), (1, 1)],
                    color=FROSTMIST, light_emission=0.2, rotation=(0, 360), zoffset=-1)]
FIELD_BREAK = [dict(L, emit=[(0, max(1, L["emit"][0][1] // 2))],
                    shape={"type": "Box", "size": tuple(v * 0.6 for v in L["shape"]["size"])} if L.get("shape") else None)
               if L.get("shape") else dict(L) for L in CROWN_BREAK]
ICE_PART = {"color": CRYSTAL_RGB, "material": "Ice", "transparency": 0.22}
ECLIPSE_FIELD = {
    "seed": 23,
    "groups": [
        # la corona: picos de hielo gigantes en el borde, inclinados hacia afuera
        {"name": "IceCrown", "count": 40, "ring": True, "r": (0.96, 1.04), "lean": "radial",
         "wid": (3.5, 6.0), "thick": (18.0, 34.0), "len": (3.5, 6.0), "tilt": (22, 42), "yaw": 25, "pitch": 8,
         "show": 0.85, "rise": 0.16, "t": TE_I + 0.02, "sweep": 0.2, "delay": (0.0, 0.06),
         "end_at": (TE_D, TE_D + 0.05), "big": {"frac": 0.2, "k": 1.35}, "end": "shatter", "shatter": CROWN_BREAK,
         "ice": ICE_PART, "tip": 0.8},
        # el campo de cristales: brotan con la onda que sale del centro
        {"name": "IceCrystals", "count": 60, "r": (0.12, 0.9), "lean": "radial",
         "wid": (2.5, 4.5), "thick": (8.0, 18.0), "len": (2.5, 4.5), "tilt": (10, 40), "yaw": 30, "pitch": 12,
         "show": 0.75, "rise": 0.12, "t": TE_I, "sweep": 0.22, "delay": (0.0, 0.05),
         "end_at": (TE_D - 0.02, TE_D + 0.08), "big": {"frac": 0.15, "k": 1.5}, "end": "shatter",
         "shatter": FIELD_BREAK, "ice": ICE_PART, "tip": 0.8},
        # losas del suelo que saltan inclinadas hacia afuera (color y material del suelo) y se hunden al final
        {"name": "ZoneSlabs", "count": 70, "r": (0.1, 1.0), "lean": "radial",
         "wid": (4.0, 8.0), "thick": (1.0, 2.0), "len": (4.0, 8.0), "tilt": (15, 45), "yaw": 14, "pitch": 10,
         "show": 0.6, "rise": 0.08, "t": TE_I, "sweep": 0.25, "delay": (0.0, 0.05), "sink": 0.5,
         "end_at": (TE_D + 0.3, TE_D + 0.8), "ground": True, "preview_color": SLAB_RGB},
    ],
}

ECLIPSE_CUBES = {
    "gravity": 160, "bounce": 0.32, "friction": 0.55, "spin": (240, 820),
    "rest": (0.5, 1.3), "fade": 0.35, "settle": 0.12, "shrink": (0.16, 0.26), "dissolve_time": (0.18, 0.6),
    "color_var": (0.72, 1.08), "dark": 0.15,
    # parte de los pedazos son cristal brillante (en hielo y plata); el resto, del color del suelo
    "neon_colors": [(150, 205, 255), (90, 150, 255), (220, 238, 255), (120, 175, 255)],
    "preview_color": (112, 110, 118),
    "fx": dict(name="CubeDissolve", texture="fx_spark002", direction="Top", spread=(180, 180), speed=(4, 12),
               lifetime=(0.25, 0.4), size=[(0, 0), (0.2, 2.2), (1, 0)], color=GLINT, light_emission=1.0,
               brightness=1.7, rotation=(0, 45), emit_n=2),
    "groups": [
        {"name": "Lift", "mode": "lift", "count": 90, "t": (0.15, 1.0), "r": (0.1, 0.95), "size": (0.5, 3.0),
         "skew": 2.2, "lift": (3.0, 14.0), "release": (TE_I, TE_I + 0.05), "out": (25, 70), "up": (50, 110),
         "dissolve": 0.35, "neon": 0.4},
        {"name": "Blast", "mode": "blast", "count": 260, "t": (TE_I, TE_I + 0.08), "r": (0.15, 1.05),
         "size": (0.4, 3.2), "skew": 2.6, "out": (25, 90), "up": (35, 110), "dissolve": 0.35, "neon": 0.3},
        {"name": "DetBlast", "mode": "blast", "count": 140, "t": (TE_D, TE_D + 0.05), "r": (0.05, 0.9),
         "size": (0.4, 2.6), "skew": 2.4, "out": (40, 120), "up": (40, 120), "dissolve": 0.5, "neon": 0.5},
    ],
}

ECLIPSE = {
    "name": "Eclipse",
    "doc": ("MOONFANG SKILL 4 (Eclipse, la ULTIMATE): una luna gigante aparece sobre la zona y se eclipsa mientras en "
            "el suelo se dibuja el círculo lunar y el hielo flota hacia ella; al quedar tapada cae una columna de luz "
            "de luna del ancho de toda la zona que congela el suelo (corona de picos de hielo en el borde, campo de "
            "cristales, escombros); al final la columna colapsa y todo el hielo revienta en una detonación. "
            "cf = centro de la zona en el suelo. Golpes: la columna a los "
            f"{TE_I:g} s y la detonación a los {TE_D:g} s (ver EclipseTimes)."),
    "duration": TE_D + 1.4,
    "zone": {"radius": ER, "height": EH, "charge": TE_C, "collapse": TE_E},
    "times": {"Eclipse": TE_C, "Impact": TE_I, "Collapse": TE_E, "Detonation": TE_D},
    "shake_ramp": (0.0, TE_E, 0.15, 1.3, 1.8),
    "shakes": [(TE_I, 2.2, 0.8), (TE_D, 2.6, 1.0)],
    "lights": [
        {"t": 0.3, "h": 10, "color": (150, 190, 255), "brightness": 1.5, "range": 60, "rise": 0.8, "hold": 0.2,
         "fall": 0.3, "ring": (6, 0.6)},
        {"t": TE_I, "h": 8, "color": (190, 225, 255), "brightness": 10, "range": 60, "rise": 0.03, "hold": 0.08,
         "fall": 0.6},
        {"t": TE_I, "h": 8, "color": (190, 225, 255), "brightness": 10, "range": 60, "rise": 0.03, "hold": 0.08,
         "fall": 0.6, "ring": (6, 0.62)},
        {"t": TE_I + 0.1, "h": 14, "color": (150, 200, 255), "brightness": 4, "range": 60, "rise": 0.1,
         "hold": TE_E - TE_I - 0.3, "fall": 0.3, "ring": (6, 0.55)},
        {"t": TE_D, "h": 10, "color": (200, 230, 255), "brightness": 12, "range": 60, "rise": 0.02, "hold": 0.05,
         "fall": 0.8},
        {"t": TE_D, "h": 10, "color": (200, 230, 255), "brightness": 12, "range": 60, "rise": 0.02, "hold": 0.05,
         "fall": 0.8, "ring": (8, 0.6)},
    ],
    # el mundo se oscurece mientras la luna se eclipsa y la pantalla destella con el golpe y la detonación
    "screen": {
        "range": 3.0,
        "cc": [(0.0, 0, 0, 0, 255, 255, 255), (TE_C - 0.9, -0.04, 0.04, -0.08, 228, 236, 255),
               (TE_C, -0.16, 0.14, -0.22, 188, 204, 255), (TE_E, -0.16, 0.14, -0.22, 188, 204, 255),
               (TE_D, 0.06, 0.1, -0.1, 232, 242, 255), (TE_D + 1.3, 0, 0, 0, 255, 255, 255)],
        "flash": [(TE_I, 0.45, 0.03, 0.35), (TE_D, 0.6, 0.03, 0.55)],
        "flash_color": (226, 238, 255),
    },
    "cubes": ECLIPSE_CUBES,
    "zbeams": ECLIPSE_ZBEAMS,
    "zfield": ECLIPSE_FIELD,
    "layers": eclipse_layers(random.Random(41)),
}


SPECS = {
    "MoonBite": MOON_BITE, "MoonBiteFinisher": MOON_BITE_FINISHER, "MoonFang": MOON_FANG,
    "MoonGuard": MOON_GUARD, "MoonGuardHit": MOON_GUARD_HIT,
    "CrescentWave": CRESCENT_WAVE, "IceWave": ICE_WAVE,
    "LunarHowl": LUNAR_HOWL, "LunarAura": LUNAR_AURA, "Eclipse": ECLIPSE,
}
