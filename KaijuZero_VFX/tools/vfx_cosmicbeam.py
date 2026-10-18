"""OMNÍVORA — RAYO CÓSMICO (3 s, se puede apuntar). Misma filosofía y colores que el Pilar cósmico y el Agujero
negro: azul muy oscuro que se aclara a celeste, destellos blancos y el púrpura de su boca acompañando.

La boca de Omnívora junta energía y estrellas (las devora) y suelta un RAYO de nebulosa: un cuerpo denso de azul muy
oscuro con venas celestes, manchas púrpura y estrellas, envuelto en hebras de energía celestes y púrpura, con el
núcleo blanco. En la boca gira un disco púrpura como el del agujero negro y se abren anillos; a lo largo del rayo
viajan anillos y remolinos (como los que trepan por el pilar), relámpagos, auroras, y deja una ESTELA CÓSMICA de
nebulosa y estrellas que se queda flotando cuando el rayo se mueve. Donde pega: destello, halo, ondas, la nebulosa
que estalla, estelas, cubitos que salen volando y grietas de luz en el suelo (y una estela de grietas si lo barre).
SE PUEDE APUNTAR igual que el de Kaiju Zero: se corta en la primera superficie que toca, hasta 124 studs × escala.
Capas: line_u 0 = boca, 1 = la punta; impact = solo mientras pega; on_hit = ráfagas cada vez que empieza a pegar
(emit relativo); at_ground = en el suelo bajo el impacto; trail = marcas que van quedando al barrer el suelo.
"""
from vfx_omnivora import (BOLT, CRACKC, DECAL, DEEPB, DUST, ENERGY, FLASH, INWARD, MOUTH, MOUTHG, NEBW, PINKS,
                          RINGC, SCORCH, SHOCK, STAR, STATIC2x2, STREAK, TWINKLE, VOIDC, WHITE)

START, GROW, STOP, FADE = 0.3, 0.1, 3.3, 0.3        # sale, tarda en llegar a su largo, se corta, se apaga
HIT = START + GROW
ON = STOP - 0.02                                     # hasta aquí emite todo lo continuo
MOUTH_AT = dict(offset=(0, 0, -2))
IMPACT = dict(line_u=1.0, offset=(0, 0, 3), impact=True)   # donde pega, un poco hacia la boca
TIP = dict(line_u=1.0, offset=(0, 0, 3))
ALONG = dict(line_u=0.5)
FADE_IO = [(0, 1), (0.12, 0.3), (0.75, 0.4), (1, 1)]
CUBEC = [(0, (150, 154, 168)), (1, (120, 124, 140))]


def along_box(w, k=0.92):
    return {"type": "Box", "size": (w, w, 1), "len_k": k}


# ----------------------------------------------------------------------------- el rayo (Beams)
WIDTH_T = [(0, 0), (START, 0), (START + 0.03, 1.3), (START + 0.15, 1.0), (STOP - 0.05, 1.0), (STOP, 0.85),
           (STOP + FADE, 0)]
ALPHA_T = [(0, 0), (STOP, 0), (STOP + FADE, 1)]


def beam(name, texture, width, color, transparency, le, bright, tex_len, speed, pulse, hz, z):
    return {"name": name, "texture": texture, "mode": "Wrap", "tex_len": tex_len, "speed": speed,
            "light_emission": le, "brightness": bright, "color": color, "transparency": transparency,
            "width": width, "w0": 1.0, "w1": 1.0, "width_t": WIDTH_T, "alpha_t": ALPHA_T,
            "pulse": pulse, "pulse_hz": hz, "zoffset": z}


