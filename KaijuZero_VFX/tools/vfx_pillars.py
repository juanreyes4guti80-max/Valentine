"""H3 — LAS ROCAS DEL RAYO DETONAN EN UNA PARED DE LLAMAS (normal e IGNITION).

Filosofía: todas las rocas detonan A LA VEZ (destello, onda de choque, polvo, esquirlas en llamas)
y cada una levanta su racimo de picos de fuego; juntos forman una pared de llamas en línea recta.
Cada pico va en capas (exterior rojo-naranja que da las puntas, cuerpo naranja, núcleo
amarillo-blanco) para que el color nunca se queme a blanco. Brota del suelo de golpe, se sostiene
firme (sin rebotar) y se hunde al apagarse. En la última roca, el remate: un pilar gigante.
Ignition = carmesí con núcleo blanco-rosado y deja marcas de fuego en cada roca.

Las posiciones son RELATIVAS A CADA ROCA, porque en el juego las rocas las pone el rayo:
  "rock_emit":  variantes [[(t, n, du, lado, alto), ...], ...]; la roca i usa la variante i % n
  "final_emit": [(t, n, du, lado, alto), ...] solo en la última roca (el final del rayo)
du = desplazamiento a lo largo de la línea en unidades de la separación entre rocas; lado y alto en
studs. Las capas de emisión continua usan "rock_stream"/"final_stream" con (retraso, du, lado, alto).
"""
import math
import random

# ----------------------------------------------------------------------------- paletas
NORMAL = {
    "fire": [(0, (255, 246, 210)), (0.1, (255, 218, 110)), (0.3, (255, 160, 50)),
             (0.55, (240, 104, 30)), (0.8, (190, 60, 22)), (1, (96, 32, 16))],
    "lick": [(0, (255, 236, 150)), (0.3, (255, 176, 60)), (0.7, (245, 108, 30)), (1, (180, 50, 18))],
    "spike": [(0, (255, 226, 120)), (0.2, (255, 196, 80)), (0.5, (255, 150, 44)), (0.8, (232, 92, 28)), (1, (170, 48, 18))],
    "hot": [(0, (255, 246, 200)), (0.4, (255, 200, 100)), (1, (255, 140, 50))],
    "core": [(0, (255, 250, 225)), (1, (255, 200, 110))],
    "spark": [(0, (255, 238, 150)), (0.5, (255, 184, 60)), (1, (255, 110, 24))],
    "smoke": [(0, (255, 156, 76)), (0.08, (170, 112, 84)), (0.25, (126, 114, 108)),
              (0.65, (150, 144, 140)), (1, (172, 168, 164))],
    "wisp": [(0, (120, 104, 96)), (1, (150, 144, 140))],
    "dust": [(0, (222, 200, 172)), (0.5, (200, 186, 170)), (1, (186, 178, 170))],
    "ring": [(0, (255, 176, 90)), (1, (255, 120, 50))],
    "glow": [(0, (255, 170, 70)), (1, (230, 90, 30))],
    "flash": [(0, (255, 214, 120)), (1, (255, 150, 60))],
    "trail_fire": [(0, (255, 246, 210)), (0.3, (255, 170, 60)), (1, (200, 60, 22))],
    "trail_smoke": [(0, (255, 170, 80)), (0.2, (100, 88, 82)), (1, (140, 134, 130))],
    "ember": [(0, (255, 220, 120)), (1, (255, 110, 30))],
    # pico en capas: exterior rojo-naranja (puntas), cuerpo naranja, núcleo amarillo-blanco
    "sp_outer": [(0, (255, 160, 58)), (0.15, (255, 128, 40)), (0.5, (242, 94, 28)), (0.8, (206, 60, 20)), (1, (150, 34, 14))],
    "sp_body": [(0, (255, 220, 120)), (0.25, (255, 184, 66)), (0.65, (252, 140, 44)), (1, (226, 94, 30))],
    "sp_core": [(0, (255, 250, 220)), (0.4, (255, 230, 160)), (1, (255, 186, 96))],
    "dome": [(0, (255, 232, 160)), (0.1, (255, 196, 90)), (0.3, (255, 150, 46)), (0.6, (236, 96, 28)), (1, (150, 50, 20))],
    "wsmoke": [(0, (150, 96, 64)), (0.15, (92, 80, 74)), (0.6, (120, 114, 110)), (1, (150, 146, 142))],
}
IGNITION = {
    "fire": [(0, (255, 236, 236)), (0.1, (255, 136, 140)), (0.3, (248, 60, 72)),
             (0.55, (212, 24, 44)), (0.8, (150, 12, 28)), (1, (70, 8, 16))],
    "lick": [(0, (255, 220, 220)), (0.3, (255, 90, 96)), (0.7, (224, 30, 46)), (1, (150, 14, 24))],
    "spike": [(0, (255, 170, 176)), (0.2, (255, 100, 108)), (0.5, (238, 40, 56)), (0.8, (188, 18, 36)), (1, (110, 10, 20))],
    "hot": [(0, (255, 238, 238)), (0.4, (255, 140, 146)), (1, (255, 60, 74))],
    "core": [(0, (255, 246, 246)), (1, (255, 130, 136))],
    "spark": [(0, (255, 232, 232)), (0.5, (255, 110, 120)), (1, (230, 36, 50))],
    "smoke": [(0, (210, 44, 56)), (0.08, (120, 42, 50)), (0.25, (74, 50, 54)),
              (0.65, (96, 86, 90)), (1, (124, 118, 120))],
    "wisp": [(0, (96, 70, 74)), (1, (124, 116, 118))],
    "dust": [(0, (200, 176, 160)), (0.5, (180, 164, 156)), (1, (170, 162, 158))],
    "ring": [(0, (255, 90, 104)), (1, (220, 30, 50))],
    "glow": [(0, (255, 70, 84)), (1, (190, 20, 40))],
    "flash": [(0, (255, 150, 160)), (1, (240, 50, 66))],
    # las rocas que salen volando también arden en carmesí
    "trail_fire": [(0, (255, 236, 236)), (0.3, (255, 92, 104)), (1, (190, 24, 40))],
    "trail_smoke": [(0, (210, 44, 56)), (0.2, (78, 58, 62)), (1, (118, 110, 114))],
    "ember": [(0, (255, 200, 200)), (1, (240, 40, 56))],
    "sp_outer": [(0, (255, 80, 84)), (0.15, (235, 36, 50)), (0.5, (200, 20, 38)), (0.8, (150, 10, 26)), (1, (90, 6, 16))],
    "sp_body": [(0, (255, 150, 150)), (0.25, (255, 86, 92)), (0.65, (240, 44, 58)), (1, (190, 22, 38))],
    "sp_core": [(0, (255, 244, 240)), (0.4, (255, 200, 196)), (1, (255, 126, 128))],
    "dome": [(0, (255, 200, 204)), (0.1, (255, 110, 120)), (0.3, (240, 50, 66)), (0.6, (200, 22, 42)), (1, (100, 10, 22))],
    "wsmoke": [(0, (140, 40, 50)), (0.15, (70, 52, 56)), (0.6, (96, 86, 90)), (1, (124, 118, 120))],
}

