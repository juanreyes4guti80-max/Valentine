"""OMNÍVORA — ULTIMATE: CATACLISMO GRAVITACIONAL (radio de 500 m).

Una sola secuencia continua. Todo lo que se mueve responde al MISMO campo gravitacional (playCataclysm en el módulo,
render_cataclysm en el simulador): las rocas, los portadores de polvo y partículas, las corrientes de energía, los
brazos de polvo y las víctimas. El campo tiene tres partes que se encienden y se pisan en el tiempo:
  L  sin gravedad: lo que está en el suelo se despega y sube hacia su franja de altura.
  S  remolino: todo gira alrededor del epicentro, más rápido cerca del centro (cada cosa con su variación).
  A  atracción: la singularidad tira de todo; lo de adentro primero. Lo que gira cae en espiral hacia ella y, al
     llegar a su horizonte, desaparece. La tormenta se vacía porque el agujero negro se la come.
  0.0 - 3.6 s   DESPERTAR: una onda recorre el suelo hasta los 500 m; tiembla; se despegan piedras, luego rocas y
                trozos de terreno (tiemblan antes de salir, algunos salen disparados); polvo, grietas y ondas.
  2.4 - 8 s     VÓRTICE: las corrientes se organizan en una tormenta que gira: polvo y nebulosa arrastrados, rocas que
                orbitan a distintas alturas y velocidades, remolinos secundarios, corrientes de energía del suelo al
                cielo. Las rocas chocan y se rompen en pedazos que siguen girando hasta deshacerse.
  6.4 - 12.4 s  SINGULARIDAD: sobre el epicentro nace un agujero negro pequeño que crece hasta ser colosal; las
                corrientes se inclinan hacia él y la materia sube en espiral a alimentarlo.
  10.6 - 14.2 s CONSUMO TOTAL: la tormenta se derrumba hacia el centro y sube al agujero; las víctimas son levantadas
                y arrastradas hacia él. Al final solo queda el agujero suspendido y restos que terminan de entrar.
  14.4 - 16.6 s MASA CRÍTICA: la luz del agujero crece, late cada vez más rápido y distorsiona; destello blanco.
  16.62 s       DETONACIÓN: esfera de energía, onda expansiva en el cielo y en el suelo, distorsión, partículas
                expulsadas; las víctimas salen disparadas HACIA ABAJO.
  ~17.2 s       IMPACTO: cada víctima se estrella en su punto (CataclysmImpact): onda, cráter, grietas, rocas, polvo.
  17.4 - 22.4 s RESIDUOS: polvo que sube y se abre despacio, piedras que caen, partículas cósmicas que flotan.
Todas las medidas son para el radio de referencia (R studs): con otro radio, todo se escala igual.
"""
import math

from vfx_omnivora import (BOLT, CRACKC, DECAL, DEEPB, DUST, ENERGY, FLASH, INWARD, MOUTH, NEBW, PINKS, RING2, RINGC,
                          SCORCH, SHOCK, STAR, STATIC2x2, STREAK, VOIDC)

R = 1786.0       # 500 m con la conversión oficial de Roblox (1 stud = 0.28 m)
H = 760.0        # altura de la singularidad sobre el epicentro
DET = 16.62

T = {
    "front": [0.0, 3.6],          # la onda del despertar llega a los 500 m
    "lift": [0.2, 3.0],           # la gravedad desaparece (L de 0 a 1)
    "swirl": [2.4, 7.5],          # la tormenta se organiza (S de 0 a 1)
    "swirl_up": [10.6, 13.0],     # al consumir gira más rápido
    "sing": [6.4, 12.4],          # la singularidad crece
    "attract": [6.8, 10.6, 12.4],  # atracción: 0 -> a_mid -> 1
    "victims": [10.8, 13.6],      # las víctimas suben a la singularidad
    "crit": [14.4, 16.6],         # masa crítica
    "det": DET,
    "end": 23.0,
}
PHASES = [["Despertar gravitacional", 0.0], ["Formación del vórtice", 2.4], ["La singularidad emerge", 6.4],
          ["Consumo total", 10.6], ["Masa crítica", 14.4], ["Detonación cósmica", DET],
          ["Impacto planetario", 17.15], ["Secuelas cósmicas", 17.6]]

FIELD = {
    "omega0": 0.16,     # rad/s en el borde (más rápido hacia el centro)
    "omega_pow": 0.6,
    "r_core": 0.12,     # radio (fracción de R) donde deja de acelerar hacia el centro
    "swirl_boost": 0.9,  # S llega a 1.9 durante el consumo
    "a_mid": 0.35,
    "c_in": 0.62,       # qué tan rápido cae hacia el eje cuando A = 1
    "c_up": 1.4,        # qué tan rápido sube a la altura de la singularidad cuando A = 1
    "c_rise": 0.9,      # qué tan rápido sube a su franja sin gravedad
    "funnel": 0.45,     # el embudo: lo de adentro sube más cuando hay atracción
    "turb_r": 0.025,    # turbulencia (fracción de R y de H)
    "turb_y": 0.02,
    "capture": 1.3,     # se lo traga dentro de capture × radio del agujero
}

HOLE = {
    "rb": [6.0, 150.0],    # radio del núcleo al nacer y al máximo
    "crit_shrink": 0.82,   # se comprime antes de detonar
    "halo": 6.5, "photon": 2.35, "purple": 2.85, "swirl": 6.0, "wind": 7.6, "disk": 8.0, "lens": 4.2,
    "glow": [2.6, 10.5],   # resplandor de la masa crítica (radios)
    "spin_swirl": -260.0, "spin_wind": 170.0, "spin_disk": -45.0, "tilt": 22.0,
    "shell": 3.3,          # la materia cae desde capture...shell radios
    "pulse_hz": [1.0, 7.0],
}

