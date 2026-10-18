"""KAIJU ZERO — ULTIMATE: RAYO CARMESÍ (3 s).

La boca junta energía un instante (chispas y aros que se cierran) y suelta un RAYO CARMESÍ con el núcleo
al rojo blanco, envuelto en energía con vetas de lava que corre hacia el rival. En la boca queda un
estallido de destellos y aros que se abren; a lo largo del rayo pasan aros finos, brasas, gotas de lava y
humo rojo. Donde pega (el rival, o la primera superficie que encuentre) revienta un impacto: destellos,
ondas, chispas, lava, escombros de roca y rocas fundidas que salen volando; el suelo debajo se quema y se
agrieta en carmesí. A los 3 s el rayo se corta, se adelgaza y se apaga.
SE PUEDE APUNTAR: cada cuadro mira hacia donde apunta (el rival, o lo que le digas con rayo:AimAt) y se corta en
la primera superficie que toca, hasta 186 studs × escala (1.5 veces el largo con el que se presentó). El impacto
y las marcas del suelo siguen al punto donde pega; si barre el suelo, deja una estela quemada; cada vez que
vuelve a pegar después de ir por el aire, revienta de nuevo.
Origen = la boca; el rayo mira hacia -Z. line_u: 0 = boca, 1 = la punta (donde pega). impact = solo mientras
pega; on_hit = ráfagas cada vez que empieza a pegar (emit relativo); trail = marcas que van quedando en el suelo.
"""
STATIC2x2 = ("Grid2x2", "Random", 0, True)
DECAL = dict(decal=True, orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))

START, GROW, STOP, FADE = 0.3, 0.1, 3.3, 0.3        # sale, tarda en llegar al rival, se corta, se apaga
HIT = START + GROW                                   # el rayo llega al rival
ON = STOP - 0.02                                     # hasta aquí emite todo lo continuo

# ----------------------------------------------------------------------------- colores (carmesí)
WHITE_HOT = [(0, (255, 248, 244)), (1, (255, 236, 232))]
HOT = [(0, (255, 240, 236)), (0.25, (255, 120, 120)), (0.6, (235, 40, 62)), (1, (170, 14, 36))]
CRIMSON = [(0, (255, 92, 104)), (0.5, (225, 28, 52)), (1, (160, 10, 32))]
DEEP = [(0, (230, 30, 55)), (1, (170, 10, 32))]
SPARK = [(0, (255, 236, 232)), (0.4, (255, 96, 104)), (1, (210, 22, 46))]
EMBER = [(0, (255, 200, 196)), (0.4, (255, 70, 84)), (1, (190, 14, 38))]
FLAME = [(0, (255, 236, 230)), (0.2, (255, 116, 116)), (0.55, (228, 32, 56)), (1, (120, 10, 26))]
LAVA = [(0, (255, 170, 160)), (0.25, (255, 70, 80)), (0.6, (205, 20, 44)), (1, (120, 12, 28))]
ROCK = [(0, (255, 140, 130)), (1, (240, 100, 96))]           # la textura pone la costra oscura y las grietas
SMOKE = [(0, (215, 52, 62)), (0.3, (175, 40, 52)), (0.7, (135, 40, 50)), (1, (112, 58, 64))]    # humo rojo
SMOKE_DARK = [(0, (190, 42, 52)), (0.4, (125, 34, 42)), (1, (86, 46, 50))]
DUST = [(0, (150, 50, 50)), (0.4, (122, 60, 60)), (1, (105, 80, 80))]
FADE_IO = [(0, 1), (0.12, 0.3), (0.75, 0.4), (1, 1)]

IMPACT = dict(line_u=1.0, offset=(0, 0, 3), impact=True)   # en el impacto, un poco hacia la boca (no dentro del rival)
TIP = dict(line_u=1.0, offset=(0, 0, 3))            # en la punta, pegue o no (el resoplido final)
ALONG = dict(line_u=0.5)                             # cajas a lo largo de todo el rayo (Box con len_k)