STATIC2x2 = ("Grid2x2", "Random", 0, True)


def _r(v, k):
    return round(v * k, 3)


class RockPlaces:
    """Dónde emite una capa, relativo a las rocas: variantes que se reparten entre las rocas
    (la roca i usa la variante i % n) y lugares extra en la última roca (el remate)."""

    def __init__(self, variants=None, final=None):
        self.variants = variants or []   # [[(t, du, lado), ...], ...]
        self.final = final or []         # [(t, du, lado), ...]

    def E(self, dts, n, y):
        out = {}
        if self.variants:
            out["rock_emit"] = [[(round(t + dt, 3), n, round(du, 4), round(sd, 2), round(y, 2))
                                 for (t, du, sd) in var for dt in dts] for var in self.variants]
        if self.final:
            out["final_emit"] = [(round(t + dt, 3), n, round(du, 4), round(sd, 2), round(y, 2))
                                 for (t, du, sd) in self.final for dt in dts]
        return out


EACH = RockPlaces(variants=[[(0.0, 0.0, 0.0)]])     # en cada roca
LAST = RockPlaces(final=[(0.0, 0.0, 0.0)])          # solo en la última roca


# ----------------------------------------------------------------------------- detonación
def detonation_layers(tag, pal, H0, P, n_rocks=8, big=True, burn=1.2):
    """Detonación: destello, anillos, polvo, domo de fuego, chispas y esquirlas en llamas.
    P = RockPlaces (en qué rocas y dónde); un solo emisor por capa aunque haya varias rocas."""

    def E(dt, n, y):
        return P.E((dt,), n, y)
    L = []
    L.append(dict(name=f"{tag}_FlashBurst", texture="fx_burst_a", lifetime=(0.1, 0.13),
                  size=[(0, _r(0.25, H0)), (0.3, _r(0.95, H0)), (1, _r(1.05, H0))],
                  transparency=[(0, 0.3), (0.5, 0.5), (1, 1)], color=pal["flash"], light_emission=0.35,
                  brightness=1.0, rotation=(0, 360), zoffset=_r(0.2, H0), **E(0.0, 2, 0.14 * H0)))
    L.append(dict(name=f"{tag}_FlashStar", texture="fx_star", lifetime=(0.15, 0.15),
                  size=[(0, _r(0.6, H0)), (0.25, _r(1.8, H0)), (1, _r(1.0, H0))],
                  transparency=[(0, 0.35), (0.6, 0.6), (1, 1)], color=pal["flash"], light_emission=0.5,
                  brightness=1.0, zoffset=_r(0.22, H0), **E(0.0, 1, 0.14 * H0)))
    L.append(dict(name=f"{tag}_Glow", texture="fx_glow", lifetime=(0.7, 0.7),
                  size=[(0, _r(0.5, H0)), (0.15, _r(1.5, H0)), (1, _r(1.7, H0))],
                  transparency=[(0, 0.5), (0.4, 0.75), (1, 1)], color=pal["glow"], light_emission=0.3,
                  zoffset=_r(-0.2, H0), **E(0.0, 1, 0.25 * H0)))
    L.append(dict(name=f"{tag}_GroundRing", decal=True, texture="fx_shock_spiky", lifetime=(0.4, 0.4),
                  orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01),
                  size=[(0, _r(0.4, H0)), (0.25, _r(0.95, H0)), (1, _r(1.3, H0))],
                  transparency=[(0, 0.4), (0.4, 0.6), (1, 1)], color=pal["ring"], light_emission=0.35,
                  rotation=(0, 360), **E(0.0, 1, 0.3)))
    L.append(dict(name=f"{tag}_ShockRing", decal=True, texture="kk_circle_03", lifetime=(0.55, 0.55),
                  orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01),
                  size=[(0, _r(0.5, H0)), (0.2, _r(1.6, H0)), (0.6, _r(2.5, H0)), (1, _r(2.8, H0))],
                  transparency=[(0, 0.4), (0.4, 0.6), (1, 1)], color=pal["ring"], light_emission=0.35,
                  **E(0.0, 1, 0.35)))
    if big:
        L.append(dict(name=f"{tag}_GroundRing2", decal=True, texture="kk_circle_03", lifetime=(0.45, 0.45),
                      orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01),
                      size=[(0, _r(0.45, H0)), (0.25, _r(1.25, H0)), (1, _r(2.25, H0))],
                      transparency=[(0, 0.4), (0.5, 0.7), (1, 1)], color=pal["hot"], light_emission=0.3,
                      **E(0.06, 1, 0.25)))
        L.append(dict(name=f"{tag}_GroundStreaks", texture="kk_trace_01", orientation="VelocityParallel",
                      direction="Front", spread=(180, 2), speed=(_r(3.4, H0), _r(4.8, H0)), drag=7,
                      lifetime=(0.18, 0.26), size=[(0, _r(0.36, H0), _r(0.06, H0)), (1, _r(0.5, H0), _r(0.06, H0))],
                      transparency=[(0, 0), (0.5, 0.3), (1, 1)], color=pal["core"], light_emission=0.8,
                      brightness=1.3, **E(0.0, 18, 1.5)))
    L.append(dict(name=f"{tag}_DustWave", texture="kk_smoke_07", direction="Front", spread=(180, 3),
                  speed=(_r(2.0, H0), _r(3.0, H0)), drag=3.6, accel=(0, _r(0.1, H0), 0), lifetime=(1.0, 1.35),
                  size=[(0, _r(0.16, H0), _r(0.04, H0)), (0.3, _r(0.4, H0), _r(0.07, H0)), (1, _r(0.57, H0), _r(0.09, H0))],
                  transparency=[(0, 0.45), (0.15, 0.18), (0.6, 0.4), (1, 1)], color=pal["dust"],
                  rotation=(0, 360), rot_speed=(-40, 40), zoffset=_r(-0.05, H0), **E(0.02, 34 if big else 12, 2.5)))
    L.append(dict(name=f"{tag}_FireDome", texture="kk_fire_01",
                  shape={"type": "Sphere", "radius": _r(0.08, H0)}, direction="Top", spread=(70, 70),
                  speed=(_r(0.35, H0), _r(0.7, H0)), drag=4, accel=(0, _r(0.25, H0), 0), lifetime=(0.55, 0.75),
                  size=[(0, _r(0.14, H0), _r(0.04, H0)), (0.15, _r(0.32, H0), _r(0.06, H0)),
                        (0.6, _r(0.38, H0), _r(0.06, H0)), (1, _r(0.4, H0), _r(0.06, H0))],
                  transparency=[(0, 0), (0.55, 0.05), (0.85, 0.45), (1, 1)], color=pal["dome"],
                  light_emission=0.2, brightness=1.35, rotation=(0, 360), rot_speed=(-50, 50),
                  **E(0.0, 8 if big else 5, 0.1 * H0)))
    L.append(dict(name=f"{tag}_FireDome2", texture="kk_fire_02",
                  shape={"type": "Sphere", "radius": _r(0.08, H0)}, direction="Top", spread=(70, 70),
                  speed=(_r(0.3, H0), _r(0.6, H0)), drag=4, accel=(0, _r(0.25, H0), 0), lifetime=(0.5, 0.7),
                  size=[(0, _r(0.13, H0), _r(0.04, H0)), (0.15, _r(0.3, H0), _r(0.05, H0)),
                        (0.6, _r(0.36, H0), _r(0.05, H0)), (1, _r(0.38, H0), _r(0.05, H0))],
                  transparency=[(0, 0), (0.55, 0.05), (0.85, 0.45), (1, 1)], color=pal["dome"],
                  light_emission=0.2, brightness=1.35, rotation=(0, 360), rot_speed=(-50, 50),
                  **E(0.03, 5 if big else 3, 0.1 * H0)))
    L.append(dict(name=f"{tag}_Sparks", texture="kk_trace_01", orientation="VelocityParallel", direction="Top",
                  spread=(75, 75), speed=(_r(2.2, H0), _r(4.0, H0)), drag=4, accel=(0, _r(-0.9, H0), 0),
                  lifetime=(0.3, 0.55), size=[(0, _r(0.34, H0), _r(0.08, H0)), (1, _r(0.12, H0))],
                  color=pal["spark"], light_emission=1.0, brightness=1.7,
                  **E(0.0, 36 if big else 14, 0.14 * H0)))
    if n_rocks:
        L.append(dict(name=f"{tag}_Rocks", type="meteor", direction="Top", spread=(60, 60),
                      speed=(_r(1.25, H0), _r(2.0, H0)), accel=(0, _r(-2.1, H0), 0), drag=0.2,
                      lifetime=(1.4, 1.8),
                      sprite={"texture": "kz_debris_2x2", "layout": "Grid2x2",
                              "size": (_r(0.043, H0), _r(0.065, H0)), "rot_speed": (-500, 500),
                              "color": (60, 50, 48)},
                      trails=[
                          {"name": f"{tag}_RockSmoke", "rate": 40, "texture": "kk_smoke_04", "speed": (1, 4),
                           "direction": "Top", "spread": (180, 180), "drag": 2, "accel": (0, 6, 0),
                           "lifetime": (0.5, 0.8), "size": [(0, _r(0.055, H0), 0.8), (1, _r(0.16, H0), 2)],
                           "transparency": [(0, 0.3), (0.6, 0.5), (1, 1)], "color": pal["trail_smoke"],
                           "rotation": (0, 360)},
                          {"name": f"{tag}_RockFire", "rate": 55, "texture": "kk_fire_01", "speed": (0, 2),
                           "direction": "Top", "spread": (180, 180), "lifetime": (0.16, 0.26),
                           "size": [(0, _r(0.1, H0), 1.2), (1, _r(0.027, H0))], "color": pal["trail_fire"],
                           "light_emission": 0.5, "brightness": 1.6, "rotation": (0, 360)},
                      ],
                      land=[
                          {"name": f"{tag}_RockDust", "emit": [(0, 4)], "texture": "kk_smoke_04", "direction": "Top",
                           "spread": (75, 75), "speed": (8, 18), "drag": 3, "accel": (0, 4, 0),
                           "lifetime": (0.6, 0.9), "size": [(0, 3, 1), (0.4, 8, 1.5), (1, 10, 1.5)],
                           "transparency": [(0, 0.35), (0.6, 0.5), (1, 1)], "color": pal["dust"],
                           "rotation": (0, 360)},
                          {"name": f"{tag}_RockBurn", "texture": "kk_muzzle_05", "orientation": "VelocityParallel",
                           "direction": "Top", "spread": (10, 10), "speed": (4, 9), "drag": 2,
                           "lifetime": (0.35, 0.55), "size": [(0, 1.5, 0.5), (0.3, 5, 1), (1, 3, 0.8)],
                           "transparency": [(0, 0), (0.6, 0.12), (1, 1)], "color": pal["lick"],
                           "light_emission": 0.35, "brightness": 1.5, "stream": [(0, burn, 12, 0)]},
                      ],
                      **E(0.02, n_rocks, 0.07 * H0)))
    return L



