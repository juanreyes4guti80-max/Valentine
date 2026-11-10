"""OMNÍVORA — M1 3 "Empuje gravitatorio" (el tercer golpe básico: el que remata el combo).

Omnívora empuja hacia adelante y la GRAVEDAD sale por el suelo en TRIÁNGULO: una onda CURVA (el centro adelante y
las puntas atrás) hecha con Beams curvos que miran a la cámara (FRONT_ARCS: nebulosa, hebras celestes y púrpura,
estrellas, halo y un borde de luz con grosor pegado al suelo; detrás, dos ondas más débiles). Sale rápido y se va
frenando hasta apagarse en el borde lejano. A su paso:
  - RASPA el suelo: queda una marca NEGRA con rayas en la dirección del empuje y surcos largos (los arrastres), que
    se dibuja detrás del frente, dura unos segundos y se desvanece. Un brillo azul muy tenue corre por los surcos.
  - DESPLAZA lo que hay: rocas (Parts del color y material del suelo) salen empujadas hacia adelante, piedritas que
    saltan, polvo que rueda hacia adelante y se abre hacia los lados en los bordes del triángulo, y ráfagas de aire.
  - Toques cósmicos SUTILES: polvo de estrellas en la estela, destellos que titilan sobre la marca, un poco del
    púrpura de la boca, una neblina azul muy oscura y piedritas que flotan un momento (la gravedad quedó revuelta).
  0.00 s  el golpe: un núcleo oscuro que se traga la luz (las motas caen hacia él), un destello y un anillo.
  0.06 s  sale el empuje; llega al borde lejano a los 0.48 s (WAVE = T0, TW, freno).
La cámara se sacude en el golpe y mientras pasa el frente.
Emisiones en el triángulo ("cone_emit"): (t, n, u, s, alto) como en vfx_astral.py (u = fracción del largo desde el
vértice, s = fracción del medio ancho). Las marcas del suelo (Decals) quedan giradas hacia afuera desde el vértice:
las rayas de las texturas om_scrape y om_scrape_line van en la dirección del empuje.
"""
import math
import random

from vfx_omnivora import (CORE, DECAL, DEEPB, DUST, FLASH, INWARD, MOUTH, STAR, STATIC2x2, VOIDC)

GL, GA = 66.0, 46.0                 # largo y apertura del triángulo (escala 1; se eligen al llamar el efecto)
T0, TW, EASE = 0.06, 0.42, 1.6      # el frente sale, tarda en cruzar y cuánto se frena (1 = velocidad constante)
WAVE = (T0, TW, EASE)
TEND = round(T0 + TW, 3)            # llega al borde lejano (ya casi quieto)
STRIKE = (0, 5, -3)                 # el golpe: un poco adelante y arriba del vértice
BULGE = 0.38                        # las puntas del frente quedan 0.38 × medio ancho detrás del centro

# ----------------------------------------------------------------------------- colores (los de Omnívora)
SCRAPE = [(0, (18, 20, 38)), (0.5, (12, 14, 30)), (1, (10, 12, 26))]       # la marca: casi negra, un toque azul
GROOVE = [(0, (6, 7, 16)), (1, (8, 9, 20))]                               # los surcos, más oscuros todavía
WINDC = [(0, (232, 242, 255)), (0.5, (175, 208, 255)), (1, (120, 160, 245))]
PEBBLE = [(0, (128, 126, 134)), (1, (104, 102, 110))]
HAZE = [(0, (30, 40, 96)), (0.5, (20, 28, 72)), (1, (14, 20, 52))]        # neblina azul muy oscura
EMBER = [(0, (120, 180, 255)), (0.5, (70, 125, 250)), (1, (40, 80, 220))]  # el brillo que corre por los surcos
ROCK_RGB = (118, 112, 116)          # color de las rocas en la vista previa (en el juego: el del suelo)
TWINKLE_S = [(0, 0), (0.08, 2.2), (0.22, 1.0), (0.38, 2.4), (0.55, 0.8), (0.72, 2.0), (1, 0)]


