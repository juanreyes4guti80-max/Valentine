"""ASTRAL COLOSSUS — VFX cósmicos (galaxia: morado, azul y blanco).

H1 "Choque astral": la lanza choca contra el escudo (destello estelar, anillos, relámpagos cósmicos) y
lanza hacia adelante TRES OLAS DE AIRE en forma de TRIÁNGULO, cada una más débil que la anterior. La
primera es DESTRUCTIVA: rompe el suelo (grietas de luz y marcas oscuras), arranca rocas que salen
volando con estela cósmica, levanta esquirlas y estallidos de polvo, y empuja un muro de polvo por
delante. Detrás queda un campo de nebulosa con estrellas y polvo SUSPENDIDOS, casi quietos y
titilando: ahí el tiempo se frena (la ralentización).

Las emisiones del triángulo van en "cone_emit": (t, n, u, s, alto)
  u = fracción del largo (0 = vértice, 1 = borde lejano), s = fracción del medio ancho en esa
  distancia (-1 izquierda .. 1 derecha), alto en studs. Cada emisión sale mirando desde el vértice
  hacia su punto (y "pitch" grados hacia arriba), así todo se abre en abanico. Largo y ángulo del
  triángulo se eligen al llamar el efecto.
"""
import random

# ----------------------------------------------------------------------------- colores
WHITE = [(0, (255, 255, 255)), (1, (225, 228, 255))]
CORE = [(0, (236, 242, 255)), (0.5, (170, 182, 255)), (1, (128, 108, 255))]        # blanco azulado -> morado
FLASH = [(0, (172, 178, 255)), (0.4, (140, 128, 255)), (1, (108, 84, 240))]       # azul -> morado
WIND = [(0, (235, 242, 255)), (0.35, (160, 188, 255)), (1, (120, 96, 255))]        # blanco -> azul -> morado
WIND2 = [(0, (225, 215, 255)), (0.4, (170, 124, 255)), (1, (104, 72, 232))]        # blanco -> morado
WALL = [(0, (176, 190, 255)), (0.5, (142, 142, 255)), (1, (120, 100, 250))]        # muro de aire
GUST = [(0, (196, 210, 255)), (0.4, (142, 162, 255)), (1, (120, 96, 255))]         # ráfagas: azul -> morado
NEB_P = [(0, (148, 108, 255)), (0.5, (110, 84, 236)), (1, (80, 64, 200))]          # nebulosa morada
NEB_B = [(0, (118, 160, 255)), (0.5, (82, 112, 236)), (1, (60, 72, 192))]          # nebulosa azul
STAR = [(0, (255, 255, 255)), (0.5, (222, 232, 255)), (1, (184, 194, 255))]
SPARK = [(0, (242, 246, 255)), (0.5, (172, 184, 255)), (1, (132, 104, 255))]
CRACK = [(0, (228, 212, 255)), (1, (134, 92, 255))]
GLOW_P = [(0, (132, 100, 255)), (1, (90, 70, 220))]
DUST = [(0, (204, 198, 232)), (0.5, (170, 164, 204)), (1, (146, 140, 176))]       # polvo de roca, algo lila
SCAR = [(0, (46, 36, 70)), (1, (60, 50, 84))]                                      # suelo roto (oscuro)
ROCK_TRAIL = [(0, (236, 240, 255)), (0.4, (150, 150, 255)), (1, (110, 80, 230))]

TWINKLE = [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2), (0.72, 2.8), (1, 0)]
STATIC2x2 = ("Grid2x2", "Random", 0, True)

T0, TW = 0.05, 0.36                     # la primera ola sale a los 0.05 s y llega al final a los 0.41 s
WAVES = ((0.0, 1.0), (0.13, 0.78), (0.26, 0.56))   # (retraso, fuerza) de las tres olas de aire
CLASH = (0, 13, 4)                      # donde chocan lanza y escudo (sobre el vértice, un poco atrás)


def _front(u, delay=0.0):
    """Instante en que la ola pasa por u."""
    return round(T0 + delay + TW * u, 3)