# ----------------------------------------------------------------------------- picos de fuego
# Geometría de las texturas de llama (fracción del tamaño del sprite, medida en el alfa):
# base de la llama bajo el centro / punta sobre el centro.
TEX_GEOM = {"kk_muzzle_04": (0.40, 0.31), "kk_muzzle_01": (0.418, 0.283), "kk_muzzle_05": (0.40, 0.133)}


def steady_flame(tex, Hv, life):
    """Llama que brota de golpe (≈3 cuadros), se SOSTIENE sin rebotar y se hunde mientras se apaga.
    Sin velocidad inicial ni arrastre: solo una aceleración suave hacia abajo que casi no se nota
    al principio (t²) y hunde la llama al final, así su base nunca flota.
    Hv = altura visible de la punta; life = (min, max) de vida."""
    bf, tf = TEX_GEOM[tex]
    S = Hv / (bf + tf)
    c = bf * S                                  # centro con la base justo en el suelo
    lm = (life[0] + life[1]) / 2
    return {"size": [(0, _r(0.62, S)), (0.08, _r(1.0, S)), (0.55, _r(1.03, S)), (1, _r(0.62, S))],
            "y": c, "accel": (0, -_r(0.9 * c / lm ** 2, 1), 0)}


def spike_layers(tag, pal, H, P, life=(0.75, 0.85)):
    """Pico de fuego en capas: exterior rojo-naranja alto (da las puntas), cuerpo naranja y núcleo
    amarillo-blanco abajo. Un solo pulso: brota con un estallido, se sostiene y se hunde."""
    E = P.E
    L = []
    o = steady_flame("kk_muzzle_04", H, life)
    L.append({"name": f"{tag}_Outer", "texture": "kk_muzzle_04", "orientation": "FacingCameraWorldUp",
              **E((0.0,), 1, o["y"]), "accel": o["accel"], "lifetime": life, "size": o["size"],
              "transparency": [(0, 0.12), (0.06, 0), (0.6, 0.04), (0.85, 0.4), (1, 1)], "color": pal["sp_outer"],
              "light_emission": 0.08, "brightness": 1.1, "rotation": (-3, 3)})
    lb = (round(life[0] - 0.04, 3), round(life[1] - 0.04, 3))
    b = steady_flame("kk_muzzle_01", 0.62 * H, lb)
    L.append({"name": f"{tag}_Body", "texture": "kk_muzzle_01", "orientation": "FacingCameraWorldUp",
              **E((0.015,), 1, b["y"]), "accel": b["accel"], "lifetime": lb, "size": b["size"],
              "transparency": [(0, 0.12), (0.06, 0), (0.55, 0.05), (0.8, 0.4), (1, 1)], "color": pal["sp_body"],
              "light_emission": 0.2, "brightness": 1.25, "rotation": (-6, 6), "zoffset": 0.5})
    lc = (round(life[0] - 0.08, 3), round(life[1] - 0.08, 3))
    c = steady_flame("kk_muzzle_01", 0.34 * H, lc)
    L.append({"name": f"{tag}_Core", "texture": "kk_muzzle_01", "orientation": "FacingCameraWorldUp",
              **E((0.02,), 1, c["y"]), "accel": c["accel"], "lifetime": lc, "size": c["size"],
              "transparency": [(0, 0.15), (0.06, 0.05), (0.5, 0.1), (0.8, 0.5), (1, 1)], "color": pal["sp_core"],
              "light_emission": 0.45, "brightness": 1.35, "rotation": (-7, 7), "zoffset": 1})
    # lenguas que trepan por el pico y se sueltan arriba (vida en la silueta, sin mover el pico)
    L.append({"name": f"{tag}_Licks", "texture": "kk_muzzle_05", "orientation": "VelocityParallel",
              **E((0.04, 0.16, 0.28, 0.4), 2, 0.1 * H), "direction": "Top", "spread": (6, 6),
              "speed": (_r(1.2, H), _r(2.4, H)), "drag": 4, "lifetime": (0.25, 0.4),
              "size": [(0, _r(0.12, H)), (0.3, _r(0.3, H)), (1, _r(0.14, H))],
              "transparency": [(0, 0.1), (0.6, 0.2), (1, 1)], "color": pal["sp_outer"],
              "light_emission": 0.15, "brightness": 1.2, "zoffset": 0.3})
    # fuego denso al pie: une los picos en una banda continua
    L.append({"name": f"{tag}_Foot", "texture": "kk_fire_01", **E((0.0, 0.15, 0.3), 2, 0.06 * H),
              "shape": {"type": "Box", "size": (_r(0.2, H), 0.5, _r(0.2, H))},
              "direction": "Top", "spread": (12, 12), "speed": (_r(0.2, H), _r(0.8, H)), "drag": 3,
              "accel": (0, _r(0.3, H), 0), "lifetime": (0.4, 0.6),
              "size": [(0, _r(0.12, H), _r(0.03, H)), (0.3, _r(0.26, H), _r(0.04, H)), (1, _r(0.2, H), _r(0.03, H))],
              "transparency": [(0, 0), (0.6, 0.1), (0.85, 0.5), (1, 1)], "color": pal["sp_body"],
              "light_emission": 0.25, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-60, 60),
              "zoffset": 1.5})
    # estallido al nacer + raya incandescente que sube disparada
    L.append({"name": f"{tag}_Pop", "texture": "fx_burst_fan", "orientation": "FacingCameraWorldUp",
              **E((0.0,), 1, 0.2 * H), "lifetime": (0.16, 0.2),
              "size": [(0, _r(0.2, H)), (0.3, _r(0.55, H)), (1, _r(0.62, H))],
              "transparency": [(0, 0.3), (0.4, 0.5), (1, 1)], "color": pal["hot"],
              "light_emission": 0.25, "brightness": 1.15, "zoffset": 2})
    L.append({"name": f"{tag}_Streak", "texture": "fx_line", "orientation": "VelocityParallel",
              **E((0.0,), 1, 0.05 * H), "direction": "Top", "spread": (2, 2),
              "speed": (_r(4.0, H), _r(5.0, H)), "drag": 8, "lifetime": (0.2, 0.26),
              "size": [(0, _r(0.6, H), _r(0.1, H)), (1, _r(0.8, H), _r(0.1, H))],
              "transparency": [(0, 0), (0.5, 0.25), (1, 1)], "color": pal["core"],
              "light_emission": 1.0, "brightness": 1.5})
    # brasas que se desprenden
    L.append({"name": f"{tag}_Embers", "texture": "kk_flare_01", **E((0.1, 0.35), 2, 0.5 * H),
              "shape": {"type": "Box", "size": (_r(0.15, H), _r(0.7, H), _r(0.15, H))},
              "direction": "Top", "spread": (40, 40), "speed": (_r(0.1, H), _r(0.5, H)), "drag": 1.6,
              "accel": (0, _r(0.25, H), 0), "lifetime": (0.6, 1.0),
              "size": [(0, 0), (0.1, _r(0.04, H), _r(0.012, H)), (1, 0)], "color": pal["ember"],
              "light_emission": 1.0, "brightness": 1.6})
    return L