ROCKS = {
    # rocas medianas: [t0, t1, tasa0, tasa1] por segundo
    "medium": {"rate": [[1.0, 3.0, 4, 12], [3.0, 10.0, 12, 12], [10.0, 11.5, 12, 0]], "size": [6, 26], "skew": 1.8,
               "aspect": [0.55, 1.1], "max": 140, "tremble": [0.25, 0.9], "shoot": 0.22, "band": [0.04, 0.5],
               "rise": [0.5, 1.3], "w": [0.75, 1.3], "inward": [0.7, 1.3], "break_p": 0.22, "break_t": [4.5, 12.5],
               "dark": 0.45},
    # trozos de terreno: losas grandes con el color y el material del suelo
    "chunk": {"rate": [[2.0, 9.5, 1.3, 1.3]], "size": [45, 110], "skew": 1.4, "aspect": [0.28, 0.5], "max": 18,
              "tremble": [0.6, 1.4], "shoot": 0.12, "band": [0.03, 0.3], "rise": [0.32, 0.7], "w": [0.7, 1.1],
              "inward": [0.6, 1.0], "break_p": 0.65, "break_t": [5.0, 12.0], "dark": 0.15},
    "frag": {"n": [3, 5], "k": [0.32, 0.6], "life": [1.8, 3.4]},
    "collide": {"every": 0.12, "min_size": 24},
    # lo que llueve después de la detonación
    "rain": {"n": 36, "t": [DET + 0.25, DET + 2.9], "size": [3, 11], "height": [160, 620], "r": [0.05, 0.7]},
    "r_min": 0.08,
}

# anillos de portadores de partículas: [radio (fracción de R), cantidad, franja (fracción de H), alto de la caja (fracción
# de H)]. Cada portador es una caja invisible que sigue al campo con partículas pegadas (LockedToPart).
RINGS = [[0.16, 5, 0.40, 0.32], [0.30, 7, 0.33, 0.29], [0.46, 9, 0.26, 0.25], [0.62, 10, 0.2, 0.22],
         [0.78, 9, 0.15, 0.19], [0.94, 8, 0.1, 0.16]]   # un embudo: los de adentro, más arriba
FRONT_N = 16
# grietas que se abren en el suelo detrás de la onda del despertar: [desde, hasta, cada cuántos segundos]
CRACKS = [0.3, 4.2, 0.12]
UPDRAFTS = {"n": 10, "r": [0.2, 0.85], "band": [0.05, 0.2]}
EDDIES = {"n": 6, "r": [0.25, 0.8], "band": [0.06, 0.3], "box": [260, 140, 260], "spin": [110, 190],
          "life": [[3.6, 9.5], [4.6, 10.4], [5.2, 11.0], [6.0, 11.6], [6.8, 12.0], [7.6, 12.2]]}
AFTER = {"n": 18, "r": [0.04, 0.7]}


def flow_beam(name, texture, width, color, transparency, le, bright, tex_len, speed):
    return {"name": name, "texture": texture, "width": width, "color": color, "transparency": transparency,
            "light_emission": le, "brightness": bright, "tex_len": tex_len, "speed": speed}


# corrientes de energía del suelo al cielo (cadenas de Beams que giran con la tormenta y se doblan hacia la singularidad)
CURRENTS = {
    "n": 14, "points": 11, "r": [0.2, 0.62], "wind": [0.6 * math.pi, 1.0 * math.pi], "top": 1.15, "taper": 0.55,
    "w": [0.85, 1.15], "fade": [3.2, 6.5], "bend": 1.4,
    "beams": [flow_beam("CurrentCeleste", "om_beam_flow", 90, [[0, [160, 215, 255]], [1, [110, 185, 255]]], 0.25, 1.0,
                        1.25, 260, 1.4),
              flow_beam("CurrentPurple", "om_beam_flow", 72, [[0, [220, 140, 255]], [1, [180, 80, 245]]], 0.32, 1.0,
                        1.25, 300, 1.1),
              flow_beam("CurrentGlow", "om_beam_glow", 130, [[0, [120, 180, 255]], [1, [90, 150, 255]]], 0.5, 1.0,
                        1.1, 400, 0.8)],
}
# brazos de polvo cerca del suelo: cada punto sigue al campo (el giro diferencial los enrolla y el consumo los traga)
BANDS = {
    "n": 6, "points": 9, "r": [0.15, 0.75], "spiral": 1.7, "band": [0.04, 0.2], "fade": [2.6, 6.0],
    "beams": [flow_beam("DustArm", "om_beam_nebula", 300, [[0, [255, 255, 255]], [1, [230, 235, 255]]], 0.42, 0.18,
                        1.0, 420, 0.35),
              flow_beam("DustArmStars", "om_beam_stars", 220, [[0, [255, 255, 255]], [1, [200, 230, 255]]], 0.35, 1.0,
                        1.4, 360, 0.6)],
}
# corrientes de acreción: de la tormenta al agujero negro (aparecen con la atracción)
STREAMS = {
    "n": 5, "points": 13, "r": [0.4, 0.75], "band": [0.12, 0.3], "turns": 1.1, "fade": [8.0, 10.5],
    "beams": [flow_beam("Accretion", "om_beam_flow", 110, [[0, [200, 235, 255]], [1, [120, 190, 255]]], 0.15, 1.0,
                        1.4, 240, 2.2)],
}
# anillos de luz sobre el suelo (Beams en círculo que siempre miran a la cámara)
LOOPS = {
    "points": 36,
    "front": flow_beam("FrontWave", "om_beam_glow", 70, [[0, [150, 210, 255]], [1, [150, 210, 255]]], 0.35, 1.0, 1.2,
                       500, 0.6),
    "ripple": flow_beam("GravityRipple", "om_beam_glow", 46, [[0, [120, 170, 255]], [1, [120, 170, 255]]], 0.5, 1.0,
                        1.1, 500, 0.4),
    "ripple_purple": flow_beam("GravityRipplePurple", "om_beam_glow", 40, [[0, [200, 110, 255]], [1, [200, 110, 255]]],
                               0.55, 1.0, 1.1, 500, 0.4),
    "ripples": [0.5, 1.4, 2.3, 3.2, 4.1, 5.0, 5.9, 6.8, 7.7, 8.6],   # cuándo sale cada onda
    "ripple_time": 2.4,
    "det_ground": flow_beam("ShockGround", "om_beam_glow", 150, [[0, [190, 230, 255]], [1, [190, 230, 255]]], 0.15,
                            1.0, 1.4, 600, 0.0),
    "det_ground_core": flow_beam("ShockGroundCore", "om_beam_core", 60, [[0, [235, 245, 255]], [1, [235, 245, 255]]],
                                 0.1, 1.0, 1.6, 600, 0.0),
    "det_sky": flow_beam("ShockSky", "om_beam_glow", 120, [[0, [170, 215, 255]], [1, [170, 215, 255]]], 0.2, 1.0, 1.3,
                         600, 0.0),
    "det_sky_purple": flow_beam("ShockSkyPurple", "om_beam_glow", 100, [[0, [200, 110, 255]], [1, [200, 110, 255]]],
                                0.3, 1.0, 1.3, 600, 0.0),
}