def front_t(u, delay=0.0):
    """Instante en que el frente pasa por u (sale rápido y se va frenando)."""
    return round(T0 + delay + TW * (1 - (1 - min(max(u, 0.0), 1.0)) ** (1 / EASE)), 3)


def samples(g, n, u0=0.05, u1=1.0, s_max=0.95, up=(0.3, 0.3), delay=(0.0, 0.0), k=1):
    """n puntos del triángulo (más donde es más ancho), en el instante en que pasa el frente (+ delay)."""
    out = []
    for _ in range(n):
        u = math.sqrt(g.uniform(u0 * u0, u1 * u1))
        out.append((round(front_t(u) + g.uniform(*delay), 3), k, round(u, 4), round(g.uniform(-s_max, s_max), 3),
                    round(g.uniform(*up), 2)))
    return sorted(out)


def at(t, n=1, off=STRIKE):
    return {"emit": [(t, n)], "offset": off}


# ----------------------------------------------------------------------------- el golpe (en el vértice)
def strike_layers():
    return [
        # el núcleo oscuro: la gravedad se traga la luz un instante
        dict(name="PushCore", texture="fx_glow", lifetime=(0.28, 0.28), size=[(0, 4), (0.22, 15), (1, 17)],
             transparency=[(0, 0.55), (0.2, 0.3), (0.6, 0.55), (1, 1)], color=VOIDC, zoffset=2, **at(0.0)),
        # motas que caen hacia el núcleo (la atracción, justo antes del empuje)
        dict(name="PullIn", texture="kk_trace_06", orientation="VelocityParallel",
             shape={"type": "Sphere", "radius": 9, "style": "Surface", "inout": "Inward"}, speed=(95, 115),
             lifetime=(0.08, 0.1), size=[(0, 1.5), (0.5, 5), (1, 1.5)], transparency=[(0, 0.35), (1, 0.6)],
             color=INWARD, light_emission=1.0, brightness=1.6, **at(0.0, 18)),
        dict(name="PushFlash", texture="fx_glow", lifetime=(0.14, 0.14), size=[(0, 3), (0.3, 12), (1, 14)],
             transparency=[(0, 0.2), (0.5, 0.55), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.4,
             zoffset=3, **at(0.05)),
        dict(name="PushStar", texture="kk_star_09", lifetime=(0.2, 0.2), size=[(0, 4), (0.2, 15), (1, 3)],
             transparency=[(0, 0.15), (1, 1)], color=CORE, light_emission=1.0, brightness=1.4, rotation=(0, 90),
             zoffset=4, **at(0.05)),
        dict(name="PushSwirl", texture="fx_wind_swirl", lifetime=(0.3, 0.3), size=[(0, 6), (1, 20)],
             transparency=[(0, 0.4), (0.5, 0.6), (1, 1)], color=DEEPB, light_emission=0.6, brightness=1.2,
             rotation=(0, 360), rot_speed=(-500, -400), zoffset=1, **at(0.0)),
        # el anillo del golpe en el suelo y el polvo que levanta
        dict(name="PushRing", texture="kk_circle_02", lifetime=(0.34, 0.34), size=[(0, 4), (1, 30)],
             transparency=[(0, 0.55), (0.5, 0.75), (1, 1)], color=DEEPB, light_emission=0.6, emit=[(0.05, 1)],
             offset=(0, 0.25, -2), **DECAL),
        dict(name="PushDust", texture="kk_smoke_07", shape={"type": "Sphere", "radius": 3}, direction="Top",
             spread=(180, 180), speed=(14, 26), drag=3, accel=(0, 3, 0), lifetime=(0.6, 0.9),
             size=[(0, 4, 1), (0.3, 9, 2), (1, 12, 2)], transparency=[(0, 0.45), (0.4, 0.6), (1, 1)], color=DUST,
             rotation=(0, 360), rot_speed=(-40, 40), zoffset=-2, emit=[(0.05, 6)], offset=(0, 1.5, -2)),
    ]


# ----------------------------------------------------------------------------- el frente (viaja con la ola)
# `count` puntos a lo ancho del frente; rate = partículas por segundo de cada punto con el frente a todo lo ancho
PUSH_FRONT = {
    "wave": WAVE, "count": 12, "s_max": 0.95,
    "emitters": [
        # polvo que el empuje arrastra: nace en el frente, rueda hacia adelante y se queda atrás frenándose
        dict(name="FrontDust", up=2.6, rate=16, texture="kk_smoke_04", direction="Front", spread=(25, 15),
             speed=(30, 60), drag=3, accel=(0, 2.5, 0), lifetime=(0.6, 1.0),
             size=[(0, 3, 1), (0.3, 7, 1.5), (1, 9.5, 2)],
             transparency=[(0, 0.5), (0.3, 0.45), (0.7, 0.7), (1, 1)], color=DUST, rotation=(0, 360),
             rot_speed=(-60, 60), zoffset=-1),
        # piedritas que saltan hacia adelante
        dict(name="FrontGrit", up=0.8, rate=10, pitch=25, texture="om_cubes_2x2", flipbook=STATIC2x2,
             direction="Front", spread=(25, 15), speed=(40, 75), drag=0.5, accel=(0, -150, 0), lifetime=(0.4, 0.7),
             size=[(0, 0.8, 0.3), (1, 0.6, 0.2)], color=PEBBLE, rotation=(0, 360), rot_speed=(-500, 500)),
        # chispitas de estrella en el frente (sutiles)
        dict(name="FrontStars", up=2.5, rate=6, texture="fx_spark002", direction="Top", spread=(180, 180),
             speed=(2, 6), drag=2, lifetime=(0.35, 0.6), size=[(0, 0), (0.2, 1.6), (0.5, 0.8), (0.7, 1.4), (1, 0)],
             color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 45)),
        # el aire que corre por delante del frente
        dict(name="FrontWind", up=2.5, rate=8, texture="kk_trace_01", orientation="VelocityParallel",
             direction="Front", spread=(6, 4), speed=(110, 150), drag=3, lifetime=(0.18, 0.28),
             size=[(0, 6, 1), (0.5, 12, 2), (1, 6)], transparency=[(0, 0.4), (0.6, 0.55), (1, 1)], color=WINDC,
             light_emission=0.6, brightness=1.3),
    ],
}