CLASSES = (1.4, 1.0, 0.74, 0.52)       # alturas de pico relativas a Hb


def rock_wall(tag, pal, Hb, seed, n_var=3, per_rock=4, life=(0.75, 0.85), extra_final=None):
    """Racimos de picos (uno por roca) que juntos forman la pared. El pico más alto va en la roca y
    los más bajos hacia los lados; todos nacen casi a la vez (≤ 0.02 s de diferencia).
    Hay n_var variantes del racimo para que la pared no se vea repetida."""
    g = random.Random(seed)
    places = {c: RockPlaces(variants=[[] for _ in range(n_var)], final=[]) for c in CLASSES}
    smk = [[] for _ in range(n_var)]
    smk_final = []
    puffs = (0.22, 0.42, 0.62)
    for v in range(n_var):
        for j in range(per_rock):
            f = (j + 0.5) / per_rock - 0.5
            du = f * 1.05 + g.uniform(-0.12, 0.12) / per_rock
            d = abs(du) / 0.5
            if d < 0.3:
                c = 1.4 if g.random() < 0.45 else 1.0
            elif d < 0.65:
                c = 1.0 if g.random() < 0.4 else 0.74
            else:
                c = 0.74 if g.random() < 0.35 else 0.52
            t = round(g.uniform(0, 0.02), 3)
            sd = round(g.uniform(-1.2, 1.2), 2)
            places[c].variants[v].append((t, du, sd))
            for dt in puffs:
                smk[v].append((round(t + dt + g.uniform(0, 0.06), 3), 1, round(du, 4),
                               round(sd + g.uniform(-1.5, 1.5), 2), round(Hb * c * g.uniform(0.6, 0.95), 2)))
    for c, lst in (extra_final or {}).items():
        places[c].final += lst
        for (t, du, sd) in lst:
            for dt in puffs:
                smk_final.append((round(t + dt + g.uniform(0, 0.06), 3), 1, round(du, 4),
                                  round(sd + g.uniform(-1.5, 1.5), 2), round(Hb * c * g.uniform(0.6, 0.95), 2)))
    L = []
    for c in CLASSES:
        P = places[c]
        if any(P.variants) or P.final:
            if not any(P.variants):
                P = RockPlaces(final=P.final)
            L += spike_layers(f"{tag}S{int(c * 100)}", pal, round(Hb * c, 1), P, life)
    smoke = {"rock_emit": [sorted(v) for v in smk]}
    if smk_final:
        smoke["final_emit"] = sorted(smk_final)
    L.append({"name": f"{tag}_WallSmoke", "texture": "kk_smoke_08", **smoke, "direction": "Top",
              "spread": (25, 25), "speed": (_r(0.08, Hb), _r(0.35, Hb)), "drag": 1.0,
              "accel": (0, _r(0.15, Hb), 0), "lifetime": (1.3, 1.9),
              "size": [(0, _r(0.16, Hb), _r(0.04, Hb)), (0.35, _r(0.4, Hb), _r(0.08, Hb)), (1, _r(0.6, Hb), _r(0.1, Hb))],
              "transparency": [(0, 0.8), (0.12, 0.45), (0.5, 0.6), (0.8, 0.85), (1, 1)], "color": pal["wsmoke"],
              "rotation": (0, 360), "rot_speed": (-20, 20), "zoffset": _r(-0.3, Hb)})
    return L


