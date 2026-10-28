"""MOONFANG — lobo kaiju lunar de cristal. VFX de su kit completo.

Identidad: luz de luna FRÍA (plata y blanco), hielo y azul cristal, esquirlas afiladas, medias lunas y destellos de
estrella. Formas cortantes y brillantes (Omnívora, en cambio, es nebulosa suave, púrpura y agujeros negros).

  M1        MoonClaw (golpes 1-3) y MoonClawFinisher (golpe 4): garras de cristal sobre el rival
  BLOQUEO   MoonGuard (aura mientras bloquea) y MoonGuardHit (cada golpe bloqueado)
  PESADO    MoonFang: mordida lunar; brotan cristales de la herida y estallan
  SKILL 1   CrescentWave "Medialuna": una media luna de luz vuela a ras del suelo y lo corta
  SKILL 2   FangRain "Lluvia de colmillos": colmillos de cristal caen del cielo sobre una zona
  SKILL 3   LunarHowl "Aullido lunar" (el aullido y la luna llena) + LunarAura (la mejora)
  SKILL 4   Eclipse: una luna se eclipsa sobre la zona y cae una columna de luz de luna
Los golpes sobre el rival usan el marco de playHit (X = derecha de la pantalla, Y = arriba, +Z hacia la cámara;
tamaño 1 = rival de 22 studs). Las demás se escalan con `scale`.
"""
import math
import random

import vfx_aura as AU
from vfx_omnivora import scatter, center

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
def claw(t, size, direction="Bottom", name="Claw", bright=1.25):
    """Tres marcas curvas de garra que se desgarran (flipbook), su resplandor y el arco de la media luna."""
    return [
        dict(name=f"{name}Marks", texture="mf_claw_4x4", flipbook=ONESHOT, orientation="VelocityParallel",
             direction=direction, speed=(4, 4), emit=[(t, 1)], lifetime=(0.3, 0.3), size=[(0, size), (1, size * 1.04)],
             transparency=[(0, 0), (0.7, 0), (1, 1)], color=SILVER, light_emission=0.6, brightness=bright, zoffset=5),
        dict(name=f"{name}Glow", texture="mf_claw_glow", orientation="VelocityParallel", direction=direction,
             speed=(4, 4), emit=[(t + 0.03, 1)], lifetime=(0.34, 0.34), size=[(0, size * 1.1), (1, size * 1.18)],
             transparency=[(0, 0.5), (1, 1)], color=CRYST, light_emission=1.0, brightness=0.7, zoffset=4),
        dict(name=f"{name}Arc", texture="mf_crescent", orientation="VelocityParallel", direction=direction,
             speed=(4, 4), emit=[(t, 1)], lifetime=(0.18, 0.18), size=[(0, size * 0.7), (1, size * 1.2)],
             transparency=[(0, 0.45), (0.5, 0.7), (1, 1)], color=CRYST, light_emission=1.0, brightness=1.0, zoffset=3),
    ]


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


CLAWBOX = (14, 22, 1)

# ----------------------------------------------------------------------------- M1: golpes 1-3
T_CLAW = 0.05
MOON_CLAW = {
    "name": "MoonClaw",
    "doc": ("MOONFANG M1 (golpes 1 a 3): tres marcas de garra curvas en plata se desgarran sobre el rival, con "
            "esquirlas de cristal, chispas de hielo y destellos. Alterna el ángulo en cada golpe (35, -35, 70)."),
    "duration": 0.6,
    "hit": {"lift": 3, "ref": 22, "angle": 35, "angled": True, "impact": T_CLAW},
    "light": {"color": (170, 210, 255), "brightness": 3, "range": 22, "time": 0.25, "delay": T_CLAW},
    "shakes": [(T_CLAW, 0.4, 0.2)],
    "layers": claw(0.0, 26) + impact(T_CLAW) + side_sparks(T_CLAW, CLAWBOX) + shards(T_CLAW, 12, CLAWBOX)
    + glints(T_CLAW + 0.03, 6, (16, 24, 2)) + mist(T_CLAW + 0.01, 3, (10, 18, 1)),
}

# ----------------------------------------------------------------------------- M1: golpe 4 (remate)
T_FIN = 0.1
MOON_CLAW_FINISHER = {
    "name": "MoonClawFinisher",
    "doc": ("MOONFANG M1 (golpe 4, remate): dos zarpazos que se cruzan en X sobre el rival y revientan en un anillo "
            "de cristal con muchas esquirlas y destellos."),
    "duration": 0.85,
    "hit": {"lift": 3, "ref": 22, "angle": 45, "angled": True, "impact": T_FIN},
    "light": {"color": (180, 215, 255), "brightness": 5, "range": 28, "time": 0.35, "delay": T_FIN},
    "shakes": [(0.02, 0.3, 0.15), (T_FIN, 0.75, 0.3)],
    "layers": claw(0.0, 29, "Bottom", "ClawA") + claw(T_FIN - 0.02, 29, "Right", "ClawB", bright=1.35)
    + impact(T_FIN, flash=24, ring_=48, glow=0.6)
    + [dict(name="CrossBurst", texture="kk_star_08", emit=[(T_FIN, 1)], lifetime=(0.22, 0.22),
            size=[(0, 12), (0.3, 36), (1, 20)], transparency=[(0, 0.3), (1, 1)], color=ICE, light_emission=1.0,
            brightness=1.1, rotation=(45, 45), zoffset=7),
       dict(name="CrystalRing", texture="kk_circle_02", emit=[(T_FIN + 0.02, 1)], lifetime=(0.32, 0.32),
            size=[(0, 10), (1, 56)], transparency=[(0, 0.15), (0.6, 0.5), (1, 1)], color=ICE, light_emission=1.0,
            brightness=1.2, zoffset=2)]
    + side_sparks(T_FIN, (18, 18, 1), n=(18, 8)) + side_sparks(T_FIN, (18, 18, 1), n=(10, 6), dirs=("Top", "Bottom"),
                                                              name="SparksV")
    + shards(T_FIN, 24, (18, 18, 1), speed=(35, 75), size=1.7) + glints(T_FIN + 0.02, 10, (22, 22, 2), k=1.4)
    + mist(T_FIN + 0.01, 5, (14, 14, 1), size=(5, 14)),
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
# Una media luna de luz (geometría: cadenas de Beams en un arco 3D) que vuela con la PUNTA hacia adelante y los
# cuernos atrás. Su cuerno de abajo roza el suelo: lo corta (zanja oscura, grietas de escarcha, cristales que crecen
# en el corte) y arranca rocas que salen volando a los lados. Al llegar al final detona en hielo: destello, ondas,
# una nube de aire helado, ráfagas de viento frío que giran y corren por el suelo, una corona de púas, pedazos de
# hielo que se quedan clavados y escarcha que flota.
LW = 130.0                 # largo por defecto (escala 1)
T0 = 0.14                  # sale del zarpazo
TW = 0.62                  # tarda en recorrer la línea (la punta llega al final a los T0 + TW s)
TD = T0 + TW               # detona
BR, BARC, BTILT, BBOW = 20.0, 72.0, 18.0, 0.45         # radio del arco, medio ángulo, inclinación y curva de los cuernos
_ca, _sa = math.cos(math.radians(BARC)), math.sin(math.radians(BARC))
_ct, _st = math.cos(math.radians(BTILT)), math.sin(math.radians(BTILT))
CUT_LAG = BR * (1 - _ca) / LW                          # el cuerno de abajo va detrás de la punta (en fracción)
CUT_SIDE = -BR * _sa * _st + BBOW * BR * (1 - _ca) * _ct   # y corrido hacia un lado
NP = 26                    # puntos a lo largo del camino


def path(t0, n, per, up=0.0, side=0.0, jitter=0.0, seed=1, u0=0.03, u1=0.97, lag=0.0, jitter_up=0.0):
    """Eventos (t, n, u, lado, alto) a lo largo del camino, cuando pasa la hoja (lag = cuánto va detrás)."""
    g = random.Random(seed)
    out = []
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1)
        out.append((round(t0 + TW * min(u + lag, 1.0), 3), per, round(u, 3), round(side + g.uniform(-jitter, jitter), 2),
                    round(up + g.uniform(-jitter_up, jitter_up), 2)))
    return out