VICTIMS = {"stagger": 0.28, "hold_r": 1.75, "hold_drop": 0.25, "hold_spin": 0.6, "turns": 0.85, "tremble": 0.5,
           "fall": 0.55, "fall_stagger": 0.06, "land_max": 0.55, "ref": 40.0,
           "tether": flow_beam("Tether", "om_beam_flow", 34, [[0, [170, 220, 255]], [1, [210, 130, 255]]], 0.3, 1.0,
                               1.4, 120, 2.6)}

DETO = {"core": [0.3, 3.0, 0.04, 0.45],     # [crece en s, hasta radios, empieza a desvanecerse, se desvanece en s]
        "shell": [1.1, 2040.0, 0.15], "shell2": [1.0, 1700.0, 0.06, 0.25], "ring": [0.6, 2040.0],
        "distort": [0.85, 2040.0, 0.55], "sky": [1.4, 1.0], "ground": [0.15, 1.35, 1.0], "wall_n": 20}

# sacudida de cámara: [segundo, intensidad] (lineal entre puntos); los impactos suman sus golpes
SHAKE = [[0.0, 0.04], [3.5, 0.22], [7.5, 0.4], [10.6, 0.5], [12.6, 0.85], [14.2, 0.32], [14.4, 0.3], [16.55, 0.95],
         [DET, 2.4], [DET + 0.7, 0.9], [DET + 1.9, 0.35], [DET + 3.9, 0.1], [DET + 5.4, 0.0]]
# corrección de color: [segundo, brillo, contraste, saturación, tinte R, G, B]
CC = [[0.0, 0, 0, 0, 255, 255, 255], [2.5, -0.06, 0.05, -0.05, 225, 232, 255], [6.4, -0.14, 0.1, -0.12, 200, 210, 255],
      [12.6, -0.18, 0.14, -0.15, 190, 200, 255], [14.4, -0.2, 0.15, -0.18, 188, 196, 255],
      [16.3, 0.15, 0.22, -0.2, 225, 236, 255], [16.55, 0.4, 0.3, -0.3, 230, 240, 255], [DET, 0.3, 0.2, -0.15, 240, 246, 255],
      [DET + 0.6, 0.05, 0.08, -0.08, 235, 240, 255], [DET + 3.0, -0.05, 0.05, -0.05, 230, 236, 255],
      [DET + 5.5, 0, 0, 0, 255, 255, 255]]
FLASH_T = [16.45, 16.6, 0.05, 0.3]   # empieza, máximo, se sostiene, se apaga en


def layer(name, role, **kw):
    return dict(name=name, role=role, **kw)


TW = [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2), (0.72, 2.8), (1, 0)]


def twinkle(k):
    return [(t, round(v * k, 3)) for t, v in TW]


DUSTC = [(0, (138, 144, 170)), (0.5, (112, 118, 146)), (1, (90, 96, 124))]
PEBBLE = [(0, (150, 154, 168)), (1, (112, 116, 132))]
STORM_ENV = [(0, 0), (2.4, 0.15), (5.0, 0.8), (7.5, 1.0), (10.6, 1.25), (12.6, 1.1), (13.8, 0.3), (14.2, 0)]

