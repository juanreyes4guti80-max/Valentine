"""PEBLEDON — kaiju de piedra (tipo Godzilla) con venas de energía turquesa y placas dorsales de cristal cian.

Identidad: ROCA viva y ENERGÍA TURQUESA que se escapa por las grietas como fuego frío. Formas pesadas y sísmicas:
el suelo se parte, las rocas vuelan y por las grietas brota fuego cian. Paleta sacada de su imagen:
  cristal claro (94, 229, 224), medio (52, 147, 152), oscuro (39, 121, 127); roca (93, 85, 76); panza (164, 148, 133)

  SKILL 1   SeismicRoar "Rugido sísmico": un rugido hacia adelante; la onda parte el suelo, arrastra rocas y por
            las grietas brota fuego cian (expone, ralentiza y empuja un poco: eso lo hace el servidor)
  SKILL 2   BlueBreath "Aliento azul": como el de Godzilla, fuego azul concentrado que sale recto de la boca 3 s (se apunta)
Las skills se escalan con `scale` (1 = Pebledon de unos 25 studs de alto, con la boca a unos 21 studs del suelo).
"""
import math
import random

STATIC2x2 = ("Grid2x2", "Random", 0, True)
DECAL = dict(decal=True, orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))

# ----------------------------------------------------------------------------- colores
CRYSTAL = (94, 229, 224)
CRYSTAL_MID = (52, 147, 152)
CRYSTAL_DARK = (39, 121, 127)
ROCK = (93, 85, 76)
BELLY = (164, 148, 133)
TURQ = [(0, (215, 255, 252)), (0.4, CRYSTAL), (1, CRYSTAL_MID)]
TURQ_SOFT = [(0, (150, 240, 234)), (0.5, (95, 205, 202)), (1, (60, 150, 152))]
GLINT = [(0, (255, 255, 255)), (0.5, (205, 255, 250)), (1, (120, 235, 228))]
FLAME = [(0, (175, 255, 250)), (0.3, (100, 236, 230)), (0.65, (60, 185, 186)), (1, CRYSTAL_DARK)]
DUST = [(0, (160, 150, 136)), (0.5, (138, 128, 116)), (1, (112, 104, 94))]
DUST_DARK = [(0, (118, 109, 98)), (1, (92, 85, 77))]
CRACK_DARK = [(0, (34, 30, 27)), (1, (40, 36, 32))]
SLAB_RGB = (104, 96, 86)    # color de las losas y rocas en la vista previa (en Roblox, el del suelo)


def twinkle(k):
    return [(t, round(v * k, 3)) for t, v in [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2),
                                              (0.72, 2.8), (1, 0)]]


# ----------------------------------------------------------------------------- SKILL 1: Rugido sísmico
# Pebledon junta energía en la boca (el suelo ya tiembla bajo él) y RUGE hacia adelante: ondas de sonido turquesa,
# un chorro de aire cargado con fuego cian y brasas. La onda baja al suelo y avanza en TRIÁNGULO (modo "cone" que sale
# de la cabeza: el triángulo va por el suelo bajo la boca): el frente parte el suelo, levanta losas, ARRASTRA ROCAS
# hacia adelante (saltan delante del frente y caen más allá) y deja grietas con venas turquesa por las que brota
# fuego cian un rato. Al llegar al final, las rocas que arrastraba se amontonan y revientan en polvo.
RL, RA = 100.0, 42.0           # largo y apertura del triángulo (escala 1)
T_ROAR = 0.36                  # ruge
T0R = T_ROAR + 0.03            # la onda del suelo sale
TWR, EASE_R = 0.85, 1.35       # tarda en cruzar y cuánto se frena (1 = velocidad constante)
WAVE_R = (T0R, TWR, EASE_R)
MOUTH_H = 21.5                 # alto de la boca sobre el suelo (escala 1; solo si no se encuentra el suelo)
BODY = (0, 0, 8)               # el centro del cuerpo respecto al vértice (+Z = detrás), en el suelo


def rfront(u, delay=0.0):
    """Instante en que el frente pasa por u."""
    return round(T0R + delay + TWR * (1 - (1 - min(max(u, 0.0), 1.0)) ** (1 / EASE_R)), 3)


def rsamples(g, n, u0=0.05, u1=1.0, s_max=0.95, up=(0.3, 0.3), delay=(0.0, 0.0), k=1):
    """Puntos del triángulo (más donde es más ancho) en el instante en que pasa el frente (+ delay)."""
    out = []
    for _ in range(n):
        u = math.sqrt(g.uniform(u0 * u0, u1 * u1))
        out.append((round(rfront(u) + g.uniform(*delay), 3), k, round(u, 4), round(g.uniform(-s_max, s_max), 3),
                    round(g.uniform(*up), 2)))
    return sorted(out)


def rflicker(g, pts, n, span, k=1):
    """Cada punto vuelve a soltar n veces durante span s (el fuego que sigue saliendo de una grieta)."""
    out = []
    for (t, _, u, s, h) in pts:
        for j in range(n):
            out.append((round(t + span * (j + g.uniform(0.0, 0.8)) / n, 3), k, u, s, h))
    return sorted(out)


def redge(n, up=0.5, k=1, u=0.97):
    """A lo ancho del borde lejano, cuando el frente llega (ya casi quieto)."""
    return [(rfront(u), k, u, round(-0.95 + 1.9 * j / (n - 1), 3), up) for j in range(n)]