def final_side_spikes():
    """Picos que rodean al pilar del remate (se abren a lo ancho de la línea); van en la pared."""
    return {1.4: [(0.02, 0.0, -2.4), (0.03, 0.0, 2.2)],
            1.0: [(0.04, 0.0, -4.6), (0.05, 0.0, 4.4), (0.03, -0.25, 0.8)]}


def final_pillar(tag, pal, Hp, life=(0.9, 1.0)):
    """Remate en la última roca: un pilar gigante que revienta arriba en fuego y humo."""
    L = spike_layers(f"{tag}P", pal, Hp, RockPlaces(final=[(0.0, 0.0, -1.0), (0.02, 0.0, 1.0)]), life)

    def E(evs):
        return {"final_emit": [(dt, n, 0.0, 0.0, round(y, 2)) for (dt, n, y) in evs]}
    L.append({"name": f"{tag}_Cap", "texture": "kk_fire_02", **E([(0.1, 6, 0.85 * Hp), (0.3, 4, 0.82 * Hp)]),
              "shape": {"type": "Sphere", "radius": _r(0.06, Hp), "style": "Surface"},
              "direction": "Top", "spread": (180, 180), "speed": (_r(0.08, Hp), _r(0.25, Hp)), "drag": 3,
              "accel": (0, _r(0.18, Hp), 0), "lifetime": (0.55, 0.75),
              "size": [(0, _r(0.14, Hp)), (0.3, _r(0.3, Hp)), (1, _r(0.38, Hp))],
              "transparency": [(0, 0), (0.55, 0.1), (0.85, 0.5), (1, 1)], "color": pal["dome"],
              "light_emission": 0.2, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-50, 50)})
    L.append({"name": f"{tag}_Column", "texture": "kk_smoke_07",
              **E([(0.35, 3, 0.9 * Hp), (0.6, 3, 0.85 * Hp), (0.85, 2, 0.8 * Hp)]),
              "direction": "Top", "spread": (30, 30), "speed": (_r(0.1, Hp), _r(0.25, Hp)),
              "drag": 1.2, "accel": (0, _r(0.14, Hp), 0), "lifetime": (1.4, 1.9),
              "size": [(0, _r(0.18, Hp), _r(0.04, Hp)), (0.4, _r(0.4, Hp), _r(0.06, Hp)), (1, _r(0.55, Hp), _r(0.08, Hp))],
              "transparency": [(0, 0.7), (0.12, 0.4), (0.55, 0.55), (0.85, 0.85), (1, 1)], "color": pal["wsmoke"],
              "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": _r(-0.2, Hp)})
    return L


