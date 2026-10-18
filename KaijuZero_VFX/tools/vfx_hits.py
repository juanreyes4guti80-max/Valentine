"""KAIJU ZERO — GOLPES QUE RECIBE EL RIVAL (juego por turnos): CORTE, CORTE QUEMADO Y MORDISCO.

Kaiju Zero ataca desde su lado (su animación) y en el rival aparece el golpe:
  CORTE             un zarpazo de garra (tres marcas rasgadas, como el logo de Monster) que se desgarra en
                    diagonal sobre el rival, con chispas que saltan a los lados, destello y un anillo.
  CORTE QUEMADO     el mismo zarpazo al rojo vivo: quedan las marcas encendidas ardiendo, con llamas, brasas,
                    gotas de lava y humo.
  MORDISCO          dos mandíbulas de colmillos aparecen sobre el rival y se cierran de golpe: al chocar hay
                    un destello corto, chispas y un anillo (sin que alumbre demasiado).
Los efectos miran a la cámara (playHit los orienta): X = derecha de la pantalla, Y = arriba, +Z = hacia la
cámara. El zarpazo va en diagonal (`angle` = 35: de arriba a la izquierda a abajo a la derecha; 0 = vertical).
Tamaño 1 = un rival de 22 studs de alto.
"""
STATIC2x2 = ("Grid2x2", "Random", 0, True)
ONESHOT = ("Grid4x4", "OneShot", 30, False)          # el flipbook se reproduce una vez en la vida de la partícula

SLASH_HIT = 0.05        # el zarpazo pasa por el centro del rival
BITE_HIT = 0.14         # las mandíbulas chocan (cuadro 6 de 16 en 0.36 s)
CLAWS = {"type": "Box", "size": (14, 22, 1)}        # donde quedan las tres marcas (Y = a lo largo del zarpazo)
BITE_LINE = {"type": "Box", "size": (18, 2, 1)}      # donde se juntan los colmillos

# ----------------------------------------------------------------------------- colores
WHITE = [(0, (255, 255, 255)), (1, (255, 246, 236))]
WARM = [(0, (255, 252, 244)), (0.5, (255, 226, 186)), (1, (255, 180, 110))]
DUST = [(0, (170, 160, 150)), (1, (130, 124, 120))]
ROCKY = [(0, (150, 120, 100)), (1, (100, 88, 80))]
# fuego de Kaiju Zero (el mismo naranja de su lava)
HOT = [(0, (255, 255, 240)), (0.3, (255, 212, 120)), (0.65, (255, 140, 45)), (1, (220, 70, 20))]
LAVA_HOT = [(0, (255, 220, 140)), (0.15, (255, 170, 60)), (0.4, (250, 120, 30)), (0.75, (225, 70, 15)),
            (1, (190, 50, 12))]
FLAME = [(0, (255, 236, 150)), (0.3, (255, 166, 50)), (0.7, (240, 90, 20)), (1, (160, 40, 12))]
EMBER = [(0, (255, 225, 130)), (0.5, (255, 140, 40)), (1, (220, 60, 15))]
GLOB = [(0, (255, 214, 120)), (0.2, (255, 150, 40)), (0.55, (240, 90, 18)), (1, (185, 44, 12))]
ASH = [(0, (255, 130, 50)), (0.06, (130, 74, 50)), (0.2, (78, 64, 58)), (0.6, (92, 84, 80)), (1, (112, 106, 102))]
SCAR = [(0, (255, 226, 150)), (0.2, (255, 146, 50)), (0.6, (215, 64, 20)), (1, (90, 26, 12))]