def cut(n, per, seed, jitter=1.5, up=0.2, u0=0.04, u1=0.94, side=0.0):
    """En el corte del suelo (donde pasa el cuerno de abajo)."""
    return path(T0, n, per, up=up, side=CUT_SIDE + side, jitter=jitter, seed=seed, u0=u0, u1=u1, lag=CUT_LAG)


BLADE = {
    "t0": T0, "travel": TW, "fade": 0.1, "grow": 0.1, "start_k": 0.35, "swell": 0.15,
    "radius": BR, "arc": BARC, "tilt": BTILT, "bow": BBOW, "lift": 0.6, "n": 19, "taper": 0.75,
    "light": {"color": (170, 210, 255), "brightness": 6, "range": 40},
    "layers": [
        # halo azul ancho (con su estela)
        {"name": "BladeGlow", "texture": "mf_blade_glow", "width": 17, "back": 1.5, "transparency": 0.35,
         "color": [(0, (40, 80, 210)), (0.5, (90, 150, 255)), (1, (40, 80, 210))], "light_emission": 1.0,
         "brightness": 1.0, "zoffset": -1, "ghosts": [(5, 0.35), (10, 0.6), (16, 0.8)]},
        # cuerpo de escarcha
        {"name": "BladeFrost", "texture": "mf_blade_frost", "width": 9, "back": 0.8, "transparency": 0.1,
         "color": [(0, (120, 175, 255)), (0.5, (200, 232, 255)), (1, (120, 175, 255))], "light_emission": 1.0,
         "brightness": 1.25, "ghosts": [(4, 0.4), (8, 0.7)]},
        # núcleo blanco y el filo de adelante
        {"name": "BladeCore", "texture": "mf_blade_core", "width": 3.4, "transparency": 0.0,
         "color": [(0, (190, 220, 255)), (0.5, (255, 255, 255)), (1, (190, 220, 255))], "light_emission": 1.0,
         "brightness": 1.8, "zoffset": 1, "ghosts": [(2.5, 0.5)]},
        {"name": "BladeEdge", "texture": "mf_blade_core", "width": 1.3, "back": -0.7, "transparency": 0.0,
         "color": [(0, (230, 245, 255)), (0.5, (255, 255, 255)), (1, (230, 245, 255))], "light_emission": 1.0,
         "brightness": 2.4, "zoffset": 2},
    ],
}