BEAMS = [
    # halo azul alrededor (detrás de todo)
    beam("Aura", "om_beam_glow", 46, [(0, (40, 80, 210)), (1, (30, 60, 180))],
         [(0, 0.82), (0.03, 0.72), (1, 0.75)], 1.0, 0.8, 60, 0.4, 0.1, 5, 0.0),
    # el cuerpo: nebulosa densa de azul muy oscuro (la textura trae el color), deriva despacio hacia el rival
    beam("Body", "om_beam_nebula", 27, [(0, (255, 255, 255)), (1, (235, 240, 255))],
         [(0, 0.45), (0.04, 0.05), (1, 0.08)], 0.1, 1.0, 44, 0.9, 0.06, 6, 0.1),
    # hebras de energía celestes y púrpura que corren más rápido
    beam("Strands", "om_beam_flow", 21, [(0, (150, 210, 255)), (1, (110, 185, 255))],
         [(0, 0.5), (0.04, 0.3), (1, 0.35)], 0.9, 1.1, 30, 2.4, 0.08, 9, 0.2),
    beam("StrandsPurple", "om_beam_flow", 17, [(0, (220, 130, 255)), (1, (180, 80, 245))],
         [(0, 0.6), (0.04, 0.42), (1, 0.45)], 1.0, 1.1, 38, 1.5, 0.08, 7, 0.25),
    # polvo de estrellas dentro del rayo
    beam("Stars", "om_beam_stars", 19, [(0, (255, 255, 255)), (1, (200, 230, 255))],
         [(0, 0.4), (0.04, 0.1), (1, 0.15)], 1.0, 1.6, 40, 0.7, 0.05, 4, 0.3),
    # el núcleo blanco
    beam("Core", "om_beam_core", 4.2, [(0, (245, 250, 255)), (1, (205, 235, 255))],
         [(0, 0.3), (0.03, 0.05), (1, 0.05)], 1.0, 1.6, 18, 3.2, 0.12, 15, 0.35),
]