LAYERS = [
    # ---------------- la tormenta (en los portadores de los anillos; las partículas giran pegadas a ellos) ----------------
    layer("StormDust", "storm", locked=True, texture="kk_smoke_07", direction="Top", spread=(40, 40), speed=(5, 20),
          accel=(0, 6, 0), lifetime=(2.6, 3.6), size=[(0, 60, 15), (1, 100)], transparency=[(0, 1), (0.2, 0.72), (0.7, 0.78), (1, 1)],
          color=DUSTC, rotation=(0, 360), rot_speed=(-25, 25), zoffset=-4, rate=5.0, env=STORM_ENV),
    layer("StormDark", "storm", locked=True, texture="kk_smoke_04", direction="Top", spread=(40, 40), speed=(4, 14),
          lifetime=(2.4, 3.2), size=[(0, 70, 15), (1, 100)], transparency=[(0, 1), (0.2, 0.55), (0.7, 0.62), (1, 1)],
          color=[(0, (30, 38, 80)), (1, (16, 22, 52))], rotation=(0, 360), rot_speed=(-20, 20), zoffset=-5, rate=1.6,
          env=STORM_ENV),
    layer("StormNebula", "storm", locked=True, texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Top",
          spread=(40, 40), speed=(4, 14), lifetime=(2.2, 3.0), size=[(0, 70, 15), (1, 100)],
          transparency=[(0, 1), (0.2, 0.5), (0.7, 0.58), (1, 1)], color=NEBW, light_emission=0.15, rotation=(0, 360),
          rot_speed=(-20, 20), zoffset=-3, rate=2.4, env=STORM_ENV),
    layer("StormMotes", "storm", locked=True, texture="fx_spark002", direction="Top", spread=(60, 60), speed=(10, 30),
          lifetime=(1.2, 2.0), size=twinkle(3.0), color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 45),
          rate=8, env=STORM_ENV),
    layer("StormPebbles", "storm", locked=True, texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top",
          spread=(30, 30), speed=(10, 30), lifetime=(2.5, 3.5), size=[(0, 5, 2), (1, 4, 1.5)], color=PEBBLE,
          rotation=(0, 360), rot_speed=(-300, 300), rate=10, env=STORM_ENV),
    layer("StormStreaks", "storm", locked=True, texture="kk_trace_03", orientation="VelocityParallel", direction="Front",
          spread=(6, 6), speed=(90, 170), lifetime=(0.4, 0.7), size=[(0, 10), (0.3, 55), (1, 15)], color=STREAK,
          light_emission=1.0, brightness=1.2, rate=2.2, env=STORM_ENV),
    # ---------------- el despertar (portadores en la onda que recorre el suelo) ----------------
    layer("FrontDust", "front", texture="kk_smoke_07", direction="Top", spread=(35, 35), speed=(15, 40), drag=0.5,
          accel=(0, 4, 0), lifetime=(2.5, 3.5), size=[(0, 50, 10), (1, 100)], transparency=[(0, 1), (0.15, 0.62), (0.7, 0.72), (1, 1)],
          color=DUSTC, rotation=(0, 360), rot_speed=(-25, 25), zoffset=-4, rate=8,
          env=[(0, 0.4), (0.5, 1.0), (3.6, 1.0), (4.4, 0)]),
    layer("FrontPebbles", "front", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top", spread=(25, 25),
          speed=(20, 60), accel=(0, 10, 0), lifetime=(3.0, 4.0), size=[(0, 5, 2), (1, 4, 1.5)], color=PEBBLE,
          rotation=(0, 360), rot_speed=(-300, 300), rate=24, env=[(0, 0.3), (0.6, 1.0), (3.6, 1.0), (4.4, 0)]),
    layer("FrontMotes", "front", texture="fx_particle02", direction="Top", spread=(40, 40), speed=(10, 35),
          lifetime=(1.5, 2.5), size=[(0, 0), (0.15, 7, 2), (0.8, 5), (1, 0)], color=[(0, (220, 240, 255)), (1, (120, 180, 255))],
          light_emission=1.0, brightness=1.6, rate=16, env=[(0, 0.5), (0.6, 1.0), (3.6, 1.0), (4.4, 0)]),
    # ---------------- corrientes que suben (de la tierra al cielo; con la atracción, hacia la singularidad) ----------------
    layer("Updraft", "updraft", texture="kk_trace_03", orientation="VelocityParallel", direction="Front",
          spread=(6, 6), speed=(350, 700), lifetime=(0.7, 1.2), size=[(0, 10), (0.3, 75), (1, 20)], color=STREAK,
          light_emission=1.0, brightness=1.2, rate=6,
          env=[(0, 0), (2.4, 0), (5.0, 0.8), (7.5, 1.0), (12.6, 1.3), (13.8, 0.2), (14.2, 0)]),
    layer("UpdraftPurple", "updraft", texture="kk_trace_04", orientation="VelocityParallel", direction="Front",
          spread=(8, 8), speed=(300, 600), lifetime=(0.7, 1.1), size=[(0, 10), (0.3, 60), (1, 18)], color=MOUTH,
          light_emission=1.0, brightness=1.3, rate=3,
          env=[(0, 0), (3.0, 0), (6.0, 0.8), (8.0, 1.0), (12.6, 1.2), (13.8, 0.2), (14.2, 0)]),
    layer("UpdraftMotes", "updraft", texture="fx_spark002", direction="Front", spread=(15, 15), speed=(100, 220),
          lifetime=(1.0, 1.8), size=twinkle(2.4), color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 45),
          rate=10, env=[(0, 0), (2.4, 0), (5.0, 1.0), (12.6, 1.2), (14.2, 0)]),
    # ---------------- remolinos secundarios (giran sobre sí mismos mientras orbitan) ----------------
    layer("EddyDust", "eddy", locked=True, texture="kk_smoke_04", direction="Top", spread=(30, 30), speed=(4, 12),
          lifetime=(1.5, 2.2), size=[(0, 45, 10), (1, 90)], transparency=[(0, 1), (0.2, 0.68), (0.7, 0.75), (1, 1)],
          color=DUSTC, rotation=(0, 360), rot_speed=(-40, 40), zoffset=-2, rate=7),
    layer("EddySwirl", "eddy", locked=True, texture="fx_swirl_rings", lifetime=(1.0, 1.4), size=[(0, 60), (1, 100)],
          transparency=[(0, 1), (0.2, 0.55), (0.75, 0.6), (1, 1)], color=PINKS, light_emission=0.7, brightness=1.1,
          rotation=(0, 360), rot_speed=(-260, -180), rate=1.6),
    layer("EddyWind", "eddy", locked=True, texture="fx_wind_swirl", lifetime=(0.9, 1.3), size=[(0, 70), (1, 100)],
          transparency=[(0, 1), (0.2, 0.5), (0.75, 0.6), (1, 1)], color=ENERGY, light_emission=0.8, brightness=1.1,
          rotation=(0, 360), rot_speed=(160, 240), rate=1.4),
    # ---------------- la singularidad (portador en el agujero: la materia cae desde una esfera hacia el centro) --------------
    layer("HoleInflow", "hole", shell=3.3, texture="kk_trace_01", orientation="VelocityParallel", lifetime=(0.38, 0.46),
          size=[(0, 8), (0.4, 70), (1, 22)], transparency=[(0, 0.6), (0.25, 0.1), (1, 0.4)], color=INWARD,
          light_emission=1.0, brightness=1.4, rate=150,
          env=[(0, 0), (6.4, 0), (8.0, 0.3), (10.6, 0.7), (12.6, 1.0), (14.2, 0.35), (16.0, 0.6), (16.6, 1.0), (16.62, 0)]),
    layer("HoleInflowPurple", "hole", shell=3.6, texture="kk_trace_01", orientation="VelocityParallel",
          lifetime=(0.4, 0.5), size=[(0, 8), (0.4, 70), (1, 22)], transparency=[(0, 0.6), (0.25, 0.1), (1, 0.4)],
          color=MOUTH, light_emission=1.0, brightness=1.4, rate=70,
          env=[(0, 0), (6.4, 0), (8.0, 0.3), (10.6, 0.7), (12.6, 1.0), (14.2, 0.35), (16.6, 0.8), (16.62, 0)]),
    layer("HoleStars", "hole", shell=2.9, texture="fx_spark002", lifetime=(0.45, 0.55), size=[(0, 0), (0.25, 9), (1, 3)],
          color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 45), rate=80,
          env=[(0, 0), (6.4, 0.2), (10.6, 0.8), (12.6, 1.0), (14.2, 0.4), (16.62, 0)]),
    layer("HoleDebris", "hole", shell=4.0, texture="om_cubes_2x2", flipbook=STATIC2x2, lifetime=(0.55, 0.7),
          size=[(0, 6, 2), (1, 2)], color=PEBBLE, rotation=(0, 360), rot_speed=(-400, 400), rate=60,
          env=[(0, 0), (8.0, 0), (10.6, 0.6), (12.6, 1.0), (14.0, 0.2), (14.4, 0)]),
    layer("CritBolts", "crit", shell=1.3, texture="fx_thunder", lifetime=(0.08, 0.12), size=[(0, 80, 15), (1, 100)],
          color=BOLT, light_emission=1.0, brightness=1.5, rotation=(0, 360), rate=26,
          env=[(0, 0), (14.4, 0), (15.6, 0.5), (16.6, 1.0), (16.62, 0)]),
    layer("CritSparks", "crit", shell=1.1, outward=True, texture="fx_spark002", speed=(60, 160), lifetime=(0.5, 0.9),
          size=twinkle(3.0), color=STAR, light_emission=1.0, brightness=1.9, rotation=(0, 45), rate=90,
          env=[(0, 0), (14.4, 0.2), (16.6, 1.0), (16.62, 0)]),
    # ---------------- las víctimas: un aura que las envuelve mientras las arrastra y una estela al caer ----------------
    layer("VictimAura", "victim", locked=True, texture="om_aura_wisp_2x2", flipbook=STATIC2x2,
          orientation="FacingCameraWorldUp", direction="Top", spread=(25, 25), speed=(4, 12), lifetime=(0.6, 1.0),
          size=[(0, 15, 4), (0.3, 35, 6), (1, 45, 8)], transparency=[(0, 1), (0.2, 0.35), (0.7, 0.5), (1, 1)],
          color=NEBW, light_emission=0.5, rate=30),
    layer("VictimSparks", "victim", locked=True, texture="fx_spark002", direction="Top", spread=(60, 60),
          speed=(10, 30), lifetime=(0.6, 1.0), size=twinkle(2.0), color=STAR, light_emission=1.0, brightness=1.8,
          rotation=(0, 45), rate=30),
    layer("FallTrail", "trail", texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Top", spread=(25, 25),
          speed=(10, 30), drag=1, lifetime=(0.8, 1.2), size=[(0, 40, 8), (1, 100)],
          transparency=[(0, 0.3), (0.5, 0.55), (1, 1)], color=NEBW, light_emission=0.2, rotation=(0, 360),
          rot_speed=(-30, 30), zoffset=-2, rate=70),
    layer("FallStreaks", "trail", texture="kk_trace_01", orientation="VelocityParallel", direction="Top",
          spread=(5, 5), speed=(200, 420), lifetime=(0.25, 0.4), size=[(0, 20), (0.3, 90), (1, 30)], color=STREAK,
          light_emission=1.0, brightness=1.3, rate=45),
    # ---------------- ráfagas sueltas (un emisor que se mueve a cada punto y suelta Emit) ----------------
    layer("BurstDust", "burst", texture="kk_smoke_07", shape={"type": "Sphere", "radius": 0.5, "style": "Surface"},
          speed=(30, 80), drag=2, accel=(0, 4, 0), lifetime=(1.0, 1.6), size=[(0, 25, 6), (1, 60, 10)],
          transparency=[(0, 0.5), (0.3, 0.6), (1, 1)], color=DUSTC, rotation=(0, 360), rot_speed=(-40, 40)),
    layer("BurstSparks", "burst", texture="kk_trace_01", orientation="VelocityParallel",
          shape={"type": "Sphere", "radius": 0.5, "style": "Surface"}, speed=(120, 260), drag=2, lifetime=(0.25, 0.4),
          size=[(0, 5), (0.3, 30), (1, 10)], color=STREAK, light_emission=1.0, brightness=1.3),
    layer("BurstDebris", "burst", texture="om_cubes_2x2", flipbook=STATIC2x2,
          shape={"type": "Sphere", "radius": 0.5, "style": "Surface"}, speed=(40, 110), drag=1, lifetime=(0.8, 1.4),
          size=[(0, 6, 2), (1, 3)], color=PEBBLE, rotation=(0, 360), rot_speed=(-400, 400)),
    layer("BurstFlash", "burst", texture="kk_star_09", lifetime=(0.22, 0.28), size=[(0, 30), (0.2, 90), (1, 20)],
          color=FLASH, light_emission=1.0, brightness=1.2, rotation=(0, 90)),
    layer("ConsumeFlash", "burst", texture="fx_glow", lifetime=(0.2, 0.25), size=[(0, 30), (0.3, 80), (1, 40)],
          transparency=[(0, 0.2), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.3),
    # ---------------- detonación (en la singularidad) ----------------
    layer("DetStreaks", "det", texture="kk_trace_01", orientation="VelocityParallel",
          shape={"type": "Sphere", "radius": 0.5, "style": "Surface"}, speed=(900, 1600), drag=0.6, lifetime=(0.5, 0.9),
          size=[(0, 20), (0.3, 100), (1, 40)], color=STREAK, light_emission=1.0, brightness=1.3, n=150),
    layer("DetPurple", "det", texture="kk_trace_01", orientation="VelocityParallel",
          shape={"type": "Sphere", "radius": 0.5, "style": "Surface"}, speed=(800, 1400), drag=0.6, lifetime=(0.5, 0.9),
          size=[(0, 20), (0.3, 100), (1, 40)], color=MOUTH, light_emission=1.0, brightness=1.35, n=80),
    layer("DetNebula", "det", texture="om_nebula_2x2", flipbook=STATIC2x2,
          shape={"type": "Sphere", "radius": 0.5, "style": "Surface"}, speed=(150, 420), drag=1.5, lifetime=(1.6, 2.4),
          size=[(0, 60), (0.3, 100), (1, 100)], transparency=[(0, 1), (0.08, 0.3), (0.6, 0.45), (1, 1)], color=NEBW,
          light_emission=0.15, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, n=50),
    layer("DetStars", "det", texture="fx_spark002", shape={"type": "Sphere", "radius": 0.5, "style": "Surface"},
          speed=(100, 600), drag=1.2, lifetime=(1.2, 2.2), size=twinkle(4.0), color=STAR, light_emission=1.0,
          brightness=1.9, rotation=(0, 45), n=260),
    layer("DetBolts", "det", texture="fx_thunder", shape={"type": "Sphere", "radius": 0.8, "style": "Surface"},
          lifetime=(0.1, 0.16), size=[(0, 90), (1, 100)], color=BOLT, light_emission=1.0, brightness=1.6,
          rotation=(0, 360), n=18),
    layer("DetFlash", "det", texture="fx_glow", lifetime=(0.4, 0.4), size=[(0, 60), (0.2, 100), (1, 100)],
          transparency=[(0, 0), (0.4, 0.4), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.4, n=6),
    # el polvo que levanta la onda en el suelo (portadores que avanzan con ella)
    layer("WallDust", "wall", texture="kk_smoke_07", direction="Top", spread=(40, 40), speed=(40, 110), drag=1.2,
          accel=(0, 6, 0), lifetime=(1.8, 2.8), size=[(0, 60, 10), (1, 100)], transparency=[(0, 0.4), (0.3, 0.55), (1, 1)],
          color=DUSTC, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, rate=18,
          env=[(DET, 0), (DET + 0.15, 1.0), (DET + 1.3, 0.7), (DET + 1.6, 0)]),
    layer("WallSparks", "wall", texture="fx_spark002", direction="Top", spread=(50, 50), speed=(60, 200), drag=1,
          lifetime=(0.8, 1.4), size=twinkle(3.0), color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 45),
          rate=20, env=[(DET, 0), (DET + 0.15, 1.0), (DET + 1.3, 0.5), (DET + 1.6, 0)]),
    # ---------------- secuelas: polvo que sube despacio y partículas cósmicas que flotan ----------------
    layer("AfterDust", "after", texture="kk_smoke_07", direction="Top", spread=(40, 40), speed=(8, 25), drag=0.6,
          accel=(0, 3, 0), lifetime=(3.5, 5.0), size=[(0, 60, 10), (1, 100)], transparency=[(0, 1), (0.25, 0.5), (0.75, 0.62), (1, 1)],
          color=DUSTC, rotation=(0, 360), rot_speed=(-15, 15), zoffset=-4, rate=4.5,
          env=[(DET, 0), (DET + 0.3, 1.0), (DET + 2.5, 0.8), (DET + 4.6, 0)]),
    layer("AfterMotes", "after", texture="fx_spark002", direction="Top", spread=(70, 70), speed=(5, 20), drag=0.5,
          accel=(0, 4, 0), lifetime=(1.8, 3.0), size=twinkle(3.2), color=STAR, light_emission=1.0, brightness=1.9,
          rotation=(0, 45), rate=14, env=[(DET, 0), (DET + 0.4, 1.0), (DET + 3.0, 0.6), (DET + 5.0, 0)]),
    layer("AfterNebula", "after", texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Top", spread=(60, 60),
          speed=(4, 14), lifetime=(2.5, 3.6), size=[(0, 60), (1, 100)], transparency=[(0, 1), (0.25, 0.65), (0.7, 0.72), (1, 1)],
          color=NEBW, light_emission=0.12, rotation=(0, 360), rot_speed=(-15, 15), zoffset=-3, rate=1.6,
          env=[(DET, 0), (DET + 0.4, 1.0), (DET + 3.0, 0.5), (DET + 4.6, 0)]),
    # ---------------- marcas en el suelo (Decals) ----------------
    layer("GroundCrack", "decal", texture="om_cracks", lifetime=(5.5, 7.0), size=[(0, 30), (0.06, 240), (1, 260)],
          transparency=[(0, 1), (0.04, 0.25), (0.1, 0.05), (0.4, 0.2), (0.85, 0.35), (1, 1)], color=CRACKC,
          light_emission=0.8, rotation=(0, 360), **DECAL),
    layer("GroundVoid", "decal", texture="fx_glow", lifetime=(6.0, 7.5), size=[(0, 20), (0.05, 160), (1, 170)],
          transparency=[(0, 1), (0.05, 0.35), (0.8, 0.45), (1, 1)], color=VOIDC, light_emission=0, **DECAL),
    layer("GroundScar", "decal", texture="kz_scorch", lifetime=(6.0, 7.5), size=[(0, 20), (0.05, 200), (1, 210)],
          transparency=[(0, 1), (0.05, 0.4), (0.8, 0.5), (1, 1)], color=SCORCH, light_emission=0, rotation=(0, 360),
          **DECAL),
]