def _cone_samples(g, u0, u1, n_u, base, per_u, up_range, delay=0.0, dt=(0.0, 0.0), s_max=0.95):
    """Puntos dentro del triángulo (más donde es más ancho), en el instante en que pasa la ola."""
    out = []
    for i in range(n_u):
        u = u0 + (u1 - u0) * (i / max(1, n_u - 1))
        for _ in range(base + int(round(per_u * u))):
            uu = min(1.0, max(0.0, u + g.uniform(-0.03, 0.03)))
            out.append((round(_front(uu, delay) + g.uniform(*dt), 3), round(uu, 4),
                        round(g.uniform(-s_max, s_max), 3), round(g.uniform(*up_range), 2)))
    return sorted(out)


def _ce(samples, n=1, up=None):
    return [(t, n, u, s, up if up is not None else h) for (t, u, s, h) in samples]


def clash_layers():
    def at(t, n=1):
        return {"emit": [(t, n)], "offset": CLASH}
    L = [
        dict(name="ClashFlash", texture="fx_glow", lifetime=(0.13, 0.13),
             size=[(0, 5), (0.3, 20), (1, 22)], transparency=[(0, 0.15), (0.45, 0.5), (1, 1)],
             color=FLASH, light_emission=0.7, brightness=1.3, zoffset=4, **at(0.0)),
        dict(name="ClashStar", texture="kk_star_09", lifetime=(0.26, 0.26),
             size=[(0, 10), (0.18, 28), (1, 6)], color=CORE, light_emission=0.7, brightness=1.3,
             rotation=(0, 90), rot_speed=(-60, 60), zoffset=5, **at(0.0)),
        dict(name="ClashGlint", texture="kk_star_08", lifetime=(0.2, 0.2),
             size=[(0, 44), (1, 12)], transparency=[(0, 0.1), (0.5, 0.35), (1, 1)], color=WIND,
             light_emission=0.9, brightness=1.4, rotation=(0, 360), zoffset=5, **at(0.02)),
        dict(name="ClashBurst", texture="fx_shock_soft", lifetime=(0.3, 0.3),
             size=[(0, 8), (1, 44)], transparency=[(0, 0.55), (0.6, 0.8), (1, 1)], color=FLASH,
             light_emission=0.5, brightness=1.2, rotation=(0, 360), zoffset=3, **at(0.0)),
        dict(name="ClashRing", texture="kk_circle_03", lifetime=(0.28, 0.28),
             size=[(0, 4), (1, 40)], transparency=[(0, 0.25), (0.6, 0.6), (1, 1)], color=FLASH,
             light_emission=0.6, brightness=1.3, zoffset=3, **at(0.04)),
        dict(name="ClashRing2", texture="fx_shock_wave003", lifetime=(0.34, 0.34),
             size=[(0, 6), (1, 44)], transparency=[(0, 0.35), (0.5, 0.7), (1, 1)], color=WIND2,
             light_emission=0.5, brightness=1.2, rotation=(0, 360), zoffset=2, **at(0.03)),
        dict(name="ClashSparks", texture="kk_trace_01", orientation="VelocityParallel",
             direction="Top", spread=(180, 180), speed=(70, 130), drag=6, lifetime=(0.18, 0.34),
             size=[(0, 8, 2), (1, 2)], color=SPARK, light_emission=1.0, brightness=1.8, **at(0.0, 40)),
        dict(name="ClashSwirl", texture="fx_wind_swirl", lifetime=(0.4, 0.4),
             size=[(0, 6), (1, 40)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=WIND2,
             light_emission=0.6, brightness=1.4, rotation=(0, 360), rot_speed=(300, 360), **at(0.02)),
    ]
    for k, tex in enumerate(("kk_spark_05", "kk_spark_06")):
        L.append(dict(name=f"ClashBolts{k}", texture=tex, lifetime=(0.08, 0.12),
                      size=[(0, 18, 5), (1, 24, 5)], color=CRACK, light_emission=0.8, brightness=1.5,
                      rotation=(0, 360), zoffset=4, emit=[(0.0, 3), (0.06, 2), (0.12, 2)], offset=CLASH))
    return L


def air_wave_layers(g):
    """Tres olas de aire: cada una es un muro de luz que barre el triángulo, con ráfagas de viento y
    un muro de polvo empujado por delante. La primera es la más fuerte."""
    L = []
    gusts, thin, dust = [], [], []
    for w, (delay, k) in enumerate(WAVES):
        # el FRENTE de la ola: partículas que salen del vértice en abanico y viajan a la velocidad de la ola,
        # así forman un arco de aire que se abre y avanza hasta el borde del triángulo
        fan = [(round(T0 + delay, 3), 1, 0.02, round(-0.97 + 1.94 * j / 27, 3), round(3.2 * k, 2)) for j in range(28)]
        L.append(dict(name=f"AirFront{w}", texture="fx_glow", direction="Front", speed_len=(0.985 / TW, 1.015 / TW),
                      lifetime=(TW, TW + 0.02), size=[(0, 2), (0.25, round(7.5 * k, 1)), (1, round(13 * k, 1))],
                      transparency=[(0, 0.45), (0.15, 0.25), (0.85, 0.4), (1, 1)], color=WALL,
                      light_emission=0.45, brightness=1.2, zoffset=1, cone_emit=fan))
        lines = [(round(T0 + delay + g.uniform(0, 0.02), 3), 1, 0.02, round(g.uniform(-0.95, 0.95), 3),
                  round(g.uniform(1.0, 6.0) * k, 2)) for _ in range(int(round(16 * k)))]
        L.append(dict(name=f"AirLines{w}", texture="kk_trace_07", orientation="VelocityParallel", direction="Front",
                      speed_len=(0.95 / TW, 1.02 / TW), lifetime=(TW, TW + 0.02),
                      size=[(0, 4), (0.3, round(12 * k, 1)), (1, round(16 * k, 1))],
                      transparency=[(0, 0.3), (0.8, 0.45), (1, 1)], color=GUST, light_emission=0.6,
                      brightness=1.35, zoffset=1.5, cone_emit=sorted(lines)))
        n_g = int(round(10 * k))
        gusts += _ce(_cone_samples(g, 0.05, 1.0, n_g, 2, 4, (0.8, 7.0 * k), delay))
        thin += _ce(_cone_samples(g, 0.05, 1.0, n_g, 1, 2, (0.6, 5.0 * k), delay + 0.02))
        dust += _ce(_cone_samples(g, 0.06, 1.0, int(round(12 * k)), 2, 4, (1.2, 3.5), delay))
    L.append(dict(name="Gust", texture="kk_trace_07", orientation="VelocityParallel", direction="Front",
                  spread=(3, 3), speed=(60, 95), drag=3, lifetime=(0.2, 0.32),
                  size=[(0, 12, 2), (0.5, 20, 3), (1, 12)], transparency=[(0, 0.15), (0.6, 0.35), (1, 1)],
                  color=GUST, light_emission=0.5, brightness=1.3, cone_emit=sorted(gusts)))
    L.append(dict(name="GustThin", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
                  spread=(2, 2), speed=(90, 130), drag=3, lifetime=(0.15, 0.22),
                  size=[(0, 14), (1, 22)], color=WHITE, light_emission=1.0, brightness=1.6, cone_emit=sorted(thin)))
    # el polvo que empuja cada ola (rueda hacia adelante y se frena)
    for k, tex in enumerate(("kk_smoke_07", "kk_smoke_04")):
        L.append(dict(name=f"DustWall{k}", texture=tex, direction="Front", spread=(12, 12),
                      speed=(30, 48), drag=2.6, accel=(0, 2, 0), lifetime=(0.6, 0.95),
                      size=[(0, 4, 1), (0.3, 11, 2), (1, 15, 2)],
                      transparency=[(0, 0.45), (0.2, 0.3), (0.7, 0.6), (1, 1)], color=DUST,
                      light_emission=0.08, brightness=1.0, rotation=(0, 360), rot_speed=(-60, 60), zoffset=-1,
                      cone_emit=sorted(dust[k::2])))
    # bordes del triángulo (solo la primera ola)
    edges = [(_front(u), 1, round(u, 3), sd, 1.0) for u in [0.05 + 0.95 * i / 12 for i in range(13)]
             for sd in (-0.97, 0.97)]
    L.append(dict(name="EdgeStreaks", texture="kk_trace_07", orientation="VelocityParallel", direction="Front",
                  spread=(1, 1), speed=(55, 80), drag=3, lifetime=(0.22, 0.3),
                  size=[(0, 14, 2), (1, 18, 2)], transparency=[(0, 0.05), (0.6, 0.3), (1, 1)], color=GUST,
                  light_emission=0.8, brightness=1.5, cone_emit=edges))
    return L


def destruction_layers(g):
    """La primera ola rompe el suelo: rocas que salen volando, esquirlas, estallidos de polvo, grietas
    de luz y marcas oscuras."""
    L = []
    # rocas de verdad (Parts) arrancadas del suelo: salen hacia adelante y arriba con estela cósmica
    rocks = _cone_samples(g, 0.12, 1.0, 13, 1, 1, (0.6, 1.2), dt=(0.0, 0.03), s_max=0.8)
    L.append(dict(name="Rocks", type="meteor", direction="Front", pitch=50, spread=(22, 22),
                  speed=(45, 75), accel=(0, -115, 0), drag=0.3, lifetime=(1.2, 1.6),
                  sprite={"texture": "kz_debris_2x2", "layout": "Grid2x2", "size": (3.0, 5.5),
                          "rot_speed": (-480, 480), "color": (66, 58, 88)},
                  trails=[
                      {"name": "RockStardust", "rate": 34, "texture": "fx_spark002", "speed": (0, 2),
                       "direction": "Top", "spread": (180, 180), "lifetime": (0.25, 0.45),
                       "size": [(0, 0), (0.2, 2.2, 0.6), (1, 0)], "color": ROCK_TRAIL,
                       "light_emission": 1.0, "brightness": 1.8, "rotation": (0, 45)},
                      {"name": "RockDustTrail", "rate": 26, "texture": "kk_smoke_04", "speed": (1, 3),
                       "direction": "Top", "spread": (180, 180), "drag": 2, "accel": (0, 4, 0),
                       "lifetime": (0.45, 0.7), "size": [(0, 2.2, 0.6), (1, 6, 1.5)],
                       "transparency": [(0, 0.4), (0.6, 0.6), (1, 1)], "color": DUST, "rotation": (0, 360)},
                  ],
                  land=[
                      {"name": "RockLandDust", "emit": [(0, 4)], "texture": "kk_smoke_04", "direction": "Top",
                       "spread": (75, 75), "speed": (8, 16), "drag": 3, "accel": (0, 4, 0),
                       "lifetime": (0.5, 0.8), "size": [(0, 2.5, 0.8), (0.4, 6.5, 1.2), (1, 8, 1.2)],
                       "transparency": [(0, 0.35), (0.6, 0.55), (1, 1)], "color": DUST, "rotation": (0, 360)},
                      {"name": "RockLandSpark", "emit": [(0, 3)], "texture": "fx_spark002", "direction": "Top",
                       "spread": (80, 80), "speed": (4, 10), "drag": 3, "lifetime": (0.2, 0.35),
                       "size": [(0, 0), (0.2, 2.6), (1, 0)], "color": STAR, "light_emission": 1.0,
                       "brightness": 1.8},
                  ],
                  cone_emit=_ce(rocks, up=1.0)))
    # esquirlas pequeñas (partículas) que saltan en abanico con la ola
    chips = _cone_samples(g, 0.08, 1.0, 13, 2, 4, (0.6, 1.4))
    L.append(dict(name="Chips", texture="kz_debris_2x2", flipbook=STATIC2x2, direction="Front", pitch=40,
                  spread=(25, 25), speed=(35, 70), accel=(0, -95, 0), drag=0.6, lifetime=(0.7, 1.1),
                  size=[(0, 1.4, 0.5), (1, 1.2, 0.4)], color=[(0, (80, 72, 104)), (1, (66, 58, 88))],
                  rotation=(0, 360), rot_speed=(-400, 400), cone_emit=_ce(chips, n=2)))
    # estallidos de polvo donde se rompen las rocas
    bursts = _cone_samples(g, 0.15, 1.0, 7, 1, 1, (1.0, 1.5), s_max=0.75)
    L.append(dict(name="RockBurst", texture="kk_smoke_07", direction="Top", spread=(55, 55),
                  speed=(14, 26), drag=3, accel=(0, 4, 0), lifetime=(0.7, 1.0),
                  size=[(0, 4, 1), (0.3, 10, 2), (1, 13, 2)], transparency=[(0, 0.35), (0.25, 0.3), (0.7, 0.6), (1, 1)],
                  color=DUST, light_emission=0.05, rotation=(0, 360), rot_speed=(-50, 50),
                  cone_emit=_ce(bursts, n=4)))
    L.append(dict(name="RockFlash", texture="fx_spark002", lifetime=(0.16, 0.2),
                  size=[(0, 4), (0.3, 12), (1, 0)], color=CORE, light_emission=1.0, brightness=1.8,
                  rotation=(0, 45), zoffset=2, cone_emit=_ce(bursts, up=2.0)))
    # suelo roto: marcas oscuras que quedan y grietas de luz cósmica
    scars = [(_front(u), 1, u, round(g.uniform(-0.55, 0.55), 2), 0.15)
             for u in (0.22, 0.34, 0.46, 0.58, 0.7, 0.82, 0.94)]
    L.append(dict(name="GroundScar", decal=True, texture="kz_scorch", orientation="VelocityPerpendicular",
                  direction="Top", speed=(0.01, 0.01), lifetime=(2.6, 2.6),
                  size=[(0, 5), (0.05, 13), (1, 14)], transparency=[(0, 0.45), (0.75, 0.55), (1, 1)],
                  color=SCAR, rotation=(0, 360), zoffset=-1, cone_emit=scars))
    cracks = [(_front(u), 1, u, round(g.uniform(-0.6, 0.6), 2), 0.25)
              for u in (0.12, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.97)]
    L.append(dict(name="GroundCracks", decal=True, texture="kk_spark_02", orientation="VelocityPerpendicular",
                  direction="Top", speed=(0.01, 0.01), lifetime=(1.1, 1.1),
                  size=[(0, 12), (0.1, 26), (1, 28)], transparency=[(0, 0.15), (0.6, 0.45), (1, 1)],
                  color=CRACK, light_emission=0.9, rotation=(0, 360), cone_emit=cracks))
    bands = (((0.08, 0.16, 0.24), 14), ((0.32, 0.4, 0.48), 22), ((0.56, 0.64, 0.72), 30), ((0.8, 0.88, 0.96), 38))
    for k, (us, size) in enumerate(bands):
        evs = []
        for u in us:
            n = 1 + int(round(3 * u))
            for j in range(n):
                sj = 0.0 if n == 1 else -0.7 + 1.4 * j / (n - 1)
                evs.append((_front(u), 1, u, round(sj, 3), 0.25))
        L.append(dict(name=f"GroundGlow{k}", decal=True, texture="fx_glow", orientation="VelocityPerpendicular",
                      direction="Top", speed=(0.01, 0.01), lifetime=(1.3, 1.3),
                      size=[(0, size * 0.3), (0.12, size), (1, size * 1.05)],
                      transparency=[(0, 0.7), (0.15, 0.55), (1, 1)], color=GLOW_P if k % 2 == 0 else NEB_B,
                      light_emission=0.5, zoffset=-0.5, cone_emit=evs))
    return L


def field_layers(g):
    """Detrás de las olas: nebulosa, estrellas y polvo que quedan suspendidos (el campo que frena)."""
    L = []
    neb = _cone_samples(g, 0.12, 1.0, 9, 1, 3, (2.0, 9.0), delay=0.08, s_max=0.85)
    for k, (tex, col) in enumerate((("fx_fog3001", NEB_P), ("fx_fog2001", NEB_B))):
        L.append(dict(name=f"Nebula{k}", texture=tex, direction="Front", spread=(30, 30),
                      speed=(1.5, 4), drag=1.2, accel=(0, 0.6, 0), lifetime=(1.6, 2.1),
                      size=[(0, 6, 1), (0.25, 15, 2), (1, 19, 2)],
                      transparency=[(0, 0.85), (0.15, 0.6), (0.65, 0.72), (1, 1)], color=col,
                      light_emission=0.3, brightness=1.2, rotation=(0, 360), rot_speed=(-12, 12), zoffset=-2,
                      cone_emit=_ce(neb[k::2])))
    stars = _cone_samples(g, 0.1, 1.0, 10, 2, 4, (1.0, 12.0), dt=(0.05, 0.35))
    L.append(dict(name="Stars", texture="kk_star_06", direction="Top", spread=(180, 180),
                  speed=(0.5, 2), drag=1.5, lifetime=(1.0, 1.8), size=TWINKLE, color=STAR,
                  light_emission=1.0, brightness=2.0, rotation=(0, 30), zoffset=1, cone_emit=_ce(stars)))
    motes = _cone_samples(g, 0.08, 1.0, 12, 3, 6, (0.5, 10.0), dt=(0.05, 0.3))
    L.append(dict(name="Stardust", texture="fx_particle02", direction="Top", spread=(180, 180),
                  speed=(0.5, 2), drag=1, accel=(0, 0.8, 0), lifetime=(1.2, 2.0),
                  size=[(0, 0), (0.1, 0.9, 0.3), (0.8, 0.7), (1, 0)], color=WHITE,
                  light_emission=1.0, brightness=1.8, cone_emit=_ce(motes)))
    eddies = _cone_samples(g, 0.2, 1.0, 4, 1, 1, (3.0, 7.0), delay=0.3, s_max=0.6)
    L.append(dict(name="Eddies", texture="fx_wind_swirl", lifetime=(0.8, 1.1),
                  size=[(0, 6), (0.3, 12), (1, 14)], transparency=[(0, 0.7), (0.3, 0.5), (1, 1)],
                  color=WIND2, light_emission=0.6, brightness=1.3, rotation=(0, 360), rot_speed=(-90, -60),
                  cone_emit=_ce(eddies)))
    blink = [(round(g.uniform(0.55, 1.9), 3), 1, round(g.uniform(0.15, 1.0), 3), round(g.uniform(-0.85, 0.85), 3),
              round(g.uniform(1.0, 10.0), 2)) for _ in range(22)]
    L.append(dict(name="Blink", texture="fx_spark002", lifetime=(0.22, 0.3),
                  size=[(0, 0), (0.3, 4.5), (1, 0)], color=STAR, light_emission=1.0, brightness=2.2,
                  rotation=(0, 45), cone_emit=sorted(blink)))
    return L


def astral_clash_spec():
    g = random.Random(11)
    L = clash_layers() + air_wave_layers(g) + destruction_layers(g) + field_layers(g)
    return {
        "name": "AstralClash",
        "doc": ("ASTRAL COLOSSUS H1: la lanza choca con el escudo y lanza tres olas de aire cósmicas en TRIÁNGULO "
                "que rompen el suelo y arrancan rocas; deja un campo de nebulosa y estrellas suspendidas "
                "(el tiempo se frena). AstralColossusVFX.AstralClash(cf, largo, angulo, escala, sacudida): "
                "cf = vértice del triángulo en el suelo, mirando hacia adelante."),
        "duration": 2.6,
        "cone": {"length": 70, "angle": 55, "wave": [T0, TW]},
        "shakes": [(0.0, 1.2, 0.6), (0.13, 0.7, 0.4), (0.26, 0.5, 0.4)],
        "light": {"color": (150, 120, 255), "brightness": 5, "range": 45, "time": 0.9},
        "layers": L,
    }


ASTRAL_CLASH = astral_clash_spec()
SPECS = {"AstralClash": ASTRAL_CLASH}