FROSTMIST = [(0, (220, 236, 255)), (1, (175, 200, 240))]
STONE = (98, 96, 108)
ROCK_LAND = [dict(name="RockPuff", texture="kk_smoke_04", emit=[(0, 2)], direction="Top", spread=(70, 70),
                  speed=(4, 10), drag=2, accel=(0, 3, 0), lifetime=(0.5, 0.8), size=[(0, 3, 1), (1, 8, 2)],
                  transparency=[(0, 0.5), (0.4, 0.6), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2)]
ROCK_CRUMBLE = [dict(name="RockCrumble", texture="kz_debris_2x2", flipbook=STATIC2x2, emit=[(0, 5)],
                     shape={"type": "Box", "size": (3, 2, 3)}, direction="Top", spread=(70, 70), speed=(6, 16),
                     drag=0.5, accel=(0, -110, 0), lifetime=(0.35, 0.55), size=[(0, 0.9, 0.3), (1, 0.7, 0.2)],
                     color=[(0, (120, 118, 128)), (1, (96, 94, 104))], rotation=(0, 360), rot_speed=(-400, 400)),
                dict(name="RockDust", texture="kk_smoke_04", emit=[(0, 2)], direction="Top", spread=(60, 60),
                     speed=(2, 6), drag=2, lifetime=(0.4, 0.6), size=[(0, 2, 0.5), (1, 6, 1)],
                     transparency=[(0, 0.6), (0.4, 0.65), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2)]


def rocks(name, direction, n_ev, per, size, speed, spread, seed, side=0.0, up=0.3):
    """Rocas del suelo que el corte arranca (Parts que vuelan, caen, se quedan un momento y se desmoronan)."""
    return dict(name=name, type="meteor", emit=cut(n_ev, per, seed, jitter=1.2, up=up, side=side),
                direction=direction, spread=spread, speed=speed, accel=(0, -196, 0), drag=0.1, lifetime=(2.2, 2.2),
                sprite={"texture": "kz_debris_2x2", "layout": "Grid2x2", "size": size, "aspect": (1.0, 0.75, 0.9),
                        "rot_speed": (-420, 420), "color": STONE, "material": "Slate", "stick": 0.55, "sink": 0.25},
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
    "doc": ("MOONFANG SKILL 1 (Medialuna): de un zarpazo lanza una media luna de luz que vuela con la punta hacia "
            "adelante; su cuerno de abajo corta el suelo y arranca rocas que salen volando a los lados; al llegar al "
            "final (0.76 s) detona en hielo: nube de aire helado, ráfagas de viento frío, púas, pedazos de hielo y "
            "escarcha flotando. MoonfangVFX.CrescentWave(CFrame.lookAt(origen, origen + dirección), largo, escala)."),
    "duration": 3.4,
    "line": LW,
    "blade": BLADE,
    "light": {"color": (180, 215, 255), "brightness": 5, "range": 40, "time": 0.3},
    "shakes": [(0.02, 0.45, 0.25), (T0 + 0.1, 0.25, TW), (TD, 1.0, 0.45)],
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
        # ---------------- el camino: lo que suelta la hoja ----------------
        dict(name="BladeMist", texture="kk_smoke_04", direction="Back", spread=(30, 30), speed=(3, 8), drag=2,
             accel=(0, 2, 0), lifetime=(0.6, 0.9), size=[(0, 6, 1.5), (1, 15, 3)],
             transparency=[(0, 0.62), (0.4, 0.68), (1, 1)], color=FROSTMIST, rotation=(0, 360), rot_speed=(-40, 40),
             zoffset=-3, emit=path(T0 + 0.02, NP, 1, up=12, jitter=6, jitter_up=7, seed=11)),
        dict(name="BladeShards", texture="mf_shard_2x2", flipbook=STATIC2x2, direction="Back", spread=(40, 40),
             speed=(8, 20), drag=0.6, accel=(0, -110, 0), lifetime=(0.5, 0.8), size=[(0, 1.2, 0.4), (1, 0.8, 0.3)],
             transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
             rotation=(0, 360), rot_speed=(-500, 500), emit=path(T0 + 0.01, NP, 2, up=14, jitter=9, jitter_up=8, seed=12)),
        dict(name="BladeGlints", texture="kk_star_06", direction="Back", spread=(60, 60), speed=(4, 10), drag=1.5,
             lifetime=(0.4, 0.7), size=twinkle(1.1), color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45),
             emit=path(T0 + 0.01, NP, 2, up=13, jitter=10, jitter_up=9, seed=13)),
        # ---------------- el corte del suelo ----------------
        dict(name="CutTrench", texture="kz_scorch", lifetime=(1.9, 2.1), rotation=(0, 360),
             size=[(0, 6), (0.06, 15), (1, 16)], transparency=[(0, 0.3), (0.75, 0.4), (1, 1)], color=NIGHT,
             emit=cut(NP, 1, 21, jitter=0.8, up=0.12), **DECAL),
        dict(name="CutCracks", texture="mf_frost_cracks", lifetime=(1.7, 1.9), rotation=(0, 360),
             size=[(0, 8), (0.06, 24), (1, 25)], transparency=[(0, 0), (0.3, 0.1), (0.8, 0.45), (1, 1)], color=FROST,
             light_emission=0.9, emit=cut(20, 1, 22, jitter=1.2, up=0.18), **DECAL),
        dict(name="CutGlow", texture="fx_glow", lifetime=(0.9, 1.1), size=[(0, 6), (0.1, 12), (1, 13)],
             transparency=[(0, 0.2), (0.6, 0.55), (1, 1)], color=ICE, light_emission=1.0,
             emit=cut(NP, 1, 23, jitter=0.5, up=0.24), **DECAL),
        dict(name="CutSparks", texture="kk_trace_01", orientation="VelocityParallel", direction="Back",
             spread=(30, 25), speed=(60, 110), drag=4, accel=(0, -30, 0), lifetime=(0.18, 0.3),
             size=[(0, 6, 1.5), (1, 2)], color=ICE, light_emission=1.0, brightness=2.0,
             emit=cut(NP, 3, 24, jitter=1.0, up=0.6)),
        dict(name="CutDebris", texture="kz_debris_2x2", flipbook=STATIC2x2, direction="Top", spread=(60, 60),
             speed=(30, 65), drag=0.4, accel=(0, -130, 0), lifetime=(0.6, 0.9), size=[(0, 1.1, 0.4), (1, 0.9, 0.3)],
             color=[(0, (130, 128, 138)), (1, (100, 98, 108))], rotation=(0, 360), rot_speed=(-500, 500),
             emit=cut(NP, 4, 25, jitter=1.5, up=0.5)),
        dict(name="CutDust", texture="kk_smoke_04", direction="Top", spread=(70, 70), speed=(8, 18), drag=2,
             accel=(0, 4, 0), lifetime=(0.6, 0.9), size=[(0, 5, 1), (1, 14, 3)],
             transparency=[(0, 0.5), (0.4, 0.6), (1, 1)], color=MIST, rotation=(0, 360), rot_speed=(-40, 40),
             zoffset=-2, emit=cut(NP, 2, 26, jitter=2.0, up=1.0)),
        dict(name="CutCrystals", texture="mf_spike", orientation="VelocityParallel", direction="Top", spread=(30, 30),
             speed=(14, 24), drag=13, lifetime=(1.0, 1.25), size=[(0, 0.5), (0.12, 5.5, 1.5), (0.8, 5.8, 1.5), (1, 0)],
             transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.5, brightness=1.5,
             emit=cut(16, 1, 27, jitter=2.2, up=0.4, u1=0.9)),
        rocks("RocksOut", "Left", 16, 1, (3.5, 8.0), (50, 95), (40, 25), 31, side=-1.5),
        rocks("RocksIn", "Right", 12, 1, (3.0, 6.5), (45, 85), (40, 25), 32, side=1.5),
        rocks("RocksUp", "Top", 10, 1, (4.0, 9.0), (55, 90), (22, 22), 33),
        # ---------------- la detonación de hielo ----------------
        dict(name="DetFlash", texture="fx_glow", emit=det_up(0.0, 1, 10), lifetime=(0.2, 0.22),
             size=[(0, 12), (0.3, 56), (1, 60)], transparency=[(0, 0.45), (0.5, 0.65), (1, 1)], color=CRYST,
             light_emission=1.0, brightness=1.0, zoffset=5),
        dict(name="DetStar", texture="kk_star_09", emit=det_up(0.0, 1, 10), lifetime=(0.26, 0.26),
             size=[(0, 16), (0.2, 70), (1, 24)], transparency=[(0, 0.05), (1, 1)], color=GLINT, light_emission=1.0,
             brightness=1.3, rotation=(0, 90), zoffset=6),
        dict(name="DetHalo", texture="fx_halo", emit=det_up(0.02, 1, 10), lifetime=(0.35, 0.35),
             size=[(0, 10), (1, 86)], transparency=[(0, 0.3), (0.5, 0.55), (1, 1)], color=CRYST, light_emission=1.0,
             brightness=1.1, rotation=(0, 360), zoffset=3),
        dict(name="DetRing", texture="kk_circle_02", emit=det_up(0.0, 1, 0.3), lifetime=(0.5, 0.5),
             size=[(0, 12), (1, 150)], transparency=[(0, 0.15), (0.5, 0.45), (1, 1)], color=ICE, light_emission=0.8,
             **DECAL),
        dict(name="DetRingSharp", texture="kk_circle_02", emit=det_up(0.03, 1, 0.32), lifetime=(0.34, 0.34),
             size=[(0, 10), (1, 120)], transparency=[(0, 0.05), (0.6, 0.4), (1, 1)], color=SILVER, light_emission=1.0,
             **DECAL),
        # el aire helado: una nube fría que se expande, ráfagas que giran y viento que corre por el suelo
        dict(name="ColdCloud", texture="kk_smoke_07", emit=det_up(0.01, 16, 8), shape={"type": "Sphere", "radius": 6},
             direction="Top", spread=(180, 180), speed=(25, 55), drag=3.2, accel=(0, 3, 0), lifetime=(1.3, 1.8),
             size=[(0, 10, 2), (0.3, 26, 4), (1, 34, 4)], transparency=[(0, 0.35), (0.3, 0.5), (0.8, 0.75), (1, 1)],
             color=FROSTMIST, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3),
        dict(name="ColdSwirl", texture="fx_wind_swirl", emit=det_up(0.0, 2, 10) + det_up(0.1, 1, 12),
             lifetime=(0.6, 0.8), size=[(0, 14), (1, 76)], transparency=[(0, 0.3), (0.5, 0.55), (1, 1)], color=ICE,
             light_emission=0.6, brightness=1.0, rotation=(0, 360), rot_speed=(-220, 220), zoffset=2),
        dict(name="ColdArcs", texture="kz_wind_arcs", emit=det_up(0.04, 3, 9), lifetime=(0.4, 0.55),
             size=[(0, 16), (1, 64)], transparency=[(0, 0.3), (0.6, 0.6), (1, 1)], color=SILVER, light_emission=0.7,
             brightness=1.1, rotation=(0, 360), rot_speed=(-180, 180), zoffset=2),
        dict(name="GroundGust", texture="kk_trace_03", orientation="VelocityParallel", emit=det_up(0.02, 26, 1.2),
             direction="Front", spread=(180, 5), speed=(90, 150), drag=3, lifetime=(0.4, 0.6),
             size=[(0, 10, 2), (0.4, 14, 3), (1, 4)], transparency=[(0, 0.2), (0.6, 0.45), (1, 1)], color=ICE,
             light_emission=1.0, brightness=1.4),
        dict(name="GroundMist", texture="kk_smoke_04", emit=det_up(0.03, 14, 1), direction="Front", spread=(180, 4),
             speed=(45, 80), drag=3.5, accel=(0, 2, 0), lifetime=(0.9, 1.3), size=[(0, 6, 1), (1, 18, 3)],
             transparency=[(0, 0.45), (0.4, 0.6), (1, 1)], color=FROSTMIST, rotation=(0, 360), zoffset=-2),
        # el hielo: esquirlas, una corona de púas y pedazos que se quedan clavados
        dict(name="DetShards", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=det_up(0.0, 40, 8),
             shape={"type": "Sphere", "radius": 4}, direction="Top", spread=(180, 180), speed=(45, 95), drag=0.5,
             accel=(0, -110, 0), lifetime=(0.6, 1.0), size=[(0, 2.0, 0.6), (1, 1.4, 0.4)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
             rotation=(0, 360), rot_speed=(-500, 500)),
        dict(name="IceCrown", texture="mf_spike", orientation="VelocityParallel", emit=det_up(0.04, 18, 0.5),
             shape={"type": "Box", "size": (26, 1, 26)}, direction="Top", spread=(25, 25), speed=(25, 40), drag=12,
             lifetime=(1.3, 1.5), size=[(0, 0.6), (0.1, 9, 2.5), (0.8, 9.5, 2.5), (1, 0)],
             transparency=[(0, 0), (0.8, 0.1), (1, 1)], color=SHARD, light_emission=0.5, brightness=1.6),
        dict(name="IceChunks", type="meteor", emit=det_up(0.02, 9, 4), direction="Top", spread=(70, 70),
             speed=(60, 105), accel=(0, -196, 0), drag=0.1, lifetime=(2.4, 2.4),
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
        dict(name="DetCracks", texture="mf_frost_cracks", emit=det_up(0.02, 1, 0.22), lifetime=(2.3, 2.5),
             rotation=(0, 360), size=[(0, 20), (0.06, 70), (1, 74)],
             transparency=[(0, 0), (0.25, 0.1), (0.8, 0.4), (1, 1)], color=FROST, light_emission=0.9, **DECAL),
        dict(name="DetFrost", texture="fx_glow", emit=det_up(0.05, 1, 0.16), lifetime=(2.2, 2.4),
             size=[(0, 30), (0.1, 72), (1, 76)], transparency=[(0, 0.5), (0.7, 0.6), (1, 1)], color=ICE,
             light_emission=0.4, **DECAL),
        dict(name="Snow", texture="fx_spark002", shape={"type": "Sphere", "radius": 26}, direction="Top",
             spread=(180, 180), speed=(2, 6), drag=1, accel=(0, -3, 0), lifetime=(1.4, 2.2), size=twinkle(0.55),
             color=GLINT, light_emission=1.0, brightness=1.8, rotation=(0, 45),
             emit=det_up(0.05, 40, 14)),
    ],
}

# ----------------------------------------------------------------------------- SKILL 2: Lluvia de colmillos
RR = 30.0                  # radio de la zona (escala 1)
T_FALL = (0.4, 1.3)        # cuándo caen los colmillos
FANGS_EMIT = [(0.40, 3), (0.52, 3), (0.64, 3), (0.76, 3), (0.88, 2), (1.0, 2), (1.12, 2), (1.24, 2)]
FANG_RAIN = {
    "name": "FangRain",
    "doc": ("MOONFANG SKILL 2 (Lluvia de colmillos): se marca un círculo de escarcha en el suelo y del cielo caen "
            "colmillos de cristal gigantes que se clavan, brillan y estallan en esquirlas. cf = centro de la zona en "
            "el suelo (radio 30 studs × escala). Los colmillos caen entre los 0.4 y los 1.3 s."),
    "duration": 3.4,
    "light": {"color": (170, 210, 255), "brightness": 3, "range": 50, "time": 1.6},
    "shakes": [(0.45, 0.3, 0.3), (0.7, 0.4, 0.3), (0.95, 0.45, 0.3), (1.2, 0.45, 0.3), (2.05, 0.35, 0.3)],
    "layers": [
        # la zona: anillo, grietas de escarcha y sombra fría
        dict(name="ZoneRing", texture="kk_circle_02", emit=[(0.0, 1)], offset=(0, 0.2, 0), lifetime=(2.4, 2.4),
             size=[(0, 3.39 * RR * 1.2), (0.08, 3.39 * RR), (1, 3.39 * RR)],
             transparency=[(0, 1), (0.06, 0.15), (0.85, 0.3), (1, 1)], color=ICE, light_emission=0.8, **DECAL),
        dict(name="ZoneCracks", texture="mf_frost_cracks", emit=[(0.05, 1)], offset=(0, 0.25, 0), lifetime=(2.6, 2.6),
             rotation=(0, 360), size=[(0, 0.6 * RR), (0.1, 2.3 * RR), (1, 2.4 * RR)],
             transparency=[(0, 1), (0.08, 0.2), (0.7, 0.35), (1, 1)], color=FROST, light_emission=0.8, **DECAL),
        dict(name="ZoneShade", texture="fx_glow", emit=[(0.02, 1)], offset=(0, 0.15, 0), lifetime=(3.0, 3.0),
             size=[(0, RR), (0.1, 2.3 * RR), (1, 2.4 * RR)], transparency=[(0, 1), (0.1, 0.45), (0.8, 0.5), (1, 1)],
             color=NIGHT, **DECAL),
        # destellos que suben de la zona y destellos en el cielo antes de que caigan
        dict(name="ZoneRise", texture="kk_star_06", shape={"type": "Box", "size": (1.6 * RR, 1, 1.6 * RR)},
             direction="Top", spread=(10, 10), speed=(10, 20), lifetime=(0.6, 1.0), size=twinkle(1.2), color=GLINT,
             light_emission=1.0, brightness=2.0, rotation=(0, 45), stream=[(0.05, 1.4, 40, 10)]),
        dict(name="SkyGlints", texture="kk_star_08", offset=(0, 95, 0),
             shape={"type": "Box", "size": (1.5 * RR, 6, 1.5 * RR)}, lifetime=(0.25, 0.35),
             size=[(0, 2), (0.3, 12, 3), (1, 0)], color=GLINT, light_emission=1.0, brightness=1.6, rotation=(0, 90),
             stream=[(0.1, 1.2, 22, 8)]),
        # los colmillos: piezas de cristal (material Ice) que caen derechas, se clavan y estallan
        dict(name="Fangs", type="meteor", emit=FANGS_EMIT, offset=(0, 100, 0),
             shape={"type": "Box", "size": (1.75 * RR, 4, 1.75 * RR)}, direction="Bottom", spread=(4, 4),
             speed=(150, 190), accel=(0, -220, 0), drag=0, lifetime=(2.0, 2.0),
             sprite={"texture": "mf_shard_2x2", "layout": "Grid2x2", "frame": 0, "size": (10, 15),
                     "aspect": (0.55, 2.4, 0.55), "upright": True, "stick": 0.85, "sink": 0.3,
                     "rot_speed": (0, 0), "color": CRYSTAL_RGB, "material": "Ice"},
             trails=[{"name": "FangTrail", "rate": 60, "texture": "kk_trace_01", "orientation": "VelocityParallel",
                      "speed": (0, 0), "lifetime": (0.12, 0.16), "size": [(0, 6, 1), (1, 2)], "color": ICE,
                      "light_emission": 1.0, "brightness": 1.6},
                     {"name": "FangGlow", "rate": 30, "texture": "fx_glow", "speed": (0, 0), "lifetime": (0.1, 0.14),
                      "size": [(0, 9), (1, 5)], "transparency": [(0, 0.5), (1, 1)], "color": CRYST,
                      "light_emission": 1.0, "brightness": 1.0},
                     {"name": "FangSparkle", "rate": 18, "texture": "fx_spark002", "speed": (0, 6),
                      "direction": "Top", "spread": (180, 180), "lifetime": (0.3, 0.5), "size": twinkle(0.5),
                      "color": GLINT, "light_emission": 1.0, "brightness": 1.8, "rotation": (0, 45)}],
             land=[dict(name="LandFlash", texture="fx_glow", emit=[(0, 1)], lifetime=(0.16, 0.18),
                        size=[(0, 6), (0.3, 20), (1, 22)], transparency=[(0, 0.4), (1, 1)], color=ICE,
                        light_emission=1.0, brightness=1.0),
                   dict(name="LandRing", texture="kk_circle_02", emit=[(0, 1)], lifetime=(0.35, 0.35),
                        size=[(0, 4), (1, 30)], transparency=[(0, 0.2), (0.6, 0.55), (1, 1)], color=ICE,
                        light_emission=0.9, **DECAL),
                   dict(name="LandCracks", texture="mf_frost_cracks", emit=[(0, 1)], lifetime=(1.6, 1.8),
                        rotation=(0, 360), size=[(0, 4), (0.1, 16), (1, 17)],
                        transparency=[(0, 0), (0.3, 0.15), (0.8, 0.45), (1, 1)], color=FROST, light_emission=0.9,
                        **DECAL),
                   dict(name="LandChips", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0, 8)],
                        direction="Top", spread=(70, 70), speed=(20, 45), drag=0.5, accel=(0, -110, 0),
                        lifetime=(0.45, 0.7), size=[(0, 1.2, 0.4), (1, 0.9, 0.3)], color=SHARD,
                        light_emission=0.45, brightness=1.4, rotation=(0, 360), rot_speed=(-500, 500)),
                   dict(name="LandMist", texture="kk_smoke_04", emit=[(0, 3)], direction="Top", spread=(80, 80),
                        speed=(6, 14), drag=2, accel=(0, 3, 0), lifetime=(0.6, 0.9), size=[(0, 5, 1), (1, 14, 2)],
                        transparency=[(0, 0.55), (0.4, 0.6), (1, 1)], color=MIST, rotation=(0, 360), zoffset=-2)],
             shatter=[dict(name="BreakFlash", texture="kk_star_06", emit=[(0, 1)], lifetime=(0.14, 0.16),
                           size=[(0, 6), (0.3, 18), (1, 10)], color=GLINT, light_emission=1.0, brightness=1.5,
                           rotation=(0, 360)),
                      dict(name="BreakShards", texture="mf_shard_2x2", flipbook=STATIC2x2, emit=[(0, 12)],
                           shape={"type": "Box", "size": (3, 10, 3)}, direction="Top", spread=(90, 90),
                           speed=(15, 40), drag=0.5, accel=(0, -110, 0), lifetime=(0.45, 0.75),
                           size=[(0, 1.6, 0.5), (1, 1.0, 0.3)], color=SHARD, light_emission=0.45, brightness=1.4,
                           rotation=(0, 360), rot_speed=(-500, 500)),
                      dict(name="BreakGlints", texture="fx_spark002", emit=[(0, 6)],
                           shape={"type": "Box", "size": (4, 10, 4)}, direction="Top", spread=(90, 90),
                           speed=(4, 10), lifetime=(0.4, 0.7), size=twinkle(0.7), color=GLINT, light_emission=1.0,
                           brightness=1.8, rotation=(0, 45))]),
    ],
}

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
ER, EH = 26.0, 150.0       # radio de la zona y altura de la luna (escala 1)
TE_C, TE_E = 1.0, 2.6      # la luna queda eclipsada y cae la columna / fin de la columna