CATACLYSM = {
    "name": "GravitationalCataclysm",
    "doc": ("OMNÍVORA ULTIMATE: CATACLISMO GRAVITACIONAL en un radio de 500 m (1786 studs). La gravedad desaparece y se "
            "levanta el terreno; la materia se organiza en una tormenta cósmica colosal; sobre el epicentro nace una "
            "singularidad que crece, se traga la tormenta y a las víctimas; acumula energía hasta un destello blanco y "
            "detona, estrellando a las víctimas contra el suelo. Quedan 5 s de residuos y todo se limpia."),
    "duration": T["end"],
    "impact": "CataclysmImpact",      # el efecto de cada impacto (va antes en SPECS)
    "cataclysm": {
        "radius": R, "height": H, "t": T, "phases": PHASES, "field": FIELD, "hole": HOLE, "rocks": ROCKS,
        "rings": RINGS, "front_n": FRONT_N, "cracks": CRACKS, "updrafts": UPDRAFTS, "eddies": EDDIES, "after": AFTER,
        "currents": CURRENTS, "bands": BANDS, "streams": STREAMS, "loops": LOOPS, "victims": VICTIMS, "det": DETO,
        "shake": SHAKE, "cc": CC, "flash": FLASH_T,
    },
    "layers": LAYERS,
}