def arc(name, texture, width, color, transparency, le, bright, tex_len, speed, up, delay=0.0, ahead=0.0,
        zoffset=0.0):
    """Un arco del frente (un Beam curvo que mira a la cámara; ver runFrontArcs en gen_luau.py)."""
    return {"name": name, "texture": texture, "width": width, "color": color, "transparency": transparency,
            "light_emission": le, "brightness": bright, "tex_len": tex_len, "speed": speed, "up": up,
            "delay": delay, "ahead": ahead, "zoffset": zoffset, "fade": 0.12, "bulge": BULGE, "s_max": 0.97,
            "grow0": 0.3, "ends": 0.16, "segments": 24}


# el frente de gravedad: una onda CURVA (el centro adelante y las puntas atrás) hecha con las texturas del rayo
# cósmico: un cuerpo de nebulosa, hebras de energía celestes y púrpura que corren por la curva, estrellas, un halo
# azul y, pegado al suelo, un borde de luz con grosor; detrás, dos ondas más débiles
FRONT_ARCS = {
    "wave": WAVE,
    "arcs": [
        arc("GravAura", "om_beam_glow", 20, [(0, (40, 80, 210)), (1, (30, 60, 180))], 0.74, 1.0, 0.8, 40, 0.4, 10.0,
            zoffset=-2),
        arc("GravBody", "om_beam_nebula", 11, [(0, (255, 255, 255)), (1, (235, 240, 255))], 0.14, 0.1, 1.0, 18,
            0.6, 5.8),
        arc("GravStrands", "om_beam_flow", 9, [(0, (150, 210, 255)), (1, (110, 185, 255))], 0.36, 0.9, 1.0, 13,
            2.4, 5.8, zoffset=0.2),
        arc("GravStrandsPurple", "om_beam_flow", 7, [(0, (220, 130, 255)), (1, (180, 80, 245))], 0.5, 1.0, 1.0,
            15, -1.5, 5.8, zoffset=0.25),
        arc("GravStars", "om_beam_stars", 8.5, [(0, (255, 255, 255)), (1, (200, 230, 255))], 0.45, 1.0, 1.3, 17,
            0.7, 5.8, zoffset=0.3),
        arc("GravEdge", "om_beam_glow", 3.2, [(0, (175, 222, 255)), (1, (150, 205, 255))], 0.22, 1.0, 1.5, 30,
            0.0, 1.6, ahead=0.8, zoffset=0.4),
        arc("GravRipple0", "om_beam_glow", 2.6, [(0, (120, 180, 255)), (1, (90, 150, 250))], 0.55, 1.0, 1.3, 30,
            0.0, 1.3, delay=0.07),
        arc("GravRipple1", "om_beam_glow", 2.4, [(0, (100, 160, 255)), (1, (70, 120, 240))], 0.7, 1.0, 1.2, 30,
            0.0, 1.2, delay=0.14),
    ],
}