def EW(rate, rin=0.08, rout=0.15):
    return [(TE_C, TE_C + rin, rate * 0.4, rate), (TE_C + rin, TE_E - rout, rate, rate), (TE_E - rout, TE_E, rate, 0.0)]


def eclipse_layers(g):
    D = 3.39 * ER
    L = [
        # ---------------- carga: la zona y la luna que se eclipsa ----------------
        dict(name="ZoneRing", texture="kk_circle_02", rel="r", lifetime=(TE_C + 0.2, TE_C + 0.2),
             size=[(0, 1.2 * D), (0.15, D), (1, D)], transparency=[(0, 1), (0.1, 0.15), (0.85, 0.1), (1, 1)],
             color=ICE, light_emission=0.8, ring_emit=center(0.0, 0.14), **DECAL),
        dict(name="ZoneCracks", texture="mf_frost_cracks", rel="r", lifetime=(3.4, 3.4), rotation=(0, 360),
             size=[(0, 0.4 * ER), (0.12, 2.2 * ER), (1, 2.3 * ER)],
             transparency=[(0, 1), (0.08, 0.3), (0.26, 0.15), (0.3, 0.02), (0.5, 0.2), (0.85, 0.35), (1, 1)],
             color=FROST, light_emission=0.85, ring_emit=center(0.1, 0.16), **DECAL),
        dict(name="ZoneShade", texture="fx_glow", rel="r", lifetime=(3.6, 3.6),
             size=[(0, 10), (0.15, 2.3 * ER), (1, 2.4 * ER)], transparency=[(0, 1), (0.12, 0.45), (0.8, 0.45), (1, 1)],
             color=NIGHT, ring_emit=center(0.05, 0.1), **DECAL),
        dict(name="Moon", texture="mf_moon", rel="r", hu="H", lifetime=(TE_E + 0.6, TE_E + 0.6),
             size=[(0, 1.0 * ER), (0.12, 2.6 * ER), (1, 2.7 * ER)],
             transparency=[(0, 1), (0.08, 0.0), (0.92, 0.1), (1, 1)], color=MOONC, light_emission=0.35,
             brightness=1.3, zoffset=-8, ring_emit=center(0.0, 1.0)),
        dict(name="MoonHalo", texture="fx_glow", rel="r", hu="H", lifetime=(TE_E + 0.6, TE_E + 0.6),
             size=[(0, 2 * ER), (0.12, 5.0 * ER), (1, 5.2 * ER)], transparency=[(0, 1), (0.1, 0.45), (0.9, 0.5), (1, 1)],
             color=CRYST, light_emission=1.0, brightness=0.9, zoffset=-9, ring_emit=center(0.0, 1.0)),
        # la sombra que cubre la luna (empieza a un lado y se corre hasta taparla a los TE_C s)
        dict(name="Shadow", texture="fx_glow", rel="r", hu="H", lifetime=(0.75, 0.75),
             size=[(0, 0.8 * ER), (1, 2.5 * ER)], transparency=[(0, 1), (0.4, 0.4), (1, 0)], color=SHADOW, zoffset=-7,
             ring_emit=center(TE_C - 0.75, 1.0)),
        dict(name="ShadowHold", texture="fx_glow", rel="r", hu="H", lifetime=(TE_E - TE_C + 0.1, TE_E - TE_C + 0.1),
             size=[(0, 2.5 * ER), (1, 2.5 * ER)], transparency=[(0, 0), (0.85, 0), (1, 1)], color=SHADOW, zoffset=-7,
             ring_emit=center(TE_C, 1.0)),
        dict(name="Corona", texture="kk_circle_02", rel="r", hu="H", lifetime=(TE_E - TE_C + 0.1, TE_E - TE_C + 0.1),
             size=[(0, 2.2 * D * 0.42), (0.05, 2.0 * D * 0.42), (1, 2.05 * D * 0.42)],
             transparency=[(0, 0.0), (0.85, 0.1), (1, 1)], color=SILVER, light_emission=1.0, brightness=1.6,
             zoffset=-6, ring_emit=center(TE_C, 1.0)),
        dict(name="CoronaFlare", texture="kk_star_09", rel="r", hu="H", lifetime=(0.35, 0.35),
             size=[(0, 1 * ER), (0.2, 5 * ER), (1, 2 * ER)], color=GLINT, light_emission=1.0, brightness=1.5,
             rotation=(0, 90), zoffset=-5, ring_emit=center(TE_C, 1.0)),
        # lo que sube de la zona mientras carga (destellos y escarcha)
        dict(name="ChargeRise", texture="kk_star_06", rel="r", direction="Top", speed=(12, 22), lifetime=(0.7, 1.0),
             size=twinkle(1.3), color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45),
             ring_emit=scatter(g, 60, (0.05, TE_C), (0.1, 1.0), 0.5)),
        dict(name="ChargeMist", texture="kk_smoke_04", rel="r", direction="Top", speed=(2, 5), drag=1,
             lifetime=(0.8, 1.1), size=[(0, 4), (1, 12)], transparency=[(0, 1), (0.3, 0.6), (0.8, 0.7), (1, 1)],
             color=MIST, rotation=(0, 360), rot_speed=(-30, 30), ring_emit=scatter(g, 18, (0.1, 0.8), (0.2, 1.0), 1.0)),
        dict(name="GuideLine", texture="fx_laser_thin", rel="h", hu="H", orientation=UP, lifetime=(0.2, 0.2),
             size=[(0, 0.21 * EH), (1, 0.21 * EH)], transparency=[(0, 1), (0.3, 0.1), (1, 0.5)], color=SILVER,
             light_emission=1.0, brightness=1.7,
             ring_emit=[(round(TE_C - 0.12 + 0.06 * (i + 0.5) / 6, 3), 1, 0.0, 0.0, round((i + 0.5) / 6, 3))
                        for i in range(6)]),
        # ---------------- cae la columna de luz de luna ----------------
        dict(name="DropHead", texture="fx_glow", rel="r", hu="H", direction="Bottom", speed_h=(6.0, 6.0),
             lifetime=(0.16, 0.16), size=[(0, 1.2 * ER), (1, 1.5 * ER)], transparency=[(0, 0.2), (1, 0.4)],
             color=ICE, light_emission=1.0, brightness=1.3, ring_emit=center(TE_C, 1.0)),
        dict(name="ImpactFlash", texture="fx_glow", rel="r", lifetime=(0.22, 0.22),
             size=[(0, 8), (0.25, 1.8 * ER), (1, 2.0 * ER)], transparency=[(0, 0.3), (0.4, 0.55), (1, 1)], color=ICE,
             light_emission=1.0, brightness=1.15, zoffset=3, ring_emit=center(TE_C + 0.15, 4.0)),
        dict(name="ImpactStar", texture="kk_star_09", rel="r", lifetime=(0.3, 0.3),
             size=[(0, 20), (0.15, 3.0 * ER), (1, 12)], color=GLINT, light_emission=1.0, brightness=1.2,
             rotation=(0, 90), zoffset=4, ring_emit=center(TE_C + 0.15, 8.0)),
        dict(name="ShockRing", texture="kk_circle_02", rel="r", lifetime=(0.5, 0.5),
             size=[(0, D), (1, D * 3.6)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=ICE,
             light_emission=0.6, ring_emit=center(TE_C + 0.15, 0.2), **DECAL),
        dict(name="ShockRingSharp", texture="kk_circle_02", rel="r", lifetime=(0.32, 0.32),
             size=[(0, D), (1, D * 4.8)], transparency=[(0, 0.1), (0.6, 0.45), (1, 1)], color=SILVER,
             light_emission=0.7, ring_emit=center(TE_C + 0.15, 0.21), **DECAL),
        dict(name="ColumnBeam", texture="fx_beam", rel="h", hu="H", orientation=UP, lifetime=(TE_E - TE_C, TE_E - TE_C),
             size=[(0, 0.28 * EH), (1, 0.28 * EH)], transparency=[(0, 0.5), (0.1, 0.4), (0.85, 0.45), (1, 1)],
             color=ICE, light_emission=1.0, brightness=1.1,
             ring_emit=[(round(TE_C + 0.15 * (1 - h), 3), 1, 0.0, 0.0, h) for h in (0.92, 0.78, 0.64, 0.5, 0.36,
                                                                                 0.22, 0.08)]),
        # el cuerpo: luz de luna que CAE (al revés que el pilar de Omnívora), luminosa y transparente
        dict(name="ColumnBody", texture="mf_moonlight_2x2", flipbook=STATIC2x2, rel="r", hu="H", orientation=UP,
             direction="Bottom", speed_h=(0.18, 0.24), lifetime=(0.6, 0.8),
             size=[(0, 2.0 * ER), (0.3, 2.3 * ER), (1, 2.35 * ER)],
             transparency=[(0, 1), (0.2, 0.4), (0.75, 0.45), (1, 1)], color=ICE, light_emission=0.55,
             brightness=0.85, zoffset=-4, zstream=EW(26), zdist={"r": (0.0, 0.25), "h": (0.05, 1.0)}),
        dict(name="ColumnEdge", texture="mf_moonlight_2x2", flipbook=STATIC2x2, rel="r", hu="H", orientation=UP,
             direction="Bottom", speed_h=(0.3, 0.4), lifetime=(0.5, 0.7), size=[(0, 1.0 * ER), (1, 1.3 * ER)],
             transparency=[(0, 1), (0.2, 0.5), (0.75, 0.55), (1, 1)], color=CRYST, light_emission=1.0, brightness=1.0,
             zoffset=-3, zstream=EW(30), zdist={"r": (0.7, 1.0), "h": (0.05, 1.0)}),
        dict(name="FallingStreaks", texture="kk_trace_01", rel="r", hu="H", orientation="VelocityParallel",
             direction="Bottom", speed_h=(0.9, 1.4), lifetime=(0.25, 0.4), size=[(0, 6), (0.3, 24), (1, 14)],
             color=ICE, light_emission=1.0, brightness=1.3, zstream=EW(70), zdist={"r": (0.1, 1.0), "h": (0.2, 1.0)}),
        dict(name="FallingStars", texture="fx_spark002", rel="r", hu="H", direction="Bottom", speed_h=(0.25, 0.4),
             lifetime=(0.8, 1.2), size=twinkle(1.0), color=GLINT, light_emission=1.0, brightness=1.9, rotation=(0, 45),
             zstream=EW(60), zdist={"r": (0.0, 1.1), "h": (0.1, 1.0)}),
        dict(name="GroundGlow", texture="fx_glow", rel="r", lifetime=(0.5, 0.6),
             size=[(0, 2.2 * ER), (1, 2.4 * ER)], transparency=[(0, 1), (0.3, 0.55), (0.7, 0.6), (1, 1)], color=ICE,
             light_emission=1.0, brightness=1.0,
             ring_emit=[c for t in (1.2, 1.5, 1.8, 2.1) for c in center(t, 0.1)], **DECAL),
        dict(name="GroundSpikes", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", orientation="VelocityParallel",
             direction="Top", spread=(20, 20), speed=(16, 26), drag=12, lifetime=(1.2, 1.4),
             size=[(0, 0.5), (0.12, 7, 2), (0.85, 7.4, 2), (1, 0)], transparency=[(0, 0), (0.85, 0.1), (1, 1)],
             color=SHARD, light_emission=0.5, brightness=1.5,
             ring_emit=scatter(g, 26, (TE_C + 0.15, TE_C + 0.35), (0.25, 1.05), 0.5)),
        # ---------------- fin: la columna se apaga y queda un anillo de cristal roto ----------------
        dict(name="EndFlash", texture="fx_glow", rel="r", lifetime=(0.25, 0.25), size=[(0, 10), (0.3, 1.6 * ER), (1, 1.8 * ER)],
             transparency=[(0, 0.4), (1, 1)], color=ICE, light_emission=1.0, brightness=1.0,
             ring_emit=center(TE_E, 4.0)),
        dict(name="EndShards", texture="mf_shard_2x2", flipbook=STATIC2x2, rel="r", direction="Top", spread=(70, 70),
             speed=(30, 70), drag=0.5, accel=(0, -110, 0), lifetime=(0.6, 0.9), size=[(0, 2.0, 0.6), (1, 1.3, 0.4)],
             transparency=[(0, 0), (0.85, 0.1), (1, 1)], color=SHARD, light_emission=0.45, brightness=1.4,
             rotation=(0, 360), rot_speed=(-500, 500), ring_emit=scatter(g, 26, (TE_E, TE_E + 0.05), (0.3, 1.0), 1.0, n=2)),
        dict(name="EndGlints", texture="kk_star_06", rel="r", direction="Top", speed=(4, 10), lifetime=(0.8, 1.3),
             size=twinkle(1.4), color=GLINT, light_emission=1.0, brightness=2.0, rotation=(0, 45),
             ring_emit=scatter(g, 40, (TE_E, TE_E + 0.4), (0.1, 1.1), (1.0, 10.0))),
    ]
    return L