def along_box(w, k=0.92):
    return {"type": "Box", "size": (w, w, 1), "len_k": k}


# ----------------------------------------------------------------------------- el rayo (Beams)
WIDTH_T = [(0, 0), (START, 0), (START + 0.03, 1.35), (START + 0.15, 1.0), (STOP - 0.05, 1.0), (STOP, 0.85),
           (STOP + FADE, 0)]
ALPHA_T = [(0, 0), (STOP, 0), (STOP + FADE, 1)]


def beam(name, texture, width, color, transparency, le, bright, tex_len, speed, pulse, hz, z, mode="Wrap"):
    return {"name": name, "texture": texture, "mode": mode, "tex_len": tex_len, "speed": speed,
            "light_emission": le, "brightness": bright, "color": color, "transparency": transparency,
            "width": width, "w0": 1.0, "w1": 1.0, "width_t": WIDTH_T, "alpha_t": ALPHA_T,
            "pulse": pulse, "pulse_hz": hz, "zoffset": z}


BEAMS = [
    # resplandor ancho (aditivo y tenue: sobre el cielo azul no se vuelve rosa)
    beam("Glow", "kz_beam_glow", 42, [(0, (200, 10, 34)), (1, (180, 8, 30))],
         [(0, 0.84), (0.03, 0.76), (1, 0.78)], 1.0, 0.8, 60, 0.4, 0.1, 5, 0.0),
    # lenguas de energía por fuera: la misma textura más ancha, tenue y más rápida (el borde hierve)
    beam("Wisps", "kz_beam_flow", 30, [(0, (205, 14, 36)), (1, (190, 10, 32))],
         [(0, 0.8), (0.05, 0.52), (1, 0.56)], 0.15, 1.4, 48, 2.4, 0.1, 6, 0.05),
    # la energía que envuelve el rayo: vetas de lava que corren hacia el rival (casi opaca: carmesí de verdad)
    beam("Sheath", "kz_beam_flow", 22, [(0, (190, 8, 28)), (1, (175, 6, 26))],
         [(0, 0.4), (0.04, 0.04), (1, 0.06)], 0.06, 1.5, 36, 1.6, 0.07, 7, 0.1),
    beam("Inner", "kz_beam_flow", 12, [(0, (255, 52, 70)), (1, (245, 40, 60))],
         [(0, 0.35), (0.04, 0.0), (1, 0.05)], 0.45, 1.8, 24, 2.6, 0.09, 11, 0.2),
    # núcleo al rojo blanco
    beam("Core", "kz_beam_core", 6.5, WHITE_HOT, [(0, 0.2), (0.03, 0.0), (1, 0.0)], 1.0, 2.4, 18, 3.5, 0.12, 17, 0.3),
]