def rock_aftermath(tag, pal, H0, vis, glow):
    """Suelo bajo cada roca: brillo mientras arde, quemadura que queda y brasas."""
    return [
        dict(name=f"{tag}_GroundGlow", decal=True, texture="fx_glow", orientation="VelocityPerpendicular",
             direction="Top", speed=(0.01, 0.01), lifetime=(glow, glow),
             size=[(0, _r(0.4, H0)), (0.1, _r(1.5, H0)), (0.7, _r(1.4, H0)), (1, _r(1.2, H0))],
             transparency=[(0, 0.5), (0.1, 0.25), (0.6, 0.45), (1, 1)], color=pal["glow"], light_emission=0.8,
             zoffset=-0.5, **EACH.E((0.02,), 1, 0.25)),
        dict(name=f"{tag}_Scorch", decal=True, texture="kz_scorch", orientation="VelocityPerpendicular",
             direction="Top", speed=(0.01, 0.01), lifetime=(vis, vis),
             size=[(0, _r(0.3, H0)), (0.04, _r(1.05, H0)), (1, _r(1.1, H0))],
             transparency=[(0, 0.15), (0.8, 0.3), (1, 1)], rotation=(0, 360), zoffset=-1,
             **EACH.E((0.03,), 1, 0.15)),
        dict(name=f"{tag}_Embers", texture="kk_flare_01", direction="Top", spread=(60, 60),
             speed=(_r(0.4, H0), _r(1.2, H0)), drag=1.6, accel=(0, _r(0.6, H0), 0), lifetime=(0.8, 1.2),
             size=[(0, 0), (0.1, _r(0.12, H0), _r(0.04, H0)), (1, 0)], color=pal["ember"],
             light_emission=1.0, brightness=1.6, **EACH.E((0.15,), 5, 0.6 * H0)),
    ]