ECLIPSE_CUBES = {
    "gravity": 160, "bounce": 0.32, "friction": 0.55, "spin": (240, 820),
    "rest": (0.5, 1.3), "fade": 0.35, "settle": 0.12, "shrink": (0.16, 0.26), "dissolve_time": (0.18, 0.6),
    "color_var": (0.72, 1.08), "dark": 0.15,
    # parte de los pedazos son cristal brillante (en hielo y plata); el resto, del color del suelo
    "neon_colors": [(150, 205, 255), (90, 150, 255), (220, 238, 255), (120, 175, 255)],
    "preview_color": (112, 110, 118),
    "fx": dict(name="CubeDissolve", texture="fx_spark002", direction="Top", spread=(180, 180), speed=(4, 12),
               lifetime=(0.25, 0.4), size=[(0, 0), (0.2, 1.8), (1, 0)], color=GLINT, light_emission=1.0,
               brightness=1.7, rotation=(0, 45), emit_n=2),
    "groups": [
        {"name": "Lift", "mode": "lift", "count": 30, "t": (0.1, 0.6), "r": (0.12, 0.9), "size": (0.25, 1.1),
         "skew": 1.8, "lift": (1.0, 6.0), "release": (TE_C + 0.15, TE_C + 0.18), "out": (18, 48), "up": (45, 90),
         "dissolve": 0.35, "neon": 0.5},
        {"name": "Blast", "mode": "blast", "count": 120, "t": (TE_C + 0.15, TE_C + 0.2), "r": (0.25, 1.05),
         "size": (0.12, 1.2), "skew": 2.8, "out": (18, 60), "up": (26, 80), "dissolve": 0.4, "neon": 0.35},
    ],
}