def wave_layers(g):
    """Lo que acompaña al frente (los arcos van en FRONT_ARCS): el viento que barre el triángulo, el polvo que se abre
    en los bordes y el final, donde el empuje se apaga."""
    L = []
    # líneas de aire que salen del vértice y corren con el frente
    lines = sorted((round(T0 + g.uniform(0, 0.03), 3), 1, 0.02, round(g.uniform(-0.95, 0.95), 3),
                    round(g.uniform(1.0, 6.0), 2)) for _ in range(14))
    L.append(dict(name="AirLines", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
                  speed_len=(2.6, 3.0), drag=2, lifetime=(0.4, 0.45), size=[(0, 4), (0.3, 12), (1, 8)],
                  transparency=[(0, 0.35), (0.8, 0.5), (1, 1)], color=WINDC, light_emission=0.7, brightness=1.4,
                  cone_emit=lines))
    # ráfagas finas que nacen donde pasa el frente
    L.append(dict(name="Gusts", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
                  spread=(3, 3), speed=(60, 95), drag=3, lifetime=(0.2, 0.32), size=[(0, 8, 2), (0.5, 14, 3), (1, 8)],
                  transparency=[(0, 0.4), (0.6, 0.55), (1, 1)], color=WINDC, light_emission=0.6, brightness=1.4,
                  cone_emit=samples(g, 26, up=(1.0, 6.0))))
    # en los bordes del triángulo el polvo se abre hacia afuera (como la proa de un barco)
    for side, sv, dname in (("R", 0.97, "Right"), ("L", -0.97, "Left")):
        ev = [(front_t(u), 2, round(u, 3), sv, 2.0) for u in [0.1 + 0.9 * i / 9 for i in range(10)]]
        L.append(dict(name=f"EdgeDust{side}", texture="kk_smoke_04", direction=dname, spread=(35, 20),
                      speed=(18, 34), drag=2.5, accel=(0, 2.5, 0), lifetime=(0.7, 1.1),
                      size=[(0, 3, 1), (0.3, 7, 1.5), (1, 9.5, 2)],
                      transparency=[(0, 0.45), (0.3, 0.4), (0.7, 0.7), (1, 1)], color=DUST, rotation=(0, 360),
                      rot_speed=(-50, 50), zoffset=-1, cone_emit=ev))
    far = [(front_t(0.96), 1, 0.97, round(-0.95 + 1.9 * j / 13, 3), 1.8) for j in range(14)]
    L.append(dict(name="FarDust", texture="kk_smoke_07", direction="Front", pitch=35, spread=(25, 15), speed=(10, 22),
                  drag=2.5, accel=(0, 2, 0), lifetime=(0.8, 1.2), size=[(0, 4, 1), (0.3, 8, 1.5), (1, 10, 2)],
                  transparency=[(0, 0.5), (0.3, 0.45), (0.7, 0.7), (1, 1)], color=DUST, rotation=(0, 360),
                  rot_speed=(-40, 40), zoffset=-1, cone_emit=far))
    stars = sorted((round(t + 0.03 * (j % 3), 3), 1, u, sv, 3.0) for j, (t, _, u, sv, _) in enumerate(far[1::2]))
    L.append(dict(name="FarStars", texture="kk_star_06", direction="Top", spread=(60, 60), speed=(2, 6), drag=1.5,
                  lifetime=(0.5, 0.8), size=TWINKLE_S, color=STAR, light_emission=1.0, brightness=1.8, rotation=(0, 30),
                  cone_emit=stars))
    return L