# ----------------------------------------------------------------------------- piezas comunes
def claw_marks(color, bright, glow_color, glow_life):
    """El zarpazo (las tres marcas se desgarran con el flipbook) y su resplandor. VelocityParallel con la partícula
    bajando: el zarpazo sigue la inclinación del golpe (el giro del efecto)."""
    return [
        dict(name="ClawMarks", texture="kz_claw_4x4", flipbook=ONESHOT, orientation="VelocityParallel",
             direction="Bottom", speed=(4, 4), emit=[(0.0, 1)], lifetime=(0.28, 0.28), size=[(0, 27), (1, 28)],
             transparency=[(0, 0), (0.7, 0), (1, 1)], color=color, light_emission=0.55, brightness=bright, zoffset=5),
        dict(name="ClawGlow", texture="kz_claw_glow", orientation="VelocityParallel", direction="Bottom",
             speed=(4, 4), emit=[(0.03, 1)], lifetime=(glow_life, glow_life), size=[(0, 29), (1, 31)],
             transparency=[(0, 0.62), (1, 1)], color=glow_color, light_emission=1.0, brightness=0.45, zoffset=4),
    ]


def impact(t, color, star_color, flash=20, ring=34, glow=1.0):
    """Destello, estrella y anillo del golpe (miran a la cámara). glow < 1 los hace más tenues."""
    return [
        dict(name="HitFlash", texture="fx_glow", emit=[(t, 1)], lifetime=(0.16, 0.18),
             size=[(0, 6), (0.3, flash), (1, flash * 1.1)], transparency=[(0, 1 - 0.7 * glow), (1, 1)], color=color,
             light_emission=1.0, brightness=0.9 * glow, zoffset=6),
        dict(name="HitStar", texture="kk_star_06", emit=[(t, 1)], lifetime=(0.14, 0.14),
             size=[(0, 10), (0.4, flash * 0.95), (1, flash * 0.6)], transparency=[(0, 1 - glow), (1, 1)],
             color=star_color, light_emission=1.0, brightness=1.5 * glow, rotation=(0, 360), zoffset=7),
        dict(name="HitRing", texture="kz_beam_ring", emit=[(t, 1)], lifetime=(0.22, 0.24),
             size=[(0, 6), (1, ring)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=color,
             light_emission=1.0, brightness=1.4, rotation=(0, 360), zoffset=3),
    ]


def side_sparks(t, color, shape, n=(16, 8), dirs=("Right", "Left")):
    """Chispas que saltan a los dos lados de la línea del golpe."""
    return [dict(name=f"Sparks{d}", texture="kk_trace_01", orientation="VelocityParallel", shape=shape,
                 direction=d, spread=(25, 35), speed=(70, 140), drag=5, accel=(0, -40, 0), lifetime=(0.16, 0.3),
                 emit=[(t - 0.01, n[0]), (t + 0.02, n[1])], size=[(0, 6, 1.5), (1, 2)], color=color,
                 light_emission=1.0, brightness=2.0) for d in dirs]


def chips_and_puff(t, n=8):
    """Esquirlas de la piel del rival y una nube de polvo."""
    return [
        dict(name="Chips", texture="kz_debris_2x2", flipbook=STATIC2x2, emit=[(t, n)], direction="Back",
             spread=(55, 55), speed=(25, 50), drag=0.5, accel=(0, -90, 0), lifetime=(0.45, 0.7),
             size=[(0, 1.0, 0.3), (1, 0.9, 0.3)], color=ROCKY, light_emission=0.05, rotation=(0, 360),
             rot_speed=(-400, 400)),
        dict(name="DustPuff", texture="kk_smoke_04", emit=[(t + 0.01, 3)], direction="Back", spread=(60, 60),
             speed=(4, 10), drag=2, accel=(0, 4, 0), lifetime=(0.45, 0.6), size=[(0, 4, 1), (1, 11, 2)],
             transparency=[(0, 0.6), (0.3, 0.55), (1, 1)], color=DUST, rotation=(0, 360), rot_speed=(-40, 40),
             zoffset=-2),
    ]


def jaws(color, le, bright):
    """Las mandíbulas (flipbook): colmillos casi opacos con su borde oscuro, sin aura."""
    return [
        dict(name="Jaws", texture="kz_bite_4x4", flipbook=ONESHOT, emit=[(0.0, 1)], lifetime=(0.36, 0.36),
             size=[(0, 25), (1, 26)], transparency=[(0, 0.5), (0.06, 0), (0.62, 0), (1, 1)], color=color,
             light_emission=le, brightness=bright, zoffset=5),
    ]


# ----------------------------------------------------------------------------- corte
SLASH = {
    "name": "SlashHit",
    "doc": ("CORTE: el rival recibe un zarpazo de garra (tres marcas rasgadas) que se desgarra en diagonal, con "
            "chispas, destello y anillo."),
    "duration": 0.6,
    "hit": {"lift": 3, "ref": 22, "angle": 35, "angled": True, "impact": SLASH_HIT},
    "light": {"color": (255, 236, 210), "brightness": 3, "range": 22, "time": 0.25, "delay": SLASH_HIT},
    "shakes": [(SLASH_HIT, 0.45, 0.22)],
    "layers": claw_marks([(0, (255, 255, 255)), (0.6, (255, 240, 220)), (1, (255, 205, 160))], 1.15,
                          [(0, (255, 230, 200)), (1, (255, 180, 120))], 0.32)
    + impact(SLASH_HIT, WHITE, WARM)
    + side_sparks(SLASH_HIT, WARM, CLAWS)
    + [dict(name="ClawShards", texture="fx_spark4", shape={"type": "Box", "size": (14, 24, 1)}, emit=[(SLASH_HIT, 16)],
            direction="Back", spread=(60, 60), speed=(8, 20), drag=2, lifetime=(0.2, 0.35),
            size=[(0, 0), (0.2, 2.2, 0.6), (1, 0)], color=WARM, light_emission=1.0, brightness=2.0,
            rotation=(0, 360))]
    + chips_and_puff(SLASH_HIT),
}

# ----------------------------------------------------------------------------- corte quemado
BURNING_SLASH = {
    "name": "BurningSlashHit",
    "doc": ("CORTE QUEMADO: el zarpazo sale al rojo vivo y sus marcas quedan encendidas ardiendo un momento, con "
            "llamas, brasas, gotas de lava y humo."),
    "duration": 1.0,
    "hit": {"lift": 3, "ref": 22, "angle": 35, "angled": True, "impact": SLASH_HIT},
    "light": {"color": (255, 140, 50), "brightness": 5, "range": 26, "time": 0.6, "delay": SLASH_HIT},
    "shakes": [(SLASH_HIT, 0.55, 0.25)],
    "layers": claw_marks(HOT, 1.2, [(0, (255, 160, 60)), (1, (255, 100, 30))], 0.45)
    + [
        # las marcas quedan encendidas y se enfrían (naranja -> rojo -> costra)
        dict(name="BurnScar", texture="kz_claw", orientation="VelocityParallel", direction="Bottom",
             speed=(0.5, 0.5), emit=[(0.11, 1)], lifetime=(0.9, 0.9), size=[(0, 27.5), (1, 27.5)],
             transparency=[(0, 0), (0.6, 0.25), (1, 1)], color=SCAR, light_emission=0.85, brightness=1.6,
             zoffset=4.5),
        dict(name="ScarGlow", texture="kz_claw_glow", orientation="VelocityParallel", direction="Bottom",
             speed=(0.5, 0.5), emit=[(0.11, 1)], lifetime=(0.8, 0.8), size=[(0, 30), (1, 31)],
             transparency=[(0, 0.45), (1, 1)], color=[(0, (255, 120, 35)), (1, (200, 50, 15))],
             light_emission=1.0, brightness=1.0, zoffset=4),
        # llamas que lamen las marcas, una llamarada al cortar, gotas de lava, brasas y humo
        dict(name="FireLicks", texture="kk_muzzle_04", orientation="VelocityParallel",
             shape={"type": "Box", "size": (14, 24, 1.5)}, direction="Top", spread=(35, 35), speed=(4, 10), drag=1.5,
             accel=(0, 35, 0), lifetime=(0.3, 0.5), size=[(0, 2, 0.5), (0.3, 6, 1.2), (1, 3.5, 0.8)],
             transparency=[(0, 0.1), (0.6, 0.25), (1, 1)], color=FLAME, light_emission=0.4, brightness=1.6,
             stream=[(0.06, 0.75, 45, 10)]),
        dict(name="FireBurst", texture="fx_fire_2x2", flipbook=STATIC2x2, shape=CLAWS, emit=[(SLASH_HIT, 14)], direction="Back", spread=(60, 60), speed=(10, 26), drag=3, accel=(0, 12, 0),
             lifetime=(0.3, 0.45), size=[(0, 4, 1), (0.4, 9, 2), (1, 10, 2)],
             transparency=[(0, 0.05), (0.6, 0.2), (1, 1)], color=LAVA_HOT, light_emission=0.3, brightness=1.5,
             rotation=(0, 360), rot_speed=(-90, 90)),
        dict(name="LavaDrops", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, shape=CLAWS, emit=[(SLASH_HIT + 0.01, 12)],
             direction="Back", spread=(60, 60), speed=(8, 20), drag=0.4, accel=(0, -110, 0), lifetime=(0.4, 0.7),
             size=[(0, 0.8, 0.2), (0.3, 1.6, 0.4), (1, 1.0, 0.3)], transparency=[(0, 0), (0.75, 0.05), (1, 1)],
             color=GLOB, light_emission=0.5, brightness=1.5, rotation=(0, 360), rot_speed=(-220, 220)),
        dict(name="Embers", texture="kk_flare_01", shape={"type": "Box", "size": (16, 24, 2)}, direction="Top",
             spread=(60, 60), speed=(4, 14), accel=(0, 14, 0), lifetime=(0.5, 0.9),
             size=[(0, 0), (0.15, 1.8, 0.5), (1, 0)], color=EMBER, light_emission=1.0, brightness=1.8,
             emit=[(SLASH_HIT, 20)], stream=[(0.06, 0.9, 40, 10)]),
        dict(name="BurnSmoke", texture="kk_smoke_04", shape={"type": "Box", "size": (12, 22, 1)}, direction="Top",
             spread=(25, 25), speed=(4, 9), drag=1, accel=(0, 8, 0), lifetime=(0.7, 1.0), size=[(0, 3, 1), (1, 10, 2)],
             transparency=[(0, 0.7), (0.3, 0.55), (1, 1)], color=ASH, rotation=(0, 360), rot_speed=(-30, 30),
             zoffset=-2, stream=[(0.15, 0.9, 12, 4)]),
    ]
    + impact(SLASH_HIT, [(0, (255, 240, 200)), (1, (255, 140, 50))], HOT, flash=24)
    + side_sparks(SLASH_HIT, [(0, (255, 240, 180)), (0.5, (255, 170, 60)), (1, (240, 90, 20))], CLAWS),
}

# ----------------------------------------------------------------------------- mordisco
BITE = {
    "name": "BiteHit",
    "doc": ("MORDISCO: dos mandíbulas de colmillos se cierran de golpe sobre el rival; al chocar hay un destello corto "
            "y chispas."),
    "duration": 0.6,
    "hit": {"lift": 3, "ref": 22, "angle": 0, "angled": False, "impact": BITE_HIT},
    "light": {"color": (255, 240, 220), "brightness": 1.2, "range": 18, "time": 0.18, "delay": BITE_HIT},
    "shakes": [(BITE_HIT, 0.55, 0.25)],
    "layers": jaws(WHITE, 0.08, 1.1)
    + impact(BITE_HIT, WHITE, WARM, flash=12, ring=34, glow=0.5)
    + [dict(name="ChompBurst", texture="fx_burst_a", emit=[(BITE_HIT, 1)], lifetime=(0.1, 0.12),
            size=[(0, 6), (0.4, 15), (1, 17)], transparency=[(0, 0.55), (1, 1)], color=WARM, light_emission=0.6,
            brightness=0.9, rotation=(0, 360), zoffset=5),
       dict(name="FangSparks", texture="fx_spark4", shape=BITE_LINE, emit=[(BITE_HIT, 10)], direction="Back",
            spread=(70, 70), speed=(10, 24), drag=2, lifetime=(0.2, 0.35), size=[(0, 0), (0.2, 1.8, 0.5), (1, 0)],
            color=WARM, light_emission=1.0, brightness=1.4, rotation=(0, 360))]
    + side_sparks(BITE_HIT, WARM, BITE_LINE, n=(10, 6))
    + chips_and_puff(BITE_HIT),
}


HITS = {"SlashHit": SLASH, "BurningSlashHit": BURNING_SLASH, "BiteHit": BITE}