# ----------------------------------------------------------------------------- partículas
LAYERS = [
    # ---------------- la carga (0 – 0.3 s): la boca devora energía y estrellas ----------------
    dict(name="ChargeGather", texture="kk_trace_06", orientation="VelocityParallel",
         shape={"type": "Sphere", "radius": 18.0, "style": "Surface", "inout": "Inward"}, speed=(62, 80),
         lifetime=(0.22, 0.27), size=[(0, 1), (0.3, 6), (1, 2)], transparency=[(0, 0.6), (0.2, 0.1), (1, 0.3)],
         color=INWARD, light_emission=1.0, brightness=1.3, stream=[(0.0, 0.27, 100, 140)], **MOUTH_AT),
    dict(name="ChargeGatherPurple", texture="kk_trace_06", orientation="VelocityParallel",
         shape={"type": "Sphere", "radius": 15.0, "style": "Surface", "inout": "Inward"}, speed=(52, 66),
         lifetime=(0.22, 0.27), size=[(0, 1), (0.3, 5.5), (1, 2)], transparency=[(0, 0.6), (0.2, 0.1), (1, 0.3)],
         color=MOUTH, light_emission=1.0, brightness=1.5, stream=[(0.0, 0.27, 50, 70)], **MOUTH_AT),
    dict(name="ChargeMotes", texture="fx_particle02",
         shape={"type": "Sphere", "radius": 14.0, "style": "Surface", "inout": "Inward"}, speed=(45, 58),
         lifetime=(0.24, 0.3), size=[(0, 0), (0.2, 1.2, 0.3), (1, 0.5)], color=STAR, light_emission=1.0,
         brightness=1.8, stream=[(0.0, 0.27, 60, 80)], **MOUTH_AT),
    dict(name="ChargeGlow", texture="fx_glow", emit=[(0.0, 1)], lifetime=(0.34, 0.34),
         size=[(0, 4), (0.85, 22), (1, 30)], transparency=[(0, 0.6), (0.8, 0.2), (1, 1)],
         color=[(0, (150, 60, 240)), (0.6, (120, 190, 255)), (1, (235, 245, 255))], light_emission=1.0,
         brightness=1.3, zoffset=2, **MOUTH_AT),
    dict(name="ChargeSwirl", texture="fx_swirl_rings", orientation="VelocityPerpendicular", direction="Front",
         speed=(0.5, 0.5), lifetime=(0.26, 0.26), size=[(0, 30), (1, 6)], transparency=[(0, 1), (0.3, 0.35), (1, 0.3)],
         color=PINKS, light_emission=0.9, brightness=1.2, rotation=(0, 360), rot_speed=(-420, -360),
         stream=[(0.0, 0.24, 9, 12)], **MOUTH_AT),
    # ---------------- la boca: destello al disparar, disco púrpura que gira, anillos y relámpagos ----------------
    dict(name="MouthFlash", texture="fx_glow", emit=[(START, 1)], lifetime=(0.3, 0.3),
         size=[(0, 16), (0.25, 38), (1, 42)], transparency=[(0, 0.25), (0.5, 0.65), (1, 1)], color=FLASH,
         light_emission=1.0, brightness=0.85, zoffset=4, **MOUTH_AT),
    dict(name="MouthBurst", texture="kk_star_09", emit=[(START, 2)], lifetime=(0.26, 0.3),
         size=[(0, 20), (0.15, 50), (1, 14)], color=FLASH, light_emission=1.0, brightness=1.0, rotation=(0, 90),
         zoffset=5, **MOUTH_AT),
    dict(name="MouthHalo", texture="fx_halo", emit=[(START, 1)], lifetime=(0.32, 0.36),
         size=[(0, 10), (1, 60)], transparency=[(0, 0.3), (0.5, 0.6), (1, 1)], color=SHOCK, light_emission=1.0,
         brightness=1.1, rotation=(0, 360), zoffset=3, **MOUTH_AT),
    dict(name="MouthStar", texture="kk_star_08", lifetime=(0.1, 0.16), size=[(0, 20, 4), (0.5, 26, 5), (1, 20, 4)],
         transparency=[(0, 0.3), (0.6, 0.4), (1, 1)], color=FLASH, light_emission=1.0, brightness=0.9,
         rotation=(0, 360), zoffset=5, stream=[(START, ON, 14, 14)], **MOUTH_AT),
    dict(name="MouthGlow", texture="fx_glow", lifetime=(0.15, 0.2), size=[(0, 22, 3), (1, 28, 3)],
         transparency=[(0, 0.62), (1, 0.82)], color=DEEPB, light_emission=1.0, brightness=1.0, zoffset=3,
         stream=[(START, ON, 12, 12)], **MOUTH_AT),
    dict(name="MouthDisk", texture="fx_swirl_rings", orientation="VelocityPerpendicular", direction="Front",
         speed=(1, 1), lifetime=(0.4, 0.5), size=[(0, 18), (1, 26)], transparency=[(0, 1), (0.2, 0.4), (0.8, 0.5), (1, 1)],
         color=PINKS, light_emission=0.9, brightness=1.1, rotation=(0, 360), rot_speed=(-320, -260),
         stream=[(START + 0.02, ON, 6, 6)], **MOUTH_AT),
    dict(name="MouthRings", texture="kk_light_03", orientation="VelocityPerpendicular", direction="Front",
         speed=(14, 24), drag=2, lifetime=(0.35, 0.45), size=[(0, 8), (0.4, 24), (1, 34)],
         transparency=[(0, 0.1), (0.5, 0.4), (1, 1)], color=RINGC, light_emission=0.9, brightness=1.2,
         rotation=(0, 360), stream=[(START + 0.02, ON, 7, 7)], **MOUTH_AT),
    dict(name="MouthInflow", texture="kk_trace_06", orientation="VelocityParallel",
         shape={"type": "Sphere", "radius": 16.0, "style": "Surface", "inout": "Inward"}, speed=(50, 64),
         lifetime=(0.22, 0.28), size=[(0, 1), (0.3, 5), (1, 2)], transparency=[(0, 0.6), (0.2, 0.15), (1, 0.4)],
         color=INWARD, light_emission=1.0, brightness=1.2, stream=[(HIT, ON, 30, 30)], **MOUTH_AT),
] + [
    dict(name=f"MouthBolts{k}", texture=tex, lifetime=(0.07, 0.1), size=[(0, 10, 2), (1, 14, 2)], color=BOLT,
         light_emission=1.0, brightness=1.4, rotation=(0, 360), zoffset=4, stream=[(START + 0.05, ON, 5, 5)],
         **MOUTH_AT) for k, tex in enumerate(("kk_spark_05", "kk_spark_06"))
] + [
    # ---------------- la punta mientras crece ----------------
    dict(name="BeamHead", texture="fx_glow", line_u=1.0, lifetime=(0.05, 0.07), size=[(0, 20), (1, 24)],
         transparency=[(0, 0.15), (1, 0.4)], color=FLASH, light_emission=1.0, brightness=1.3, zoffset=4,
         stream=[(START, START + GROW + 0.03, 70, 70)]),
    dict(name="BeamHeadStar", texture="kk_star_08", line_u=1.0, lifetime=(0.05, 0.07), size=[(0, 24), (1, 28)],
         transparency=[(0, 0), (1, 0.3)], color=FLASH, light_emission=1.0, brightness=1.4, rotation=(0, 360), zoffset=5,
         stream=[(START, START + GROW + 0.03, 40, 40)]),
    # ---------------- a lo largo del rayo: anillos y remolinos que viajan, estela cósmica, relámpagos, auroras ----
    dict(name="TravelRings", texture="kk_light_03", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -3), speed_len=(1.6, 2.0), lifetime=(0.4, 0.45), size=[(0, 28), (0.5, 32), (1, 29)],
         transparency=FADE_IO, color=RINGC, light_emission=0.9, brightness=1.2, rotation=(0, 360),
         stream=[(HIT + 0.02, STOP - 0.05, 8, 8)]),
    dict(name="TravelSwirls", texture="fx_swirl_rings", orientation="VelocityPerpendicular", direction="Front",
         offset=(0, 0, -3), speed_len=(0.8, 1.0), lifetime=(0.85, 0.95), size=[(0, 34), (0.5, 38), (1, 35)],
         transparency=[(0, 1), (0.12, 0.45), (0.75, 0.55), (1, 1)], color=PINKS, light_emission=0.8, brightness=1.0,
         rotation=(0, 360), rot_speed=(-260, -200), stream=[(HIT + 0.02, STOP - 0.6, 3, 3)]),
    # la estela cósmica: nebulosa y estrellas que se quedan flotando donde pasó el rayo
    dict(name="NebulaTrail", texture="om_nebula_2x2", flipbook=STATIC2x2, shape=along_box(10, 0.9), direction="Top",
         spread=(180, 180), speed=(2, 6), drag=1, lifetime=(1.0, 1.5), size=[(0, 8, 2), (0.4, 14, 3), (1, 18, 3)],
         transparency=[(0, 1), (0.15, 0.55), (0.65, 0.65), (1, 1)], color=NEBW, light_emission=0.12,
         rotation=(0, 360), rot_speed=(-30, 30), zoffset=-5, stream=[(HIT + 0.05, ON, 24, 24)], **ALONG),
    dict(name="TrailStars", texture="fx_spark002", shape=along_box(9), direction="Top", spread=(180, 180),
         speed=(2, 10), drag=1.5, lifetime=(0.8, 1.4), size=TWINKLE, color=STAR, light_emission=1.0, brightness=1.8,
         rotation=(0, 45), stream=[(HIT, ON, 90, 90)], **ALONG),
    dict(name="TrailMotes", texture="fx_particle02", shape=along_box(8), direction="Top", spread=(180, 180),
         speed=(3, 12), drag=1.5, lifetime=(0.5, 0.9), size=[(0, 0), (0.15, 0.9, 0.3), (0.8, 0.7), (1, 0)],
         color=[(0, WHITE), (1, (150, 200, 255))], light_emission=1.0, brightness=1.6, stream=[(HIT, ON, 50, 50)],
         **ALONG),
    dict(name="Streaks", texture="kk_trace_03", orientation="VelocityParallel",
         shape={"type": "Box", "size": (8, 8, 1), "len_k": 0.76}, line_u=0.42, direction="Front", spread=(4, 4),
         speed_len=(1.6, 2.2), lifetime=(0.07, 0.1), size=[(0, 12, 3), (1, 7)], color=STREAK, light_emission=1.0,
         brightness=1.2, stream=[(HIT, ON, 40, 40)]),
    dict(name="StreaksPurple", texture="kk_trace_04", orientation="VelocityParallel",
         shape={"type": "Box", "size": (9, 9, 1), "len_k": 0.76}, line_u=0.42, direction="Front", spread=(4, 4),
         speed_len=(1.4, 2.0), lifetime=(0.08, 0.11), size=[(0, 12, 3), (1, 7)], color=MOUTH, light_emission=1.0,
         brightness=1.3, stream=[(HIT, ON, 25, 25)]),
    dict(name="Lightning", texture="fx_thunder", orientation="VelocityParallel", direction="Front", speed=(2, 2),
         shape=along_box(6, 0.8), lifetime=(0.07, 0.11), size=[(0, 16, 4), (1, 18, 4)], color=BOLT,
         light_emission=1.0, brightness=1.4, zoffset=2, stream=[(HIT, ON, 8, 8)], **ALONG),
    dict(name="AuroraBlue", texture="fx_aurora", shape=along_box(10, 0.9), direction="Top", spread=(60, 60),
         speed=(2, 5), lifetime=(0.6, 0.9), size=[(0, 14), (0.5, 20), (1, 22)],
         transparency=[(0, 1), (0.25, 0.6), (0.75, 0.65), (1, 1)], color=ENERGY, light_emission=0.9, brightness=1.0,
         zoffset=1, stream=[(HIT, ON, 9, 9)], **ALONG),
    dict(name="AuroraPurple", texture="fx_aurora", shape=along_box(10, 0.9), direction="Top", spread=(60, 60),
         speed=(2, 5), lifetime=(0.6, 0.9), size=[(0, 14), (0.5, 20), (1, 22)],
         transparency=[(0, 1), (0.25, 0.55), (0.75, 0.6), (1, 1)], color=MOUTH, light_emission=0.9, brightness=1.05,
         zoffset=1, stream=[(HIT, ON, 10, 10)], **ALONG),
    # ---------------- el impacto: lo que revienta cada vez que empieza a pegar ----------------
    dict(name="ImpactFlash", texture="fx_glow", emit=[(0, 1)], on_hit=True, lifetime=(0.3, 0.3),
         size=[(0, 16), (0.25, 48), (1, 52)], transparency=[(0, 0.25), (0.5, 0.6), (1, 1)], color=FLASH,
         light_emission=1.0, brightness=0.85, zoffset=4, **IMPACT),
    dict(name="ImpactStarBurst", texture="kk_star_09", emit=[(0, 2)], on_hit=True, lifetime=(0.28, 0.32),
         size=[(0, 20), (0.15, 54), (1, 14)], color=FLASH, light_emission=1.0, brightness=1.0, rotation=(0, 90),
         zoffset=5, **IMPACT),
    dict(name="ImpactHalo", texture="fx_halo", emit=[(0, 1), (0.05, 1)], on_hit=True, lifetime=(0.36, 0.4),
         size=[(0, 10), (1, 80)], transparency=[(0, 0.3), (0.5, 0.6), (1, 1)], color=SHOCK, light_emission=1.0,
         brightness=1.1, rotation=(0, 360), zoffset=3, **IMPACT),
    dict(name="ImpactShell", texture="kk_circle_02", orientation="VelocityPerpendicular", direction="Back",
         speed=(0.5, 0.5), emit=[(0, 1)], on_hit=True, lifetime=(0.4, 0.4), size=[(0, 12), (1, 84)],
         transparency=[(0, 0.1), (0.6, 0.45), (1, 1)], color=RINGC, light_emission=1.0, brightness=1.2, **IMPACT),
    dict(name="ImpactShellPurple", texture="kk_circle_02", orientation="VelocityPerpendicular", direction="Back",
         speed=(0.5, 0.5), emit=[(0.06, 1)], on_hit=True, lifetime=(0.4, 0.4), size=[(0, 10), (1, 66)],
         transparency=[(0, 0.2), (0.6, 0.5), (1, 1)], color=MOUTH, light_emission=1.0, brightness=1.2, **IMPACT),
    dict(name="ImpactNebulaBurst", texture="om_nebula_2x2", flipbook=STATIC2x2, emit=[(0, 10)], on_hit=True,
         direction="Back", spread=(75, 75), speed=(20, 45), drag=2.5, lifetime=(0.8, 1.2),
         size=[(0, 8, 2), (0.3, 20, 3), (1, 26, 3)], transparency=[(0, 1), (0.08, 0.3), (0.6, 0.45), (1, 1)],
         color=NEBW, light_emission=0.12, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, **IMPACT),
    dict(name="ImpactStreakBurst", texture="kk_trace_01", orientation="VelocityParallel", emit=[(0, 36)],
         on_hit=True, direction="Back", spread=(80, 80), speed=(90, 160), drag=3.5, lifetime=(0.25, 0.4),
         size=[(0, 6), (0.3, 22), (1, 9)], color=STREAK, light_emission=1.0, brightness=1.1, **IMPACT),
    dict(name="ImpactPurpleBurst", texture="kk_trace_01", orientation="VelocityParallel", emit=[(0, 20)],
         on_hit=True, direction="Back", spread=(80, 80), speed=(80, 150), drag=3.5, lifetime=(0.25, 0.4),
         size=[(0, 6), (0.3, 22), (1, 9)], color=MOUTH, light_emission=1.0, brightness=1.2, **IMPACT),
    dict(name="ImpactThunder", texture="fx_thunder", emit=[(0, 3), (0.08, 2)], on_hit=True, lifetime=(0.08, 0.12),
         size=[(0, 22), (1, 26)], color=BOLT, light_emission=1.0, brightness=1.5, rotation=(0, 360), zoffset=4,
         **IMPACT),
    # ---------------- el impacto mientras pega ----------------
    dict(name="ImpactGlow", texture="fx_glow", lifetime=(0.15, 0.22), size=[(0, 36, 4), (1, 42, 4)],
         transparency=[(0, 0.55), (1, 0.8)], color=DEEPB, light_emission=1.0, brightness=1.0, zoffset=2,
         stream=[(HIT, ON, 10, 10)], **IMPACT),
    dict(name="ImpactStar", texture="kk_star_08", lifetime=(0.08, 0.14), size=[(0, 30, 6), (0.5, 40, 8), (1, 28, 6)],
         transparency=[(0, 0.15), (0.6, 0.3), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.3,
         rotation=(0, 360), zoffset=4, stream=[(HIT, ON, 14, 14)], **IMPACT),
    dict(name="ImpactRings", texture="kk_light_03", orientation="VelocityPerpendicular", direction="Back",
         speed=(6, 14), lifetime=(0.3, 0.4), size=[(0, 10), (1, 46)], transparency=[(0, 0.1), (0.5, 0.4), (1, 1)],
         color=RINGC, light_emission=0.9, brightness=1.3, rotation=(0, 360), stream=[(HIT + 0.02, ON, 7, 7)],
         **IMPACT),
    dict(name="ImpactSplash", texture="kk_trace_01", orientation="VelocityParallel", direction="Back",
         spread=(80, 80), speed=(80, 150), drag=3.5, lifetime=(0.22, 0.36), size=[(0, 5), (0.3, 18), (1, 8)],
         color=STREAK, light_emission=1.0, brightness=1.1, stream=[(HIT, ON, 60, 60)], **IMPACT),
    dict(name="ImpactSplashPurple", texture="kk_trace_01", orientation="VelocityParallel", direction="Back",
         spread=(80, 80), speed=(70, 140), drag=3.5, lifetime=(0.22, 0.36), size=[(0, 5), (0.3, 18), (1, 8)],
         color=MOUTH, light_emission=1.0, brightness=1.2, stream=[(HIT, ON, 30, 30)], **IMPACT),
    dict(name="ImpactNebula", texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Back", spread=(70, 70),
         speed=(8, 20), drag=1.5, lifetime=(0.6, 0.9), size=[(0, 6, 1), (0.4, 14, 2), (1, 17, 2)],
         transparency=[(0, 1), (0.15, 0.45), (0.65, 0.55), (1, 1)], color=NEBW, light_emission=0.12,
         rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, stream=[(HIT + 0.05, ON, 14, 14)], **IMPACT),
    dict(name="ImpactCubes", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Back", spread=(70, 70),
         speed=(40, 90), drag=0.4, accel=(0, -160, 0), lifetime=(0.6, 1.0), size=[(0, 0.9, 0.35), (1, 0.7, 0.3)],
         color=CUBEC, rotation=(0, 360), rot_speed=(-400, 400), emit=[(0, 24)], on_hit=True,
         stream=[(HIT, ON, 22, 22)], **IMPACT),
    dict(name="ImpactStars", texture="fx_spark002", direction="Back", spread=(180, 180), speed=(10, 40), drag=2,
         lifetime=(0.4, 0.8), size=[(0, 0), (0.15, 2.2, 0.6), (1, 0)], color=STAR, light_emission=1.0,
         brightness=1.8, rotation=(0, 45), emit=[(0, 40)], on_hit=True, stream=[(HIT, ON, 40, 40)], **IMPACT),
] + [
    dict(name=f"ImpactBolts{k}", texture=tex, lifetime=(0.07, 0.11), size=[(0, 12, 3), (1, 18, 3)], color=BOLT,
         light_emission=1.0, brightness=1.4, rotation=(0, 360), zoffset=4, stream=[(HIT, ON, 5, 5)], **IMPACT)
    for k, tex in enumerate(("kk_spark_05", "kk_spark_06"))
] + [
    # el rayo se corta: un último destello y estrellas en la punta
    dict(name="CutFlash", texture="fx_glow", emit=[(STOP + 0.02, 1)], lifetime=(0.25, 0.25),
         size=[(0, 14), (0.3, 30), (1, 34)], transparency=[(0, 0.25), (1, 1)], color=FLASH, light_emission=1.0,
         brightness=1.0, zoffset=3, **TIP),
    dict(name="CutStars", texture="fx_spark002", emit=[(STOP + 0.02, 40)], direction="Back", spread=(180, 180),
         speed=(8, 26), drag=1.5, lifetime=(0.7, 1.1), size=TWINKLE, color=STAR, light_emission=1.0, brightness=1.8,
         rotation=(0, 45), **TIP),
    dict(name="CutNebula", texture="om_nebula_2x2", flipbook=STATIC2x2, emit=[(STOP + 0.02, 6)], direction="Back",
         spread=(80, 80), speed=(6, 16), drag=1.5, lifetime=(0.8, 1.2), size=[(0, 8, 2), (1, 20, 3)],
         transparency=[(0, 1), (0.12, 0.5), (0.65, 0.6), (1, 1)], color=NEBW, light_emission=0.12,
         rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, **TIP),
    # ---------------- el suelo bajo el impacto ----------------
    dict(name="GroundShock", texture="kk_circle_02", emit=[(0.01, 1)], on_hit=True, at_ground=True,
         offset=(0, 0.22, 0), lifetime=(0.45, 0.45), size=[(0, 20), (1, 90)], transparency=[(0, 0.25), (0.5, 0.55), (1, 1)],
         color=SHOCK, light_emission=0.5, **DECAL),
    dict(name="GroundVoid", texture="fx_glow", emit=[(0.02, 1)], on_hit=True, at_ground=True, offset=(0, 0.1, 0),
         lifetime=(3.2, 3.2), size=[(0, 10), (0.08, 34), (1, 36)], transparency=[(0, 1), (0.08, 0.4), (0.8, 0.45), (1, 1)],
         color=VOIDC, light_emission=0, **DECAL),
    dict(name="GroundCracks", texture="om_cracks", emit=[(0.03, 1)], on_hit=True, at_ground=True, offset=(0, 0.16, 0),
         lifetime=(3.2, 3.2), size=[(0, 10), (0.08, 44), (1, 46)],
         transparency=[(0, 1), (0.05, 0.25), (0.12, 0.05), (0.3, 0.15), (0.8, 0.3), (1, 1)], color=CRACKC,
         light_emission=0.8, rotation=(0, 360), **DECAL),
    dict(name="GroundDust", texture="kk_smoke_07", emit=[(0.02, 18)], on_hit=True, at_ground=True, offset=(0, 2, 0),
         direction="Front", spread=(180, 3), speed=(50, 90), drag=3.5, accel=(0, 4, 0), lifetime=(0.9, 1.3),
         size=[(0, 8, 2), (0.3, 16, 3), (1, 22, 4)], transparency=[(0, 0.5), (0.2, 0.35), (1, 1)], color=DUST,
         rotation=(0, 360), rot_speed=(-40, 40), zoffset=-3),
    dict(name="GroundSpikes", texture="fx_spikes", orientation="FacingCameraWorldUp", at_ground=True,
         offset=(0, 3, 0), shape={"type": "Box", "size": (12, 1, 12)}, lifetime=(0.22, 0.32),
         size=[(0, 6), (0.5, 10), (1, 11)], transparency=[(0, 0.7), (0.3, 0.45), (1, 1)], color=RINGC,
         light_emission=0.7, brightness=1.0, zoffset=1, stream=[(HIT + 0.05, ON, 14, 14)]),
    dict(name="GroundCubes", texture="om_cubes_2x2", flipbook=STATIC2x2, at_ground=True, offset=(0, 0.6, 0),
         shape={"type": "Box", "size": (14, 1, 14)}, direction="Top", spread=(25, 25), speed=(15, 35),
         accel=(0, -120, 0), lifetime=(0.5, 0.8), size=[(0, 0.7, 0.3), (1, 0.5, 0.2)], color=CUBEC,
         rotation=(0, 360), rot_speed=(-300, 300), stream=[(HIT + 0.05, ON, 18, 18)]),
    dict(name="GroundStars", texture="fx_spark002", at_ground=True, offset=(0, 1, 0),
         shape={"type": "Box", "size": (16, 1, 16)}, direction="Top", spread=(20, 20), speed=(6, 16),
         accel=(0, 8, 0), lifetime=(0.6, 1.0), size=[(0, 0), (0.15, 2.0, 0.5), (1, 0)], color=STAR,
         light_emission=1.0, brightness=1.7, rotation=(0, 45), stream=[(HIT + 0.1, ON, 14, 14)]),
    # la estela que deja al barrer el suelo: marca oscura con grietas de luz
    dict(name="TrailVoid", texture="fx_glow", trail=True, at_ground=True, offset=(0, 0.08, 0), lifetime=(2.4, 2.4),
         size=[(0, 6), (0.08, 15), (1, 16)], transparency=[(0, 1), (0.08, 0.45), (0.8, 0.5), (1, 1)], color=VOIDC,
         light_emission=0, **DECAL),
    dict(name="TrailCracks", texture="om_cracks", trail=True, at_ground=True, offset=(0, 0.14, 0), lifetime=(2.2, 2.2),
         size=[(0, 6), (0.1, 16), (1, 17)], transparency=[(0, 1), (0.06, 0.2), (0.3, 0.2), (0.8, 0.35), (1, 1)],
         color=CRACKC, light_emission=0.8, rotation=(0, 360), **DECAL),
    dict(name="TrailScorch", texture="kz_scorch", trail=True, at_ground=True, offset=(0, 0.12, 0), lifetime=(2.4, 2.4),
         size=[(0, 6), (0.08, 17), (1, 18)], transparency=[(0, 1), (0.06, 0.45), (0.75, 0.55), (1, 1)], color=SCORCH,
         light_emission=0, rotation=(0, 360), **DECAL),
]

COSMIC_BEAM = {
    "name": "CosmicBeam",
    "doc": ("OMNÍVORA: RAYO CÓSMICO de 3 s. La boca devora energía 0.3 s y suelta un rayo de nebulosa azul muy oscura "
            "con hebras celestes y púrpura y el núcleo blanco; viajan anillos y remolinos, deja una estela de nebulosa "
            "y estrellas. Se puede apuntar mientras dura: pega en la primera superficie (hasta 124 studs × escala) con "
            "halo, ondas, nebulosa, cubitos y grietas de luz en el suelo (deja una estela si lo barre). Cierra limpio."),
    "duration": STOP + FADE,
    "beam": {"start": START, "grow": GROW, "stop": STOP, "fade": FADE, "max_len": 124, "trail_every": 0.1,
             "trail_move": 4, "rehit": 0.3, "light_color": (90, 150, 255), "light_brightness": 5, "light_range": 50},
    "beams": BEAMS,
    "layers": LAYERS,
    "shake_ramp": (START, STOP, 0.25, 0.5, 1.0),
    "shakes": [(HIT, 0.9, 0.5), (STOP, 0.45, 0.35)],
}