# ----------------------------------------------------------------------------- rocas que el empuje desplaza
ROCK_LAND = [
    dict(name="RockLandDust", emit=[(0, 3)], texture="kk_smoke_04", direction="Top", spread=(75, 75), speed=(6, 12),
         drag=3, accel=(0, 4, 0), lifetime=(0.5, 0.8), size=[(0, 2, 0.6), (0.4, 4.5, 1), (1, 5.5, 1)],
         transparency=[(0, 0.4), (0.6, 0.6), (1, 1)], color=DUST, rotation=(0, 360)),
]
ROCK_CRUMBLE = [
    dict(name="RockLandCrumble", emit=[(0, 4)], texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top",
         spread=(70, 70), speed=(8, 18), drag=0.5, accel=(0, -120, 0), lifetime=(0.4, 0.7),
         size=[(0, 0.6, 0.2), (1, 0.5, 0.15)], color=PEBBLE, rotation=(0, 360), rot_speed=(-400, 400)),
    dict(name="RockLandCrumbleDust", emit=[(0, 2)], texture="kk_smoke_04", direction="Top", spread=(60, 60),
         speed=(3, 8), drag=2, accel=(0, 2, 0), lifetime=(0.5, 0.8), size=[(0, 2.5, 0.8), (1, 6, 1)],
         transparency=[(0, 0.5), (0.5, 0.65), (1, 1)], color=DUST, rotation=(0, 360)),
]


def rock_layer(name, events, size, speed, pitch, spread, rot):
    return dict(name=name, type="meteor", direction="Front", pitch=pitch, spread=spread, speed=speed,
                accel=(0, -196, 0), drag=0.4, lifetime=(1.8, 1.8),
                sprite={"texture": "om_cubes_2x2", "layout": "Grid2x2", "size": size, "aspect": (1.0, 0.85, 1.0),
                        "cube": True, "ground": True, "color": ROCK_RGB, "color_var": (0.8, 1.1), "rot_speed": rot,
                        "material": "Slate", "stick": 1.0, "sink": 0.25},
                trails=[{"name": f"{name}Dust", "rate": 10, "texture": "kk_smoke_04", "speed": (0, 2),
                         "direction": "Top", "spread": (180, 180), "drag": 2, "lifetime": (0.35, 0.55),
                         "size": [(0, 1.0, 0.3), (1, 3, 0.8)], "transparency": [(0, 0.55), (0.5, 0.65), (1, 1)],
                         "color": DUST, "rotation": (0, 360)}],
                land=ROCK_LAND, shatter=ROCK_CRUMBLE, cone_emit=events)


def rock_layers(g):
    return [
        rock_layer("PushRocks", samples(g, 16, u0=0.12, u1=0.85, s_max=0.85, up=(0.6, 0.6)), (0.8, 1.8),
                   (55, 85), 20, (16, 10), (-500, 500)),
        rock_layer("PushChunks", samples(g, 5, u0=0.2, u1=0.7, s_max=0.7, up=(0.9, 0.9)), (1.6, 2.6),
                   (40, 60), 24, (12, 8), (-300, 300)),
    ]


# ----------------------------------------------------------------------------- la marca negra del raspón
# filas de parches raspados (más y más grandes donde el triángulo es más ancho): (u, cuántos, tamaño en studs)
SCRAPE_ROWS = ((0.13, 1, 15), (0.32, 2, 19), (0.52, 3, 22), (0.72, 3, 26), (0.9, 4, 27))
# los surcos (arrastres de rocas): (s, centros u de sus tramos); empiezan y terminan en distintos lugares
GOUGES = ((-0.62, (0.2, 0.52)), (-0.2, (0.36, 0.68)), (0.15, (0.18, 0.5, 0.82)), (0.5, (0.45, 0.77)),
          (0.8, (0.68,)))
GOUGE_SIZE = 25                                # cada tramo mide ~0.94 de esto
SCRAPE_LIFE = 3.0