ROAR_FRONT = {
    "wave": WAVE_R, "count": 12, "s_max": 0.95,
    "emitters": [
        # el muro de polvo y tierra que levanta el frente (nace ahí y se queda atrás: la estela)
        dict(name="DustWall", up=2.0, rate=16, texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front",
             pitch=28, spread=(30, 14), speed=(45, 85), drag=2.6, accel=(0, 2, 0), lifetime=(1.2, 1.9),
             size=[(0, 6, 1.5), (0.25, 13, 2), (1, 20, 3)], transparency=[(0, 0.35), (0.15, 0.3), (0.5, 0.6), (1, 1)],
             color=DUST, rotation=(0, 360), rot_speed=(-35, 35), zoffset=-2),
        dict(name="DustLow", up=1.0, rate=12, texture="fx_fog2001", direction="Front", spread=(55, 6),
             speed=(35, 70), drag=2.0, accel=(0, 0.5, 0), lifetime=(1.8, 2.6), size=[(0, 6, 1), (0.4, 12, 2), (1, 16, 2)],
             transparency=[(0, 0.5), (0.15, 0.45), (0.5, 0.7), (1, 1)], color=DUST_DARK, rotation=(0, 360),
             rot_speed=(-20, 20), zoffset=-3),
        # las rocas que arrastra: saltan delante del frente dando vueltas y caen más allá
        dict(name="CarriedRocks", up=1.5, rate=14, pitch=26, texture="pb_rock_2x2", flipbook=STATIC2x2,
             direction="Front", spread=(22, 14), speed=(70, 120), drag=0.5, accel=(0, -150, 0), lifetime=(0.5, 0.8),
             size=[(0, 2.6, 1.0), (1, 2.2, 0.8)], transparency=[(0, 0), (0.85, 0), (1, 1)], rotation=(0, 360),
             rot_speed=(-420, 420)),
        dict(name="CarriedChips", up=1.0, rate=18, pitch=34, texture="om_cubes_2x2", flipbook=STATIC2x2,
             direction="Front", spread=(30, 20), speed=(55, 105), drag=0.5, accel=(0, -160, 0), lifetime=(0.4, 0.7),
             size=[(0, 0.8, 0.3), (1, 0.6, 0.2)], color=[(0, (128, 118, 106)), (1, (100, 92, 82))], rotation=(0, 360),
             rot_speed=(-500, 500)),
        # la energía del rugido en el frente: fuego cian bajo y brasas que saltan
        dict(name="FrontFlames", up=2.0, rate=12, texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Top",
             spread=(25, 25), speed=(6, 14), drag=1.5, accel=(0, 8, 0), lifetime=(0.35, 0.6),
             size=[(0, 3, 1), (0.3, 7, 1.5), (1, 2)], transparency=[(0, 0.1), (0.6, 0.35), (1, 1)], color=FLAME,
             light_emission=1.0, brightness=1.45, rotation=(-15, 15)),
        dict(name="FrontEmbers", up=2.0, rate=14, texture="fx_spark002", direction="Front", pitch=40, spread=(35, 35),
             speed=(30, 70), drag=2.2, accel=(0, 14, 0), lifetime=(0.5, 1.0), size=twinkle(0.5), color=GLINT,
             light_emission=1.0, brightness=2.0, rotation=(0, 45)),
    ],
}

ROAR_FIELD = {
    "wave": WAVE_R, "seed": 21,
    "groups": [
        # losas del suelo que saltan inclinadas hacia afuera cuando pasa la onda (color y material del suelo)
        {"name": "RoarSlabs", "count": 46, "u": (0.08, 1.0), "s": (-1.0, 1.0), "lean": "radial",
         "wid": (2.0, 3.8), "thick": (0.6, 1.2), "len": (1.8, 3.6), "tilt": (18, 46), "yaw": 16, "pitch": 12,
         "show": 0.62, "rise": 0.08, "hold": (1.5, 2.2), "sink": 0.55, "delay": (0.0, 0.05),
         "ground": True, "preview_color": SLAB_RGB, "mesh": "RoarSlab"},
        # unas pocas grandes por el medio (la onda pega más fuerte en el centro)
        {"name": "RoarSlabsBig", "count": 12, "u": (0.18, 0.95), "s": (-0.55, 0.55), "lean": "radial",
         "wid": (3.6, 6.0), "thick": (1.0, 1.8), "len": (3.4, 5.6), "tilt": (24, 44), "yaw": 12, "pitch": 10,
         "show": 0.6, "rise": 0.1, "hold": (1.5, 2.1), "sink": 0.6, "delay": (0.0, 0.04),
         "ground": True, "preview_color": SLAB_RGB, "mesh": "RoarSlab"},
    ],
}

ROCK_LAND = [dict(name="RockPuff", texture="kk_smoke_04", emit=[(0, 2)], direction="Top", spread=(70, 70),
                  speed=(4, 9), drag=2, lifetime=(0.4, 0.6), size=[(0, 2.5, 0.5), (1, 6, 1)],
                  transparency=[(0, 0.45), (0.5, 0.6), (1, 1)], color=DUST, rotation=(0, 360))]
ROCK_CRUMBLE = [dict(name="RockCrumble", texture="om_cubes_2x2", flipbook=STATIC2x2, emit=[(0, 5)],
                     shape={"type": "Box", "size": (2, 1, 2)}, direction="Top", spread=(60, 60), speed=(10, 20),
                     drag=0.5, accel=(0, -150, 0), lifetime=(0.4, 0.6), size=[(0, 0.7, 0.2), (1, 0.5, 0.15)],
                     color=[(0, (120, 112, 100)), (1, (96, 88, 78))], rotation=(0, 360), rot_speed=(-400, 400)),
                dict(name="RockCrumbleDust", texture="kk_smoke_04", emit=[(0, 1)], direction="Top", spread=(60, 60),
                     speed=(2, 5), drag=2, lifetime=(0.4, 0.6), size=[(0, 2, 0.5), (1, 5, 1)],
                     transparency=[(0, 0.5), (0.5, 0.65), (1, 1)], color=DUST, rotation=(0, 360))]


def rock_trail(name, size):
    return [{"name": name, "rate": 12, "texture": "kk_smoke_04", "speed": (0, 2), "direction": "Top",
             "spread": (180, 180), "drag": 2, "lifetime": (0.35, 0.55), "size": [(0, size, 0.5), (1, size * 2.5, 1)],
             "transparency": [(0, 0.55), (0.5, 0.65), (1, 1)], "color": DUST, "rotation": (0, 360)}]