# ----------------------------------------------------------------------------- partículas
LAYERS = [
    # ---------------- la carga (0 – 0.3 s): chispas y aros que se cierran sobre la boca ----------------
    dict(name="ChargeGlow", texture="fx_glow", emit=[(0.0, 1)], offset=(0, 0, -1), lifetime=(0.34, 0.34),
         size=[(0, 4), (0.85, 24), (1, 32)], transparency=[(0, 0.6), (0.8, 0.15), (1, 1)],
         color=[(0, (255, 70, 86)), (0.7, (255, 150, 150)), (1, (255, 236, 232))], light_emission=1.0,
         brightness=1.4, zoffset=2),
    dict(name="ChargeIn", texture="kk_trace_01", orientation="VelocityParallel", offset=(0, 0, -1),
         shape={"type": "Sphere", "radius": 18.0, "style": "Surface", "inout": "Inward"}, speed=(62, 82),
         lifetime=(0.2, 0.26), size=[(0, 0), (0.3, 11, 2), (1, 3)], color=SPARK, light_emission=1.0,
         brightness=2.0, stream=[(0.0, 0.27, 110, 150)]),
    dict(name="ChargeSparks", texture="fx_spark4", offset=(0, 0, -1),
         shape={"type": "Sphere", "radius": 14.0, "style": "Surface", "inout": "Inward"}, speed=(45, 60),
         lifetime=(0.2, 0.26), size=[(0, 0), (0.3, 3.2, 0.8), (1, 1)], color=SPARK, light_emission=1.0,
         brightness=2.0, rotation=(0, 360), stream=[(0.0, 0.27, 50, 70)]),
    dict(name="ChargeRings", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -1), speed=(0.5, 0.5), lifetime=(0.22, 0.22), size=[(0, 26), (1, 3)],
         transparency=[(0, 1), (0.35, 0.3), (1, 0.15)], color=[(0, (220, 24, 50)), (1, (255, 200, 200))],
         light_emission=1.0, brightness=1.6, rotation=(0, 360), stream=[(0.0, 0.24, 14, 18)]),
    # ---------------- la boca: estallido de destellos y aros que se abren ----------------
    dict(name="MouthFlash", texture="fx_glow", emit=[(START, 1)], offset=(0, 0, -2), lifetime=(0.3, 0.3),
         size=[(0, 18), (0.25, 44), (1, 48)], transparency=[(0, 0.15), (0.5, 0.6), (1, 1)], color=HOT,
         light_emission=1.0, brightness=1.0, zoffset=4),
    dict(name="MouthBurst", texture="fx_star", emit=[(START, 3)], offset=(0, 0, -2), lifetime=(0.18, 0.24),
         size=[(0, 24), (0.3, 52), (1, 36)], transparency=[(0, 0), (0.6, 0.3), (1, 1)], color=HOT,
         light_emission=1.0, brightness=1.7, rotation=(0, 360), zoffset=5),
    dict(name="MouthStar", texture="fx_star", offset=(0, 0, -2), lifetime=(0.1, 0.16),
         size=[(0, 28, 6), (0.5, 38, 7), (1, 28, 6)], transparency=[(0, 0.2), (0.6, 0.3), (1, 1)], color=HOT,
         light_emission=1.0, brightness=1.3, rotation=(0, 360), zoffset=5, stream=[(START, ON, 16, 16)]),
    dict(name="MouthStarCore", texture="kk_star_06", offset=(0, 0, -2), lifetime=(0.08, 0.12),
         size=[(0, 14, 3), (0.5, 18, 3), (1, 14, 3)], transparency=[(0, 0), (0.6, 0.2), (1, 1)],
         color=[(0, (255, 248, 244)), (0.5, (255, 140, 140)), (1, (230, 40, 60))], light_emission=1.0,
         brightness=1.6, rotation=(0, 360), zoffset=6, stream=[(START, ON, 12, 12)]),
    dict(name="MouthGlow", texture="fx_glow", offset=(0, 0, -2), lifetime=(0.15, 0.2),
         size=[(0, 26, 3), (1, 32, 3)], transparency=[(0, 0.55), (1, 0.8)], color=DEEP, light_emission=1.0,
         brightness=1.0, zoffset=3, stream=[(START, ON, 12, 12)]),
    dict(name="MouthRings", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -2), speed=(14, 26), drag=2, lifetime=(0.32, 0.46), size=[(0, 8), (0.4, 26), (1, 38)],
         transparency=[(0, 0.05), (0.5, 0.35), (1, 1)], color=HOT, light_emission=1.0, brightness=1.6,
         rotation=(0, 360), stream=[(START + 0.02, ON, 8, 8)]),
    dict(name="MouthSwirl", texture="kk_twirl_01", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -3), speed=(3, 5), lifetime=(0.25, 0.35), size=[(0, 16), (1, 30)],
         transparency=[(0, 0.4), (0.4, 0.3), (1, 1)], color=CRIMSON, light_emission=1.0, brightness=1.5,
         rotation=(0, 360), rot_speed=(380, 560), stream=[(START + 0.02, ON, 9, 9)]),
    dict(name="MouthSparks", texture="kk_trace_01", orientation="VelocityParallel", direction="Front",
         offset=(0, 0, -2), spread=(55, 55), speed=(70, 130), drag=3, lifetime=(0.2, 0.35),
         size=[(0, 10, 2), (1, 3)], color=SPARK, light_emission=1.0, brightness=1.8,
         stream=[(START + 0.02, ON, 50, 50)]),
    dict(name="MouthSmoke", texture="fx_smoke_2x2", flipbook=STATIC2x2, offset=(0, 2, -3), direction="Top",
         spread=(40, 40), speed=(6, 12), drag=1.5, accel=(0, 10, 0), lifetime=(0.9, 1.3), size=[(0, 6, 2), (1, 20, 4)],
         transparency=[(0, 1), (0.15, 0.62), (0.5, 0.72), (1, 1)], color=SMOKE, light_emission=0.1, brightness=1.2,
         rotation=(0, 360), rot_speed=(-25, 25), zoffset=-3, stream=[(HIT, ON, 7, 7)]),
    # ---------------- la punta del rayo: un destello que va con ella mientras crece ----------------
    dict(name="BeamHead", texture="fx_glow", line_u=1.0, lifetime=(0.05, 0.07), size=[(0, 20), (1, 24)],
         transparency=[(0, 0.15), (1, 0.4)], color=[(0, (255, 236, 232)), (1, (255, 120, 120))], light_emission=1.0,
         brightness=1.4, zoffset=4, stream=[(START, START + GROW + 0.03, 70, 70)]),
    dict(name="BeamHeadStar", texture="kk_star_06", line_u=1.0, lifetime=(0.05, 0.07), size=[(0, 24), (1, 28)],
         transparency=[(0, 0), (1, 0.3)], color=HOT, light_emission=1.0, brightness=1.6, rotation=(0, 360), zoffset=5,
         stream=[(START, START + GROW + 0.03, 40, 40)]),
    # ---------------- a lo largo del rayo: aros, brasas, rayas de energía, gotas de lava y humo rojo ----------------
    dict(name="TravelRings", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -3), speed_len=(1.7, 2.1), lifetime=(0.4, 0.45), size=[(0, 26), (0.5, 30), (1, 27)],
         transparency=FADE_IO, color=[(0, (255, 170, 170)), (0.3, (250, 64, 80)), (1, (215, 24, 48))],
         light_emission=1.0, brightness=1.5, rotation=(0, 360), stream=[(HIT + 0.02, STOP - 0.05, 9, 9)]),
    dict(name="TravelRingsBig", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -3), speed_len=(0.8, 1.0), lifetime=(0.85, 0.95), size=[(0, 34), (0.5, 38), (1, 35)],
         transparency=[(0, 1), (0.12, 0.45), (0.75, 0.55), (1, 1)], color=CRIMSON, light_emission=1.0,
         brightness=1.4, rotation=(0, 360), stream=[(HIT + 0.02, STOP - 0.6, 3.5, 3.5)]),
    dict(name="BeamEmbers", texture="kk_flare_01", shape=along_box(7), direction="Top", spread=(180, 180),
         speed=(6, 22), drag=1, accel=(0, 12, 0), lifetime=(0.4, 0.8), size=[(0, 0), (0.15, 2.4, 0.6), (1, 0)],
         color=EMBER, light_emission=1.0, brightness=1.8, stream=[(HIT, ON, 70, 70)], **ALONG),
    dict(name="BeamStreaks", texture="kk_trace_01", orientation="VelocityParallel",
         shape={"type": "Box", "size": (8, 8, 1), "len_k": 0.76}, line_u=0.42, direction="Front",
         spread=(4, 4), speed_len=(1.6, 2.2), lifetime=(0.07, 0.1), size=[(0, 12, 3), (1, 7)], color=SPARK,
         light_emission=1.0, brightness=1.6, stream=[(HIT, ON, 45, 45)]),
    dict(name="BeamLava", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, shape=along_box(6, 0.9),
         direction="Top", spread=(180, 180), speed=(4, 14), drag=0.4, accel=(0, -90, 0), lifetime=(0.5, 0.8),
         size=[(0, 1.0, 0.3), (0.3, 2.1, 0.5), (1, 1.2, 0.3)], transparency=[(0, 0), (0.75, 0.05), (1, 1)],
         color=LAVA, light_emission=0.5, brightness=1.6, rotation=(0, 360), rot_speed=(-200, 200),
         stream=[(HIT + 0.05, ON, 22, 22)], **ALONG),
    dict(name="BeamSmoke", texture="kk_smoke_08", shape=along_box(12, 0.9), direction="Top",
         spread=(60, 60), speed=(3, 8), drag=1, accel=(0, 6, 0), lifetime=(0.8, 1.1), size=[(0, 8, 2), (1, 22, 4)],
         transparency=[(0, 1), (0.15, 0.5), (0.6, 0.62), (1, 1)], color=SMOKE_DARK, light_emission=0.1, brightness=1.2,
         rotation=(0, 360), rot_speed=(-20, 20), zoffset=-6, stream=[(HIT + 0.05, ON, 14, 14)], **ALONG),
    # ---------------- el impacto ----------------
    dict(name="ImpactFlash", texture="fx_glow", emit=[(0, 1)], on_hit=True, lifetime=(0.3, 0.3),
         size=[(0, 20), (0.25, 60), (1, 66)], transparency=[(0, 0.1), (0.5, 0.55), (1, 1)], color=HOT,
         light_emission=1.0, brightness=1.1, zoffset=4, **IMPACT),
    dict(name="ImpactBurst", texture="fx_burst_a", emit=[(0, 2)], on_hit=True, lifetime=(0.2, 0.24),
         size=[(0, 16), (0.4, 50), (1, 56)], transparency=[(0, 0), (0.5, 0.35), (1, 1)], color=FLAME,
         light_emission=0.6, brightness=1.6, rotation=(0, 360), zoffset=3, **IMPACT),
    dict(name="ImpactShock", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Back",
         emit=[(0, 2)], on_hit=True, speed=(0.5, 0.5), lifetime=(0.32, 0.4), size=[(0, 12), (1, 80)],
         transparency=[(0, 0), (0.5, 0.3), (1, 1)], color=HOT, light_emission=1.0, brightness=1.7,
         rotation=(0, 360), **IMPACT),
    dict(name="ImpactRings", texture="kz_beam_ring", orientation="VelocityPerpendicular", direction="Back",
         speed=(6, 14), lifetime=(0.3, 0.4), size=[(0, 10), (1, 46)], transparency=[(0, 0.1), (0.5, 0.4), (1, 1)],
         color=HOT, light_emission=1.0, brightness=1.6, rotation=(0, 360), stream=[(HIT + 0.02, ON, 7, 7)],
         **IMPACT),
    dict(name="ImpactStar", texture="fx_star", lifetime=(0.08, 0.14), size=[(0, 32, 6), (0.5, 42, 8), (1, 30, 6)],
         transparency=[(0, 0.1), (0.6, 0.3), (1, 1)], color=HOT, light_emission=1.0, brightness=1.4,
         rotation=(0, 360), zoffset=4, stream=[(HIT, ON, 15, 15)], **IMPACT),
    dict(name="ImpactGlow", texture="fx_glow", lifetime=(0.15, 0.22), size=[(0, 36, 4), (1, 42, 4)],
         transparency=[(0, 0.55), (1, 0.8)], color=DEEP, light_emission=1.0, brightness=1.0, zoffset=2,
         stream=[(HIT, ON, 10, 10)], **IMPACT),
    dict(name="ImpactFire", texture="fx_fire_2x2", flipbook=STATIC2x2, direction="Back", spread=(75, 75),
         speed=(12, 30), drag=2.5, accel=(0, 14, 0), lifetime=(0.3, 0.5), size=[(0, 8, 2), (0.4, 18, 3), (1, 22, 3)],
         transparency=[(0, 0.05), (0.6, 0.25), (1, 1)], color=FLAME, light_emission=0.35, brightness=1.6,
         rotation=(0, 360), rot_speed=(-90, 90), stream=[(HIT, ON, 26, 26)], **IMPACT),
    dict(name="ImpactSpray", texture="kk_trace_01", orientation="VelocityParallel", direction="Back",
         spread=(80, 80), speed=(90, 170), drag=3.5, accel=(0, -70, 0), lifetime=(0.25, 0.45),
         size=[(0, 12, 3), (1, 4)], color=SPARK, light_emission=1.0, brightness=1.8,
         emit=[(0, 40)], on_hit=True, stream=[(HIT, ON, 75, 75)], **IMPACT),
    dict(name="ImpactLava", texture="kz_lava_glob_2x2", flipbook=STATIC2x2, direction="Back", spread=(70, 70),
         speed=(35, 75), drag=0.5, accel=(0, -130, 0), lifetime=(0.6, 0.9),
         size=[(0, 1.6, 0.4), (0.3, 3.0, 0.6), (1, 2.0, 0.4)], transparency=[(0, 0), (0.75, 0.05), (1, 1)],
         color=LAVA, light_emission=0.45, brightness=1.6, rotation=(0, 360), rot_speed=(-220, 220),
         emit=[(0, 20)], on_hit=True, stream=[(HIT, ON, 30, 30)], **IMPACT),
    dict(name="ImpactDebris", texture="kz_lava_rock_2x2", flipbook=STATIC2x2, direction="Back", spread=(70, 70),
         speed=(40, 90), drag=0.3, accel=(0, -130, 0), lifetime=(0.7, 1.1), size=[(0, 2.2, 0.8), (1, 1.9, 0.7)],
         color=ROCK, light_emission=0.1, brightness=1.5, rotation=(0, 360), rot_speed=(-360, 360),
         emit=[(0, 16)], on_hit=True, stream=[(HIT, ON, 18, 18)], **IMPACT),
    dict(name="ImpactSmoke", texture="fx_smoke_2x2", flipbook=STATIC2x2, direction="Top", spread=(35, 35),
         speed=(10, 20), drag=1.2, accel=(0, 10, 0), lifetime=(1.0, 1.5), size=[(0, 10, 3), (1, 30, 5)],
         transparency=[(0, 0.6), (0.15, 0.32), (0.6, 0.45), (1, 1)], color=SMOKE, light_emission=0.1,
         brightness=1.2, rotation=(0, 360), rot_speed=(-25, 25), zoffset=-5, stream=[(HIT + 0.05, ON, 9, 9)], **IMPACT),
    # la energía del rayo se aplasta contra la superficie: chorros carmesí que se abren en abanico
    dict(name="ImpactSplash", texture="kk_muzzle_01", orientation="VelocityParallel", direction="Back",
         spread=(85, 85), speed=(40, 70), drag=4, lifetime=(0.16, 0.26), size=[(0, 6, 2), (0.3, 18, 4), (1, 14, 3)],
         transparency=[(0, 0.05), (0.6, 0.25), (1, 1)], color=FLAME, light_emission=0.5, brightness=1.6,
         stream=[(HIT, ON, 34, 34)], **IMPACT),
    # rocas fundidas (Parts con CrackedLava) que salen volando del impacto
    dict(name="ImpactRocks", type="meteor", emit=[(HIT + 0.02, 4), (1.3, 2), (2.0, 2)],
         direction="Back", spread=(55, 55), speed=(55, 95), accel=(0, -130, 0), drag=0.2, lifetime=(1.0, 1.3),
         sprite={"texture": "kz_lava_rock_2x2", "layout": "Grid2x2", "size": (2.6, 4.2), "rot_speed": (-480, 480),
                 "color": (140, 34, 38), "material": "CrackedLava",
                 "glow": {"texture": "fx_glow", "size_k": 2.0, "color": (230, 20, 45), "alpha": 0.32}},
         trails=[
             {"name": "RockGlow", "rate": 60, "locked": True, "texture": "fx_glow", "speed": (0, 0),
              "direction": "Top", "lifetime": (0.075, 0.075), "size": [(0, 6.5, 0.8), (1, 6.5, 0.8)],
              "color": [(0, (255, 30, 50)), (1, (255, 30, 50))], "transparency": [(0, 0.9), (1, 0.9)],
              "light_emission": 1.0, "brightness": 1.0},
             {"name": "RockEmbers", "rate": 30, "texture": "kk_flare_01", "speed": (0, 3), "direction": "Top",
              "spread": (180, 180), "lifetime": (0.25, 0.45), "size": [(0, 0), (0.15, 2.4, 0.6), (1, 0)],
              "color": EMBER, "light_emission": 1.0, "brightness": 1.7},
             {"name": "RockSmoke", "rate": 22, "texture": "kk_smoke_04", "speed": (1, 4), "direction": "Top",
              "spread": (180, 180), "drag": 2, "accel": (0, 6, 0), "lifetime": (0.5, 0.8),
              "size": [(0, 3, 0.8), (1, 9, 2)], "transparency": [(0, 0.4), (0.6, 0.6), (1, 1)],
              "color": SMOKE, "rotation": (0, 360)},
         ],
         land=[
             dict(name="RockSplat", texture="kz_lava_splat", emit=[(0, 1)], lifetime=(1.4, 1.4),
                  size=[(0, 2), (0.05, 7), (1, 7.5)], transparency=[(0, 0.1), (0.75, 0.3), (1, 1)],
                  color=[(0, (230, 60, 70)), (0.3, (170, 20, 40)), (1, (70, 12, 20))], light_emission=0.5,
                  rotation=(0, 360), **DECAL),
             dict(name="RockWisp", texture="kk_smoke_04", direction="Top", spread=(15, 15), speed=(4, 9),
                  drag=1.2, accel=(0, 5, 0), lifetime=(0.7, 1.0), size=[(0, 2, 0.6), (1, 7, 2)],
                  transparency=[(0, 0.6), (0.3, 0.5), (1, 1)], color=SMOKE, rotation=(0, 360),
                  stream=[(0.05, 0.7, 3, 0.5)]),
         ], **IMPACT),
    # el rayo se corta: último resoplido de humo y brasas en el impacto
    dict(name="CutPuff", texture="fx_smoke_2x2", flipbook=STATIC2x2, emit=[(STOP + 0.02, 8)], direction="Back",
         spread=(70, 70), speed=(14, 30), drag=2, accel=(0, 10, 0), lifetime=(0.9, 1.3), size=[(0, 8, 2), (1, 26, 5)],
         transparency=[(0, 0.6), (0.3, 0.55), (1, 1)], color=SMOKE, light_emission=0.1, brightness=1.2,
         rotation=(0, 360), rot_speed=(-30, 30), zoffset=-4, **TIP),
    dict(name="CutEmbers", texture="kk_flare_01", emit=[(STOP + 0.02, 40)], direction="Back", spread=(90, 90),
         speed=(20, 60), drag=2, accel=(0, 10, 0), lifetime=(0.5, 1.0), size=[(0, 0), (0.15, 2.6, 0.6), (1, 0)],
         color=EMBER, light_emission=1.0, brightness=1.8, **TIP),
    # ---------------- el suelo bajo el impacto: quemadura, grietas carmesí, polvo y fuego ----------------
    dict(name="GroundScorch", texture="kz_scorch", emit=[(0.02, 1)], on_hit=True, at_ground=True, offset=(0, 0.14, 0),
         lifetime=(4.0, 4.0), size=[(0, 8), (0.05, 40), (1, 44)], transparency=[(0, 0.15), (0.8, 0.25), (1, 1)],
         rotation=(0, 360), **DECAL),
    dict(name="GroundCracks", texture="kz_lava_cracks", emit=[(0.05, 1)], on_hit=True, at_ground=True,
         offset=(0, 0.18, 0), lifetime=(3.9, 3.9), size=[(0, 10), (0.06, 46), (1, 50)],
         transparency=[(0, 0.1), (0.7, 0.3), (1, 1)],
         color=[(0, (255, 120, 120)), (0.1, (240, 40, 62)), (0.6, (190, 18, 40)), (1, (90, 10, 22))],
         light_emission=1.0, rotation=(0, 360), **DECAL),
    dict(name="GroundDust", texture="kk_smoke_07", emit=[(0.02, 22)], on_hit=True, at_ground=True, offset=(0, 2, 0),
         direction="Front", spread=(180, 3), speed=(60, 100), drag=3.5, accel=(0, 4, 0), lifetime=(0.9, 1.3),
         size=[(0, 8, 2), (0.3, 18, 3), (1, 24, 4)], transparency=[(0, 0.5), (0.2, 0.35), (1, 1)], color=DUST,
         rotation=(0, 360), rot_speed=(-40, 40), zoffset=-3),
    dict(name="GroundFire", texture="kk_muzzle_04", orientation="VelocityParallel", at_ground=True,
         offset=(0, 0.5, 0), shape={"type": "Box", "size": (16, 0.5, 16)}, direction="Top", spread=(10, 10),
         speed=(4, 9), drag=2, lifetime=(0.3, 0.5), size=[(0, 2, 0.5), (0.3, 6, 1), (1, 4, 0.8)],
         transparency=[(0, 0.05), (0.6, 0.2), (1, 1)], color=FLAME, light_emission=0.4, brightness=1.6,
         stream=[(HIT + 0.1, ON, 12, 12)]),
    dict(name="GroundEmbers", texture="kk_flare_01", at_ground=True, offset=(0, 1, 0),
         shape={"type": "Box", "size": (18, 1, 18)}, direction="Top", spread=(20, 20), speed=(6, 16),
         accel=(0, 10, 0), lifetime=(0.6, 1.0), size=[(0, 0), (0.15, 2.2, 0.6), (1, 0)], color=EMBER,
         light_emission=1.0, brightness=1.8, stream=[(HIT + 0.1, ON, 16, 16)]),
    # la estela quemada que deja al barrer el suelo
    dict(name="TrailScorch", texture="kz_scorch", trail=True, at_ground=True, offset=(0, 0.12, 0), lifetime=(2.4, 2.4),
         size=[(0, 6), (0.08, 17), (1, 18)], transparency=[(0, 0.2), (0.75, 0.3), (1, 1)], rotation=(0, 360), **DECAL),
    dict(name="TrailCracks", texture="kz_lava_cracks", trail=True, at_ground=True, offset=(0, 0.16, 0),
         lifetime=(2.0, 2.0), size=[(0, 6), (0.1, 15), (1, 16)], transparency=[(0, 0.15), (0.6, 0.35), (1, 1)],
         color=[(0, (255, 120, 120)), (0.15, (240, 40, 62)), (0.6, (180, 16, 38)), (1, (80, 10, 20))],
         light_emission=1.0, rotation=(0, 360), **DECAL),
]