ECLIPSE = {
    "name": "Eclipse",
    "doc": ("MOONFANG SKILL 4 (Eclipse): una luna llena aparece sobre la zona y se va eclipsando mientras la zona se "
            "agrieta en escarcha y los pedazos del suelo levitan; al quedar cubierta (1 s) cae una columna de luz de "
            "luna que hace volar la tierra y el cristal; a los 2.6 s se apaga y queda un anillo de cristal roto. "
            "cf = centro de la zona en el suelo. El golpe es a los 1.15 s."),
    "duration": 3.6,
    "zone": {"radius": ER, "height": EH, "charge": TE_C, "collapse": TE_E},
    "shake_ramp": (0.0, TE_E, 0.1, 1.2, 1.6),
    "lights": [
        {"t": 0.0, "h": 0.9, "hu": "H", "color": (190, 215, 255), "brightness": 3, "range": 80, "rise": 0.4,
         "hold": TE_C - 0.5, "fall": 0.2},
        {"t": TE_C + 0.15, "h": 6, "color": (190, 225, 255), "brightness": 9, "range": 70, "rise": 0.03, "hold": 0.05,
         "fall": 0.6},
        {"t": TE_C + 0.15, "h": 0.3, "hu": "H", "color": (150, 200, 255), "brightness": 5, "range": 70, "rise": 0.1,
         "hold": TE_E - TE_C - 0.4, "fall": 0.4},
        {"t": TE_E, "h": 4, "color": (190, 225, 255), "brightness": 5, "range": 50, "rise": 0.02, "hold": 0.03,
         "fall": 0.5},
    ],
    "cubes": ECLIPSE_CUBES,
    "layers": eclipse_layers(random.Random(41)),
}

SPECS = {
    "MoonClaw": MOON_CLAW, "MoonClawFinisher": MOON_CLAW_FINISHER, "MoonFang": MOON_FANG,
    "MoonGuard": MOON_GUARD, "MoonGuardHit": MOON_GUARD_HIT,
    "CrescentWave": CRESCENT_WAVE, "FangRain": FANG_RAIN,
    "LunarHowl": LUNAR_HOWL, "LunarAura": LUNAR_AURA, "Eclipse": ECLIPSE,
}
