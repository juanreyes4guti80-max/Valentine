"""PAREDES DE LLAMAS con detonación (H1 y H3), en versión normal e IGNITION.

Filosofía: detonación seca (destello, onda de choque, polvo, rocas en llamas) y, a lo largo de una
línea recta, muchos picos de fuego de alturas variadas que brotan del suelo, se sostienen y se
hunden de vuelta. Cada pico va en capas (exterior rojo-naranja que da las puntas, cuerpo naranja,
núcleo amarillo-blanco), así el color nunca se quema a blanco. Humo oscuro arriba, suelo
brillando y quemado abajo. Ignition = carmesí (núcleo blanco-rosado), más grande en H1 y deja
marcas de fuego.

Todo se posiciona sobre la línea con emisiones (t, n, u, lado, alto): u = fracción del largo
(hacia adelante), lado y alto en studs. Un emisor por tipo de capa y altura de pico.
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
    # las estelas de las rocas quedan naranja-rojizas (como en la captura de Ignition)
    "trail_fire": [(0, (255, 236, 200)), (0.3, (255, 130, 60)), (1, (200, 40, 30))],
    "trail_smoke": [(0, (230, 70, 60)), (0.2, (80, 60, 64)), (1, (120, 112, 116))],
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


# ----------------------------------------------------------------------------- detonación
def detonation_layers(tag, pal, H0, places, n_rocks=8, big=True, burn=1.2):
    """Detonación: destello, anillos, polvo, domo de fuego, chispas y rocas.
    places = [(t, u), ...] sobre la línea; un solo emisor por capa aunque haya varios lugares."""

    def E(dt, n, y):
        return {"emit": [(round(p[0] + dt, 3), n, p[1], 0.0, round(y, 2)) for p in places]}
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


def burn_marks(tag, pal, spots, t0, t_end, k=1.0):
    """Marcas de fuego que quedan ardiendo (Ignition). spots: (u, lado, tamaño[, retraso]) sobre la línea;
    cada marca se enciende en t0 + retraso y se apaga en t_end + retraso."""
    L = []
    t00, t_end0 = t0, t_end
    for i, spot in enumerate(spots):
        a, b, s = spot[:3]
        dt = spot[3] if len(spot) > 3 else 0.0
        t0, t_end = round(t00 + dt, 3), round(t_end0 + dt, 3)
        sc = s * k
        pos = {"line_u": a, "offset": (b, 0.6, 0)}
        pos_hi = {"line_u": a, "offset": (b, 3, 0)}
        glow_e = {"emit": [(t0, 1, a, b, 0.3)]}
        box = {"type": "Box", "size": (_r(6, sc), 0.2, _r(6, sc))}
        L += [
            dict(name=f"{tag}_BurnGlow{i}", decal=True, texture="fx_glow", orientation="VelocityPerpendicular",
                 direction="Top", speed=(0.01, 0.01), lifetime=(t_end - t0 + 0.3, t_end - t0 + 0.3),
                 size=[(0, 0), (0.04, _r(13, sc)), (0.75, _r(10, sc)), (1, 0)],
                 transparency=[(0, 0.35), (0.8, 0.55), (1, 1)], color=pal["glow"], light_emission=0.8,
                 **glow_e),
            dict(name=f"{tag}_BurnFlames{i}", texture="fx_fire_2x2", flipbook=STATIC2x2,
                 orientation="VelocityParallel", shape=box, direction="Top", spread=(8, 8),
                 speed=(_r(7, sc), _r(13, sc)), drag=2, lifetime=(0.4, 0.62),
                 size=[(0, _r(4, sc), sc), (0.3, _r(11, sc), _r(3, sc)), (1, _r(7, sc), _r(2, sc))],
                 transparency=[(0, 0.05), (0.6, 0.15), (1, 1)], color=pal["lick"], light_emission=0.35,
                 brightness=1.6, stream=[(t0, t0 + 0.55 * (t_end - t0), 14, 5), (t0 + 0.55 * (t_end - t0), t_end, 5, 0)],
                 **pos),
            dict(name=f"{tag}_BurnBase{i}", texture="kk_fire_01", shape=box, direction="Top", spread=(20, 20),
                 speed=(2, 5), drag=2, lifetime=(0.35, 0.55),
                 size=[(0, _r(3, sc), sc), (0.4, _r(6, sc), _r(1.5, sc)), (1, _r(4, sc), sc)],
                 transparency=[(0, 0.1), (0.6, 0.3), (1, 1)], color=pal["fire"], light_emission=0.45,
                 brightness=1.5, rotation=(0, 360), rot_speed=(-60, 60), stream=[(t0, t_end, 9, 0)], **pos),
            dict(name=f"{tag}_BurnSmoke{i}", texture="kk_smoke_04", direction="Top", spread=(15, 15),
                 speed=(6, 12), drag=1.2, accel=(0, 6, 0), lifetime=(1.2, 1.7),
                 size=[(0, _r(3, sc), sc), (1, _r(13, sc), _r(3, sc))], transparency=[(0, 0.6), (0.3, 0.45), (1, 1)],
                 color=pal["wisp"], rotation=(0, 360), rot_speed=(-30, 30), zoffset=-2,
                 stream=[(t0 + 0.15, t_end + 0.1, 3, 1)], **pos_hi),
        ]
    return L


# ----------------------------------------------------------------------------- PARED DE LLAMAS
# Geometría de las texturas de llama (fracción del tamaño del sprite, medida en el alfa):
# base de la llama bajo el centro / punta sobre el centro.
TEX_GEOM = {"kk_muzzle_04": (0.40, 0.31), "kk_muzzle_01": (0.418, 0.283), "kk_muzzle_05": (0.40, 0.133)}


def rising_flame(tex, Hv, life=0.67):
    """Llama que brota del suelo, se sostiene y se HUNDE de vuelta al morir (la base nunca flota).
    Hv = altura visible de la punta en el máximo. Devuelve tamaño, altura de emisión y física."""
    bf, tf = TEX_GEOM[tex]
    S = Hv / (bf + tf)
    c = bf * S                      # centro con la base justo en el suelo
    k = 20 * math.log(2)            # Drag 20
    rate = 0.8 * c * 0.67 / life    # hundimiento final
    rise = 0.53 * c
    return {
        "size": [(0, _r(0.55, S)), (0.1, _r(1.0, S)), (0.25, _r(1.04, S)), (0.6, _r(0.97, S)), (1, _r(0.66, S))],
        "y": 0.64 * c,
        "speed": (_r(rise * k - rate, 1), _r(rise * k - rate, 1)),
        "drag": 20, "accel": (0, -_r(rate * k, 1), 0),
    }


def spike_layers(tag, pal, H, places, pulses=(0.0, 0.3), lick_pulses=(0.0, 0.12, 0.24, 0.36, 0.48)):
    """Pico de fuego en capas: exterior rojo-naranja alto (da las puntas), cuerpo naranja y núcleo
    amarillo-blanco abajo. Brota del suelo con un estallido y se hunde al apagarse.
    places = (t, u, lado) sobre la línea."""

    def em(dts, n, y):
        return [(round(t + dt, 3), n, round(u, 4), round(sd, 2), round(y, 2)) for (t, u, sd) in places for dt in dts]

    L = []
    o = rising_flame("kk_muzzle_04", H)
    L.append({"name": f"{tag}_Outer", "texture": "kk_muzzle_04", "orientation": "FacingCameraWorldUp",
              "emit": em(pulses, 1, o["y"]), "direction": "Top", "speed": o["speed"], "drag": o["drag"],
              "accel": o["accel"], "lifetime": (0.62, 0.72), "size": o["size"],
              "transparency": [(0, 0.1), (0.08, 0), (0.55, 0.04), (0.8, 0.35), (1, 1)], "color": pal["sp_outer"],
              "light_emission": 0.08, "brightness": 1.1, "rotation": (-4, 4)})
    b = rising_flame("kk_muzzle_01", 0.62 * H)
    L.append({"name": f"{tag}_Body", "texture": "kk_muzzle_01", "orientation": "FacingCameraWorldUp",
              "emit": em(tuple(p + 0.02 for p in pulses), 1, b["y"]), "direction": "Top", "speed": b["speed"],
              "drag": b["drag"], "accel": b["accel"], "lifetime": (0.6, 0.7), "size": b["size"],
              "transparency": [(0, 0.1), (0.08, 0), (0.55, 0.05), (0.8, 0.4), (1, 1)], "color": pal["sp_body"],
              "light_emission": 0.2, "brightness": 1.25, "rotation": (-7, 7), "zoffset": 0.5})
    c = rising_flame("kk_muzzle_01", 0.34 * H)
    L.append({"name": f"{tag}_Core", "texture": "kk_muzzle_01", "orientation": "FacingCameraWorldUp",
              "emit": em(tuple(p + 0.03 for p in pulses), 1, c["y"]), "direction": "Top", "speed": c["speed"],
              "drag": c["drag"], "accel": c["accel"], "lifetime": (0.55, 0.65), "size": c["size"],
              "transparency": [(0, 0.15), (0.08, 0.05), (0.5, 0.1), (0.8, 0.5), (1, 1)], "color": pal["sp_core"],
              "light_emission": 0.45, "brightness": 1.35, "rotation": (-8, 8), "zoffset": 1})
    # lenguas que trepan por el pico y se sueltan arriba (parpadeo de la silueta)
    L.append({"name": f"{tag}_Licks", "texture": "kk_muzzle_05", "orientation": "VelocityParallel",
              "emit": em(lick_pulses, 2, 0.1 * H), "direction": "Top", "spread": (6, 6),
              "speed": (_r(1.2, H), _r(2.4, H)), "drag": 4, "lifetime": (0.25, 0.4),
              "size": [(0, _r(0.12, H)), (0.3, _r(0.3, H)), (1, _r(0.14, H))],
              "transparency": [(0, 0.1), (0.6, 0.2), (1, 1)], "color": pal["sp_outer"],
              "light_emission": 0.15, "brightness": 1.2, "zoffset": 0.3})
    # fuego denso al pie: une los picos en una banda continua
    L.append({"name": f"{tag}_Foot", "texture": "kk_fire_01", "emit": em(lick_pulses[:4], 2, 0.06 * H),
              "shape": {"type": "Box", "size": (_r(0.2, H), 0.5, _r(0.2, H))},
              "direction": "Top", "spread": (12, 12), "speed": (_r(0.2, H), _r(0.8, H)), "drag": 3,
              "accel": (0, _r(0.3, H), 0), "lifetime": (0.4, 0.6),
              "size": [(0, _r(0.12, H), _r(0.03, H)), (0.3, _r(0.26, H), _r(0.04, H)), (1, _r(0.2, H), _r(0.03, H))],
              "transparency": [(0, 0), (0.6, 0.1), (0.85, 0.5), (1, 1)], "color": pal["sp_body"],
              "light_emission": 0.25, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-60, 60),
              "zoffset": 1.5})
    # estallido al nacer + raya incandescente que sube disparada
    L.append({"name": f"{tag}_Pop", "texture": "fx_burst_fan", "orientation": "FacingCameraWorldUp",
              "emit": em((0.0,), 1, 0.2 * H), "lifetime": (0.18, 0.22),
              "size": [(0, _r(0.2, H)), (0.3, _r(0.55, H)), (1, _r(0.62, H))],
              "transparency": [(0, 0), (0.4, 0.3), (1, 1)], "color": pal["hot"],
              "light_emission": 0.5, "brightness": 1.3, "zoffset": 2})
    L.append({"name": f"{tag}_Streak", "texture": "fx_line", "orientation": "VelocityParallel",
              "emit": em((0.0,), 1, 0.05 * H), "direction": "Top", "spread": (2, 2),
              "speed": (_r(4.0, H), _r(5.0, H)), "drag": 8, "lifetime": (0.2, 0.26),
              "size": [(0, _r(0.6, H), _r(0.1, H)), (1, _r(0.8, H), _r(0.1, H))],
              "transparency": [(0, 0), (0.5, 0.25), (1, 1)], "color": pal["core"],
              "light_emission": 1.0, "brightness": 1.5})
    # brasas que se desprenden
    L.append({"name": f"{tag}_Embers", "texture": "kk_flare_01", "emit": em((0.12, 0.4), 2, 0.5 * H),
              "shape": {"type": "Box", "size": (_r(0.15, H), _r(0.7, H), _r(0.15, H))},
              "direction": "Top", "spread": (40, 40), "speed": (_r(0.1, H), _r(0.5, H)), "drag": 1.6,
              "accel": (0, _r(0.25, H), 0), "lifetime": (0.6, 1.0),
              "size": [(0, 0), (0.1, _r(0.04, H), _r(0.012, H)), (1, 0)], "color": pal["ember"],
              "light_emission": 1.0, "brightness": 1.6})
    return L


def wall_places(n, u0, u1, t_start, sweep, seed, side_jit=1.2):
    """Picos a lo largo de la línea: alturas MUY variadas (borde dramático) y algunos picos 'estrella'."""
    g = random.Random(seed)
    ph = g.uniform(0, 6.28)
    cls = {1.4: [], 1.0: [], 0.74: [], 0.52: []}
    for i in range(n):
        f = i / max(1, n - 1)
        u = u0 + (u1 - u0) * f + g.uniform(-0.3, 0.3) * (u1 - u0) / max(1, n - 1)
        u = round(min(1.0, max(0.0, u)), 4)
        t = round(t_start + sweep * f + g.uniform(0, 0.05), 3)
        side = round(g.uniform(-side_jit, side_jit), 2)
        h = 0.72 + 0.22 * math.sin(f * math.pi * 3.1 + ph) + g.uniform(-0.2, 0.2)
        if g.random() < 0.14:
            c = 1.4
        else:
            c = 1.0 if h > 0.86 else (0.74 if h > 0.64 else 0.52)
        cls[c].append((t, u, side))
    return cls


def flame_wall(tag, pal, Hb, L0, u0, u1, t_start, sweep, n_pillars, seed, pulses=(0.0, 0.3)):
    """Pared de llamas: muchos picos de alturas variadas que se tocan en la base + humo oscuro
    que brota de las puntas mientras arde."""
    L = []
    g = random.Random(seed + 99)
    smk = []
    last = max(pulses)
    for c, places in wall_places(n_pillars, u0, u1, t_start, sweep, seed).items():
        if not places:
            continue
        H = round(Hb * c, 1)
        L += spike_layers(f"{tag}S{int(c * 100)}", pal, H, places, pulses=pulses,
                          lick_pulses=tuple(round(i * 0.12, 2) for i in range(int((last + 0.36) / 0.12) + 1)))
        for (t, u, sd) in places:
            for dt in (0.3, 0.55, 0.8) + ((1.05,) if last > 0.4 else ()):
                smk.append((round(t + dt + g.uniform(0, 0.08), 3), 1, u, round(sd + g.uniform(-1.5, 1.5), 2),
                            round(H * g.uniform(0.6, 0.95), 2)))
    smk.sort()
    L.append({"name": f"{tag}_WallSmoke", "texture": "kk_smoke_08", "emit": smk, "direction": "Top",
              "spread": (25, 25), "speed": (_r(0.08, Hb), _r(0.35, Hb)), "drag": 1.0,
              "accel": (0, _r(0.15, Hb), 0), "lifetime": (1.3, 1.9),
              "size": [(0, _r(0.16, Hb), _r(0.04, Hb)), (0.35, _r(0.4, Hb), _r(0.08, Hb)), (1, _r(0.6, Hb), _r(0.1, Hb))],
              "transparency": [(0, 0.8), (0.12, 0.45), (0.5, 0.6), (0.8, 0.85), (1, 1)], "color": pal["wsmoke"],
              "rotation": (0, 360), "rot_speed": (-20, 20), "zoffset": _r(-0.3, Hb)})
    return L


def rock_wall(tag, pal, Hb, L0, rocks, seed, per_rock=4, pulses=(0.0, 0.3), extra=None):
    """Pared de llamas que nace de rocas que detonan en cadena: cada roca levanta su racimo de
    picos (el más alto en la roca, más bajos hacia los lados) y el racimo se abre en ~0.1 s.
    rocks = [(t_detonación, u), ...]"""
    g = random.Random(seed)
    cls = {1.4: [], 1.0: [], 0.74: [], 0.52: []}
    gap = 1.0 / max(1, len(rocks) - 1) if len(rocks) > 1 else 0.2
    for (tr, ur) in rocks:
        for j in range(per_rock):
            # reparte los picos en [-gap/2, gap/2] alrededor de la roca
            f = (j + 0.5) / per_rock - 0.5
            du = f * gap * 1.05 + g.uniform(-0.12, 0.12) * gap / per_rock
            u = round(min(1.0, max(0.0, ur + du)), 4)
            d = abs(du) / (gap / 2)
            t = round(tr + 0.12 * d + g.uniform(0, 0.03), 3)
            if d < 0.3:
                c = 1.4 if g.random() < 0.45 else 1.0
            elif d < 0.65:
                c = 1.0 if g.random() < 0.4 else 0.74
            else:
                c = 0.74 if g.random() < 0.35 else 0.52
            cls[c].append((t, u, round(g.uniform(-1.2, 1.2), 2)))
    for c, places in (extra or {}).items():     # picos del remate que comparten emisor con la pared
        cls[c] += places
    L = []
    smk = []
    last = max(pulses)
    for c, places in cls.items():
        if not places:
            continue
        H = round(Hb * c, 1)
        L += spike_layers(f"{tag}S{int(c * 100)}", pal, H, places, pulses=pulses,
                          lick_pulses=tuple(round(i * 0.12, 2) for i in range(int((last + 0.36) / 0.12) + 1)))
        for (t, u, sd) in places:
            for dt in (0.3, 0.55, 0.8) + ((1.05,) if last > 0.4 else ()):
                smk.append((round(t + dt + g.uniform(0, 0.08), 3), 1, u, round(sd + g.uniform(-1.5, 1.5), 2),
                            round(H * g.uniform(0.6, 0.95), 2)))
    smk.sort()
    L.append({"name": f"{tag}_WallSmoke", "texture": "kk_smoke_08", "emit": smk, "direction": "Top",
              "spread": (25, 25), "speed": (_r(0.08, Hb), _r(0.35, Hb)), "drag": 1.0,
              "accel": (0, _r(0.15, Hb), 0), "lifetime": (1.3, 1.9),
              "size": [(0, _r(0.16, Hb), _r(0.04, Hb)), (0.35, _r(0.4, Hb), _r(0.08, Hb)), (1, _r(0.6, Hb), _r(0.1, Hb))],
              "transparency": [(0, 0.8), (0.12, 0.45), (0.5, 0.6), (0.8, 0.85), (1, 1)], "color": pal["wsmoke"],
              "rotation": (0, 360), "rot_speed": (-20, 20), "zoffset": _r(-0.3, Hb)})
    return L


def final_pillar(tag, pal, Hp, t, u, pulses=(0.0, 0.3, 0.6)):
    """Remate: un pilar gigante (pico muy alto) que revienta arriba en fuego y humo.
    Los picos que lo rodean van en la pared (ver final_side_spikes)."""
    L = spike_layers(f"{tag}P", pal, Hp, [(t, u, -1.0), (round(t + 0.03, 3), u, 1.0)], pulses=pulses,
                     lick_pulses=tuple(round(i * 0.12, 2) for i in range(int((max(pulses) + 0.36) / 0.12) + 1)))
    E = lambda dt, n, y: [(round(t + dt, 3), n, u, 0.0, round(y, 2))]
    L.append({"name": f"{tag}_Cap", "texture": "kk_fire_02", "emit": E(0.14, 6, 0.85 * Hp) + E(0.42, 4, 0.82 * Hp),
              "shape": {"type": "Sphere", "radius": _r(0.06, Hp), "style": "Surface"},
              "direction": "Top", "spread": (180, 180), "speed": (_r(0.08, Hp), _r(0.25, Hp)), "drag": 3,
              "accel": (0, _r(0.18, Hp), 0), "lifetime": (0.55, 0.75),
              "size": [(0, _r(0.14, Hp)), (0.3, _r(0.3, Hp)), (1, _r(0.38, Hp))],
              "transparency": [(0, 0), (0.55, 0.1), (0.85, 0.5), (1, 1)], "color": pal["dome"],
              "light_emission": 0.2, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-50, 50)})
    L.append({"name": f"{tag}_Column", "texture": "kk_smoke_07", "emit": E(0.45, 3, 0.9 * Hp) + E(0.75, 3, 0.85 * Hp)
              + E(1.05, 2, 0.8 * Hp), "direction": "Top", "spread": (30, 30), "speed": (_r(0.1, Hp), _r(0.25, Hp)),
              "drag": 1.2, "accel": (0, _r(0.14, Hp), 0), "lifetime": (1.4, 1.9),
              "size": [(0, _r(0.18, Hp), _r(0.04, Hp)), (0.4, _r(0.4, Hp), _r(0.06, Hp)), (1, _r(0.55, Hp), _r(0.08, Hp))],
              "transparency": [(0, 0.7), (0.12, 0.4), (0.55, 0.55), (0.85, 0.85), (1, 1)], "color": pal["wsmoke"],
              "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": _r(-0.2, Hp)})
    return L


def final_side_spikes(t, u):
    """Picos que rodean al pilar del remate (se abren a lo ancho de la línea); van en la pared."""
    return {1.4: [(round(t + 0.03, 3), u, -2.4), (round(t + 0.04, 3), u, 2.2)],
            1.0: [(round(t + 0.06, 3), u, -4.6), (round(t + 0.07, 3), u, 4.4),
                  (round(t + 0.05, 3), round(u - 0.03, 3), 0.8)]}


def line_aftermath(tag, pal, L0, u0, u1, t_start, sweep, vis, H0=20, step=12, glow=1.3):
    """Quemadura continua + brasas a lo largo de la línea."""
    span = (u1 - u0) * L0
    n = max(2, int(round(span / step)) + 1)
    places = [(round(t_start + sweep * i / (n - 1), 3), round(u0 + (u1 - u0) * i / (n - 1), 4)) for i in range(n)]
    L = [
        dict(name=f"{tag}_GroundGlow", decal=True, texture="fx_glow", orientation="VelocityPerpendicular",
             direction="Top", speed=(0.01, 0.01), lifetime=(glow, glow),
             size=[(0, _r(0.4, H0)), (0.1, _r(1.5, H0)), (0.7, _r(1.4, H0)), (1, _r(1.2, H0))],
             transparency=[(0, 0.5), (0.1, 0.25), (0.6, 0.45), (1, 1)], color=pal["glow"], light_emission=0.8,
             zoffset=-0.5, emit=[(round(t + 0.02, 3), 1, u, 0.0, 0.25) for t, u in places]),
        dict(name=f"{tag}_Scorch", decal=True, texture="kz_scorch", orientation="VelocityPerpendicular",
             direction="Top", speed=(0.01, 0.01), lifetime=(vis - t_start, vis - t_start),
             size=[(0, _r(0.3, H0)), (0.04, _r(1.0, H0)), (1, _r(1.05, H0))],
             transparency=[(0, 0.15), (0.8, 0.3), (1, 1)], rotation=(0, 360), zoffset=-1,
             emit=[(round(t + 0.03, 3), 1, u, 0.0, 0.15) for t, u in places]),
        dict(name=f"{tag}_Embers", texture="kk_flare_01", direction="Top", spread=(60, 60),
             speed=(_r(0.4, H0), _r(1.2, H0)), drag=1.6, accel=(0, _r(0.6, H0), 0), lifetime=(0.8, 1.2),
             size=[(0, 0), (0.1, _r(0.12, H0), _r(0.04, H0)), (1, 0)], color=pal["ember"],
             light_emission=1.0, brightness=1.6,
             emit=[(round(t + 0.15, 3), 5, u, 0.0, round(0.6 * H0, 2)) for t, u in places]),
    ]
    return L


def line_licks(tag, pal, spots, t0, t_end):
    """Llamitas breves sobre la línea (versión normal)."""
    L = []
    for i, spot in enumerate(spots):
        u, side, s = spot[:3]
        dt = spot[3] if len(spot) > 3 else 0.0
        L.append(dict(name=f"{tag}_Lick{i}", texture="fx_fire_2x2", flipbook=STATIC2x2,
                      orientation="VelocityParallel", line_u=u, offset=(side, 0.6, 0),
                      shape={"type": "Box", "size": (_r(5, s), 0.2, _r(5, s))}, direction="Top", spread=(8, 8),
                      speed=(_r(6, s), _r(11, s)), drag=2, lifetime=(0.35, 0.55),
                      size=[(0, _r(3, s), s), (0.3, _r(8, s), _r(2, s)), (1, _r(5, s), _r(1.5, s))],
                      transparency=[(0, 0.05), (0.6, 0.15), (1, 1)], color=pal["lick"], light_emission=0.35,
                      brightness=1.6, stream=[(round(t0 + dt, 3), round(t_end + dt, 3), 10, 0)]))
    return L


# ----------------------------------------------------------------------------- H1
def h1_spec(ignition=False):
    """H1: el tajo impacta y una PARED DE LLAMAS avanza rompiendo el suelo hacia adelante.
    Uso: cf = punto de impacto en el suelo, mirando hacia adelante; largo en studs."""
    pal = IGNITION if ignition else NORMAL
    k = 1.35 if ignition else 1.0                 # Ignition: más grande (más alta y más larga)
    tag = "I" if ignition else "N"
    L0 = round(100 * k)
    Hb = round(32 * k, 1)
    t0, sweep = 0.05, (0.6 if ignition else 0.5)
    g = random.Random(41)
    L = []
    # golpe de la espada: la detonación más fuerte, al inicio de la línea
    L += detonation_layers(f"{tag}Hit", pal, round(42 * k, 1), [(0.0, 0.0)], n_rocks=6 if ignition else 4,
                           burn=2.0 if ignition else 1.0)
    # el suelo se rompe a lo largo del camino: chispazos, polvo y rocas que saltan
    n_cr = 6 if ignition else 5
    crack_places = [(round(t0 + sweep * (i + 1) / n_cr, 3), round((i + 1) / n_cr, 3)) for i in range(n_cr)]
    L += [Ld for Ld in detonation_layers(f"{tag}Cr", pal, round(20 * k, 1), crack_places,
                                         n_rocks=2, big=False, burn=1.4 if ignition else 0.8)
          if not Ld["name"].endswith(("FlashStar", "Glow", "GroundRing"))]
    # la pared
    L += flame_wall(f"{tag}W", pal, Hb, L0, 0.0, 1.0, t0, sweep, 32 if ignition else 24, seed=17,
                    pulses=(0.0, 0.3, 0.6) if ignition else (0.0, 0.3))
    vis = 4.8 if ignition else 3.0
    L += line_aftermath(f"{tag}A", pal, L0, 0.0, 1.0, t0, sweep, vis, H0=round(20 * k, 1),
                        glow=1.7 if ignition else 1.25)
    if ignition:
        spots = [(round(i / 6 + g.uniform(-0.04, 0.04), 3), round(g.uniform(-3, 3), 2), round(1.0 + 0.6 * g.random(), 2))
                 for i in range(7)]
        # cada marca se enciende cuando su tramo de muro empieza a apagarse
        spots = [(min(1.0, max(0.0, u)), sd, sc, round(sweep * min(1.0, max(0.0, u)), 3)) for u, sd, sc in spots]
        L += burn_marks(f"{tag}Burn", pal, spots, 0.75, 4.4, k=1.15)
    else:
        spots = [(round(0.1 + 0.8 * i / 3, 3), round(g.uniform(-2, 2), 2), round(0.9 + 0.4 * g.random(), 2)) for i in range(4)]
        spots = [(u, sd, sc, round(sweep * u, 3)) for u, sd, sc in spots]
        L += line_licks(f"{tag}Lick", pal, spots, 0.6, 1.6)
    return {
        "name": "H1_ExplosionIgnition" if ignition else "H1_Explosion",
        "doc": ("H1 IGNITION: pared de llamas carmesí, más alta y larga; deja marcas de fuego ~4 s. "
                if ignition else "H1: el golpe levanta una pared de llamas que avanza rompiendo el suelo. ")
               + "KaijuFireVFX.<nombre>(CFrame.lookAt(impacto, impacto + adelante), largo, escala, sacudida).",
        "duration": 6.0 if ignition else 3.6,
        "line": L0,
        "shakes": [(0.0, 1.0, 0.9)],
        "light": {"color": (255, 60, 90) if ignition else (255, 150, 60), "brightness": 6, "range": 60,
                  "time": 1.8 if ignition else 1.3, "sweep": t0 + sweep},
        "layers": L,
    }


# ----------------------------------------------------------------------------- H3
def h3_spec(ignition=False):
    """H3: las rocas que dejó el rayo detonan EN CADENA; cada una levanta su racimo de pilares y
    juntas forman una PARED DE LLAMAS. Al final del rayo, el remate: un pilar gigante.
    Uso: cf = inicio de la línea en el suelo, mirando hacia donde fue el rayo; largo en studs."""
    pal = IGNITION if ignition else NORMAL
    tag = "J" if ignition else "T"
    g = random.Random(7)
    L0 = 100
    Hb = 34 if ignition else 30
    N = 7
    us = [round(0.04 + 0.86 * i / (N - 1), 3) for i in range(N)]
    t0, step = 0.1, 0.07                     # cadena: una roca cada 0.07 s
    rocks = [(round(t0 + step * i, 3), u) for i, u in enumerate(us)]
    L = []
    # anticipación: cada roca se pone al rojo un instante antes de estallar
    L.append(dict(name=f"{tag}_Heat", texture="fx_glow", lifetime=(0.14, 0.18),
                  size=[(0, 3), (0.6, 10), (1, 7)], transparency=[(0, 0.55), (0.6, 0.35), (1, 1)],
                  color=pal["glow"], light_emission=0.7, brightness=1.0,
                  emit=[(round(t - 0.08, 3), 1, u, 0.0, 2.0) for t, u in rocks]))
    L += [Ld for Ld in detonation_layers(f"{tag}D", pal, 24, rocks, n_rocks=2,
                                         big=False, burn=1.4 if ignition else 0.8)
          if not Ld["name"].endswith(("FlashStar", "Glow"))]
    pulses = (0.0, 0.3, 0.6) if ignition else (0.0, 0.3)
    t_fin = round(rocks[-1][0] + 0.12, 3)          # remate al final del rayo
    L += rock_wall(f"{tag}W", pal, Hb, L0, rocks, seed=23, pulses=pulses,
                   extra=final_side_spikes(round(t_fin + 0.02, 3), 1.0))
    L += detonation_layers(f"{tag}Fin", pal, 44, [(t_fin, 1.0)], n_rocks=6, burn=2.0 if ignition else 1.0)
    L += final_pillar(f"{tag}F", pal, round(Hb * 2.1, 1), round(t_fin + 0.02, 3), 1.0,
                      pulses=(0.0, 0.3, 0.6) if ignition else (0.0, 0.3, 0.55))
    vis = 4.4 if ignition else 3.0
    L += line_aftermath(f"{tag}A", pal, L0, 0.0, 1.0, t0, step * (N - 1) / 0.86, vis, H0=22,
                        glow=1.7 if ignition else 1.25)
    if ignition:
        spots = [(u, round(g.uniform(-3, 3), 2), round(0.9 + 0.5 * g.random(), 2), round(t - t0, 3)) for t, u in rocks]
        spots.append((1.0, 0.0, 1.5, round(t_fin - t0, 3)))
        L += burn_marks(f"{tag}Burn", pal, spots, 0.8, 4.2)
    else:
        spots = [(us[i], round(g.uniform(-2, 2), 2), round(0.9 + 0.4 * g.random(), 2), round(rocks[i][0] - t0, 3))
                 for i in (1, 3, 5)]
        L += line_licks(f"{tag}Lick", pal, spots, 0.65, 1.7)
    return {
        "name": "H3_DetonationIgnition" if ignition else "H3_Detonation",
        "doc": ("H3 IGNITION: las rocas detonan en una pared de llamas carmesí y dejan marcas de fuego. "
                if ignition else "H3: las rocas de la línea detonan en cadena y levantan una pared de llamas. ")
               + "KaijuFireVFX.<nombre>(CFrame.lookAt(inicio, inicio + direccion), largo, escala, sacudida).",
        "duration": 6.2 if ignition else 3.9,
        "line": L0,
        "shakes": [(t0, 0.5, 0.5), (t_fin, 1.0, 0.8)],
        "light": {"color": (255, 60, 90) if ignition else (255, 150, 60), "brightness": 5, "range": 50,
                  "time": 1.8 if ignition else 1.3, "sweep": t_fin},
        "layers": L,
    }


H1_N = h1_spec(False)
H1_I = h1_spec(True)
H3_N = h3_spec(False)
H3_I = h3_spec(True)