ULTIMATE_BEAM = {
    "name": "UltimateBeam",
    "doc": ("ULTIMATE de Kaiju Zero: la boca junta energía 0.3 s y suelta un RAYO CARMESÍ de 3 s con el núcleo al rojo "
            "blanco y vetas de lava, con aros, brasas y humo rojo. Se puede apuntar mientras dura: pega en la primera "
            "superficie (hasta 186 studs × escala) con destellos, chispas, lava y rocas fundidas, y el suelo debajo se "
            "quema y se agrieta (deja una estela si lo barre). Cierra limpio."),
    "duration": STOP + FADE,
    # max_len = largo máximo (studs × escala); trail_every / trail_move = cada cuánto y desde qué distancia deja
    # marcas al barrer el suelo; rehit = tiempo sin pegar antes de que un nuevo impacto vuelva a reventar
    "beam": {"start": START, "grow": GROW, "stop": STOP, "fade": FADE, "max_len": 186, "trail_every": 0.1,
             "trail_move": 4, "rehit": 0.3, "light_color": (255, 40, 62), "light_brightness": 5, "light_range": 50},
    "beams": BEAMS,
    "layers": LAYERS,
    "shake_ramp": (START, STOP, 0.3, 0.55, 1.0),
    "shakes": [(HIT, 1.0, 0.6), (STOP, 0.5, 0.4)],
}