def _sources(var_sides, final_side, delay):
    """Fuentes de emisión continua: una por roca (lado según la variante) y, si se pide, el remate."""
    out = {"rock_stream": [[] if sd is None else [(delay, 0.0, sd, 0.0)] for sd in var_sides]}
    if final_side is not None:
        out["final_stream"] = [(delay, 0.0, final_side, 0.0)]
    return out


def burn_marks(tag, pal, var_sides, t0, dur, final=True):
    """Ignition: en cada roca queda una marca de fuego ardiendo dur segundos, desde t0."""
    src = _sources(var_sides, 0.0 if final else None, t0)
    box = {"type": "Box", "size": (6, 0.2, 6)}
    glow_e = {"rock_emit": [[] if sd is None else [(t0, 1, 0.0, sd, 0.3)] for sd in var_sides]}
    if final:
        glow_e["final_emit"] = [(t0, 1, 0.0, 0.0, 0.3)]
    k = 0.55 * dur
    return [
        dict(name=f"{tag}_BurnGlow", decal=True, texture="fx_glow", orientation="VelocityPerpendicular",
             direction="Top", speed=(0.01, 0.01), lifetime=(dur + 0.3, dur + 0.3),
             size=[(0, 0), (0.04, 14), (0.75, 11), (1, 0)],
             transparency=[(0, 0.35), (0.8, 0.55), (1, 1)], color=pal["glow"], light_emission=0.8, **glow_e),
        dict(name=f"{tag}_BurnFlames", texture="fx_fire_2x2", flipbook=STATIC2x2, orientation="VelocityParallel",
             shape=box, direction="Top", spread=(8, 8), speed=(8, 14), drag=2, lifetime=(0.4, 0.62),
             size=[(0, 4.4, 1.1), (0.3, 12, 3.3), (1, 7.7, 2.2)], offset=(0, 0.6, 0),
             transparency=[(0, 0.05), (0.6, 0.15), (1, 1)], color=pal["lick"], light_emission=0.35,
             brightness=1.6, stream=[(0, round(k, 3), 14, 5), (round(k, 3), dur, 5, 0)], **src),
        dict(name=f"{tag}_BurnBase", texture="kk_fire_01", shape=box, direction="Top", spread=(20, 20),
             speed=(2, 5), drag=2, lifetime=(0.35, 0.55), offset=(0, 0.6, 0),
             size=[(0, 3.3, 1.1), (0.4, 6.6, 1.6), (1, 4.4, 1.1)],
             transparency=[(0, 0.1), (0.6, 0.3), (1, 1)], color=pal["fire"], light_emission=0.45,
             brightness=1.5, rotation=(0, 360), rot_speed=(-60, 60), stream=[(0, dur, 9, 0)], **src),
        dict(name=f"{tag}_BurnSmoke", texture="kk_smoke_04", direction="Top", spread=(15, 15),
             speed=(6, 12), drag=1.2, accel=(0, 6, 0), lifetime=(1.2, 1.7), offset=(0, 3, 0),
             size=[(0, 3.3, 1.1), (1, 14, 3.3)], transparency=[(0, 0.6), (0.3, 0.45), (1, 1)],
             color=pal["wisp"], rotation=(0, 360), rot_speed=(-30, 30), zoffset=-2,
             stream=[(0.15, dur + 0.1, 3, 1)], **src),
    ]


def rock_licks(tag, pal, var_sides, t0, dur):
    """Versión normal: llamitas breves en algunas rocas mientras se disipa el humo."""
    return [dict(name=f"{tag}_Licks", texture="fx_fire_2x2", flipbook=STATIC2x2, orientation="VelocityParallel",
                 shape={"type": "Box", "size": (5.5, 0.2, 5.5)}, direction="Top", spread=(8, 8),
                 speed=(6.6, 12), drag=2, lifetime=(0.35, 0.55), offset=(0, 0.6, 0),
                 size=[(0, 3.3, 1.1), (0.3, 8.8, 2.2), (1, 5.5, 1.6)],
                 transparency=[(0, 0.05), (0.6, 0.15), (1, 1)], color=pal["lick"], light_emission=0.35,
                 brightness=1.6, stream=[(0, dur, 10, 0)], **_sources(var_sides, None, t0))]