def scrape_layers(g):
    L = [
        # donde empezó el empuje el suelo queda más oscuro
        dict(name="ScrapeCore", texture="fx_glow", lifetime=(SCRAPE_LIFE, SCRAPE_LIFE),
             size=[(0, 4), (0.04, 12), (1, 13)], transparency=[(0, 0.6), (0.04, 0.12), (0.75, 0.25), (1, 1)],
             color=SCRAPE, cone_emit=[(T0, 1, 0.03, 0.0, 0.058)], **DECAL),
    ]
    # una base continua (más clara) bajo los parches: la marca queda pareja, sin huecos
    base_tr = [(0, 1), (0.03, 0.55), (0.07, 0.35), (0.72, 0.42), (1, 1)]
    L.append(dict(name="ScrapeBase", texture="om_scrape", lifetime=(SCRAPE_LIFE, SCRAPE_LIFE),
                  size=[(0, 20), (0.04, 36), (1, 37)], transparency=base_tr, color=SCRAPE,
                  cone_emit=[(front_t(0.1), 1, 0.3, 0.0, 0.05)], **DECAL))
    L.append(dict(name="ScrapeBaseFar", texture="om_scrape", lifetime=(SCRAPE_LIFE, SCRAPE_LIFE),
                  size=[(0, 30), (0.04, 52), (1, 53)], transparency=base_tr, color=SCRAPE,
                  cone_emit=[(front_t(0.4), 1, 0.63, 0.0, 0.052)], **DECAL))
    k = 0
    for i, (u, n, size) in enumerate(SCRAPE_ROWS):
        ev = []
        for j in range(n):
            s = 0.0 if n == 1 else -0.72 + 1.44 * j / (n - 1)
            uu = round(u + g.uniform(-0.02, 0.02), 3)
            ss = round(max(-0.9, min(0.9, s + g.uniform(-0.08, 0.08))), 3)
            k += 1
            # cada parche a una altura un poco distinta (los Decals que se tapan no parpadean)
            ev.append((front_t(uu - 0.06), 1, uu, ss, round(0.06 + 0.004 * k, 3)))
        L.append(dict(name=f"Scrape{i}", texture="om_scrape", lifetime=(SCRAPE_LIFE, SCRAPE_LIFE),
                      size=[(0, round(0.55 * size, 1)), (0.03, size), (1, round(1.02 * size, 1))],
                      transparency=[(0, 1), (0.02, 0.35), (0.06, 0.1), (0.72, 0.18), (1, 1)], color=SCRAPE,
                      rotation=(-6, 6), cone_emit=sorted(ev), **DECAL))
    ev = []
    for (sg, us) in GOUGES:
        for uc in us:
            sv = round(sg + g.uniform(-0.03, 0.03), 3)
            ev.append((front_t(uc - 0.12), 1, uc, sv, round(0.13 + 0.004 * len(ev), 3)))
    L.append(dict(name="Gouges", texture="om_scrape_line", lifetime=(SCRAPE_LIFE, SCRAPE_LIFE),
                  size=[(0, GOUGE_SIZE), (1, GOUGE_SIZE)], transparency=[(0, 1), (0.04, 0.2), (0.72, 0.3), (1, 1)],
                  color=GROOVE, cone_emit=sorted(ev), **DECAL))
    # el brillo azul muy tenue que corre por los surcos justo después del frente
    emb = []
    for (sg, us) in GOUGES:
        for _ in range(3 * len(us)):
            u = g.uniform(min(us) - 0.15, max(us) + 0.15)
            emb.append((front_t(u, g.uniform(0.01, 0.06)), 1, round(min(max(u, 0.05), 1.0), 3), sg, 0.35))
    L.append(dict(name="GougeEmbers", texture="fx_glow", lifetime=(0.3, 0.55), size=[(0, 2), (0.2, 4.5), (1, 3)],
                  transparency=[(0, 0.85), (0.3, 0.78), (1, 1)], color=EMBER, light_emission=1.0, brightness=1.1,
                  cone_emit=sorted(emb)))
    return L