# ----------------------------------------------------------------------------- el impacto de cada víctima
# (también se puede llamar suelto: OmnivoraVFX.CataclysmImpact(cf, escala, sacudida)). cf = el punto del suelo.
IMPACT = {
    "name": "CataclysmImpact",
    "doc": ("OMNÍVORA: el impacto de una víctima que cae desde el cielo bajo una gravedad descomunal: destello, ondas "
            "de choque, cráter oscuro con grietas de luz, rocas que salen disparadas, una nube densa de polvo y residuos "
            "cósmicos que quedan unos 5 s. cf = el punto del suelo."),
    "duration": 5.6,
    "light": {"color": (150, 200, 255), "brightness": 8, "range": 60, "time": 0.9},
    "shakes": [(0.0, 1.4, 0.7)],
    "layers": [
        dict(name="ImpFlash", texture="fx_glow", emit=[(0.0, 2)], lifetime=(0.28, 0.32), size=[(0, 30), (0.25, 100), (1, 100)],
             transparency=[(0, 0), (0.5, 0.5), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.3, offset=(0, 12, 0)),
        dict(name="ImpStar", texture="kk_star_09", emit=[(0.0, 2)], lifetime=(0.3, 0.36), size=[(0, 30), (0.15, 100), (1, 25)],
             color=FLASH, light_emission=1.0, brightness=1.3, rotation=(0, 90), offset=(0, 14, 0)),
        dict(name="ImpShock", texture="kk_circle_02", emit=[(0.0, 1)], lifetime=(0.6, 0.6), size=[(0, 40), (1, 560)],
             transparency=[(0, 0.2), (0.5, 0.55), (1, 1)], color=SHOCK, light_emission=0.45, offset=(0, 0.6, 0), **DECAL),
        dict(name="ImpShockSharp", texture="kk_circle_02", emit=[(0.04, 1)], lifetime=(0.42, 0.42), size=[(0, 40), (1, 760)],
             transparency=[(0, 0.2), (0.6, 0.6), (1, 1)], color=RINGC, light_emission=0.6, offset=(0, 0.7, 0), **DECAL),
        dict(name="ImpCrater", texture="fx_glow", emit=[(0.0, 1)], lifetime=(5.4, 5.4), size=[(0, 30), (0.03, 220), (1, 230)],
             transparency=[(0, 1), (0.03, 0.15), (0.8, 0.3), (1, 1)], color=VOIDC, light_emission=0, offset=(0, 0.3, 0),
             **DECAL),
        dict(name="ImpCracks", texture="om_cracks", emit=[(0.02, 1)], lifetime=(5.2, 5.2), size=[(0, 60), (0.05, 340), (1, 360)],
             transparency=[(0, 1), (0.03, 0.2), (0.1, 0.02), (0.4, 0.2), (0.85, 0.35), (1, 1)], color=CRACKC,
             light_emission=0.8, rotation=(0, 360), offset=(0, 0.5, 0), **DECAL),
        dict(name="ImpScorch", texture="kz_scorch", emit=[(0.0, 1)], lifetime=(5.5, 5.5), size=[(0, 40), (0.03, 300), (1, 310)],
             transparency=[(0, 1), (0.03, 0.3), (0.8, 0.45), (1, 1)], color=SCORCH, light_emission=0, rotation=(0, 360),
             offset=(0, 0.4, 0), **DECAL),
        dict(name="ImpRocks", type="meteor", emit=[(0.0, 14)], direction="Top", spread=(60, 60), speed=(160, 300),
             accel=(0, -196, 0), drag=0.15, lifetime=(1.6, 2.4),
             sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": (8, 22), "rot_speed": (-360, 360),
                     "color": (112, 116, 130), "material": "Slate"},
             trails=[{"name": "ImpRockDust", "rate": 28, "texture": "kk_smoke_04", "speed": (1, 6), "direction": "Top",
                      "spread": (180, 180), "drag": 2, "accel": (0, 5, 0), "lifetime": (0.6, 1.0),
                      "size": [(0, 8, 2), (1, 26, 4)], "transparency": [(0, 0.45), (0.6, 0.6), (1, 1)], "color": DUSTC,
                      "rotation": (0, 360)},
                     {"name": "ImpRockSparks", "rate": 20, "texture": "fx_spark002", "speed": (0, 8), "direction": "Top",
                      "spread": (180, 180), "lifetime": (0.4, 0.7), "size": twinkle(1.6), "color": STAR,
                      "light_emission": 1.0, "brightness": 1.8, "rotation": (0, 45)}],
             land=[dict(name="ImpRockPuff", texture="kk_smoke_07", emit=[(0, 4)], direction="Top", spread=(70, 70),
                        speed=(10, 30), drag=2, accel=(0, 4, 0), lifetime=(1.0, 1.5), size=[(0, 12, 3), (1, 34, 6)],
                        transparency=[(0, 0.45), (0.4, 0.6), (1, 1)], color=DUSTC, rotation=(0, 360))]),
        dict(name="ImpDust", texture="kk_smoke_07", emit=[(0.0, 34)], shape={"type": "Sphere", "radius": 20, "style": "Surface"},
             speed=(60, 180), drag=2.5, accel=(0, 8, 0), lifetime=(2.6, 4.0), size=[(0, 50, 10), (0.3, 90, 10), (1, 100)],
             transparency=[(0, 0.35), (0.3, 0.5), (0.8, 0.7), (1, 1)], color=DUST, rotation=(0, 360), rot_speed=(-30, 30),
             offset=(0, 10, 0), zoffset=-3),
        # una columna de polvo que sube del cráter
        dict(name="ImpColumn", texture="kk_smoke_07", emit=[(0.03, 22)], direction="Top", spread=(12, 12),
             speed=(120, 320), drag=1.6, lifetime=(2.2, 3.4), size=[(0, 50, 10), (0.3, 100), (1, 100)],
             transparency=[(0, 0.35), (0.4, 0.5), (1, 1)], color=DUST, rotation=(0, 360), rot_speed=(-30, 30),
             offset=(0, 10, 0), zoffset=-3),
        dict(name="ImpDustRing", texture="kk_smoke_04", emit=[(0.02, 40)], direction="Front", spread=(180, 3),
             speed=(260, 450), drag=3, accel=(0, 6, 0), lifetime=(1.6, 2.3), size=[(0, 40, 8), (1, 100)],
             transparency=[(0, 0.4), (0.4, 0.55), (1, 1)], color=DUSTC, rotation=(0, 360), rot_speed=(-40, 40),
             offset=(0, 8, 0), zoffset=-3),
        dict(name="ImpNebula", texture="om_nebula_2x2", flipbook=STATIC2x2, emit=[(0.0, 12)],
             shape={"type": "Sphere", "radius": 15, "style": "Surface"}, speed=(40, 120), drag=2, lifetime=(1.6, 2.6),
             size=[(0, 60), (0.3, 100), (1, 100)], transparency=[(0, 1), (0.08, 0.35), (0.6, 0.5), (1, 1)], color=NEBW,
             light_emission=0.15, rotation=(0, 360), rot_speed=(-30, 30), offset=(0, 18, 0), zoffset=-2),
        dict(name="ImpStreaks", texture="kk_trace_01", orientation="VelocityParallel", emit=[(0.0, 50)],
             shape={"type": "Sphere", "radius": 10, "style": "Surface"}, speed=(300, 600), drag=2, lifetime=(0.3, 0.5),
             size=[(0, 10), (0.3, 70), (1, 20)], color=STREAK, light_emission=1.0, brightness=1.3, offset=(0, 10, 0)),
        dict(name="ImpPurple", texture="kk_trace_01", orientation="VelocityParallel", emit=[(0.0, 30)],
             shape={"type": "Sphere", "radius": 10, "style": "Surface"}, speed=(260, 520), drag=2, lifetime=(0.3, 0.5),
             size=[(0, 10), (0.3, 70), (1, 20)], color=MOUTH, light_emission=1.0, brightness=1.35, offset=(0, 10, 0)),
        dict(name="ImpStars", texture="fx_spark002", emit=[(0.0, 80)], shape={"type": "Sphere", "radius": 10, "style": "Surface"},
             speed=(60, 260), drag=1.5, lifetime=(1.0, 2.0), size=twinkle(2.4), color=STAR, light_emission=1.0,
             brightness=1.9, rotation=(0, 45), offset=(0, 12, 0)),
        dict(name="ImpLingerDust", texture="kk_smoke_07", direction="Top", spread=(60, 60), speed=(10, 30), drag=0.5,
             accel=(0, 5, 0), lifetime=(3.5, 5.0), size=[(0, 70, 10), (1, 100)], transparency=[(0, 1), (0.2, 0.55), (0.75, 0.7), (1, 1)],
             color=DUST, rotation=(0, 360), rot_speed=(-15, 15), zoffset=-4, shape={"type": "Box", "size": (220, 10, 220)},
             stream=[(0.3, 3.8, 18, 3)], offset=(0, 10, 0)),
        dict(name="ImpLingerMotes", texture="fx_particle02", direction="Top", spread=(50, 50), speed=(6, 22), drag=0.4,
             accel=(0, 4, 0), lifetime=(1.6, 2.8), size=[(0, 0), (0.15, 6, 2), (0.8, 4), (1, 0)],
             color=[(0, (220, 240, 255)), (1, (120, 180, 255))], light_emission=1.0, brightness=1.6,
             shape={"type": "Box", "size": (200, 20, 200)}, stream=[(0.2, 4.2, 22, 3)], offset=(0, 12, 0)),
    ],
}