# ----------------------------------------------------------------------------- H3
def h3_spec(ignition=False):
    """H3: las rocas que dejó el rayo detonan TODAS A LA VEZ; cada una levanta su racimo de pilares y
    juntas forman una PARED DE LLAMAS. En la última roca (final del rayo), el pilar gigante.
    Uso: KaijuFireVFX.H3_Detonation(rocas, escala, sacudida) con las posiciones (o Parts) de las rocas."""
    pal = IGNITION if ignition else NORMAL
    tag = "J" if ignition else "T"
    Hb = 34 if ignition else 30
    life = (0.75, 0.85)
    g = random.Random(7)
    L = []
    # cada roca detona (sin anticipación: el instante de la llamada ES la explosión)
    L += [Ld for Ld in detonation_layers(f"{tag}D", pal, 24, EACH, n_rocks=2, big=False,
                                         burn=1.4 if ignition else 0.8)
          if not Ld["name"].endswith(("FlashStar", "Glow", "ShockRing"))]   # 7 a la vez: sin anillos gigantes
    L += rock_wall(f"{tag}W", pal, Hb, seed=23, life=life, extra_final=final_side_spikes())
    # remate en la última roca
    L += detonation_layers(f"{tag}Fin", pal, 44, LAST, n_rocks=6, burn=2.0 if ignition else 1.0)
    L += final_pillar(f"{tag}F", pal, round(Hb * 2.1, 1), life=(0.9, 1.0))
    L += rock_aftermath(f"{tag}A", pal, 22, vis=3.6 if ignition else 2.4, glow=1.5 if ignition else 1.1)
    sides = [round(g.uniform(-2.5, 2.5), 2) for _ in range(3)]
    if ignition:
        L += burn_marks(f"{tag}Burn", pal, sides, t0=0.45, dur=3.0)
    else:
        L += rock_licks(f"{tag}Lick", pal, [sides[0], None, sides[2]], t0=0.5, dur=1.1)
    return {
        "name": "H3_DetonationIgnition" if ignition else "H3_Detonation",
        "doc": ("H3 IGNITION: las rocas detonan a la vez en una pared de llamas carmesí y dejan marcas de fuego. "
                if ignition else "H3: las rocas del rayo detonan a la vez y levantan una pared de llamas. ")
               + "KaijuFireVFX.<nombre>(rocas, escala, sacudida): rocas = lista de Vector3 (suelo) o de las Parts.",
        "duration": 4.6 if ignition else 2.8,
        # separación de diseño entre rocas (studs a escala 1) y límites; en el juego se usa la real
        "rocks": {"gap": 14, "gap_min": 6, "gap_max": 34, "jitter": 0.03},
        "preview_rocks": [(round(8 + 14 * i, 2), 0.0, round(0.8 * math.sin(i * 2.3), 2)) for i in range(7)],
        "shakes": [(0.0, 1.0, 0.8)],
        "light": {"color": (255, 60, 90) if ignition else (255, 150, 60), "brightness": 6, "range": 60,
                  "time": 1.5 if ignition else 1.1},
        "layers": L,
    }


# ----------------------------------------------------------------------------- vista previa
def rock_layout(rocks, rcfg, scale=1.0, seed=3):
    """Igual que en el módulo Luau: ordena las rocas a lo largo de la línea y calcula para cada una su
    separación (gap) y su pequeño retraso aleatorio. rocks = puntos del suelo (x, y, z)."""
    import numpy as np
    P = [np.asarray(r, float) for r in rocks]
    d = P[-1] - P[0]
    d[1] = 0.0
    n = np.linalg.norm(d)
    dirv = d / n if n > 0.1 else np.array([0.0, 0.0, -1.0])
    order = sorted(range(len(P)), key=lambda i: float((P[i] - P[0]) @ dirv))
    P = [P[i] for i in order]
    proj = [float((p - P[0]) @ dirv) for p in P]
    g = random.Random(seed)
    out = []
    for i, p in enumerate(P):
        ds = []
        if i > 0:
            ds.append(proj[i] - proj[i - 1])
        if i < len(P) - 1:
            ds.append(proj[i + 1] - proj[i])
        gap = sum(ds) / len(ds) if ds else rcfg["gap"] * scale
        gap = min(max(gap, rcfg["gap_min"] * scale), rcfg["gap_max"] * scale)
        out.append({"pos": p, "gap": gap, "delay": g.uniform(0, rcfg["jitter"])})
    right = np.cross(dirv, [0.0, 1.0, 0.0])
    return out, dirv, right


def expand_rocks(spec, rocks, scale=1.0, seed=3):
    """Convierte la spec de rocas en una spec normal con posiciones absolutas ("points" y emisores
    continuos con offset propio) para el simulador."""
    import numpy as np
    R, dirv, right = rock_layout(rocks, spec["rocks"], scale, seed)
    up = np.array([0.0, 1.0, 0.0])

    def world(r, du, sd, y):
        return r["pos"] + dirv * (du * r["gap"]) + right * (sd * scale) + up * (y * scale)

    def events(L, key_var, key_fin):
        out = []
        var = L.get(key_var) or []
        for i, r in enumerate(R):
            if var:
                for ev in var[i % len(var)]:
                    out.append((ev, r))
        for ev in L.get(key_fin) or []:
            out.append((ev, R[-1]))
        return out

    layers = []
    rock_keys = ("rock_emit", "final_emit", "rock_stream", "final_stream")
    for L in spec["layers"]:
        base = {k: v for k, v in L.items() if k not in rock_keys}
        if L.get("rock_stream") or L.get("final_stream"):
            ox, oy, oz = L.get("offset", (0, 0, 0))       # en el marco de la roca, como en el módulo
            for k, ((delay, du, sd, y), r) in enumerate(events(L, "rock_stream", "final_stream")):
                p = (world(r, du, sd + ox, y + oy) - dirv * (oz * scale)) / scale
                layers.append(dict(base, name=f"{L['name']}_{k}", offset=tuple(float(v) for v in p),
                                   stream=[(w[0] + delay + r["delay"], w[1] + delay + r["delay"], w[2], w[3])
                                           for w in L["stream"]]))
            continue
        pts = []
        for (t, n, du, sd, y), r in events(L, "rock_emit", "final_emit"):
            p = world(r, du, sd, y) / scale
            pts.append((round(t + r["delay"], 4), n, float(p[0]), float(p[1]), float(p[2])))
        if pts:
            layers.append(dict(base, points=sorted(pts)))
    flat = {k: v for k, v in spec.items() if k != "layers"}
    flat["layers"] = layers
    return flat


H3_N = h3_spec(False)
H3_I = h3_spec(True)