# ----------------------------------------------------------------------------- toques cósmicos (sutiles)
def cosmic_layers(g):
    return [
        dict(name="Stardust", texture="fx_particle02", direction="Top", spread=(180, 180), speed=(1, 4), drag=1.5,
             accel=(0, 1.2, 0), lifetime=(0.8, 1.4), size=[(0, 0), (0.1, 0.8, 0.25), (0.8, 0.6), (1, 0)],
             color=STAR, light_emission=1.0, brightness=1.8,
             cone_emit=samples(g, 36, up=(0.5, 5.0), delay=(0.02, 0.15))),
        dict(name="ScrapeTwinkles", texture="kk_star_06", lifetime=(0.6, 1.0), size=TWINKLE_S, color=STAR,
             light_emission=1.0, brightness=2.0, rotation=(0, 30),
             cone_emit=samples(g, 14, u0=0.08, s_max=0.8, up=(0.6, 1.2), delay=(0.1, 0.9))),
        dict(name="PurpleGlints", texture="fx_spark002", lifetime=(0.3, 0.5), size=[(0, 0), (0.3, 2.2), (1, 0)],
             color=MOUTH, light_emission=1.0, brightness=1.8, rotation=(0, 45),
             cone_emit=samples(g, 8, u0=0.15, up=(1.0, 4.0), delay=(0.0, 0.3))),
        # piedritas que flotan un momento sobre la marca: la gravedad quedó revuelta
        dict(name="Levitate", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Top", spread=(20, 20),
             speed=(2, 5), drag=1.2, accel=(0, 1.5, 0), lifetime=(1.2, 1.8), size=[(0, 0.5, 0.2), (1, 0.4, 0.1)],
             transparency=[(0, 0), (0.75, 0.1), (1, 1)], color=PEBBLE, rotation=(0, 360), rot_speed=(-90, 90),
             cone_emit=samples(g, 16, u0=0.1, s_max=0.8, up=(0.3, 0.3), delay=(0.15, 0.5))),
        # neblina azul muy oscura que queda sobre la marca y se disipa
        dict(name="GravityHaze", texture="kk_smoke_07", direction="Top", spread=(40, 40), speed=(1, 3), drag=1.2,
             accel=(0, 0.8, 0), lifetime=(1.0, 1.6), size=[(0, 6, 1), (0.4, 11, 2), (1, 14, 2)],
             transparency=[(0, 0.85), (0.25, 0.72), (0.7, 0.82), (1, 1)], color=HAZE, light_emission=0.15,
             rotation=(0, 360), rot_speed=(-20, 20), zoffset=-3,
             cone_emit=samples(g, 12, u0=0.1, s_max=0.75, up=(2.5, 4.0), delay=(0.05, 0.2))),
    ]


def gravity_push_spec():
    g = random.Random(17)
    L = strike_layers() + wave_layers(g) + rock_layers(g) + scrape_layers(g) + cosmic_layers(g)
    return {
        "name": "GravityPush",
        "doc": ("OMNÍVORA M1 3 (Empuje gravitatorio): empuja hacia adelante y la gravedad sale por el suelo en "
                "TRIÁNGULO; raspa el suelo (marca negra con rayas y surcos), desplaza rocas, polvo y aire, con toques "
                "cósmicos sutiles y sacudida de cámara. "
                "OmnivoraVFX.GravityPush(cf, largo, angulo, escala, sacudida): "
                "cf = vértice del triángulo en el suelo (frente a Omnívora), mirando hacia adelante."),
        "duration": 3.6,
        "cone": {"length": GL, "angle": GA, "wave": list(WAVE)},
        # exporta GravityPushLength, GravityPushAngle, GravityPushTimes y GravityPushFrontTime (para el servidor)
        "front_time": True,
        "times": {"Hit": 0.0, "Push": T0, "Reach": TEND},
        "front": PUSH_FRONT,
        "front_arcs": FRONT_ARCS,
        "light": {"color": (90, 140, 255), "brightness": 4, "range": 34, "time": 0.45},
        "shakes": [(0.0, 0.8, 0.3), (T0 + 0.04, 0.45, 0.45)],
        "layers": L,
    }


GRAVITY_PUSH = gravity_push_spec()