def roar_layers(g):
    head = dict(head=True)
    crack_pts = rsamples(g, 34, u0=0.06, up=(0.15, 0.15), delay=(0.0, 0.05))
    flame_pts = rsamples(g, 30, u0=0.08, up=(0.6, 0.6), delay=(0.04, 0.1))
    L = [
        # ================ la carga: la energía se junta en la boca y el suelo tiembla ================
        dict(name="GatherMotes", texture="fx_particle02", shape={"type": "Sphere", "radius": 13, "style": "Surface",
                                                                 "inout": "Inward"},
             speed=(34, 44), lifetime=(0.27, 0.3), size=[(0, 0), (0.3, 1.0), (1, 0.3)], color=GLINT,
             light_emission=1.0, brightness=1.8, stream=[(0.0, T_ROAR - 0.02, 120, 80)], **head),
        dict(name="GatherFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, shape={"type": "Sphere", "radius": 2.6},
             direction="Top", spread=(40, 40), speed=(3, 8), drag=1, accel=(0, 10, 0), lifetime=(0.25, 0.4),
             size=[(0, 1.2, 0.4), (0.35, 2.8, 0.6), (1, 0.6)], transparency=[(0, 0.15), (0.6, 0.35), (1, 1)],
             color=FLAME, light_emission=1.0, brightness=1.6, rotation=(-20, 20),
             stream=[(0.05, T_ROAR, 30, 80), (T_ROAR, T_ROAR + 0.7, 50, 0)], **head),
        dict(name="GatherGlow", texture="fx_glow", emit=[(0.0, 1)], lifetime=(T_ROAR, T_ROAR), size=[(0, 2), (1, 12)],
             transparency=[(0, 0.85), (1, 0.3)], color=TURQ, light_emission=1.0, brightness=1.4, **head),
        dict(name="TremorPebbles", floor=True, offset=(0, 0.5, BODY[2]), ring=(14, 7), texture="om_cubes_2x2",
             flipbook=STATIC2x2, direction="Front", pitch=70, spread=(15, 15), speed=(10, 18), accel=(0, -150, 0),
             lifetime=(0.3, 0.4), size=[(0, 0.6, 0.2), (1, 0.5, 0.15)], color=[(0, (124, 116, 104)), (1, (96, 88, 78))],
             rotation=(0, 360), rot_speed=(-400, 400), emit=[(0.04, 1), (0.14, 1), (0.24, 1)]),
        dict(name="TremorDust", floor=True, offset=(0, 1.0, BODY[2]), ring=(10, 6), texture="kk_smoke_04",
             direction="Front", pitch=10, spread=(20, 10), speed=(4, 9), drag=1.5, lifetime=(0.5, 0.8),
             size=[(0, 3, 1), (1, 8, 2)], transparency=[(0, 0.6), (0.4, 0.7), (1, 1)], color=DUST, rotation=(0, 360),
             emit=[(0.05, 1), (0.2, 1)]),
        # ================ el rugido ================
        dict(name="MouthFlash", texture="fx_glow", emit=[(T_ROAR, 1)], lifetime=(0.24, 0.24),
             size=[(0, 5), (0.3, 18), (1, 20)], transparency=[(0, 0.45), (1, 1)], color=TURQ, light_emission=1.0,
             brightness=1.1, zoffset=3, **head),
        dict(name="MouthStar", texture="kk_star_09", emit=[(T_ROAR, 1)], lifetime=(0.24, 0.24), rotation=(0, 90),
             size=[(0, 6), (0.2, 26), (1, 8)], color=GLINT, light_emission=1.0, brightness=1.3, zoffset=4, **head),
        dict(name="MouthShock", texture="pb_sonic_ring", orientation="VelocityPerpendicular", direction="Front",
             speed=(8, 8), emit=[(T_ROAR, 1)], lifetime=(0.3, 0.3), size=[(0, 5), (1, 44)],
             transparency=[(0, 0.0), (0.5, 0.35), (1, 1)], color=GLINT, light_emission=1.0, brightness=1.6, **head),
        # las ondas de sonido: anillos que avanzan y se abren (los primeros más fuertes)
        # (viajan con la onda del suelo: salen a ~156 studs/s y se frenan igual que el frente)
        dict(name="SonicRings", texture="pb_sonic_ring", orientation="VelocityPerpendicular", direction="Front",
             speed=(156, 156), drag=1.2, lifetime=(0.85, 0.85), size=[(0, 10), (1, 85)],
             transparency=[(0, 0.7), (0.12, 0.28), (0.5, 0.5), (1, 1)], color=TURQ, light_emission=1.0, brightness=1.2,
             emit=[(round(T_ROAR + 0.08 * k, 3), 1) for k in range(6)], **head),
        dict(name="SonicRingsSharp", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Front",
             speed=(175, 175), drag=1.1, lifetime=(0.75, 0.75), size=[(0, 8), (1, 70)],
             transparency=[(0, 0.7), (0.12, 0.38), (0.6, 0.6), (1, 1)], color=GLINT, light_emission=1.0, brightness=1.3,
             emit=[(round(T_ROAR + 0.04 + 0.16 * k, 3), 1) for k in range(3)], **head),
        dict(name="ScreamLines", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
             spread=(34, 22), speed=(110, 170), drag=3, lifetime=(0.18, 0.3), size=[(0, 11, 2), (1, 3)], color=TURQ,
             light_emission=1.0, brightness=1.8, emit=[(T_ROAR, 26), (T_ROAR + 0.12, 18), (T_ROAR + 0.26, 12)],
             **head),
        # el chorro de aire cargado: humo turquesa claro, fuego cian y brasas
        dict(name="RoarBlast", texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front", spread=(16, 12),
             speed=(70, 120), drag=2.4, accel=(0, 2, 0), lifetime=(0.7, 1.0), size=[(0, 4, 1), (0.4, 13, 2), (1, 19, 3)],
             transparency=[(0, 0.5), (0.3, 0.62), (1, 1)], color=TURQ_SOFT, light_emission=0.15, rotation=(0, 360),
             rot_speed=(-40, 40), stream=[(T_ROAR, T_ROAR + 0.5, 60, 15)], **head),
        dict(name="RoarFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Front", spread=(20, 15),
             speed=(65, 115), drag=2.8, accel=(0, 6, 0), lifetime=(0.3, 0.55), size=[(0, 2.5, 0.8), (0.3, 6.5, 1.5), (1, 2)],
             transparency=[(0, 0.1), (0.6, 0.4), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.8,
             rotation=(0, 360), rot_speed=(-60, 60), stream=[(T_ROAR, T_ROAR + 0.45, 70, 20)], **head),
        dict(name="RoarEmbers", texture="fx_spark002", direction="Front", spread=(30, 24), speed=(45, 100), drag=2.4,
             accel=(0, 10, 0), lifetime=(0.6, 1.2), size=twinkle(0.55), color=GLINT, light_emission=1.0,
             brightness=2.0, rotation=(0, 45), stream=[(T_ROAR, T_ROAR + 0.6, 70, 15)], **head),
        # ================ en el suelo, bajo él: el golpe del rugido ================
        dict(name="FloorRing", floor=True, offset=(0, 0, 2), texture="kk_circle_02", emit=[(T_ROAR + 0.02, 1)],
             lifetime=(0.5, 0.5), size=[(0, 8), (1, 70)], transparency=[(0, 0.2), (0.6, 0.55), (1, 1)], color=TURQ,
             light_emission=0.8, **DECAL),
        dict(name="FloorCracks", floor=True, offset=(0, 0, 2), texture="pb_vein_cracks", emit=[(T_ROAR + 0.04, 1)],
             lifetime=(1.6, 1.6), rotation=(0, 360), size=[(0, 6), (0.1, 30), (1, 31)],
             transparency=[(0, 1), (0.08, 0.2), (0.7, 0.35), (1, 1)], color=TURQ, light_emission=0.9, **DECAL),
        dict(name="FloorDust", floor=True, offset=(0, 2.0, 4), ring=(16, 6), texture="fx_smoke_2x2",
             flipbook=STATIC2x2, direction="Front", pitch=8, spread=(10, 6), speed=(30, 55), drag=2.5, accel=(0, 2, 0),
             lifetime=(0.9, 1.3), size=[(0, 5, 1), (1, 14, 2)], transparency=[(0, 0.4), (0.35, 0.58), (1, 1)],
             color=DUST, rotation=(0, 360), rot_speed=(-30, 30), emit=[(T_ROAR + 0.03, 1)]),
        dict(name="FloorFlames", floor=True, offset=(0, 0.8, 5), ring=(9, 7), texture="fx_aura_tongue_2x2",
             flipbook=STATIC2x2, direction="Top", spread=(10, 10), speed=(4, 8), drag=1.2, accel=(0, 8, 0),
             lifetime=(0.4, 0.6), size=[(0, 2, 0.6), (0.3, 5, 1), (1, 1)], transparency=[(0, 0.2), (0.6, 0.45), (1, 1)],
             color=FLAME, light_emission=1.0, brightness=1.5, rotation=(-10, 10),
             emit=[(round(T_ROAR + 0.03 + 0.15 * k, 3), 1) for k in range(4)]),
        # ================ lo que deja la onda: grietas con venas, fuego cian, polvo y rocas ================
        dict(name="GroundCracks", texture="pb_vein_cracks", lifetime=(2.6, 3.2), rotation=(0, 360),
             size=[(0, 8), (0.05, 24, 4), (1, 25, 4)], transparency=[(0, 0.2), (0.75, 0.35), (1, 1)], color=CRACK_DARK,
             cone_emit=[(t, n, u, s, 0.12) for (t, n, u, s, _) in crack_pts], **DECAL),
        dict(name="VeinCracks", texture="pb_vein_cracks", lifetime=(1.8, 2.3), rotation=(0, 360),
             size=[(0, 6), (0.06, 20, 3), (1, 21, 3)], transparency=[(0, 0.5), (0.1, 0.15), (0.6, 0.35), (1, 1)],
             color=TURQ, light_emission=1.0, cone_emit=[(round(t + 0.02, 3), n, u, s, 0.2) for (t, n, u, s, _) in crack_pts],
             **DECAL),
        dict(name="CrackFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Top", spread=(15, 15),
             speed=(5, 11), drag=1.2, accel=(0, 9, 0), lifetime=(0.45, 0.8), size=[(0, 2.5, 0.8), (0.3, 6.5, 1.5), (1, 1.5)],
             transparency=[(0, 0.12), (0.6, 0.38), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.45,
             rotation=(-15, 15), cone_emit=rflicker(g, flame_pts, 6, 1.4, k=2)),
        dict(name="CrackTongues", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, direction="Top", spread=(10, 10),
             speed=(4, 9), drag=1.2, accel=(0, 8, 0), lifetime=(0.35, 0.6), size=[(0, 2.5, 0.8), (0.3, 7, 1.5), (1, 2)],
             transparency=[(0, 0.2), (0.6, 0.45), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.45,
             rotation=(-10, 10), cone_emit=rflicker(g, flame_pts, 5, 1.3, k=1)),
        # la vibración del rugido levanta piedras que flotan un momento y vuelven a caer
        dict(name="ResonanceRocks", texture="pb_rock_2x2", flipbook=STATIC2x2, direction="Top", spread=(25, 25),
             speed=(9, 16), drag=0.8, accel=(0, -14, 0), lifetime=(1.1, 1.5), size=[(0, 0.8, 0.3), (1, 0.7, 0.2)],
             transparency=[(0, 0), (0.85, 0), (1, 1)], rotation=(0, 360), rot_speed=(-90, 90),
             cone_emit=rsamples(g, 30, u0=0.08, up=(0.5, 0.5), delay=(0.0, 0.08), k=2)),
        dict(name="CrackEmbers", texture="fx_spark002", direction="Top", spread=(35, 35), speed=(8, 18), drag=1.5,
             accel=(0, 6, 0), lifetime=(0.6, 1.1), size=twinkle(0.4), color=GLINT, light_emission=1.0, brightness=2.0,
             rotation=(0, 45), cone_emit=rflicker(g, flame_pts, 3, 1.0, k=2)),
        dict(name="FieldDust", texture="kk_smoke_04", direction="Top", spread=(70, 70), speed=(6, 14), drag=2,
             accel=(0, 3, 0), lifetime=(0.7, 1.1), size=[(0, 4, 1), (1, 12, 3)],
             transparency=[(0, 0.5), (0.4, 0.62), (1, 1)], color=DUST, rotation=(0, 360), zoffset=-2,
             cone_emit=rsamples(g, 26, up=(0.8, 0.8), delay=(0.0, 0.05))),
        dict(name="FieldSmoke", texture="fx_fog2001", direction="Top", spread=(30, 30), speed=(2, 6), drag=1,
             accel=(0, 1.5, 0), lifetime=(1.8, 2.6), size=[(0, 8, 2), (0.5, 16, 3), (1, 21, 3)],
             transparency=[(0, 0.72), (0.3, 0.64), (1, 1)], color=DUST_DARK, rotation=(0, 360), rot_speed=(-20, 20),
             zoffset=-3, cone_emit=rsamples(g, 26, up=(1.0, 2.5), delay=(0.1, 0.5))),
        # las rocas que arrastra la onda (Parts): saltan hacia adelante desde el frente y caen más allá
        dict(name="PlowRocks", type="meteor", direction="Front", pitch=24, spread=(22, 12), speed=(60, 100),
             accel=(0, -196, 0), drag=0.1, lifetime=(2.0, 2.0),
             sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": (1.4, 3.2), "aspect": (1.0, 0.85, 1.0),
                     "cube": True, "ground": True, "color": SLAB_RGB, "color_var": (0.8, 1.1),
                     "rot_speed": (-480, 480), "material": "Slate", "stick": 1.0, "sink": 0.2},
             trails=rock_trail("PlowRockDust", 1.5), land=ROCK_LAND, shatter=ROCK_CRUMBLE,
             cone_emit=rsamples(g, 56, u0=0.06, up=(0.6, 0.6))),
        dict(name="PlowBoulders", type="meteor", direction="Front", pitch=32, spread=(16, 10), speed=(50, 80),
             accel=(0, -196, 0), drag=0.1, lifetime=(2.3, 2.3),
             sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": (2.8, 4.8), "aspect": (1.0, 0.8, 1.0),
                     "cube": True, "ground": True, "color": SLAB_RGB, "color_var": (0.8, 1.1),
                     "rot_speed": (-300, 300), "material": "Slate", "stick": 1.3, "sink": 0.25},
             trails=rock_trail("PlowBoulderDust", 2.5), land=ROCK_LAND, shatter=ROCK_CRUMBLE,
             cone_emit=rsamples(g, 12, u0=0.2, s_max=0.7, up=(0.6, 0.6))),
        # ================ el final: lo que arrastraba se amontona y revienta ================
        dict(name="EndBurst", texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Front", pitch=50, spread=(30, 25),
             speed=(25, 50), drag=2.5, accel=(0, 2, 0), lifetime=(0.9, 1.4), size=[(0, 6, 1), (1, 18, 3)],
             transparency=[(0, 0.35), (0.4, 0.55), (1, 1)], color=DUST, rotation=(0, 360), rot_speed=(-40, 40),
             cone_emit=redge(12, 1.0, k=2)),
        dict(name="EndRocks", texture="pb_rock_2x2", flipbook=STATIC2x2, direction="Front", pitch=55, spread=(30, 25),
             speed=(35, 65), drag=0.4, accel=(0, -160, 0), lifetime=(0.6, 1.0), size=[(0, 2.0, 0.8), (1, 1.6, 0.6)],
             transparency=[(0, 0), (0.85, 0), (1, 1)], rotation=(0, 360), rot_speed=(-400, 400),
             cone_emit=redge(10, 1.0, k=3)),
        dict(name="EndFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Top", spread=(25, 25),
             speed=(8, 16), drag=1.2, accel=(0, 10, 0), lifetime=(0.45, 0.75), size=[(0, 3, 0.8), (0.3, 6, 1.2), (1, 1.5)],
             transparency=[(0, 0.1), (0.6, 0.4), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.45,
             rotation=(-15, 15), cone_emit=redge(9, 0.6, k=2)),
    ]
    return L


SEISMIC_ROAR = {
    "name": "SeismicRoar",
    "doc": ("PEBLEDON SKILL 1 (Rugido sísmico): junta energía en la boca y ruge hacia adelante: ondas de sonido "
            "turquesa, fuego cian y brasas. La onda baja al suelo y avanza en triángulo: parte el suelo, levanta losas, "
            "arrastra rocas hacia adelante y deja grietas con venas turquesa de las que brota fuego cian. Ruge a los "
            "SeismicRoarTimes.Roar s; el frente sale a los WaveStart s y llega al final a los WaveEnd s "
            "(SeismicRoarFrontTime(distancia) = cuándo pasa por cada punto: ahí aplica el daño, la lentitud, la "
            "exposición y el empujón)."),
    "duration": 3.6,
    "cone": {"length": RL, "angle": RA, "wave": [T0R, TWR, EASE_R], "head": True, "mouth_h": MOUTH_H},
    "times": {"Roar": T_ROAR, "WaveStart": T0R, "WaveEnd": round(T0R + TWR, 3)},
    "front": ROAR_FRONT,
    "field": ROAR_FIELD,
    "light": {"color": CRYSTAL, "brightness": 5, "range": 40, "time": 0.9, "delay": T_ROAR},
    "shakes": [(0.02, 0.25, T_ROAR), (T_ROAR, 0.9, 0.5), (T0R + 0.1, 0.5, TWR)],
}
SEISMIC_ROAR["layers"] = roar_layers(random.Random(61))

# ----------------------------------------------------------------------------- SKILL 2: Aliento azul
# Como el aliento de Godzilla: FUEGO AZUL CONCENTRADO que sale de la boca y se mantiene recto hacia adelante, del
# color de sus placas. Sin aros ni hebras alrededor: un núcleo casi blanco, fuego turquesa en vetas que corre muy
# rápido hacia adelante (Beams) y llamas que viajan pegadas al rayo de la boca a la punta (LockedToPart: si lo barre,
# el fuego se queda recto con él). Más delgado que los rayos de Kaiju Zero y Omnívora. La boca junta energía y
# escupe el fuego; dura 3 s y se puede apuntar (modo "beam": se corta en la primera superficie, hasta B_LEN studs ×
# escala = 3 veces su largo). Donde pega, el fuego salpica hacia afuera, saltan rocas y el suelo queda con grietas
# turquesa que arden (y una estela si lo barre).
B_START, B_GROW, B_STOP, B_FADE = 0.55, 0.14, 3.55, 0.3   # sale, tarda en llegar, se corta, se apaga (3 s de rayo)
B_HIT = B_START + B_GROW
B_ON = B_STOP - 0.02
B_LEN = 126                     # largo máximo (escala 1): 3 veces su largo de la nariz a la cola (~42 studs)
B_MOUTH = dict(offset=(0, 0, -1.5))
B_IMPACT = dict(line_u=1.0, offset=(0, 0, 2.5), impact=True)
B_TIP = dict(line_u=1.0, offset=(0, 0, 2.5))
B_ALONG = dict(line_u=0.5)
B_JET = 0.3                     # lo que tarda una llama en ir de la boca a la punta (speed_len = 1 / B_JET)
B_WIDTH_T = [(0, 0), (B_START, 0), (B_START + 0.05, 1.3), (B_START + 0.2, 1.0), (B_STOP - 0.05, 1.0), (B_STOP, 0.75),
             (B_STOP + B_FADE, 0)]
B_ALPHA_T = [(0, 0), (B_STOP, 0), (B_STOP + B_FADE, 1)]
BREATH_CORE = [(0, (240, 255, 254)), (1, (210, 255, 251))]
BLUE_FIRE = [(0, (120, 245, 240)), (1, (70, 210, 210))]       # el fuego de adentro (a lo largo del rayo)
BLUE_FIRE_OUT = [(0, (50, 185, 215)), (1, (35, 140, 185))]    # el de afuera, más profundo (tira a azul)
JET_FLAME = [(0, (170, 252, 250)), (0.3, (90, 225, 235)), (0.7, (45, 165, 210)), (1, (30, 110, 170))]


def b_along(w, k=0.92):
    return {"type": "Box", "size": (w, w, 1), "len_k": k}


def bbeam(name, texture, width, color, transparency, le, bright, tex_len, speed, pulse, hz, z):
    return {"name": name, "texture": texture, "mode": "Wrap", "tex_len": tex_len, "speed": speed,
            "light_emission": le, "brightness": bright, "color": color, "transparency": transparency,
            "width": width, "w0": 1.0, "w1": 1.0, "width_t": B_WIDTH_T, "alpha_t": B_ALPHA_T,
            "pulse": pulse, "pulse_hz": hz, "zoffset": z}


BREATH_BEAMS = [
    # la luz suave alrededor (no se ve como un tubo: solo hace brillar)
    bbeam("Glow", "kz_beam_glow", 24, [(0, CRYSTAL), (1, CRYSTAL_MID)], [(0, 0.84), (0.03, 0.78), (1, 0.8)],
          1.0, 0.85, 60, 0.4, 0.06, 5, 0.0),
    # el fuego de afuera: vetas turquesa profundas que corren hacia adelante y se deshacen en el borde
    bbeam("FireOuter", "pb_breath_fire", 18, BLUE_FIRE_OUT, [(0, 0.45), (0.04, 0.22), (1, 0.3)],
          0.5, 1.4, 34, 4.5, 0.08, 9, 0.1),
    # el fuego de adentro: más claro y más rápido
    bbeam("FireInner", "pb_breath_fire", 8.5, BLUE_FIRE, [(0, 0.35), (0.04, 0.1), (1, 0.15)],
          1.0, 1.6, 22, 6.5, 0.08, 13, 0.2),
    # el núcleo casi blanco
    bbeam("Core", "kz_beam_core", 3.2, BREATH_CORE, [(0, 0.2), (0.03, 0.0), (1, 0.0)], 1.0, 2.2, 18, 3.5, 0.08, 15, 0.3),
]

BREATH_LAYERS = [
    # ---------------- la carga: la energía se junta en la boca y le salen llamas azules ----------------
    dict(name="BChargeMotes", texture="fx_particle02", shape={"type": "Sphere", "radius": 12, "style": "Surface",
                                                              "inout": "Inward"},
         speed=(30, 40), lifetime=(0.28, 0.32), size=[(0, 0), (0.3, 1.0), (1, 0.3)], color=GLINT, light_emission=1.0,
         brightness=1.8, stream=[(0.0, B_START - 0.03, 90, 130)], **B_MOUTH),
    dict(name="BChargeGlow", texture="fx_glow", emit=[(0.0, 1)], lifetime=(B_START, B_START),
         size=[(0, 2), (0.85, 10), (1, 13)], transparency=[(0, 0.8), (0.85, 0.3), (1, 0.6)], color=TURQ,
         light_emission=1.0, brightness=1.3, zoffset=2, **B_MOUTH),
    dict(name="BChargeFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, shape={"type": "Sphere", "radius": 2.0},
         direction="Front", spread=(45, 45), speed=(4, 9), accel=(0, 6, 0), lifetime=(0.2, 0.32),
         size=[(0, 1, 0.3), (0.35, 2.8, 0.6), (1, 0.6)], transparency=[(0, 0.2), (0.6, 0.45), (1, 1)], color=FLAME,
         light_emission=1.0, brightness=1.45, rotation=(0, 360), stream=[(0.1, B_START, 20, 70)], **B_MOUTH),
    # ---------------- la boca: el fuego que escupe mientras dura ----------------
    dict(name="BMouthFlash", texture="fx_glow", emit=[(B_START, 1)], lifetime=(0.22, 0.22),
         size=[(0, 6), (0.3, 15), (1, 16)], transparency=[(0, 0.5), (1, 1)], color=TURQ, light_emission=1.0,
         brightness=1.0, zoffset=3, **B_MOUTH),
    dict(name="BMouthFire", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Front", spread=(30, 30),
         speed=(18, 40), drag=4, accel=(0, 4, 0), lifetime=(0.18, 0.3), size=[(0, 2, 0.5), (0.4, 5.5, 1.2), (1, 3)],
         transparency=[(0, 0.15), (0.6, 0.4), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.45,
         rotation=(0, 360), rot_speed=(-120, 120), stream=[(B_START, B_ON, 50, 50)], **B_MOUTH),
    dict(name="BMouthGlow", texture="fx_glow", lifetime=(0.14, 0.2), size=[(0, 9, 1.5), (1, 11, 1.5)],
         transparency=[(0, 0.62), (1, 0.85)], color=TURQ, light_emission=1.0, brightness=1.0, zoffset=2,
         stream=[(B_START, B_ON, 12, 12)], **B_MOUTH),
    # ---------------- el chorro: llamas pegadas al rayo que van de la boca a la punta ----------------
    dict(name="BFireJet", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Front", spread=(3, 3),
         speed_len=(1 / B_JET, 1.08 / B_JET), lifetime=(B_JET * 0.92, B_JET), size=[(0, 2.6, 0.6), (0.5, 6.5, 1.4), (1, 9, 2)],
         transparency=[(0, 0.25), (0.5, 0.35), (0.85, 0.55), (1, 1)], color=JET_FLAME, light_emission=0.7, brightness=1.5,
         rotation=(0, 360), rot_speed=(-240, 240), locked=True, stream=[(B_START, B_ON, 150, 150)]),
    dict(name="BFireTongues", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, orientation="VelocityParallel",
         direction="Front", spread=(3, 3), speed_len=(1 / B_JET, 1.1 / B_JET), lifetime=(B_JET * 0.9, B_JET),
         size=[(0, 3, 0.8), (0.5, 8, 1.5), (1, 10, 2)], transparency=[(0, 0.3), (0.6, 0.45), (1, 1)], color=JET_FLAME,
         light_emission=0.7, brightness=1.45, locked=True, stream=[(B_START, B_ON, 80, 80)]),
    # unas pocas brasas que se escapan del chorro
    dict(name="BEmbers", texture="fx_spark002", shape=b_along(5), direction="Top", spread=(180, 180), speed=(3, 9),
         drag=1.5, accel=(0, 6, 0), lifetime=(0.4, 0.8), size=twinkle(0.45), color=GLINT, light_emission=1.0,
         brightness=1.9, rotation=(0, 45), stream=[(B_HIT, B_ON, 30, 30)], **B_ALONG),
    # ---------------- la punta mientras crece ----------------
    dict(name="BHead", texture="fx_fire_2x2", flipbook=STATIC2x2, line_u=1.0, lifetime=(0.06, 0.09),
         size=[(0, 7), (1, 9)], transparency=[(0, 0.2), (1, 0.5)], color=FLAME, light_emission=1.0, brightness=1.5,
         rotation=(0, 360), zoffset=3, stream=[(B_START, B_HIT + 0.03, 60, 60)]),
    # ---------------- el impacto: cada vez que empieza a pegar, el fuego salpica ----------------
    dict(name="BImpactFlash", texture="fx_glow", emit=[(0, 1)], on_hit=True, lifetime=(0.25, 0.25),
         size=[(0, 8), (0.25, 20), (1, 22)], transparency=[(0, 0.45), (0.5, 0.7), (1, 1)], color=TURQ,
         light_emission=1.0, brightness=0.9, zoffset=3, **B_IMPACT),
    dict(name="BImpactBurst", texture="fx_fire_2x2", flipbook=STATIC2x2, emit=[(0, 14)], on_hit=True, direction="Back",
         spread=(80, 80), speed=(25, 55), drag=3, accel=(0, 10, 0), lifetime=(0.35, 0.55),
         size=[(0, 3, 1), (0.3, 8, 2), (1, 3)], transparency=[(0, 0.12), (0.6, 0.4), (1, 1)], color=FLAME,
         light_emission=1.0, brightness=1.45, rotation=(0, 360), rot_speed=(-80, 80), **B_IMPACT),
    dict(name="BImpactRocks", texture="pb_rock_2x2", flipbook=STATIC2x2, emit=[(0, 14)], on_hit=True, direction="Back",
         spread=(70, 70), speed=(30, 70), drag=0.5, accel=(0, -150, 0), lifetime=(0.6, 1.0),
         size=[(0, 1.8, 0.7), (1, 1.5, 0.5)], transparency=[(0, 0), (0.85, 0), (1, 1)], rotation=(0, 360),
         rot_speed=(-400, 400), **B_IMPACT),
    # ---------------- el impacto mientras pega: el fuego se abre contra la superficie ----------------
    dict(name="BImpactGlow", texture="fx_glow", lifetime=(0.14, 0.2), size=[(0, 13, 2), (1, 16, 2)],
         transparency=[(0, 0.6), (1, 0.85)], color=TURQ, light_emission=1.0, brightness=1.0, zoffset=2,
         stream=[(B_HIT, B_ON, 12, 12)], **B_IMPACT),
    dict(name="BImpactFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Back", spread=(75, 75),
         speed=(14, 32), drag=2.5, accel=(0, 12, 0), lifetime=(0.3, 0.5), size=[(0, 2.5, 0.8), (0.3, 6.5, 1.4), (1, 1.5)],
         transparency=[(0, 0.12), (0.6, 0.4), (1, 1)], color=FLAME, light_emission=1.0, brightness=1.45,
         rotation=(0, 360), rot_speed=(-60, 60), stream=[(B_HIT, B_ON, 45, 45)], **B_IMPACT),
    dict(name="BImpactTongues", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, orientation="VelocityParallel",
         direction="Back", spread=(80, 80), speed=(20, 40), drag=3, lifetime=(0.2, 0.35),
         size=[(0, 3, 0.8), (0.4, 6.5, 1.4), (1, 2)], transparency=[(0, 0.2), (0.6, 0.45), (1, 1)], color=FLAME,
         light_emission=1.0, brightness=1.4, stream=[(B_HIT, B_ON, 30, 30)], **B_IMPACT),
    dict(name="BImpactChips", texture="pb_rock_2x2", flipbook=STATIC2x2, direction="Back", spread=(70, 70),
         speed=(30, 65), drag=0.5, accel=(0, -150, 0), lifetime=(0.5, 0.9), size=[(0, 1.2, 0.5), (1, 1.0, 0.4)],
         transparency=[(0, 0), (0.85, 0), (1, 1)], rotation=(0, 360), rot_speed=(-400, 400),
         stream=[(B_HIT, B_ON, 16, 16)], **B_IMPACT),
    dict(name="BImpactSparks", texture="fx_spark002", direction="Back", spread=(80, 80), speed=(20, 50), drag=2,
         accel=(0, 8, 0), lifetime=(0.4, 0.8), size=twinkle(0.5), color=GLINT, light_emission=1.0, brightness=1.9,
         rotation=(0, 45), stream=[(B_HIT, B_ON, 30, 30)], **B_IMPACT),
    dict(name="BImpactDust", texture="kk_smoke_04", direction="Back", spread=(70, 70), speed=(8, 18), drag=2,
         accel=(0, 3, 0), lifetime=(0.6, 1.0), size=[(0, 4, 1), (1, 12, 2)], transparency=[(0, 0.5), (0.4, 0.62), (1, 1)],
         color=DUST, rotation=(0, 360), zoffset=-2, stream=[(B_HIT + 0.05, B_ON, 10, 10)], **B_IMPACT),
    # ---------------- el corte ----------------
    dict(name="BCutFlash", texture="fx_glow", emit=[(B_STOP + 0.02, 1)], lifetime=(0.22, 0.22),
         size=[(0, 8), (0.3, 18), (1, 20)], transparency=[(0, 0.3), (1, 1)], color=TURQ, light_emission=1.0,
         brightness=1.0, zoffset=3, **B_TIP),
    dict(name="BCutEmbers", texture="fx_spark002", emit=[(B_STOP + 0.02, 24)], direction="Back", spread=(180, 180),
         speed=(6, 20), drag=1.5, accel=(0, 6, 0), lifetime=(0.6, 1.0), size=twinkle(0.5), color=GLINT,
         light_emission=1.0, brightness=1.9, rotation=(0, 45), **B_TIP),
    dict(name="BMouthPuff", texture="fx_smoke_2x2", flipbook=STATIC2x2, emit=[(B_STOP + 0.02, 5)], direction="Front",
         spread=(30, 30), speed=(6, 14), drag=2, accel=(0, 4, 0), lifetime=(0.6, 0.9), size=[(0, 3, 1), (1, 9, 2)],
         transparency=[(0, 0.5), (0.4, 0.65), (1, 1)], color=TURQ_SOFT, light_emission=0.2, rotation=(0, 360),
         **B_MOUTH),
    # ---------------- el suelo bajo el impacto: grietas que arden ----------------
    dict(name="BGroundCracks", texture="pb_vein_cracks", emit=[(0.02, 1)], on_hit=True, at_ground=True,
         offset=(0, 0.16, 0), lifetime=(2.6, 2.6), size=[(0, 6), (0.08, 26), (1, 27)],
         transparency=[(0, 1), (0.05, 0.3), (0.7, 0.45), (1, 1)], color=[(0, (110, 236, 232)), (1, CRYSTAL_MID)],
         light_emission=0.8, rotation=(0, 360), **DECAL),
    dict(name="BGroundDark", texture="pb_vein_cracks", emit=[(0.02, 1)], on_hit=True, at_ground=True,
         offset=(0, 0.12, 0), lifetime=(2.8, 2.8), size=[(0, 8), (0.08, 28), (1, 29)],
         transparency=[(0, 1), (0.05, 0.25), (0.75, 0.4), (1, 1)], color=CRACK_DARK, rotation=(0, 360), **DECAL),
    dict(name="BGroundFlames", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, at_ground=True, offset=(0, 0.8, 0),
         shape={"type": "Box", "size": (8, 1, 8)}, direction="Top", spread=(10, 10), speed=(4, 9), accel=(0, 8, 0),
         lifetime=(0.35, 0.6), size=[(0, 2, 0.6), (0.3, 5.5, 1.2), (1, 1.5)], transparency=[(0, 0.2), (0.6, 0.45), (1, 1)],
         color=FLAME, light_emission=1.0, brightness=1.45, rotation=(-10, 10), stream=[(B_HIT + 0.05, B_ON, 22, 22)]),
    # la estela que deja al barrer el suelo: grietas con venas, suelo oscuro y la mancha que brilla
    dict(name="BTrailCracks", texture="pb_vein_cracks", trail=True, at_ground=True, offset=(0, 0.14, 0),
         lifetime=(2.2, 2.2), size=[(0, 6), (0.1, 18), (1, 19)], transparency=[(0, 1), (0.06, 0.3), (0.75, 0.45), (1, 1)],
         color=[(0, (110, 236, 232)), (1, CRYSTAL_MID)], light_emission=0.8, rotation=(0, 360), **DECAL),
    dict(name="BTrailBurn", texture="fx_glow", trail=True, at_ground=True, offset=(0, 0.18, 0), lifetime=(1.6, 1.6),
         size=[(0, 5), (0.1, 10), (1, 9)], transparency=[(0, 1), (0.06, 0.25), (0.6, 0.55), (1, 1)], color=TURQ,
         light_emission=1.0, **DECAL),
    dict(name="BTrailDark", texture="pb_vein_cracks", trail=True, at_ground=True, offset=(0, 0.1, 0),
         lifetime=(2.4, 2.4), size=[(0, 7), (0.1, 21), (1, 22)], transparency=[(0, 1), (0.06, 0.25), (0.75, 0.42), (1, 1)],
         color=CRACK_DARK, rotation=(0, 360), **DECAL),
]

BLUE_BREATH = {
    "name": "BlueBreath",
    "doc": ("PEBLEDON SKILL 2 (Aliento azul): como el aliento de Godzilla: junta energía en la boca 0.55 s y escupe "
            "fuego azul concentrado que se mantiene recto (núcleo casi blanco, fuego turquesa en vetas y llamas que "
            "corren pegadas al rayo), sin aros. Dura 3 s y se puede apuntar: pega en la primera superficie (hasta 126 "
            "studs × escala = 3 veces su largo); el fuego salpica, saltan rocas y el suelo queda con grietas que arden "
            "(estela si lo barre)."),
    "duration": B_STOP + B_FADE,
    "beam": {"start": B_START, "grow": B_GROW, "stop": B_STOP, "fade": B_FADE, "max_len": B_LEN, "trail_every": 0.1,
             "trail_move": 4, "rehit": 0.3, "light_color": CRYSTAL, "light_brightness": 4, "light_range": 40},
    "beams": BREATH_BEAMS,
    "layers": BREATH_LAYERS,
    "shake_ramp": (B_START, B_STOP, 0.15, 0.3, 1.0),
    "shakes": [(B_HIT, 0.5, 0.35), (B_STOP, 0.25, 0.3)],
}

SPECS = {
    "SeismicRoar": SEISMIC_ROAR,
    "BlueBreath": BLUE_BREATH,
}
